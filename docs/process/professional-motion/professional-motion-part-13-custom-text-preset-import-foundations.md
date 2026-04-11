# Professional Motion Part 13 - Custom Text Preset Import Foundations

This slice adds the first custom text preset import path without changing the core timeline engine or existing media import flow.

## What changed

- `Text Presets` bottom sheet now supports:
  - compact preset cards
  - built-in presets
  - custom preset cards
  - a dedicated `Add Preset` card
- The first import path is:
  - paste structured preset JSON inside the app
  - parse it into `MotionTextPresetDefinition`
  - add it to the current session catalog
  - render it as a new selectable card

## Why this path

- The current Professional Motion text pipeline already compiles from `MotionTextPresetDefinition`
- the safest extension is to import into that canonical model
- this avoids introducing a second preset runtime
- and keeps future file import identical to the current in-app paste format

## Current accepted input model

- canonical input shape: JSON object
- future file extension target: `.fxtextpreset.json`
- same JSON payload can be used for:
  - paste flow now
  - file import later
  - template library storage later

## Scope

- includes:
  - session-level custom preset catalog
  - JSON parsing/validation
  - custom preset card rendering
  - built-in + custom preset selection
- intentionally excludes:
  - file picker import
  - preset persistence
  - preset editing UI
  - preset deletion UI

## Notes

- this is a product-facing bridge layer, not a redesign
- compile/evaluation/render continue to use the same motion backbone built in parts 1-12
