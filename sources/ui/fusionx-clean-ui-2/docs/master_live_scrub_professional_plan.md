# Master Live Scrub Professional Plan

Status: official implementation plan for Master Live Scrub Professional  
Package: `com.refusion.app`  
Date: 2026-05-03  
Depends on: `docs/master_clock_value_truth_foundation_plan.md`  
Binding safety mandate: `docs/live_scrub_migration_mandate.md`

## 0. Purpose

This plan defines the professional Master Live Scrub path for ReFusion.

This is not an isolated Live Scrub project. It is the next connected phase
after `Master Clock & Value Truth Foundation`.

The goal is not to create another preview engine, another scrub engine, or
another renderer-specific timing system. The goal is to make Live Scrub consume
the same time, value, graph, and frame-evaluation truth used by preview,
playback, transitions, keyframes, and export.

The professional target is:

```text
MasterTimeSnapshot
-> TimeDomainMapper
-> MasterFrameEvaluation
-> LiveScrubVisualProgram
-> Stage5 native scrub renderer
-> one native scrub output surface
```

No user-visible scrub frame may be explained by a private clock, private value
mapper, thumbnail fallback, still boundary frame, or transition-only compositor.

## 0.1 Continuity With Master Clock

Master Live Scrub Professional must be built on the foundation already created
by the Master Clock work. It must not duplicate that foundation.

Canonical upstream chain:

```text
TimelineClockCoordinator
-> MasterClockNativeBridge
-> MasterTimeSnapshot
-> TimeDomainMapper
-> ValueTruthRegistry
-> MasterKeyframeValueEvaluator
-> MasterFrameEvaluation
```

Master Live Scrub starts only after this chain exists:

```text
MasterFrameEvaluation
-> LiveScrubVisualProgram
-> LiveScrubSurfaceDescriptor
-> Stage5 native scrub renderer
```

This means:

- `TimelineClockCoordinator` remains the time authority;
- `MasterClockNativeBridge` remains the screen/native boundary for timeline
  clock handoff;
- `MasterFrameEvaluationReadAdapter` is the first approved read path for frame
  truth;
- `ValueTruthRegistry` owns UI/engine/renderer value meaning;
- Live Scrub may add adapters and descriptors, but it may not add a new clock,
  a new value registry, or a private keyframe evaluator.

If a Live Scrub implementation cannot consume `MasterFrameEvaluation`, the
implementation must stop and fix the missing adapter instead of creating a
parallel path.

## 1. Mandatory Reading

Before any implementation under this plan, read:

1. `/Users/mx/.codex/skills/refusion-development-guardrails/SKILL.md`
2. `docs/professional_checkpoint_policy.md`
3. `docs/live_scrub_migration_mandate.md`
4. `docs/master_clock_value_truth_foundation_plan.md`
5. `docs/professional_refusion_motion_keyframe_engine.md`
6. this file, `docs/master_live_scrub_professional_plan.md`

Then run:

```bash
git status -sb
git rev-parse --short HEAD
```

## 2. Existing Truth

The current active Live Scrub path is native-owned:

```text
Timeline touch
-> Stage5TimelineScrubPlatformView
-> Stage5NativeScrubEngine
-> Stage5SurfaceScrubDecoder
-> Stage5ScrubOverlayTextureView
```

The playback and final settle path remains:

```text
Stage5TransportManager -> ExoPlayer
```

This is important. The plan must improve the professional truth consumed by
Live Scrub without casually replacing the working Stage5 hot path.

## 3. Diagnosis

The Master Clock & Value Truth foundation now gives the app a single way to
explain time and values:

```text
MasterTimeSnapshot
-> TimeDomainMapper
-> KeyframeEvaluator
-> ValueTruthRegistry
-> MasterFrameEvaluation
```

Live Scrub still has open professional gaps:

- scrub descriptors do not yet carry full clip placement metadata;
- scrub output is not yet guaranteed to reflect every authored transform,
  opacity, effect, mask, transition, or scene-clip instance value;
- transition rendering previously used a separate pixel path, which can drift
  from the master clock and from the Stage5 scrub surface;
- source video frames, authoring graph values, scene scope projections, and
  transition windows are not yet one Live Scrub visual program;
- cross-source scrub can still be slower because native scrub may need to
  rebind media sources;
- final parity between preview, playback, Live Scrub, and export is not yet
  enforced by one acceptance matrix.

The root problem is not one missing effect. The root problem is that Live Scrub
must receive a complete evaluated visual program, not just a source media frame.

## 4. One Principle

Live Scrub is a consumer of the master frame graph, not a separate animation
engine.

Every scrubbed frame must answer these questions deterministically:

- what root timeline time is being scrubbed;
- what scene, layer, transition, and source-media domain times are projected;
- what clip or scene instance owns each visible surface;
- what graph keyframes evaluate at this time;
- what property values are in renderer units;
- what source media frame is needed;
- what transforms, opacity, effects, masks, and transition roles apply;
- what native output surface presents the final scrub frame.

If any answer comes from a second clock, a private progress value, or a still
thumbnail fallback, the implementation is not professional.

## 5. Non-Negotiable Rules

- Do not use `ExoPlayer` as the active scrub display renderer.
- Do not call `ExoPlayer.seekTo()` during active scrub.
- Do not call `ExoPlayer.setMediaItem()` during active scrub.
- Do not reintroduce transport-backed scrub as a shortcut.
- Do not create a Flutter thumbnail/poster fallback for professional scrub.
- Do not use boundary still frames as a substitute for live video scrub.
- Do not use `MediaMetadataRetriever` per scrub frame in the active scrub path.
- Do not create a second Live Scrub clock, second playhead, or mode-local time
  source.
- Do not fork Live Scrub per scope, transition, scene, or effect.
- Do not touch protected Stage5 files until the phase explicitly authorizes the
  exact change and the user has approved that Live Scrub slice.

Protected paths include:

- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`
- `Stage5PreviewPlatformView`
- Flutter Live Scrub handoff paths

## 6. Target Architecture

The target architecture is:

```text
Flutter editor gesture / native scrub gesture
-> MasterClockNativeBridge
-> TimelineClockCoordinator snapshot
-> MasterFrameEvaluationReadAdapter
-> MasterLiveScrubProgramAdapter
-> Stage5 scrub descriptor bridge
-> Stage5NativeScrubEngine
-> native decoder/proxy frame source
-> native visual compositor
-> Stage5ScrubOverlayTextureView
```

Key rule:

```text
Stage5 owns the hot scrub surface.
MasterFrameEvaluation owns the meaning of the frame.
The adapter between them must be explicit, tested, and reversible.
```

## 7. Core Contracts

### 7.1 MasterLiveScrubFrameRequest

Purpose: describes the exact frame the scrub engine is asked to show.

Required fields:

- `requestId`
- `rootTime`
- `presentationTime`
- `frameIndex`
- `commitFrameNumber`
- `renderMode = liveScrub`
- `timelineDuration`
- `viewportSize`
- `canvasSize`
- `activeScope`
- `sourceRevision`

### 7.2 LiveScrubVisualProgram

Purpose: describes everything visible at the scrubbed frame.

Required contents:

- ordered visual surfaces;
- source media identity for each video-backed surface;
- root clip timing;
- source media time;
- canvas placement;
- crop/fit/fill policy;
- evaluated transform;
- evaluated opacity;
- evaluated masks;
- evaluated effects;
- transition role (`none`, `outgoing`, `incoming`, `overlay`, `matte`);
- transition window/progress when applicable;
- scene-clip instance binding when applicable;
- blockers when a surface cannot be represented truthfully.

### 7.3 LiveScrubSurfaceDescriptor

Purpose: the native-safe descriptor sent toward Stage5.

Required contents:

- stable surface id;
- source uri or proxy id;
- source dimensions;
- source media time;
- playback rate mapping;
- visible canvas rect;
- crop rect;
- normalized transform matrix;
- opacity;
- z-order;
- effect program id list;
- transition role metadata;
- validity/blocker reasons.

The descriptor must be data-only. It must not contain shader source, executable
scripts, or UI-only values.

### 7.4 LiveScrubParityReport

Purpose: records whether Live Scrub can truthfully display the evaluated frame.

Required fields:

- `canScrubFrame`
- `usesMasterClock`
- `usesMasterFrameEvaluation`
- `usesNativeScrubSurface`
- `usesExoPlayerDuringActiveScrub`
- `usesStillFallback`
- `missingDescriptors`
- `unsupportedEffects`
- `transitionParityState`
- `latencyBudgetState`

## 8. Phase Plan

### Phase 0 - Inventory And Baseline

Goal: document the current Stage5 Live Scrub path, descriptor shape, native
handoff, and known parity gaps.

Allowed changes:

- docs only;
- tests that inspect existing APIs without changing behavior.

Deliverables:

- `docs/master_live_scrub_professional_inventory.md`
- list of Flutter scrub handoff methods;
- list of native Stage5 scrub classes and responsibilities;
- list of descriptor fields currently sent to native;
- list of missing descriptor fields for transform/effects/transitions/scenes;
- device baseline checklist for fast/slow/reverse/cross-source scrub.

Verification:

```bash
rg "Stage5TimelineScrubPlatformView|Stage5NativeScrubEngine|Stage5SurfaceScrubDecoder|Stage5ScrubOverlayTextureView|LiveScrubPreviewSourceDescriptor" lib android
flutter analyze
```

No Stage5 behavior may change in Phase 0.

### Phase 1 - Domain Contract And Program Adapter

Goal: build domain-only models and an adapter from `MasterFrameEvaluation` to a
`LiveScrubVisualProgram`.

Allowed changes:

- Dart domain models;
- Dart adapter/service;
- focused unit tests;
- docs and skills updates.

Forbidden:

- no Stage5 native edits;
- no Flutter scrub handoff rewiring;
- no preview surface changes;
- no renderer changes.

Verification:

```bash
flutter test test/master_live_scrub_visual_program_test.dart
flutter analyze
```

Acceptance:

- a video clip at a root time becomes one video-backed visual surface;
- evaluated opacity/scale/position/rotation are present in renderer units;
- transition-local time is explicit but does not claim pixels;
- unsupported effects produce blockers instead of silent fallback.

Implementation note (checkpoint `checkpoint: add master live scrub program adapter`):

- `MasterLiveScrubProgramAdapter` now lowers `MasterFrameEvaluation` into a
  domain-only `LiveScrubVisualProgram` contract.
- `LiveScrubVisualProgram` includes explicit transition window state, and
  transition pixel readiness remains false by contract in this phase.
- unsupported effect ids now produce explicit blockers (for example
  `unsupported_effect:<id>`) instead of silent fallback.
- this slice does not touch Stage5/native scrub files and does not alter
  runtime Live Scrub behavior.

### Phase 2 - Descriptor Projection Preflight

Goal: convert `LiveScrubVisualProgram` into native-safe
`LiveScrubSurfaceDescriptor` data without changing the active scrub renderer.

Allowed changes:

- Dart descriptor projection;
- MethodChannel payload planning only if gated and read-only;
- tests proving stable descriptor ids and exact source-time mapping.

Forbidden:

- no active Stage5 behavior change;
- no native drawing change;
- no hidden fallback.

Verification:

```bash
flutter test test/master_live_scrub_descriptor_projection_test.dart
flutter analyze
```

Implementation note (checkpoint `checkpoint: add live scrub descriptor projection preflight`):

- added a domain-only descriptor contract:
  `LiveScrubTimelineSourceWindow`, `LiveScrubSurfaceDescriptor`, and
  `LiveScrubDescriptorProjectionResult`.
- added `MasterLiveScrubDescriptorProjection` to project
  `LiveScrubVisualProgram` into deterministic descriptor payloads with stable
  descriptor ids and explicit blockers.
- source-time mapping is now explicit per descriptor through timeline-window to
  source-window projection (`sourcePositionMs`) and is verified by tests.
- this slice does not touch Stage5/native scrub behavior and does not change
  active renderer ownership.

### Phase 3 - Native Capability Handshake

Goal: let Flutter ask native Stage5 what Live Scrub capabilities are available
before sending advanced descriptors.

Allowed changes:

- explicit native capability method;
- read-only capability result;
- debug diagnostics;
- no visual behavior change.

Capability fields:

- `supportsSourceDimensions`
- `supportsCanvasPlacement`
- `supportsCrop`
- `supportsTransformMatrix`
- `supportsOpacity`
- `supportsEffectProgramIds`
- `supportsDualSourceTransitionWindow`
- `supportsLatencyMetrics`

Verification:

```bash
flutter test <targeted bridge tests>
./gradlew app:compileDebugKotlin
flutter analyze
```

This is the first phase that may touch protected Stage5-adjacent bridge code,
and it requires explicit user approval before implementation.

Implementation note (checkpoint `checkpoint: add live scrub capability handshake`):

- added a read-only native capability handshake method:
  `getLiveScrubCapabilities`.
- Android now reports explicit capability flags without changing scrub render
  ownership or runtime scrub behavior.
- Flutter transport now has `Stage5LiveScrubCapabilities` parsing with safe
  defaults.
- this slice does not alter active scrub drawing, decoder ownership, or
  playback/scrub handoff behavior.

### Phase 4 - Placement And Transform Parity

Goal: Stage5 Live Scrub displays source video with the same canvas placement,
fit/crop, translation, scale, rotation, and opacity as the master visual
program.

Required behavior:

- normal video clip scrub still works;
- scene clip instance placement is respected when represented as video-backed
  media;
- root composition background remains truthful;
- unsupported layers report blockers rather than fake pixels.

Verification:

```bash
./gradlew app:compileDebugKotlin
flutter analyze
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Device checks:

- fast forward scrub;
- slow frame-by-frame scrub;
- reverse scrub;
- zoomed timeline scrub;
- cross-source boundary scrub;
- pause after scrub and play from the exact settled frame.

Implementation note (checkpoint `checkpoint: add live scrub capability-gated descriptor parity`):

- added `LiveScrubDescriptorCapabilities` so descriptor projection can evaluate
  native Stage5 capability support before claiming placement/transform parity.
- descriptor projection now emits explicit blockers when native capability is
  missing for source dimensions, canvas placement, transform matrix, opacity,
  effect program ids, or dual-source transition windows.
- Stage5 capability handshake is now mappable into descriptor capabilities via
  `Stage5LiveScrubCapabilities.toDescriptorCapabilities()`.
- this slice is still preflight/domain-safe: it does not change active scrub
  drawing ownership or Stage5 hot-path behavior.

### Phase 5 - Effects Program Parity

Goal: Live Scrub applies supported graph effects through native scrub output
without leaving the Stage5 hot path.

Initial supported effects:

- opacity;
- transform;
- crop/fit/fill;
- gaussian blur only when native can render it within budget;
- tile/mirror only when native can render it within budget;
- motion blur only when there is a real temporal sampling strategy.

Forbidden:

- do not fake blur/tile/motion blur with still thumbnails;
- do not run slow CPU bitmap rendering on every scrub tick;
- do not call the old transition compositor as a parallel scrub renderer.

Acceptance:

- unsupported effects block professional parity explicitly;
- supported effects are visible during Live Scrub and remain editable as graph
  keyframes;
- fast scrub does not become slower outside effect windows.

Implementation note (checkpoint `checkpoint: add live scrub effect catalog preflight parity`):

- expanded native capability handshake payload with
  `supportedEffectProgramIds`.
- descriptor capability model now carries a strict effect catalog set.
- descriptor projection now blocks with
  `native_effect_program_catalog_missing` when effect capability is enabled
  without an explicit catalog.
- descriptor projection now blocks each non-whitelisted effect with
  `unsupported_effect_program:<id>`.
- this slice remains preflight/domain-safe and does not change active Stage5
  scrub drawing or decoder ownership.

### Phase 6 - Transition Window Parity

Goal: Live Scrub displays transition windows from the same graph-backed
transition data used by manual/preset authoring.

Rules:

- active only inside the real transition window;
- no wide focus-window suppression;
- no boundary-frame freeze;
- outgoing/incoming roles are explicit;
- transition progress comes from `TimeDomainMapper`;
- transition values come from `MasterFrameEvaluation`;
- Live Scrub, preview, and playback all report whether they consume the same
  transition graph.

Acceptance:

- outside the transition window, normal Live Scrub remains unchanged;
- inside the transition window, blockers are explicit until the native renderer
  can draw the transition truthfully;
- no audio-only/video-frozen state is accepted.

Implementation note (checkpoint `checkpoint: add live scrub transition window preflight parity`):

- added explicit transition-window contract:
  `LiveScrubTransitionTimelineWindow`.
- `LiveScrubSurfaceDescriptor` now carries `transitionId`,
  transition timeline bounds, and normalized transition progress.
- descriptor projection now enforces real-window gating for transition roles:
  - missing window binding -> `missing_transition_window:<targetId>`
  - playhead outside real window ->
    `transition_timeline_outside_window:<targetId>`
- this slice remains domain/preflight only and does not alter Stage5 hot scrub
  rendering behavior.

### Phase 7 - Performance And Latency Budget

Goal: prove the professional path is fast enough for real editing.

Metrics:

- per-scrub frame request rate;
- native decode/rebind latency;
- descriptor projection latency;
- frame presentation latency;
- dropped frame count;
- cross-source boundary warmup success;
- memory pressure during fast scrubbing.

Acceptance:

- fast scrub remains responsive;
- slow scrub is frame-accurate;
- reverse scrub works;
- cross-source scrub does not deadlock;
- no ANR;
- no black frames;
- no final-snap-only behavior.

Implementation note (checkpoint `checkpoint: add live scrub latency parity preflight report`):

- added `LiveScrubParityReport` to descriptor projection results with required
  parity fields (`canScrubFrame`, missing descriptors/effects, transition parity
  state, and latency budget state).
- added `LiveScrubPerformanceSnapshot` + latency thresholds and mapped
  `descriptorProjectionLatencyUs` from measured projection runtime.
- latency budget state is now explicit:
  `nativeMetricsUnavailable`, `nativeMetricsPending`, `withinBudget`,
  `overBudget`.
- this slice is still domain/preflight only and does not change Stage5 active
  scrub rendering behavior.

### Phase 8 - Guardrails And Deletion Gates

Goal: prevent future code from bypassing Master Live Scrub.

Required guards:

- no new active scrub `ExoPlayer.seekTo()` path;
- no new thumbnail/poster fallback in active scrub;
- no direct transition compositor path for Live Scrub;
- no new scrub clock outside `MasterClockNativeBridge`;
- no unsupported effect claiming scrub parity.

Deletion gates:

- delete obsolete fallback paths only after equivalent native professional path
  is verified on device;
- keep rollback simple through focused commits;
- never delete a working Stage5 safety path in the same commit that introduces
  a new renderer.

Implementation note (checkpoint `checkpoint: add master live scrub guardrails gate`):

- added executable guard script: `scripts/master_live_scrub_guard_check.sh`.
- added allowlist policy: `docs/master_live_scrub_guard_allowlist.txt`.
- the guard now blocks:
  - unapproved `seekTo` / `setMediaItem` paths in protected Stage5 scrub files;
  - thumbnail/poster/fallback tokens in protected Stage5 scrub files;
  - direct transition compositor coupling inside Master Live Scrub domain
    contracts;
  - scrub clock sources in Live Scrub domain files unless explicitly allowlisted.
- this slice is enforcement-only and does not alter Stage5 scrub rendering
  behavior.

Implementation note (checkpoint `checkpoint: add master live scrub preflight verify script`):

- added executable verification bundle:
  `scripts/master_live_scrub_preflight_verify.sh`.
- the bundle runs guardrails + targeted Master Live Scrub tests + `flutter analyze`
  in one command for repeatable checkpoint validation.
- this slice is tooling-only and does not alter Stage5 scrub rendering behavior.

Implementation note (checkpoint `checkpoint: add live scrub descriptor preflight bridge snapshot`):

- added read-only Stage5 transport bridge methods:
  - `submitLiveScrubDescriptorPreflight`
  - `getLiveScrubDescriptorPreflightSnapshot`
- native now accepts and stores the latest preflight descriptor/parity payload
  for diagnostics and bridge validation without changing active scrub rendering.
- descriptor/parity models now expose stable map serialization for bridge payloads
  and targeted tests verify payload shape.
- this slice does not change Stage5 hot-path scrub rendering behavior.

Implementation note (checkpoint `checkpoint: wire live scrub preflight bridge submission`):

- `FusionXCleanUiScreen` now schedules nonblocking descriptor preflight
  submissions during active professional transition overlay rendering.
- submissions are key-throttled and include:
  - bridge-time master frame snapshot context,
  - source timeline windows from transition render-plan sources,
  - real transition window/progress contract for outgoing/incoming roles,
  - native capability-gated descriptor projection payload.
- bridge submission remains read-only diagnostics (`submit...`/`snapshot...`)
  and does not transfer scrub render ownership away from Stage5.

Implementation note (checkpoint `checkpoint: wire live scrub runtime descriptor surface config`):

- added `LiveScrubRuntimeSurfaceConfigAdapter` to convert
  `LiveScrubDescriptorProjectionResult` into Stage5-native
  `LiveScrubPreviewSourceDescriptor` entries.
- `FusionXCleanUiScreen` now attempts runtime transition-scoped descriptor
  projection during active timeline scrubbing and merges projected descriptors
  over baseline scrub preview sources.
- this creates a real runtime handoff path from
  `MasterFrameEvaluation -> LiveScrubVisualProgram -> LiveScrubSurfaceDescriptor`
  into the existing Stage5 scrub `previewSources` config channel (no separate
  renderer ownership transfer).
- protected Stage5 native scrub classes are unchanged in this slice; this is a
  reversible Flutter-side runtime config linkage step.

Implementation note (checkpoint `checkpoint: wire live scrub native performance snapshot telemetry`):

- Android `Stage5NativeScrubEngine` now reports runtime scrub telemetry in
  `diagnosticsSnapshot()`, including estimated frame request rate, average
  decoder configure latency, average/max frame render latency, dropped-frame
  estimate, and cross-source warmup readiness.
- `MainActivity` now exposes `getLiveScrubPerformanceSnapshot` over the Stage5
  method channel as a read-only diagnostics endpoint.
- Flutter `Stage5NativeTransportController` now parses this payload into
  `LiveScrubPerformanceSnapshot`.
- transition preflight projection submission now injects native telemetry into
  `MasterLiveScrubDescriptorProjection.project(...)`, so
  `LiveScrubParityReport.latencyBudgetState` can evaluate against real native
  metrics instead of remaining pending by default.

## 9. Verification Matrix

Every implementation slice must name which rows it affects:

| Area | Required proof |
| --- | --- |
| Time | one `MasterTimeSnapshot` drives the scrubbed frame |
| Values | properties pass through `ValueTruthRegistry` |
| Source media | source time maps exactly to clip/source domain |
| Placement | native scrub surface matches preview canvas placement |
| Effects | supported effects are visible or explicitly blocked |
| Transitions | active only inside real transition window |
| Performance | fast/slow/reverse scrub remains responsive |
| Safety | no ExoPlayer active-scrub render path |
| Rollback | one checkpoint can be reverted cleanly |

## 10. Stop Conditions

Stop immediately if:

- Live Scrub becomes slower on ordinary video;
- scrub shows black frames;
- scrub shows a still thumbnail when live pixels are expected;
- audio continues while video freezes after scrub/play handoff;
- implementation needs protected Stage5 files without explicit approval;
- transition rendering tries to suppress the normal video surface outside the
  true transition window;
- a second clock or private progress source appears;
- an effect claims scrub parity without native visual proof.

## 11. First Implementation Slice

The first implementation slice after this documentation checkpoint must be:

```text
Phase 0 only:
- create `docs/master_live_scrub_professional_inventory.md`;
- inventory current Flutter and native Live Scrub handoff paths;
- document current descriptor fields and missing professional fields;
- document baseline device-test steps;
- do not edit Stage5 native files;
- do not change scrub behavior;
- update refusion-skills if agent-facing rules change;
- verify with rg and flutter analyze;
- checkpoint and push.
```

Do not start renderer, Stage5, transition, GPU, or effect implementation until
Phase 0 inventory is reviewed.

## 12. Writer Prompt

Use this prompt for the writer agent:

```text
You are the Writer agent for ReFusionXx.

Project:
/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2

Branch:
codex/unified-keyframe-ops-foundation-20260426

Mandatory reading:
1. /Users/mx/.codex/skills/refusion-development-guardrails/SKILL.md
2. docs/professional_checkpoint_policy.md
3. docs/live_scrub_migration_mandate.md
4. docs/master_clock_value_truth_foundation_plan.md
5. docs/professional_refusion_motion_keyframe_engine.md
6. docs/master_live_scrub_professional_plan.md

Start with:
git status -sb
git rev-parse --short HEAD

Task:
Implement Phase 0 of Master Live Scrub Professional only.

Deliver:
- docs/master_live_scrub_professional_inventory.md
- current Flutter scrub handoff inventory
- current native Stage5 scrub class inventory
- current descriptor field inventory
- missing professional descriptor field list
- device baseline checklist

Hard boundaries:
- Do not edit Stage5 native files.
- Do not edit Flutter Live Scrub handoff behavior.
- Do not implement renderer/GPU/effects/transitions.
- Do not change preview surface ownership.
- Ignore unrelated untracked ../../../.claude/.

Verification:
- rg checks named in Phase 0
- flutter analyze

Checkpoint:
Commit app repo with:
checkpoint: inventory master live scrub professional path

If refusion-skills changed, commit that repo separately with:
checkpoint: document master live scrub professional plan

Push both repos.
Install APK only if runnable app code changed and a device is connected.
```

## 13. Definition Of Done

Master Live Scrub Professional is complete when:

- Live Scrub receives a `MasterFrameEvaluation`-derived visual program;
- all video-backed surfaces include source time, placement, transform, opacity,
  crop, z-order, and supported effect metadata;
- root composition, scene clip, layer scope, and transition scope scrub through
  one master frame truth;
- active scrub does not use ExoPlayer as the display renderer;
- active scrub does not use still thumbnails as a professional fallback;
- supported effects and transitions are visible during scrub;
- unsupported effects and transitions report explicit blockers;
- preview, playback, Live Scrub, and export can explain the same frame through
  the same time/value graph;
- device validation passes fast, slow, reverse, cross-source, and transition
  window scrub checks;
- every checkpoint is independently revertible.

## 14. Final Rule

Do not call a Live Scrub result professional unless it is:

```text
master-clocked
graph-evaluated
native-rendered
surface-presented
device-validated
revertible
```
