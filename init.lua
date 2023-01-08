---@diagnostic disable
local xplr = xplr
---@diagnostic enable
local helper = require("preview.lib.helper")
local manager = require("preview.lib.previewManager")

local preview_pane = {
    CustomContent = {
        title = "Preview",
        body = { DynamicParagraph = { render = "custom.preview.render" } },
    },
}

local function build_args(args)
    args = args or {}

    args.as_default = args.as_default or false
    args.keybind = args.keybind or "P"

    args.left_pane_constraint = args.left_pane_constraint or { Percentage = 55 }
    args.right_pane_constraint = args.right_pane_constraint or { Percentage = 45 }

    args.style = args.style or (args.style == nil and true)

    args.text = args.text or {}
    args.text.enable = args.text.enable or (args.text.enable == nil and true)
    args.text.highlight = args.text.highlight or {}
    args.text.highlight.method = args.text.highlight.method or "ansi"

    args.image = args.image or {}
    args.image.enable = args.image.enable or false
    args.image.method = (args.image.enable and args.image.method) or ""

    args.directory = args.directory or {}
    args.directory.enable = args.directory.enable or (args.directory.enable == nil and true)

    return args
end

local function setup(args)
    args = build_args(args)

    local preview_layout = {
        Vertical = {
            config = {
                constraints = {
                    { Min = 1 },
                    { Length = 3 },
                },
            },
            splits = {
                {
                    Horizontal = {
                        config = {
                            constraints = {
                                args.left_pane_constraint,
                                args.right_pane_constraint
                            },
                        },
                        splits = {
                            "Table",
                            preview_pane
                        },
                    },
                },
                "InputAndLogs",
            },
        },
    }

    xplr.fn.custom.preview = {
        render = function(ctx)
            local node = ctx.app.focused_node

            if node then
                return manager.handle(node, ctx, args)
            else
                return ""
            end
        end,
        clear_image_preview = function(app)
            if (app.mode.layout ~= nil or not helper.table_match(app.layout, preview_layout)) and
                manager.current.type == "image" then
                helper.clear_image()
            end
        end
    }

    if args.as_default then
        xplr.config.layouts.builtin.default = preview_layout
    else
        xplr.config.layouts.custom.preview = preview_layout

        xplr.config.modes.builtin.switch_layout.key_bindings.on_key[args.keybind] = {
            help = "preview",
            messages = {
                "PopMode",
                { SwitchLayoutCustom = "preview" },
            },
        }
    end
end

return { setup = setup }
