#!/usr/bin/env python3
"""Build DevPurge's Zine icon and a complete macOS ICNS, without network assets.

The bold D extends site/favicon.svg; paper, ink and accent colors come from
our Zine/Blacklight palettes. Render once at 1024px and downsample with Lanczos
so small Finder icons have the same silhouette without jagged contours.
"""
from pathlib import Path
import random
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024
INK = '#141414'
PINK = '#FF5FD2'
LIME = '#C6FF3D'
BLUE = '#2B3FE0'
PAPER = '#FFF7E5'
ICON_SIZES = (
    ('icon_16x16.png', 16), ('icon_16x16@2x.png', 32),
    ('icon_32x32.png', 32), ('icon_32x32@2x.png', 64),
    ('icon_128x128.png', 128), ('icon_128x128@2x.png', 256),
    ('icon_256x256.png', 256), ('icon_256x256@2x.png', 512),
    ('icon_512x512.png', 512), ('icon_512x512@2x.png', 1024),
)


def paper_polygon(left, top, right, bottom, seed):
    """Small, deliberate paper tears, not a noisy silhouette."""
    rng = random.Random(seed)
    steps = 26
    points = []
    for i in range(steps + 1):
        points.append((left + (right-left)*i/steps, top + rng.randrange(-5, 6)))
    for i in range(1, steps + 1):
        points.append((right + rng.randrange(-5, 6), top + (bottom-top)*i/steps))
    for i in range(1, steps + 1):
        points.append((right - (right-left)*i/steps, bottom + rng.randrange(-5, 6)))
    for i in range(1, steps):
        points.append((left + rng.randrange(-5, 6), bottom - (bottom-top)*i/steps))
    return points


def make_master():
    image = Image.new('RGBA', (SIZE, SIZE))
    # Native-sized mask leaves a transparent margin for Finder and Dock.
    mask = Image.new('L', image.size)
    ImageDraw.Draw(mask).rounded_rectangle((80, 72, 944, 936), radius=194, fill=255)
    shadow = Image.new('RGBA', image.size)
    ImageDraw.Draw(shadow).rounded_rectangle((83, 87, 941, 950), radius=192, fill=(20, 20, 20, 60))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(13)))
    base = Image.new('RGBA', image.size, PINK)
    base.putalpha(mask)
    image.alpha_composite(base)
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((80, 72, 944, 936), radius=194, outline=INK, width=9)
    draw.rounded_rectangle((91, 82, 933, 923), radius=185, outline=(255, 236, 245, 105), width=4)

    # Blue print registration offset beneath the lime offcut.
    offset = Image.new('RGBA', image.size)
    ImageDraw.Draw(offset).polygon(paper_polygon(246, 216, 819, 838, 9), fill=BLUE)
    image.alpha_composite(offset.rotate(-6, resample=Image.Resampling.BICUBIC))

    note = Image.new('RGBA', image.size)
    n = ImageDraw.Draw(note)
    shape = paper_polygon(206, 184, 792, 801, 17)
    n.polygon([(x+8, y+12) for x, y in shape], fill=(20, 20, 20, 150))
    n.polygon(shape, fill=PAPER)
    n.polygon(paper_polygon(214, 193, 782, 788, 17), fill=LIME)
    # Use the same licensed display face as the app and landing page.
    font = ImageFont.truetype(str(ROOT / 'mac/Resources/Fonts/LilitaOne-Regular.ttf'), 650)
    box = n.textbbox((0, 0), 'D', font=font)
    x = 499 - (box[2] - box[0]) / 2 - box[0]
    y = 491 - (box[3] - box[1]) / 2 - box[1]
    n.text((x, y), 'D', font=font, fill=INK)
    # Sparse ink wear is visible at 512/1024, but disappears at small sizes.
    ink_mask = Image.new('L', image.size)
    ImageDraw.Draw(ink_mask).text((x, y), 'D', font=font, fill=255)
    rng = random.Random(404)
    for _ in range(2200):
        px, py = rng.randrange(260, 750), rng.randrange(240, 750)
        if ink_mask.getpixel((px, py)) > 250:
            radius = rng.choice((0.5, 0.7, 1.1))
            n.ellipse((px, py, px+radius*2, py+radius*2), fill=LIME)
    image.alpha_composite(note.rotate(7, resample=Image.Resampling.BICUBIC))

    # A short paper tape accent echoes the site's collage without tiny text.
    tape = Image.new('RGBA', image.size)
    ImageDraw.Draw(tape).polygon(paper_polygon(139, 781, 364, 830, 24), fill=PAPER)
    image.alpha_composite(tape.rotate(19, resample=Image.Resampling.BICUBIC))

    # Fine deterministic paper flecks stay inside the outer tile.
    flecks = Image.new('RGBA', image.size)
    f = ImageDraw.Draw(flecks)
    rng = random.Random(31)
    for _ in range(14000):
        px, py = rng.randrange(90, 934), rng.randrange(82, 926)
        if mask.getpixel((px, py)) == 255:
            f.point((px, py), fill=(20, 20, 20, rng.randrange(7, 24)))
    image.alpha_composite(flecks)
    return image


def make_icon(size):
    return make_master().resize((size, size), Image.Resampling.LANCZOS)


def main():
    master = make_master()
    master_path = ROOT / 'mac/Resources/AppIcon.png'
    master.save(master_path, optimize=True)
    # Temporary iconsets avoid leaving generated files in the repository root.
    with tempfile.TemporaryDirectory(prefix='devpurge-icon-') as temporary:
        iconset = Path(temporary) / 'DevPurge.iconset'
        iconset.mkdir()
        for name, size in ICON_SIZES:
            master.resize((size, size), Image.Resampling.LANCZOS).save(iconset / name)
        subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', str(ROOT / 'AppIcon.icns')], check=True)
    print(f'Generated {master_path} and {ROOT / "AppIcon.icns"}')


if __name__ == '__main__':
    main()
