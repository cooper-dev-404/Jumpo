#!/usr/bin/env python3
"""Build Jumpo's layered-window app icon as a PNG master and macOS .icns.

The two overlapping panes represent switching between windows. The single
up-forward arrow matches the menu bar symbol. The artwork is transparent and
unmasked so it remains a complete icon on older macOS versions and sits cleanly
inside the system-provided icon treatment on current macOS.

Usage:
    python3 Tools/generate_app_icon.py
    python3 Tools/generate_app_icon.py --preview /tmp/jumpo-icon-preview
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter


CANVAS = 1024
SCALE = 4
BIG = CANVAS * SCALE
ART_SCALE = 1.25


def rounded_mask(box, radius):
    mask = Image.new("L", (BIG, BIG), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        tuple(round(value * SCALE) for value in box),
        radius=radius * SCALE,
        fill=255,
    )
    return mask


def vertical_gradient(top, bottom):
    strip = Image.new("RGBA", (1, BIG))
    for y in range(BIG):
        t = y / (BIG - 1)
        strip.putpixel(
            (0, y),
            tuple(round(top[channel] * (1 - t) + bottom[channel] * t) for channel in range(3)) + (255,),
        )
    return strip.resize((BIG, BIG), Image.Resampling.BILINEAR)


def shadow_for(mask, blur, offset, opacity):
    shadow = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    shadow.putalpha(mask.point(lambda value: round(value * opacity / 255)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur * SCALE))
    shifted = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    shifted.alpha_composite(shadow, (0, offset * SCALE))
    return shifted


def pane(box, radius, top, bottom, edge):
    mask = rounded_mask(box, radius)
    surface = vertical_gradient(top, bottom)
    surface.putalpha(mask)

    # One restrained edge gives the panes material depth without adding marks
    # that disappear at Dock size.
    details = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    draw = ImageDraw.Draw(details)
    draw.rounded_rectangle(
        tuple(round(value * SCALE) for value in box),
        radius=radius * SCALE,
        outline=edge,
        width=3 * SCALE,
    )
    details.putalpha(Image.composite(details.getchannel("A"), Image.new("L", (BIG, BIG)), mask))
    return Image.alpha_composite(surface, details), mask


def arrow_layer():
    # A single broad mark survives 16 px. Its upper-right corner crosses
    # from the foreground pane onto the destination pane.
    mask = Image.new("L", (BIG, BIG), 0)
    draw = ImageDraw.Draw(mask)
    width = 76 * SCALE
    draw.line([(355 * SCALE, 685 * SCALE), (718 * SCALE, 322 * SCALE)], fill=255, width=width)
    draw.line(
        [(540 * SCALE, 322 * SCALE), (718 * SCALE, 322 * SCALE), (718 * SCALE, 500 * SCALE)],
        fill=255,
        width=width,
        joint="curve",
    )
    radius = width // 2
    for x, y in ((355, 685), (540, 322), (718, 500)):
        cx, cy = x * SCALE, y * SCALE
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=255)
    arrow = Image.new("RGBA", (BIG, BIG), (247, 252, 255, 0))
    arrow.putalpha(mask)
    return arrow, mask


def build():
    master = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))

    back, back_mask = pane(
        (328, 200, 822, 694), 98,
        (92, 193, 252), (33, 113, 218),
        (171, 231, 255, 120),
    )
    master = Image.alpha_composite(master, shadow_for(back_mask, 30, 26, 74))
    master = Image.alpha_composite(master, back)

    front, front_mask = pane(
        (202, 326, 696, 820), 98,
        (55, 91, 225), (26, 48, 158),
        (125, 158, 255, 128),
    )
    master = Image.alpha_composite(master, shadow_for(front_mask, 27, 23, 82))
    master = Image.alpha_composite(master, front)

    arrow, arrow_mask = arrow_layer()
    master = Image.alpha_composite(master, shadow_for(arrow_mask, 11, 12, 78))
    master = Image.alpha_composite(master, arrow)
    expanded = round(BIG * ART_SCALE)
    master = master.resize((expanded, expanded), Image.Resampling.LANCZOS)
    inset = (expanded - BIG) // 2
    master = master.crop((inset, inset, inset + BIG, inset + BIG))
    return master.resize((CANVAS, CANVAS), Image.Resampling.LANCZOS)


def write_bundle(master, root):
    resources = os.path.join(root, "Resources")
    master_path = os.path.join(resources, "JumpoIcon-1024.png")
    bundle = os.path.join(resources, "Jumpo.icns")
    master.save(master_path)

    iconset = tempfile.mkdtemp(suffix=".iconset")
    try:
        for size in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                name = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
                master.resize((size * scale, size * scale), Image.Resampling.LANCZOS).save(
                    os.path.join(iconset, name)
                )
        subprocess.run(["iconutil", "-c", "icns", iconset, "-o", bundle], check=True)
    finally:
        shutil.rmtree(iconset, ignore_errors=True)
    return bundle, master_path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", default="")
    parser.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    arguments = parser.parse_args()

    master = build()
    if arguments.preview:
        os.makedirs(arguments.preview, exist_ok=True)
        master.save(os.path.join(arguments.preview, "jumpo-icon-1024.png"))
        for size in (128, 64, 32, 16):
            master.resize((size, size), Image.Resampling.LANCZOS).save(
                os.path.join(arguments.preview, f"jumpo-icon-{size}.png")
            )
        print(f"previews in {arguments.preview}")
        return

    bundle, master_path = write_bundle(master, arguments.root)
    print(f"wrote {bundle} and {master_path}")


if __name__ == "__main__":
    sys.exit(main())
