# Professional MCP Connectors Inventory

Status: implementation baseline  
Date: 2026-05-11  
Plan reference: `docs/professional_mcp_connectors.md`  
Phase coverage: `PMC-00`

## 1. Safe Domain Entry Points

The MCP layer must call domain services, not widgets.

| MCP action | Service | File |
| --- | --- | --- |
| validate scene program | `ReFusionSceneProgramImportService.validate` | `lib/features/editor/domain/services/refusion_scene_program_import_service.dart` |
| author scene program | `ReFusionSceneProgramAuthoringService.importSceneProgram` | `lib/features/editor/domain/services/refusion_scene_program_authoring_service.dart` |
| apply scene program transaction | `SceneProgramApplyTransaction.apply` | `lib/features/editor/domain/services/scene_program_apply_transaction.dart` |
| extract scene payload | `KieSceneProgramAgentService.extractSceneProgramPayload` | `lib/features/editor/domain/services/kie_scene_program_agent_service.dart` |
| compile director plan | `ReFusionMotionDirectorPlanImportService.importDirectorPlan` + `ReFusionMotionDirectorSceneProgramCompiler.compile` | `lib/features/editor/domain/services/refusion_motion_director_plan_import_service.dart`, `lib/features/editor/domain/services/refusion_motion_director_scene_program_compiler.dart` |
| apply motion patch | `ReFusionMotionPatchImportService.validate` + `ReFusionMotionPatchApplicator.apply` | `lib/features/editor/domain/services/refusion_motion_patch_import_service.dart`, `lib/features/editor/domain/services/refusion_motion_patch_applicator.dart` |
| keyframe edit | `UnifiedKeyframeOperations` | `lib/features/editor/domain/services/unified_keyframe_operations.dart` |
| evaluate frame | `MasterFrameEvaluationReadAdapter` | `lib/features/editor/presentation/services/master_frame_evaluation_read_adapter.dart` |
| unified timeline projection | `UnifiedTimelinePresentationAdapter` + `UnifiedTimelinePanelProjectionAdapter` | `lib/features/editor/presentation/services/unified_timeline_presentation_adapter.dart`, `lib/features/editor/presentation/services/unified_timeline_panel_projection_adapter.dart` |

## 2. Protected Boundaries

Do not directly modify or control the following from MCP:

- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`
- `Stage5PreviewPlatformView`
- Flutter Live Scrub handoff paths
- Native playback clock ownership

## 3. UI Entry Points (Read Only Context)

These files are UI integration points and should stay out of command execution:

- `lib/features/editor/presentation/widgets/scene_program_import_bottom_sheet.dart`
- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

The MCP connector should route through domain services and then let UI observe
state updates naturally.

## 4. Present Preset Note

Current present list behavior is preset-driven and currently includes a limited
catalog path. MCP should not depend on UI preset selection. MCP should accept
scene sources directly and apply through transaction services.

## 5. Baseline Outcome For Next Phases

`PMC-01` to `PMC-03` can now build on:

- command envelope and capability model,
- transaction manager foundation,
- resource provider abstraction,
- tool registry surface.
