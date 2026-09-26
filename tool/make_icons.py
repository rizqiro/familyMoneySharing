"""Renders the 'Rumah' app icon at every size the two platforms want.

The mark is one roof stroke and two dots. Drawing it with Pillow rather than
rasterising an SVG keeps the whole thing to one dependency, and the shapes are
simple enough that the geometry below IS the source of truth.

Everything is drawn at 4x and shrunk with LANCZOS at the end: Pillow has no
antialiasing of its own, so this is what gives clean edges.
"""
import os
from PIL import Image, ImageDraw

SS = 4                      # supersample factor
SRC = 1024.0                # the coordinate space the design was drawn in

ACCENT = (190, 58, 32, 255)     # #BE3A20
CREAM = (253, 250, 245, 255)    # #FDFAF5
BUTTER = (242, 193, 78, 255)    # #F2C14E

# The mark, in SRC units: a roof polyline and two dots beneath it.
ROOF = [(206, 536), (512, 306), (818, 536)]
ROOF_W = 94
DOTS = [((416, 702), 76, CREAM), ((608, 702), 76, BUTTER)]

# The smallest circle centred here that contains the whole mark. Used to scale
# the mark into the adaptive icon's safe zone.
MARK_CENTRE = (512, 542)
MARK_RADIUS = 306


def disc(d, cx, cy, r, fill):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def draw_mark(d, scale, dx, dy):
    """Roof and dots. Round caps and joins are discs at every vertex - that is
    exactly what a round-joined stroke is, and it avoids Pillow's ragged
    joint handling."""
    w = ROOF_W * scale
    pts = [(x * scale + dx, y * scale + dy) for x, y in ROOF]
    for a, b in zip(pts, pts[1:]):
        d.line([a, b], fill=CREAM, width=int(round(w)))
    for p in pts:
        disc(d, p[0], p[1], w / 2, CREAM)
    for (cx, cy), r, colour in DOTS:
        disc(d, cx * scale + dx, cy * scale + dy, r * scale, colour)


def full_icon(size, radius_ratio=230 / SRC, square=False):
    """The whole icon: accent ground with the mark on it."""
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if square:
        d.rectangle([0, 0, big, big], fill=ACCENT)
    else:
        d.rounded_rectangle([0, 0, big - 1, big - 1],
                            radius=big * radius_ratio, fill=ACCENT)
    draw_mark(d, big / SRC, 0, 0)
    return img.resize((size, size), Image.LANCZOS)


def adaptive_foreground(size=432):
    """Android's adaptive foreground: the mark alone on transparency, scaled so
    it sits inside the 66dp safe circle of the 108dp canvas. Anything outside
    that circle can be cropped away by the launcher's mask."""
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    safe_r = big * (66 / 108) / 2
    scale = safe_r / MARK_RADIUS
    dx = big / 2 - MARK_CENTRE[0] * scale
    dy = big / 2 - MARK_CENTRE[1] * scale
    draw_mark(d, scale, dx, dy)
    return img.resize((size, size), Image.LANCZOS)


def flatten(img, bg=ACCENT):
    """The App Store and Play Store both refuse transparency."""
    out = Image.new("RGB", img.size, bg[:3])
    out.paste(img, mask=img.split()[3])
    return out


root = "android/app/src/main/res"
written = []

# ---------------------------------------------------- Android legacy icons
for folder, px in [("mipmap-mdpi", 48), ("mipmap-hdpi", 72),
                   ("mipmap-xhdpi", 96), ("mipmap-xxhdpi", 144),
                   ("mipmap-xxxhdpi", 192)]:
    os.makedirs(f"{root}/{folder}", exist_ok=True)
    icon = full_icon(px)
    icon.save(f"{root}/{folder}/ic_launcher.png")
    # The round variant is what launchers with circular masks ask for.
    big = px * SS
    circ = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    cd = ImageDraw.Draw(circ)
    cd.ellipse([0, 0, big - 1, big - 1], fill=ACCENT)
    draw_mark(cd, big / SRC, 0, 0)
    circ.resize((px, px), Image.LANCZOS).save(f"{root}/{folder}/ic_launcher_round.png")
    written += [f"{folder}/ic_launcher.png", f"{folder}/ic_launcher_round.png"]

# ------------------------------------------------ Android adaptive layers
for folder, dp in [("mipmap-mdpi", 108), ("mipmap-hdpi", 162),
                   ("mipmap-xhdpi", 216), ("mipmap-xxhdpi", 324),
                   ("mipmap-xxxhdpi", 432)]:
    adaptive_foreground(dp).save(f"{root}/{folder}/ic_launcher_foreground.png")
    written.append(f"{folder}/ic_launcher_foreground.png")

# ------------------------------------------------------------------- iOS
ios = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
sizes = {
    "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60, "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120, "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180, "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152, "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}
for name, px in sizes.items():
    # iOS applies its own corner mask, so these are square and opaque.
    flatten(full_icon(px, square=True)).save(f"{ios}/{name}")
    written.append(f"AppIcon/{name}")

# ------------------------------------------------------- store listing art
os.makedirs("docs/store", exist_ok=True)
flatten(full_icon(512, square=True)).save("docs/store/play-store-icon-512.png")
written.append("docs/store/play-store-icon-512.png")

print(f"{len(written)} files")
