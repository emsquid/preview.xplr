# preview.xplr

This plugin provides a, somewhat cool, preview panel for [xplr](https://xplr.dev). 

## Requirements

- `style` requires my [styling plugin](https://github.com/emsquid/style.xplr).
- `highlight` requires [highlight](https://gitlab.com/saalen/highlight) command line tool
- `image` requires [viu](https://github.com/atanunq/viu) for blocks preview, or [kitty](https://github.com/kovidgoyal/kitty) terminal for better (but slower) preview
> **NOTE**: As of now kitty image preview requires python3 and [Pillow](https://pypi.org/project/Pillow/) library to be installed. I made a lua implementation but it was twice less efficient 

## Installation

### Install manually

- Add the following line in `~/.config/xplr/init.lua`

    ```lua
    local home = os.getenv("HOME")
    package.path = home
      .. "/.config/xplr/plugins/?/src/init.lua;"
      .. home
      .. "/.config/xplr/plugins/?.lua;"
      .. package.path
    ```

- Clone the plugin

    ```bash
    mkdir -p ~/.config/xplr/plugins
    git clone https://github.com/emsquid/preview.xplr ~/.config/xplr/plugins/preview
    ```

- Require the module in `~/.config/xplr/init.lua`

    ```lua
    require("preview").setup("your config goes here")

    -- And add these hooks if you want to use kitty image preview

    return {
        on_load = {...},
        on_directory_change = {...},
        on_focus_change = {...},
        on_mode_switch = { { CallLuaSilently = "custom.preview.clear_image_preview" } },
        on_layout_switch = { { CallLuaSilently = "custom.preview.clear_image_preview" } },
    }
    ```
    > **NOTE**: These hooks aren't upstream yet, we are working on them

## Configuration

- Here is the default config
    ```lua
    require("preview").setup({
        as_default = false,
        keybind = "P", -- only needed if you set `as_default` to false
        left_pane_constraint = { Percentage = 55 },
        right_pane_constraint = { Percentage = 45 },
        style = false,
        text = {
            enable = true,
            highlight = {
                enable = false,
                method = "ansi",
                style = nil,
            }
        },
        image = {
            enable = false,
            method = nil,
        },
        directory = {
            enable = true,
        }
    })
    ```
- See all possibilities
    | **Configuration Key** | **Type** | **Description** 
    |----|----|----|
    | `as_default` | `boolean` | Whether to make preview layout default or not |
    | `keybind` | `string` | The keybind used to switch to preview layout (only needed if `as_default` is set to false) |
    | `left_pane_constraint` | `table` refers to [Constraint](https://xplr.dev/en/layout#constraint) | The constraint applied to the left pane |
    | `right_pane_constraint` | `table` refers to [Constraint](https://xplr.dev/en/layout#constraint) | The constraint applied to the right pane |
    | `style` | `boolean` | Whether to style or not (requires [styling plugin](https://github.com/emsquid/style.xplr)) |
    | `text.enable` | `boolean` | Whether to preview text files or not |
    | `text.highlight.enable` | `boolean` | Whether to highlight previewed text files or not (requires [highlight](https://gitlab.com/saalen/highlight)) |
    | `text.highlight.method` | `string` one of "ansi", "xterm256", "truecolor" | The method used by highlight |
    | `text.highlight.style` | `string` | A custom style to pass as an argument, see [here](https://gitlab.com/saalen/highlight#user-content-theme-definitions) |
    | `image.enable` | `boolean` | Whether to preview images or not |
    | `image.method` | `string` one of "kitty", "viu" | The method used to display images |
    | `directory.enable` | `boolean` | Whether to preview directories or not |
