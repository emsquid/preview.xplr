import sys
import fcntl
import array
import base64
import termios
from contextlib import contextmanager

PROTOCOL_START = b"\x1b_G"
PROTOCOL_END = b"\x1b\\"
STDBOUT = getattr(sys.stdout, "buffer", sys.stdout)


@contextmanager
def temporarily_moved_cursor(x: int, y: int):
    STDBOUT.write(b"\x1b[s")
    STDBOUT.write(f"\x1b[{y+1}:{x+1}H".encode("ascii"))
    yield
    STDBOUT.write(b"\x1b[u")


def get_cell_size() -> tuple:
    buf = array.array("H", [0, 0, 0, 0])
    fcntl.ioctl(sys.stdout, termios.TIOCGWINSZ, buf)

    rows, cols, x_px_tot, y_px_tot = buf

    return x_px_tot // cols, y_px_tot // rows


def send_graphics_command(keys: dict, payload: str = "", size: int = 4096):
    data = base64.standard_b64encode(payload.encode("ascii"))
    cmd = (",".join(f"{k}={v}" for k, v in keys.items()) + ",").encode("ascii")

    for i in range(0, max(1, len(data)), size):
        cmd = cmd + (b"m=1;" if i + size < len(data) else b"m=0;")
        STDBOUT.write(PROTOCOL_START + cmd + data[i : i + size] + PROTOCOL_END)
        cmd = ""


def clear():
    keys = {"a": "d", "d": "a"}
    send_graphics_command(keys)


def load(path: str, id: int, width: int, height: int):
    try:
        from PIL import Image
    except ImportError:
        exit(1)

    image = Image.open(path)

    cell_width, cell_height = get_cell_size()
    box_size = (int(width) * cell_width, int(height) * cell_height)

    if image.width > box_size[0] or image.height > box_size[1]:
        scale = min(box_size[0] / image.width, box_size[1] / image.height)
        image = image.resize(
            (int(scale * image.width), int(scale * image.height)),
            Image.Resampling.LANCZOS,
        )

    image_name = f"/tmp/tty-graphics-protocol{id}.png"
    image.save(image_name, format="png", compress_level=0)

    keys = {"a": "t", "t": "t", "f": 100, "i": id, "q": 2}
    send_graphics_command(keys, image_name)


def display(id: int, x: int, y: int):
    keys = {"a": "p", "i": id, "q": 2}
    with temporarily_moved_cursor(x, y):
        clear()
        send_graphics_command(keys)


args = sys.argv[1:]
command = args[0]

if command == "load":
    path, id, width, height = args[1], args[2], int(args[3]), int(args[4])
    load(path, id, width, height)
elif command == "display":
    id, x, y = args[1], int(args[2]), int(args[3])
    display(id, x, y)
elif command == "clear":
    clear()
