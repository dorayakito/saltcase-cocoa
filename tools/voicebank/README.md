# SaltCase Voicebank tools

These tools prepare licensed singing data and package trained Core ML models as
`.scvoice` voicebanks. The application does not train models.

The expected package contains `manifest.json`, `acoustic.mlmodelc`,
`vocoder.mlmodelc`, `phonemes.json`, `timbre.json`, and an optional preview.
Training scripts intentionally fail with a clear message until the project's
chosen ML training stack is installed and configured.
