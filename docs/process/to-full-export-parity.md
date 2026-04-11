# To Full Export Parity

Status: `ACTIVE`

Type: `standalone full export expansion plan`

Starting point:

- first Android export baseline is now working through `Media3 Transformer`
- export now has:
  - canonical `ExportComposition`
  - native bridge and manager
  - output validation
  - file handoff (`open/share/save`)
  - preset ladder foundation
  - scalar speed foundation

This plan starts **after** the first working export baseline.

## Priority Order

1. `Preset + scalar speed hardening`
2. `Motion/text render contract`
3. `Image/audio track parity`
4. `Effects + transitions render parity`
5. `Quality/performance/backend hardening`

## Phase 1: Preset And Scalar Speed Hardening

Status:

- `FOUNDATION IMPLEMENTED`
- `device acceptance still pending`

Goal:

- make current export quality and speed behavior reliable enough to be treated as a supported layer, not a hidden extension

Includes:

- real-device validation for:
  - `720p`
  - `1080p`
  - `Original`
- real-device validation for:
  - `0.25x`
  - `0.5x`
  - `1.0x`
  - `2.0x`
  - `4.0x`
- confirm duration truth, audio presence, and resolution truth after speed changes
- confirm no unexpected frame-rate explosion on fast clips

Exit criteria:

- preset output dimensions are deterministic
- scalar speed export is accepted for `normal` mode clips
- export validation remains green after speed/preset combinations

## Phase 2: Motion/Text Render Contract

Status:

- `ACTIVE`

Goal:

- move `motion/text` export from summary metadata into a real render contract

Includes:

- export payload must carry:
  - element timing
  - text animation timing
  - effect timing
  - transition timing
- native side must receive a renderable contract rather than just counts
- keep this contract separate from preview-only state

Current checkpoint:

- Flutter export payload now carries a structured motion render contract with:
  - scenes
  - layers
  - elements
  - source bindings
  - property assignments
  - property channels
  - keyframes
  - interpolation specs
- Flutter now also prepares a sampled `motion text render track` for export
  from the existing motion evaluator/render adapter path
- export sheet now surfaces this contract explicitly in diagnostics
- native side now parses and reports explicit motion/text/effects/transitions counts
  plus richer contract counts such as scenes/channels/cameras
- native export now has first `CanvasOverlay` wiring for text-only motion export
- remaining renderer gap is no longer “missing wiring”, but:
  - device acceptance
  - richer text styling parity
  - effects/transitions/camera parity

Exit criteria:

- export payload is rich enough to drive a renderer for motion/text
- unsupported motion/text content is blocked by explicit reason, not by missing structure

## Phase 3: Image/Audio Track Parity

Goal:

- move beyond video-only export

Status:

- `IMAGE FOUNDATION IMPLEMENTED`
- `SINGLE AUDIO-TRACK FOUNDATION IMPLEMENTED`

Includes:

- imported image clips
- imported audio-only clips
- audio presence/mute policy
- multi-track timeline truth for non-video media

Exit criteria:

- video + image + audio timelines export correctly with canonical ordering and duration

## Phase 4: Effects And Transition Parity

Goal:

- export visible creative intent, not just clip assembly

Includes:

- motion effects
- transition windows
- text animation rendering
- timing correctness for effect ranges

Important:

- this is the first phase where `Media3 baseline` may stop being enough by itself
- if effect parity becomes too constrained, this is the point where `BMF` becomes an implementation candidate rather than a distant option

Exit criteria:

- effects and transitions render in export with acceptable parity against the editor

## Phase 5: Backend And Quality Hardening

Goal:

- move from “feature complete export” to “professional export”

Includes:

- better preset ladder enforcement
- bitrate/codec policy review
- export performance profiling
- stress validation on larger timelines
- decision point:
  - remain on `Media3` for current scope
  - or open `BMF` backend for advanced parity

Exit criteria:

- export path is stable, measurable, and ready for wider feature load

## Current Recommendation

The next correct implementation slice is:

`Phase 2 foundation: motion/text render contract`

Reason:

- preset ladder and scalar speed already have code foundations
- the biggest architectural gap now is that `motion/text/effects/transitions` still do not cross the export bridge as a renderable contract
- closing that contract first avoids building the later renderer on top of summary-only metadata
