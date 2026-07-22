from PIL import Image, ImageDraw
import math

SIZE = 1024

# ── Background gradient ───────────────────────────────────────────────────
# Change these two colours to adjust the background
TOP_COLOR    = (255, 107, 107)   # coral   #FF6B6B
BOTTOM_COLOR = (255, 140,  66)   # orange  #FF8C42

img = Image.new('RGB', (SIZE, SIZE))
draw = ImageDraw.Draw(img)
for y in range(SIZE):
    t = y / (SIZE - 1)
    draw.line(
        [(0, y), (SIZE - 1, y)],
        fill=(
            int(TOP_COLOR[0] + (BOTTOM_COLOR[0] - TOP_COLOR[0]) * t),
            int(TOP_COLOR[1] + (BOTTOM_COLOR[1] - TOP_COLOR[1]) * t),
            int(TOP_COLOR[2] + (BOTTOM_COLOR[2] - TOP_COLOR[2]) * t),
        ),
    )

# ── Icon rounded-corner mask ──────────────────────────────────────────────
CORNER_RADIUS = 220   # increase = more rounded, decrease = more square
mask = Image.new('L', (SIZE, SIZE), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=CORNER_RADIUS, fill=255)

img_rgba = img.convert('RGBA')
overlay  = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
od       = ImageDraw.Draw(overlay)

WHITE = (255, 255, 255, 255)

# ── Heart ─────────────────────────────────────────────────────────────────
HEART_CX    = SIZE // 2                              # horizontal centre
HEART_CY    = SIZE // 2                              # vertical centre of icon
HEART_SCALE = 285                                    # size of heart — increase to make bigger

heart_pts = []
for i in range(600):
    t = 2 * math.pi * i / 600
    hx = 16 * math.sin(t) ** 3
    hy = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
    heart_pts.append((HEART_CX + hx * HEART_SCALE / 16, HEART_CY + hy * HEART_SCALE / 16))
od.polygon(heart_pts, fill=WHITE)

# ── ECG / pulse line ──────────────────────────────────────────────────────
ECG_COLOR = (180, 60, 30, 230)   # colour of the pulse line
ECG_WIDTH = 13                    # thickness of the pulse line
ly = HEART_CY + 54               # vertical position of the baseline

pts = [
    (HEART_CX - 265, ly), (HEART_CX - 155, ly),
    (HEART_CX - 126, ly - 25),
    (HEART_CX -  98, ly),
    (HEART_CX -  62, ly),
    (HEART_CX -  36, ly + 40),
    (HEART_CX +   0, ly - 148),  # tall spike — change ly-148 to adjust spike height
    (HEART_CX +  38, ly + 32),
    (HEART_CX +  72, ly),
    (HEART_CX + 104, ly - 48),
    (HEART_CX + 142, ly),
    (HEART_CX + 265, ly),
]
ecg_draw = ImageDraw.Draw(overlay)
for i in range(len(pts) - 1):
    ecg_draw.line([pts[i], pts[i + 1]], fill=ECG_COLOR, width=ECG_WIDTH)

# ── Composite layers & apply rounded mask ─────────────────────────────────
img_rgba.alpha_composite(overlay)
r, g, b, a = img_rgba.split()
a = Image.composite(a, Image.new('L', (SIZE, SIZE), 0), mask)
result = Image.merge('RGBA', (r, g, b, a))

# ── Save ──────────────────────────────────────────────────────────────────
OUT = 'assets/icons/app_icon.png'
result.save(OUT)
print(f'Icon saved → {OUT}')
