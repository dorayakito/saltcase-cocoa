saltcase
========

Open source Japanese vocal software

Written by [@sugarcape](http://twitter.com/sugarcape)

## Overview

SaltCase is a Japanese vocal software for Mac OS X. 
It is a successor to [SugarCape](http://sugarcape.net/), which has been developed since 2009 by [@sugarcape](http://twitter.com/sugarcape).

## Requirements

1. macOS 12 Monterey or later.
2. Xcode 27 or later for development.

## Building

Open the project in Xcode or build it from Terminal:

    xcodebuild -project SaltCase.xcodeproj -scheme SaltCase -configuration Debug -derivedDataPath build build

The application is generated at build/Build/Products/Debug/SaltCase.app.

## Tests

Run the XCTest suite with:

    xcodebuild -project SaltCase.xcodeproj -scheme SaltCase -configuration Debug -derivedDataPath build test

## Editor shortcuts

- Space: play or stop.
- 1, 2, 3: selection, pencil and eraser tools.
- Shift + click: add to the selection.
- Option + drag: select notes with a rectangle.
- Delete / Backspace: delete selected notes.
- Command + C, X, V: copy, cut and paste.
- Command + Z / Shift + Command + Z: undo and redo.
- Arrow keys: transpose selected notes.
- Command + Up/Down: transpose one octave.
- Command + Left/Right: move notes in time.
- Option + Left/Right: change note duration.
- P: toggle grid snapping.
- Q / E: zoom out/in.
- Timeline ruler: click or drag at the top of the piano roll to move the playhead.

## Current editor features

SaltCase currently supports:

- modern macOS editor controls and responsive tool panels;
- multi-note piano-roll editing;
- undo/redo, copy/paste, snapping and zoom;
- tempo, play/stop, loop, metronome and volume controls;
- per-note volume, vibrato, pitch bend, lyrics and phonemes;
- note color intensity communicates volume, while hue reflects pitch bend;
- copy/paste preserves all note expression data;
- MIDI import and export;
- JSON project persistence with backward-compatible defaults.
- opening `.mid`/`.midi` files and importing basic `.usxt` OpenUtau projects;

## License

MIT License

Copyright (c) 2012 Sota Yokoe

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
