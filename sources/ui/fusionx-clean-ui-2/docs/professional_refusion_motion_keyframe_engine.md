# Professional ReFusion Motion And Keyframe Engine

Status: official master execution plan  
Package: `com.refusion.app`  
Supersedes: `docs/professional_timeline_clock_contract.md`  
Scope: professional timeline clock, timeline geometry, scoped timelines, keyframes, effects, transitions, script import, scene programs, preview parity, and export parity

## Mandatory Checkpoint Policy

All implementation work under this plan must follow:

`docs/professional_checkpoint_policy.md`

The Composition Timeline migration must also follow:

`docs/professional_composition_timeline_migration_plan.md`

Agent-authored editable scene generation must also follow:

`docs/professional_agent_scene_program_engine.md`

Scene container clips and mention-driven motion patches must also follow:

`docs/professional_scene_container_and_mention_motion_plan.md`

Professional composition workspace, scene sequencing, outliner, inspector, and
context-aware insertion work must also follow:

`docs/professional_composition_workspace_and_scene_orchestration_plan.md`

Professional prompt-to-scene choreography must also follow:

`docs/professional_motion_director_engine.md`

Tutorial-derived professional capability growth must also follow:

`docs/super_professional_engine_like_after_effects.md`

This is a strict project rule. Every completed build step must be committed as a focused checkpoint and pushed to GitHub before starting the next build step, unless the user explicitly says not to push.

The required order is:

```text
finish scoped change
-> verify
-> commit focused files only
-> push checkpoint branch
-> report commit hash and rollback command
```

This rule exists so timeline, Live Scrub, keyframe, transition, and motion-engine regressions can be rolled back precisely.

## Execution Status

- Current stable rollback baseline: `acea124` (`checkpoint: lock timeline clock handoff contracts`). This is the verified point where Live Scrub returned to normal after rollback testing.
- Phase 0: completed. Expanded baseline audit for timeline time writers, geometry writers, keyframe data paths, effect data paths, transition data paths, script import outputs, preview inputs, and export inputs is documented in `docs/professional_timeline_clock_audit.md`.
- Phase 1: completed as isolated infrastructure. `TimelineClockCoordinator` exists in `lib/features/editor/domain/services/timeline_clock_coordinator.dart` with tests in `test/timeline_clock_coordinator_test.dart`.
- Phase 2: device-validated candidate. Main timeline playback start, native playback samples, and scrub handoff pass through `TimelineClockCoordinator`. Real-device validation on April 25, 2026 reported high stability for play/pause and Live Scrub on valid media.
- Phase 3: in progress. `TimelineGeometryMapper` exists in `lib/features/editor/domain/services/timeline_geometry_mapper.dart` with tests in `test/timeline_geometry_mapper_test.dart`; central time/offset mapping, visual follow, clip move, trim drag, and native scrub pointer delta paths are being routed through it. Contract tests now lock scrub/settle/play and zoom/play handoff behavior before deeper motion-engine unification.
- Phase 5A: completed as isolated infrastructure. `UnifiedKeyframeOperations` exists in `lib/features/editor/domain/services/unified_keyframe_operations.dart` with tests in `test/unified_keyframe_operations_test.dart`. It is not wired to UI yet and does not touch Stage5 or Live Scrub.
- Phase 5B: completed as Layer Scope adapter parity infrastructure. `CanvasTimelineUnifiedKeyframeAdapter` exists in `lib/features/editor/domain/services/canvas_timeline_unified_keyframe_adapter.dart` with tests in `test/canvas_timeline_unified_keyframe_adapter_test.dart`. It preserves existing canvas timeline IDs and is not wired to UI yet.
- Composition Timeline migration: documented in `docs/professional_composition_timeline_migration_plan.md`. The approved direction is Composition Timeline Graph as canonical truth, Unified Layer Scope Timeline as the only scope editing surface, and Legacy Transition Scope Timeline as deprecated compatibility.
- Composition Phase C1: completed as domain-only projection infrastructure. `CompositionTimelineProjectionResolver` exists in `lib/features/editor/domain/services/composition_timeline_projection.dart` with tests in `test/composition_timeline_projection_test.dart`. It is not wired to UI and does not touch Stage5 or Live Scrub.
- Composition Phase C2 foundation: completed as domain/adapter infrastructure. `LayerScopeCompositionAdapter` exists in `lib/features/editor/domain/services/layer_scope_composition_adapter.dart` with tests in `test/layer_scope_composition_adapter_test.dart`. It routes layer-scope keyframe mutations through the unified keyframe adapter but is not wired to UI yet.
- Unified Scope lane projection: `UnifiedScopeTimelineProjectionAdapter` exists in `lib/features/editor/presentation/services/unified_scope_timeline_projection_adapter.dart` with tests in `test/unified_scope_timeline_projection_adapter_test.dart`. It makes timeline lanes a projection of graph channels rather than a second source of truth.
- Composition Phase C3 foundation: `ScopeMotionPropertyCatalog` exists in `lib/features/editor/domain/services/scope_motion_property_catalog.dart` with tests in `test/scope_motion_property_catalog_test.dart`. It defines the shared text/image/shape layer-scope property surface and proves all three can author keyframes through `LayerScopeCompositionAdapter`.
- Composition Phase C4 foundation: `NormalTransitionMotionGraphLowerer` exists in `lib/features/editor/domain/services/normal_transition_motion_graph_lowerer.dart` with tests in `test/normal_transition_motion_graph_lowerer_test.dart`. It lowers existing normal transition recipes into canonical `MotionPropertyChannelModel` channels for outgoing/incoming targets without touching the legacy Transition Scope UI.
- Composition Phase C4 apply foundation: `NormalTransitionGraphAuthoringService` exists in `lib/features/editor/domain/services/normal_transition_graph_authoring_service.dart` with tests in `test/normal_transition_graph_authoring_service_test.dart`. It creates transition node/instance/window data, graph channels, and transition bundle metadata together so future UI wiring can apply presets without writing permanent legacy transition lanes.
- Composition Phase C4 lane projection: `TransitionScopeGraphLaneAdapter` exists in `lib/features/editor/presentation/services/transition_scope_graph_lane_adapter.dart` with tests in `test/transition_scope_graph_lane_adapter_test.dart`. It projects transition graph bundles into role-aware unified scope lanes without touching the legacy Transition Scope UI.
- Composition Phase C4 preset expansion: the graph-backed normal transition catalog now includes built-in `cross_dissolve`, `fade_black`, and `zoom_in_camera` definitions, and `NormalTransitionTimelineAdapter` maps those timeline presets into the graph-backed transition path. This is still adapter/domain infrastructure and does not touch Live Scrub.
- Composition Phase C4 UI-facing facade: `TransitionScopeGraphAuthoringAdapter` exists in `lib/features/editor/presentation/services/transition_scope_graph_authoring_adapter.dart` with tests in `test/transition_scope_graph_authoring_adapter_test.dart`. It applies a preset, creates graph channels, resolves transition scope, and projects unified lanes in one adapter call for future UI wiring.
- Composition Phase C4 entry gate: `TransitionUnifiedScopeEntryGate` exists in `lib/features/editor/presentation/services/transition_unified_scope_entry_gate.dart` with tests in `test/transition_unified_scope_entry_gate_test.dart`. It is disabled by default and chooses between graph-backed Unified Scope and legacy Transition Scope with explicit fallback reasons. It is a preflight adapter only and is not wired to production UI yet.
- Composition Phase C5 request foundation: `TransitionUnifiedScopeRequestFactory` exists in `lib/features/editor/presentation/services/transition_unified_scope_request_factory.dart` with tests in `test/transition_unified_scope_request_factory_test.dart`. It converts an adjacent video-clip boundary into a temporary transition-scope motion project and `TransitionScopeGraphAuthoringRequest` so future bridge UI wiring does not construct graph targets inside the large editor screen.
- Composition Phase C5 bridge entry foundation: `TransitionUnifiedScopeBridgeEntryAdapter` exists in `lib/features/editor/presentation/services/transition_unified_scope_bridge_entry_adapter.dart` with tests in `test/transition_unified_scope_bridge_entry_adapter_test.dart`. It resolves a timeline bridge preset through the normal transition catalog, request factory, and entry gate, while falling back to legacy scope when disabled or unsupported.
- Composition Phase C5 bridge UI preflight: `FusionXCleanUiScreen` now has a disabled-by-default `_unifiedTransitionScopeBridgeEnabled` guard and `_tryOpenUnifiedTransitionScopeBridge(...)` entry point. With the flag off, production behavior remains legacy. This is only the reversible handoff point for the next checkpoint.
- Composition Phase C5 launch session foundation: `TransitionUnifiedScopeBridgeSession` now packages the graph-backed transition scope project, scope projection, lane projection, lane bindings, transition window, outgoing/incoming layer IDs, and local/global time mapping for the future Unified Layer Scope handoff. The production flag remains off.
- Composition Phase C5 timeline view-model foundation: `TransitionUnifiedScopeTimelineSessionAdapter` converts a unified transition session into Layer Scope style timeline tracks, scoped clip slices, editable lane projections, time display offset, local duration, and seam-local time. This prepares the UI handoff without enabling the production flag.
- Composition Phase C5 screen handoff state: `FusionXCleanUiScreen` can now stage a successful unified transition scope entry as a screen-level session and view model behind `_unifiedTransitionScopeBridgeEnabled`. The flag remains disabled, so production behavior still falls back to legacy transition handling.
- Composition Phase C5 hidden TimelinePanel handoff: when the disabled-by-default flag is enabled, `FusionXCleanUiScreen` can now render the staged unified transition view model inside `TimelinePanel`, with transition-local time mapping, zoom mapping, lane/keyframe selection, and read-only controls. Keyframe mutation remains the next checkpoint.
- Composition Phase C5 keyframe operation foundation: `TransitionUnifiedScopeKeyframeAdapter` routes transition-lane add/move/value/delete operations through `UnifiedKeyframeOperations`, rebuilds the graph-backed transition session, and reprojects the Layer Scope style timeline view model. This remains adapter infrastructure behind the disabled transition scope flag and does not touch Stage5 or Live Scrub.
- Composition Phase C5 hidden UI operation wiring: when the disabled-by-default unified transition flag is enabled, the staged transition `TimelinePanel` now routes keyframe drag, Key add, Value editing, and move-selected-to-playhead through `TransitionUnifiedScopeKeyframeAdapter`. The production flag remains off, so legacy transition behavior is unchanged.
- Composition Phase C5 hidden Graph/Easy Ease wiring: when the disabled-by-default unified transition flag is enabled, the staged transition Graph button can open the existing Layer Scope graph sheet and route Easy Ease interpolation changes through `TransitionUnifiedScopeKeyframeAdapter` and `UnifiedKeyframeOperations`. The production flag remains off, so legacy transition behavior and Live Scrub are unchanged.
- Composition Phase C6 schema foundation: `ReFusionSceneProgramImportService` exists in `lib/features/editor/domain/services/refusion_scene_program_import_service.dart` with tests in `test/refusion_scene_program_import_service_test.dart`. It validates declarative JSON scene programs, rejects executable/import/shader-source keys, and preserves layers/elements/channels/keyframes for the future graph lowerer. It is not wired to UI and does not touch Live Scrub.
- Agent Scene Program Engine plan: documented in `docs/professional_agent_scene_program_engine.md`. The approved direction is Remotion-inspired frame-based composition, After Effects-style editable layer/property/keyframe semantics, declarative JSON-only scene programs, and a `ReFusionSceneProgramLowerer` as the next safe implementation slice. The plan explicitly forbids Live Scrub changes for this engine path.
- Scene Container and Mention Motion plan: documented in `docs/professional_scene_container_and_mention_motion_plan.md`. The approved direction is root timeline Scene Clip containers for generated compositions, Scene Scope for internal layers, Unified Layer Scope for element keyframes, and `@mention` motion patches that target stable existing graph IDs.
- Scene Container Phase S1 foundation: `CompositionSceneClipModel` exists in `lib/features/editor/domain/models/composition_scene_clip_models.dart` with tests in `test/composition_scene_clip_models_test.dart`. It defines root Scene Clip container timing, source-scene binding, reusable scene instances, root/source/local time mapping, and validation. It is not wired to UI, preview, export, or Live Scrub yet.
- Scene Container Phase S2 foundation: `SceneProgramApplyTransaction` exists in `lib/features/editor/domain/services/scene_program_apply_transaction.dart` with tests in `test/scene_program_apply_transaction_test.dart`. It applies a valid Scene Program authoring result as one root Scene Clip plus a nested source scene, namespaces generated layers/channels/text bindings, and avoids merging generated layers directly into the root scene. It is not wired to UI, preview, export, or Live Scrub yet.
- Scene Container Phase S3 foundation: `RootSceneClipProjectionAdapter` exists in `lib/features/editor/presentation/services/root_scene_clip_projection_adapter.dart` with tests in `test/root_scene_clip_projection_adapter_test.dart`. It projects scene clip containers into one root scene timeline track, preserves root-time gaps, rejects overlaps, and keeps internal generated layers hidden from the root timeline. It is not wired to production UI, preview, export, or Live Scrub yet.
- Scene Container Phase S3 UI wiring: Scene Program import now applies through the scene-clip transaction and root projection adapter, so the root timeline shows one generated Scene Clip container instead of internal generated layers. Nested Scene Scope opening, nested preview/export semantics, and element-level editing remain future phases. This checkpoint does not touch Stage5 or Live Scrub.
- Scene Container Phase S4 foundation: `SceneScopeSessionResolver` exists in `lib/features/editor/domain/services/scene_scope_session.dart` with tests in `test/scene_scope_session_test.dart`. It resolves a root Scene Clip into a nested Scene Scope session with root/source/local time mapping and a small `ScopeStack` contract for future double-tap navigation. It is domain-only and does not touch Stage5 or Live Scrub.
- Scene Container Phase S4 UI wiring: root Scene Clips can now be opened by double tap into a Scene Scope timeline view that projects nested layers as local tracks and returns to the root timeline through the existing scope toolbar. This checkpoint does not wire element-level keyframe editing, nested export semantics, or Stage5 Live Scrub changes.
- Scene Container Phase S5 foundation: supported internal Scene Scope layers can now be opened by double tap into a Unified Layer Scope style timeline that shows the layer clip and graph-projected keyframe lanes. This is a nested-scope projection step only; mutation wiring and nested export semantics remain future checkpoints, and Stage5 Live Scrub is untouched.
- Scene Container Phase S5 keyframe drag wiring: Scene Layer Scope keyframe markers can now move existing graph keyframes through `LayerScopeCompositionAdapter`, then merge the edited local scope channel back into source-scene time. Add/value/delete/graph controls and nested export semantics remain future checkpoints, and Stage5 Live Scrub is untouched.
- Scene Container Phase S5 keyframe add wiring: Scene Layer Scope can now add a keyframe on the selected animation row at the current scoped playhead time. The operation routes through `LayerScopeCompositionAdapter` and merges back into source-scene graph time. Value/delete/graph controls and nested export semantics remain future checkpoints, and Stage5 Live Scrub is untouched.
- Scene Container Phase S5 keyframe value wiring: Scene Layer Scope can now open the Value editor for selected scalar/integer/boolean graph keyframes and write the edited value back through `LayerScopeCompositionAdapter`. Delete/graph controls and nested export semantics remain future checkpoints, and Stage5 Live Scrub is untouched.
- Scene Container Phase S5 keyframe tool wiring: Scene Layer Scope now uses a focused keyframe toolbar instead of disabled clip-edit tools. Selected keyframes can move to the current playhead or be deleted through `LayerScopeCompositionAdapter`, with edits merged back into source-scene graph time. Nested export semantics remain future checkpoints, and Stage5 Live Scrub is untouched.
- Scene Container Phase S5 graph/ease wiring: Scene Layer Scope can now open the Graph sheet for selected graph keyframes and apply/remove Easy Ease interpolation through `LayerScopeCompositionAdapter`, with edits merged back into source-scene graph time. Nested export semantics remain future checkpoints, and Stage5 Live Scrub is untouched.
- Scene Container Phase S6 foundation: `SceneMentionIndex` exists in `lib/features/editor/domain/services/scene_mention_index.dart` with tests in `test/scene_mention_index_test.dart`. It builds stable `@mention` entities for Scene Clips and animatable elements, disambiguates duplicate names, exposes supported properties, and treats deleted elements as invalid mentions when the index is rebuilt. This is domain-only infrastructure for future prompt/autocomplete UI and does not touch Stage5 or Live Scrub.
- Scene Container Phase S7 foundation: `SceneMentionPromptContextBuilder` exists in `lib/features/editor/domain/services/scene_mention_prompt_context.dart` with tests in `test/scene_mention_prompt_context_test.dart`. Mention Motion is now split into a dedicated `RemotionPromptBottomSheet` opened from its own bottom dock action, while `SceneProgramImportBottomSheet` remains JSON/preset-only for full scene creation. The Remotion sheet supports `@` autocomplete, mention chips, API-ready motion-patch payload summaries, and broken mention diagnostics without API calls, graph mutation, Stage5, or Live Scrub changes.
- Scene Container Phase S8 foundation: `ReFusionMotionPatch` exists in `lib/features/editor/domain/models/refusion_motion_patch_models.dart` and `ReFusionMotionPatchImportService` exists in `lib/features/editor/domain/services/refusion_motion_patch_import_service.dart` with tests in `test/refusion_motion_patch_import_service_test.dart`. It validates declarative motion patches against stable mention targets and supported graph properties, blocks executable/runtime keys, enforces scope time bounds, and does not mutate graph data, call APIs, touch Stage5, or touch Live Scrub.
- Scene Container Phase S9 foundation: `ReFusionMotionPatchApplicator` exists in `lib/features/editor/domain/services/refusion_motion_patch_applicator.dart` with tests in `test/refusion_motion_patch_applicator_test.dart`. It applies validated motion patches into editable graph channels through `UnifiedKeyframeOperations`, creates missing channels, updates same-time keyframes without identity churn, supports component-channel expansion such as `position`, and remains domain-only without API calls, UI apply wiring, Stage5, or Live Scrub changes.
- Scene Container Phase S10 local test mode: the Remotion sheet now supports pasted Motion Patch JSON and applies valid patches locally through the validator/applicator path into root or Scene Scope graph channels. This enables end-to-end local testing before remote KIE.ai integration and intentionally performs no API calls.
- Scene Container Phase S11A agent dry-run: `ReFusionMotionAgentProviderCatalog` now defines KIE.ai Codex/GPT/Gemini motion-agent profiles and builds dry-run request previews for the Remotion sheet. The UI can select a model and prepare the provider-specific payload, but it still performs no API calls, consumes no credits, and does not touch Stage5 or Live Scrub.
- Scene Container Phase S11B live agent generation: `KieMotionAgentService` now sends the selected KIE.ai request only after the user taps Generate, resolves `KIE_API_KEY` through the existing runtime config channel, extracts returned Motion Patch JSON, validates it, and then reuses the local editable graph applicator. GPT-5.5 is the first profile when supported by the KIE account, with Codex 5.3 as a documented fallback. Stage5 and Live Scrub remain untouched.
- Scene Container Phase S11B hardening: Motion Patch import now defensively accepts model-produced operation `targetId` as an alias for canonical `target`, while the provider prompt explicitly instructs agents to emit `target`. This protects valid generated patches without weakening validation or touching Stage5/Live Scrub.
- Scene Container Phase S12 foundation: `SceneExportParityGate` now gives generated scene export a first explicit readiness contract. Text motion over a media baseline can pass when the deterministic motion-text export program exists; scene-only canvas export and non-text authored visuals are blocked clearly until their native renderer paths are implemented. This is export-domain infrastructure only and does not touch Stage5/Live Scrub.
- Performance watch note: continuous keyframe dragging and repeated scene-script editing may expose intermittent UI heaviness on device. Treat this as a tracked validation risk for a future profiling pass after the mutation surface is complete; do not solve it by weakening Live Scrub.
- Core Design Pack Phase A: `ReFusionCoreDesignPack` exists in `lib/features/editor/domain/services/refusion_core_design_pack.dart`, `kind: "icon"` scene elements lower into editable generated shapes via `asset.icon`, and the agent-facing guide lives in `docs/refusion_scene_program_agent_authoring_guide.md`. This is an offline lightweight core pack; remote asset/CDN packs remain a future phase.
- Scene Program importer now supports channel `timeBasis: "project"` and also converts likely project-time keyframes into local channel time with warnings. This protects agent-generated scenes that stagger delayed layers on a global timeline without touching Live Scrub.
- Scene Program importer now normalizes out-of-order keyframes into ascending local time with warnings instead of rejecting the full scene. The lowerer also supports agent-friendly aliases such as `typingProgress`, `typewriterProgress`, `size`, `radius`, and `backgroundColor` so common prompt-generated UI scenes lower into editable motion channels.
- Scene Program importer now repairs simple layer timing aliases and numeric strings, such as `startTimeMs: "0"` or `duration: "2400"`, into canonical numeric `startMs`/`durationMs` with warnings instead of rejecting otherwise valid agent scenes.
- Scene Program text reveal channels now generate explicit text animation bindings for letter/typewriter or word reveal semantics. This keeps agent-generated `typingProgress`/`typewriterProgress` scenes connected to the existing Text Motion typewriter engine instead of treating reveal as an ambiguous scalar.
- Scene Program importer now repairs too-short layer durations when all keyframes are still inside the scene timeline, and warns when typewriter/reveal channels run backward (`1.0 -> 0.0`) because that produces a delete/backspace effect rather than keyboard type-on.
- Scene Program importer now compacts simple agent-generated character-by-character text layers into a single text element with a true `typewriterProgress` channel. This is a defensive repair for agents that incorrectly create one text element per letter instead of using the native text reveal engine.
- Scene Program lowerer now offsets local layer/element keyframes into project time before runtime evaluation. Delayed text layers therefore type at their visible timeline position instead of revealing early as if their keyframes started at project zero.
- Motion Director Phase D1 foundation: `ReFusionMotionDirectorPlan`, ordered beats, semantic components, primitives, and `ReFusionMotionDirectorLinter` now define the professional planning layer above Scene Program. Ordered beat plans pass, disjoint-component beat overlap is accepted with warning for intentional parallel choreography, same-component or unspecified overlap fails, unknown targets fail, primitives outside their owning beat fail, missing typewriter ranges default to `0.0 -> 1.0` with warning, and backward typewriter motion fails before it can become random generated keyframes.
- Motion Director Phase D2 prompt foundation: KIE Mention Motion requests now include a director-style beat contract and system instruction before the agent writes Motion Patch JSON, so generated patches are pushed toward ordered enter/hold/action/exit choreography instead of unrelated simultaneous motion.
- Motion Director Phase D2 Scene Generate UI: the Scene bottom sheet now has `Script` and `Generate` tabs. `Generate` is limited to Codex and Claude Opus scene-director profiles, sends the Director/Scene Program contract through KIE.ai only on explicit Generate tap, extracts the generated `refusion.scene-program/v1` JSON, validates it, and returns the user to Script for review/apply. This does not touch Stage5 or Live Scrub.
- Motion Director Phase D2 payload hardening: Scene Generate now prefers the strict wrapper `{"directorPlan": {...}, "sceneProgram": {...}}`. A returned `directorPlan` is imported and linted before the Scene Program is accepted, so backward typewriter motion, invalid beats, unknown targets, or malformed plans are rejected before they can become editable scene data. Direct Scene Program JSON remains a legacy compatibility fallback only.
- Motion Director Phase D3 compiler foundation: `ReFusionMotionDirectorSceneProgramCompiler` can compile known semantic Director components and primitives into valid `refusion.scene-program/v1` layers/elements/channels, and the compiled output lowers into graph channels/text bindings through the existing Scene Program lowerer. UI integration remains a later slice.
- Motion Director Phase D3 extraction integration: when a live agent returns a valid `directorPlan` without an executable `sceneProgram`, `KieSceneProgramAgentService` compiles that plan locally into `refusion.scene-program/v1` JSON. This keeps the professional Director path usable even when the model returns choreography intent instead of raw layer/keyframe JSON.
- Motion Director Phase D4 alignment gate foundation: live Scene Generate responses that include both `directorPlan` and `sceneProgram` now pass an alignment check. Director components must appear as real scene layers/elements, and Director primitives must map to matching animation channels. This blocks valid-looking JSON that ignores its own choreography plan.
- Motion Director Phase D4 hardening: the alignment gate now understands background/canvas aliases such as `bg-layer`, `bg-solid`, `canvas-fill`, and full-canvas solid fills, while still requiring real animated channels for primitives such as `opacity`. If a generated `sceneProgram` fails to implement a valid `directorPlan`, Scene Generate falls back to compiling the Director Plan locally instead of failing the entire generation. Incomplete pasted JSON now reports a specific copy/upload recovery message.
- Motion Director Phase D4 handoff hardening: Director beat overlap on the same component is now accepted only for inspectable handoff choreography where overlapping primitives animate disjoint property groups, such as `scale` ending while `width` begins. Same-component overlap on the same property remains an error. This fixes valid prompt-shell scenes that pop a circle and begin expanding it into an input bar without weakening the anti-random-motion gate.
- Motion Director Phase D5 timing contract foundation: `ProfessionalSceneTimingContractValidator` exists in `lib/features/editor/domain/services/professional_scene_timing_contract.dart` with tests in `test/professional_scene_timing_contract_test.dart`. The Director linter now enforces readable holds after text reveal, rejects overlapping same-target/same-property primitives, derives component timing lifetimes for future compiler use, and exposes Scene Program timing checks for duplicate channels and keyframes outside layer spans. This is domain-only and does not touch Stage5 or Live Scrub.
- Motion Director Phase D6 compiler channel merge: `ReFusionMotionDirectorSceneProgramCompiler` now merges sequential primitives for the same component/property into one ordered Scene Program channel before lowering. Same-time handoff keyframes collapse into one editable point, so generated motion no longer creates duplicate target/property channels for staged pop/settle or enter/exit choreography. This is compiler/domain-only and does not touch Stage5 or Live Scrub.
- Motion Director Phase D7 Scene Program timing gate: `ReFusionSceneProgramAuthoringService` now validates imported Scene Programs with `ProfessionalSceneTimingContractValidator` before lowering, and `KieSceneProgramAgentService` validates extracted generated Scene Programs before accepting them. Direct generated JSON that violates the timing contract is rejected; wrapped responses with a valid Director Plan fall back to locally compiled Director output. This is authoring/extraction-domain infrastructure and does not touch Stage5 or Live Scrub.
- Motion Director Phase D8 timing repair feedback: `ProfessionalSceneTimingContractIssueFormatter` now turns timing-contract failures into actionable repair hints for users and agents, including duplicate channel merge guidance, layer-local keyframe timing, sorted keyframes, readable holds, same-property overlap, and forward typewriter direction. Scene Generate and pasted direct Scene Program JSON now expose these hints when rejecting invalid output. This is extraction/domain feedback infrastructure and does not touch Stage5 or Live Scrub.
- Motion Director Phase D9 lifetime and completion contract: `ProfessionalSceneTimingContractValidator` now enforces primitive ownership by an existing beat, requires the owning beat to reference the animated component, rejects primitives outside their beat time range, rejects empty Scene Program channels, and warns when a visible component's final motion ends exactly at the scene boundary without a resolve/hold moment. This is domain-only timing infrastructure and does not touch Stage5 or Live Scrub.
- Motion Director Phase D10 explicit overlap intent: `ReFusionMotionDirectorLinter` now rejects beat overlap on distinct components unless the Director Plan explicitly marks the overlap as parallel/while/meanwhile/alongside/during choreography, and rejects shared-component disjoint-property overlap unless it is explicitly described as handoff/morph/transform/expand/collapse choreography. This closes a major source of random-looking simultaneous motion while preserving intentional parallel and handoff animation. This is Director/domain validation only and does not touch Stage5 or Live Scrub.
- Motion Director Phase D11 direct Scene Program completion holds: `ProfessionalSceneTimingContractValidator` now also applies timing taste directly to pasted/generated Scene Program JSON. Text reveal/typewriter channels are rejected when their final reveal leaves no readable hold inside the owning layer, and visible non-exit final motion warns when it leaves no completion hold. This is domain validation only and does not touch Stage5 or Live Scrub.
- Super Professional Engine like After Effects plan: `docs/super_professional_engine_like_after_effects.md` now defines the official tutorial-to-capability workflow, capability taxonomy, registry contract, choreography rules, and `Present` demo-library purpose. Tutorials must produce reusable engine capabilities, not one-off cloned presets.
- Super Professional Engine M1 foundation: Scene Program import/lowering now accepts `kind: "mask"` elements, preserves mask/reveal metadata such as `maskTarget`, `maskMode`, and `revealDirection`, lowers `movingMaskReveal`/`maskReveal` aliases into editable `mask.revealProgress` channels, and supports shape morph aliases such as `morphSize` and `roundness` as canonical width/height/cornerRadius channels. This is reusable domain/editing foundation only; preview/export mask compositing remains a future renderer slice, and Stage5/Live Scrub are untouched.
- Present Demo P2 Codex Prompt Bloom: the Present sheet now includes a D11 timing demo with a white-field welcome title, black rounded-square Codex icon, icon-to-prompt morph, left send/right plus controls, typewriter prompt text, send press, and a white cover-circle resolve. It is authored as one editable Scene Program preset and does not touch Stage5 or Live Scrub.
- Text Professional Pack foundation: Scene Program text now carries real typography through lowerer, preview, and render adapters for `fontWeight`, `fontFamily`, `fontStyle`, `lineHeight`, and `textAlign`; `fontWeight` and `lineHeight` are exposed in the editable text scope property catalog. This improves agent-authored typography without touching Stage5 or Live Scrub.
- Modern UI Motion Pack V1 foundation: Scene Program shape/icon elements now carry reusable `effects.softShadow` controls (`shadowOpacity`, `shadowBlur`, `shadowOffsetX/Y`, `shadowSpread`, `shadowColor`) through import/lowering and shape preview, with scalar shadow controls exposed in Shape Layer Scope. Native export parity for authored visual shadows remains a tracked renderer gap. This does not touch Stage5 or Live Scrub.
- Modern UI Motion Pack V1 line reveal foundation: Scene Program line shapes now carry reusable `shape.trimPath` controls (`trimStart`, `trimEnd`, `trimOffset`) through import/lowering and line preview, with scalar trim controls exposed in Shape Layer Scope and Mention Motion patches. Native export parity for authored visual trim paths remains a tracked renderer gap. This does not touch Stage5 or Live Scrub.
- Text Range Selector V1 foundation: Scene Program and Mention Motion patches now accept After Effects-style text aliases such as `wordRangeSelectorProgress`, `letterRangeSelectorProgress`, `rangeSelectorProgress`, and `trackingAmount`, lowering them into editable `revealProgress` and `letterSpacing` channels with proper word/letter text preview bindings. This does not touch Stage5 or Live Scrub.
- Modern UI Composition Grammar V1 layout foundation: Scene Program now has a strict layout/parent contract for inspectable UI composition. Elements may declare `parentId`, `containerId`, `parentGroup`, `layoutRole`, `layoutMode`, `padding`, `gap`, `align`, `justify`, `anchor`, `safeArea`, `constraints`, and `zIndex` metadata. Authoring rejects missing parent references, duplicate element IDs, parent cycles, and children whose layer lifetime escapes the parent lifetime; lowering preserves the metadata under `sourceBinding.metadata` for future Scene Scope, Layer Scope, Mention Motion, preview, and export adapters. This is domain/authoring infrastructure only and does not touch Stage5 or Live Scrub.
- Composition Workspace Orchestration plan: `docs/professional_composition_workspace_and_scene_orchestration_plan.md` defines the official workflow for composition-first startup, default Scene Clip containers, context-aware Add, Scene create/modify semantics, mobile outliner, selection-driven inspector, scene transitions, agent context, preview/export parity, mandatory checkpoints, and Live Scrub protection.
- Composition Workspace W2 manual create settings: the Create Composition sheet now treats presets as editable starting points and exposes project name, width, height, FPS, duration, and background metadata before creating the root composition and initial `Scene 01` container. The created project preserves its actual canvas size and frame rate instead of being forced back to a fixed 1080-wide format.
- Composition Workspace W2 preview background wiring: the project composition background color now drives the Flutter preview canvas/background for empty compositions, scene clips, shape/text overlays, and media poster fallback. Export/native render parity for composition backgrounds remains a tracked future renderer step.
- Composition Workspace W3 scene scope command separation: opening a Scene Clip now shows a Scene Contents toolbar instead of layer/keyframe/frame controls. Scene Scope bottom actions are context-aware: `Media` imports image/video layers into the open scene, while Shape/Text have direct layer insertion buttons and Audio/Null/Adjustment remain explicit planned layer commands. Unified Layer Scope keyframe controls appear only after opening an internal layer.
- Composition Workspace W3 Scene Contents media refinement: the Scene Scope bottom `Media`/plus command opens only Video Layer and Image Layer import for the open source scene. Text and Shape remain direct bottom-dock element commands, while Audio/Null/Adjustment remain visible planned dock commands. This keeps media insertion separate from element creation and layer-scope keyframes, and does not touch Stage5 or Live Scrub.
- Composition Workspace W3 layer-scope authoring dock: Scene Layer Scope now preserves the opened layer visual identity, so image layers render with image icons instead of composition icons, and the keyframe dock exposes `Animate`, `Effects`, `Key`, `Value`, and `Graph` as the focused authoring surface. Animate/Effects selections create real graph-backed property channels through the unified layer-scope keyframe adapter, without touching Stage5 or Live Scrub.
- Composition Workspace W3 image preview parity: Scene image layers now render through a graph-evaluated `MotionImagePreviewOverlay`, so authored `position`, `scale`, `rotation`, `opacity`, and `blur` channels are visible in the composition preview instead of being hidden behind the old static poster fallback. This is Flutter preview parity only and does not touch Stage5 or Live Scrub.
- Composition Workspace W3 paired value editing: Scene Layer Scope value editing now treats paired numeric properties as professional compound controls. Selecting Position opens X/Y together, selecting Scale opens X/Y together, and selecting Shape Size opens Width/Height together; each slider still writes to its own real graph keyframe through `LayerScopeCompositionAdapter`. This keeps the visible value workflow aligned with actual timeline data and does not touch Stage5 or Live Scrub.
- Composition Workspace W3 paired keyframe operations: Scene Layer Scope now keeps paired numeric keyframes together for the common compound properties. Adding, moving, or deleting a Position/Scale/Shape Size keyframe also applies to its sibling channel when both channels share the same local keyframe time, preserving mobile-friendly compound editing while still storing real per-channel graph data. This does not touch Stage5 or Live Scrub.
- Composition Workspace W5 inspector write-back entry: the mobile Inspector can now commit real Scene Clip instance edits for transform, opacity, enabled/locked state, and draw order. Editable rows open exact-value controls or toggle booleans, then update `_sceneClips` and reproject the root Scene track instead of changing UI-only text. Layer/element/keyframe write-back remains a future W5 slice. This does not touch Stage5 or Live Scrub.
- Composition Workspace W5 layer/element inspector write-back: the mobile Inspector can now commit real source-layer edits for timing, enabled state, static opacity, and z-index, plus source-element edits for timing, enabled state, and static opacity. Static opacity edits are stored as real `MotionPropertyAssignment` values on the selected layer/element, keeping Inspector edits visible to the motion compiler rather than creating detached UI state. This does not touch Stage5 or Live Scrub.
- Composition Workspace W5 keyframe inspector write-back: selected Scene Layer Scope keyframes can now surface as formal Inspector targets and commit real graph edits for keyframe time, scalar/integer/boolean value, and interpolation cycling. The edit path updates the owning `MotionPropertyChannelModel` directly and preserves selection by keyframe id, so Inspector edits are timeline data rather than UI-only annotations. This does not touch Stage5 or Live Scrub.
- Composition Workspace root layering amendment: the plan now distinguishes project background metadata from future editable root background layers, and requires Scene Clip instances to behave like transformable composition-layer cards above that root background. Instance transform/opacity/crop/effects/draw order belong to the root clip instance; opening the clip still edits the nested source scene.
- Composition Workspace W1 root-layering domain foundation: `CompositionSceneClipModel` now stores instance visual style data separately from source scene timing, including transform, opacity, crop, effects, and draw order. `CompositionWorkspaceModel` now stores root background layer projections and can resolve visible background layers at root time. This is domain/test infrastructure only and does not touch Stage5 or Live Scrub.
- Composition Workspace W1 root-layer projection foundation: `RootCompositionLayerProjectionAdapter` now projects editable root background layers and Scene Clip instances into one deterministic draw-order list for future outliner, inspector, preview, and export adapters. It preserves Scene Clip instance transform/opacity/effects metadata and allows overlapping scene cards through explicit z-index rather than exploding source-scene internals onto the root timeline. This is presentation adapter/test infrastructure only and does not touch Stage5 or Live Scrub.
- Composition Workspace W4 outliner projection foundation: `CompositionWorkspaceOutlinerAdapter` now projects the workspace into a professional hierarchy: Project, Assets, Root Composition, Background Layers, Scene Clip instances, Source Compositions, Layers, Elements, and editable Channels. It preserves draw order, selection targets, channel ownership, and root-layer projection issues for the future mobile outliner sheet. This is presentation adapter/test infrastructure only and does not touch Stage5 or Live Scrub.
- Composition Workspace W4 mobile outliner entry: the top-left editor button now opens a mobile Outliner sheet driven by `CompositionWorkspaceOutlinerAdapter`. Users can inspect project hierarchy, root background, Scene Clip instances, source compositions, layers, elements, and channels, select root Scene Clips, and jump into a source composition/layer from the tree. Rename/delete/duplicate and the formal Inspector remain future W4/W5 slices. This UI wiring does not touch Stage5 or Live Scrub.
- Composition Workspace W5 inspector projection foundation: `CompositionWorkspaceInspectorAdapter` now resolves the active workspace selection into a formal inspector model for root compositions, Scene Clip instances, source compositions, layers, elements, and keyframes. It exposes timing/source/transform/style/effects/draw-order/graph sections while preserving instance/source ownership and reporting missing targets instead of creating fake UI values. This is presentation adapter/test infrastructure only and does not touch Stage5 or Live Scrub.
- Composition Workspace W5 mobile inspector sheet: the editor top bar now exposes a read-only Inspector bottom sheet backed by `CompositionWorkspaceInspectorAdapter`. It lets the user inspect current selection properties without write-back yet, preserving the separation between Outliner navigation, Timeline timing, and Inspector properties. This UI wiring does not touch Stage5 or Live Scrub.
- Composition Workspace W6 selected-scene insertion: root `Add > New Scene` now inserts a new empty Scene Clip immediately after the selected Scene Clip and shifts later sequential Scene Clips forward to preserve a non-overlapping story sequence. Without a selected Scene Clip, New Scene still appends to the end. This is root composition sequencing only and does not touch Stage5 or Live Scrub.
- Phase 4/5B+: open. Scope projection wiring, UI adapters, motion graph import, transition unification, scriptable scene programs, and export parity must be built on top of the clock/keyframe foundations.
- Live Scrub status: protected. Stage5 Live Scrub is not part of a rewrite. It is a production path that must remain fast, precise, and native-optimized.

## 0. Non-Negotiable Live Scrub Protection

Live Scrub is a protected production path.

This plan must not rebuild, replace, or degrade the current Stage5 Live Scrub path. Any implementation must treat Live Scrub as a high-value existing capability and integrate with it through an adapter layer first.

Strict rules:

- Do not rewrite the Stage5 Live Scrub engine as part of this plan.
- Do not modify Stage5 Live Scrub native files unless a specific, reviewed fix requires it.
- Do not use timeline, keyframe, transition, or script work as a reason to weaken scrub responsiveness.
- Do not accept any phase if fast scrub, slow scrub, zoomed-in scrub, or reverse scrub regresses.
- If a clock or motion engine fix conflicts with scrub quality, stop and redesign the integration layer.
- The target is 100% professional stability, not a visual mask over a timing mismatch.

The goal is to make Live Scrub safer by giving it a proper timeline, geometry, and evaluation contract, not to disturb the working scrub path.

## 1. Master Goal

Build one professional motion system for ReFusion:

```text
Professional Timeline Clock
-> Unified Timeline Geometry
-> Unified Keyframe Operations
-> Unified Motion Property Graph
-> ReFusion Scene Program
-> Preview And Export Parity
```

Every manual edit, preset, transition, imported script, and future AI-generated motion scene must land in the same editable model:

```text
Scene
Layer
Element
Effect Instance
Property Channel
Keyframe
Interpolation
```

No feature may create a private animation engine that cannot be inspected, edited, scrubbed, previewed, exported, or represented in a scope timeline.

## 2. Current Architectural Problem

The app currently has several useful systems, but they are not fully unified:

- Timeline clock and native playback are being centralized, but some UI paths still historically wrote time directly.
- Layer Scope uses real motion channels for some text workflows, but image/shape parity is not complete.
- Transition Scope has manual lanes and script lanes, but they are not yet the same graph as layer motion.
- Script import exists for scoped text and transitions, but both are specialized importers.
- Timeline UI lanes can represent keyframes, but they are not always direct projections of `MotionPropertyChannelModel`.
- Export supports several motion programs, but preview/export parity is not yet guaranteed for every effect.

The professional requirement is:

```text
playhead time
= scroll geometry
= preview frame
= native player position
= scoped local time
= keyframe evaluation time
= export evaluation time
```

## 3. Final Architecture

### 3.1 Timeline Clock

`TimelineClockCoordinator` owns timeline time and interaction phase.

It is the only component allowed to decide the current global timeline time.

Other systems may request time changes, but they must not independently write:

- timeline display time,
- scroll position as time truth,
- preview evaluation time,
- native playback time,
- scoped local time,
- keyframe evaluation time.

### 3.2 Timeline Geometry

`TimelineGeometryMapper` owns deterministic time-to-pixel mapping.

```text
scrollOffset = geometry.offsetForTime(clock.time)
time = geometry.timeForOffset(scrollOffset)
```

Rules:

- The playhead is fixed in viewport space.
- The content scrolls according to clock time.
- Zoom preserves the exact anchor frame.
- Zoom must not change preview frame.
- Native scrub regions, ruler labels, clip bounds, transition windows, and keyframe lanes use the same mapper.

### 3.3 Unified Keyframe Operations

All keyframe operations must use identity-based operations, not index-based operations.

Required operations:

```text
addKeyframe(channelId, localTime, value)
moveKeyframe(keyframeId, localTime)
setKeyframeValue(keyframeId, value)
setKeyframeInterpolation(keyframeId, interpolation)
deleteKeyframe(keyframeId)
selectKeyframe(keyframeId)
moveSelectedKeyframeToPlayhead()
```

Rules:

- A keyframe has a stable ID.
- Moving a keyframe never changes which keyframe is selected.
- Sorting by time must not lose identity.
- Time collisions must not silently drop keyframes.
- Multi-channel properties such as Position must move as a group when they represent one user-visible keyframe.
- UI lanes, Layer Scope, Transition Scope, and script import must call the same keyframe operation layer.

### 3.4 Unified Motion Property Graph

The canonical animation model is a property graph:

```text
MotionProject
MotionScene
MotionLayer
MotionElement
MotionEffectInstance
MotionPropertyChannel
MotionKeyframe
MotionInterpolationSpec
```

Everything compiles to this graph:

- manual canvas edits,
- scoped text animation,
- image animation,
- shape animation,
- transition presets,
- transition scripts,
- imported scene programs,
- future agent-generated motion graphics.

No feature may keep a permanent separate lane model that cannot be lowered into this graph.

### 3.5 ReFusion Scene Program

`ReFusionSceneProgram` is the scriptable authoring format.

It is a declarative data document, not executable code.

Allowed:

- JSON first.
- YAML may be allowed later if validation is identical.
- Strict schema versioning.
- Declarative layers, elements, effects, channels, keyframes, easing, and asset references.

Forbidden:

- JSX.
- JavaScript execution.
- `eval`.
- external imports.
- hidden runtime code.
- shader source embedded directly in user scripts.

The importer pipeline:

```text
External script or agent output
-> ReFusionSceneProgram validation
-> scope and target resolver
-> effect and channel lowerer
-> MotionAuthoringBundle
-> transaction
-> MotionPropertyChannelModel
-> preview/export graph
```

### 3.6 Scope Projection

Scopes are projections, not separate engines.

```text
layerLocalTime = globalClock.time - layerStartTime
transitionLocalTime = globalClock.time - transitionWindowStartTime
```

Layer Scope, Transition Scope, and future Scene Scope must share:

- one clock,
- one geometry mapper,
- one keyframe operation layer,
- one evaluator contract,
- one undo/redo transaction model.

### 3.7 Preview And Export Parity

Preview and export must evaluate the same graph.

The preview pipeline may be optimized, and export may run elsewhere, but both must consume the same normalized motion data:

```text
MotionGraph + clock/evaluation time -> visual state
```

Any effect accepted into the product must define:

- preview behavior,
- scrub behavior,
- playback behavior,
- export behavior,
- fallback or blocker behavior if unsupported.

## 4. Timeline Clock Contract

The coordinator exposes a strict state machine:

- `idle`
- `paused`
- `scrubbing`
- `scrubSettling`
- `playStarting`
- `playing`
- `pausing`
- `seeking`
- `zooming`
- `structuralEditing`

Invalid combinations are forbidden.

Examples:

- The system must not be `playing` and `scrubSettling` at the same time.
- The system must not be `zooming` while accepting timeline time drift from playback samples.
- The system must not be `scrubbing` while playback samples drive visible time.

Every phase defines:

- who may request time changes,
- who may confirm time changes,
- whether native transport is authoritative,
- whether preview frames are requested or streamed,
- whether scroll is user-owned or clock-owned.

All timeline time changes must go through coordinator commands:

```dart
clock.scrubStart(anchorTime);
clock.scrubUpdate(targetTime);
clock.scrubEnd(finalTime);
clock.playFrom(time);
clock.pauseAt(time);
clock.seekTo(time);
clock.zoomStart(anchorTime);
clock.zoomUpdate(anchorTime, scale);
clock.zoomEnd(anchorTime);
clock.applyNativeSample(sampleTime);
clock.applyStructuralEdit(resultingTime);
```

No widget should coordinate playback by mixing:

- `setCurrentTime`,
- `setPlaybackSampleTime`,
- native `seekTo`,
- native `play`,
- scroll `jumpTo`.

Those actions must become coordinator-owned side effects.

## 5. Playback Contract

When the user presses Play:

1. Read start time from `TimelineClockCoordinator`.
2. End or supersede any pending scrub settle for that target time.
3. Send one native command: `playFrom(startTime)`.
4. Enter `playStarting(startTime)`.
5. Reject stale native samples older than the requested start time.
6. Accept the first valid native sample as playback confirmation.
7. Enter `playing`.
8. Drive preview, timeline scroll, ruler, keyframes, effects, transitions, and scopes from accepted clock time.

Acceptance criteria:

- Play after forward scrub starts from the exact final scrub frame.
- Play after reverse scrub starts from the exact final scrub frame.
- Pause then Play starts from the exact paused frame.
- No track jump.
- No refresh flash.
- No preview/timeline divergence.

## 6. Live Scrub Contract

Live Scrub remains native-optimized, but its lifecycle is represented in the coordinator.

Flow:

```text
native scrub down -> clock.scrubStart(anchorTime)
native scrub move -> clock.scrubUpdate(time)
native scrub up   -> clock.scrubEnd(finalTime)
native settle     -> clock.scrubSettling(finalTime)
settle complete   -> clock.pausedAt(finalTime)
```

The coordinator must not slow down scrub input. It adapts scrub events; it does not replace the scrub engine.

Acceptance criteria:

- Fast Live Scrub remains responsive.
- Slow Live Scrub remains stable frame-by-frame.
- Reverse Live Scrub does not jitter between adjacent frames.
- Deep zoom Live Scrub remains precise.
- Scrub-to-play handoff has no jump.

## 7. Native Transport Adapter

Native transport is authoritative only in these phases:

- `playStarting`, after first valid confirmed sample.
- `playing`, for accepted playback samples.
- `seeking`, when confirming requested seek completion.

It is not authoritative during:

- user scrub updates,
- zoom gestures,
- structural edit transactions,
- scoped timeline edits,
- manual keyframe dragging.

The adapter exposes typed events:

```dart
NativePlaybackStarted(requestedTime, firstSampleTime)
NativePlaybackSample(sampleTime)
NativePlaybackPaused(positionTime)
NativeSeekConfirmed(requestedTime, actualTime)
NativeScrubSettleConfirmed(targetTime)
NativeTransportStalled(lastKnownTime)
```

Raw native position events must not directly mutate UI time.

## 8. Keyframe And Effect Evaluation Contract

All keyframe and effect evaluation reads from:

```dart
clock.evaluationTime
```

No effect may evaluate from:

- widget local state,
- scroll position,
- native raw position,
- stale playback sample,
- independent scoped timer.

This applies to:

- opacity,
- position,
- scale,
- rotation,
- blur,
- color,
- text animation,
- imported script motion,
- transition parameters,
- future shape/image/video effects.

## 9. Transition Contract

Transitions are first-class timeline windows driven by the same clock.

Transition scope uses:

```text
transitionProgress = (globalClock.time - transitionWindowStart) / transitionWindowDuration
```

Rules:

- Transition keyframes change real transition timing.
- Presets and imported scripts compile to the same property channels.
- Preview and export use the same transition evaluator.
- Transition Scope must not invent a separate playback clock.
- Manual transition lanes are temporary UI projections until transition channels are lowered into the canonical graph.

## 10. Script And Agent Authoring Contract

Future agents should not generate app-private hacks.

They should generate a `ReFusionSceneProgram` document that the app validates and lowers into editable motion data.

A generated scene must be inspectable:

- layers visible in timeline,
- elements visible on canvas,
- effects visible in scope,
- keyframes visible on lanes,
- values editable through inspectors,
- timing editable by dragging or move-to-playhead,
- preview and export matching the same authored data.

The import UX must support:

- paste script,
- upload file,
- validation report,
- preview before apply,
- apply as transaction,
- undo/redo as one command,
- edit after import.

## 11. Undo/Redo Transaction Contract

Every user operation must be a transaction.

Required transaction groups:

- add media,
- cut/trim/move clip,
- add layer,
- edit layer style,
- enter/exit scope without mutation,
- add effect,
- add keyframe,
- move keyframe,
- set keyframe value,
- set interpolation,
- import script,
- apply transition preset,
- edit transition keyframe.

Undo/Redo must not be left as a later polish item. It is part of professional timeline safety.

## 12. Implementation Phases

### Phase 0: Audit And Baseline Freeze

Document all current writers of time, scroll, keyframe lanes, effect values, transition lanes, and script import outputs.

Exit criteria:

- A list of all writers exists.
- No code behavior change.

### Phase 1: Timeline Clock Foundation

Complete `TimelineClockCoordinator` ownership for playback, pause, scrub handoff, and native playback samples.

Exit criteria:

- Pause/play has no jump.
- Forward scrub then play has no jump.
- Reverse scrub then play has no jump.
- Existing Live Scrub quality is unchanged.

### Phase 2: Timeline Geometry Foundation

Route all time-to-offset and offset-to-time mapping through `TimelineGeometryMapper`.

Exit criteria:

- Zoom preserves exact frame.
- Playback moves real scroll, not visual-only transforms.
- Native scrub regions update from the same geometry.
- Main timeline, Layer Scope, and Transition Scope share the same mapping rules.

### Phase 3: Live Scrub Adapter Hardening

Wrap Live Scrub events into coordinator commands without rewriting scrub internals.

Exit criteria:

- Slow scrub is stable.
- Reverse scrub is stable.
- Deep zoom scrub is stable.
- Scrub-to-play remains exact.
- No Stage5 regression.

### Phase 4: Scoped Timeline Projection

Connect Layer Scope and Transition Scope as projections of the global clock.

Exit criteria:

- Scoped playback matches main timeline playback.
- Scoped scrub matches main timeline scrub.
- Scope local time is derived, not independently owned.
- Transition scope does not drift from global timeline.

### Phase 5: Unified Keyframe Operations

Create a shared keyframe operation layer used by Layer Scope, Transition Scope, and script imports.

Exit criteria:

- Keyframes use stable IDs.
- Add/move/delete/value/interpolation behavior is identical across scopes.
- Move-to-playhead is available where keyframes exist.
- Time collisions are explicit, not silent.
- Position-like compound channels can move as one visible keyframe group.

Current foundation:

- `UnifiedKeyframeOperations` provides add, move, grouped move-to-time, value edit, interpolation edit, delete, and selection helpers over `MotionPropertyChannelModel`.
- `CanvasTimelineUnifiedKeyframeAdapter` proves Layer Scope keyframe operations can route through the unified operation layer while preserving existing canvas timeline channel/keyframe IDs.
- The current slice is domain/adapter only and must not replace the production Layer Scope UI path until the next wiring checkpoint is separately verified.
- This slice intentionally avoids `Stage5TimelineScrubPlatformView`, `Stage5NativeScrubEngine`, `Stage5SurfaceScrubDecoder`, and `Stage5PreviewPlatformView`.

### Phase 6: Motion Property Graph Lowering

Lower UI lanes, direct effects, transition lanes, and scoped script imports into canonical motion property channels.

Exit criteria:

- `TimelineAnimationLaneData` is a projection, not permanent source of truth.
- Text, image, shape, and transition motion all have graph-backed channels.
- Existing text script import is moved out of screen code into a reusable domain lowerer.

### Phase 7: ReFusion Scene Program V1

Define and implement a strict declarative script format.

Exit criteria:

- JSON schema exists.
- Schema version is required.
- Importer produces a `MotionAuthoringBundle`.
- Imported scene can create layers, elements, effects, channels, and keyframes.
- Imported scene remains editable in the UI.

### Phase 8: Preview Evaluator Parity

All preview surfaces read from the same normalized motion graph.

Exit criteria:

- Manual keyframes work in scrub/play.
- Scripted effects work in scrub/play.
- Transition keyframes are real, not visual-only.
- Preview does not use a private effect path unavailable to export.

### Phase 9: Export Parity

Export consumes the same normalized graph and interpolation semantics as preview.

Exit criteria:

- Preview and export match within accepted visual tolerance.
- Unsupported effects produce explicit blockers.
- No effect is accepted if it cannot be represented in export or clearly marked preview-only.

### Phase 10: Agent Authoring Contract

Create the documentation that external agents use to generate valid `ReFusionSceneProgram` files.

Exit criteria:

- Agent prompt contract exists.
- Example scripts exist for text intro, promo card, transition, lower third, and motion graphic scene.
- Validation errors are human-readable.
- Imported agent output is visible and editable as normal timeline/keyframe data.

## 13. Test Matrix

Required tests before accepting relevant phases:

- Play from paused frame.
- Pause at frame, play again.
- Forward Live Scrub, release, play.
- Reverse Live Scrub, release, play.
- Live Scrub while playing.
- Zoom in then play.
- Zoom out then play.
- Deep zoom slow scrub.
- Main timeline playback.
- Layer Scope playback.
- Transition Scope playback.
- Keyframe add/move/delete/value edit.
- Keyframe drag then play.
- Keyframe move-to-playhead then play.
- Effect value edit then scrub/play.
- Script import then scrub/play.
- Transition preset then scrub/play.
- Preview/export parity probe for every accepted effect family.

## 14. Rejection Criteria

Reject any implementation if:

- Live Scrub becomes slower.
- Play causes a visible jump.
- Preview moves while timeline does not.
- Timeline moves while preview does not.
- Playhead can move outside real timeline content.
- Keyframes evaluate differently in scrub and playback.
- Scope timeline uses a separate clock engine.
- A visual transform hides a real clock mismatch.
- Script import creates hidden motion that cannot be edited.
- Export differs from preview without an explicit documented blocker.

## 15. Final Target

The final target is a 2026-grade ReFusion motion engine:

- one clock,
- one geometry mapper,
- one keyframe operation layer,
- one motion property graph,
- one scene program importer,
- one preview evaluator contract,
- one export parity contract,
- scope timelines as projections,
- scripts as editable data,
- no fake visual correction,
- no Live Scrub regression,
- no playback jump,
- no preview/timeline divergence.

This plan is the foundation for professional transitions, scoped layer animation, direct effects, scriptable motion graphics, future AI-generated scenes, and reliable export.
