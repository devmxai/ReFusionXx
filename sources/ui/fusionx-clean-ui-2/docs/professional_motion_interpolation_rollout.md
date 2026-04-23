# Professional Motion Interpolation Rollout

Status: active rollout plan. Phases 1-5 completed for the first professional
text effect family pass. Broader family expansion and visual QA remain ongoing.

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

Implementation state:

- native export now registers `spring`, `bounce`, and `elastic`
- native motion text export reads their parameter payloads
- native scalar-channel and text-animation evaluators use matching curve
  semantics for the advanced interpolation kinds

### Phase 5: Professional Effect Families

Goal:

- build named professional text effects like `Bounce In` and `Elastic Pop` on
  top of the canonical interpolation primitives

Success criteria:

- AI scripts and manual authoring can both target the same professional motion
  families

Implementation state:

- `Bounce In` is a named professional family, not a separate engine:
  - opacity fades in with `easeOut`
  - scale animates from small to final size with canonical `bounce`
  - vertical position rises into place with the same canonical `bounce`
- `Elastic Pop` now defaults to canonical `elastic` instead of a plain
  `easeOut` scale label
- `Rise In` is a spring-based text entrance:
  - opacity fades in with `easeOut`
  - vertical position lifts into place with canonical `spring`
  - subtle scale settles from 96% to 100%
- `Slide In` is a spring-based horizontal entrance:
  - opacity fades in with `easeOut`
  - horizontal position settles into place with canonical `spring`
- `Blur Rise In` is a cinematic text entrance:
  - opacity fades in with `easeOut`
  - blur resolves from soft focus to sharp text
  - vertical position lifts into place with canonical `spring`
  - subtle scale settles from 98% to 100%
- `Rotate In` is a transform-driven entrance:
  - opacity fades in with `easeOut`
  - rotation settles into place with canonical `spring`
  - scale settles into final size with the same canonical `spring`
- script/preset `animationBlocks` can use `bounceIn`, `riseIn`, `slideIn`, or
  `blurRiseIn`, `rotateIn`, or `elasticPop` without manually supplying
  interpolation details
- imported high-level blocks are still lowered into editable real keyframe
  channels, so users can retime or reshape them after import

## 5. Current Implementation State

As of Phase 5:

- the canonical contract now exists at the model layer
- script and preset import preserve `spring`, `bounce`, and `elastic` payloads
- bridge/export models preserve the authored payloads
- Dart-side preview/runtime uses a shared evaluator for:
  - `spring`
  - `bounce`
  - `elastic`
- script import and preset import now share canonical interpolation parsing
- native export registers and evaluates `spring`, `bounce`, and `elastic`
- first named professional effect families now lower into editable canonical
  channels:
  - `bounceIn`
  - `riseIn`
  - `slideIn`
  - `blurRiseIn`
  - `rotateIn`
  - `elasticPop`
- remaining work shifts to adding more families and broader visual QA

## 6. Notes For Agents

If an AI agent is asked to generate a motion script:

- prefer the canonical interpolation kinds listed above
- use parameterized `bounce` and `elastic` objects instead of vague prose
- do not ask for target or layer IDs when the script is intended for the active
  scoped text layer
- do not hand-bake bounce or elastic with many micro keyframes unless the user
  explicitly asks for handcrafted timing
- prefer a small number of readable key poses and attach motion character
  through interpolation objects
- preview/runtime and export now share support for the advanced interpolation
  kinds
- prefer `animationBlocks` with named families like `bounceIn`, `riseIn`,
  `slideIn`, `blurRiseIn`, `rotateIn`, or `elasticPop` when the user asks for a
  direct professional effect
