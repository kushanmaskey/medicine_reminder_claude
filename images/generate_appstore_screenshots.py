from PIL import Image, ImageDraw
import os

SCRIPT_DIR = os.path.dirname(__file__)
APP_DIR = os.path.join(SCRIPT_DIR, "application images")
OUT_DIR = os.path.join(SCRIPT_DIR, "application images", "appstore")

BG_COLOR = (74, 20, 20)
ACCENT   = (180, 80, 60)

os.makedirs(OUT_DIR, exist_ok=True)

SIZES = {
    "iphone_65": (1242, 2688),   # 6.5-inch iPhone
    "ipad_13":   (2048, 2732),   # 13-inch iPad
}

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

def fit_image(img, target_w, target_h):
    src_w, src_h = img.size
    scale = min(target_w / src_w, target_h / src_h)
    new_w = int(src_w * scale)
    new_h = int(src_h * scale)
    img = img.resize((new_w, new_h), Image.LANCZOS)
    canvas = gradient_bg(target_w, target_h)
    x = (target_w - new_w) // 2
    y = (target_h - new_h) // 2
    if img.mode == "RGBA":
        canvas.paste(img, (x, y), img)
    else:
        canvas.paste(img, (x, y))
    return canvas

def make_ipad(left_file, right_file, target_w, target_h):
    canvas = gradient_bg(target_w, target_h)
    draw = ImageDraw.Draw(canvas)
    draw.rectangle([(0, 0), (target_w, 4)], fill=ACCENT)

    padding = 60
    gap     = 30
    screen_w = (target_w - padding * 2 - gap) // 2
    scale    = screen_w / 640
    screen_h = min(int(1500 * scale), target_h - padding * 2)
    y = (target_h - screen_h) // 2

    for i, fname in enumerate([left_file, right_file]):
        path = os.path.join(APP_DIR, fname)
        if not os.path.exists(path):
            files = [f for f in os.listdir(APP_DIR) if f.endswith(".png") and "appstore" not in f]
            path = os.path.join(APP_DIR, sorted(files)[i % len(files)])
        img = Image.open(path).convert("RGBA")
        img = img.resize((screen_w, screen_h), Image.LANCZOS)
        x = padding + i * (screen_w + gap)
        canvas.paste(img, (x, y), img)

    mid_x = padding + screen_w + gap // 2
    draw.line([(mid_x, padding + 40), (mid_x, target_h - padding - 40)], fill=ACCENT, width=1)
    return canvas

screens = sorted([f for f in os.listdir(APP_DIR) if f.endswith(".png") and "appstore" not in f and "tablet" not in f])

# iPhone 6.5-inch — one screenshot per file
iw, ih = SIZES["iphone_65"]
for fname in screens:
    path = os.path.join(APP_DIR, fname)
    img = Image.open(path).convert("RGB")
    out = fit_image(img, iw, ih)
    out_path = os.path.join(OUT_DIR, f"iphone65_{fname}")
    out.convert("RGB").save(out_path, "PNG")
    print(f"Saved iPhone: {out_path}")

# iPad 13-inch — pairs of screenshots side by side
pw, ph = SIZES["ipad_13"]
pairs = [(screens[i], screens[i+1]) for i in range(0, len(screens)-1, 2)]
if len(screens) % 2 != 0:
    pairs.append((screens[-1], screens[0]))

for i, (left, right) in enumerate(pairs):
    out = make_ipad(left, right, pw, ph)
    out_path = os.path.join(OUT_DIR, f"ipad13_pair{i+1}.png")
    out.convert("RGB").save(out_path, "PNG")
    print(f"Saved iPad: {out_path}")

print(f"\nDone. Files saved to: {OUT_DIR}")
