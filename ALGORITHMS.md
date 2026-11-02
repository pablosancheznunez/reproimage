# ReproImage algorithms (version 1)

This is the normative specification. The Python package (`src/reproimage/`) and the R package (`r/`) implement it independently and are tested against the same reference images and expected results (`r/inst/extdata/reference/expected.json`). Any change here is a new algorithm version.

## 1. Decoding

Supported: PNG, TIFF (8 or 16 bits per sample, uncompressed or losslessly compressed), JPEG, BMP, GIF, WebP (Python only for the last three).

The image is decoded into an RGB array of floats on a 0–255 scale:

- 8-bit samples keep their integer level `v`.
- 16-bit samples become `v / 257` (so 65535 maps to 255).
- Grey images are replicated into the three channels. Alpha is dropped. Palette images are expanded to RGB.

16-bit colour images are not part of the conformance set: decoders differ in how they reduce them.

## 2. Grey level

`grey = (0.299 * R + 0.587 * G) + 0.114 * B`, evaluated in that order in double precision.

## 3. Block resize

To resize a grey image of `H × W` to `h × w`, output cell `(i, j)` (0-based) is the mean of input rows `r0 ≤ r < r1` and columns `c0 ≤ c < c1`, where

```
r0 = floor(i * H / h)        r1 = max(floor((i + 1) * H / h), r0 + 1)
c0 = floor(j * W / w)        c1 = max(floor((j + 1) * W / w), c0 + 1)
```

No library resampling is used, so every implementation gives the same result.

## 4. Comparison tolerance

All comparisons use `EPS = 1e-6`: `a` is greater than `b` only if `a - b > EPS`. This makes results independent of floating-point summation order.

## 5. Hashes

| Hash | Definition |
| --- | --- |
| `file_sha256` | SHA-256 of the file bytes |
| `pixel_sha256` | SHA-256 of the ASCII header `"{H}x{W}\n"` followed by the RGB levels rounded with `floor(x + 0.5)` to bytes, row-major, channels interleaved |
| `dhash` | Block-resize grey to 8 rows × 9 columns; bit `(i, j)` is 1 if `g[i, j+1] - g[i, j] > EPS`; 64 bits row-major |
| `phash` | Block-resize grey to 32 × 32; `D = C · g · Cᵀ` with `C[k, n] = cos(π (2n + 1) k / 64)`; take the top-left 8 × 8 block row-major; `m` = median of its 63 values after the first; bit is 1 if `value - m > EPS` |

64-bit hashes are written as 16 lowercase hexadecimal characters, first bit most significant. The distance between two hashes is the Hamming distance (0–64).

## 6. Orientations

Eight orientations of the grey image are hashed: `identity`, `rot90`, `rot180`, `rot270` (counter-clockwise), and the same four after a horizontal flip (`flip`, `flip_rot90`, `flip_rot180`, `flip_rot270`; flip first, then rotate).

## 7. Pair classification

For every pair of images (A, B), in this order of precedence:

| Category | Rule |
| --- | --- |
| `identical_file` | equal `file_sha256` |
| `identical_pixels` | equal `pixel_sha256` |
| `similar` | for some orientation `o` of B, `dhash` distance ≤ 10 **and** `phash` distance ≤ 10 between A (identity) and B (orientation `o`); the orientation with the smallest sum of both distances is reported (ties: the order of section 6) |
| `different` | otherwise (not listed in reports) |

Categories describe visual relations, not misconduct. A `similar` pair needs expert review: it may be a legitimate reuse, a control shown twice, or an error.
