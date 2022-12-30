---@diagnostic disable
local xplr = xplr
---@diagnostic enable

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

local function bit(x, color, cond)
    if cond then
        return color(x)
    else
        return color("-")
    end
end

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
    local function path_escape(path)
        return string.gsub(string.gsub(path, "\\", "\\\\"), "\n", "\\n")
    end

    -- ICON
    local node_icon = icon(node)

    -- NAME
    local node_name = path_escape(node.relative_path)

    if node.is_dir then
        node_name = node_name .. "/"
    end

    node_name = node_name .. xplr.config.general.default_ui.suffix

    if node.is_symlink then
        node_name = node_name .. " -> "

        if node.is_broken then
            node_name = node_name .. "×"
        else
            node_name = node_name .. path_escape(node.symlink.absolute_path)

            if node.symlink.is_dir then
                node_name = node_name .. "/"
            end
        end
    end

    -- STYLE
    local node_style = get_node_style(node)

    return node_style(node_icon .. " " .. node_name .. separator)
end

local function preview_dir(dir, ctx, args)
    local subnodes = {}

    local ok, nodes = pcall(xplr.util.explore, dir.absolute_path, ctx.app.explorer_config)

    if not ok then
        nodes = {}
    end

    for i, node in ipairs(nodes) do
        if i > ctx.layout_size.height + 1 then
            break
        else
            table.insert(subnodes, format(node))
        end
    end

    return subnodes
end

local function preview_file(file, ctx, args)
    local preview = {}

    if args.highlight.enable then
        preview = xplr.util.shell_execute(
            "highlight",
            {
                "--out-format=" .. (args.highlight.method or "ansi"),
                "--line-range=1-" .. ctx.layout_size.height,
                "--style=" .. (args.highlight.style or "night"),
                file.absolute_path
            }
        )
    else
        preview = xplr.util.shell_execute(
            "head",
            { "-" .. ctx.layout_size.height, file.absolute_path }
        )
    end

    if preview == {} or preview.returncode == 1 then
        return stats(file)
    else
        return preview.stdout
    end
end

local function setup(args)
    args = args or {}

    xplr.fn.custom.preview_pane = { render = function(ctx)
        local node = ctx.app.focused_node

        if node then
            if node.is_file then
                return preview_file(node, ctx, args)
            elseif node.is_dir then
                local subnodes = preview_dir(node, ctx, args)
                return table.concat(subnodes, "\n")
            else
                return stats(node)
            end
        else
            return ""
        end
    end }

    local preview_pane = {
        CustomContent = {
            title = "Preview",
            body = { DynamicParagraph = { render = "custom.preview_pane.render" } },
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
                                args.left_pane_width or { Percentage = 55 },
                                args.right_pane_width or { Percentage = 45 },
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

        xplr.config.modes.builtin.switch_layout.key_bindings.on_key[args.keybind or "P"] = {
            help = "preview",
            messages = {
                "PopMode",
                { SwitchLayoutCustom = "preview" },
            },
        }
    end
end

return { setup = setup }
