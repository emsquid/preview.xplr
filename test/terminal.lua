local ffi = require("ffi")
local base64 = require("preview.test.base64")

local terminal = {}

function terminal.get_cell_size()
    ffi.cdef [[
        int ioctl(int __fd, unsigned long int __request, ...);

        typedef struct winsize {
            unsigned short rows;
            unsigned short cols;
            unsigned short xpixel;
            unsigned short ypixel;
        };
    ]]

    local handle = assert(io.popen("uname"))
    local ostype = handle:read("*a")
    handle:close()

    local TIOCGWINSZ = nil
    if ostype:match("Linux") then
        TIOCGWINSZ = 0x5413
    elseif ostype:match("Darwin") then
        TIOCGWINSZ = 0x40087468
    end

    local ws = ffi.new('struct winsize')
    ffi.C.ioctl(0, TIOCGWINSZ, ws)
    ---@diagnostic disable
    local screen_size_x = ws.xpixel
    local screen_size_y = ws.ypixel
    local screen_size_cols = ws.cols
    local screen_size_rows = ws.rows

    return { x = ws.xpixel / ws.cols, y = ws.ypixel / ws.rows }
    ---@diagnostic enable
end

function terminal.write(str)
    print(str)
end

function terminal.restore_cursor()
    terminal.write("\x1b[u")
end

function terminal.move_cursor(x, y)
    terminal.write("\x1b[s")
    terminal.write("\x1b[" .. y .. ":" .. x .. "H")
end

function terminal.get_chunked(str)
    local chunks = {}
    for i = 1, #str, 4096 do
        local chunk = str:sub(i, i + 4096 - 1):gsub("%s", "")
        if #chunk > 0 then
            table.insert(chunks, chunk)
        end
    end
    return chunks
end

function terminal.send_graphics_command(keys, payload)
    local cmd = ""
    for k, v in pairs(keys) do
        if v ~= nil then
            cmd = cmd .. k .. "=" .. v .. ","
        end
    end

    if payload then
        payload = base64.encode(payload)
        local chunks = terminal.get_chunked(payload)
        for i = 1, #chunks do
            cmd = (i == #chunks and cmd .. "m=0") or cmd .. "m=1"
            terminal.write("\x1b_G" .. cmd .. ";" .. chunks[i] .. "\x1b\\")
        end
    else
        cmd = cmd .. "m=0"
        terminal.write("\x1b_G" .. cmd .. "\x1b\\")
    end
end

return terminal
