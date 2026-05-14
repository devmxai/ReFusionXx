# PIVWSCT-09 Motion, Keyframe, And Effect Stack Unification

Slice: `PIVWSCT-09`  
Plan: `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`  
Date: `2026-05-15`

## Mandatory Pre-Build Evaluation And User Sync Gate

### Current ReFusion state

1. Motion/effect updates were split across legacy adapters and metadata payload
   styles.
2. Unified apply engine existed, but did not own motion channels/effect stack.

### HyperFrames / Remotion comparison

1. HyperFrames motion targets stable elements and updates by identity.
2. Remotion animation/effects are deterministic by frame and identity.
3. ReFusion parity requirement: animation/effect must mutate existing layer
   identity only and remain seek-driven.

### Decision

`upgrade`  
Extend `UnifiedCreativeApplyEngine` as the owner for:
animation recipe lowering, keyframe channels, ordered effect stack updates.

## Implemented

File:
`lib/features/editor/domain/services/unified_creative_apply_engine.dart`

Added:

1. `UnifiedCreativeKeyframe`
2. `UnifiedCreativeMotionChannel`
3. `UnifiedCreativeEffectEntry`
4. node-level fields:
   - `motionChannels`
   - `effectStack`
5. intent handlers:
   - `animationApplyRecipe`
   - `keyframeBatchApply`
   - `effectApply`
6. strict domain preflight:
   - `UNKNOWN_MOTION_RECIPE` fail-closed
   - `TARGET_NOT_FOUND` for update/motion/effect intents
7. recipe lowering for:
   - `popUp`
   - `scaleInBounce`
   - `slideInFromLeft`

Rules now enforced:

1. animation update never creates layer.
2. effect update never creates layer.
3. motion/effect updates require existing `layerId`.
4. same effect type updates existing stack entry unless `explicitStack=true`.

## Tests

File:
`test/unified_motion_effect_unification_test.dart`

Covers:

1. manual shape move then keyframe batch motion starts from moved position.
2. MCP text pop recipe updates same text target (no duplicate layer).
3. effect apply updates existing effect entry; explicit stack allows append.
4. unknown recipe fails closed and does not mutate revision.

## Acceptance Mapping

```text
motion_target_identity_pass = true
effect_target_identity_pass = true
frame_determinism_pass = seed-level deterministic in channel ownership
metadata_only_effect_success_count = 0 (graph mutation required)
```

## Scope Confirmation

No Live Scrub files touched.  
No Stage5 files touched.  
No renderer path touched in this slice.

