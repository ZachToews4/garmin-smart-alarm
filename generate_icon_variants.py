#!/usr/bin/env python3
"""
Generate multiple launcher icon variants (70x70 px PNG each).
Also produces a side-by-side comparison sheet.
"""

from PIL import Image, ImageDraw
import math, os

SIZE = 70
HALF = SIZE // 2
OUT  = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    "resources", "drawables")

# ── Shared helpers ────────────────────────────────────────────────────────────

def new_canvas():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)

def rounded_bg(d, fill, radius=14):
    d.rounded_rectangle([0, 0, SIZE-1, SIZE-1], radius=radius, fill=fill)

def add_gloss(img):
    gl = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gl)
    gd.pieslice([8, 4, HALF+10, HALF], start=200, end=320,
                fill=(255, 255, 255, 35))
    return Image.alpha_composite(img, gl)

# ═══════════════════════════════════════════════════════════════════════════════
# V1 — Classic alarm clock  (original, refined)
# ═══════════════════════════════════════════════════════════════════════════════
def variant_classic():
    img, d = new_canvas()
    rounded_bg(d, (18, 42, 100))

    # Bell feet
    for bx in [HALF - 16, HALF + 16]:
        d.ellipse([bx-4, SIZE-16, bx+4, SIZE-8], fill=(255, 210, 0))
    d.rectangle([HALF-16, SIZE-14, HALF+16, SIZE-10], fill=(255, 210, 0))

    # Bell domes
    for bx in [HALF - 20, HALF + 20]:
        d.pieslice([bx-7, 8, bx+7, 22], start=180, end=0, fill=(255, 210, 0))
        d.ellipse([bx-2, 14, bx+2, 18], fill=(255,255,255))

    # Clock rim + face
    cx, cy, r = HALF, 38, 20
    d.ellipse([cx-r-2, cy-r-2, cx+r+2, cy+r+2], fill=(200, 220, 255))
    d.ellipse([cx-r,   cy-r,   cx+r,   cy+r],   fill=(255, 255, 255))

    # Tick marks
    for i in range(12):
        a = math.radians(i * 30 - 90)
        major = (i % 3 == 0)
        ri, ro = r - (4 if major else 2), r - 1
        d.line([(cx + ri*math.cos(a), cy + ri*math.sin(a)),
                (cx + ro*math.cos(a), cy + ro*math.sin(a))],
               fill=(100,120,160), width=2 if major else 1)

    # Hands (7:00)
    for angle, length, width in [
        (math.radians(7*30 - 90), r-8, 3),   # hour
        (math.radians(-90),        r-4, 2),   # minute
    ]:
        d.line([(cx, cy), (cx + length*math.cos(angle),
                           cy + length*math.sin(angle))],
               fill=(30,30,80), width=width)
    d.ellipse([cx-2, cy-2, cx+2, cy+2], fill=(30,30,80))

    return add_gloss(img)

# ═══════════════════════════════════════════════════════════════════════════════
# V2 — Flat minimal: bold bell on gradient
# ═══════════════════════════════════════════════════════════════════════════════
def variant_flat_bell():
    img, d = new_canvas()
    rounded_bg(d, (0, 120, 200))   # bright blue

    # Bell body (simple polygon)
    cx, top, bot = HALF, 14, 52
    bell_pts = [
        (cx,        top - 4),   # top knob
        (cx + 4,    top + 2),
        (cx + 20,   bot - 6),
        (cx + 20,   bot),
        (cx - 20,   bot),
        (cx - 20,   bot - 6),
        (cx - 4,    top + 2),
    ]
    d.polygon(bell_pts, fill=(255, 255, 255))

    # Clapper
    d.ellipse([cx-5, bot, cx+5, bot+10], fill=(255, 255, 255))

    # Top knob
    d.ellipse([cx-4, top-8, cx+4, top+0], fill=(255, 255, 255))

    # Alarm ripple lines (right side)
    for i, offset in enumerate([0, 6, 12]):
        alpha = 200 - i * 50
        r_out = 28 + offset
        r_in  = 24 + offset
        arc_img = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
        arc_d   = ImageDraw.Draw(arc_img)
        arc_d.arc([cx - r_out, HALF - r_out, cx + r_out, HALF + r_out],
                  start=-40, end=40, fill=(255, 255, 255, alpha), width=2)
        img = Image.alpha_composite(img, arc_img)
    d = ImageDraw.Draw(img)  # refresh after compositing

    return img

# ═══════════════════════════════════════════════════════════════════════════════
# V3 — Moon + clock: sleep-themed, dark purple
# ═══════════════════════════════════════════════════════════════════════════════
def variant_moon():
    img, d = new_canvas()
    rounded_bg(d, (35, 20, 75))   # deep purple

    # Crescent moon (top-right)
    mx, my = 50, 16
    d.ellipse([mx-10, my-10, mx+10, my+10], fill=(255, 210, 0))
    d.ellipse([mx-4,  my-10, mx+16, my+10], fill=(35, 20, 75))   # cut-out

    # Stars (small dots)
    for sx, sy in [(15, 12), (28, 8), (20, 20)]:
        d.ellipse([sx-1, sy-1, sx+1, sy+1], fill=(255,255,255,180))

    # Clock face (lower center)
    cx, cy, r = HALF, 44, 19
    d.ellipse([cx-r-2, cy-r-2, cx+r+2, cy+r+2], fill=(80, 60, 130))
    d.ellipse([cx-r,   cy-r,   cx+r,   cy+r],   fill=(245, 240, 255))

    # Tick marks (4 cardinal only)
    for i in [0, 3, 6, 9]:
        a = math.radians(i * 30 - 90)
        d.line([(cx + (r-1)*math.cos(a), cy + (r-1)*math.sin(a)),
                (cx + (r-4)*math.cos(a), cy + (r-4)*math.sin(a))],
               fill=(100, 80, 150), width=2)

    # Hands (7:00)
    for angle, length, width, color in [
        (math.radians(7*30 - 90), r-7, 3, (60,40,120)),
        (math.radians(-90),        r-3, 2, (60,40,120)),
    ]:
        d.line([(cx, cy), (cx + length*math.cos(angle),
                           cy + length*math.sin(angle))],
               fill=color, width=width)
    d.ellipse([cx-2, cy-2, cx+2, cy+2], fill=(60,40,120))

    # Alarm dot
    d.ellipse([cx+r-3, cy-3, cx+r+3, cy+3], fill=(255,80,80))

    return add_gloss(img)

# ═══════════════════════════════════════════════════════════════════════════════
# V4 — Vibration: watch face + wave lines, teal/dark
# ═══════════════════════════════════════════════════════════════════════════════
def variant_vibrate():
    img, d = new_canvas()
    rounded_bg(d, (10, 55, 55))   # dark teal

    cx, cy, r = HALF, HALF, 22

    # Vibration arcs (both sides)
    for side in [-1, 1]:
        for i, gap in enumerate([6, 12, 18]):
            alpha = 220 - i * 55
            arc_img = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
            arc_d   = ImageDraw.Draw(arc_img)
            arc_d.arc([cx - r - gap, cy - r - gap,
                       cx + r + gap, cy + r + gap],
                      start=side * 60 - 30,
                      end=side * 60 + 30,
                      fill=(0, 220, 180, alpha), width=2)
            img = Image.alpha_composite(img, arc_img)
    d = ImageDraw.Draw(img)

    # Clock rim + face
    d.ellipse([cx-r-2, cy-r-2, cx+r+2, cy+r+2], fill=(0, 180, 150))
    d.ellipse([cx-r,   cy-r,   cx+r,   cy+r],   fill=(240, 255, 252))

    # Tick marks
    for i in range(12):
        a = math.radians(i * 30 - 90)
        major = (i % 3 == 0)
        ri, ro = r-(4 if major else 2), r-1
        d.line([(cx + ri*math.cos(a), cy + ri*math.sin(a)),
                (cx + ro*math.cos(a), cy + ro*math.sin(a))],
               fill=(0,120,100), width=2 if major else 1)

    # Hands (7:00)
    for angle, length, width in [
        (math.radians(7*30 - 90), r-8, 3),
        (math.radians(-90),        r-4, 2),
    ]:
        d.line([(cx, cy), (cx + length*math.cos(angle),
                           cy + length*math.sin(angle))],
               fill=(0, 60, 50), width=width)
    d.ellipse([cx-2, cy-2, cx+2, cy+2], fill=(0,60,50))

    return img

# ═══════════════════════════════════════════════════════════════════════════════
# V5 — Sunrise: warm gradient bg, sun + clock
# ═══════════════════════════════════════════════════════════════════════════════
def variant_sunrise():
    img, d = new_canvas()

    # Warm gradient bg (faked with stacked rectangles)
    rounded_bg(d, (30, 15, 60))   # dark base
    for i in range(35):
        frac  = i / 34
        r_c   = int(30  + frac * 170)
        g_c   = int(15  + frac * 60)
        b_c   = int(60  - frac * 40)
        y_top = SIZE - 1 - i
        d.line([(0, y_top), (SIZE-1, y_top)], fill=(r_c, g_c, b_c, 120))

    # Sun rising (bottom center, half visible)
    sun_cx, sun_cy, sun_r = HALF, SIZE - 4, 14
    d.ellipse([sun_cx - sun_r, sun_cy - sun_r,
               sun_cx + sun_r, sun_cy + sun_r], fill=(255, 200, 0))
    for i in range(8):
        a  = math.radians(i * 45 - 90)
        if a > -math.pi * 0.1:  # only draw rays above horizon
            continue
        x1 = sun_cx + (sun_r + 3) * math.cos(a)
        y1 = sun_cy + (sun_r + 3) * math.sin(a)
        x2 = sun_cx + (sun_r + 9) * math.cos(a)
        y2 = sun_cy + (sun_r + 9) * math.sin(a)
        d.line([(x1,y1),(x2,y2)], fill=(255,200,0), width=2)

    # Horizon line
    d.line([(8, SIZE-4), (SIZE-8, SIZE-4)], fill=(255,160,60,180), width=1)

    # Clock (top half of screen)
    cx, cy, r = HALF, 28, 18
    d.ellipse([cx-r-2, cy-r-2, cx+r+2, cy+r+2], fill=(255,160,60,180))
    d.ellipse([cx-r,   cy-r,   cx+r,   cy+r],   fill=(255,250,235))

    for i in range(12):
        a = math.radians(i * 30 - 90)
        major = (i % 3 == 0)
        ri, ro = r-(4 if major else 2), r-1
        d.line([(cx + ri*math.cos(a), cy + ri*math.sin(a)),
                (cx + ro*math.cos(a), cy + ro*math.sin(a))],
               fill=(180,100,30), width=2 if major else 1)

    for angle, length, width in [
        (math.radians(7*30 - 90), r-7, 3),
        (math.radians(-90),        r-3, 2),
    ]:
        d.line([(cx, cy), (cx + length*math.cos(angle),
                           cy + length*math.sin(angle))],
               fill=(120, 60, 0), width=width)
    d.ellipse([cx-2, cy-2, cx+2, cy+2], fill=(120,60,0))

    return add_gloss(img)

# ═══════════════════════════════════════════════════════════════════════════════
# Build all variants + comparison sheet
# ═══════════════════════════════════════════════════════════════════════════════

variants = [
    ("v1_classic",   variant_classic(),  "V1: Classic"),
    ("v2_bell",      variant_flat_bell(),"V2: Bell"),
    ("v3_moon",      variant_moon(),     "V3: Moon"),
    ("v4_vibrate",   variant_vibrate(),  "V4: Vibrate"),
    ("v5_sunrise",   variant_sunrise(),  "V5: Sunrise"),
]

# Save individual 70x70 icons
for name, icon, _ in variants:
    path = os.path.join(OUT, f"launcher_icon_{name}.png")
    icon.save(path)
    print(f"Saved {path}")

# ── Comparison sheet (scale each up 5× with labels) ──────────────────────────
from PIL import ImageFont

SCALE   = 5
THUMB   = SIZE * SCALE          # 350px each
PAD     = 20
LABEL_H = 30
COLS    = len(variants)
SHEET_W = COLS * THUMB + (COLS + 1) * PAD
SHEET_H = THUMB + LABEL_H + PAD * 2 + 10

sheet = Image.new("RGB", (SHEET_W, SHEET_H), (20, 20, 20))
sd    = ImageDraw.Draw(sheet)

try:
    label_font = ImageFont.truetype(
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
except:
    label_font = ImageFont.load_default()

for i, (name, icon, label) in enumerate(variants):
    thumb = icon.resize((THUMB, THUMB), Image.NEAREST)
    # Composite onto dark bg
    bg = Image.new("RGB", (THUMB, THUMB), (20, 20, 20))
    bg.paste(thumb, mask=thumb.split()[3])

    x = PAD + i * (THUMB + PAD)
    y = PAD
    sheet.paste(bg, (x, y))

    # Label
    bbox = sd.textbbox((0, 0), label, font=label_font)
    lw   = bbox[2] - bbox[0]
    lx   = x + (THUMB - lw) // 2
    sd.text((lx, y + THUMB + 8), label, font=label_font, fill=(200, 200, 200))

sheet_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icon_variants_preview.png")
sheet.save(sheet_path)
print(f"\nComparison sheet: {sheet_path}")
