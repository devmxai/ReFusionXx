# Professional Motion Interpolation Rollout

Status: active rollout plan. Phase 1 started.

This document is the strict implementation plan for upgrading ReFusion motion
interpolation from partial labels to a professional, canonical contract that
can support:

- manual keyframe authoring
- scoped timeline authoring
- AI-authored motion scripts
- preview/runtime evaluation
- export parity

## 0. Non-Negotiable Safety Rules

Before implementing any phase in this document, read:

- `docs/live_scrub_migration_mandate.md`

Protected rule:

- do not modify Stage5 live scrub files as an incidental side effect
- if a phase appears to require a Stage5 change, stop at that boundary and
  request explicit approval

Checkpoint rule:

- every implementation phase must end with:
  - verification
  - a checkpoint commit
  - a push to `codex/professional-canvas-timeline-snapshot`

## 1. Root Diagnosis

The current engine recognizes interpolation kinds such as `spring`, `bounce`,
and `elastic`, but the system is not yet authoritative end to end:

- some import paths downgrade `bounce` or `elastic`
- some runtime evaluators flatten advanced kinds to linear progress
- export parity is not yet implemented for the advanced kinds

This means scripts can be parsed and keyframes can appear correctly while the
resulting motion still looks unprofessional.

## 2. Canonical Direction

ReFusion must use one canonical interpolation contract:

`script/manual authoring -> canonical interpolation spec -> shared evaluator or baked curve data -> preview/runtime/export`

This means:

- no silent downgrade from one interpolation kind to another
- each interpolation kind carries explicit parameters
- preview and export consume the same authored meaning

## 3. Canonical Interpolation Contract

Phase 1 defines the canonical authoring contract only. It does not claim that
every evaluator is already implemented natively.

Supported canonical kinds:

- `hold`
- `linear`
- `easeIn`
- `easeOut`
- `easeInOut`
- `cubicBezier`
- `spring`
- `bounce`
- `elastic`

Canonical parameters:

- `cubicBezier`
  - `x1`, `y1`, `x2`, `y2`
- `spring`
  - `stiffness`, `damping`, `mass`, `initialVelocity`
- `bounce`
  - `amplitude`, `bounces`, `decay`
- `elastic`
  - `amplitude`, `period`, `decay`

## 4. Rollout Phases

### Phase 1: Canonical Contract

Goal:

- add `bounce` and `elastic` parameter payloads to the core interpolation model
- normalize script and preset parsers to preserve those payloads
- propagate the contract through bridge/export models without claiming export
  parity yet

Success criteria:

- no silent downgrade inside core import paths
- scripts and preset JSON can carry canonical bounce/elastic parameters
- metadata/bridge maps preserve the authored payloads

### Phase 2: Unified Curve Evaluator

Goal:

- replace label-only handling with a single authoritative evaluator for
  `spring`, `bounce`, and `elastic`

Success criteria:

- preview/runtime motion visibly differs from linear for those kinds
- the same evaluator is consumed by all Dart-side motion paths

### Phase 3: Import Normalization

Goal:

- make AI/script import consume canonical interpolation consistently and reject
  unsupported ambiguities

Success criteria:

- no parser-specific interpretation drift between preset import and scoped
  script import

### Phase 4: Export Parity

Goal:

- ensure export uses the same authored meaning, either through native evaluator
  parity or canonical baking

Success criteria:

- preview and export match within approved tolerance

### Phase 5: Professional Effect Families

Goal:

- build named professional text effects like `Bounce In` and `Elastic Pop` on
  top of the canonical interpolation primitives

Success criteria:

- AI scripts and manual authoring can both target the same professional motion
  families

## 5. Current Implementation State

As of Phase 1:

- the canonical contract now exists at the model layer
- script and preset import preserve `spring`, `bounce`, and `elastic` payloads
- bridge/export models preserve the authored payloads
- export runtime parity remains intentionally blocked until later phases

## 6. Notes For Agents

If an AI agent is asked to generate a motion script:

- prefer the canonical interpolation kinds listed above
- use parameterized `bounce` and `elastic` objects instead of vague prose
- do not ask for target or layer IDs when the script is intended for the active
  scoped text layer
- remember that Phase 1 establishes authoring fidelity, not final playback
  fidelity
