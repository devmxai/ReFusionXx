# Professional Animation Velocity Contracts

Status: official implementation plan  
Package: `com.refusion.app`  
Branch: `codex/unified-keyframe-ops-foundation-20260426`  
Date opened: 2026-05-07  
Scope: animation smoothness, keyframe velocity, Easy Ease, Speed Graph, preview/liveScrub/playback/export parity

## Closure Status (2026-05-07)

Velocity contracts are now the runtime source of truth across Graph editing,
evaluation parity diagnostics, Motion Blur velocity bridging, and export
interpolation payloads.

Completed closure checkpoints on this branch:

- `09` legacy cleanup and evaluator velocity bridge (`65c2f3e`)
- `10` motion blur visual velocity polish (`140140e`)
- `11` agent scene velocity authoring (`036c7c0`)
- `12` export velocity parity (`75d4a10`)

This plan is now in closure QA mode. Any follow-up work must build on these
checkpoints with the same sequential policy from Section 1.

## 0. Name And Intent

`Animation Velocity Contracts` is the ReFusion engine plan for the professional
combination of:

```text
flow + velocity + temporal influence
```

This plan makes animation speed a first-class engine contract, not a UI-only
label. The goal is to make ReFusion motion feel closer to professional tools
such as After Effects:

```text
slow start -> fast middle -> smooth slow finish
```

This must apply to:

- position
- scale
- rotation
- opacity
- effect parameters
- transition parameters
- Motion Blur velocity
- generated scene/program motion
- AI-authored motion patches
- preview
- liveScrub
- playback
- export

## 1. Mandatory Checkpoint Rule

Every implementation step under this plan must create a focused GitHub
checkpoint before the next step begins.

This is mandatory, not optional polish.

Required order:

```text
implement one scoped build step
-> run focused tests
-> build if runtime behavior changed
-> install on connected Android device when available
-> stage only focused files
-> commit with sequential checkpoint name
-> push branch
-> report rollback command
```

### 1.1 Sequential Checkpoint Naming

Checkpoint commit names must be sequential and date-stamped.

Format:

```text
checkpoint: YYYY-MM-DD professional animation velocity contracts NN - short description
```

Examples:

```text
checkpoint: 2026-05-07 professional animation velocity contracts 01 - domain velocity model
checkpoint: 2026-05-07 professional animation velocity contracts 02 - curve evaluator parity
checkpoint: 2026-05-07 professional animation velocity contracts 03 - easy ease operations
checkpoint: 2026-05-07 professional animation velocity contracts 04 - speed graph ui contract
checkpoint: 2026-05-07 professional animation velocity contracts 05 - motion blur velocity integration
```

Rules:

- Do not skip numbers.
- Do not reuse a number.
- Do not combine unrelated work in one checkpoint.
- If checkpoint `03` breaks behavior, rollback target is clearly `02`.
- The final response after every step must include:
  - branch
  - commit hash
  - commit message
  - files changed
  - tests/build/install results
  - rollback command

Minimum rollback command:

```bash
git -C /Users/mx/Documents/ReFusionXx revert <commit-hash>
```

### 1.2 Dirty Worktree Protection

Before every checkpoint:

```bash
git -C /Users/mx/Documents/ReFusionXx status -sb
```

Only stage files related to the current numbered step. Existing unrelated
diagnostic files, screenshots, local experiments, or user work must not be
staged.

## 2. Professional References

This plan follows the professional animation model used by After Effects:

- Linear interpolation changes at a constant rate and can look mechanical.
- Bezier/Auto Bezier/Continuous Bezier create smoother temporal changes.
- Easy Ease automates keyframe speed easing.
- Speed Graph controls acceleration and deceleration between keyframes.
- Keyframe Velocity uses speed plus influence.

Reference anchors:

- Adobe keyframe interpolation:
  `https://helpx.adobe.com/after-effects/using/keyframe-interpolation.html`
- Adobe speed graph and Easy Ease:
  `https://helpx.adobe.com/after-effects/using/speed.html`
- Adobe Graph Editor learning path:
  `https://www.adobe.com/mena_en/learn/after-effects/web/adjusting-keyframes-dynamic-movement`

## 3. Current ReFusion Foundation

ReFusion already has useful foundations:

```text
MotionInterpolationSpec
MotionInterpolationKind
MotionBezierControlPoints
evaluateMotionCurveProgress(...)
MotionPropertyChannelModel
MotionKeyframeModel
MasterKeyframeValueEvaluator
Professional motion interpolation rollout
```

Existing supported interpolation kinds:

```text
hold
linear
easeIn
easeOut
easeInOut
cubicBezier
spring
bounce
elastic
```

Existing Easy Ease parsing:

```text
easyEase -> cubicBezier(0.3333, 0.0, 0.6667, 1.0)
```

This is a good start, but it is not enough for After Effects-level motion.

## 4. Root Diagnosis

The current model mainly stores interpolation labels and value progress.

It does not yet make these concepts first-class everywhere:

```text
incoming velocity
outgoing velocity
incoming influence
outgoing influence
speed graph handles
velocityAt(time)
accelerationAt(time)
roving keyframes
preview/liveScrub/playback/export curve parity
Motion Blur consuming authored velocity
```

Resulting user-visible problems:

- animation can look mechanical or stepped,
- rotation can feel uneven even when values are correct,
- Motion Blur may not match the true authored speed curve,
- slow live scrub and playback can feel different,
- Graph controls can appear as UI but not fully change engine semantics,
- agents can author keyframes but cannot reliably author professional speed.

## 5. Core Rule

Animation speed must become engine truth.

Required canonical path:

```text
authoring command
-> MotionPropertyChannelModel
-> MotionKeyframeModel
-> MotionAnimationVelocityContract
-> MotionCurveSegment
-> ProfessionalMotionCurveEvaluator
-> valueAt(time)
-> velocityAt(time)
-> preview/liveScrub/playback/export/MotionBlur
```

Forbidden:

```text
UI-only easing labels
preview-only curve behavior
liveScrub-only curve shortcuts
export-only interpolation downgrades
Motion Blur deriving fake velocity when authored velocity exists
Graph controls that do not update keyframe velocity contracts
```

## 6. Canonical Domain Contract

### 6.1 New Contract: MotionKeyframeVelocity

Add a first-class velocity payload to keyframes or keyframe segment metadata.

Model:

```text
MotionKeyframeVelocity
  incomingSpeed
  outgoingSpeed
  incomingInfluence
  outgoingInfluence
  incomingHandleLocked
  outgoingHandleLocked
  continuous
  roving
  presetId
```

Units:

```text
position: px/sec
rotation: deg/sec or rad/sec, canonicalized internally
scale: percent/sec or scalar/sec, canonicalized internally
opacity: percent/sec
effect amount: units/sec based on property definition
color: component/sec or normalized progress derivative
```

### 6.2 New Contract: MotionVelocityPreset

The engine must support named professional speed presets.

Required initial presets:

```text
linear
easyEase
easyEaseIn
easyEaseOut
slowFastSlow
fastSlow
slowFast
smoothStop
smoothStart
whipSnap
cinematicEase
customSpeedGraph
```

### 6.3 New Contract: MotionCurveSegment

Each pair of adjacent keyframes must lower into a segment:

```text
MotionCurveSegment
  channelId
  fromKeyframeId
  toKeyframeId
  startTime
  endTime
  fromValue
  toValue
  interpolation
  velocityContract
  valueKind
  units
  continuityMode
```

The evaluator must not guess semantics from the UI.

## 7. Easy Ease F9 Contract

### 7.1 Required User Behavior

When selected keyframes receive Easy Ease:

```text
F9 / Easy Ease
```

the keyframes must become professional temporal Bezier keyframes.

Default After Effects-inspired behavior:

```text
incomingSpeed = 0
outgoingSpeed = 0
incomingInfluence = 33.333
outgoingInfluence = 33.333
continuous = true
```

### 7.2 Easy Ease Modes

Required commands:

```text
applyEasyEase(selectedKeyframes)
applyEasyEaseIn(selectedKeyframes)
applyEasyEaseOut(selectedKeyframes)
removeEase(selectedKeyframes)
setKeyframeVelocity(selectedKeyframes, velocityContract)
```

Semantics:

```text
Easy Ease:
  affects incoming and outgoing handles where valid

Easy Ease In:
  affects incoming handle only

Easy Ease Out:
  affects outgoing handle only
```

### 7.3 Existing Cubic Bezier Compatibility

Existing `easyEase` parsing as:

```text
cubicBezier(0.3333, 0.0, 0.6667, 1.0)
```

may remain as a compatibility approximation, but the new authoritative model
must store velocity/influence as explicit data.

## 8. Speed Graph Contract

### 8.1 Bottom Dock Graph Modes

The existing `Graph` bottom dock must support:

```text
Value Graph
Speed Graph
```

Speed Graph is the professional default for transition motion refinement.

### 8.2 Speed Graph UI Must Edit Engine Data

Dragging speed handles must write:

```text
incomingSpeed
outgoingSpeed
incomingInfluence
outgoingInfluence
continuous / split handles
```

It must not only reshape a display curve.

### 8.3 Required Speed Preset Buttons

Inside Graph controls:

```text
Linear
Easy Ease
Ease In
Ease Out
Slow-Fast-Slow
Fast-Slow
Slow-Fast
Whip
Custom
```

### 8.4 Speed Graph Diagnostics

Every edited graph operation must be able to log:

```text
TF_VELOCITY_GRAPH_EDIT_PROOF
channelId
propertyPath
selectedKeyframeIds
graphMode
presetId
incomingSpeed
outgoingSpeed
incomingInfluence
outgoingInfluence
continuous
valueAtBefore
valueAtAfter
velocityAtBefore
velocityAtAfter
previewRevision
fallbackReason
```

## 9. Unified Curve Evaluator

### 9.1 Required API

Create or upgrade the central evaluator to provide:

```text
valueAt(channel, time)
velocityAt(channel, time)
accelerationAt(channel, time)
segmentAt(channel, time)
sampleCurve(channel, startTime, endTime, fps)
```

### 9.2 Required Parity

The same evaluator must feed:

```text
MasterKeyframeValueEvaluator
Stage5 runtime state
Motion Blur velocity compiler
Live Scrub visual program
playback preview
export bridge
AI/script import preview
```

### 9.3 No Silent Downgrades

If a curve kind is unsupported in a target path:

```text
block with explicit fallbackReason
```

Do not silently convert to linear.

## 10. Motion Blur Integration

Motion Blur must use authored velocity when available.

Required:

```text
MotionBlurVelocityCompiler
  reads valueAt(time)
  reads velocityAt(time)
  reads angularVelocityAt(time)
  reads scaleVelocityAt(time)
```

This is essential because professional Motion Blur is only as good as the
motion curve. A linear or mismatched velocity source will always make blur feel
less cinematic.

Diagnostics:

```text
TF_VELOCITY_MB_VELOCITY_PROOF
timelineTimeMs
propertyPath
valueAtTime
velocityAtTime
angularVelocityAtTime
scaleVelocityAtTime
speedGraphPreset
sampleCount
shutterAngle
motionBlurDirectiveHash
fallbackReason
```

Acceptance:

- slow-fast-slow rotation produces weak blur at start/end and strong blur in
  the middle,
- liveScrub and playback agree at the same frame,
- changing speed graph changes Motion Blur shape without separate fake sliders.

## 11. AI And Documentation Contract

Agents must be able to author professional motion speed intentionally.

Required JSON shape:

```json
{
  "target": "layer:video-1",
  "property": "transform.rotation",
  "keyframes": [
    { "timeMs": 0, "value": 0 },
    { "timeMs": 600, "value": 360 }
  ],
  "velocity": {
    "preset": "slowFastSlow",
    "outInfluence": 85,
    "inInfluence": 85,
    "continuous": true
  }
}
```

Required aliases:

```text
easyEase
f9
slowFastSlow
speedGraph
velocityGraph
cinematicEase
whip
smoothStop
smoothStart
```

Unsupported or ambiguous input must produce clear validation errors.

## 12. Implementation Phases

Each phase below is one checkpoint or a small group of tightly related
checkpoints. Every checkpoint must use the sequential commit naming rule from
section 1.

### Phase 01: Domain Velocity Model

Goal:

- add the canonical velocity/influence contract,
- keep old interpolation specs backward compatible,
- avoid any UI or native changes.

Likely files:

```text
professional_motion_animation_models.dart
professional_motion_interpolation_parsing.dart
export_composition_models.dart
```

Tests:

```text
motion_interpolation_model_test.dart
motion_interpolation_parsing_test.dart
export_composition_builder_test.dart
```

Checkpoint:

```text
checkpoint: YYYY-MM-DD professional animation velocity contracts 01 - domain velocity model
```

### Phase 02: Curve Evaluator With Velocity

Goal:

- implement `valueAt`, `velocityAt`, and `accelerationAt`,
- support velocity/influence,
- keep old progress evaluator working through compatibility adapters.

Likely files:

```text
professional_motion_interpolation_evaluator.dart
professional_motion_runtime_helpers.dart
master_keyframe_value_evaluator.dart
```

Tests:

```text
professional_motion_interpolation_evaluator_test.dart
master_keyframe_value_evaluator_test.dart
```

Acceptance:

- `easyEase` starts and ends at near-zero velocity,
- `slowFastSlow` peaks near segment center,
- linear remains constant speed.

Checkpoint:

```text
checkpoint: YYYY-MM-DD professional animation velocity contracts 02 - curve evaluator velocity
```

### Phase 03: Easy Ease Authoring Operations

Goal:

- add formal operations for Easy Ease / Easy Ease In / Easy Ease Out,
- apply to selected keyframes across supported scopes,
- preserve selection and current frame.

Likely files:

```text
unified_keyframe_operations.dart
professional_canvas_timeline_authoring_models.dart
transition_unified_scope_keyframe_adapter.dart
```

Acceptance:

- selected keyframes get real velocity contracts,
- F9-style Easy Ease can be applied without changing keyframe time/value,
- no global refresh or playhead jump.

Checkpoint:

```text
checkpoint: YYYY-MM-DD professional animation velocity contracts 03 - easy ease operations
```

### Phase 04: Speed Graph UI Contract

Goal:

- add `Speed Graph` mode to the existing Graph bottom dock,
- expose professional presets,
- allow handle/influence editing.

Likely files:

```text
fusionx_clean_ui_screen.dart
timeline_panel.dart
graph editor / bottom dock components
```

Protected boundary:

This phase may touch UI and preview submission paths. Do not touch protected
Live Scrub native files unless the user explicitly approves that exact change.

Acceptance:

- Graph can switch between Value Graph and Speed Graph,
- preset buttons write real velocity data,
- Speed Graph reflects selected keyframes,
- current visible frame stays locked during edits.

Checkpoint:

```text
checkpoint: YYYY-MM-DD professional animation velocity contracts 04 - speed graph controls
```

### Phase 05: Runtime Parity Bridge

Goal:

- feed the same curve evaluator into preview, liveScrub, playback, and export,
- prove no mode is using a different curve approximation.

Diagnostics:

```text
TF_VELOCITY_PARITY_PROOF
adapterMode
timelineTimeMs
channelId
propertyPath
valueAtTime
velocityAtTime
curveHash
velocityHash
matchesPreview
matchesPlayback
matchesLiveScrub
fallbackReason
```

Acceptance:

- same frame has same value/velocity in liveScrub and playback,
- no frame A value with frame B velocity,
- no hidden linear fallback.

Checkpoint:

```text
checkpoint: YYYY-MM-DD professional animation velocity contracts 05 - runtime parity bridge
```

### Phase 06: Motion Blur Velocity Integration

Goal:

- make Motion Blur consume `velocityAt(time)` from Velocity contracts,
- stop deriving professional blur from approximate adjacent-frame deltas when
  authored velocity is available.

Likely files:

```text
motion_blur_velocity_compiler.dart
Stage5MotionBlurShaderPass.kt
Stage5PreviewPlatformView.kt
```

Protected boundary:

This phase touches Stage5 visual runtime behavior. It requires explicit user
approval before native Live Scrub files are edited.

Acceptance:

- slow-fast-slow rotation gives cinematic blur,
- start/end blur is light,
- middle blur is strong,
- liveScrub/playback/export use the same authored velocity meaning.

Checkpoint:

```text
checkpoint: YYYY-MM-DD professional animation velocity contracts 06 - motion blur velocity integration
```

### Phase 07: Agent And Scene Program Integration

Goal:

- allow agents and scene programs to author Velocity presets directly,
- validate and lower into editable keyframes.

Likely files:

```text
refusion_scene_program_import_service.dart
refusion_motion_patch_applicator.dart
professional_motion_director_engine docs/tests
```

Acceptance:

- agent-authored `slowFastSlow` becomes real velocity graph data,
- imported motion remains editable,
- no unsupported speed preset is silently downgraded.

Checkpoint:

```text
checkpoint: YYYY-MM-DD professional animation velocity contracts 07 - agent velocity authoring
```

### Phase 08: Export Parity

Goal:

- export consumes the same value/velocity semantics as preview,
- unsupported native curves are baked explicitly rather than downgraded.

Acceptance:

- exported spin transition matches preview timing,
- Easy Ease and Speed Graph survive export,
- export contract reports all used Velocity kinds.

Checkpoint:

```text
checkpoint: YYYY-MM-DD professional animation velocity contracts 08 - export parity
```

## 13. Acceptance Criteria

The plan is complete only when:

- every animated property can use Velocity contracts,
- Easy Ease F9 works as real velocity/influence data,
- Speed Graph edits engine state, not only UI display,
- slow-fast-slow transition motion is available as a preset,
- liveScrub and playback match at the same frame,
- Motion Blur follows authored speed curves,
- agents can author speed graph presets,
- export preserves the same timing,
- all phases have numbered GitHub checkpoints.

## 14. Stop List

Do not:

- add another fake animation layer,
- create a separate speed system for transitions only,
- make Easy Ease a UI-only toggle,
- make Speed Graph a display-only graph,
- let Motion Blur ignore authored velocity,
- silently downgrade unsupported curves,
- mix Motion Blur, Motion Tile, and Velocity in one checkpoint,
- commit untracked diagnostics or unrelated user work.

## 15. First Build Instruction For Codex 5.3

Start with Phase 01 only.

Do not touch UI.
Do not touch Stage5.
Do not touch Live Scrub native files.

Implement the domain contract and tests, then checkpoint:

```text
checkpoint: YYYY-MM-DD professional animation velocity contracts 01 - domain velocity model
```

Only after Phase 01 is verified and pushed should Phase 02 begin.
