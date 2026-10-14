#!/usr/bin/env python3
"""Generate macOS AppIcon.icns for DevPurge."""
import os
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont

def make_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rounded rectangle dimensions
    padding = size * 0.08
    rect = [padding, padding, size - padding, size - padding]
    radius = size * 0.22

    # Draw shadow
    shadow_offset = size * 0.03
    shadow_rect = [padding, padding + shadow_offset, size - padding, size - padding + shadow_offset]
    draw.rounded_rectangle(shadow_rect, radius=radius, fill=(21, 35, 27, 45))

    # Draw body (Warm limestone #f5f3ed)
    draw.rounded_rectangle(rect, radius=radius, fill=(245, 243, 237, 255), outline=(217, 221, 211, 255), width=max(1, int(size * 0.015)))

    # Inner soft accent
    inner_pad = padding + size * 0.05
    inner_rect = [inner_pad, inner_pad, size - inner_pad, size - inner_pad]
    draw.rounded_rectangle(inner_rect, radius=radius * 0.8, fill=(229, 237, 223, 140))

    # Brand text "d/"
    # Try finding system font Menlo or default
    font_size = int(size * 0.44)
    font = None
    for path in [
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/SFNSMono.ttf",
        "/System/Library/Fonts/Monaco.dfont",
        "/Library/Fonts/Menlo.ttc"
    ]:
        if os.path.exists(path):
            try:
                font = ImageFont.truetype(path, font_size)
                break
            except Exception:
                pass

    if font is None:
        font = ImageFont.load_default()

    text = "d/"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    text_x = (size - text_w) / 2
    text_y = (size - text_h) / 2 - (size * 0.04)

    # Pine green accent #275941
    draw.text((text_x, text_y), text, font=font, fill=(39, 89, 65, 255))
    return img

def main():
    root = Path(__file__).resolve().parents[1]
    iconset = root / "DevPurge.iconset"
    iconset.mkdir(exist_ok=True)

    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for name, s in sizes:
        img = make_icon(s)
        img.save(iconset / name)

    icns_path = root / "AppIcon.icns"
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(icns_path)], check=True)
    print(f"Generated {icns_path}")

if __name__ == "__main__":
    main()
