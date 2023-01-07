-- Prototype for an image displayer in lua with lua-vips
local terminal = require("preview.test.terminal")
local succes, vips = pcall(require, "vips")

local Image = {
    enabled = succes,
    instances = {},
    next_id = 1,
    cell_size = terminal.get_cell_size()
}

function Image.load(path, width, height)
    if not Image.enabled then return end

    local image = vips.Image.new_from_file(path)
    local img_width, img_height = image:size()
    local box_width, box_height = width * Image.cell_size.x, height * Image.cell_size.y

    if img_width > box_width or img_height > box_height then
        local scale = math.min(box_width / img_width, box_height / img_height)
        image = image:resize(scale)
    end

    local tmp_path = "/tmp/tty-graphics-protocol" .. Image.next_id .. ".png"
    image:write_to_file(tmp_path)

    local keys = { a = "t", t = "f", f = 100, i = Image.next_id, q = 2 }
    terminal.send_graphics_command(keys, tmp_path)

    Image.instances[path] = {
        id = Image.next_id,
        width = width,
        height = height,
    }

    Image.next_id = Image.next_id + 1

    return Image.instances[path]
end

function Image.display(path, x, y, width, height)
    if not Image.enabled then return end

    local image = Image.instances[path]
    if image == nil or image.width ~= width or image.height ~= height then
        image = Image.load(path, width, height)
    end

    local keys = { a = "p", i = (image and image.id), q = 2, C = 1 }
    terminal.move_cursor(x + 1, y)
    terminal.send_graphics_command(keys)
    terminal.restore_cursor()

    return true
end

function Image.clear(id)
    if not Image.enabled then return end

    local keys = { a = "d", d = "i", i = id }
    terminal.send_graphics_command(keys)
end

return Image
