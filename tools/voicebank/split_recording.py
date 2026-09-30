#!/usr/bin/env python3
"""Split a CV recording into a small SaltCase voicebank source package."""
import argparse
import json
import wave
from pathlib import Path


SEGMENTS = {
    "a": (0.20, 0.85),
    "ga": (0.94, 1.46),
    "za": (1.60, 2.07),
    "da": (2.23, 2.81),
    "ba": (2.92, 3.49),
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    samples = args.output / "samples"
    samples.mkdir(exist_ok=True)

    with wave.open(str(args.source), "rb") as source:
        params = source.getparams()
        if params.nchannels != 1 or params.sampwidth != 2 or params.framerate != 44100:
            raise SystemExit("The source must be mono, signed 16-bit, 44.1 kHz WAV")
        frames = source.readframes(params.nframes)

    frame_width = params.sampwidth * params.nchannels
    entries = []
    for phoneme, (start, end) in SEGMENTS.items():
        first = round(start * params.framerate) * frame_width
        last = round(end * params.framerate) * frame_width
        output = samples / f"{phoneme}.wav"
        with wave.open(str(output), "wb") as target:
            target.setparams(params._replace(nframes=0))
            target.writeframes(frames[first:last])
        entries.append({
            "phoneme": phoneme,
            "audio": f"samples/{phoneme}.wav",
            "startSeconds": start,
            "endSeconds": end,
        })

    manifest = {
        "formatVersion": 1,
        "engine": "saltcase-neural-source",
        "name": "SATURNO CVV source",
        "author": "SATURNO",
        "license": "User-provided recording; verify redistribution permission",
        "language": "pt-BR",
        "sampleRate": 44100,
        "phonemeSet": "saltcase-v1",
        "sourceRecording": args.source.name,
        "phonemes": list(SEGMENTS),
        "segments": entries,
        "status": "source-segments-only",
        "note": "This package contains source segments for training. It is not a runnable Core ML voicebank until acoustic and vocoder models are added."
    }
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Created {len(entries)} source segments in {args.output}")


if __name__ == "__main__":
    main()
