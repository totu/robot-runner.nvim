local config = require("robot_runner.config")
local M = {}

local ns = vim.api.nvim_create_namespace("robot_runner")
local last_terminal_buf = nil
local last_terminal_win = nil

-- Define highlight groups
vim.api.nvim_set_hl(0, "RobotRunnerPass", { link = "String", default = true })
vim.api.nvim_set_hl(0, "RobotRunnerFail", { link = "Error", default = true })

-- Helper to find the test case name
local function get_current_test_name()
    local current_line_num = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(0, 0, current_line_num, false)
    local candidate = nil
    
    -- Iterate backwards from current line
    for i = #lines, 1, -1 do
        local line = lines[i]
        
        -- Check for section header
        if line:match("^%*%*%*") then
            if line:lower():match("test cases") then
                return candidate
            else
                -- In some other section like Settings or Keywords
                return nil
            end
        end

        -- Check if line is a potential test case (starts with non-whitespace)
        local clean_line = line:gsub("%s*#.*$", "") -- Remove comments
        if clean_line:match("^%S") then
             if not candidate then
                 candidate = vim.trim(clean_line)
             end
        end
    end
    return nil
end

local function parse_output(lines)
    local results = {}
    for _, line in ipairs(lines) do
        -- Strip ANSI codes
        local clean_line = line:gsub("\27%[[0-9;]*m", "")
        
        -- Match "Test Name ... | PASS |" or "| FAIL |"
        -- Using %u+ to capture PASS or FAIL
        local name, status = clean_line:match("^(.-)%s+|%s+(%u+)%s+|")
        if name and (status == "PASS" or status == "FAIL") then
            local trimmed_name = vim.trim(name)
            results[trimmed_name] = status
            
            -- Handle "Test Name :: Documentation" format
            -- If the name contains " :: ", we also store the part before it
            local test_name_only = trimmed_name:match("^(.-)%s+::%s+")
            if test_name_only then
                results[vim.trim(test_name_only)] = status
            end
        end
    end
    return results
end

local function set_markers(source_buf, results)
    if not vim.api.nvim_buf_is_valid(source_buf) then return end
    
    -- Clear existing markers if configured
    if config.options.clear_on_run then
        vim.api.nvim_buf_clear_namespace(source_buf, ns, 0, -1)
    end
    
    local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
    for i, line in ipairs(lines) do
        -- Check if this line is a test case definition
        -- It should start with non-whitespace and not be a header
        if line:match("^%S") and not line:match("^%*") then
            local raw_name = line:gsub("%s*#.*$", "")
            local test_name = vim.trim(raw_name)
            
            -- Robot Framework normalizes spaces to single space
            local normalized_name = test_name:gsub("%s+", " ")
            
            local status = results[test_name] or results[normalized_name]
            
            if status then
                -- If we are accumulating (not clearing), we should remove any existing marker on this line first
                if not config.options.clear_on_run then
                    local extmarks = vim.api.nvim_buf_get_extmarks(source_buf, ns, {i-1, 0}, {i-1, -1}, {})
                    for _, mark in ipairs(extmarks) do
                        vim.api.nvim_buf_del_extmark(source_buf, ns, mark[1])
                    end
                end

                local icon = status == "PASS" and config.options.icons.pass or config.options.icons.fail
                local hl = status == "PASS" and "RobotRunnerPass" or "RobotRunnerFail"
                
                local opts = {}
                if config.options.display_mode == "sign_column" then
                    -- Try to use sign_text (nvim 0.10+)
                    -- Fallback to sign_hl_group only (which shows a dot or similar if no text defined, 
                    -- but we can define signs if needed. For now, let's try sign_text)
                    opts.sign_text = icon
                    opts.sign_hl_group = hl
                    -- Fallback for older neovim: define signs?
                    -- Let's just set priority high
                    opts.priority = 20
                else
                    opts.virt_text = {{ " " .. icon, hl }}
                end

                vim.api.nvim_buf_set_extmark(source_buf, ns, i-1, 0, opts)
            end
        end
    end
end

-- Helper to open floating window and run command
local function run_in_floating_win(cmd, source_buf)
    local width = math.floor(vim.o.columns * config.options.window.width)
    local height = math.floor(vim.o.lines * config.options.window.height)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- Close existing window if open
    if last_terminal_win and vim.api.nvim_win_is_valid(last_terminal_win) then
        vim.api.nvim_win_close(last_terminal_win, true)
    end

    -- Cleanup previous buffer
    if last_terminal_buf and vim.api.nvim_buf_is_valid(last_terminal_buf) then
        vim.api.nvim_buf_delete(last_terminal_buf, { force = true })
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
    last_terminal_buf = buf

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = config.options.window.border
    })
    last_terminal_win = win

    -- Close window on 'q'
    vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })

    -- Run the command in terminal
    vim.fn.termopen(cmd, {
        on_exit = function()
            -- Read the terminal buffer content
            if vim.api.nvim_buf_is_valid(buf) then
                local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                local results = parse_output(lines)
                
                -- Schedule the marker update on the main loop
                vim.schedule(function()
                    set_markers(source_buf, results)
                end)
            end
        end
    })
    -- Start in insert mode
    vim.cmd("startinsert")
end

function M.run_suite(args)
    local file = vim.fn.expand("%:p")
    local source_buf = vim.api.nvim_get_current_buf()
    local cmd = config.options.suite_command
    
    cmd = cmd:gsub("{file}", vim.fn.shellescape(file))
    
    if args and args ~= "" then
        cmd = cmd .. " " .. args
    end
    
    run_in_floating_win(cmd, source_buf)
end

function M.run_test(args)
    local file = vim.fn.expand("%:p")
    local source_buf = vim.api.nvim_get_current_buf()
    local test_name = get_current_test_name()
    
    if not test_name then
        vim.notify("Could not find a test case definition above the cursor.", vim.log.levels.ERROR)
        return
    end

    local cmd = config.options.test_command
    cmd = cmd:gsub("{file}", vim.fn.shellescape(file))
    cmd = cmd:gsub("{test}", vim.fn.shellescape(test_name))
    
    if args and args ~= "" then
        cmd = cmd .. " " .. args
    end

    run_in_floating_win(cmd, source_buf)
end

function M.run_tag(args)
    local file = vim.fn.expand("%:p")
    local source_buf = vim.api.nvim_get_current_buf()
    local tag = vim.fn.expand("<cword>")
    
    if not tag or tag == "" then
        vim.notify("No tag found under cursor.", vim.log.levels.ERROR)
        return
    end

    local cmd = config.options.tag_command
    cmd = cmd:gsub("{file}", vim.fn.shellescape(file))
    cmd = cmd:gsub("{tag}", vim.fn.shellescape(tag))
    
    if args and args ~= "" then
        cmd = cmd .. " " .. args
    end

    run_in_floating_win(cmd, source_buf)
end

function M.toggle()
    if last_terminal_win and vim.api.nvim_win_is_valid(last_terminal_win) then
        vim.api.nvim_win_close(last_terminal_win, true)
        last_terminal_win = nil
    else
        if last_terminal_buf and vim.api.nvim_buf_is_valid(last_terminal_buf) then
            local width = math.floor(vim.o.columns * config.options.window.width)
            local height = math.floor(vim.o.lines * config.options.window.height)
            local row = math.floor((vim.o.lines - height) / 2)
            local col = math.floor((vim.o.columns - width) / 2)
            
            last_terminal_win = vim.api.nvim_open_win(last_terminal_buf, true, {
                relative = "editor",
                width = width,
                height = height,
                row = row,
                col = col,
                style = "minimal",
                border = config.options.window.border
            })
            vim.cmd("startinsert")
        else
            vim.notify("No active Robot Runner terminal found.", vim.log.levels.WARN)
        end
    end
end

function M.clear_markers()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

function M.register_autocmds()
    local grp = vim.api.nvim_create_augroup("RobotRunner", { clear = true })
    
    vim.api.nvim_create_autocmd("FileType", {
        pattern = config.options.filetypes,
        group = grp,
        callback = function()
            vim.api.nvim_buf_create_user_command(0, "RobotRun", function(opts)
                M.run_suite(opts.args)
            end, { nargs = "*" })
            
            vim.api.nvim_buf_create_user_command(0, "RobotRunTest", function(opts)
                M.run_test(opts.args)
            end, { nargs = "*" })

            vim.api.nvim_buf_create_user_command(0, "RobotRunTag", function(opts)
                M.run_tag(opts.args)
            end, { nargs = "*" })

            vim.api.nvim_buf_create_user_command(0, "RobotClear", function()
                M.clear_markers()
            end, {})
        end
    })

    vim.api.nvim_create_user_command("RobotToggle", function()
        M.toggle()
    end, {})
end

function M.setup(options)
    config.setup(options)
    M.register_autocmds()
end

return M
