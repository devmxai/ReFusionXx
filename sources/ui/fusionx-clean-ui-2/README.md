# ReFusion

ReFusion is a standalone Flutter project that preserves the editor UI
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

## Architecture Docs

- `docs/live_scrub_migration_mandate.md`: the single binding live scrub
  migration directive for the native scrub engine rebuild
- `docs/professional_direct_text_effects_and_scriptable_motion.md`: the
  unified architecture for direct text effects and scriptable/programmatic
  motion over the shared motion substrate

## Critical Agent Safety Notes

Before touching timeline, canvas, scope, motion, or animation code:

1. read `docs/live_scrub_migration_mandate.md`
2. treat the current `Live Scrub` path as a protected system boundary
3. do not modify protected scrub files as an incidental side effect

Protected scrub path examples:

- `NativeTimelineScrubSurface`
- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`

If any task appears to require a real `Live Scrub` change:

- stop at that boundary
- document the exact dependency and affected files
- propose the smallest possible change
- do not proceed without explicit approval

This rule is strict and applies even when the feature itself is unrelated to
scrub work.

## Checkpoint Workflow

To keep development reversible and stable, ReFusion uses a checkpoint-based
Git workflow instead of pushing unfinished work to `main`.

Rules:

- `main` stays protected as the stable reference line.
- active implementation happens on a dedicated development branch such as
  `codex/professional-canvas-timeline-snapshot`
- every meaningful change is saved as a focused checkpoint commit
- every verified checkpoint commit is pushed to GitHub immediately
- rollback should happen by returning to a known checkpoint, not by rebuilding
  the feature from memory

Recommended cycle for each change:

1. make the scoped code change
2. run the smallest relevant verification (`flutter analyze`, targeted tests,
   build/install when needed)
3. create a checkpoint commit with a clear message
4. push the branch to GitHub right away

Recommended commit style:

- `checkpoint: stabilize scoped timeline interactions`
- `checkpoint: fix playback preview start sync`
- `checkpoint: refine gaussian blur controls`

Rollback options:

- inspect previous checkpoints on the branch and return to a known good commit
- use a new corrective commit or `git revert` instead of rewriting shared
  branch history
- merge to `main` only after the branch behavior is verified on device

This gives the project the same practical safety model used in professional
teams: small verified checkpoints, remote backup after each step, and clean
recovery when a regression appears.

## Run

```bash
flutter pub get
flutter run
```
