# Seam Continuity Engine Plan

Status: official proposed implementation plan  
Project: `ReFusionXx`  
Primary objective: make every A/B boundary behave like one continuous professional visual event for all transforms, effects, preview modes, Live Scrub, playback, and export  
Audience: Codex 5.3 writer agent and future ReFusion agents

---

## 0. Executive Decision

ReFusionXx must stop treating A/B boundaries as a hard source switch.

The professional target is:

```text
Track A + Track B + transition window = one continuous evaluated visual event
```

This is not a Motion Blur-only fix. It is a global continuity layer that every
effect and transform must consume.

Official engine name:

```text
Seam Continuity Engine (SCE)
```

The SCE owns:

- source activation continuity,
- canonical transition time,
- effect state history across the boundary,
- render ownership continuity,
- realtime frame-budget policy,
- export semantic parity.

The first implementation slice may focus on Manual Transition because that is
where the current regression is visible, but the architecture must be global.

---

## 1. Why This Exists

Current behavior can render an effect correctly while the playhead is inside
clip A or clip B. The failure appears at the exact A/B boundary because runtime
state is reconstructed as:

```text
before seam: A active
at/after seam: B active
```

That causes discontinuities:

- effect stack can disappear for one frame,
- velocity/history-based effects can reset,
- source decode or descriptor ownership can switch,
- transforms can briefly fall back to identity,
- Live Scrub or playback can skip the critical boundary update,
- the viewer sees a gap, flicker, stutter, or effect collapse.

The correct mental model is not:

```text
clip A ends, then clip B starts
```

The correct model is:

```text
within the transition window, A and B are both participating sources of one
continuous composition state
```

---

## 2. External Reference Model

The SCE direction is aligned with professional compositing and editing models:

- OpenFX transition/image-effect contexts model multiple input clips plus one
  output under a host-owned render contract.
- OpenFX temporal effects can declare frame dependencies and sequential render
  requirements instead of guessing history locally.
- FFmpeg `xfade` style transitions require compatible A/B cadence and format
  before a transition can be evaluated predictably.
- Android performance guidance treats missed frame deadlines and frozen frames
  as first-class failures, not cosmetic diagnostics.
- GPU APIs such as Vulkan/D3D12 treat ownership and resource state transitions
  explicitly; ReFusion must mirror that idea at the renderer-contract level.

Reference URLs for future agents:

- `https://openfx.readthedocs.io/en/main/Reference/ofxImageEffectContexts.html`
- `https://openfx.readthedocs.io/en/latest/Reference/ofxRendering.html`
- `https://openfx.readthedocs.io/en/latest/Reference/ofxImageEffectActions.html`
- `https://ffmpeg.org/ffmpeg-filters.html`
- `https://developer.android.com/topic/performance/vitals/render#frozen-frames`
- `https://developer.android.com/media/media3/exoplayer/troubleshooting`
- `https://docs.vulkan.org/spec/latest/chapters/devsandqueues.html`

These references do not dictate ReFusion implementation details directly. They
support the architectural rule that a host must own source sets, temporal
dependencies, render ownership, and frame-budget policy explicitly.

---

## 3. Current Hotspots That Must Be Fixed

The following areas are known seam-continuity risks. Future implementation must
address them systematically, not one effect at a time.

### 3.1 Active source filtering

File:

```text
lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart
```

Functions:

- `_manualTransitionLiveScrubProgram`
- `_activeManualTransitionSourceIdsForTime`
- `_resolveStage5VisualRuntimePrimaryTargetClipId`

Risk:

The runtime program currently filters to source IDs active at the current root
time. At an A/B boundary this can become single-source selection instead of
continuous A+B participation.

Required fix:

Inside an SCE transition window, the active source set is the seam participant
set, not the clip-local current source.

### 3.2 Half-open boundary mismatch

Files:

```text
fusionx_clean_ui_screen.dart
master_live_scrub_descriptor_projection.dart
timeline_time.dart
Stage5NativeScrubEngine.kt
```

Risk:

Different boundary comparisons such as `< end`, `<= end`, or `> end` can create
one-frame disagreements between Dart projection and Kotlin descriptor
resolution.

Required fix:

Adopt one official boundary policy everywhere:

```text
[startMs, endExclusiveMs)
```

The seam instant belongs to the transition window and must not drop either
participant from the seam active set.

### 3.3 Previous-state lookup collapse

File:

```text
fusionx_clean_ui_screen.dart
```

Function:

```text
_stage5MotionBlurDirectiveForSurface
```

Risk:

When previous state for a target is missing, code may substitute current state
as previous state. That makes velocity zero for a frame and can disable
temporal effects. Equivalent defaulting can hurt any history-based effect.

Required fix:

History inside a seam window must come from `SeamStateHistoryCache`. If history
is missing, the fallback must be explicit and stable. No effect may silently
invent identity/current-as-previous state inside the seam path.

### 3.4 Runtime submission coalescing

File:

```text
fusionx_clean_ui_screen.dart
```

Functions:

- `_scheduleStage5VisualRuntimeSubmission`
- `_stage5VisualRuntimeSubmissionKey`
- `_scheduleLiveScrubRuntimeBridgeSubmission`
- `_liveScrubRuntimeBridgeSubmissionKey`

Risk:

Bucketed keys and in-flight suppression can drop the exact boundary frame or
submit stale state after the playhead crosses the seam.

Required fix:

Seam-critical updates must use deterministic latest-frame application:

```text
if request is stale -> ignore it
if newer request exists -> apply newest
do not skip seam-critical state because an older request is in flight
```

### 3.5 Descriptor and visual-state fallback

Files:

```text
Stage5NativeScrubEngine.kt
Stage5SurfaceScrubDecoder.kt
```

Risk:

If descriptor or surface state resolution misses at the seam, fallback can
become identity transform, opacity 1, no effects, or a decoder reconfiguration
pause.

Required fix:

No seam frame may fall back silently to identity/no-effects. Use either:

- last valid seam state for the same continuity key, or
- explicit fallback with diagnostics and stable visual owner.

### 3.6 Decoder churn

Files:

```text
Stage5NativeScrubEngine.kt
Stage5SurfaceScrubDecoder.kt
Stage5TransportManager.kt
```

Risk:

Switching clip descriptors at the boundary can force decoder target update,
seek, flush, or reconfigure. That can cause visible lag even if effect math is
correct.

Required fix:

SCE must support decoder continuity:

- prewarm both participants before the seam,
- keep A/B source descriptors resident through the seam window,
- avoid decoder reconfigure/flush for a normal boundary,
- treat decoder rebind as a blocker unless explicitly unavoidable.

---

## 4. Non-Negotiable Architecture Rule

Inside any transition window:

```text
SCE is the source of continuity truth.
```

No effect, renderer, adapter, or UI path may independently decide:

- which A/B source is active,
- what the previous state is,
- whether the seam has crossed,
- whether ownership can switch,
- whether a frame may drop continuity.

Required chain:

```text
TimelineTime
-> SeamWindowResolver
-> SeamActiveSetResolver
-> SeamTimeMapper
-> SeamStateHistoryCache
-> SeamEffectEvaluationContext
-> Renderer adapter
-> final output
```

---

## 5. Core Contracts

### 5.1 Seam Window Contract

Required fields:

```text
windowId
transitionId
leftClipId
rightClipId
rootStartMs
rootSeamMs
rootEndExclusiveMs
localStartMs
localSeamMs
localEndExclusiveMs
mode
frameRate
```

Rules:

- `rootStartMs < rootEndExclusiveMs`
- `rootSeamMs` must be inside the window
- every consumer uses `[start, endExclusive)`
- window identity must be stable while editing keyframes or scrubbing

### 5.2 Seam Participant Contract

Required participant roles:

```text
SourceFrom / outgoing / A
SourceTo / incoming / B
Output
```

Required fields per participant:

```text
participantId
clipId
assetId
role
sourceUri
rootTimelineRange
sourceTimeRange
playbackRate
mediaKind
decodeReadiness
```

Rules:

- A and B both remain participants over the full seam window.
- A/B may have different opacity or contribution weights, but not disappear
  from the continuity contract unless a blocker is emitted.
- Missing source URI, invalid source range, unsupported media, or decoder
  failure must produce explicit blockers.

### 5.3 Seam Active Set Contract

Inside the seam window:

```text
activeSourceIds = {leftClipId, rightClipId}
```

The renderer may choose one primary visible source for simple non-blend modes,
but the continuity context still carries both participants.

This distinction is mandatory:

```text
continuity active set != currently dominant visible source
```

### 5.4 Seam Time Contract

Required time tuple:

```text
rootTimeMs
seamLocalTimeMs
normalizedProgress
sourceFromTimeMs
sourceToTimeMs
shutterOpenMs
shutterCloseMs
frameIndex
```

Rules:

- `normalizedProgress` is continuous and monotonic across the seam window.
- effect evaluators read canonical seam time, not ad-hoc clip local branches.
- temporal effects must read shutter/frame dependency times from this contract.

### 5.5 Seam State History Contract

Required cache:

```text
SeamStateHistoryCache
```

Cache key:

```text
(windowId, participantId, targetId, effectStackId, mode)
```

Cache value:

```text
previousTransform
previousOpacity
previousEffectValues
previousContributionWeight
previousSourceTimeMs
previousFrameIndex
continuityRevision
```

Rules:

- Effects inside seam windows may not compute previous state by searching only
  the current active clip.
- Missing history is never silent.
- History fallback must be explicit:

```text
historyFallbackReason = first_frame_in_window
historyFallbackReason = source_not_ready
historyFallbackReason = decoder_state_missing
historyFallbackReason = effect_stack_changed
```

### 5.6 Effect Dependency Contract

Each effect must declare what it needs:

```text
requiresPreviousFrame
requiresNextFrame
requiresSourceFrom
requiresSourceTo
requiresStableOwner
requiresDecoderPrewarm
maxRealtimeCostTier
```

Examples:

- Motion Blur: requires previous transform/effect state.
- Gaussian Blur: does not require history, but requires stable source surface.
- Opacity/Color: requires effect stack continuity and active participant
  continuity.
- Future temporal trails: require bounded history frames.

### 5.7 Render Ownership Contract

Exactly one final owner per frame:

```text
Stage5RealtimeSurface
or
ProfessionalCompositorSurface
or
ExportRenderer
```

Forbidden:

```text
Stage5 visible + Professional surface visible as final output
```

Required diagnostic:

```text
overlayConflict = false
```

### 5.8 Decode Continuity Contract

Inside seam windows:

- A and B descriptors are prewarmed.
- A and B source windows are known before the seam.
- decoder target changes must not block the critical seam frame.
- decoder readiness is part of seam proof.

Required readiness flags:

```text
sourceFromReady
sourceToReady
sourceFromDecoderWarm
sourceToDecoderWarm
decoderReconfiguredAtSeam
decoderDroppedSeamFrame
```

---

## 6. Global Invariants

These are blocking invariants. A build cannot be accepted if any fail.

1. Active-set invariant  
   A and B are both present in the seam active set for every frame in the
   transition window.

2. Boundary invariant  
   All Dart/Kotlin/domain/presentation code uses `[start, endExclusive)`.

3. History invariant  
   Seam-active effects resolve previous state from SCE history or emit an
   explicit stable fallback.

4. No default-reset invariant  
   No seam frame may silently become identity transform, no effects, opacity 1,
   or current-as-previous.

5. Single-owner invariant  
   No overlay conflict, no owner flip-flop, no duplicate visible final surface.

6. Submission invariant  
   Critical seam updates cannot be dropped by in-flight guards or coarse
   buckets. Latest requested seam frame wins deterministically.

7. Decode invariant  
   Normal A/B boundary playback must not require decoder churn on the critical
   seam frame.

8. Effect-order invariant  
   Effect order is the same before, during, and after the seam.

9. Parity invariant  
   Preview, Live Scrub, playback, and export may differ in quality only. They
   must not differ in semantic source/effect/time evaluation.

10. Budget invariant  
   Realtime must reduce quality, not drop continuity.

---

## 7. Effect Order Around Seam

Required order:

```text
source readiness / source surface
-> canonical seam time mapping
-> participant contribution weights
-> transform evaluation
-> temporal effects
-> spatial effects
-> color effects
-> opacity
-> blend/composite
-> output owner
```

Blend math rule:

```text
premultiplied alpha is required for compositing participant outputs
```

Future advanced quality:

- multiband or exposure-aware blending may be added later for difficult
  A/B visual mismatch,
- but it must consume SCE contracts, not bypass them.

---

## 8. Runtime Mobile Performance Policy

Realtime cannot promise zero device cost on every Android device. It can and
must promise:

```text
no seam-specific avoidable stall
no silent state reset
no queue growth
stable fallback when budget is exceeded
```

### 8.1 Frame budget

Use mode-specific budgets:

```text
60fps target: about 16ms
90fps target: about 11ms
120fps target: about 8ms
```

### 8.2 Quality ladder

When budget is tight:

1. lower sample count,
2. reduce effect radius/trail,
3. reduce preview resolution where supported,
4. skip nonessential polish effects,
5. keep seam active-set/history/ownership intact.

Forbidden fallback:

```text
drop A or B from active set to save time
drop history to save time
switch owner mid-window to save time
```

### 8.3 Scheduler policy

Required behavior:

```text
latest seam request wins
stale results are ignored
critical seam frames cannot be skipped because an older request is in flight
```

Diagnostics must distinguish:

- dropped stale request,
- dropped frame deadline,
- applied latest frame,
- reused last valid continuity state.

---

## 9. Diagnostics

Every seam-relevant frame must be able to emit:

```text
TF_SEAM_CONTINUITY_PROOF
```

Required fields:

```text
transitionId
windowId
adapterMode
rootTimeMs
seamLocalTimeMs
normalizedProgress
activeSourceIds
sourceFromReady
sourceToReady
sourceFromDecoderWarm
sourceToDecoderWarm
boundaryPolicy
historyResolved
historyFallbackReason
effectStackId
executionOwner
surfaceOwner
overlayConflict
renderTimeMs
frameBudgetMs
droppedFrames
staleRequestIgnored
latestRequestApplied
decoderReconfiguredAtSeam
decoderDroppedSeamFrame
continuityPassed
continuityBlockers
```

Required success shape:

```text
TF_SEAM_CONTINUITY_PROOF
activeSourceIds=A,B
boundaryPolicy=start_inclusive_end_exclusive
historyResolved=true
overlayConflict=false
decoderDroppedSeamFrame=false
continuityPassed=true
```

---

## 10. Implementation Phases

### Phase 0 - Baseline and freeze

Do not start by changing effects.

Tasks:

- log current seam behavior,
- capture visible reproduction around A/B boundary,
- add diagnostics-only probes,
- identify current active source set, owner, decoder state, and history state.

Acceptance:

- `TF_SEAM_CONTINUITY_PROOF` exists in diagnostics-only mode,
- no behavior change yet,
- current discontinuity is measurable.

### Phase 1 - Boundary semantics lock

Tasks:

- define one official boundary policy: `[start, endExclusive)`,
- update tests that assert boundary ownership,
- identify and quarantine mismatched comparisons.

Acceptance:

- Dart/Kotlin tests prove consistent boundary behavior,
- no off-by-one policy remains undocumented.

### Phase 2 - Seam contracts

Tasks:

- add `SeamWindow`,
- add `SeamParticipant`,
- add `SeamActiveSet`,
- add `SeamTimeMapping`,
- project A/B participants for Manual Transition first.

Acceptance:

- every frame in transition window resolves `{A,B}`,
- seam local time is monotonic,
- blockers are explicit for missing source data.

### Phase 3 - Runtime program integration

Tasks:

- wire seam contracts into runtime program generation,
- stop filtering seam-active sources down to a single clip inside transition
  windows,
- keep dominant source separate from continuity active set.

Acceptance:

- runtime state carries A and B during seam window,
- no effect-specific fix required to see both participants.

### Phase 4 - Seam history cache

Tasks:

- create `SeamStateHistoryCache`,
- store previous transform/effect/contribution state,
- replace ad-hoc current-as-previous fallback in seam context,
- add explicit fallback reasons.

Acceptance:

- temporal effects resolve history across A/B boundary,
- first-frame or source-missing fallback is explicit,
- no silent zero velocity/history collapse.

### Phase 5 - Effect evaluation context

Tasks:

- add `SeamEffectEvaluationContext`,
- route transform, opacity, Gaussian, Motion Blur, and future effect
  evaluators through the same seam context,
- add effect dependency declarations.

Acceptance:

- all tested effects share the same seam source/time/history contracts,
- no effect owns seam-specific previous-state logic.

### Phase 6 - Submission and scheduler hardening

Tasks:

- replace seam-critical skip behavior with latest-request-wins behavior,
- prevent coarse buckets from hiding boundary changes,
- ignore stale results explicitly.

Acceptance:

- scrub/playback over seam does not miss the critical state update,
- diagnostics show latest seam request applied or explicit fallback.

### Phase 7 - Decoder continuity

Tasks:

- prewarm A and B descriptors before seam,
- keep both descriptors/source windows resident through seam,
- avoid decoder reconfigure/flush on normal boundary,
- log decoder readiness.

Acceptance:

- no decoder reconfiguration on critical seam frame for normal A/B video,
- no seam-specific playback stall from descriptor switch.

### Phase 8 - Ownership lock

Tasks:

- enforce one final owner,
- block overlay conflict,
- keep fallback stable if renderer is not ready.

Acceptance:

- `overlayConflict=false`,
- no owner flip-flop across seam,
- no duplicate visible output.

### Phase 9 - Export parity

Tasks:

- bind export adapter to same SCE contracts,
- allow higher quality only,
- forbid semantic divergence.

Acceptance:

- export uses same active set, time mapping, history dependency, and effect
  order.

### Phase 10 - Legacy cleanup

Tasks:

- remove seam-unsafe branches replaced by SCE,
- keep debug tools isolated,
- add guard tests preventing reintroduction.

Acceptance:

- no production seam path uses silent single-source switch,
- no production seam path silently defaults to identity/no-effects.

---

## 11. Test Matrix

### 11.1 Unit tests

Required tests:

- seam window resolves correct start/seam/end times,
- boundary policy is `[start, endExclusive)`,
- active set is `{A,B}` for every seam-window frame,
- normalized progress is monotonic,
- source time mapping for A/B is continuous,
- history cache hit across seam,
- history fallback reason explicit,
- no current-as-previous fallback inside seam context,
- effect dependency declarations are present.

### 11.2 Integration tests

Required tests:

- transform continuity across seam,
- opacity continuity across seam,
- Gaussian continuity across seam,
- Motion Blur continuity across seam,
- combined transform/effect continuity across seam,
- no identity/no-effects frame at seam,
- no owner flip-flop,
- no overlay conflict,
- no dropped critical seam update from in-flight scheduling.

### 11.3 Native/Android tests

Required checks:

- descriptor resolution at seam is deterministic,
- decoder does not reconfigure on normal seam frame,
- latest frame wins under rapid scrub,
- stale native result is ignored,
- frame budget diagnostics are emitted.

### 11.4 Device validation

Manual validation:

- scrub repeatedly through seam at slow speed,
- scrub repeatedly through seam at fast speed,
- play over seam at normal speed,
- pause just before seam and step forward,
- test Motion Blur, Gaussian, opacity, rotation, scale, and combined effects.

Acceptance:

- no visible effect gap,
- no one-frame reset,
- no severe seam-specific lag,
- no duplicate layer,
- no black flash,
- diagnostics confirm continuity.

---

## 12. Codex 5.3 Build Rules

Codex must follow these rules:

1. Do not solve this by changing only Motion Blur.
2. Do not add per-effect seam hacks.
3. Do not introduce a second visible overlay as final output.
4. Do not use bitmap snapshot or `MediaMetadataRetriever` loops for realtime
   seam continuity.
5. Do not hide frame drops by logging success.
6. Do not suppress Stage5 or switch owner without proof.
7. Do not remove fallback until replacement is proven.
8. Do not mix unrelated transition preset work into SCE checkpoints.

---

## 13. Rollout Safety

Use controlled rollout:

1. diagnostics-only SCE proof,
2. boundary semantics lock,
3. active-set projection,
4. history cache in shadow mode,
5. history cache read mode for selected effects,
6. global evaluator adoption,
7. native scheduler/decoder hardening,
8. export binding,
9. legacy cleanup.

No phase may claim final success without focused tests and a device install.

---

## 14. Checkpoint Policy

This plan is subject to:

```text
docs/professional_checkpoint_policy.md
docs/professional_refusion_motion_keyframe_engine.md
```

After each implementation phase:

```text
finish scoped change
-> run focused verification
-> flutter build apk --debug when behavior/native path changed
-> install on connected Android device when available
-> commit focused files only
-> push branch
-> report commit hash and rollback command
```

Commit message format:

```text
checkpoint: <seam continuity phase>
```

---

## 15. Final Acceptance

SCE is accepted only when all are true:

1. A/B seam behaves visually as one continuous event.
2. Effects do not drop at the boundary.
3. Transform state does not reset at the boundary.
4. History-based effects do not collapse for one frame.
5. Active source set contains A and B throughout the seam window.
6. Boundary semantics are unified across Dart and Kotlin.
7. Realtime scheduler does not drop the critical seam update.
8. Decoder readiness does not cause a seam-specific stall.
9. Exactly one final owner renders each frame.
10. Preview, Live Scrub, playback, and export share the same semantics.
11. Diagnostics prove continuity.
12. Tests and device validation pass.

---

## 16. Final Statement

The SCE professional rule is:

```text
one seam window
one participant set
one canonical time
one continuity history
one effect context
one final owner
```

This is the required architecture for ReFusionXx to make A and B behave like
one continuous professional shot under every effect.

