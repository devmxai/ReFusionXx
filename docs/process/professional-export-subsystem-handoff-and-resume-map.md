# Professional Export Subsystem Handoff And Resume Map

Last updated: April 10, 2026

Status: `ACTIVE HANDOFF REFERENCE`

Type: `subsystem resume map`

Timeline relation note:

- export/effects remains intentionally paused at this handoff point
- later pushed timeline work through `BETA1` does not change the export resume
  order recorded here

Purpose:

- freeze the exact current export/effects state before switching focus to
  timeline work
- make future return to `effects / transitions / camera / compositor / audio`
  explicit instead of guess-based
- define the correct resume point for each export subsystem independently

Primary references:

- [Professional Export Audit Gap And Cleanup Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-audit-gap-and-cleanup-plan.md)
- [Professional Effects Render And Export Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-effects-render-and-export-plan.md)
- [Professional Export System Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-system-plan.md)
- [Export Current-Stage Closure Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/export-current-stage-closure-plan.md)
- [Remaining Path To Full Export Parity](/Users/mx/Documents/InGeneBMFPro/docs/process/remaining-path-to-full-export-parity.md)

## Overall State

The export system now has:

- a real `Media3 Transformer` baseline backbone
- a real `ExportComposition` and `canonicalEffectsGraph`
- a real deterministic motion-text lane
- a first isolated authored-surface GL blur/effect stack for motion text
- a real compositor-aware routing model
- a first authored non-text surface program and runtime evaluator

The export system still does **not** yet have:

- a full professional authored effects engine for all asset types
- full `transition` execution
- full `camera` execution
- a final multi-layer authored visual compositor
- a full audio graph / curve speed export engine

## Resume Rules

When export work resumes later:

1. do **not** reopen preset-level tuning first
2. resume from the subsystem entry below
3. only widen support through shared backend lanes
4. keep `Media3` as the backbone unless a later documented gate proves it
   insufficient

## Subsystem Status Map

### 1. Motion Text Effects And Blur

Current status: `partially executable, partially accepted`

What is landed:

- deterministic `motionTextProgram`
- `motionTextRasterContract`
- `motionTextRasterProgram`
- shaped full-text layout in preview/export
- first isolated overlay-sequence GL effect stack for:
  - `GaussianBlur`
  - `AlphaScale`
- blur diagnostics now expose:
  - execution mode
  - GL sigma
  - decision code/detail

What is still open:

- blur parity is improved but not closed as final professional truth
- common authored cases still fall back outside the narrow GL slice
- broader authored-surface backend ownership is still needed

Correct resume point:

- resume from `broaden isolated authored-surface backend ownership`
- not from tuning one text preset

Next real task:

- promote the current text-only isolated surface lane into a generic
  `authored-surface effects backend`

### 2. Image / Shape / Mask / Video Authored Surfaces

Current status: `modeled + bridged + runtime-evaluable, not yet rendered through the professional backend lane`

What is landed:

- `visualCompositorGraph` now emits real non-text authored overlay segments
- `authoredVisualSurfaceProgram` now exists end-to-end
- Android preflight verifies compositor-owned non-text segments against program
  nodes
- Android now has a first time-resolved authored-surface runtime evaluator
- export UI now exposes `Authored Surfaces` runtime diagnostics

What is still open:

- no final isolated surface renderer/backend lane yet
- no blur/effect execution parity yet for `image/shape`
- no final authored layer compositing path yet

Correct resume point:

- start from `backend routing decision` for authored non-text surfaces
- then connect those nodes to the same isolated effects backend lane

Next real task:

- route `image/shape` through the first shared `surface-effect eligible`
  execution path

### 3. Canonical Effects Graph

Current status: `read in native path, partially execution-relevant, not yet final execution truth`

What is landed:

- graph exists in `ExportComposition`
- native preflight/export now reads it
- unsupported categories now fail honestly from graph truth
- UI now exposes `Canonical Effects` diagnostics

What is still open:

- graph is still more `execution-aware diagnostics truth` than full backend
  driving truth
- transition/camera/effect routing is not yet executed from graph semantics

Correct resume point:

- promote graph output into backend routing adapters, not only blockers and
  diagnostics

### 4. Visual Compositor

Current status: `routing truth exists, final compositor runtime does not`

What is landed:

- `visualCompositorGraph`
- window plans
- media vs authored ownership separation
- motion-text overlay windows separated from authored non-text windows

What is still open:

- no final authored multi-layer compositor backend
- no final blend/compositing parity
- no real shared authored-surface renderer for `text + image + shape` together

Correct resume point:

- resume from `authored surface backend ownership`
- then build the wider compositor lane above it

### 5. Transitions

Current status: `modeled only`

What is landed:

- transitions exist in normalized motion/canonical graph planning truth
- graph diagnostics can block unsupported transition execution honestly

What is still open:

- no real transition runtime evaluation lane
- no compositor transition window execution
- no encoded export parity for transitions

Correct resume point:

- start from `canonical transition -> compositor window execution adapter`
- do not start from UI polish or visual tuning

### 6. Camera

Current status: `modeled only`

What is landed:

- camera nodes/operations exist in canonical graph truth
- camera presence is now blocked honestly when unsupported

What is still open:

- no runtime camera evaluation lane
- no camera-aware compositor ownership
- no camera export parity

Correct resume point:

- start from `canonical camera ops -> authored visual compositor routing`

### 7. Audio Graph And Speed/Time Remap

Current status: `baseline-only`

What is landed:

- baseline optional single-audio-lane export
- constant speed baseline for current clip export scenarios

What is still open:

- curve speed export
- richer audio graph/mix semantics
- final time-remap parity across authored layers and media

Correct resume point:

- start from `audio graph + curve speed execution adapter`

### 8. Validation, Diagnostics, And Cleanup

Current status: `strong but not closed`

What is landed:

- motion/text parity diagnostics
- canonical effects diagnostics
- authored surfaces diagnostics
- visual assembly diagnostics

What is still open:

- pixel-diff style acceptance for strong visual cases
- broader device acceptance matrix
- monolith cleanup, especially in
  [Stage6ExportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt)

Correct resume point:

- keep diagnostics honest
- widen backend support first
- close with device/pixel acceptance after execution lanes are in place

## Recommended Future Resume Order

If export work resumes after timeline work, the correct order is:

1. widen `authored-surface backend routing`
2. connect `image/shape` to the shared isolated effects lane
3. widen compositor-backed authored surface ownership
4. move supported effects from partial `CanvasOverlay` truth into the shared
   backend lane
5. open `transition`
6. open `camera`
7. open `audio graph + curve speed`
8. close with device acceptance and visual validation

## Anti-Regression Notes

When export work resumes later, do not:

- re-open preset-by-preset blur tuning as the main strategy
- claim `image/shape` export parity before they run through the shared backend
- claim `transition` support from graph presence alone
- claim `camera` support from modeling truth alone
- close the export file while authored-surface execution truth is still split
  per asset type
