"""Command line: reproimage analyze <folder> --out <dir>"""

import argparse
import sys
from datetime import datetime, timezone

from . import __version__
from .analysis import THRESHOLDS, analyze_folder
from .report import write_all


def main(argv=None):
    parser = argparse.ArgumentParser(prog="reproimage", description="Integrity, provenance and reproducibility checks for scientific images.")
    parser.add_argument("--version", action="version", version=f"reproimage {__version__}")
    sub = parser.add_subparsers(dest="command", required=True)
    a = sub.add_parser("analyze", help="Fingerprint every image in a folder and report related pairs")
    a.add_argument("folder")
    a.add_argument("--out", default="reproimage-report", help="Output folder (default: reproimage-report)")
    a.add_argument("--dhash", type=int, default=THRESHOLDS["dhash"], help="Maximum dHash distance for 'similar'")
    a.add_argument("--phash", type=int, default=THRESHOLDS["phash"], help="Maximum pHash distance for 'similar'")
    args = parser.parse_args(argv)

    started = datetime.now(timezone.utc).isoformat(timespec="seconds")
    result = analyze_folder(args.folder, thresholds={"dhash": args.dhash, "phash": args.phash})
    out = write_all(result, args.folder, args.out, started)
    print(f"{len(result['images'])} images, {len(result['pairs'])} related pairs. Report: {out / 'report.html'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
