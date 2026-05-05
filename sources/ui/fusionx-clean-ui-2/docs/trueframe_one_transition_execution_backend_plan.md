# TRUEFRAME ONE

Status: official implementation plan for the first correct professional transition execution step  
Audience: Codex 5.3 writer agent and future ReFusion engineering agents  
Project: `/Users/mx/Documents/ReFusionXx`  
Branch: `codex/unified-keyframe-ops-foundation-20260426`  
Current reference checkpoint at plan creation: `3ca7075`

## Purpose

`TRUEFRAME ONE` is the first correct step toward a professional ReFusion motion
and effects engine.

The goal is not to patch Motion Blur as an isolated filter. The goal is to stop
the current split execution model where:

```text
Stage5 native preview renderer owns some visual truth.
Professional transition compositor owns some visual truth.
Stage6 export renderer owns another visual truth.
```

This plan moves Manual Transition FX toward one execution truth:

```text
TransitionExecutionGraph
-> TransitionRuntimeEvaluator
-> NativeTransitionRenderBackend
-> Preview / Live Scrub / Playback / Export adapters
```

Preview and export do not need to share identical rendering code on day one.
They must, however, consume the same graph, evaluator, effect order, time
sampling model, interpolation rules, and parity diagnostics.

The core rule is:

```text
Not necessarily the same code.
Always the same truth.
```

## Current Problem

Manual Transition `Rotation` and `Scale` appear responsive because Stage5 applies
Android `View` transforms directly to the visible `playerView`.

Gaussian Blur appears because Stage5 can apply Android `RenderEffect` as a
single-frame spatial blur.

Motion Blur fails because it is temporal. It requires:

- ownership of the source frame or texture,
- root/local/source time mapping,
- sub-frame sample times,
- sampled transforms,
- source A/B contribution ownership,
- alpha-aware accumulation,
- one final visible surface.

The current architecture splits these responsibilities. As a result, enabling
Motion Blur can hide Stage5 before the professional surface has produced a valid
frame, causing frozen frames, black frames, or inconsistent live scrub/playback.

## Build Freedom And Safety

The writer agent should not be blocked by artificial implementation constraints.
The correct implementation may touch Flutter, Dart domain models, Stage5 native
preview handoff, the professional compositor, Stage6 export contracts, tests,
and diagnostics when the phase requires it.

This is not permission for careless work.

Mandatory safety remains:

- Keep changes scoped to the active phase.
- Do not mix unrelated refactors with transition backend work.
- Do not use destructive git commands.
- Do not revert unrelated user work.
- Do not leave silent fallbacks.
- Do not claim success from model data alone; success requires visible/proven
  frame behavior.
- Keep Stage5 protected-file changes explicit and justified by this plan.
- Every completed build step must be checkpointed, pushed, and reported.

## Mandatory Workflow For Codex 5.3

Before every implementation slice:

1. Run:

   ```bash
   git status -sb
   git rev-parse --short HEAD
   ```

2. Read the mandatory ReFusion policies:

   ```text
   sources/ui/fusionx-clean-ui-2/docs/professional_checkpoint_policy.md
   sources/ui/fusionx-clean-ui-2/docs/professional_refusion_motion_keyframe_engine.md
   sources/ui/fusionx-clean-ui-2/docs/trueframe_one_transition_execution_backend_plan.md
   ```

3. Identify whether the slice touches protected Stage5 / Live Scrub files.
   This plan approves Stage5 changes only when they directly serve:

   - surface handoff safety,
   - preview host/presenter behavior,
   - transition backend integration,
   - live scrub parity diagnostics.

4. Before editing a protected file, state the exact reason in the work log.

After every completed implementation slice:

1. Run the smallest relevant verification.
2. For native/renderer changes, run at minimum:

   ```bash
   flutter test <targeted tests>
   flutter build apk --debug
   ```

3. Install the latest build on the connected wireless Android device when
   available:

   ```bash
   adb devices -l
   adb mdns services
   adb connect <ip:port>
   flutter install --debug -d <ip:port>
   ```

   If `flutter install` hangs, use the explicit APK route:

   ```bash
   adb -s <ip:port> push build/app/outputs/flutter-apk/app-debug.apk /data/local/tmp/refusion-debug.apk
   adb -s <ip:port> shell pm install -r -t --user 0 /data/local/tmp/refusion-debug.apk
   ```

4. Stage only the related files.
5. Commit with:

   ```text
   checkpoint: <short phase result>
   ```

6. Push the branch.
7. Report:

   - branch,
   - commit hash,
   - files changed,
   - tests/builds,
   - device install result,
   - rollback command.

8. Update the relevant plan/status documentation or local agent skill notes when
   a new invariant is introduced. Do not leave future agents guessing.

## Non-Negotiable Engineering Rules

1. Motion Blur must not be implemented as Gaussian Blur.
2. Motion Blur must not be a `View` transform trick.
3. Motion Blur must not be a Flutter or Android overlay that competes with the
   real video surface.
4. Motion Blur must not depend on `MediaMetadataRetriever.getFrameAtTime` in
   live scrub or playback.
5. Stage5 must not be hidden just because Motion Blur is enabled.
6. Stage5 may be hidden only after the professional surface proves
   `firstFrameReady=true`.
7. Preview/live scrub/playback/export may use different quality settings, but
   they must consume the same transition truth.
8. No backend may silently reinterpret effect order or keyframe values.
9. No backend may silently fall back without diagnostics.
10. Every visible frame must be attributable to one owner.

## Phase 0 - Baseline Freeze And Feature Gates

Goal: freeze the currently working Stage5 baseline and prevent future regressions
while the professional backend is introduced.

Tasks:

- Confirm current working behavior for:
  - Track A + Track B,
  - Manual Transition,
  - Rotation,
  - Scale,
  - Gaussian Blur,
  - live scrub,
  - playback.
- Add or verify feature gates:
  - `trueframeOneBackendEnabled`,
  - `manualTransitionProfessionalBackendEnabled`,
  - `manualTransitionMotionBlurBackendEnabled`,
  - `surfaceHandoffSafetyEnabled`.
- Ensure the default state never breaks the current working Stage5 path.
- Add a rollback note for disabling the professional backend quickly.

Verification:

- Targeted guard tests.
- No visual behavior change when flags are off.
- Device install if app code changes.

Checkpoint:

```text
checkpoint: add trueframe one backend gates
```

## Phase 1 - Surface Handoff Safety

Goal: eliminate black frames and frozen frames immediately.

Implement a surface handoff state machine:

```text
STAGE5_ACTIVE
PREPARE_PROFESSIONAL_SURFACE
WAIT_FIRST_FRAME
PROFESSIONAL_ACTIVE
FALLBACK_TO_STAGE5
```

Rules:

- Stage5 remains visible in `STAGE5_ACTIVE`, `PREPARE_PROFESSIONAL_SURFACE`, and
  `WAIT_FIRST_FRAME`.
- Professional surface may become the visible owner only after:

  ```text
  firstFrameReady == true
  canRenderFrame == true
  framePresented == true
  surfaceAttached == true
  ```

- If first frame does not arrive within the timeout, return to
  `FALLBACK_TO_STAGE5`.
- If the professional backend reports:

  ```text
  canRenderFrame=false
  pixelRendererImplemented=false
  sourceFrameUnavailable
  surfaceAttached=false
  framePresented=false
  ```

  Stage5 remains visible and the reason is logged.

Required diagnostics:

```text
handoffState
stage5Visible
professionalSurfaceVisible
firstFrameReady
firstFrameTimeoutMs
fallbackReason
surfaceId
mode
timelineTimeMs
```

Acceptance:

- Enabling Motion Blur never blacks the screen.
- Enabling Motion Blur never freezes the previously visible frame.
- If the professional backend is not ready, Stage5 remains visible.
- The user can still live scrub and press play.

Checkpoint:

```text
checkpoint: add trueframe surface handoff safety
```

## Phase 2 - TransitionExecutionGraph

Goal: create one typed truth for Manual Transition FX.

Introduce a canonical graph model, suggested name:

```text
TransitionExecutionGraph
```

Required fields:

```text
graphId
graphRevision
transitionId
timelineWindow
outputSize
outputFps
sourceA
sourceB
sourceAWindow
sourceBWindow
transitionProgressChannel
transformChannels
  position
  scale
  rotation
  anchor
visualChannels
  opacity
  gaussianBlur
  motionBlur
effectStack
zOrder
blendMode
surfacePolicy
backendCapabilityRequirements
diagnosticTags
```

Rules:

- The screen must not hand-build separate effect truth for Motion Blur.
- The compositor must not reinterpret raw UI values.
- Stage6 export must not reconstruct transition meaning from unrelated maps.
- The graph must preserve root time, local transition time, source time, and
  source role.

Verification:

- Unit tests prove manual transition Rotation/Scale/Gaussian/Motion Blur lower
  into the graph.
- Tests prove the graph includes both outgoing and incoming source identity.
- Tests prove keyframe values are not read from legacy side paths.

Checkpoint:

```text
checkpoint: add transition execution graph
```

## Phase 3 - TransitionRuntimeEvaluator

Goal: evaluate the same transition state for every backend.

Introduce:

```text
TransitionRuntimeEvaluator
evaluateTransitionAt(time)
```

It returns:

```text
TransitionFrameState
  rootTimeMs
  transitionLocalTimeMs
  progress
  sourceATimeMs
  sourceBTimeMs
  sourceAVisible
  sourceBVisible
  transformMatrix3x3
  position
  scale
  rotation
  anchor
  opacity
  gaussianBlurSigmaPx
  motionBlurSamplingPlan
  bounds
  effectStackOrder
  diagnostics
```

Motion Blur must be evaluated here, not separately by renderers.

The evaluator must produce:

```text
MotionBlurSamplingPlan
  shutterOpenTimeMs
  shutterCloseTimeMs
  sampleTimesMs[]
  sampleWeights[]
  sampleTransforms[]
  sampleSourceContributions[]
  amount
  shutterAngleDegrees
  shutterPhaseDegrees
  sampleCount
  qualityMode
```

Rules:

- Preview and export may request different sample counts.
- Sample times and effect meaning must come from the evaluator.
- A/B boundary samples must include outgoing and incoming contributions according
  to actual sample time.
- No sample is dropped merely because the current playhead is on the other clip.

Verification:

- Position-only, Rotation-only, Scale-only, and combined transforms generate
  non-identical sample transforms when velocity exists.
- No movement produces no Motion Blur.
- A shutter window crossing the A/B boundary includes both source roles.
- Shutter Angle changes sample offsets.
- Shutter Phase shifts the sample window.

Checkpoint:

```text
checkpoint: add transition runtime evaluator
```

## Phase 4 - NativeTransitionRenderBackend Contract

Goal: define the backend that owns professional transition pixels.

Suggested interface:

```text
NativeTransitionRenderBackend
  renderPreviewFrame(graph, frameState, outputSurface)
  renderLiveScrubFrame(graph, frameState, outputSurface)
  renderPlaybackFrame(graph, frameState, outputSurface)
  renderExportFrame(graph, frameState, exportTarget)
```

Backend responsibilities:

- source texture acquisition,
- transform rendering,
- temporal sample accumulation,
- Gaussian Blur execution,
- opacity and blend,
- final surface presentation,
- frame proof diagnostics.

Source frame provider rules:

- Live scrub/playback must not use `MediaMetadataRetriever.getFrameAtTime`.
- Use decoded texture, persistent decoder, cached frame provider, or GPU texture
  path suitable for real-time rendering.
- `MediaMetadataRetriever` may remain only for thumbnail/debug/offline fallback,
  with explicit diagnostics.

Required diagnostics:

```text
backendId
backendVersion
sourceFrameProvider
executionOwner
surfaceOwner
graphRevision
frameStateRevision
effectStackOrder
canRender
fallbackUsed
fallbackReason
```

Checkpoint:

```text
checkpoint: add native transition render backend contract
```

## Phase 5 - Motion Blur Render Pass

Goal: implement real temporal transform sampling.

Required render model:

```text
For each output frame at time T:
  evaluator builds shutter interval.
  evaluator builds N sample times.
  for each sample:
    evaluate source contribution and transform.
    render source texture at sampled transform.
  alpha-aware accumulate weighted samples.
  output one final frame.
```

Expected behavior:

- Position motion creates linear streaks.
- Rotation creates arc/circular blur around the anchor.
- Scale creates zoom/radial blur from or toward the anchor.
- Combined transform creates combined temporal blur.
- Slow motion creates subtle blur.
- No motion creates no blur.

Effect order:

```text
source decode
-> source color transform
-> transform evaluation
-> temporal motion blur
-> gaussian/static blur
-> opacity
-> blend/composite
-> output
```

Rules:

- Do not use Gaussian Blur as Motion Blur.
- Do not draw a separate ghost overlay above the real video.
- Do not darken the frame through incorrect alpha accumulation.
- Do not render only Track B when the shutter window includes Track A.
- Do not claim success without pixel/checksum delta when amount and velocity are
  non-zero.

Checkpoint:

```text
checkpoint: render manual transition motion blur in trueframe backend
```

## Phase 6 - Gaussian Blur And Effect Stack Parity

Goal: bring Gaussian Blur under the same execution truth.

Stage5 `RenderEffect` may remain as a temporary fast-path only while clearly
diagnosed. The professional backend must own the canonical Gaussian Blur
semantics for Manual Transition.

Tasks:

- Lower Gaussian Blur into `TransitionExecutionGraph`.
- Evaluate Gaussian Blur in `TransitionRuntimeEvaluator`.
- Execute Gaussian Blur in the backend after temporal motion blur and before
  opacity/composite.
- Prove preview and playback use the same effect order.
- Prepare export adapter to consume the same graph/evaluator state.

Checkpoint:

```text
checkpoint: unify manual transition gaussian blur effect order
```

## Phase 7 - Stage5 Becomes Host, Not Effect Truth

Goal: stop Stage5 from being the final semantic owner of Manual Transition FX.

Stage5 may remain responsible for:

- playback transport,
- live scrub host,
- surface presentation,
- fallback preview,
- diagnostics,
- backend handoff.

Stage5 must not remain the canonical owner of:

- Rotation semantics,
- Scale semantics,
- Gaussian Blur semantics,
- Motion Blur semantics,
- effect order.

Migration rule:

- Do not remove the working Stage5 fallback until the professional backend is
  proven on device.
- Once proven, guarded tests should prevent Stage5-only semantic paths from
  competing with the backend for Manual Transition FX.

Checkpoint:

```text
checkpoint: make stage5 a trueframe transition host
```

## Phase 8 - Export Adapter

Goal: make Stage6 export consume the same graph and evaluator.

Stage6 must not reinterpret transition effects from raw authoring values.

Required path:

```text
Stage6ExportManager
-> TransitionExecutionGraph
-> TransitionRuntimeEvaluator
-> NativeTransitionRenderBackend export adapter
-> Media3/BMF/encoder path
```

Quality model:

```text
Preview:
  samples = 4-8
  resolution = preview surface
  real-time priority

Export:
  samples = 16-32
  resolution = final output
  quality priority
  no silent fallback
```

Checkpoint:

```text
checkpoint: route transition export through trueframe graph
```

## Phase 9 - Tests, Proof, And Performance Gates

Required tests:

- Surface handoff:
  - Stage5 remains visible until `firstFrameReady=true`.
  - timeout falls back to Stage5.
  - no black frame when backend cannot render.
- Graph/evaluator:
  - Rotation + Motion Blur.
  - Scale + Motion Blur.
  - Position + Motion Blur.
  - combined transform + Motion Blur.
  - A/B boundary crossing.
  - no movement means no blur.
- Renderer:
  - Amount `0` produces no pixel delta.
  - Amount `>0` plus transform velocity produces pixel/checksum delta.
  - no Gaussian fallback for Motion Blur.
  - no ghost overlay.
  - no Track B-only bias.
- Preview/playback parity:
  - live scrub and playback use the same graph/evaluator.
  - scrub then play does not jump or black out.
- Export parity:
  - export uses the same graph/evaluator.
  - preview/export differ by quality, not effect meaning.
- Performance:
  - no `MediaMetadataRetriever.getFrameAtTime` loop in live/playback.
  - no decoder churn during live scrub.
  - latest-wins render queue prevents stale frames.

Required frame diagnostics:

```text
executionOwner
surfaceOwner
backendId
graphRevision
frameStateRevision
timelineTimeMs
sampleCount
sampleTimesMs
sourceFrameProvider
effectStackOrder
firstFrameReady
fallbackUsed
fallbackReason
checksumBefore
checksumAfter
checksumDelta
droppedFrameCount
actualFps
```

Checkpoint:

```text
checkpoint: add trueframe transition parity and performance gates
```

## Phase 10 - Cleanup And Guardrails

Goal: remove obsolete competing paths after the backend is proven.

Cleanup candidates:

- Stage5-only Manual Transition effect semantics.
- ad-hoc Motion Blur plans built in the editor screen.
- silent professional-surface failure paths.
- any `MediaMetadataRetriever` live/playback frame extraction.
- compositor paths that claim capability without frame proof.
- export paths that reinterpret Manual Transition FX independently.

Every removal must have:

- replacement already active,
- tests proving replacement behavior,
- rollback checkpoint,
- device validation.

Checkpoint:

```text
checkpoint: remove legacy manual transition effect ownership
```

## Device Validation Script

After each native or rendering checkpoint:

1. Discover device:

   ```bash
   adb devices -l
   adb mdns services
   adb connect <ip:port>
   ```

2. Build:

   ```bash
   cd /Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2
   flutter build apk --debug
   ```

3. Install:

   ```bash
   flutter install --debug -d <ip:port>
   ```

4. If install hangs:

   ```bash
   adb -s <ip:port> push build/app/outputs/flutter-apk/app-debug.apk /data/local/tmp/refusion-debug.apk
   adb -s <ip:port> shell pm install -r -t --user 0 /data/local/tmp/refusion-debug.apk
   ```

5. Validate manually:

   ```text
   New Composition
   -> Scene 01
   -> Track A + Track B
   -> Transition Timeline
   -> Add Rotation keyframes
   -> Add Motion Blur
   -> Change Amount
   -> Live Scrub
   -> Play
   -> Stop
   -> Scrub backward/forward
   ```

6. Capture proof if a failure occurs:

   ```bash
   adb -s <ip:port> shell pidof com.refusion.app
   adb -s <ip:port> logcat --pid <pid> -d -t 1500
   adb -s <ip:port> exec-out screencap -p > /tmp/trueframe_failure.png
   ```

## Acceptance Criteria

`TRUEFRAME ONE` is not complete until:

- Stage5 never disappears before a professional frame is ready.
- Motion Blur never causes black screen or frozen screen.
- Rotation and Scale still work.
- Gaussian Blur still works.
- Motion Blur visibly affects live scrub and playback.
- Position/Rotation/Scale Motion Blur follow correct temporal direction.
- Track A and Track B both contribute when the shutter window crosses the
  boundary.
- No `MediaMetadataRetriever.getFrameAtTime` live/playback loop remains.
- Preview and export consume the same graph/evaluator/effect order.
- Every fallback is explicit and diagnostic.
- Every completed step has a checkpoint commit pushed to GitHub.
- Every native/rendering step is installed on the connected wireless device when
  available.

## Agent Writer Summary

Build freely, but build with proof.

Do not patch Motion Blur as a one-off.

First prevent black/frozen frames through surface handoff safety.
Then create the single execution truth.
Then make the runtime evaluator produce the same state for every backend.
Then render Motion Blur as temporal transform sampling in a real native backend.
Then route preview/playback/export through adapters over that same truth.
Then remove old competing ownership paths only after proof exists.

This is the first correct step.

