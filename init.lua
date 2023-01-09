---@diagnostic disable
local xplr = xplr
---@diagnostic enable
local helper = require("preview.lib.helper")
local manager = require("preview.lib.previewManager")


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

local function create_preview_assets(args)
    args = build_args(args)

    local assets = {}
    assets.panel = {
        CustomContent = {
            title = "Preview",
            body = { DynamicParagraph = { render = "custom.preview.render" } },
        },
    }
    assets.layout = {
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
                            assets.panel
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
            if (app.mode.layout ~= nil or not helper.table_match(app.layout, assets.layout)) and
                manager.current.type == "image" then
                helper.handle_batch_commands({ "clear" }, false)
            end
        end
    }

    return assets
end

local function setup(args)
    args = build_args(args)

    local assets = create_preview_assets(args)

    if args.as_default then
        xplr.config.layouts.builtin.default = assets.layout
    else
        xplr.config.layouts.custom.preview = assets.layout

        xplr.config.modes.builtin.switch_layout.key_bindings.on_key[args.keybind] = {
            help = "preview",
            messages = {
                "PopMode",
                { SwitchLayoutCustom = "preview" },
            },
        }
    end
end

return { setup = setup, create_preview_assets = create_preview_assets }
