"""Generate the synthetic reference dataset (deterministic, no third-party images).

The images in r/inst/extdata/reference/images/ are committed (a single copy, used by the Python
tests, the R package and the examples); this script documents how they were made. Regenerating them with another zlib or Pillow version may change the
file bytes, so expected.json would need review (a high-risk change).

    python reference/generate.py
"""

import shutil
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[1] / "r/inst/extdata/reference" / "images"
SIZE = 128


def gel(seed):
    rng = np.random.default_rng(seed)
    y = np.arange(SIZE).reshape(-1, 1)
    img = np.full((SIZE, SIZE), 225.0) + rng.normal(0, 4, (SIZE, SIZE))
    lane_width = SIZE // 6
    for lane in range(6):
        x0 = lane * lane_width + 3
        profile = np.zeros((SIZE, 1))
        for _ in range(rng.integers(2, 5)):
            centre, strength = rng.uniform(15, SIZE - 15), rng.uniform(80, 170)
            profile += strength * np.exp(-((y - centre) ** 2) / (2 * rng.uniform(1.5, 3.5) ** 2))
        img[:, x0 : x0 + lane_width - 6] -= profile
    return np.clip(img, 0, 255).round().astype(np.uint8)


def cells(seed):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    rgb = np.zeros((SIZE, SIZE, 3)) + rng.normal(8, 2, (SIZE, SIZE, 3))
    for _ in range(14):
        cy, cx, r = rng.uniform(10, SIZE - 10), rng.uniform(10, SIZE - 10), rng.uniform(4, 10)
        blob = np.exp(-((yy - cy) ** 2 + (xx - cx) ** 2) / (2 * r**2))
        rgb[:, :, 1] += 220 * blob
        rgb[:, :, 0] += rng.uniform(0, 120) * blob
    return np.clip(rgb, 0, 255).round().astype(np.uint8)


def save(array, name, **kwargs):
    Image.fromarray(array).save(OUT / name, **kwargs)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    a, b = gel(1), gel(2)
    save(a, "gel_a.png")
    shutil.copyfile(OUT / "gel_a.png", OUT / "gel_a_copy.png")
    save(a, "gel_a.tif", compression="raw")
    save(np.ascontiguousarray(np.rot90(a, 1)), "gel_a_rot90.png")
    save(np.ascontiguousarray(a[:, ::-1]), "gel_a_flip.png")
    save((255 * (a / 255) ** 0.8).round().astype(np.uint8), "gel_a_contrast.png")
    spliced = a.copy()
    spliced[:, 64:85] = b[:, 64:85]
    save(spliced, "gel_a_spliced.png")
    save(b, "gel_b.png")

    c = cells(3)
    save(c, "cells_a.png")
    green16 = (c[:, :, 1].astype(np.uint16) * 257).astype(np.uint16)
    Image.fromarray(green16).save(OUT / "cells_a_16bit.png")
    Image.fromarray(green16).save(OUT / "cells_a_16bit.tif", compression="raw")
    save(cells(4), "cells_b.png")
    print(f"wrote {len(list(OUT.iterdir()))} images to {OUT}")


if __name__ == "__main__":
    main()
