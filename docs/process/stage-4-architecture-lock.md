# Stage 4 Architecture Lock

Status: `CLOSED`

## Goal

- lock transport, preview, import, processing, and export ownership before real integration work starts

## Official vs Project-Owned Boundary

Official-source-backed responsibilities:

- `BMFLite / BMF`:
  - client-side media processing framework
  - super-resolution
  - denoise
  - native algorithm and buffer pipeline
- `Android Media3`:
  - transport ownership
  - play / pause
  - seek / scrub
  - playback surface handling

Project-owned responsibilities:

- Flutter editor UI
- Flutter timeline presentation
- Flutter tool panels and editor chrome
- Flutter/native bridge contracts
- the integration architecture combining Flutter, Media3, and BMFLite

## Ownership Table

| Area | Owner | Notes |
| --- | --- | --- |
| Transport state | Android native / Media3 | Flutter must not own the playback clock |
| Play / pause / seek / scrub | Android native / Media3 | Flutter issues commands only |
| Preview rendering surface | Android native | Flutter hosts the surface |
| Preview aspect ratio | Native media metadata via integration contract | Display shape follows inserted media, not source-resolution mutation |
| Timeline visual shell | Flutter | UI only until real timeline truth stage |
| Timeline playhead authority | Android native during real transport stage | Flutter reflects current position |
| Import picker ownership | Android native on Android | Flutter triggers the flow and receives normalized results |
| Processing and effects | BMFLite / BMF | Integrated behind native contracts |
| Export orchestration | Project-owned native integration | Must be defined before export stage |

## Locked Rules

- Flutter does not own transport timing
- Flutter does not synthesize fake playback once Stage 5 starts
- preview aspect ratio follows imported media metadata, not arbitrary canvas presets
- import ownership belongs to the native platform path, not generated mock assets
- BMFLite is a processing engine, not the Flutter transport owner

## Hot Reload Policy

- `Hot Reload` is appropriate for Flutter-shell edits:
  - layout
  - widgets
  - styling
  - interaction states that stay inside Dart
- rebuild/redeploy is still required for:
  - Android native code
  - platform-channel changes
  - Media3 integration
  - BMFLite / C++ code
  - Gradle / manifest / native dependency changes

## Closure Judgment

- Stage 4 is closed
- this document is the binding ownership reference for Stage 5 and later integration work

## Next Stage

- `Stage 5 - Native Transport And Preview Integration`
