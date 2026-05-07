# Professional Speed Graph System

Status: official implementation plan  
Internal product name: `SpeedyGraph`  
Package: `com.refusion.app`  
Branch: `codex/unified-keyframe-ops-foundation-20260426`  
Date opened: 2026-05-07  
Scope: Bezier truth, Speed Graph, preset cards, numeric velocity editing, AI-authored motion, preview/liveScrub/playback/export parity, and Motion Blur velocity consumption

## 0. Purpose

This plan defines the professional Speed Graph system for ReFusionXx.

The goal is to make animation timing feel trustworthy and cinematic like professional editors:

```text
After Effects / Premiere / Alight Motion style motion
```

The system must support:

- Easy Ease / F9 style movement.
- Slow -> Fast -> Slow cinematic movement.
- Fast -> Slow -> Fast plateau movement.
- Fast -> Slow deceleration.
- Slow -> Fast acceleration.
- Whip / Snap motion.
- Custom Bezier curve editing.
- Numeric Speed / Influence editing.
- AI script authoring.
- Motion Blur driven by true authored velocity.
- Same curve semantics in preview, liveScrub, playback, and export.

This is not a decorative graph. The graph must control the actual pixels.

## 1. Non-Negotiable Principle

```text
Bezier Control Points are the execution truth.
Speed / Velocity / Influence are inputs or computed views that must compile into Bezier.
```

The engine must never allow this state:

```text
UI writes velocity
but evaluator consumes a different Bezier
```

The approved truth model is:

```text
Preset Card
or Speed Graph drag
or Numeric velocity values
or AI script velocity
        |
        v
MotionBezierVelocityBridge
        |
        v
MotionBezierControlPoints
        |
        v
MotionInterpolationSpec(kind: cubicBezier, bezier: ...)
        |
        v
MasterKeyframeValueEvaluator
        |
        v
valueAt(time), velocityAt(time), accelerationAt(time)
        |
        v
Preview / Live Scrub / Playback / Export / Motion Blur
```

## 2. Critical Architecture Decision

### 2.1 Bezier Is The Only Execution Truth

The evaluator must continue to resolve motion from:

```text
MotionInterpolationSpec.kind
MotionInterpolationSpec.bezier
MotionInterpolationSpec.spring
MotionInterpolationSpec.bounce
MotionInterpolationSpec.elastic
```

For cubic timing, `bezier` is the source that affects rendered motion.

### 2.2 Velocity Is Not Allowed To Be Decorative

`MotionKeyframeVelocity` may remain temporarily as compatibility metadata for import/export/UI display, but it must not be a separate execution truth.

Every write to velocity must either:

```text
compile to Bezier immediately
```

or be rejected with an explicit fallback reason.

Allowed temporary state:

```text
bezier is truth
velocity mirrors bezier for UI/export compatibility
```

Forbidden state:

```text
velocity says customSpeedGraph
bezier still contains old Easy Ease
```

### 2.3 No Hidden copyWith Side Effects

Do not put automatic solver behavior inside generic `copyWith()`.

Use explicit factories/helpers:

```dart
MotionInterpolationSpec.fromVelocityGraph(...)
MotionInterpolationSpec.fromPresetCard(...)
MotionInterpolationSpec.fromBezierTruth(...)
MotionInterpolationSpec.syncBezierAndVelocity(...)
```

This makes every truth conversion auditable and testable.

## 3. Mandatory Project Rules

This plan must follow:

- `docs/professional_checkpoint_policy.md`
- `docs/professional_refusion_motion_keyframe_engine.md`
- `docs/professional_animation_velocity_contracts.md`
- `docs/professional_motion_interpolation_rollout.md`

Protected Live Scrub rule:

```text
Do not touch Stage5 native / Live Scrub protected files unless a phase explicitly requires it and the user approves that exact change.
```

Protected files include:

- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`
- `Stage5PreviewPlatformView`
- Flutter Live Scrub handoff paths

## 4. Checkpoint Policy For This Plan

Every implementation phase must be committed separately.

Commit format:

```text
checkpoint: 2026-05-07 professional speed graph system NN - short description
```

Required sequence:

```text
implement one scoped step
-> run focused tests
-> build if runtime/UI behavior changed
-> install on connected Android device when available
-> stage only focused files
-> commit
-> push
-> report rollback command
```

Rollback format:

```bash
git -C /Users/mx/Documents/ReFusionXx revert <commit-hash>
```

Do not mix unrelated fixes with this plan.

## 5. Visual Standard From The Reference Image

The graph must visually match the professional feel of the reference image.

### 5.1 Canvas Style

```text
background: near-black
grid: subtle gray 1px lines
curve: blue, smooth, rounded caps
handles: green tangent lines
handle dots: green, large enough for touch
keyframe dots: green
aspect ratio: approximately 2:1
```

Recommended values:

```text
background: Color(0xFF0E0E10)
grid: Color(0xFF2A2A2E)
curve: Color(0xFF4DA3FF)
handles: Color(0xFF24E574)
curve stroke: 2.5px
handle stroke: 1.5px
handle visual radius: 8px
touch hit area: 24px minimum
```

### 5.2 Graph Meaning

The graph must not be a decorative painter.

It must draw samples from the actual evaluator:

```text
for t in 0..1:
  y = evaluateMotionCurveProgress(spec, t)
  velocity = evaluateMotionCurveVelocity(spec, t)
```

Value Graph:

```text
x = normalized time
y = normalized value progress
```

Speed Graph:

```text
x = normalized time
y = normalized velocity magnitude
```

The visible curve must match what the engine renders.

## 6. Preset Card System

### 6.1 Required Preset Cards

The first release must include these cards:

```text
1. Linear
2. Easy Ease / F9
3. Slow -> Fast -> Slow
4. Fast -> Slow -> Fast
5. Slow -> Fast
6. Fast -> Slow
7. Whip / Snap
8. Custom Speed Graph
```

The user-requested 2x3 grid can show the primary six:

```text
Easy Ease              Slow -> Fast -> Slow
Fast -> Slow -> Fast   Slow -> Fast
Fast -> Slow           Custom Speed Graph
```

Linear and Whip can appear as secondary cards or chips depending on available space.

### 6.2 Preset Card Data Contract

Create a central preset catalog. Each preset must include:

```text
id
displayName
arabicDisplayName
aliases
description
recommendedUse
bezier
allowsOvershoot
thumbnailSampleCount
```

Example:

```text
id: slowFastSlow
displayName: Slow -> Fast -> Slow
arabicDisplayName: بطيء -> سريع -> بطيء
aliases: slowFastSlow, cinematic, cinematicEaseStrong
bezier: (0.2, 0.0, 0.8, 1.0)
allowsOvershoot: false
recommendedUse: cinematic transitions, rotations, position moves
```

### 6.3 Approved Initial Presets

These values are the initial baseline. They may be tuned only through tests and visual QA.

#### Linear

```text
id: linear
kind: linear
behavior: constant speed
```

#### Easy Ease / F9

```text
id: easyEase
aliases: easyEase, f9, cinematicEase
bezier: (0.3333, 0.0, 0.6667, 1.0)
behavior: balanced slow start, fast middle, slow finish
```

#### Slow -> Fast -> Slow

```text
id: slowFastSlow
aliases: slowFastSlow, cinematic, dramaticEase
bezier: (0.2, 0.0, 0.8, 1.0)
behavior: stronger cinematic ease than Easy Ease
```

#### Fast -> Slow -> Fast

Use a safe plateau baseline first:

```text
id: fastSlowFast
aliases: fastSlowFast, plateau, holdMiddle
bezier: (0.12, 0.72, 0.88, 0.28)
behavior: fast entrance, softer middle, fast exit
```

Do not start with `(0.0, 0.65, 1.0, 0.35)` as the default because exact edge x handles are more sensitive for touch editing and solver behavior. That shape can be an advanced variant after QA.

#### Slow -> Fast

```text
id: slowFast
aliases: slowFast, accelerate, easeIn, whipOut
bezier: (0.65, 0.0, 0.95, 0.1)
behavior: slow buildup, strong exit
```

#### Fast -> Slow

```text
id: fastSlow
aliases: fastSlow, decelerate, easeOut, softLanding
bezier: (0.05, 0.9, 0.35, 1.0)
behavior: strong start, soft landing
```

#### Whip / Snap

```text
id: whipSnap
aliases: whip, whipSnap, snap
bezier: (0.05, 0.0, 0.25, 1.0)
behavior: aggressive quick motion
```

#### Custom Speed Graph

```text
id: customSpeedGraph
behavior: opens the interactive graph using the current Bezier
default: current selected keyframe Bezier, or Easy Ease if no custom curve exists
```

## 7. Bottom Sheet UX

The Graph bottom sheet must use three tabs:

```text
Presets | Custom Curve | Numeric
```

### 7.1 Presets Tab

Displays preset cards.

Card behavior:

```text
Tap:
  apply preset to selected keyframe(s)
  update Bezier truth
  update preview immediately
  keep current playhead time

Long press:
  animate preview dot inside card thumbnail for 2 seconds

Double tap:
  apply preset
  open Custom Curve tab for fine tuning
```

Card selected state:

```text
blue border
checkmark
accessible label
```

### 7.2 Custom Curve Tab

Displays the professional curve editor.

Required:

- grid
- value curve
- speed curve mode
- incoming handle
- outgoing handle
- keyframe dots
- current playhead marker
- selected keyframe marker
- touch-safe drag areas
- snap-to-horizontal option for Easy Ease style handles
- reset button
- apply to selected keyframes

### 7.3 Numeric Tab

Displays exact fields:

```text
outgoingSpeed
incomingSpeed
outgoingInfluence
incomingInfluence
continuous
lockedHandles
```

Any numeric edit must compile through the same Bezier bridge.

## 8. Bezier Velocity Bridge

### 8.1 New Service

Create:

```text
lib/features/editor/domain/services/motion_bezier_velocity_bridge.dart
```

Required API:

```dart
MotionBezierControlPoints velocityToBezier({
  required MotionKeyframeVelocity velocity,
  required double segmentDurationSeconds,
  required double valueDelta,
  bool allowOvershoot = false,
});

MotionKeyframeVelocity bezierToVelocity({
  required MotionBezierControlPoints bezier,
  required double segmentDurationSeconds,
  required double valueDelta,
  String? presetId,
  bool continuous = true,
});

MotionInterpolationSpec interpolationFromVelocityGraph({
  required MotionKeyframeVelocity velocity,
  required double segmentDurationSeconds,
  required double valueDelta,
  required MotionPropertyOvershootPolicy overshootPolicy,
});

MotionInterpolationSpec interpolationFromPresetCard(
  ProfessionalSpeedGraphPreset preset,
);
```

### 8.2 Duration And Value Scaling

The bridge must not assume every curve is normalized forever.

Velocity in UI can be expressed as property units per second. Therefore the conversion must account for:

```text
segmentDurationSeconds
valueDelta
normalized slope
```

Normalized fallback is allowed only when exact property units are unavailable, and must log a fallback reason.

### 8.3 Overshoot Policy

Do not globally allow 200% influence for every property.

Add a policy:

```text
MotionPropertyOvershootPolicy
  - disallow
  - allowBezierOvershoot
  - allowSpringOnly
```

Default:

```text
position: allowBezierOvershoot
scale: allowBezierOvershoot with sane clamp
rotation: allowBezierOvershoot
opacity: disallow
effect amount: disallow unless effect declares support
blur radius: disallow negative overshoot
```

## 9. Engine Integration

### 9.1 Applying A Preset

```text
User taps preset card
-> preset catalog resolves Bezier
-> MotionInterpolationSpec(kind: cubicBezier, bezier: presetBezier)
-> selected keyframe interpolationToNext is updated
-> preview is invalidated for same visible frame
-> Stage5 receives same evaluated value at same timeline time
```

### 9.2 Dragging A Handle

```text
User drags handle
-> UI converts handle position to Bezier control point
-> MotionInterpolationSpec.bezier is updated
-> optional velocity metadata is recomputed from Bezier
-> evaluator samples new curve
-> current frame updates in place
```

### 9.3 Numeric Editing

```text
User edits incomingInfluence
-> velocityToBezier(...)
-> MotionInterpolationSpec.bezier updated
-> graph redraws from evaluator samples
```

### 9.4 AI Script Authoring

Allowed input shapes:

```json
{"velocity": {"preset": "slowFastSlow"}}
```

```json
{"velocity": {"incomingInfluence": 75, "outgoingInfluence": 75}}
```

```json
{"interpolation": {"kind": "cubicBezier", "bezier": {"x1": 0.2, "y1": 0.0, "x2": 0.8, "y2": 1.0}}}
```

```json
{"interpolation": {"kind": "spring", "spring": {"stiffness": 220, "damping": 18}}}
```

All velocity inputs must compile to real `MotionInterpolationSpec` execution data.

## 10. Diagnostics

### 10.1 Preset Proof

Add:

```text
TF_SPEED_GRAPH_PRESET_PROOF
```

Fields:

```text
scope
presetId
aliasesResolved
selectedLaneId
selectedKeyframeId
bezier
curveHash
velocityHash
applied
fallbackReason
```

### 10.2 Bridge Proof

Add:

```text
TF_SPEED_GRAPH_BRIDGE_PROOF
```

Fields:

```text
inputMode: preset | velocityNumbers | bezierDrag | directBezier | aiScript
segmentDurationSeconds
valueDelta
incomingSpeed
outgoingSpeed
incomingInfluence
outgoingInfluence
bezier
overshootPolicy
normalizedFallbackUsed
fallbackReason
```

### 10.3 Graph Edit Proof

Continue or supersede:

```text
TF_VELOCITY_GRAPH_EDIT_PROOF
```

Required final fields:

```text
scope
graphMode
editType
selectedLaneId
selectedKeyframeId
beforeBezier
afterBezier
beforeCurveHash
afterCurveHash
valueAtBefore
valueAtAfter
velocityAtBefore
velocityAtAfter
repositioned
fallbackReason
```

### 10.4 AI Proof

Use:

```text
TF_VELOCITY_AI_SCRIPT_PROOF
```

Do not use `TF_FLOSITY_*`.

Fields:

```text
inputShape
presetId
parsedKind
bezier
curveHash
unsupportedKeys
compiledToExecutionTruth
fallbackReason
```

## 11. Implementation Phases

### Phase SG-01 - Foundation Bridge

Checkpoint:

```text
checkpoint: 2026-05-07 professional speed graph system 01 - bezier velocity bridge foundation
```

Required:

- Add `motion_bezier_velocity_bridge.dart`.
- Add bridge tests.
- Do not change UI yet.
- Do not delete `velocity` field yet.
- Prove velocity input can generate Bezier.
- Prove Bezier can generate display velocity.

Tests:

```text
velocityToBezier easyEase-like zero speeds
bezierToVelocity easyEase round trip
slowFastSlow preset Bezier remains stable
raw velocity numbers change evaluated curve
overshoot policy blocks unsafe properties
```

Acceptance:

```text
No decorative velocity write remains in bridge tests.
No UI behavior changes yet.
Focused tests pass.
```

### Phase SG-02 - Preset Catalog

Checkpoint:

```text
checkpoint: 2026-05-07 professional speed graph system 02 - preset catalog truth
```

Required:

- Add central preset catalog.
- Move preset definitions out of scattered UI switch statements where possible.
- Add `fastSlowFast`.
- Add aliases.
- Keep compatibility with existing preset ids.

Acceptance:

```text
Every preset resolves to exact Bezier.
Every alias resolves to same preset.
No duplicate preset truth tables.
```

### Phase SG-03 - Parser And AI Compilation

Checkpoint:

```text
checkpoint: 2026-05-07 professional speed graph system 03 - ai velocity parser compilation
```

Required:

- Update interpolation parser so velocity numbers compile to Bezier.
- Preserve direct Bezier parsing.
- Preserve spring/bounce/elastic parsing.
- Add `TF_VELOCITY_AI_SCRIPT_PROOF`.

Acceptance:

```text
AI preset input creates real Bezier.
AI velocity number input creates real Bezier.
AI direct Bezier input remains exact.
No silent linear fallback.
```

### Phase SG-04 - Preset Cards UI

Checkpoint:

```text
checkpoint: 2026-05-07 professional speed graph system 04 - preset cards ui
```

Required:

- Add `professional_speed_graph_preset_card.dart`.
- Add `professional_speed_graph_preset_grid.dart`.
- Integrate into Graph bottom sheet `Presets` tab.
- Tap applies Bezier truth.
- Keep playhead and selected keyframe stable.

Acceptance:

```text
Preset cards are visible.
Tap applies curve.
Current frame updates in place.
No playhead jump.
```

### Phase SG-05 - Mini Graph Thumbnails

Checkpoint:

```text
checkpoint: 2026-05-07 professional speed graph system 05 - preset thumbnail previews
```

Required:

- Add thumbnail painter.
- Draw curve from evaluator samples.
- Long press animates a dot along actual curve.

Acceptance:

```text
Thumbnail curve matches engine samples.
Long press preview communicates motion feel.
```

### Phase SG-06 - Custom Curve Canvas

Checkpoint:

```text
checkpoint: 2026-05-07 professional speed graph system 06 - custom curve canvas
```

Required:

- Add professional graph painter.
- Add graph canvas widget.
- Add touch-safe handle dragging.
- Draw from evaluator samples.
- Drag updates Bezier directly.

Acceptance:

```text
Graph visually matches reference style.
Handle drag changes Bezier.
Evaluator output changes immediately.
No decorative graph path.
```

### Phase SG-07 - Numeric Panel

Checkpoint:

```text
checkpoint: 2026-05-07 professional speed graph system 07 - numeric velocity panel
```

Required:

- Add numeric panel.
- Edits compile through bridge.
- Display values are computed from Bezier.

Acceptance:

```text
Numeric influence edits change Bezier.
Bezier edits update numeric values.
No mismatch between panel and curve.
```

### Phase SG-08 - Runtime Parity

Checkpoint:

```text
checkpoint: 2026-05-07 professional speed graph system 08 - runtime curve parity
```

Required:

- Prove same curve hash in preview/liveScrub/playback/export.
- Do not touch protected Stage5 files unless explicitly approved.
- Use existing adapters where possible.

Acceptance:

```text
Same keyframe curve produces same valueAt and velocityAt across paths.
No silent fallback.
```

### Phase SG-09 - Motion Blur Velocity Consumption

Checkpoint:

```text
checkpoint: 2026-05-07 professional speed graph system 09 - motion blur speed graph consumption
```

Required:

- Motion Blur reads velocity derived from Bezier/evaluator truth.
- Slow -> Fast -> Slow creates weak blur at start/end and strong blur in middle.
- Fast -> Slow creates strongest blur near start.
- Slow -> Fast creates strongest blur near end.

Acceptance:

```text
Motion Blur follows authored Speed Graph.
No fake Gaussian blur.
No overlay path.
No bitmap/proof path.
```

### Phase SG-10 - Save Custom Presets

Checkpoint:

```text
checkpoint: 2026-05-07 professional speed graph system 10 - custom preset persistence
```

Required:

- Save custom preset as Bezier truth.
- Load custom preset.
- Show `My Presets` section.

Acceptance:

```text
Saved custom preset applies identical curve to another keyframe.
Export/import preserves Bezier.
```

### Phase SG-11 - Closure QA

Checkpoint:

```text
checkpoint: 2026-05-07 professional speed graph system 11 - closure qa
```

Required:

- Run focused tests.
- Build debug APK.
- Install on connected wireless Android device.
- Capture diagnostics.
- Update this plan status.

Acceptance:

```text
All phases verified.
No TF_FLOSITY_* remains.
Graph controls real engine motion.
Preset cards, custom graph, numeric panel, AI scripts, Motion Blur, and export share one curve truth.
```

## 12. Required Tests

Add or update tests for:

```text
motion_bezier_velocity_bridge_test.dart
professional_speed_graph_preset_catalog_test.dart
motion_interpolation_contract_test.dart
professional_motion_interpolation_evaluator_test.dart
master_keyframe_value_evaluator_test.dart
transition_focus_value_write_adapter_test.dart
manual_transition_lane_to_motion_channel_adapter_test.dart
refusion_scene_program_lowerer_test.dart
export_composition_builder_test.dart
universal_motion_engine_guard_test.dart
```

Critical assertions:

```text
UI handle drag changes Bezier.
Bezier change changes valueAt and velocityAt.
Preset card applies expected Bezier.
Velocity numbers compile to Bezier.
Direct Bezier remains exact.
Motion Blur directive changes when curve velocity changes.
Preview/liveScrub/playback/export curve hashes match.
No TF_FLOSITY_* diagnostics remain.
No silent linear fallback.
```

## 13. Manual QA Checklist

On device:

```text
1. Add two rotation keyframes.
2. Open Graph.
3. Apply Easy Ease.
4. Confirm motion starts slow, speeds up, ends slow.
5. Apply Slow -> Fast -> Slow.
6. Confirm stronger cinematic middle speed.
7. Apply Fast -> Slow.
8. Confirm quick start and soft landing.
9. Drag custom handles.
10. Confirm current frame updates in place.
11. Enable Motion Blur.
12. Confirm blur follows speed curve.
13. Play from same frame as live scrub.
14. Confirm semantic parity.
15. Export test clip.
16. Confirm exported motion matches preview semantics.
```

## 14. Stop List

Do not:

- Build more graph UI before SG-01 bridge exists.
- Store velocity as a second execution truth.
- Put hidden solver behavior inside generic `copyWith()`.
- Use UI-only easing labels.
- Add fake preset names without exact Bezier.
- Draw graph curves from decorative approximations.
- Allow AI scripts to write fields that do not affect motion.
- Globally allow overshoot for unsafe properties.
- Touch protected Live Scrub files without explicit approval.
- Mix Motion Tile, Rotation, or unrelated FX fixes into this plan.
- Leave old `TF_FLOSITY_*` diagnostics.
- Claim export parity without tests.

## 15. Final Acceptance

The Professional Speed Graph System is complete only when:

```text
Bezier is the execution truth.
Velocity inputs compile to Bezier.
Preset Cards apply real Bezier curves.
Custom Curve drag writes real Bezier.
Numeric panel reads/writes through the bridge.
AI scripts compile to the same curve truth.
Motion Blur consumes evaluator-derived velocity.
Preview/liveScrub/playback/export share curve semantics.
Graph visuals are sampled from the real evaluator.
No decorative graph path remains.
No silent fallback remains.
```

In one sentence:

```text
SpeedyGraph is a professional Bezier-truth graph system where every visible card, handle, numeric value, AI script, preview frame, Motion Blur trail, and export frame resolves from the same curve.
```
