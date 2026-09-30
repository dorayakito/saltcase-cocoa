#!/usr/bin/env python3
"""Validate a minimal SaltCase voicebank dataset manifest."""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("dataset", type=Path)
    args = parser.parse_args()
    manifest = args.dataset / "dataset.json"
    if not manifest.is_file():
        raise SystemExit("dataset.json is required")
    data = json.loads(manifest.read_text(encoding="utf-8"))
    if data.get("license") in (None, "", "unknown"):
        raise SystemExit("dataset.json must declare an explicit license")
    entries = data.get("items", [])
    if not entries:
        raise SystemExit("dataset.json must contain at least one item")
    for index, item in enumerate(entries):
        for key in ("audio", "phonemes", "pitch"):
            if key not in item:
                raise SystemExit(f"dataset item {index} is missing {key}")
    print(f"Validated {len(entries)} licensed dataset items")


if __name__ == "__main__":
    main()
