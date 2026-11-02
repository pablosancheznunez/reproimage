"""Outputs: JSON, CSV, RO-Crate provenance and a self-contained HTML report."""

import base64
import csv
import html
import io
import json
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image

CATEGORY_TEXT = {
    "identical_file": "Identical files",
    "identical_pixels": "Identical pixels, different files",
    "similar": "Visually similar",
}


def write_json(result, path):
    Path(path).write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def write_csv(result, path):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["a", "b", "category", "orientation", "dhash_distance", "phash_distance"])
        w.writeheader()
        w.writerows(result["pairs"])


def write_ro_crate(result, folder, out_dir, started, ended):
    """RO-Crate 1.1 metadata describing the analysis as a CreateAction (W3C PROV compatible)."""
    tool = result["tool"]
    files = [{"@id": f"input/{im['name']}", "@type": "File", "name": im["name"], "sha256": im["file_sha256"]} for im in result["images"]]
    graph = [
        {"@id": "ro-crate-metadata.json", "@type": "CreativeWork", "conformsTo": {"@id": "https://w3id.org/ro/crate/1.1"}, "about": {"@id": "./"}},
        {
            "@id": "./",
            "@type": "Dataset",
            "name": "ReproImage analysis",
            "datePublished": ended,
            "hasPart": [{"@id": "result.json"}, {"@id": "pairs.csv"}, {"@id": "report.html"}],
            "mentions": {"@id": "#analysis"},
        },
        {
            "@id": "#analysis",
            "@type": "CreateAction",
            "name": "Fingerprint images and classify pairs",
            "instrument": {"@id": "#reproimage"},
            "object": [{"@id": f["@id"]} for f in files],
            "result": [{"@id": "result.json"}, {"@id": "pairs.csv"}, {"@id": "report.html"}],
            "startTime": started,
            "endTime": ended,
            "description": f"Input folder: {Path(folder).name}. Parameters: {json.dumps(result['parameters'])}.",
        },
        {
            "@id": "#reproimage",
            "@type": "SoftwareApplication",
            "name": "ReproImage",
            "version": tool["version"],
            "url": "https://github.com/pablosancheznunez/reproimage",
            "description": f"Algorithm version {tool['algorithm_version']}",
        },
        {"@id": "result.json", "@type": "File", "encodingFormat": "application/json"},
        {"@id": "pairs.csv", "@type": "File", "encodingFormat": "text/csv"},
        {"@id": "report.html", "@type": "File", "encodingFormat": "text/html"},
        *files,
    ]
    (Path(out_dir) / "ro-crate-metadata.json").write_text(json.dumps({"@context": "https://w3id.org/ro/crate/1.1/context", "@graph": graph}, indent=2) + "\n", encoding="utf-8")


def _thumbnail(path, size=220):
    with Image.open(path) as img:
        img.seek(0)
        if img.mode.startswith("I"):
            img = img.point(lambda v: v / 257).convert("L")
        img = img.convert("RGB")
        img.thumbnail((size, size))
        buf = io.BytesIO()
        img.save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def write_html(result, folder, path):
    esc = html.escape
    thumbs = {im["name"]: _thumbnail(Path(folder) / im["name"]) for im in result["images"]}
    rows = []
    for p in result["pairs"]:
        detail = "" if p["category"] != "similar" else f"orientation {esc(p['orientation'])}, dHash distance {p['dhash_distance']}, pHash distance {p['phash_distance']}"
        rows.append(
            f'<article class="pair"><h3>{esc(CATEGORY_TEXT[p["category"]])}</h3><p class="meta">{detail}</p>'
            f'<div class="sbs"><figure><img src="{thumbs[p["a"]]}" alt=""><figcaption>{esc(p["a"])}</figcaption></figure>'
            f'<figure><img src="{thumbs[p["b"]]}" alt=""><figcaption>{esc(p["b"])}</figcaption></figure></div></article>'
        )
    images = "".join(
        f"<tr><td>{esc(im['name'])}</td><td>{im['width']}×{im['height']}</td><td>{esc(str(im['metadata']['format']))}, {im['metadata']['bit_depth']}-bit</td>"
        f"<td>{esc(str(im['metadata']['software'] or ''))}</td><td><code>{im['file_sha256'][:16]}…</code></td><td><code>{im['dhash']}</code></td></tr>"
        for im in result["images"]
    )
    tool = result["tool"]
    page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>ReproImage report</title>
<style>
:root {{ --bg:#fbfaf8; --surface:#fff; --text:#1d1c1a; --muted:#5f5c57; --line:#e2dfda; --warn:#9a6400; color-scheme: light dark; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg:#171716; --surface:#211f1e; --text:#ece9e4; --muted:#a7a29b; --line:#3a3734; --warn:#f0b44c; }} }}
body {{ margin:0; background:var(--bg); color:var(--text); font:16px/1.5 system-ui, sans-serif; }}
main {{ max-width:960px; margin:0 auto; padding:24px 16px 48px; }}
.caveat {{ border-left:4px solid var(--warn); background:var(--surface); padding:12px 16px; }}
.pair {{ background:var(--surface); border:1px solid var(--line); border-radius:8px; padding:12px 16px; margin:12px 0; }}
.pair h3 {{ margin:0; font-size:1rem; }}
.sbs {{ display:flex; gap:16px; flex-wrap:wrap; }}
figure {{ margin:0; }} figcaption, .meta {{ color:var(--muted); font-size:.85rem; }}
img {{ max-width:220px; height:auto; image-rendering:pixelated; border:1px solid var(--line); }}
.scroll {{ overflow-x:auto; }} table {{ border-collapse:collapse; font-size:.85rem; width:100%; }}
td, th {{ text-align:left; border-bottom:1px solid var(--line); padding:4px 8px; }}
</style></head><body><main>
<h1>ReproImage report</h1>
<p class="meta">{len(result['images'])} images · {len(result['pairs'])} related pairs · ReproImage {esc(tool['version'])}, algorithm version {tool['algorithm_version']} · thresholds {esc(json.dumps(result['parameters']['thresholds']))}</p>
<div class="caveat"><strong>Requires expert review.</strong> These are visual relations between images, not evidence of misconduct. A similar pair may be a legitimate reuse, a control shown twice, or an error.</div>
<h2>Related pairs</h2>
{''.join(rows) or '<p>No identical or similar pairs were found.</p>'}
<h2>Images</h2>
<div class="scroll"><table><tr><th>File</th><th>Size</th><th>Format</th><th>Software</th><th>SHA-256</th><th>dHash</th></tr>{images}</table></div>
</main></body></html>
"""
    Path(path).write_text(page, encoding="utf-8")


def write_all(result, folder, out_dir, started):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    ended = datetime.now(timezone.utc).isoformat(timespec="seconds")
    write_json(result, out / "result.json")
    write_csv(result, out / "pairs.csv")
    write_html(result, folder, out / "report.html")
    write_ro_crate(result, folder, out, started, ended)
    return out
