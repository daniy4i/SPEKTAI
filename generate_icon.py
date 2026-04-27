"""
SPEKT AI App Icon Generator
Brand Guidelines v2.0

Void background (#08080D)
Neon Green border (#39FF14) — rounded rectangle
Skull Blue eyes (#4A7CDB) — two circles
Laser Gold laser (#D4A843) — thin horizontal line through eyes
Neon Green mouth lines (#39FF14) — two horizontal lines
"""

import os
import math
from PIL import Image, ImageDraw

# Brand colors
VOID       = (8,   8,  13, 255)
NEON_GREEN = (57, 255,  20, 255)
SKULL_BLUE = (74, 124, 219, 255)
LASER_GOLD = (212, 168,  67, 255)
TRANSPARENT = (0, 0, 0, 0)

ICON_DIR = "lannaapp/Assets.xcassets/AppIcon.appiconset"

def draw_rounded_rect(draw, xy, radius, outline_color, line_width):
    x0, y0, x1, y1 = xy
    r = radius
    w = line_width
    # Draw four arcs at corners and four lines
    for i in range(w):
        d = i
        draw.arc([x0+d, y0+d, x0+2*r-d, y0+2*r-d], 180, 270, fill=outline_color)
        draw.arc([x1-2*r+d, y0+d, x1-d, y0+2*r-d], 270, 360, fill=outline_color)
        draw.arc([x0+d, y1-2*r+d, x0+2*r-d, y1-d], 90, 180, fill=outline_color)
        draw.arc([x1-2*r+d, y1-2*r+d, x1-d, y1-d], 0, 90, fill=outline_color)
        draw.line([x0+r, y0+d, x1-r, y0+d], fill=outline_color)
        draw.line([x0+r, y1-d, x1-r, y1-d], fill=outline_color)
        draw.line([x0+d, y0+r, x0+d, y1-r], fill=outline_color)
        draw.line([x1-d, y0+r, x1-d, y1-r], fill=outline_color)

def draw_circle_outline(draw, center, radius, color, line_width):
    cx, cy = center
    for i in range(line_width):
        r = radius - i
        bbox = [cx - r, cy - r, cx + r, cy + r]
        draw.ellipse(bbox, outline=color, width=1)

def generate_icon(size):
    img = Image.new("RGBA", (size, size), VOID)
    draw = ImageDraw.Draw(img)

    s = size

    # Border — neon green rounded rectangle
    border_w = max(1, int(s * 0.028))
    padding  = max(2, int(s * 0.055))
    radius   = max(4, int(s * 0.18))
    draw_rounded_rect(
        draw,
        [padding, padding, s - padding, s - padding],
        radius,
        NEON_GREEN,
        border_w
    )

    # Eyes — two skull blue circles
    eye_r    = max(2, int(s * 0.115))
    eye_y    = int(s * 0.385)
    eye_lx   = int(s * 0.345)
    eye_rx   = int(s * 0.655)
    eye_w    = max(1, int(s * 0.024))
    draw_circle_outline(draw, (eye_lx, eye_y), eye_r, SKULL_BLUE, eye_w)
    draw_circle_outline(draw, (eye_rx, eye_y), eye_r, SKULL_BLUE, eye_w)

    # Laser gold line — thin horizontal through both eyes
    laser_w  = max(1, int(s * 0.012))
    lx_start = int(s * 0.06)
    lx_end   = int(s * 0.94)
    for i in range(laser_w):
        y = eye_y - laser_w // 2 + i
        draw.line([lx_start, y, lx_end, y], fill=LASER_GOLD)

    # Mouth — two neon green horizontal lines
    line1_y  = int(s * 0.625)
    line2_y  = int(s * 0.700)
    line1_w  = max(1, int(s * 0.022))
    line2_w  = max(1, int(s * 0.015))
    ml       = int(s * 0.245)
    mr       = int(s * 0.755)
    mr2      = int(s * 0.620)

    for i in range(line1_w):
        draw.line([ml, line1_y + i, mr,  line1_y + i], fill=NEON_GREEN)
    for i in range(line2_w):
        g = (57, 255, 20, 160)
        draw.line([ml, line2_y + i, mr2, line2_y + i], fill=g)

    return img

# Map of filename → pixel size
SIZES = {
    "icon-ios-1024x1024.png":    1024,
    "icon-ios-20x20@2x.png":       40,
    "icon-ios-20x20@3x.png":       60,
    "icon-ios-29x29@2x.png":       58,
    "icon-ios-29x29@3x.png":       87,
    "icon-ios-38x38@2x.png":       76,
    "icon-ios-38x38@3x.png":      114,
    "icon-ios-40x40@2x.png":       80,
    "icon-ios-40x40@3x.png":      120,
    "icon-ios-60x60@2x.png":      120,
    "icon-ios-60x60@3x.png":      180,
    "icon-ios-64x64@2x.png":      128,
    "icon-ios-64x64@3x.png":      192,
    "icon-ios-68x68@2x.png":      136,
    "icon-ios-76x76@2x.png":      152,
    "icon-ios-83.5x83.5@2x.png":  167,
    "icon-mac-128x128.png":        128,
    "icon-mac-128x128@2x.png":     256,
    "icon-mac-16x16.png":           16,
    "icon-mac-16x16@2x.png":        32,
    "icon-mac-256x256.png":        256,
    "icon-mac-256x256@2x.png":     512,
    "icon-mac-32x32.png":           32,
    "icon-mac-32x32@2x.png":        64,
    "icon-mac-512x512.png":        512,
    "icon-mac-512x512@2x.png":    1024,
    "icon-watchos-1024x1024.png": 1024,
    "icon-watchos-108x108@2x.png": 216,
    "icon-watchos-117x117@2x.png": 234,
    "icon-watchos-129x129@2x.png": 258,
    "icon-watchos-22x22@2x.png":    44,
    "icon-watchos-24x24@2x.png":    48,
    "icon-watchos-27.5x27.5@2x.png": 55,
    "icon-watchos-29x29@2x.png":    58,
    "icon-watchos-30x30@2x.png":    60,
    "icon-watchos-32x32@2x.png":    64,
    "icon-watchos-33x33@2x.png":    66,
    "icon-watchos-40x40@2x.png":    80,
    "icon-watchos-43.5x43.5@2x.png": 87,
    "icon-watchos-44x44@2x.png":    88,
    "icon-watchos-46x46@2x.png":    92,
    "icon-watchos-50x50@2x.png":   100,
    "icon-watchos-51x51@2x.png":   102,
    "icon-watchos-54x54@2x.png":   108,
    "icon-watchos-86x86@2x.png":   172,
    "icon-watchos-98x98@2x.png":   196,
}

generated = set()
for filename, px in SIZES.items():
    if px in generated:
        # Reuse already-generated image at this pixel size
        pass
    img = generate_icon(px)
    # iOS/macOS icons must be RGB (no alpha channel) except we keep RGBA for now
    # Convert to RGB for App Store compliance on the 1024 master
    out = img.convert("RGB") if "1024" in filename and "watchos" not in filename else img.convert("RGB")
    path = os.path.join(ICON_DIR, filename)
    out.save(path, "PNG")
    generated.add(px)
    print(f"  {filename} ({px}x{px})")

print(f"\nDone — {len(SIZES)} icons written to {ICON_DIR}/")
