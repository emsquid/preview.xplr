---@diagnostic disable
local xplr = xplr
---@diagnostic enable
local home = os.getenv("HOME") or "~"

-- HELPERS

local style_module = require("style")
local style = style_module.style
local separator = style_module.separator
local get_node_style = style_module.get_node_style

local function split(str, sep)
    if sep == nil then
        sep = "%s"
    end

    local t = {}

    for m in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(t, m)
    end

    return t
end

local function datetime(num)
    return tostring(os.date("%a %b %d %H:%M:%S %Y", num / 1000000000))
end

local function mime_type(node)
    return xplr.util.shell_execute(
        "file",
        {
            "--brief",
            "--mime-type",
            node.absolute_path
        }
    ).stdout
end

local function escape(path)
    return string.gsub(string.gsub(path, "\\", "\\\\"), "\n", "\\n")
end

local function bit(x, color, cond)
    if cond then
        return color(x)
    else
        return color("-")
    end
end

-- FORMATTING

local function permissions(p)
    local result = ""

    result = result .. bit("r", style.fg.Green, p.user_read)
    result = result .. bit("w", style.fg.Yellow, p.user_write)

    if p.user_execute == false and p.setuid == false then
        result = result .. bit("-", style.fg.Red, p.user_execute)
    elseif p.user_execute == true and p.setuid == false then
        result = result .. bit("x", style.fg.Red, p.user_execute)
    elseif p.user_execute == false and p.setuid == true then
        result = result .. bit("S", style.fg.Red, p.user_execute)
    else
        result = result .. bit("s", style.fg.Red, p.user_execute)
    end

    result = result .. bit("r", style.fg.Green, p.group_read)
    result = result .. bit("w", style.fg.Yellow, p.group_write)

    if p.group_execute == false and p.setuid == false then
        result = result .. bit("-", style.fg.Red, p.group_execute)
    elseif p.group_execute == true and p.setuid == false then
        result = result .. bit("x", style.fg.Red, p.group_execute)
    elseif p.group_execute == false and p.setuid == true then
        result = result .. bit("S", style.fg.Red, p.group_execute)
    else
        result = result .. bit("s", style.fg.Red, p.group_execute)
    end

    result = result .. bit("r", style.fg.Green, p.other_read)
    result = result .. bit("w", style.fg.Yellow, p.other_write)

    if p.other_execute == false and p.setuid == false then
        result = result .. bit("-", style.fg.Red, p.other_execute)
    elseif p.other_execute == true and p.setuid == false then
        result = result .. bit("x", style.fg.Red, p.other_execute)
    elseif p.other_execute == false and p.setuid == true then
        result = result .. bit("T", style.fg.Red, p.other_execute)
    else
        result = result .. bit("t", style.fg.Red, p.other_execute)
    end

    return style.add_modifiers.Bold(result) .. separator
end

local function stats(node)
    local type = node.mime_essence

    if node.is_symlink then
        if node.is_broken then
            type = "broken symlink"
        else
            type = "symlink to: " .. node.symlink.absolute_path
        end
    end

    return style.fg[xplr.config.node_types.symlink.style.fg](node.relative_path)
        .. separator
        .. "\n Type     : "
        .. type
        .. "\n Size     : "
        .. node.human_size
        .. "\n Owner    : "
        .. node.uid .. ":" .. node.gid
        .. "\n Perm     : "
        .. permissions(node.permissions)
        .. "\n Created  : "
        .. datetime(node.created)
        .. "\n Modified : "
        .. datetime(node.last_modified)
end

local function icon(node)
    local types = xplr.config.node_types
    local node_icon = ""

    -- TYPE
    if node.is_symlink then
        node_icon = types.symlink.meta.icon or node_icon
    elseif node.is_dir then
        node_icon = types.directory.meta.icon or node_icon
    else
        node_icon = types.file.meta.icon or node_icon
    end

    -- MIME
    local mime = split(node.mime_essence, "/")
    local mime_essence = types.mime_essence[mime[1]]

    if mime_essence ~= nil then
        if mime_essence[mime[2]] ~= nil and mime_essence[mime[2]] ~= nil then
            node_icon = mime_essence[mime[2]].meta.icon or node_icon
        elseif mime_essence["*"] ~= nil and mime_essence["*"] ~= nil then
            node_icon = mime_essence["*"].meta.icon or node_icon
        end
    end

    -- EXTENSION
    local extension = types.extension[node.extension]

    if extension ~= nil and extension.meta ~= nil then
        node_icon = extension.meta.icon or node_icon
    end

    -- SPECIAL
    local special = types.special[node.relative_path]

    if special ~= nil and special.meta ~= nil then
        node_icon = special.meta.icon or node_icon
    end

    return node_icon
end

local function format(node)
    -- ICON
    local node_icon = icon(node)

    -- NAME
    local node_name = escape(node.relative_path)

    if node.is_dir then
        node_name = node_name .. "/"
    end

    node_name = node_name .. xplr.config.general.default_ui.suffix

    if node.is_symlink then
        node_name = node_name .. " -> "

        if node.is_broken then
            node_name = node_name .. "×"
        else
            node_name = node_name .. escape(node.symlink.absolute_path)

            if node.symlink.is_dir then
                node_name = node_name .. "/"
            end
        end
    end

    -- STYLE
    local node_style = get_node_style(node)

    return node_style(node_icon .. " " .. node_name .. separator)
end

-- PREVIEW

local clear_needed = true
local image_previewed = ""

local function preview_text(file, ctx, args)
    clear_needed = (image_previewed ~= "")

    local preview = {}

    if args.text.highlight.enable then
        preview = xplr.util.shell_execute(
            "highlight",
            {
                "--out-format=" .. (args.text.highlight.method or "ansi"),
                "--line-range=1-" .. ctx.layout_size.height,
                "--style=" .. (args.text.highlight.style or "night"),
                file.absolute_path,
            }
        )
    else
        preview = xplr.util.shell_execute(
            "head",
            { "-" .. ctx.layout_size.height, file.absolute_path }
        )
    end

    return (preview.returncode == 0 and preview.stdout) or stats(file)
end

local function preview_image(image, ctx, args)
    if (image_previewed ~= image.absolute_path) and args.image.method == "kitty" then
        local x, y = ctx.layout_size.x + 1, ctx.layout_size.y + 1
        local height, width = ctx.layout_size.height - 2, ctx.layout_size.width - 2
        -- os.execute is better here
        local success = os.execute(
            string.format(
                "python3 %s/.config/xplr/plugins/preview/imagePreviewer.py %d %d %d %d %s",
                home,
                x,
                y,
                width,
                height,
                image.absolute_path
            )
        )
        image_previewed = (success and image.absolute_path) or ""
        return (success and "") or stats(image)
    elseif (image_previewed ~= image.absolute_path) and args.image.method == "viu" then
        local preview = xplr.util.shell_execute(
            "viu",
            { "--blocks", "--static", "--width", ctx.layout_size.width, image.absolute_path }
        )
        return (preview.returncode == 0 and preview.stdout) or stats(image)
    elseif (image_previewed ~= image.absolute_path) then
        return stats(image)
    else
        return ""
    end
end

local function preview_dir(dir, ctx, args)
    clear_needed = (image_previewed ~= "")

    local nodes = xplr.util.explore(dir.absolute_path, ctx.app.explorer_config)
    local subnodes = ""

    for i, node in ipairs(nodes) do
        if i > ctx.layout_size.height + 1 then
            break
        elseif args.directory.style then
            subnodes = subnodes .. format(node) .. "\n"
        else
            subnodes = subnodes .. node.relative_path .. "\n"
        end
    end

    return subnodes
end

local function preview(node, ctx, args)
    local mime = mime_type(node)

    if node.is_file then
        if args.text.enable and (mime:match("text") or mime:match("json")) then
            return preview_text(node, ctx, args)
        elseif args.image.enable and (mime:match("image") or mime:match("video")) then
            return preview_image(node, ctx, args)
        else
            return stats(node)
        end
    elseif args.directory.enable and node.is_dir then
        return preview_dir(node, ctx, args)
    else
        return stats(node)
    end
end

local function setup(args)
    args = args or {}

    args.as_default = args.as_default or false
    args.keybind = args.keybind or "P"

    args.left_pane_constraint = args.left_pane_constraint or { Percentage = 55 }
    args.right_pane_constraint = args.right_pane_constraint or { Percentage = 45 }

    args.text = args.text or {}
    args.text.enable = args.text.enable or (args.text.enable == nil and true)
    args.text.highlight = args.text.highlight or {}

    args.image = args.image or {}
    args.image.enable = args.image.enable or false
    args.image.method = (args.image.enable and args.image.method) or ""

    args.directory = args.directory or {}
    args.directory.enable = args.directory.enable or (args.directory.enable == nil and true)
    args.directory.style = args.directory.style or (args.directory.style == nil and true)

    xplr.fn.custom.preview = {
        render = function(ctx)
            local node = ctx.app.focused_node

            if node then
                return preview(node, ctx, args)
            else
                return ""
            end
        end,
        on_focus_change = function()
            if clear_needed then
                image_previewed = ""
                os.execute(string.format("python3 %s/.config/xplr/plugins/preview/imagePreviewer.py clear &", home))
            end
        end
    }

    local preview_pane = {
        CustomContent = {
            title = "Preview",
            body = { DynamicParagraph = { render = "custom.preview.render" } },
        },
    }

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
