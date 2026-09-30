#!/usr/bin/env python3
"""Package two compiled Core ML models into a .scvoice directory."""
import argparse
import json
import shutil
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--acoustic", type=Path, required=True)
    parser.add_argument("--vocoder", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--name", default="SaltCase Voice")
    parser.add_argument("--author", default="Unknown")
    parser.add_argument("--language", default="und")
    args = parser.parse_args()
    for model in (args.acoustic, args.vocoder):
        if not model.exists():
            raise SystemExit(f"Missing model: {model}")
    args.output.mkdir(parents=True, exist_ok=True)
    shutil.copytree(args.acoustic, args.output / "acoustic.mlmodelc", dirs_exist_ok=True)
    shutil.copytree(args.vocoder, args.output / "vocoder.mlmodelc", dirs_exist_ok=True)
    manifest = {
        "formatVersion": 1,
        "engine": "saltcase-neural",
        "name": args.name,
        "author": args.author,
        "language": args.language,
        "sampleRate": 44100,
        "phonemeSet": "saltcase-v1",
        "models": {"acoustic": "acoustic.mlmodelc", "vocoder": "vocoder.mlmodelc"},
        "phonemes": [],
        "controls": ["pitch", "duration", "volume", "vibrato", "pitchBend", "timbre"]
    }
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Created {args.output}")


if __name__ == "__main__":
    main()
