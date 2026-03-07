#!/usr/bin/env python3
"""
Render Garmin Venu 2 (390x390) watch screens for Smart Alarm app.
Produces PNG previews of each UI state.
"""

from PIL import Image, ImageDraw, ImageFont
import math, os

W, H = 390, 390
CX, CY = W // 2, H // 2
OUT = os.path.dirname(os.path.abspath(__file__))

# ── Colour palette (matches the .mc source) ──────────────────────────────────
BLACK       = (0,   0,   0)
WHITE       = (255, 255, 255)
BLUE        = (0,   100, 220)
LT_GRAY     = (180, 180, 180)
DK_GRAY     = (80,  80,  80)
GREEN       = (0,   200, 80)
YELLOW      = (255, 210, 0)

# ── Font helpers ──────────────────────────────────────────────────────────────
def load_font(size):
    for path in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
    ]:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()

FONT_TINY   = load_font(16)
FONT_SMALL  = load_font(22)
FONT_MEDIUM = load_font(30)
FONT_NUM_MED = load_font(48)
FONT_NUM_LG  = load_font(60)

def new_watch():
    img = Image.new("RGB", (W, H), BLACK)
    d   = ImageDraw.Draw(img)
    # Circular bezel mask
    d.ellipse([0, 0, W-1, H-1], outline=(40, 40, 40), width=6)
    return img, d

def center_text(d, y, text, font, color):
    bbox = d.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    d.text((CX - tw // 2, y), text, font=font, fill=color)

def clip_circle(img):
    """Mask everything outside the watch circle."""
    mask = Image.new("L", (W, H), 0)
    md   = ImageDraw.Draw(mask)
    md.ellipse([3, 3, W-4, H-4], fill=255)
    result = Image.new("RGB", (W, H), BLACK)
    result.paste(img, mask=mask)
    # Draw bezel ring
    rd = ImageDraw.Draw(result)
    rd.ellipse([2, 2, W-3, H-3], outline=(55, 55, 55), width=4)
    return result

# ─────────────────────────────────────────────────────────────────────────────
# Screen 1: Idle
# ─────────────────────────────────────────────────────────────────────────────
def render_idle(wake_time="7:00 AM", window=20):
    img, d = new_watch()

    # Title
    center_text(d, 42, "Smart Alarm", FONT_SMALL, BLUE)

    # Wake Time label
    center_text(d, CY - 80, "Wake Time", FONT_SMALL, LT_GRAY)
    # Wake Time value
    center_text(d, CY - 38, wake_time, FONT_NUM_MED, WHITE)

    # Divider
    d.line([(CX - 70, CY + 20), (CX + 70, CY + 20)], fill=DK_GRAY, width=1)

    # Window label + value
    center_text(d, CY + 30, "Window", FONT_SMALL, LT_GRAY)
    center_text(d, CY + 58, f"{window} min", FONT_SMALL, WHITE)

    # Hint
    center_text(d, H - 75, "Tap to configure", FONT_TINY, DK_GRAY)

    return clip_circle(img)

# ─────────────────────────────────────────────────────────────────────────────
# Screen 2: Menu
# ─────────────────────────────────────────────────────────────────────────────
def render_menu():
    img, d = new_watch()

    # Title bar
    d.rectangle([30, 30, W-30, 75], fill=(25, 25, 60))
    center_text(d, 38, "Smart Alarm", FONT_SMALL, WHITE)

    items = ["Set Wake Time", "Set Window", "Start Alarm"]
    item_h = 62
    start_y = 90
    for i, label in enumerate(items):
        y = start_y + i * item_h
        # Highlight first item as selected
        if i == 0:
            d.rectangle([30, y, W-30, y + item_h - 4], fill=(30, 30, 80), outline=BLUE, width=1)
        else:
            d.rectangle([30, y, W-30, y + item_h - 4], fill=(20, 20, 20), outline=(50, 50, 50), width=1)
        color = WHITE if i == 0 else LT_GRAY
        center_text(d, y + 18, label, FONT_SMALL, color)

    return clip_circle(img)

# ─────────────────────────────────────────────────────────────────────────────
# Screen 3: Monitoring
# ─────────────────────────────────────────────────────────────────────────────
def render_monitoring(wake_time="7:00 AM", window=20, current_time="02:14"):
    img, d = new_watch()

    # Pulsing dot
    d.ellipse([CX-10, 22, CX+10, 42], fill=GREEN)
    center_text(d, 46, "Monitoring", FONT_TINY, GREEN)

    # Wake Time label + value
    center_text(d, CY - 80, "Wake Time", FONT_SMALL, LT_GRAY)
    center_text(d, CY - 38, wake_time, FONT_NUM_MED, WHITE)

    # Divider
    d.line([(CX - 70, CY + 20), (CX + 70, CY + 20)], fill=DK_GRAY, width=1)

    # Window
    center_text(d, CY + 30, "Window", FONT_SMALL, LT_GRAY)
    center_text(d, CY + 58, f"{window} min", FONT_SMALL, WHITE)

    # Current time (small, bottom)
    center_text(d, H - 75, current_time, FONT_TINY, DK_GRAY)

    return clip_circle(img)

# ─────────────────────────────────────────────────────────────────────────────
# Screen 4: Alarm Fired
# ─────────────────────────────────────────────────────────────────────────────
def render_fired(fired_time="6:48 AM"):
    img, d = new_watch()

    # Sun circle
    sun_cx, sun_cy, sun_r = CX, 58, 18
    d.ellipse([sun_cx-sun_r, sun_cy-sun_r, sun_cx+sun_r, sun_cy+sun_r], fill=YELLOW)
    for i in range(8):
        angle = math.radians(i * 45)
        x1 = int(sun_cx + (sun_r + 6) * math.cos(angle))
        y1 = int(sun_cy + (sun_r + 6) * math.sin(angle))
        x2 = int(sun_cx + (sun_r + 14) * math.cos(angle))
        y2 = int(sun_cy + (sun_r + 14) * math.sin(angle))
        d.line([(x1, y1), (x2, y2)], fill=YELLOW, width=2)

    center_text(d, CY - 30, "Good morning!", FONT_MEDIUM, WHITE)
    center_text(d, CY + 18, "Alarm fired at", FONT_SMALL, LT_GRAY)
    center_text(d, CY + 52, fired_time, FONT_NUM_MED, YELLOW)

    center_text(d, H - 75, "Press back to dismiss", FONT_TINY, DK_GRAY)

    return clip_circle(img)

# ─────────────────────────────────────────────────────────────────────────────
# Render all screens
# ─────────────────────────────────────────────────────────────────────────────
screens = {
    "screen_idle.png":       render_idle("7:00 AM", 20),
    "screen_menu.png":       render_menu(),
    "screen_monitoring.png": render_monitoring("7:00 AM", 20, "02:14"),
    "screen_fired.png":      render_fired("6:48 AM"),
}

for fname, img in screens.items():
    path = os.path.join(OUT, fname)
    img.save(path)
    print(f"Saved {path}")
