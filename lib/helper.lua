---@diagnostic disable
local xplr = xplr
---@diagnostic enable
local home = os.getenv("HOME") or "~"
local ok, style_module = pcall(require, "style")
local style = (ok and style_module.style) or {}
local separator = (ok and style_module.separator) or ""
local get_node_style = (ok and style_module.get_node_style) or {}

local helper = {}

function helper.split(str, sep)
    if sep == nil then
        sep = "%s"
    end

    local t = {}
    for m in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(t, m)
    end
    return t
end

function helper.table_match(a, b)
    return table.concat(a) == table.concat(b)
end

function helper.datetime(num)
    return tostring(os.date("%a %b %d %H:%M:%S %Y", num / 1000000000))
end

function helper.escape(path)
    return string.gsub(string.gsub(path, "\\", "\\\\"), "\n", "\\n")
end

function helper.bit(text, color, cond)
    return (cond and color(text)) or color("-")
end

function helper.mime_type(node)
    return xplr.util.shell_execute(
        "file",
        {
            "--brief",
            "--mime-type",
            node.absolute_path
        }
    ).stdout:sub(1, -2)
end

function helper.permissions(perm, args)
    local function red(text)
        return (ok and args.style and style.fg.Red(text)) or text
    end

    local function green(text)
        return (ok and args.style and style.fg.Green(text)) or text
    end

    local function yellow(text)
        return (ok and args.style and style.fg.Yellow(text)) or text
    end

    local result = ""

    result = result .. helper.bit("r", green, perm.user_read)
    result = result .. helper.bit("w", yellow, perm.user_write)

    if perm.user_execute == false and perm.setuid == false then
        result = result .. helper.bit("-", red, perm.user_execute)
    elseif perm.user_execute == true and perm.setuid == false then
        result = result .. helper.bit("x", red, perm.user_execute)
    elseif perm.user_execute == false and perm.setuid == true then
        result = result .. helper.bit("S", red, perm.user_execute)
    else
        result = result .. helper.bit("s", red, perm.user_execute)
    end

    result = result .. helper.bit("r", green, perm.group_read)
    result = result .. helper.bit("w", yellow, perm.group_write)

    if perm.group_execute == false and perm.setuid == false then
        result = result .. helper.bit("-", red, perm.group_execute)
    elseif perm.group_execute == true and perm.setuid == false then
        result = result .. helper.bit("x", red, perm.group_execute)
    elseif perm.group_execute == false and perm.setuid == true then
        result = result .. helper.bit("S", red, perm.group_execute)
    else
        result = result .. helper.bit("s", red, perm.group_execute)
    end

    result = result .. helper.bit("r", green, perm.other_read)
    result = result .. helper.bit("w", yellow, perm.other_write)

    if perm.other_execute == false and perm.setuid == false then
        result = result .. helper.bit("-", red, perm.other_execute)
    elseif perm.other_execute == true and perm.setuid == false then
        result = result .. helper.bit("x", red, perm.other_execute)
    elseif perm.other_execute == false and perm.setuid == true then
        result = result .. helper.bit("T", red, perm.other_execute)
    else
        result = result .. helper.bit("t", red, perm.other_execute)
    end

    return (ok and args.style and style.add_modifiers.Bold(result) .. separator) or result
end

function helper.stats(node, args)
    local type = (node.mime_essence ~= "" and node.mime_essence) or helper.mime_type(node)

    if node.is_symlink then
        if node.is_broken then
            type = "broken symlink"
        else
            type = "symlink to: " .. node.symlink.absolute_path
        end
    end

    return helper.format(node, args)
        .. separator .. "\n"
        .. "Type     : "
        .. type .. "\n"
        .. "Size     : "
        .. node.human_size .. "\n"
        .. "Owner    : "
        .. node.uid .. ":" .. node.gid .. "\n"
        .. "Perm     : "
        .. helper.permissions(node.permissions, args) .. "\n"
        .. "Created  : "
        .. helper.datetime(node.created) .. "\n"
        .. "Modified : "
        .. helper.datetime(node.last_modified) .. "\n"
end

function helper.icon(node)
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
    local mime = helper.split(node.mime_essence, "/")
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

function helper.format(node, args)
    -- ICON
    local node_icon = helper.icon(node)

    -- NAME
    local node_name = helper.escape(node.relative_path)
    if node.is_dir then
        node_name = node_name .. "/"
    end

    node_name = node_name .. xplr.config.general.default_ui.suffix
    if node.is_symlink then
        node_name = node_name .. " -> "
        if node.is_broken then
            node_name = node_name .. "×"
        else
            node_name = node_name .. helper.escape(node.symlink.absolute_path)
            if node.symlink.is_dir then
                node_name = node_name .. "/"
            end
        end
    end

    -- STYLE
    local node_style = (ok and args.style and get_node_style(node)) or function(text) return text end
    return node_style(node_icon) .. node_style(" " .. node_name .. separator)
end

function helper.load_image(image, id, width, height)
    return os.execute(
        string.format(
            "python3 %s/.config/xplr/plugins/preview/lib/imageDisplayer.py load %s %d %d %d",
            home,
            image.absolute_path,
            id,
            width,
            height
        )
    ) == 0
end

function helper.display_image(id, x, y)
    return os.execute(
        string.format(
            "python3 %s/.config/xplr/plugins/preview/lib/imageDisplayer.py display %d %d %d",
            home,
            id,
            x,
            y
        )
    ) == 0
end

function helper.clear_image()
    return os.execute(
        string.format(
            "python3 %s/.config/xplr/plugins/preview/lib/imageDisplayer.py clear",
            home
        )
    ) == 0
end

return helper
