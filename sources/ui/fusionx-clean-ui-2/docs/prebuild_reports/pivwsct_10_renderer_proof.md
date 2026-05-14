# PIVWSCT-10 Renderer Proof And Realtime Invalidation

Slice: `PIVWSCT-10`  
Plan: `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`  
Date: `2026-05-15`

## Mandatory Pre-Build Evaluation And User Sync Gate

### Current ReFusion state

1. Data-level apply could be reported as success before renderer confirmation.
2. A strict proof gate was required to reject metadata-only success.

### HyperFrames / Remotion comparison

1. HyperFrames and Remotion both provide deterministic frame visibility checks.
2. ReFusion parity requirement: visible transaction must not return final success
   without renderer-observed proof target.

### Decision

`upgrade`  
Add dedicated renderer proof evaluator + invalidation controller + proof ledger
and latency primitives in domain layer.

## Implemented

File:
`lib/features/editor/domain/services/creative_renderer_proof.dart`

Added:

1. `FrameEvaluationProofTarget`
2. `RendererProofObservation`
3. `RendererProofLedger` + entry model
4. `ApplyLatencyMetrics`
5. `PreviewInvalidationController`
6. `CreativeRendererProofEvaluator`

Rules now enforced:

1. visible intents require renderer-observed target for renderer-level success.
2. metadata/cloud-only observation is rejected as final success.
3. proof carries target layer identity and operation kind.

## Tests

File:
`test/creative_renderer_proof_test.dart`

Coverage:

1. text update invalidates frame and can reach renderer proof.
2. shape transform invalidates frame and can reach renderer proof.
3. background proof includes full-canvas target bounds.
4. cloud-only (no renderer observation) does not qualify as final success.

## Acceptance Mapping

```text
renderer_proof_required_for_visible_success = true
metadata_only_success_count = 0
preview_invalidated_for_visible_transactions = true
```

## Scope Confirmation

No Live Scrub files touched.  
No Stage5 files touched.  
No presentation renderer path mutations in this slice.

