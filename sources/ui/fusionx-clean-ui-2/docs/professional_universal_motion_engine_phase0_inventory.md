# Professional Universal Motion Engine - Phase 0 Inventory

Status: official inventory before implementation  
Package: `com.refusion.app`  
Date: 2026-05-04  
Plan source: `docs/professional_universal_motion_engine_plan.md`  
Current branch baseline: `codex/unified-keyframe-ops-foundation-20260426` (`8e7fe42`)

## 0. Scope

This inventory covers the required Phase 0 evidence:

1. time writers and native clock boundaries
2. channel sources and graph buckets
3. target id forms and raw clip id use
4. keyframe operation entry points
5. renderer/effect/value consumer paths
6. presentation proof and parity paths
7. classification for migration (`canonical`, `adapter`, `compatibility`, `removal-candidate`)

## 1. Time Writers And Native Clock Boundaries

`canonical`

- [timeline_clock_coordinator.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/timeline_clock_coordinator.dart:200): single mutable clock owner with phase/authority model.
- [timeline_clock_coordinator.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/timeline_clock_coordinator.dart:571): `_commit(...)` validates phase transition and authority.
- [timeline_clock_coordinator.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/timeline_clock_coordinator.dart:624): `_isAuthorityAllowedForPhase(...)` policy guard.
- [master_clock_native_bridge.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/master_clock_native_bridge.dart:4): native boundary service between UI/native and `TimelineClockCoordinator`.
- [master_clock_native_bridge.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/master_clock_native_bridge.dart:71): `commitPresentedScrubFrame(...)` transport-mediated write path.

`adapter`

- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:3174): `_setCurrentTime(...)` UI-level time setter.
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:16586): `_commitStructuralTimelineEdit(...)` structural edit pipeline with playback/scrub sync.

`compatibility`

- [native_timeline_scrub_surface.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/native_timeline_scrub_surface.dart:283): descriptor/config writes include `currentPositionMs` compatibility payload.

`removal-candidate`

- direct UI-local time notifiers as truth writers outside canonical clock mediation:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:3158)
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:3295)

## 2. Channel Sources And Graph Buckets

`canonical`

- `MotionPropertyChannelModel` is canonical channel entity:
  - [professional_motion_animation_models.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_animation_models.dart:198)
- unified keyframe domain operations:
  - [unified_keyframe_operations.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/unified_keyframe_operations.dart:184)

`adapter`

- scene program import writes channel bucket via transaction:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:15346)
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:15367)
- motion patch apply merges scoped channels into project bucket:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:15435)
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:15456)
- Scene Layer Scope add property channels through `LayerScopeCompositionAdapter`:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:6286)
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:6315)

`compatibility`

- `_manualMotionPropertyChannels` currently acts as mixed bucket for manual and non-manual authoring:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:603)
- master frame evaluation still reads only this bucket:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:21623)

`removal-candidate`

- naming and ownership mismatch of `_manualMotionPropertyChannels` as universal source should be replaced by `UniversalTargetResolver -> UniversalMotionChannelCollector`.

## 3. Target Id Forms And Raw Clip Id Use

`canonical`

- `MotionPropertyTarget` identity shape:
  - [professional_motion_models.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_models.dart:262)
  - [professional_motion_models.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_models.dart:278)

`adapter`

- transition unified scope request factory resolves scene/layer/element ownership into `MotionPropertyTarget`:
  - [transition_unified_scope_request_factory.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/services/transition_unified_scope_request_factory.dart:253)
- text element context exposes canonical element target:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:24451)

`compatibility`

- runtime bridge still uses timeline clip ids as temporary surface targets:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:21651)
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:21658)
- preview and AI transition helpers still track `clipId` heavily as selection/runtime address:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:20483)
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:20870)

`removal-candidate`

- raw clip-id surface ownership must be resolver input only, not canonical motion target ownership.

## 4. Keyframe Operation Entry Points

`canonical`

- unified operations core:
  - [unified_keyframe_operations.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/unified_keyframe_operations.dart:184)
- Transition Unified Scope keyframe adapter:
  - [transition_unified_scope_keyframe_adapter.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/services/transition_unified_scope_keyframe_adapter.dart:105)
- Layer Scope composition adapter:
  - [layer_scope_composition_adapter.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/layer_scope_composition_adapter.dart:8)

`adapter`

- Layer Scope add keyframe UI path:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:9933)
- Layer Scope graph interpolation updates:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:10290)
- Scene Layer Scope add keyframe:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:6737)
- Transition Focus add keyframe:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:19902)

`compatibility`

- text-track constrained graph sync helpers (`context.track.kind == TimelineTrackKind.text`) in Layer Scope path:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:9022)
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:9139)

`removal-candidate`

- track-kind-based keyframe behavior guards that tie authoring semantics to UI track labels instead of canonical target/property schema.

## 5. Renderer / Effect / Value Consumer Paths

`canonical`

- master frame evaluation adapter:
  - [master_frame_evaluation_read_adapter.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/services/master_frame_evaluation_read_adapter.dart:26)
- master live scrub projection/parity build:
  - [master_live_scrub_descriptor_projection.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/master_live_scrub_descriptor_projection.dart:238)

`adapter`

- non-manual transition runtime bridge into LiveScrub program:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:21641)
- manual transition runtime bridge:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:21696)

`compatibility`

- non-manual runtime bridge rebuild drops evaluated channels and channels list:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:21665)
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:21681)
- Live Scrub property coverage limited, unsupported path active:
  - [master_live_scrub_program_adapter.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/master_live_scrub_program_adapter.dart:49)
  - [master_live_scrub_program_adapter.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/master_live_scrub_program_adapter.dart:108)
- shape/camera/effectControl projected as text timeline track/content kind:
  - [scene_layer_scope_timeline_adapter.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/services/scene_layer_scope_timeline_adapter.dart:311)

`removal-candidate`

- any renderer-side fallback that silently ignores unsupported property/value mapping instead of emitting blocker and proof mismatch.

## 6. Presentation Proof And Parity Paths

`canonical`

- Live Scrub parity contract fields (`canScrubFrame`, `usesMasterFrameEvaluation`, etc.):
  - [master_live_scrub_descriptor_models.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/master_live_scrub_descriptor_models.dart:153)
- descriptor projection produces parity report:
  - [master_live_scrub_descriptor_projection.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/master_live_scrub_descriptor_projection.dart:238)
- transition readiness preflight includes explicit parity stage:
  - [professional_video_transition_readiness_preflight.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/professional_video_transition_readiness_preflight.dart:562)

`adapter`

- runtime bridge submission path:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:22228)

`compatibility`

- interactive render result exposes delivery/presentation flags but does not yet carry full requested-vs-presented master frame proof contract:
  - [professional_video_transition_compositor.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/professional_video_transition_compositor.dart:6695)
- export parity gate still reports broad missing parity for multiple domains:
  - [scene_export_parity_gate.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_export_parity_gate.dart:190)
  - [export_composition_models.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_composition_models.dart:3457)

`removal-candidate`

- proof by transport/sample/ack-only signals without strict master-frame identity matching.

## 7. MasterFrameEvaluation Construction Inventory

`canonical`

- adapter returns canonical frame:
  - [master_frame_evaluation_read_adapter.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/services/master_frame_evaluation_read_adapter.dart:96)

`adapter`

- manual runtime program rebuild for active source filtering:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:21746)

`compatibility`

- non-manual runtime bridge rebuild with dropped channel/effect state:
  - [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:21665)

## 8. Phase 0 Conclusion

Phase 0 confirms four immediate blockers before Phase 1 implementation:

1. Master evaluation input is not universal yet; it is bucketed through `_manualMotionPropertyChannels`.
2. Non-manual transition runtime bridge drops evaluated channels and channels list.
3. Live Scrub program adapter property surface is limited and still emits `unsupported_property` for many authored domains.
4. Scope timeline projection for shape/camera/effectControl is still text-kind compatibility, not final distinct track contract.

## 9. Approved Next Slice

Per plan contract, the next slice is now approved as:

`UniversalTargetResolver -> UniversalMotionChannelCollector -> _masterFrameEvaluationForMode(...) wiring`

and must include targeted tests proving:

1. all layer kinds route to master evaluation through canonical targets
2. non-manual transition runtime bridge preserves evaluated channels/effects
3. unsupported properties are explicit blockers, not silent drops

## 10. Legacy Detach Checklist (Mandatory)

For each workflow migrated in Phase 1+:

1. list old entry points and file locations
2. mark each one as `deleted`, `blocked`, or `temporary compatibility`
3. if compatibility is temporary, define exact removal trigger
4. prove universal path is production owner with targeted tests
5. run `rg` checks proving no active dual-routing for the same workflow

No workflow is considered migrated while old and universal paths can both
execute the same frame request in production.
