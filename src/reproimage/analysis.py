"""Image fingerprints and pair classification (ALGORITHMS.md sections 5–7)."""

from itertools import combinations
from pathlib import Path

from . import __version__
from .hashing import ALGORITHM_VERSION, ORIENTATIONS, dhash, file_sha256, grey, hamming, orient, phash, pixel_sha256
from .io import find_images, load

THRESHOLDS = {"dhash": 10, "phash": 10}


def fingerprint(path, name=None):
    rgb, info = load(path)
    g = grey(rgb)
    variants = {o: {"dhash": dhash(orient(g, o)), "phash": phash(orient(g, o))} for o in ORIENTATIONS}
    return {
        "name": name or Path(path).name,
        "file_sha256": file_sha256(path),
        "pixel_sha256": pixel_sha256(rgb),
        "width": info["width"],
        "height": info["height"],
        "dhash": variants["identity"]["dhash"],
        "phash": variants["identity"]["phash"],
        "metadata": info,
        "_variants": variants,
    }


def compare(a, b, thresholds=THRESHOLDS):
    if a["file_sha256"] == b["file_sha256"]:
        return {"category": "identical_file", "orientation": None, "dhash_distance": 0, "phash_distance": 0}
    if a["pixel_sha256"] == b["pixel_sha256"]:
        return {"category": "identical_pixels", "orientation": None, "dhash_distance": 0, "phash_distance": 0}
    best = None
    for o in ORIENTATIONS:
        d = hamming(a["dhash"], b["_variants"][o]["dhash"])
        p = hamming(a["phash"], b["_variants"][o]["phash"])
        if d <= thresholds["dhash"] and p <= thresholds["phash"] and (best is None or d + p < best[1] + best[2]):
            best = (o, d, p)
    if best is None:
        return None
    return {"category": "similar", "orientation": best[0], "dhash_distance": best[1], "phash_distance": best[2]}


def analyze(paths, root=None, thresholds=THRESHOLDS):
    """Fingerprint every image and list related pairs. Names are relative to root."""
    root = Path(root) if root else None
    images = [fingerprint(p, str(Path(p).relative_to(root)).replace("\\", "/") if root else None) for p in paths]
    images.sort(key=lambda im: im["name"])
    pairs = []
    for a, b in combinations(images, 2):
        result = compare(a, b, thresholds)
        if result:
            pairs.append({"a": a["name"], "b": b["name"], **result})
    return {
        "schema": "reproimage-result/1",
        "tool": {"name": "reproimage", "version": __version__, "algorithm_version": ALGORITHM_VERSION},
        "parameters": {"thresholds": dict(thresholds)},
        "images": [{k: v for k, v in im.items() if not k.startswith("_")} for im in images],
        "pairs": pairs,
    }


def analyze_folder(folder, thresholds=THRESHOLDS):
    return analyze(find_images(folder), root=folder, thresholds=thresholds)
