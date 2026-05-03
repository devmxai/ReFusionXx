# fixAnimateFX on transition timeline

Status: strict implementation plan for the writer agent  
Package: `com.refusion.app`  
Branch: `codex/unified-keyframe-ops-foundation-20260426`  
Baseline at planning time: `9c799e0` (`checkpoint: gate manual transition legacy renderer to preview`)  
Depends on:
- `docs/master_clock_value_truth_foundation_plan.md`
- `docs/master_live_scrub_professional_plan.md`
- `docs/live_scrub_migration_mandate.md`
- `docs/professional_refusion_motion_keyframe_engine.md`
- `docs/professional_checkpoint_policy.md`

## 0. Purpose

This plan fixes the current Manual Transition Timeline failure:

```text
Manual Transition Timeline
-> add Animate/FX lane
-> add keyframes
-> edit keyframe value
-> preview freezes, Play/Live Scrub show a stuck frame or audio-only output
-> the authored Scale/Opacity/etc. does not affect the actual video
```

The professional target is:

```text
manual transition lanes/keyframes
-> master time/value evaluation
-> LiveScrubVisualProgram
-> Stage5-owned display path
-> same video surface output, no legacy transition overlay
```

Manual transition Animate/FX must become real graph/runtime data consumed by the
master display path. It must not be a bitmap preview overlay, thumbnail
fallback, second player, second clock, or `MediaMetadataRetriever` loop.

## 1. Writer Operating Contract

Before editing code, the writer must read:

1. `/Users/mx/.codex/skills/refusion-development-guardrails/SKILL.md`
2. `docs/professional_checkpoint_policy.md`
3. `docs/live_scrub_migration_mandate.md`
4. `docs/master_clock_value_truth_foundation_plan.md`
5. `docs/master_live_scrub_professional_plan.md`
6. `docs/professional_refusion_motion_keyframe_engine.md`
7. this file

Then run:

```bash
git status -sb
git rev-parse --short HEAD
```

Rules:

- Ignore unrelated untracked `../../../.claude/`.
- Do not stage unrelated dirty files.
- Every completed slice must be verified, committed with `checkpoint: ...`, and
  pushed.
- If runnable app code changes, build and install the APK on the connected
  device when available.
- Update relevant app docs after each implementation slice.
- Update `/Users/mx/Documents/refusion-skills` when the slice changes rules an
  agent must know.

## 2. Protected Boundary

This plan eventually requires Stage5 and Live Scrub integration. The following
files are protected by `docs/live_scrub_migration_mandate.md` and the local
guardrails:

- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`
- `Stage5PreviewPlatformView`
- Flutter Live Scrub handoff paths

The writer must not edit protected files until the current slice explicitly
names the exact file(s) and the user has explicitly approved that slice.

Implementation must stop at this boundary if approval has not been granted.

## 3. Verified Diagnosis

This diagnosis was reviewed against the baseline code by an additional
read-only agent. The reviewer confirmed the main failure chain and added one
important correction:

- the legacy professional transition compositor uses bitmap/extractor work for
  manual interactive rendering;
- the Stage5 scrub path itself is not a `lockCanvas/drawBitmap` scrub renderer;
  `Stage5SurfaceScrubDecoder` decodes through `MediaCodec` to a `Surface`;
- therefore the Stage5 work is not "replace a canvas blit" as a first
  assumption. It is "extend the existing Stage5 scrub/playback output contracts
  so transform/opacity/effects can be applied truthfully without creating a
  second renderer."

### RC1 - Manual preview still enters the legacy compositor

At baseline `9c799e0`, manual transitions are blocked from legacy rendering in
`liveScrub` and `playback`, but `preview` remains open:

```text
_canRenderProfessionalTransitionInteractivelyInMode(manual, preview) == true
```

That lets the following path run while the user edits keyframes:

```text
manualEffectIds.isNotEmpty
-> active transition inside seam
-> ProfessionalVideoTransitionRenderPlan exists in preview
-> NativePreviewSurface is suppressed
-> ProfessionalVideoTransitionSurfaceOverlay is mounted
-> renderInteractiveFrame
-> ProfessionalVideoTransitionCompositorManager
-> MediaMetadataRetriever.getFrameAtTime
```

This can detach or starve the real video surface and creates decoder churn. The
symptom is a stuck preview frame while audio may continue.

### RC2 - Manual Animate/FX values are not consumed by Stage5

Manual transition keyframes currently live in:

```text
TimelineTrackTransitionData.manualAnimationLanes
TimelineAnimationLaneData.normalizedKeyframeStops
TimelineAnimationLaneData.keyframeValues
```

Those values are used to build legacy `manualTransform` parameters, but they are
not lowered into `MasterEvaluatedPropertyValue` for Stage5-owned rendering.

### RC3 - Runtime descriptor projection exists but is not enough

`MasterLiveScrubProgramAdapter` and `MasterLiveScrubDescriptorProjection` can
describe transforms, opacity, effects, roles, and transition progress, but the
current runtime surface adapter and native scrub descriptors do not transport or
apply the full visual program to pixels.

### RC4 - Native runtime bridge is diagnostic-only today

`submitLiveScrubRuntimeBridgeSnapshot` currently accepts and stores a payload
for diagnostics. It does not update Stage5 rendering state or affect displayed
pixels.

### RC5 - The existing plan condition wrongly depends on legacy render plans

Runtime projection currently depends on `_professionalTransitionRenderPlanFor`.
When the legacy plan is gated off for `liveScrub` and `playback`, the master
runtime projection also disappears. Manual transition values need a separate
master-runtime path that does not depend on professional transition render
plans.

## 4. Non-Negotiable Output Contract

When this plan is complete:

- adding `Scale` in Manual Transition Timeline must not freeze preview;
- adding keyframes must not trigger the legacy compositor;
- editing keyframe values must not detach `NativePreviewSurface`;
- Play must show video and audio;
- Live Scrub must keep moving visually;
- Scale/Opacity/Position/Rotation must affect the actual video surface;
- unsupported FX must block with explicit diagnostics, not fake pixels;
- no manual transition authoring path may call `renderInteractiveFrame`;
- no manual transition authoring path may call `MediaMetadataRetriever` for
  interactive preview, playback, or Live Scrub;
- no manual transition path may create a second playback/display surface as a
  visual fallback.

## 5. Implementation Strategy

Use two tracks in order:

1. **Stabilization track:** stop the freeze immediately by disconnecting manual
   transition authoring from the legacy compositor.
2. **Authoring truth track:** prove manual lanes/keyframes lower into master
   value truth without any renderer side effect.
3. **Runtime rendering track:** connect manual transition values to the master
   Stage5 display path in small approved slices.

Do not pretend that the stabilization slice renders Scale. It only prevents the
freeze and preserves editable keyframe data. The plan is not complete until the
runtime rendering track displays the authored values on the video.

## 6. Phase 0 - Approval And Baseline Inventory

Goal: lock the dependency boundary before the writer touches Stage5.

Allowed changes:

- docs;
- tests that inspect existing APIs;
- no behavior changes.

Deliverables:

- confirm current device/app reproduction notes;
- confirm the current branch and baseline commit;
- list exact protected files required by later phases;
- request explicit user approval before any Stage5-protected implementation
  slice.

Verification:

```bash
rg "ProfessionalVideoTransitionSurfaceOverlay|renderInteractiveFrame|MediaMetadataRetriever|submitLiveScrubRuntimeBridgeSnapshot" lib android
flutter analyze
```

Checkpoint:

```text
checkpoint: document transition animate fx fix baseline
```

## 7. Phase 1 - Manual Legacy Renderer Kill Switch

Goal: Manual Transition authoring must never mount the legacy interactive
transition renderer in any mode.

Required changes:

- make manual transitions return `false` from the legacy interactive renderer
  gate for `preview`, `liveScrub`, and `playback`;
- prevent manual transitions from creating `ProfessionalVideoTransitionRenderPlan`
  for interactive UI authoring;
- prevent `manualEffectIds` from suppressing `NativePreviewSurface`;
- prevent `ProfessionalVideoTransitionSurfaceOverlay` from mounting for manual
  transitions;
- keep non-manual professional preset behavior unchanged unless a test proves it
  must be separated.

Forbidden:

- no Stage5 native edits;
- no Live Scrub protected edits;
- no fake bitmap fallback;
- no deletion of manual keyframe data.

Acceptance:

- adding a manual `Scale` lane does not mount
  `ProfessionalVideoTransitionSurfaceOverlay`;
- adding/editing manual keyframes does not call `renderInteractiveFrame`;
- preview remains visually stable even though manual Scale is not visible yet;
- Play and Live Scrub do not become audio-only after a value edit.

Targeted tests:

```bash
flutter test test/<new_manual_transition_legacy_renderer_gate_test>.dart
flutter analyze
```

Device validation after build:

- open Manual Transition Timeline;
- add `Scale`;
- add two keyframes;
- edit the second value;
- confirm no freeze.

Checkpoint:

```text
checkpoint: block manual transition legacy renderer
```

## 8. Phase 2 - Data-Only Authoring Guard

Goal: adding Animate/FX/keyframes must be a pure data mutation until the master
runtime path consumes the values.

Required changes:

- audit all manual transition authoring handlers:
  - add Animate/FX lane;
  - add keyframe;
  - move keyframe;
  - edit value;
  - delete lane/keyframe;
- prove those handlers only update transition data and selection state;
- prevent those handlers from building render plans, mounting surfaces, or
  submitting legacy render requests;
- keep the timeline UI responsive and editable even when native visual support
  is not implemented yet;
- add diagnostics that say "manual transition visual runtime not attached" only
  when needed, without freezing or falling back to thumbnails.

Forbidden:

- no Stage5 native edits;
- no legacy preview renderer;
- no fake visual fallback;
- no disabling keyframe editing.

Targeted tests:

```bash
flutter test test/<new_manual_transition_data_only_authoring_test>.dart
flutter analyze
```

Acceptance:

- adding Animate/FX does not change preview surface ownership;
- adding/editing keyframes does not call the professional compositor client;
- `manualEffectIds` and `manualAnimationLanes` remain persisted correctly;
- value editor changes are preserved after closing/reopening the transition
  timeline.

Checkpoint:

```text
checkpoint: keep manual transition authoring data only
```

## 9. Phase 3 - Manual Lane To Motion Channel Adapter

Goal: reuse the existing master keyframe/value truth path instead of creating a
parallel manual-lane evaluator.

Problem to solve:

```text
Manual transition lanes store normalized progress 0..1.
MasterKeyframeValueEvaluator expects MotionPropertyChannelModel over time.
```

Required changes:

- create a domain adapter that converts each manual transition lane into one or
  more `MotionPropertyChannelModel` instances;
- map transition progress to root timeline time through the real transition
  seam window;
- support outgoing/incoming target identity explicitly;
- preserve keyframe ids where possible;
- never use `DateTime.now()` as render/evaluation time;
- do not mutate the original transition during evaluation.

Initial lane mapping:

```text
scale         -> scaleX, scaleY renderer scalar
opacity       -> opacity renderer scalar
position      -> positionX, positionY or explicit axis mapping when available
rotation      -> rotation renderer radians
gaussianBlur  -> gaussianBlur renderer radius
tile          -> supported effect program id only when native supports it
motionBlur    -> blocker until temporal strategy exists
```

Value truth:

```text
scale 0%     -> 1.0
scale 100%   -> 2.0
scale -50%   -> 0.5
opacity 100% -> 1.0
opacity 0%   -> 0.0
rotation deg -> radians
position     -> renderer canvas units defined by existing value registry
blur         -> renderer radius/sigma defined by existing value registry
```

Forbidden:

- no UI changes;
- no native changes;
- no second keyframe evaluator unless the adapter proves impossible.

Targeted tests:

```bash
flutter test test/<new_manual_transition_lane_to_motion_channel_adapter_test>.dart
flutter analyze
```

Acceptance:

- manual Scale keyframes at progress 0 and 1 produce root-time channel keyframes;
- transition window mapping is exact at seam start/end;
- same input lanes produce stable output channels;
- unsupported lane ids produce explicit diagnostics.

Checkpoint:

```text
checkpoint: adapt manual transition lanes to motion channels
```

## 10. Phase 4 - Manual Transition Master Frame Evaluation

Goal: manual transition values must appear as `MasterEvaluatedPropertyValue`
without depending on legacy render plans.

Required changes:

- build a manual transition evaluation adapter that consumes:
  - master time snapshot;
  - transition seam window;
  - outgoing/incoming target ids;
  - channels produced by Phase 2;
- use existing `MasterKeyframeValueEvaluator` and `ValueTruthRegistry`;
- output evaluated values in renderer units;
- expose explicit blockers for unsupported FX;
- keep evaluation active only inside the real transition window.

Forbidden:

- no legacy `ProfessionalVideoTransitionRenderPlan`;
- no `manualTransform` native parameter path;
- no Stage5 native edits in this phase.

Targeted tests:

```bash
flutter test test/<new_manual_transition_master_frame_evaluation_test>.dart
flutter analyze
```

Acceptance:

- at a given root time inside the transition window, Scale/Opacity evaluate to
  renderer values;
- outside the transition window, no manual transition transform is emitted;
- evaluation is deterministic across preview, playback, and liveScrub render
  modes;
- unsupported FX returns a blocker, not a silent identity value.

Checkpoint:

```text
checkpoint: evaluate manual transition animate values
```

## 11. Phase 5 - LiveScrub Visual Program Projection For Manual Transitions

Goal: convert evaluated manual transition values into `LiveScrubVisualProgram`
surfaces without asking for a legacy render plan.

Required changes:

- add a manual-transition-specific runtime projection path that does not call
  `_professionalTransitionRenderPlanFor`;
- construct outgoing and incoming video-backed surfaces with explicit
  transition roles;
- attach evaluated transform, opacity, and supported effect bindings to the
  relevant surfaces;
- carry transition id, transition window, and transition progress;
- keep source windows mapped to the correct A/B media ranges.

Forbidden:

- no `ProfessionalVideoTransitionSurfaceOverlay`;
- no `TimelineTransitionPreviewOverlay` as a professional fallback;
- no Stage5 protected file edits.

Targeted tests:

```bash
flutter test test/<new_manual_transition_live_scrub_projection_test>.dart
flutter analyze
```

Acceptance:

- manual Scale produces a non-identity `LiveScrubSurfaceTransform`;
- manual Opacity produces surface opacity;
- transition progress is computed from the real seam window;
- output descriptors include blockers when native capabilities cannot render
  the requested transform/effect.

Checkpoint:

```text
checkpoint: project manual transition visual program
```

## 12. Phase 6 - Descriptor Contract Extension With Safe Defaults

Goal: descriptor and adapter layers must preserve transform/effect metadata
without regressing normal scrub clips.

Required changes:

- extend the Flutter descriptor contract or introduce a new runtime visual
  descriptor that carries:
  - transform matrix;
  - opacity;
  - effect program ids and renderer values;
  - transition role;
  - transition id;
  - transition progress;
  - transition window;
  - blockers;
- update `LiveScrubRuntimeSurfaceConfigAdapter` so these fields are not dropped;
- default every new field to identity/safe values for normal clips:
  - identity transform;
  - opacity `1.0`;
  - empty effects;
  - transition role `none`;
  - no transition id/progress;
- preserve existing scrub descriptor behavior when no manual transition is
  active.

Forbidden:

- no native drawing change yet;
- no hidden behavior change for ordinary video/image clips.

Targeted tests:

```bash
flutter test test/<new_live_scrub_runtime_surface_config_adapter_test>.dart
flutter analyze
```

Acceptance:

- baseline descriptors without transitions are byte/field equivalent in
  behavior through safe defaults;
- manual transition descriptors preserve transform/opacity/effect metadata;
- unsupported native capabilities become blockers.

Checkpoint:

```text
checkpoint: preserve manual transition visual descriptors
```

## 13. Phase 7 - Runtime Bridge Design Decision

Goal: choose a synchronization model before any hot-path Stage5 work.

Mandatory decision:

```text
Do not push Flutter MethodChannel updates per playback frame.
```

Adopt this model:

```text
Authoring/edit change
-> Flutter sends a compact transition visual bundle once per graph revision
-> Stage5 stores the bundle
-> Stage5 receives/owns frame time in its existing scrub/playback path
-> Stage5 evaluates the lightweight bundle locally for the displayed frame
```

Why:

- Push-per-frame is acceptable for diagnostics but too slow for playback.
- Native pull from Flutter per frame risks latency and deadlocks.
- Sideloaded keyframe/value data avoids MethodChannel traffic during playback
  and active scrub.

Required deliverables:

- define a data-only native bundle schema;
- include transition window, source windows, target roles, value mappings, and
  keyframes in renderer units;
- define a native lightweight evaluator contract;
- define Dart-vs-native parity tests for interpolation/value mapping;
- do not execute pixels in this phase unless separately approved.

Protected boundary:

- native bridge or Stage5 storage may touch protected paths. Stop for explicit
  approval before implementation.

Checkpoint:

```text
checkpoint: define manual transition runtime bridge contract
```

## 14. Phase 8a - Stage5 Scrub Bundle Intake

Requires explicit user approval for protected Live Scrub files.

Goal: Stage5 can receive and store manual transition visual bundles without
changing pixels.

Allowed changes after approval:

- native data models;
- native parsing;
- diagnostics;
- no drawing change;
- no decoder rebind behavior change.

Acceptance:

- native accepts a bundle and exposes diagnostics;
- invalid bundle is rejected with explicit reasons;
- active scrub behavior is unchanged when no bundle is active.

Verification:

```bash
./gradlew app:compileDebugKotlin
flutter analyze
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Checkpoint:

```text
checkpoint: accept manual transition visual bundle in stage5
```

## 15. Phase 8b - Stage5 Scrub Transform And Opacity

Requires explicit user approval for protected Live Scrub files.

Goal: active Live Scrub displays transform and opacity for manual transitions
on the Stage5 scrub output path.

Scope:

- transform;
- opacity;
- no gaussian blur/tile/motion blur yet;
- no dual-source blend beyond role-aware source selection unless explicitly
  included.

Implementation constraints:

- use Stage5-owned scrub output;
- do not use `ExoPlayer` during active scrub;
- do not use `MediaMetadataRetriever`;
- do not use `ProfessionalVideoTransitionCompositorManager`;
- do not introduce a Flutter overlay fallback.
- respect the current Stage5 scrub architecture:
  `Stage5NativeScrubEngine -> Stage5SurfaceScrubDecoder -> Surface` through the
  scrub overlay path;
- do not assume `Stage5SurfaceScrubDecoder` is a canvas blitter; inspect the
  current MediaCodec-to-Surface path before changing it.

Acceptance:

- Scale keyframes visibly change the video during active scrub;
- Opacity keyframes visibly change the video during active scrub when supported;
- normal clips outside transition windows scrub exactly as before;
- fast scrub, slow scrub, reverse scrub, and cross-source scrub do not regress.

Verification:

```bash
./gradlew app:compileDebugKotlin
flutter analyze
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Device checks:

- fast scrub across manual transition;
- slow frame-by-frame scrub across manual transition;
- reverse scrub across manual transition;
- scrub release/settle inside transition;
- scrub outside transition before and after it.

Checkpoint:

```text
checkpoint: apply manual transition transform in stage5 scrub
```

## 16. Phase 8c - Stage5 Scrub FX Programs

Requires explicit user approval for protected Live Scrub files.

Goal: supported FX become real native scrub programs.

Initial FX order:

1. gaussian blur;
2. tile/mirror;
3. motion blur only after temporal sampling is designed.

Rules:

- unsupported FX must show blockers;
- no CPU bitmap per scrub tick;
- no fake still-frame effect;
- no fallback thumbnail.

Acceptance:

- supported FX render in active scrub within latency budget;
- unsupported FX do not freeze or fake output;
- effect values match Dart value-truth tests.

Checkpoint:

```text
checkpoint: apply manual transition fx in stage5 scrub
```

## 17. Phase 9a - Playback Transform And Opacity

Requires explicit user approval if protected playback/surface files are touched.

Goal: normal Play displays the same manual transition transform and opacity as
Live Scrub.

Preferred implementation:

- use Media3 video effects / GL effect chain on the existing playback path;
- do not create a second player;
- do not create a second visible surface;
- keep audio and video synchronized.
- define "same output path" precisely for playback as the current
  `Stage5PreviewPlatformView` / Media3 `PlayerView` playback surface, not the
  active scrub overlay surface.

Acceptance:

- Scale keyframes are visible during playback;
- Opacity keyframes are visible during playback;
- audio remains synchronized with video;
- no audio-only frozen frame after editing keyframes.

Audio sync requirement:

```text
measured video/audio drift <= 40ms
```

Verification:

```bash
./gradlew app:compileDebugKotlin
flutter analyze
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Checkpoint:

```text
checkpoint: apply manual transition transform in playback
```

## 18. Phase 9b - Playback FX Programs

Goal: playback supports the same approved FX catalog as scrub.

Order:

1. gaussian blur;
2. tile/mirror;
3. motion blur after temporal strategy and audio/video timing proof.

Acceptance:

- preview/playback/liveScrub agree for supported FX;
- unsupported FX block with diagnostics;
- audio/video drift remains within budget.

Checkpoint:

```text
checkpoint: apply manual transition fx in playback
```

## 19. Phase 10 - Dual-Source Transition Composition

Goal: outgoing/incoming A/B roles are rendered through the master path rather
than the legacy compositor.

Required behavior:

- outside the transition window, normal single-source rendering remains active;
- inside the transition window, outgoing and incoming roles are explicit;
- transition progress is computed from the real seam window;
- Scale/Opacity/FX can target outgoing, incoming, or both according to the
  authored lane mapping;
- no boundary-frame freeze.

Acceptance:

- A/B transition scrub is visible and frame-moving;
- Play shows continuous video through the seam;
- no codec churn from per-frame extractor creation;
- no `ProfessionalVideoTransitionSurfaceOverlay`.

Checkpoint:

```text
checkpoint: render manual transition dual source path
```

## 20. Phase 11 - Legacy Guard And Deletion

Goal: prevent regressions back to the legacy manual transition path.

Required changes:

- tests proving manual transitions cannot mount
  `ProfessionalVideoTransitionSurfaceOverlay`;
- tests proving manual transitions cannot call `renderInteractiveFrame`;
- tests proving manual transition authoring does not require
  `ProfessionalVideoTransitionRenderPlan`;
- remove or isolate obsolete manual `manualTransform` code paths only after the
  master path renders successfully.

Forbidden:

- do not delete legacy code used by non-manual presets until its replacement is
  planned and tested.

Checkpoint:

```text
checkpoint: guard manual transition master renderer path
```

## 21. Phase 12 - Edge-Case Acceptance Matrix

The writer must validate all cases before declaring the plan complete:

- create manual transition with no lanes;
- add `Scale`, no keyframes;
- add `Scale` with keyframes at progress `0.0` and `1.0`;
- edit second Scale keyframe to `100%`;
- edit Scale to negative values;
- add `Opacity` with `100% -> 0%`;
- add `Rotation`;
- add Scale + Opacity + Rotation together;
- delete a lane and confirm default output returns;
- delete all manual lanes and confirm normal scrub/playback returns;
- scrub fast through transition;
- scrub slowly frame by frame;
- scrub backwards;
- release scrub inside transition and confirm settle frame matches;
- play from before transition through after transition;
- test two adjacent transitions on the same track;
- test cross-source A/B clips;
- test unsupported FX and confirm explicit blocker;
- inspect logcat for absence of legacy renderer calls.

Required log absence:

```text
renderInteractiveFrame
ProfessionalVideoTransitionSurfaceOverlay for manual
MediaMetadataRetriever.getFrameAtTime for manual interactive rendering
BufferQueueProducer timeout caused by transition keyframe edit
CCodec release/start churn caused by keyframe value edit
```

## 22. Surface Ownership Definition

The phrase "same video output path" has two concrete meanings in the current
app:

```text
Active Live Scrub:
Stage5TimelineScrubPlatformView
-> Stage5NativeScrubEngine
-> Stage5SurfaceScrubDecoder
-> Stage5ScrubOverlayTextureView

Playback / settle:
Stage5TransportManager
-> Media3/ExoPlayer
-> Stage5PreviewPlatformView / PlayerView
```

The plan does not require these two paths to become one physical surface before
manual Animate/FX can ship. It requires that both paths consume the same master
time/value truth and that neither path delegates manual transition rendering to
the legacy professional transition overlay.

Scrub parity and playback parity are separate implementation slices and must be
validated separately.

## 23. Verification Commands

Use the smallest relevant commands per slice. Common gates:

```bash
flutter analyze
flutter test <targeted tests>
./gradlew app:compileDebugKotlin
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb logcat -c
adb logcat -d -v time | rg -i "renderInteractiveFrame|MediaMetadataRetriever|ANR|BufferQueueProducer|CCodec|ProfessionalVideoTransitionSurfaceOverlay"
```

## 24. Documentation And Skills Updates

After each implementation slice:

- update this plan with status notes;
- update `docs/master_live_scrub_professional_plan.md` when runtime behavior
  changes;
- update `docs/professional_refusion_motion_keyframe_engine.md` when graph,
  keyframe, or value-truth rules change;
- update `docs/professional_normal_transitions_engine.md` when transition
  renderer ownership changes;
- update `/Users/mx/Documents/refusion-skills` when the rule affects future
  agents.

## 25. Definition Of Done

The plan is complete only when:

- Manual Transition Animate/FX no longer invokes the legacy compositor;
- manual keyframes are converted into master-evaluated renderer values;
- Live Scrub shows supported manual transition transforms on video;
- Play shows the same supported transform result;
- preview does not freeze during keyframe editing;
- audio continues synchronized with video;
- unsupported FX report blockers;
- all acceptance matrix cases pass on device;
- logs prove the old interactive manual renderer is not used;
- docs and skills are updated;
- every slice has a pushed checkpoint and rollback command.

## 26. Rollback Discipline

Every slice must be independently reversible:

```bash
git revert <slice-commit>
```

Do not merge multiple unrelated changes into one checkpoint. Do not hide Stage5
changes inside a Flutter UI checkpoint. Do not stage unrelated dirty docs or
untracked files.

## 27. Final Rule

Manual Transition Animate/FX must follow this path:

```text
manual lanes/keyframes
-> lane-to-channel adapter
-> master keyframe/value evaluator
-> LiveScrubVisualProgram
-> Stage5-owned scrub/playback renderer
-> same video output path
```

It must not follow this path:

```text
manualEffectIds
-> ProfessionalVideoTransitionRenderPlan
-> ProfessionalVideoTransitionSurfaceOverlay
-> renderInteractiveFrame
-> MediaMetadataRetriever
-> bitmap/surface overlay
```
