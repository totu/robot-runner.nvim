# robot_runner.nvim

A Neovim plugin to run Robot Framework tests in a floating window.

## Features

- Run the full suite (current file).
- Run the specific test case under the cursor.
- Run tests with the tag under the cursor.
- Customizable commands.
- Floating terminal window.
- **Pass/Fail markers** displayed next to test cases after execution.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "totu/robot-runner.nvim",
    config = function()
        require("robot_runner").setup({
            -- Optional configuration
            -- filetypes = { "robot" },
            -- test_command = "robot -t {test} {file}",
            -- suite_command = "robot {file}",
            -- tag_command = "robot --include {tag} {file}",
            -- window = { width = 0.8, height = 0.8, border = "rounded" },
        })
    end
}
```

## Usage

The plugin activates automatically in `*.robot` files.

- `:RobotRun [args]` - Run the full suite.
- `:RobotRunTest [args]` - Run the test case under the cursor.
- `:RobotRunTag [args]` - Run tests with the tag under the cursor.
- `:RobotClear` - Clear all test markers from the buffer.

You can pass additional arguments to the commands, e.g.:
`:RobotRun -i smoke`
`:RobotRunTest -v VAR:value`

## Configuration

The default configuration is:

```lua
{
    filetypes = { "robot" },
    -- {file} is replaced by the file path (shell escaped)
    -- {test} is replaced by the test name (shell escaped)
    -- {tag} is replaced by the tag name (shell escaped)
    test_command = "robot -t {test} {file}",
    suite_command = "robot {file}",
    tag_command = "robot --include {tag} {file}",
    window = {
        width = 0.8,
        height = 0.8,
        border = "rounded",
    },
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
```
