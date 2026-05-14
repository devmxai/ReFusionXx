# Pre-Build Report

Slice ID: `PUCTAS-05A.TIMELINE-PROJECTION-PROOF-CONTRACT`

Date: `2026-05-14`

## Goal

Add an explicit runtime timeline-projection validator to ACK proof generation so
`timelineVisible` / `rendererApplied` reflect target projection truth, not only
optimistic apply intent.

## Current ReFusion State Before Slice

1. ACK proof is built from apply receipt + generic flags.
2. `timelineVisible` can be true without validating each target id projection.
3. `rendererApplied` can be true from broad apply state instead of explicit
   target projection completeness.
4. This weakens timeline truth guarantees for multi-target or partially
   represented command batches.

## Reference Comparison

HyperFrames lesson adopted:

- Editing must map back to a stable patch target; projection truth is explicit.

Remotion lesson adopted:

- Identity/state updates are deterministic and verifiable against known
  composition targets.

## Gap List Closed By This Slice

1. No dedicated timeline projection validator in MCP runtime ACK path.
2. No proof fields for target projection completeness and missing target ids.
3. No tests asserting projection-aware proof override behavior.

## Decision Table

- projection validation in ACK path: `upgrade`
- scene apply proof contract: `upgrade`
- command apply engine behavior: `keep`
- renderer/Stage5/Live Scrub: `keep`

## Selected Execution Scope

1. Add `professional_scene_timeline_projection_validator.dart`.
2. Wire validator output into `_acknowledgeMcpRemoteRevision(...)` proof build.
3. Extend proof evaluator to accept explicit projection overrides.
4. Add validator and proof override tests.

No renderer changes, no Stage5 changes, no Live Scrub changes.

## Acceptance For This Slice

1. Validator computes projected/missing target ids from receipt targets.
2. ACK proof includes projection fields (`projectedTargetCount`,
   `targetProjectionComplete`, `missingTargetIds`).
3. `rendererApplied` in proof can be constrained by projection completeness.
4. Tests cover full and partial projection cases.
5. Existing MCP text + toolkit tests remain green.

## Rollback

```bash
git -C /Users/mx/Documents/ReFusionXx revert <checkpoint-commit>
```
