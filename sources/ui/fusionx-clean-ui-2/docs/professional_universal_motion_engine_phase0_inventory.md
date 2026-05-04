# Professional Universal Motion Engine - Phase 0 Inventory (Post-Implementation)

Status: updated after Phase 1-7 execution
Date: 2026-05-04  
Plan source: `/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/docs/professional_universal_motion_engine_plan.md`

## Closed As Canonical

1. **Universal channel collection and evaluation path**
   - `UniversalTargetResolver -> UniversalMotionChannelCollector -> UniversalMasterFrameEvaluationService`
   - Production owner: `fusionx_clean_ui_screen.dart` now evaluates through universal service.

2. **Master visual/render contracts**
   - `MasterVisualProgram` carries `crop/mask/text/shape/color/drawOrder`.
   - `MasterRenderGraphAdapter` emits corresponding graph families and bindings.

3. **Renderer frame proof contracts**
   - `MasterRendererFrameAdapters` + `RendererPresentationProof` enforce requested-vs-presented checks.
   - Stale/mismatch states are rejected explicitly.

4. **Legacy transition/manual links removed from production path**
   - `manualTransform`, `_manualTransitionNativeParameters`, `_isLegacyTriangularBlackMixLane` detached from production owner paths.

5. **Phase 7 downstream parity matrix**
   - Parity chain tests exist for `MasterFrameEvaluation -> MasterVisualProgram -> MasterRenderGraph -> RendererPresentationProof`.

## Closed With Production-Path Evidence

1. **Production-path parity test (new)**
   - `/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/test/phase7_production_path_parity_test.dart`
   - Proves workflows enter from `UniversalMasterFrameEvaluationService` (not manual frame fabrication), then continue through visual program, render graph, and renderer proof.

2. **Revision/performance contracts (new)**
   - `/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/test/master_render_graph_performance_contract_test.dart`
   - Confirms:
     - graph revision changes per frame/time request,
     - node `cacheKey` remains stable when inputs are unchanged,
     - source nodes do not churn when only transform values change.

3. **Source revision churn fix (new)**
   - `MasterLiveScrubProgramAdapter._buildSourceRevision(...)` now depends on source identity, not commit/frame numbers.
   - Verified by test:
     - `/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/test/master_live_scrub_program_adapter_test.dart`

## Temporary Compatibility (Explicit)

1. **`currentPositionMs` payload in native scrub surface**
   - File: `/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/native_timeline_scrub_surface.dart`
   - Classification: `temporary compatibility`
   - Current behavior: value is derived from canonical effective master time (`effectiveCurrentTime + timelineOffset`), not an independent writer.
   - Removal trigger: native scrub view contract upgrade to accept dedicated master-time field naming without legacy key dependency.

## Remaining For Full Production Closure

1. **Export parity remains capability-gated for advanced domains**
   - Non-text/effect/transition/multi-visual export parity now reports proof-oriented blockers, but full production renderer ownership is still required for complete parity.
   - Files:
     - `/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_composition_models.dart`
     - `/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_export_parity_gate.dart`

2. **Native device workflow validation**
   - Required to confirm parity behavior on real playback/scrub/export paths after every significant motion-engine checkpoint.
