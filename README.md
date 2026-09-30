# SaltCase Cocoa

Native macOS vocal editor and synthesizer built with Objective-C and AppKit. **SaltCase Cocoa** is the Cocoa implementation of SaltCase, featuring a piano roll, per-note expression editing, MIDI support, and initial UTAU/OpenUtau interoperability.

> **Current status:** functional prototype under active modernization. SaltCase was largely dormant for approximately 14 years and is gradually coming back to life. The editing core, project persistence, and MIDI/USTX import are operational. The new neural runtime is integrated, but a trained `.scvoice` voicebank is not bundled yet, so audible synthesis is not available in a clean checkout.

[Repository](https://github.com/dorayakito/saltcase-cocoa) · [Issues](https://github.com/dorayakito/saltcase-cocoa/issues) · [OpenUtau](https://github.com/stakira/OpenUtau)

![SaltCase Cocoa editor](assets/saltcase-editor.png)

*Current editor: piano roll, timeline ruler, transport controls, and expression panel.*

SaltCase Cocoa continues the work started by SugarCape, originally created for Japanese vocal composition. This codebase focuses on a native macOS workflow with fast editing, clear visual feedback, and keyboard shortcuts inspired by modern vocal editors such as OpenUtau.

### A project coming back to life

SaltCase spent roughly 14 years without active development. The current work is a gradual revival rather than a finished rewrite: some legacy behaviors, incomplete workflows, compatibility issues, and ordinary bugs remain. Feedback, reproducible bug reports, and small contributions are especially valuable as the project is brought back to life one subsystem at a time.

## Contents

- [Features](#features)
- [Supported formats](#supported-formats)
- [Getting started](#getting-started)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Building](#building)
- [Architecture](#architecture)
- [Neural voicebanks](#neural-voicebanks)
- [Known limitations](#known-limitations)
- [Contributing](#contributing)
- [License](#license)

## Features

### Piano roll

- Select, Pencil, and Erase tools.
- Multi-selection with `Shift` and rectangular selection with `Option` + drag.
- Note movement, resizing, and transposition.
- Configurable snapping, zoom, and a timeline ruler at the top of the editor.
- Playhead navigation by clicking or dragging the timeline ruler.
- Document-integrated undo and redo.
- Copy, cut, and paste preserving position, duration, lyrics, phonemes, volume, vibrato, and pitch bend.
- Visual feedback for selection, hover, volume, and pitch bend.

### Playback and synthesis

- Real-time Play/Stop controls.
- Tempo range from 40 to 320 BPM.
- Loop, metronome, and playback volume controls.
- A local Core ML synthesis runtime designed for SaltCase neural voicebanks.
- Audio export through the formats supported by the system.

### Per-note expressions

The bottom expression panel provides editing for:

- lyrics;
- custom phonemes;
- volume;
- vibrato;
- pitch bend.

Expression values are persisted in the project and used when audio events are generated.

### Interface

- Modern toolbar using native macOS visual effects.
- Responsive expression panel.
- Minimum window size to prevent control clipping.
- Visual indicators for the active tool and playback state.
- Dark piano-roll grid with alternating pitch rows and emphasized beats.

## Supported formats

| Format | Open/import | Export | Notes |
| --- | :---: | :---: | --- |
| SaltCase project | Yes | Yes | Versioned JSON, `.scase` extension |
| Standard MIDI | Yes | Yes | `.mid` and `.midi`, notes and velocity |
| OpenUtau USTX | Yes | No | `.ustx`, basic BPM, position, duration, tone, and lyric import |

SaltCase projects use `formatVersion: 2`. Projects created by future versions are rejected explicitly to prevent silent data loss.

## Getting started

1. Open the project in Xcode or build it from the command line.
2. Run the app from `build/Build/Products/Debug/SaltCase.app`.
3. Draw notes with the Pencil tool or open a `.scase`, `.mid`, `.midi`, or `.ustx` file.
4. Select a note to edit its lyric, phoneme, and expression values in the bottom panel.
5. Use the timeline ruler above the piano roll to navigate the playhead.
6. Install a compatible `.scvoice` voicebank when available.
7. Press `Space` to start playback.

> A clean checkout currently opens and edits projects normally, but does not include a trained neural voicebank. Playback displays `Neural voicebank required` until one is installed.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `Space` | Play/stop |
| `1`, `2`, `3` | Select, Pencil, Erase |
| `Shift` + click | Add to selection |
| `Option` + drag | Rectangular selection |
| `Delete` / `Backspace` | Delete selected notes |
| `⌘ C`, `⌘ X`, `⌘ V` | Copy, cut, paste |
| `⌘ Z` / `⇧⌘ Z` | Undo/redo |
| Arrow keys | Transpose notes |
| `⌘` + ↑/↓ | Transpose one octave |
| `⌘` + ←/→ | Move notes in time |
| `Option` + ←/→ | Change note duration |
| `P` | Toggle snapping |
| `Q` / `E` | Zoom out/in |
| Click/drag the ruler | Navigate the playhead |

## Building

### Requirements

- macOS 12 Monterey or later;
- Xcode 27 or later;
- an Apple Silicon or Intel Mac supported by the installed Xcode version.

### Build the app

```sh
xcodebuild \
  -project SaltCase.xcodeproj \
  -scheme SaltCase \
  -configuration Debug \
  -derivedDataPath build \
  build
```

The app is generated at `build/Build/Products/Debug/SaltCase.app`.

```sh
open build/Build/Products/Debug/SaltCase.app
```

### Run tests

```sh
xcodebuild \
  -project SaltCase.xcodeproj \
  -scheme SaltCase \
  -configuration Debug \
  -derivedDataPath build \
  test
```

The test suite covers persistence, expression limits, audio events, pitch bend, project versioning, and basic USTX import.

## Architecture

```text
SCDocument
├── Versioned JSON persistence
├── MIDI / USTX import
├── SCNote
│   └── lyric, phoneme, volume, vibrato, pitch bend
└── SCCompositionController
    ├── Toolbar and expression panel
    ├── SCPianoRoll
    │   ├── editing and selection
    │   ├── snapping, zoom, and timeline
    │   └── undo/redo and clipboard
    └── SCSynth
        └── SCNeuralSynthEngine
            ├── SCNeuralVoiceBank
            ├── acoustic Core ML model
            └── vocoder Core ML model
```

SaltCase Cocoa is an Objective-C/AppKit application using Cocoa, AudioToolbox, QuartzCore, and UniformTypeIdentifiers. The shared Xcode scheme is stored in `SaltCase.xcodeproj/xcshareddata/xcschemes` for consistent builds across machines.

The synthesis boundary is now independent from the editor: `SCAudioEvent` carries musical and expressive conditioning, while `SCNeuralSynthEngine` consumes a SaltCase `.scvoice` package. A voicebank contains an acoustic Core ML model and a vocoder Core ML model. The repository currently includes the runtime contracts and packaging tools, but not a trained voicebank or training dataset; playback is intentionally silent until a compatible voicebank is installed.

Voicebank tooling is located in [`tools/voicebank`](tools/voicebank). The application never trains models, accesses the network, or silently falls back to the retired WAV sampler.

## Neural voicebanks

SaltCase uses its own `.scvoice` package format. A package contains:

```text
MyVoice.scvoice/
├── manifest.json
├── acoustic.mlmodelc
├── vocoder.mlmodelc
├── phonemes.json
├── timbre.json
└── preview.m4a
```

The manifest identifies the voice, language, sample rate, supported phonemes, model files, and expressive controls. Voicebanks are local and offline; SaltCase does not download models or train voices inside the application.

The packaging and dataset validation entry points are documented in [`tools/voicebank/README.md`](tools/voicebank/README.md). A small source-segment fixture from the Victor BrApa recording is available at [`voicebanks/Victor-BrApa.scvoice`](voicebanks/Victor-BrApa.scvoice), containing `a`, `ga`, `za`, `da`, and `ba`. A trained, redistributable demo voice is still required before synthesis can be enabled in a fresh installation.

## Known limitations

- USTX import is intentionally basic and does not yet preserve multiple tracks, voicebanks, advanced phonemization, or complete expression curves.
- A trained `.scvoice` package is not bundled yet, so the neural renderer reports a missing voicebank and produces silence until one is installed.
- The Core ML input/output contract is intentionally versioned through `manifest.json`; model training and export are still separate work.
- Some components inherited from the original XIB may still emit deprecation warnings on recent macOS versions.
- The main interface is macOS-specific; mobile support is not part of this stage.

## Contributing

1. Create a branch for your change.
2. Keep the project buildable.
3. Add or update tests when changing models, importers, or synthesis.
4. Run `xcodebuild ... test` before opening a pull request.
5. Clearly describe changes to formats, shortcuts, or visual behavior.

Issues and pull requests are welcome, especially for USTX/MIDI import improvements, voicebanks, accessibility, and interface testing.

## License

MIT License

Copyright © 2012 Sota Yokoe.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
