"""Decoding images to the RGB float array of ALGORITHMS.md section 1."""

from pathlib import Path

import numpy as np
from PIL import Image

EXTENSIONS = {".png", ".tif", ".tiff", ".jpg", ".jpeg", ".bmp", ".gif", ".webp"}


def load(path):
    """Return (rgb, metadata) for an image file."""
    with Image.open(path) as img:
        img.seek(0)
        mode = img.mode
        info = {
            "format": img.format,
            "width": img.width,
            "height": img.height,
            "mode": mode,
            "bit_depth": 16 if mode.startswith("I;16") or mode == "I" else 8,
            "software": _exif_value(img, 0x0131),
            "datetime": _exif_value(img, 0x0132),
            "dpi": [float(x) for x in img.info["dpi"]] if "dpi" in img.info else None,
        }
        if mode.startswith("I;16") or mode == "I":
            levels = np.asarray(img, dtype=np.float64)
            rgb = np.repeat((levels / 257)[:, :, None], 3, axis=2)
        elif mode in ("L", "LA", "1"):
            levels = np.asarray(img.convert("L"), dtype=np.float64)
            rgb = np.repeat(levels[:, :, None], 3, axis=2)
        else:
            rgb = np.asarray(img.convert("RGB"), dtype=np.float64)
    return rgb, info


def _exif_value(img, tag):
    try:
        value = img.getexif().get(tag)
    except Exception:
        return None
    return str(value) if value is not None else None


def find_images(folder):
    return sorted(p for p in Path(folder).rglob("*") if p.is_file() and p.suffix.lower() in EXTENSIONS)
