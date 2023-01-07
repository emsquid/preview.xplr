---@diagnostic disable
local xplr = xplr
---@diagnostic enable
local helper = require("preview.lib.helper")

-- TODO: add last_modified criteria to `should_reload_preview`
local previewManager = {
    current = {
        type = nil,
        path = nil
    },
    text = { instances = {} },
    image = {
        instances = {},
        next_id = 1,
    },
    directory = { instances = {} },
    other = { instances = {} },
}

function previewManager.text.save_preview(preview, file, ctx)
    previewManager.text.instances[file.absolute_path] = {
        preview = preview,
        width = ctx.layout_size.width,
        height = ctx.layout_size.height,
        -- TODO: allow moving in text preview with a special mode
        -- x = 0,
        -- y = 0
    }
end

function previewManager.text.should_reload_preview(file, ctx)
    local preview = previewManager.text.instances[file.absolute_path]
    return preview == nil or preview.width ~= ctx.layout_size.width or preview.height ~= ctx.layout_size.height
end

function previewManager.text.preview(file, ctx, args)
    if not previewManager.text.should_reload_preview(file, ctx) then
        return previewManager.text.instances[file.absolute_path].preview
    end

    local preview = ""
    if args.text.highlight.enable then
        local result = xplr.util.shell_execute(
            "highlight",
            {
                "--out-format=" .. (args.text.highlight.method or "ansi"),
                "--line-range=1-" .. ctx.layout_size.height - 2,
                "--style=" .. (args.text.highlight.style or "night"),
                file.absolute_path,
            }
        )
        preview = (result.returncode == 0 and result.stdout) or helper.stats(file, args)
    else
        local result = xplr.util.shell_execute(
            "head",
            { "-" .. ctx.layout_size.height - 2, file.absolute_path }
        )
        preview = (result.returncode == 0 and result.stdout) or helper.stats(file, args)
    end
    previewManager.text.save_preview(preview, file, ctx)

    return preview
end

function previewManager.image.save_preview(preview, image, ctx)
    previewManager.image.instances[image.absolute_path] = {
        id = previewManager.image.next_id,
        preview = preview,
        width = ctx.layout_size.width,
        height = ctx.layout_size.height,
    }
    previewManager.image.next_id = previewManager.image.next_id + 1
end

function previewManager.image.should_reload_preview(image, ctx)
    local preview = previewManager.image.instances[image.absolute_path]
    return preview == nil or preview.width ~= ctx.layout_size.width or preview.height ~= ctx.layout_size.height
end

function previewManager.image.preview(image, ctx, args)
    local x, y = ctx.layout_size.x + 1, ctx.layout_size.y + 1
    local width, height = ctx.layout_size.width - 2, ctx.layout_size.height - 2

    if not previewManager.image.should_reload_preview(image, ctx) then
        local instance = previewManager.image.instances[image.absolute_path]
        if args.image.method == "kitty" then
            helper.display_image(instance.id, x, y)
        end
        return instance.preview
    end

    local preview = ""
    if args.image.method == "kitty" then
        local id = previewManager.image.next_id
        local success = helper.load_image(image, id, width, height) and helper.display_image(id, x, y)
        preview = (success and "") or helper.stats(image, args)
    elseif args.image.method == "viu" then
        local result = xplr.util.shell_execute(
            "viu",
            { "--blocks", "--static", "--width", ctx.layout_size.width - 2, image.absolute_path }
        )
        preview = (result.returncode == 0 and result.stdout) or helper.stats(image, args)
    else
        preview = helper.stats(image, args)
    end
    previewManager.image.save_preview(preview, image, ctx)

    return preview
end

function previewManager.image.clear()
    helper.clear_image()
end

function previewManager.directory.save_preview(preview, directory, ctx)
    previewManager.directory.instances[directory.absolute_path] = {
        preview = preview,
        width = ctx.layout_size.width,
        height = ctx.layout_size.height,
    }
end

function previewManager.directory.should_reload_preview(directory, ctx)
    local preview = previewManager.directory.instances[directory.absolute_path]
    return preview == nil or preview.width ~= ctx.layout_size.width or preview.height ~= ctx.layout_size.height
end

function previewManager.directory.preview(directory, ctx, args)
    if not previewManager.directory.should_reload_preview(directory, ctx) then
        return previewManager.directory.instances[directory.absolute_path].preview
    end

    local preview = ""
    local ok, nodes = pcall(xplr.util.explore, directory.absolute_path, ctx.app.explorer_config)
    if ok then
        for i, node in ipairs(nodes) do
            if i > ctx.layout_size.height - 2 then
                break
            else
                preview = preview .. helper.format(node, args) .. "\n"
            end
        end
    else
        preview = helper.stats(directory, args)
    end
    previewManager.directory.save_preview(preview, directory, ctx)

    return preview
end

function previewManager.other.save_preview(preview, other, ctx)
    previewManager.other.instances[other.absolute_path] = {
        preview = preview,
        width = ctx.layout_size.width,
        height = ctx.layout_size.height,
    }
end

function previewManager.other.should_reload_preview(other, ctx)
    local preview = previewManager.other.instances[other.absolute_path]
    return preview == nil or preview.width ~= ctx.layout_size.width or preview.height ~= ctx.layout_size.height
end

function previewManager.other.preview(node, ctx, args)
    if not previewManager.other.should_reload_preview(node, ctx) then
        return previewManager.other.instances[node.absolute_path].preview
    end

    local preview = helper.stats(node, args)
    previewManager.other.save_preview(preview, node, ctx)

    return preview
end

function previewManager.handle(node, ctx, args)
    if previewManager.current.type == "image" and node.absolute_path ~= previewManager.current.path then
        previewManager.image.clear()
    end

    local preview = ""
    local type = "other"
    local path = node.absolute_path

    if node.is_file then
        local mime = helper.mime_type(node)
        if args.text.enable and (mime:match("text") or mime:match("json")) then
            preview = previewManager.text.preview(node, ctx, args)
            type = "text"
        elseif args.image.enable and (mime:match("image") or mime:match("video")) then
            preview = previewManager.image.preview(node, ctx, args)
            type = "image"
        else
            preview = previewManager.other.preview(node, ctx, args)
        end
    elseif args.directory.enable and node.is_dir then
        preview = previewManager.directory.preview(node, ctx, args)
        type = "directory"
    else
        preview = previewManager.other.preview(node, ctx, args)
    end

    previewManager.current = { type = type, path = path }

    return preview
end

return previewManager
