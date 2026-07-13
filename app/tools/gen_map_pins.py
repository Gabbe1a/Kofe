from PIL import Image, ImageDraw
from pathlib import Path

out = Path(__file__).resolve().parents[1] / "assets" / "images" / "map"
out.mkdir(parents=True, exist_ok=True)


def make_pin(path: Path, fill: tuple[int, int, int, int], ring=None, size=128):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Soft ground shadow under tip
    d.ellipse(
        [size * 0.38, size * 0.86, size * 0.62, size * 0.96],
        fill=(0, 0, 0, 42),
    )

    cx, cy, r = size / 2, size * 0.42, size * 0.32
    tip = [
        (cx - r * 0.55, cy + r * 0.55),
        (cx + r * 0.55, cy + r * 0.55),
        (cx, size * 0.92),
    ]
    d.polygon(tip, fill=fill)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)

    if ring:
        d.ellipse(
            [cx - r + 4, cy - r + 4, cx + r - 4, cy + r - 4],
            outline=ring,
            width=5,
        )

    ir = r * 0.58
    d.ellipse([cx - ir, cy - ir, cx + ir, cy + ir], fill=(252, 252, 252, 255))

    # Cup body
    left, top, right, bottom = cx - ir * 0.45, cy - ir * 0.12, cx + ir * 0.32, cy + ir * 0.52
    d.rounded_rectangle([left, top, right, bottom], radius=6, fill=fill)
    # Handle
    d.arc(
        [right - 2, top + 3, right + ir * 0.42, bottom - 3],
        start=270,
        end=90,
        fill=fill,
        width=5,
    )
    # Steam
    for i, dx in enumerate((-7, 0, 7)):
        x = cx + dx - 4
        y0 = cy - ir * 0.58 - i
        d.arc([x, y0, x + 8, y0 + 14], start=200, end=340, fill=fill, width=3)

    img.save(path)
    print("wrote", path)


make_pin(out / "pin.png", (83, 177, 117, 255))
make_pin(out / "pin_selected.png", (24, 23, 37, 255), ring=(83, 177, 117, 255))
print("ok", sorted(p.name for p in out.iterdir()))
