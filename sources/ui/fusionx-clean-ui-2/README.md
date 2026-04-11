# FusionX Clean UI 2

FusionX Clean UI 2 is a standalone Flutter project that preserves the editor UI
shell from the original FusionX editor while intentionally excluding all media
backend logic.

## Scope

This project contains:

- editor screen layout
- top bar, tools bar, timeline, media dock, and bottom sheet UI
- mock local state used only to present the interface

This project does not contain:

- Rust engine
- preview backend
- playback engine
- export pipeline
- native media player
- platform channels for media control
- networking or persistence layers

## Goal

The purpose of this repository is to keep a clean, reusable UI-only baseline so
the playback, rendering, audio, and export engine can be rebuilt separately
from a fresh foundation.

## Product Direction

FusionX is intended to evolve into a professional native video editor with:

- a real native playback/render engine on Android
- a real native playback/render engine on iOS
- Flutter used for UI only
- native media execution handled per platform
- editor-grade transport, preview, audio, and export behavior

The current repository is the clean UI starting point for that rebuild.

## Native Engine Vision

Planned direction after this clean baseline:

- Android:
  - native video engine
  - native audio engine
  - GPU compositor
  - export pipeline
- iOS:
  - native video engine
  - native audio engine
  - GPU compositor
  - export pipeline

The target is an editor-quality experience with smooth preview, synchronized
audio, accurate seeking, and native performance on both platforms.

## Notes

- The preview area is a mock canvas for UI presentation only.
- Timeline and library content are mock data.
- Any play/pause behavior in this project is visual demo behavior only and not
  real media playback.

## Run

```bash
flutter pub get
flutter run
```
