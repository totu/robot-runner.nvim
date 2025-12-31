local config = require("robot_runner.config")
local M = {}

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
        -- And we haven't found a candidate yet (since we want the closest one above cursor)
        -- Actually, we want the *first* one we encounter going backwards, which is the closest one.
        -- But wait, if we are inside a test case, the closest one above is the correct one.
        -- If we are between test cases (empty lines), we might want the one above.
        
        local clean_line = line:gsub("%s*#.*$", "") -- Remove comments
        if clean_line:match("^%S") then
             -- Found a line starting with text.
             -- If we already have a candidate, do we overwrite it?
             -- No, we are going backwards. The first one we see is the one immediately above the cursor.
             -- So that is our candidate.
             if not candidate then
                 candidate = vim.trim(clean_line)
             end
        end
    end
    return nil
end

-- Helper to open floating window and run command
local function run_in_floating_win(cmd)
    local width = math.floor(vim.o.columns * config.options.window.width)
    local height = math.floor(vim.o.lines * config.options.window.height)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = config.options.window.border
    })

    -- Close window on 'q'
    vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })

    -- Run the command in terminal
    vim.fn.termopen(cmd)
    -- Start in insert mode
    vim.cmd("startinsert")
end

function M.run_suite(args)
    local file = vim.fn.expand("%:p")
    local cmd = config.options.suite_command
    
    cmd = cmd:gsub("{file}", vim.fn.shellescape(file))
    
    if args and args ~= "" then
        cmd = cmd .. " " .. args
    end
    
    run_in_floating_win(cmd)
end

function M.run_test(args)
    local file = vim.fn.expand("%:p")
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

    run_in_floating_win(cmd)
end

function M.run_tag(args)
    local file = vim.fn.expand("%:p")
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

    run_in_floating_win(cmd)
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
        end
    })
end

function M.setup(options)
    config.setup(options)
    M.register_autocmds()
end

return M
