"""Hashes and orientations, exactly as specified in ALGORITHMS.md."""

import hashlib

import numpy as np

ALGORITHM_VERSION = 1
EPS = 1e-6
ORIENTATIONS = ["identity", "rot90", "rot180", "rot270", "flip", "flip_rot90", "flip_rot180", "flip_rot270"]


def grey(rgb):
    return (0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1]) + 0.114 * rgb[:, :, 2]


def block_resize(g, h, w):
    H, W = g.shape
    out = np.empty((h, w))
    for i in range(h):
        r0 = (i * H) // h
        r1 = max(((i + 1) * H) // h, r0 + 1)
        for j in range(w):
            c0 = (j * W) // w
            c1 = max(((j + 1) * W) // w, c0 + 1)
            out[i, j] = g[r0:r1, c0:c1].mean()
    return out


def bits_to_hex(bits):
    value = 0
    for b in bits:
        value = (value << 1) | int(b)
    return f"{value:016x}"


def dhash(g):
    s = block_resize(g, 8, 9)
    return bits_to_hex(((s[:, 1:] - s[:, :-1]) > EPS).ravel())


def _dct_matrix(n=32):
    k = np.arange(n).reshape(-1, 1)
    j = np.arange(n).reshape(1, -1)
    return np.cos(np.pi * (2 * j + 1) * k / (2 * n))


_C = _dct_matrix()


def phash(g):
    s = block_resize(g, 32, 32)
    low = (_C @ s @ _C.T)[:8, :8].ravel()
    m = np.median(low[1:])
    return bits_to_hex((low - m) > EPS)


def hamming(a, b):
    return bin(int(a, 16) ^ int(b, 16)).count("1")


def orient(g, name):
    if name.startswith("flip"):
        g = g[:, ::-1]
    turns = {"identity": 0, "rot90": 1, "rot180": 2, "rot270": 3}[name.replace("flip_", "").replace("flip", "identity")]
    return np.rot90(g, turns)


def pixel_sha256(rgb):
    h, w, _ = rgb.shape
    data = np.floor(rgb + 0.5).clip(0, 255).astype(np.uint8)
    digest = hashlib.sha256(f"{h}x{w}\n".encode("ascii"))
    digest.update(np.ascontiguousarray(data).tobytes())
    return digest.hexdigest()


def file_sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()
