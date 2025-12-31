local M = {}

M.defaults = {
    filetypes = { "robot" },
    -- Command to run a specific test. 
    -- {file} will be replaced by the file path.
    -- {test} will be replaced by the test case name.
    test_command = "robot -t {test} {file}",
    
    -- Command to run the full suite.
    -- {file} will be replaced by the file path.
    suite_command = "robot {file}",

    -- Command to run with a specific tag.
    -- {file} will be replaced by the file path.
    -- {tag} will be replaced by the tag name.
    tag_command = "robot --include {tag} {file}",

    -- Floating window configuration
    window = {
        width = 0.8,
        height = 0.8,
        border = "rounded",
    },

    -- Icons for test status
    icons = {
        pass = "✓",
        fail = "✗",
    },
    
    -- Clear markers before running new tests.
    -- Set to false to accumulate results from multiple runs.
    clear_on_run = true,

    -- Display mode for markers: "eol" (end of line) or "sign_column" (left gutter)
    display_mode = "eol",
}

M.options = vim.deepcopy(M.defaults)

function M.setup(options)
    M.options = vim.tbl_deep_extend("force", M.defaults, options or {})
end

return M
