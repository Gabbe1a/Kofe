"""Remove near-white studio backgrounds from product PNGs."""
from __future__ import annotations

import os
from pathlib import Path

from PIL import Image
import numpy as np

BASE = Path(__file__).resolve().parents[1] / "assets" / "images" / "products"

TARGETS = [
    "cappuccino.png",
    "croissant.png",
    "lemonade.png",
    "matcha_latte.png",
    "caramel_frappe.png",
    "iced_latte_bottle.png",
]


def remove_white_bg(
    path: Path,
    out_path: Path,
    threshold: int = 245,
    soft: int = 18,
) -> None:
    im = Image.open(path).convert("RGBA")
    arr = np.asarray(im).astype(np.float32)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    white = (mn >= threshold - soft) & ((mx - mn) < 40)
    bright = (r > threshold) & (g > threshold) & (b > threshold)
    mask = white | bright
    dist = np.clip((threshold - mn) / soft, 0, 1)
    new_a = a.copy()
    new_a[mask] = 0
    near = (~mask) & (mn > threshold - soft * 2) & ((mx - mn) < 55)
    new_a[near] = np.minimum(new_a[near], (dist[near] * 255))
    out = arr.copy()
    out[:, :, 3] = new_a
    Image.fromarray(out.astype(np.uint8), "RGBA").save(out_path, optimize=True)
    print(f"wrote {out_path.name} {Image.open(out_path).mode}")


def main() -> None:
    # Skip regenerating caramel/iced — already have good MCP cutouts.
    skip_stems = {"caramel_frappe", "iced_latte_bottle"}
    for name in TARGETS:
        stem = Path(name).stem
        if stem in skip_stems:
            print(f"skip {name} (existing cutout)")
            continue
        src = BASE / name
        out = BASE / f"{stem}_cutout.png"
        remove_white_bg(src, out)
    print("done")


if __name__ == "__main__":
    main()
