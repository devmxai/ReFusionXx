# Unified Timeline Presentation Authoring Rules

Status: active authoring contract  
Applies to: timeline authoring agents and editor wiring slices under `PUTP`

## 1. Default User Journey

Use this as the primary editor path:

```text
Composition Timeline
-> select layer row
-> double tap row
-> focused Keyframe Motion Timeline
```

Do not require users to navigate multiple scope timelines for normal edits.

## 2. Layer Taxonomy

Unified timeline rows must map to exactly one type:

- `Solid Layer`
- `Media Layer`
- `Text Layer`
- `Shape Layer`
- `Audio Layer`
- `Adjustment Layer`

`Adjustment Layer` is presentation-only and must reuse existing transition/effect
engines through adapters.

## 3. Double-Tap Focus Rules

- Text/media/shape rows: route to focused keyframe timeline.
- Scene rows: route to Scene Scope fallback.
- Adjustment rows: route to adjustment controls (unified transition scope bridge
  when available).
- Audio rows: show explicit unsupported diagnostic.

## 4. Guardrails

Under `PUTP`, do not modify:

- Stage5/Live Scrub runtime paths
- keyframe evaluator
- effect evaluator
- renderer/export engines
- `TimelinePanel` visual design

Only adapter/projection/routing layers are allowed.

## 5. Feature Flag Contract

`UnifiedTimelinePresentationFlags.rolloutMode` is the rollout owner:

- `off`: production fallback path
- `internal`: internal routing only
- `beta`: controlled rollout
- `stable`: default routing

Any new routing slice must preserve clean fallback when mode is `off`.
