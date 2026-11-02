import json
import os
from pathlib import Path

import numpy as np
from PIL import Image

from reproimage.analysis import analyze_folder, compare, fingerprint
from reproimage.cli import main
from reproimage.hashing import bits_to_hex, block_resize, dhash, hamming, orient

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "r" / "inst" / "extdata" / "reference"  # single copy, shared with the R package
CONFORMANCE_KEYS = ["name", "file_sha256", "pixel_sha256", "width", "height", "dhash", "phash"]


def conformance(result):
    """The part of a result that the Python and R implementations must share."""
    return {
        "algorithm_version": result["tool"]["algorithm_version"],
        "thresholds": result["parameters"]["thresholds"],
        "images": [{k: im[k] for k in CONFORMANCE_KEYS} for im in result["images"]],
        "pairs": result["pairs"],
    }


def test_regression_against_reference_dataset():
    got = conformance(analyze_folder(REFERENCE / "images"))
    path = REFERENCE / "expected.json"
    if os.environ.get("UPDATE"):
        path.write_text(json.dumps(got, indent=1) + "\n", encoding="utf-8")
    assert got == json.loads(path.read_text(encoding="utf-8"))


def test_bits_and_hamming():
    assert bits_to_hex([1] + [0] * 63) == "8000000000000000"
    assert hamming("ffffffffffffffff", "0000000000000000") == 64
    assert hamming("8000000000000001", "8000000000000000") == 1


def test_block_resize_handles_uneven_sizes():
    g = np.arange(30, dtype=float).reshape(5, 6)
    out = block_resize(g, 2, 3)
    assert out.shape == (2, 3)
    assert out[0, 0] == g[0:2, 0:2].mean()
    assert out[1, 2] == g[2:5, 4:6].mean()


def test_uniform_image_has_zero_dhash():
    assert dhash(np.full((40, 40), 77.0)) == "0000000000000000"


def test_orientations():
    g = np.array([[1, 2], [3, 4]])
    assert orient(g, "rot90").tolist() == [[2, 4], [1, 3]]
    assert orient(g, "flip").tolist() == [[2, 1], [4, 3]]
    assert orient(g, "flip_rot90").tolist() == [[1, 3], [2, 4]]


def test_jpeg_recompression_is_similar(tmp_path):
    with Image.open(REFERENCE / "images" / "gel_a.png") as img:
        img.save(tmp_path / "gel_a.jpg", quality=75)
    result = compare(fingerprint(REFERENCE / "images" / "gel_a.png"), fingerprint(tmp_path / "gel_a.jpg"))
    assert result["category"] == "similar"


def test_unrelated_images_are_not_paired():
    a = fingerprint(REFERENCE / "images" / "gel_a.png")
    b = fingerprint(REFERENCE / "images" / "gel_b.png")
    assert compare(a, b) is None


def test_cli_writes_report_and_provenance(tmp_path):
    out = tmp_path / "report"
    assert main(["analyze", str(REFERENCE / "images"), "--out", str(out)]) == 0
    for name in ["result.json", "pairs.csv", "report.html", "ro-crate-metadata.json"]:
        assert (out / name).exists()
    crate = json.loads((out / "ro-crate-metadata.json").read_text(encoding="utf-8"))
    action = next(e for e in crate["@graph"] if e["@type"] == "CreateAction")
    assert len(action["object"]) == 12
    assert "Requires expert review" in (out / "report.html").read_text(encoding="utf-8")
