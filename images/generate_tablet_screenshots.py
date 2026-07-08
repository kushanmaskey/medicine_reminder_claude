from PIL import Image, ImageDraw, ImageFont
import os

SCRIPT_DIR = os.path.dirname(__file__)
APP_DIR = os.path.join(SCRIPT_DIR, "application images")
OUT_DIR = os.path.join(SCRIPT_DIR, "application images")

BG_COLOR  = (74, 20, 20)
ACCENT    = (180, 80, 60)
PADDING   = 40
GAP       = 24

TABLETS = [
    {"name": "tablet_7inch_1280x720.png",   "w": 1280, "h": 720},
    {"name": "tablet_10inch_1920x1080.png", "w": 1920, "h": 1080},
]

PAIRS = [
    ("summary_screen.png",      "medications_screen.png"),
    ("appointments_screen.png", "vitals_screen.png"),
]

def gradient_bg(w, h):
    img = Image.new("RGB", (w, h), BG_COLOR)
    for x in range(w):
        t = x / w
        r = int(74 + 20 * t)
        g = int(20 + 5  * t)
        b = int(20 + 5  * t)
        for y in range(h):
            img.putpixel((x, y), (r, g, b))
    return img

def load_screen(filename):
    path = os.path.join(APP_DIR, filename)
    if not os.path.exists(path):
        # fall back to any available screen
        files = [f for f in os.listdir(APP_DIR) if f.endswith(".png")]
        path = os.path.join(APP_DIR, files[0]) if files else None
    return Image.open(path).convert("RGBA") if path else None

def add_screen_shadow(img, radius=8):
    shadow = Image.new("RGBA", (img.width + radius*2, img.height + radius*2), (0, 0, 0, 0))
    shadow_bg = Image.new("RGBA", img.size, (0, 0, 0, 120))
    shadow.paste(shadow_bg, (radius, radius))
    shadow.paste(img, (0, 0), img)
    return shadow

def make_tablet(canvas_w, canvas_h, left_file, right_file, out_name):
    canvas = gradient_bg(canvas_w, canvas_h)
    draw = ImageDraw.Draw(canvas)

    # Decorative accent line at top
    draw.rectangle([(0, 0), (canvas_w, 4)], fill=ACCENT)

    usable_h = canvas_h - PADDING * 2
    usable_w = canvas_w - PADDING * 2 - GAP
    screen_w = usable_w // 2
    scale    = screen_w / 640
    screen_h = min(int(1500 * scale), usable_h)

    y = (canvas_h - screen_h) // 2

    for i, fname in enumerate([left_file, right_file]):
        img = load_screen(fname)
        if img is None:
            continue
        img = img.resize((screen_w, screen_h), Image.LANCZOS)
        img = add_screen_shadow(img)
        x = PADDING + i * (screen_w + GAP) - (8 if i == 0 else 0)
        canvas.paste(img, (x, y - 8), img)

    # Subtle divider between screens
    mid_x = PADDING + screen_w + GAP // 2
    draw.line([(mid_x, PADDING + 20), (mid_x, canvas_h - PADDING - 20)], fill=ACCENT, width=1)

    out_path = os.path.join(OUT_DIR, out_name)
    canvas.convert("RGB").save(out_path, "PNG")
    print(f"Saved: {out_path}  ({canvas_w}x{canvas_h})")

if __name__ == "__main__":
    screens = [f for f in os.listdir(APP_DIR) if f.endswith(".png")]
    screens.sort()

    # Pick two screens for each tablet (use what's available)
    left  = screens[6] if len(screens) > 6 else screens[0]   # summary_screen
    right = screens[0] if len(screens) > 1 else screens[0]   # activities_screen

    for tablet in TABLETS:
        make_tablet(tablet["w"], tablet["h"], left, right, tablet["name"])

    print("Done.")
