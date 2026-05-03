# Professional Canva Layer Unification Plan

Status: official strict implementation plan  
Package: `com.refusion.app`  
Branch: `codex/unified-keyframe-ops-foundation-20260426`  
Created: 2026-05-03  

This plan is the unified execution plan for making every visible canvas object
behave like a real animatable layer. The product-facing name is
`Professional Canva`. The architectural meaning is `Professional Canvas Layer
Unification`.

It consolidates the open work from:

- `docs/fix_animate_fx_on_transition_timeline_plan.md`
- `docs/professional_canvas_timeline.md`
- `docs/master_clock_value_truth_foundation_plan.md`
- `docs/master_live_scrub_professional_plan.md`
- `docs/professional_refusion_motion_keyframe_engine.md`

## Execution Update

- 2026-05-03 checkpoint slice (post `1869656`):
  - Manual Transition runtime seam mapping now resolves to root timeline time in
    Transition Focus and Scene Scope paths.
  - Transition Focus scrub preview sources now publish outgoing/incoming windows
    with source-range mapping tied to the active transition context, not the
    broad root catalog fallback.
  - Active transition source windows now map scene-local seam windows back to
    root when needed before runtime projection.
  - Scope: runtime time/source truth alignment only. This slice does not claim
    full video-layer parity or final Animate visual parity.
- 2026-05-03 keyframe-time truth slice (post `fc107db`):
  - Manual Transition Focus editor window is now aligned to the active
    transition window (no hidden broad scope during keyframe authoring).
  - Add Key now operates in the same visible time domain shown to the user
    inside Manual Transition Timeline.
  - Scope: keyframe authoring time-domain consistency. Full video-layer visual
    parity remains open.

## 0. Purpose

ReFusionXx must treat video, image, text, shape, masks, and future generated
objects as the same kind of professional canvas entity:

```text
visible object
-> Composition Layer
-> Motion Element
-> Motion Property Channels
-> Master Clock / Value Truth evaluation
-> Visual Layer Program
-> preview / playback / Live Scrub / export renderer
```

The current Manual Transition Scale issue proves the old split:

```text
video clip in transport/player
vs
text/image/shape as graph-backed layers
```

That split must end. A video clip must not be only a timeline transport item.
It must also resolve to a layer in the composition graph before Animate, FX,
Key, Value, Graph, preview, Live Scrub, playback, or export can claim
professional parity.

## 1. Current Verified Diagnosis

The app now has important foundations:

- Master Clock and Master Value Truth exist as the official time/value path.
- Manual Transition authoring no longer needs the legacy interactive transition
  compositor to avoid freezing.
- Manual lanes can be lowered into motion channels in partial paths.
- `Stage5VisualRuntimeState` exists and can submit transform/opacity data to
  the native side.
- Stage5 can attempt runtime transform application on scrub/player surface
  ownership paths.

But the plan is not complete because:

- Add Key in Manual Transition Focus is judged against the active transition
  window while the UI displays a wider editor scope, so the user can appear to
  be in a valid place while the command rejects the key.
- Manual Transition Timeline still does not feel like a true local transition
  timeline. It exposes surrounding clip space but only part of that space is
  valid for keyframes.
- Scale/Opacity values may be computed, transported, or submitted, but the
  visible video is still not guaranteed to be rendered as a composition layer.
- Video is still partly treated as a transport/player surface rather than the
  same `MotionLayerKind.video + MotionElementKind.videoClip` truth used by
  professional layer animation.
- Runtime output is still bridge-oriented. The target must become a real
  `VisualLayerProgram`, not a transition-specific runtime workaround.

## 2. Non-Negotiable Rule

Every visible object on the canvas is a layer.

```text
If Animate or FX targets something that is not resolved to a layer, it is a bug.
If a renderer displays video outside the layer graph, it is legacy surface
ownership, not professional canvas behavior.
If a keyframe is added in a time domain different from what the user sees, it is
a bug.
```

## 3. Mandatory Reading For Writer Agents

Before editing code under this plan, read:

1. `/Users/mx/.codex/skills/refusion-development-guardrails/SKILL.md`
2. `docs/professional_checkpoint_policy.md`
3. `docs/professional_canva_layer_unification_plan.md`
4. `docs/professional_canvas_timeline.md`
5. `docs/fix_animate_fx_on_transition_timeline_plan.md`
6. `docs/master_clock_value_truth_foundation_plan.md`
7. `docs/master_live_scrub_professional_plan.md`
8. `docs/live_scrub_migration_mandate.md`
9. `docs/professional_refusion_motion_keyframe_engine.md`

Then run:

```bash
git status -sb
git rev-parse --short HEAD
```

Ignore unrelated untracked `../../../.claude/`.

## 4. Protected Boundary

This plan eventually requires renderer and Live Scrub integration, but protected
Stage5/Live Scrub files must not be touched until the exact implementation
slice names the files and the user explicitly approves that slice.

Protected files include:

- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`
- `Stage5PreviewPlatformView`
- Flutter Live Scrub handoff paths

Before that approval, work only in:

- domain models;
- resolvers;
- adapters;
- tests;
- UI scope/time mapping;
- docs;
- guard tests that prevent legacy paths.

## 5. Canonical Layer Truth

Do not create a parallel `VideoLayerModel` if the existing model can represent
video correctly.

Canonical model:

```text
MotionLayerModel(kind: MotionLayerKind.video)
  -> MotionElementModel(kind: MotionElementKind.videoClip)
  -> MotionElementSourceBinding(media asset/source)
  -> MotionPropertyChannelModel(transform/opacity/fx)
```

Meaning:

- `TimelineClipData` is timeline placement and UI/transport projection.
- `MotionLayerModel` is visual authoring truth.
- `MotionElementModel` is layer content.
- `MotionElementSourceBinding` binds real media/source identity.
- `RendererSurface` displays evaluated output only. It does not own animation.

## 6. Current Problem To Fix

### 6.1 Keyframe Time Truth Failure

Observed behavior:

```text
User enters Manual Transition Timeline.
User moves playhead over a visible part of clip A.
User presses Add Key.
App says: Move the playhead inside the transition window before adding a keyframe.
```

Root reason:

- Manual Transition Focus displays a broad editor scope around the transition.
- Add Key accepts only the real active transition window.
- The UI does not make that boundary explicit enough.
- The Add Key command is correct to reject outside the real window, but the user
  experience is wrong because the displayed timeline suggests a wider editable
  range.

Required outcome:

```text
What the user sees as the Transition Timeline must be the same time domain that
the Add Key command accepts, or the UI must clearly separate editor context from
keyframe-active window.
```

### 6.2 Video Layer Truth Failure

Observed behavior:

```text
User adds Animate Scale.
User adds keyframes and edits value.
Preview/Play/Live Scrub do not show scale.
```

Root reason:

- Video is not yet fully consumed as the same graph-backed canvas layer as
  text/image/shape.
- Manual Transition runtime data is still not a full `VisualLayerProgram`
  consumed by the renderer stack.
- Applying a transform to player/scrub surfaces is an intermediate bridge, not
  the final professional canvas architecture.

Required outcome:

```text
Scale on video must be the same concept as Scale on image/text/shape:
MotionPropertyChannelModel -> Master Value Truth -> VisualLayerProgram ->
renderer.
```

## 7. Target Pipeline

The canonical flow for all visible objects:

```text
User gesture / Add Animate / Add FX / Add Key / Value edit
-> Unified Target Resolver
-> MotionPropertyTarget(layer/element)
-> MotionPropertyChannelModel
-> MasterTimeSnapshot
-> MasterTimeDomainMapper
-> MasterKeyframeValueEvaluator
-> MasterLiveScrubProgramAdapter / VisualLayerProgramBuilder
-> renderer-specific adapter
-> Preview / Play / Live Scrub / Export
```

No step may target raw `clipId` unless a resolver proves which layer/element it
maps to.

## 8. Phase 0 - Documentation And Inventory

Goal: freeze the truth contract before new behavior changes.

Deliverables:

- This document exists and is linked from related plans.
- Inventory every path that treats video as:
  - timeline-only clip;
  - transport-only media source;
  - graph-backed video layer;
  - transition temporary A/B source;
  - export visual node.
- Mark each path as:
  - keep;
  - adapt;
  - guard;
  - delete later.

Verification:

```bash
rg "MotionLayerKind.video|MotionElementKind.videoClip|TimelineVisualKind.video|TimelineClipContentKind.media|Stage5VisualRuntimeState|ProfessionalVideoTransitionSurfaceOverlay" lib android test docs
```

Checkpoint:

```text
checkpoint: document professional canva layer unification
```

## 9. Phase 1 - Root Video Layer Contract

Goal: every root video clip resolves to layer truth.

Required:

- Create or harden a resolver:

```text
TimelineClipData(video)
-> canonical layer id
-> canonical element id
-> source binding
```

- If the clip already has graph backing, reuse it.
- If the clip is timeline-only, produce a deterministic projection layer rather
  than letting Animate target the raw clip.
- The projection must be stable across rebuilds and undo/redo.

Forbidden:

- no new renderer;
- no Stage5 edits;
- no fake preview transform;
- no new clock.

Tests:

- video timeline clip resolves to `MotionLayerKind.video`;
- source binding preserves asset id/source uri;
- repeated resolver calls return stable ids.

## 10. Phase 2 - Unified Target Resolver

Goal: all authoring tools target the same layer/property truth.

Resolver input:

```text
selection
timeline clip
scene clip instance
scene layer scope
manual transition outgoing/incoming role
bridge selection
```

Resolver output:

```text
MotionPropertyTarget
```

Must support:

- root video clip;
- image layer;
- text layer;
- shape layer;
- scene clip instance;
- source scene layer;
- manual transition outgoing video layer;
- manual transition incoming video layer;
- manual transition both policy.

Blocker rules:

- no target -> show explicit blocker;
- ambiguous target -> show explicit blocker;
- raw clip target without layer resolution -> fail test.

Tests:

- Add Animate Scale from root video resolves to video layer/element target.
- Add Animate Scale from Manual Transition resolves to outgoing/incoming/both
  policy.
- Existing text/image/shape target behavior remains unchanged.

## 11. Phase 3 - Keyframe Time Truth

Goal: Add Key always writes at the time the user sees.

Required:

- Separate `editorContextWindow` from `keyframeActiveWindow`.
- Manual Transition Timeline must expose a clear local transition time domain:

```text
localTransitionTime: 0..transitionDuration
transitionProgress: 0..1
rootTime: seamStart..seamEnd
```

- Add Key in Manual Transition must use `localTransitionTime` or
  `transitionProgress`, not broad editor scope progress.
- If the UI still shows surrounding context, the active keyframe window must be
  visually distinct and snapping must move to it intentionally.
- Do not silently clamp a keyframe from invalid context into the active window.
- If outside active window, rejection must name the actual valid range and the
  current playhead time.

Tests:

- Add Key at transition local start creates stop `0.0`.
- Add Key at transition local middle creates stop `0.5`.
- Add Key at transition local end creates stop `1.0`.
- Add Key outside active window rejects without adding a key.
- Dragged/moved keyframes preserve ids and values.

Acceptance:

- The user can add keyframes comfortably where the transition timeline visibly
  indicates the keyframe window.
- No keyframe appears in a surprising place.

## 12. Phase 4 - Manual Transition As Composition Scope

Goal: Manual Transition is a focused composition scope, not a renderer.

Scope contains:

```text
outgoing video layer instance
incoming video layer instance
transition window
transition progress
layer target policy
motion property channels
```

Policy:

- Scale defaults to `both` only if no target is selected.
- If the user selected outgoing/incoming, target only that role.
- UI should eventually expose role targeting.
- Current safe default may remain `both`, but it must be explicit in code and
  tests.

Forbidden:

- no `ProfessionalVideoTransitionSurfaceOverlay` for Manual Transition;
- no `renderInteractiveFrame`;
- no `MediaMetadataRetriever` interactive manual rendering;
- no legacy `manualTransform` compositor for authoring preview/play/scrub.

Tests:

- Manual Transition scope builds outgoing/incoming layer instances.
- Scale lane maps to target policy.
- Unsupported FX creates blocker and never starts old renderer.

## 13. Phase 5 - Lane To Motion Channel Hardening

Goal: Manual lanes become real motion channels with correct target/time/value.

Required:

- Scale -> `visual.scaleX` and `visual.scaleY`.
- Position -> `visual.positionX` and `visual.positionY`.
- Rotation -> `visual.rotationDegrees`.
- Opacity -> `visual.opacity`.
- FX parameters -> canonical property/effect definitions.
- Keyframe stops must be transition-local/progress-based and mapped to root
  time through `MasterTimeDomainMapper`.

Tests:

- Scale `0` maps to renderer scale `1.0`.
- Scale `100` maps to renderer scale `2.0`.
- Negative scale UI values, if allowed, map according to official value truth.
- Opacity `100` maps to `1.0`.
- Empty lanes default without showing fake motion.

## 14. Phase 6 - Visual Layer Program

Goal: introduce the renderer-facing layer program that is shared by preview,
playback, Live Scrub, and export.

Model:

```text
VisualLayerProgram {
  rootTime
  canvasSize
  layers[]
  blockers[]
  diagnostics[]
}

VisualLayerNode {
  layerId
  elementId
  sourceBinding
  sourceKind
  role
  drawOrder
  timelineRange
  sourceRange
  transform
  opacity
  effects
  masks
  blockers
}
```

Rules:

- `LiveScrubVisualProgram` may be an implementation-specific projection of this
  model, but it may not be the only truth.
- Stage5 receives renderer-specific descriptors generated from this program.
- Flutter overlays receive renderer-specific snapshots generated from this
  program.
- Export receives export-specific descriptors generated from this program.

Tests:

- Root video scale produces a non-identity `VisualLayerNode.transform`.
- Manual Transition scale produces outgoing/incoming nodes with non-identity
  transforms at keyframed times.
- No visual node may exist without source binding unless it carries a blocker.

## 15. Phase 7 - Preview Renderer Parity For Layers

Goal: preview shows the same evaluated layer truth for video/image/text/shape.

Required:

- Existing image/text/shape preview overlays must consume the same program or a
  projection from it.
- Video preview must no longer depend on transition-only runtime patches.
- Existing `MotionVideoPreviewTransformSurface` may be kept only as a projection
  consumer, not as the source of truth.

Acceptance:

- Video Scale keyframe shows immediately in paused preview.
- Video Scale keyframe shows while editing the value.
- Text/image/shape behavior remains unchanged.

## 16. Phase 8 - Stage5 Runtime Adapter

Goal: Stage5 consumes evaluated visual layer truth without legacy transition
rendering.

Protected approval required before code edits in Stage5 files.

Required:

- Derive `Stage5VisualRuntimeState` or its replacement from
  `VisualLayerProgram`.
- Apply transform/opacity to the visible video output path during:
  - preview paused;
  - playback;
  - active Live Scrub;
  - scrub settle.
- Do not rely on broad config pushes for per-frame animated values.
- Runtime visual state updates must follow Master Clock frame identity.

Acceptance:

- Video Scale inside Manual Transition is visible in Preview.
- The same Scale is visible in Play.
- The same Scale is visible during Live Scrub.
- Play never becomes audio-only.
- Live Scrub does not freeze.

## 17. Phase 9 - FX Renderer Path

Goal: FX become real layer effects, not bitmap fallbacks.

Order:

1. transform/opacity only;
2. blur via approved native/Media3/GL route;
3. tile/mirror edge;
4. motion blur;
5. masks and trims;
6. export parity.

Forbidden:

- no per-frame `MediaMetadataRetriever`;
- no thumbnail/poster proof;
- no Flutter fake effect if the renderer claims native parity.

Unsupported FX:

- must show blockers;
- must not freeze;
- must not silently apply nothing.

## 18. Phase 10 - Legacy Isolation And Deletion

Goal: prevent regression into the old transition renderer.

Guards:

- Manual Transition authoring must not mount
  `ProfessionalVideoTransitionSurfaceOverlay`.
- Manual Transition authoring must not create a professional render plan for
  interactive preview/play/scrub.
- Manual Transition authoring must not call `renderInteractiveFrame`.
- Manual interactive authoring must not call `MediaMetadataRetriever`.

Tests:

- Add Animate Scale -> no legacy overlay.
- Add Key -> no legacy overlay.
- Value edit -> no legacy overlay.
- Play/Live Scrub after edit -> no legacy overlay.

## 19. Phase 11 - Acceptance Matrix

Required manual device checks:

- Root video Scale: preview, play, Live Scrub.
- Root video Opacity: preview, play, Live Scrub.
- Manual Transition Scale outgoing only.
- Manual Transition Scale incoming only.
- Manual Transition Scale both.
- Manual Transition Add Key at start/middle/end.
- Add Key outside active window rejection.
- Remove lane and verify video returns to identity.
- Multiple lanes: Scale + Opacity + Rotation.
- Fast scrub through 5+ keyframes.
- Play after keyframe edit: no audio-only state.
- Logs: no legacy manual renderer calls.

Required automated checks:

- resolver tests;
- keyframe time mapping tests;
- lane-to-channel tests;
- visual layer program tests;
- legacy guard tests;
- targeted Flutter adapter tests;
- native compile/build when Stage5 adapter changes.

## 20. What Remains From The Current Plan

The remaining work is not "make Scale bigger." It is:

1. Finish video-as-layer truth.
2. Fix Manual Transition keyframe time truth.
3. Resolve all Animate/FX targets through a unified layer target resolver.
4. Convert Manual Transition scope to composition/layer scope.
5. Build a shared Visual Layer Program.
6. Connect preview to that program.
7. Connect Stage5 to that program with explicit protected approval.
8. Add real FX renderer slices after transform/opacity works.
9. Lock guards against the old manual renderer.
10. Prove parity on device.

## 21. Recommended Next Build Slice

Do not start with native Stage5 or FX.

Next slice:

```text
checkpoint: add professional canva video layer target resolver
```

Scope:

- build root video clip -> layer/element/source resolver;
- build Manual Transition outgoing/incoming/both target resolver;
- add tests proving Scale targets a layer/element, not a raw clip;
- add tests proving Add Key local transition time maps correctly;
- no Stage5 edits;
- no Live Scrub protected edits.

This slice makes the app know exactly what should be animated before any
renderer is asked to draw it.

## 22. Definition Of Done

This plan is closed only when:

- every root video clip resolves to a canonical video layer;
- every Manual Transition outgoing/incoming source resolves to layer instances;
- Add Key writes in the same time domain shown to the user;
- Scale/Opacity/Position/Rotation on video behave like image/text/shape;
- Manual Transition Animate affects real video, not a still frame;
- Preview, Play, Live Scrub, and Export consume the same evaluated layer truth;
- unsupported FX report blockers and never freeze;
- legacy manual renderer paths are guarded or deleted;
- app docs and `refusion-skills` are updated;
- checkpoints are pushed and rollback commands are known.

## 23. One-Line Rule

Professional Canva means: video, image, text, and shape are all canvas layers
with the same time, target, keyframe, value, and renderer truth.
