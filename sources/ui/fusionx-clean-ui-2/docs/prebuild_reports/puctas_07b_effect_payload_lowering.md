# Pre-Build Report

Slice ID: `PUCTAS-07B.EFFECT-PAYLOAD-LOWERING`

Date: `2026-05-14`

## Goal

Lower MCP `effect/effects` payloads into canonical timeline style/transform
fields so supported effects become real runtime mutations instead of metadata.

## Current ReFusion State Before Slice

1. Supported direct fields are already lowered in
   `_applyRemoteTimelineClipStyleMutation` (`mask`, `border`, `glow`,
   transform-like x/y/scale/rotation).
2. Newer MCP payloads may send effects as structured `effects[]` entries
   (`type + params`) without duplicating direct fields.
3. Those structured effects are not consistently lowered today.

## Reference Comparison

HyperFrames lesson:

- Effects are adapter-driven; structured declarations must resolve to concrete
  visual mutations deterministically at seek time.

Remotion lesson:

- Component props/effect inputs are explicit and become concrete render state.
  No render-critical intent should remain as passive metadata.

## Gap List Closed By This Slice

1. Missing parser/lowerer for structured `effect/effects` inputs.
2. Style mutation path depends mainly on direct field payload shape.
3. No focused tests proving effect-list lowering behavior.

## Decision Table

- current direct-field style mutation: `keep`
- effect-list parser and lowering: `add`
- capability guard from PUCTAS-07A: `keep`
- renderer / Stage5 / Live Scrub: `keep`

## Selected Execution Scope

1. Add `McpEffectPayloadLowering` service.
2. Integrate it in `_applyRemoteTimelineClipStyleMutation` as structured-effect
   input fallback/source.
3. Add focused tests for lowering outputs.

No renderer changes. No Stage5 changes. No Live Scrub changes.

## Acceptance For This Slice

1. `effects: [{type:'mask', params:{shape:'circle'}}]` lowers to circle mask.
2. `effects: [{type:'border', params:{width,color}}]` lowers to border style.
3. `effects: [{type:'glow', params:{blur,opacity,color}}]` lowers to glow style.
4. `effects: [{type:'transform', params:{x,y,scale,rotation}}]` lowers to
   transform fields.
5. Existing direct fields still work with precedence.
6. Existing MCP and proof tests remain green.

## Rollback

```bash
git -C /Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2 revert <checkpoint-commit>
```
