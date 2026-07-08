from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1024, 500
bg_color = (74, 20, 20)

img = Image.new("RGB", (W, H), bg_color)
draw = ImageDraw.Draw(img)

# Subtle right-side lightening
for x in range(W):
    t = x / W
    r = int(74 + 20 * t)
    g = int(20 + 5 * t)
    b = int(20 + 5 * t)
    for y in range(H):
        img.putpixel((x, y), (r, g, b))

draw = ImageDraw.Draw(img)

# Load icon
icon_path = os.path.join(os.path.dirname(__file__), "ic_launcher_512x512.png")
icon = Image.open(icon_path).convert("RGBA")
icon_size = 340
icon = icon.resize((icon_size, icon_size), Image.LANCZOS)
icon_x = 90
icon_y = (H - icon_size) // 2
img.paste(icon, (icon_x, icon_y), icon)

# Divider line
line_x = icon_x + icon_size + 50
draw.line([(line_x, 80), (line_x, H - 80)], fill=(180, 80, 60), width=2)

# Text area
text_x = line_x + 40
try:
    font_title = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 54)
    font_tagline = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
    font_bullet = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 21)
except:
    font_title = ImageFont.load_default()
    font_tagline = font_title
    font_bullet = font_title

# App name
draw.text((text_x, 110), "My Medical Wallet", font=font_title, fill=(255, 235, 210))

# Tagline
draw.text((text_x, 180), "Your personal health companion", font=font_tagline, fill=(210, 160, 130))

# Separator
draw.line([(text_x, 225), (W - 60, 225)], fill=(120, 50, 40), width=1)

# Feature bullets with dot markers
bullets = [
    "Medication Reminders & Scheduling",
    "Vitals Tracking & Trends",
    "Biometric Security (Face ID / Fingerprint)",
    "Secure Cloud Sync",
]
dot_color = (220, 90, 70)
for i, bullet in enumerate(bullets):
    y = 248 + i * 44
    draw.ellipse([(text_x, y + 8), (text_x + 10, y + 18)], fill=dot_color)
    draw.text((text_x + 22, y), bullet, font=font_bullet, fill=(200, 170, 150))

out_path = os.path.join(os.path.dirname(__file__), "feature_graphic_1024x500.png")
img.save(out_path, "PNG")
print(f"Saved: {out_path}")
