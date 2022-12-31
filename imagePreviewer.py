# CREDITS: RANGER
import os
import sys
import fcntl
import codecs
import struct
import termios
import warnings
import base64
import curses
from tempfile import NamedTemporaryFile
from contextlib import contextmanager


def move_cursor(to_y, to_x):
    tparm = curses.tparm(curses.tigetstr("cup"), to_y, to_x)
    bin_stdout = getattr(sys.stdout, "buffer", sys.stdout)
    bin_stdout.write(tparm)


@contextmanager
def temporarily_moved_cursor(to_y, to_x):
    curses.setupterm()
    curses.putp(curses.tigetstr("sc"))
    move_cursor(to_y, to_x)
    yield
    curses.putp(curses.tigetstr("rc"))
    sys.stdout.flush()


class KittyImageDisplayer(object):
    """Implementation of ImageDisplayer for kitty (https://github.com/kovidgoyal/kitty/)
    terminal. It uses the built APC to send commands and data to kitty,
    which in turn renders the image. The APC takes the form
    '\033_Gk=v,k=v...;bbbbbbbbbbbbbb\033\\'
       |   ---------- --------------  |
    escape code  |             |    escape code
                 |  base64 encoded payload
        key: value pairs as parameters"""

    def __init__(self):
        if "kitty" not in os.environ["TERM"]:
            print("Kitty is required to preview images")
            exit()

        self.protocol_start = b"\x1b_G"
        self.protocol_end = b"\x1b\\"

        self.stdbout = getattr(sys.stdout, "buffer", sys.stdout)
        self.stdbin = getattr(sys.stdin, "buffer", sys.stdin)

    def draw_init(self):
        try:
            self.fs_enc = sys.getfilesystemencoding()
            codecs.lookup(self.fs_enc)
        except (LookupError, TypeError):
            self.fs_enc = "utf-8"

        try:
            import PIL.Image

            self.backend = PIL.Image
        except ImportError:
            print("PIL is required to preview images")
            exit()

        ret = fcntl.ioctl(
            sys.stdout, termios.TIOCGWINSZ, struct.pack("HHHH", 0, 0, 0, 0)
        )
        n_cols, n_rows, x_px_tot, y_px_tot = struct.unpack("HHHH", ret)

        self.pix_row, self.pix_col = x_px_tot // n_rows, y_px_tot // n_cols

    def serialize_cmd(self, cmd, payload=None, max_slice_len=4096):
        cmd = ",".join(f"{k}={v}" for k, v in cmd.items()).encode("ascii")

        if payload is not None:
            while len(payload) > max_slice_len:
                chunk, payload = payload[:max_slice_len], payload[max_slice_len:]
                yield self.protocol_start + cmd + b",m=1;" + chunk + self.protocol_end
            yield self.protocol_start + cmd + b",m=0;" + payload + self.protocol_end
        else:
            yield self.protocol_start + cmd + b";" + self.protocol_end

    def draw(self, path, x, y, width, height):
        self.draw_init()

        cmd = {"a": "T", "t": "t", "f": 100}

        with warnings.catch_warnings(record=True):
            warnings.simplefilter("ignore", self.backend.DecompressionBombWarning)
            image = self.backend.open(path)

        size = (int(width) * self.pix_row, int(height) * self.pix_col)

        if image.width > size[0] or image.height > size[1]:
            scale = min(size[0] / image.width, size[1] / image.height)
            image = image.resize(
                (int(scale * image.width), int(scale * image.height)),
                self.backend.Resampling.LANCZOS,
            )

        if image.mode not in ("RGB", "RGBA"):
            image = image.convert("RGB")

        # background to hide what may be behind the preview before it disappears
        # background = self.backend.new("RGBA", size, (0, 0, 0))
        # background.paste(image)

        with NamedTemporaryFile(prefix="preview", suffix=".png", delete=False) as tmpf:
            image.save(tmpf, format="png", compress_level=0)
            payload = base64.standard_b64encode(tmpf.name.encode(self.fs_enc))

        with temporarily_moved_cursor(int(y), int(x)):
            for cmd_str in self.serialize_cmd(cmd, payload=payload):
                self.stdbout.write(cmd_str)

    def clear(self):
        cmds = {"a": "d"}

        for cmd_str in self.serialize_cmd(cmds):
            self.stdbout.write(cmd_str)


args = sys.argv
displayer = KittyImageDisplayer()

if args[1] == "clear":
    displayer.clear()
else:
    displayer.draw(args[5], args[1], args[2], args[3], args[4])
