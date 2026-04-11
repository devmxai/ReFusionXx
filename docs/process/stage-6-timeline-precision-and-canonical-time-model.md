# Stage 6 - Timeline Precision And Canonical Time Model

## Status

Approved planning reference.

Foundation linkage:

- this timeline precision work is the exact editor foundation for future:
  - motion scripts
  - keyframes
  - structured motion JSON
  - export normalization
- reference:
  [Stage 6 Foundation Reference - Canonical Timeline Truth For Future Motion, Script, And Export Layers](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-foundation-reference-canonical-timeline-truth-for-future-motion-script-export.md)

This document defines the professional path to reach timeline/playhead/split precision that is owned by the editor itself, not approximated by preview behavior.

This plan is based on:

- current project code review
- official `Media3` constraints
- official `BMF/FFmpeg` time-model constraints
- standard NLE semantics inferred from mainstream editors

This document does **not** claim hidden internal knowledge about `CapCut` or `VN`.
Where those products are mentioned, the comparison is behavioral only.

## Target

The target is not merely "smooth preview".

The target is:

- one canonical editor time model
- one canonical playhead coordinate
- one canonical cut point
- exact structural edits
- exact timeline geometry
- preview/runtime that follow editor truth instead of redefining it

In professional terms:

- the playhead position must be a real timeline coordinate
- `split` must cut at that exact coordinate
- `delete` must remove exactly that timeline range
- the visible seam, the playhead, and the runtime projection must all refer to the same canonical time

## What 100% Precision Means

For this project, "100% precision" must mean all of the following:

- the timeline owns one authoritative time coordinate system
- the playhead is represented in that coordinate system exactly
- each clip has exact source windows
- a split point is stored exactly, not inferred later from floating-point display state
- timeline geometry may style clips, but it must not redefine clip time
- preview approximation during drag may exist, but it may never overwrite timeline truth
- export and future BMF processing must consume the same truth

## Current Precision Gaps In The Codebase

Current project review shows these structural gaps:

1. timeline time is still represented mainly as `double seconds`
2. Flutter and native repeatedly convert between:
   - `double seconds`
   - rounded milliseconds
   - back to `double seconds`
3. clip UI geometry is not fully time-linear because media clips enforce a minimum width
4. seam and cut markers are derived from rendered clip width, not only from canonical timeline time
5. preview behavior and timeline truth are still closer together than they should be

This means the current app can become usable, but it is not yet architected for exact professional time ownership.

## Official Constraints We Must Respect

### Media3

Official `Media3` constraints matter:

- exact seeking has decoder cost
- clip starts are not guaranteed to be seamless if they are not keyframe-safe
- repeated exact boundary seeks can be expensive and unstable if misused

Therefore:

- `Media3` can serve preview/transport
- but `Media3` must not be asked to define editor truth

### BMF / FFmpeg

Official `BMF` documentation states that `BMF` is fully compatible with FFmpeg capabilities and standards, including indicators consistent with `pts`, `duration`, `fps`, and related values.

This matters because the future export/processing path must align with:

- rational time bases
- exact timestamp math
- explicit source windows

Therefore:

- the editor should move toward an FFmpeg-like / `CMTime`-like time model
- not toward more floating-point seconds

## Canonical Time Model Recommendation

The professional recommendation is:

- stop using `double seconds` as the domain model for edit truth
- introduce a canonical rational/integer time type

Recommended shape:

- `TimelineTime(value, timescale)`
- or an equivalent exact integer tick model with explicit timescale

This should behave like:

- Apple `CMTime`
- FFmpeg `pts * time_base`

### Why This Is Required

`double seconds` are convenient for UI, but they are not the right source of truth for:

- split points
- trim points
- repeated structural edits
- mixed frame rates
- later export correctness

If the project stays on floating-point seconds, it will keep getting "close to correct" instead of becoming exact.

## Required Precision Contract

After the migration, the editor must satisfy this contract:

1. `playheadTime` is a canonical timeline coordinate
2. each clip stores exact source range:
   - `sourceIn`
   - `sourceOut`
3. each clip also has an exact timeline placement
4. `split` creates two exact source windows at the playhead coordinate
5. `delete` removes an exact timeline range and ripples neighbors immediately
6. preview is a projection of truth
7. export is a projection of truth

There must be no separate hidden truth inside preview code.

## Execution Plan

### Phase P1 - Canonical Time Type Lock

Goal:

- introduce a project-owned exact time type for editor truth

Required outcome:

- timeline state no longer depends on `double seconds`
- exact edit coordinates are representable without floating-point drift

Implementation direction:

- replace edit-domain `duration/sourceOffsetSeconds/currentSeconds` truth with exact time objects
- keep `double seconds` only for labels and user-facing formatting where needed

### Phase P2 - Exact Edit Domain Migration

Goal:

- migrate `TimelineClipData` and all edit operations to exact time ownership

Required outcome:

- `split`
- `trim`
- `delete`
- `duplicate`
- ripple behavior

all operate on exact timeline/source coordinates, not rounded display state

Implementation direction:

- store exact source windows instead of approximate durations only
- make all structural edit math integer/rational only

### Phase P3 - Exact Flutter/Native Projection Contract

Goal:

- make Flutter-to-native transport preserve exact edit truth

Required outcome:

- Flutter sends exact source windows and exact target timeline coordinates
- native preview receives a projection of exact truth
- rounding for player API boundaries is isolated and explicit

Implementation direction:

- split "editor truth" from "preview seek target"
- send exact values in one contract
- send rounded preview targets separately only where the player API requires it

### Phase P4 - Time-Exact Timeline Geometry

Goal:

- make visible timeline geometry derive from canonical time, not from approximated clip width

Required outcome:

- playhead position
- cut marker position
- seam marker position
- hit testing

all derive from the same canonical timeline coordinate system

Important rule:

- `minimum-width clip rendering` may remain for readability
- but it must become paint-only styling
- it must not redefine the real time position of cuts or seams

### Phase P5 - Preview Policy Separation

Goal:

- separate timeline truth from preview approximation

Required outcome:

- during drag/scrub:
  - preview may use throttling/coalescing
- on settle/release:
  - preview must land on the exact canonical coordinate
- preview approximation must never modify editor truth

### Phase P6 - Source Indexing And Frame Policy

Goal:

- define how frame-accuracy is interpreted across mixed media

Required outcome:

- explicit snap policy:
  - free time
  - frame snap
  - source-frame snap
- keyframe/index metadata path for preview and export

This is where the project decides:

- what "exact cut" means on compressed long-GOP media
- what must be guaranteed in preview
- what must be guaranteed in export

### Phase P7 - BMF / Export Alignment

Goal:

- ensure future export uses the same truth model

Required outcome:

- exact source windows and timeline mappings project directly into future `BMF/FFmpeg` export
- no second export-only timeline truth is created

## Non-Negotiable Rules

- no new floating-point edit truth
- no preview-owned timeline truth
- no UI geometry that redefines time
- no seam polish work that changes canonical edit coordinates
- no export-specific truth separate from preview truth

## Practical Product Guidance

From a professional editor perspective, the correct mental model is:

- editor truth first
- exact geometry second
- preview policy third
- seam polish after truth is stable

Not the reverse.

## Immediate Next Step

The next professional implementation step is:

- migrate the active `Stage 6 / Track B` work so that `Phase 2B` explicitly requires one canonical timeline coordinate for:
  - playhead
  - split point
  - seam marker
  - runtime projection

Then begin the exact time-model migration instead of adding more local fixes around `double seconds`.
