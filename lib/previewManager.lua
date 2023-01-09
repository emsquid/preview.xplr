---@diagnostic disable
local xplr = xplr
---@diagnostic enable
local helper = require("preview.lib.helper")

local previewManager = {
    -- current instance being previewed
    current = {},
    -- all instances of known nodes
    instances = {},
    -- loading functions
    loader = {},
    -- id to keep tracks of images
    next_image_id = 1,
}

function previewManager.loader.text(file, ctx, args)
    local preview = ""

    if args.text.highlight.enable then
        local highlight_args = {
            file.absolute_path,
            "--out-format=" .. args.text.highlight.method,
            "--line-range=" .. 1 .. "-" .. ctx.layout_size.height - 2,
        }

        if args.text.highlight.style then
            table.insert(highlight_args, "--style=" .. args.text.highlight.style)
        end

        local result = xplr.util.shell_execute("highlight", highlight_args)
        preview = (result.returncode == 0 and result.stdout) or helper.stats(file, args)
    else
        local result = xplr.util.shell_execute(
            "head",
            { "-" .. ctx.layout_size.height - 2, file.absolute_path }
        )
        preview = (result.returncode == 0 and result.stdout) or helper.stats(file, args)
    end

    previewManager.save_preview(preview, file, ctx)
end

function previewManager.loader.image(image, ctx, args)
    local path = image.absolute_path
    local width, height = ctx.layout_size.width - 2, ctx.layout_size.height - 2

    local preview = ""

    if args.image.method == "kitty" then
        local id = previewManager.next_image_id
        local command = string.format("load %s %d %d %d", helper.escape_space(path), id, width, height)
        local success = helper.handle_batch_commands({ command }, false)

        preview = (success and "") or helper.stats(image, args)
    elseif args.image.method == "viu" then
        local result = xplr.util.shell_execute(
            "viu",
            { "--blocks", "--static", "--width", width, path }
        )

        preview = (result.returncode == 0 and result.stdout) or helper.stats(image, args)
    else
        preview = helper.stats(image, args)
    end

    previewManager.save_preview(preview, image, ctx)
end

function previewManager.loader.directory(directory, ctx, args)
    local preview = ""

    local ok, nodes = pcall(xplr.util.explore, directory.absolute_path, ctx.app.explorer_config)
    if ok then
        -- local batch = {}

        for i, node in pairs(nodes) do
            if i > ctx.layout_size.height - 2 then
                break
            else
                -- if helper.type(node) == "image" and args.image.method == "kitty" then
                -- local path = node.absolute_path
                -- local id = previewManager.next_image_id
                -- local width, height = ctx.layout_size.width - 2, ctx.layout_size.height - 2
                -- local command = string.format("load %s %d %d %d", helper.escape_space(path), id, width, height)
                --
                -- table.insert(batch, command)
                -- previewManager.save_preview("", node, ctx)
                -- end

                preview = preview .. helper.format(node, args) .. "\n"
            end
        end

        -- helper.handle_batch_commands(batch, true)
    else
        preview = helper.stats(directory, args)
    end

    previewManager.save_preview(preview, directory, ctx)
end

function previewManager.loader.other(node, ctx, args)
    local preview = helper.stats(node, args)
    previewManager.save_preview(preview, node, ctx)
end

function previewManager.save_preview(preview, node, ctx)
    local type = helper.type(node)
    local path = node.absolute_path
    -- basic instance
    previewManager.instances[path] = {
        preview = preview,
        type = type,
        width = ctx.layout_size.width,
        height = ctx.layout_size.height,
        timestamp = node.last_modified
    }
    -- add needed data
    if type == "text" then
        -- TODO: add text relative position to move in the preview
    elseif type == "image" then
        previewManager.instances[path].id = previewManager.next_image_id
        previewManager.next_image_id = previewManager.next_image_id + 1
    end
end

function previewManager.should_reload_preview(node, ctx)
    local instance = previewManager.instances[node.absolute_path]
    return (instance == nil
        or instance.width ~= ctx.layout_size.width
        or instance.height ~= ctx.layout_size.height
        or instance.timestamp < node.last_modified)
end

function previewManager.preview(node, ctx, args)
    local path = node.absolute_path
    local instance = previewManager.instances[path]

    if args.image.method == "kitty" and path ~= previewManager.current.path then
        if instance.type == "image" then
            local x, y = ctx.layout_size.x + 1, ctx.layout_size.y + 1
            local command = string.format("display %d %d %d", instance.id, x, y)
            helper.handle_batch_commands({ command }, false)
        elseif previewManager.current.type == "image" then
            helper.handle_batch_commands({ "clear" }, false)
        end
    end

    previewManager.current = instance
end

function previewManager.handle(node, ctx, args)
    if previewManager.should_reload_preview(node, ctx) then
        previewManager.loader[helper.type(node)](node, ctx, args)
    end

    previewManager.preview(node, ctx, args)

    return previewManager.current.preview
end

return previewManager
