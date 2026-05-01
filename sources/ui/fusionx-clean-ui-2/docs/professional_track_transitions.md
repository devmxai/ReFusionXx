# Professional Track Transitions

Status: documentation and planning only. No runtime code is implemented by this
file.

This document records the current state of the active ReFusion professional
timeline plans, then opens a dedicated plan for professional transitions between
two adjacent video clips: clip A to clip B.

## 0. Current Plan Ledger

This ledger is intentionally practical. "Closed" means the current development
branch has a real implementation or an accepted checkpoint. "Open" means the
work remains architectural, partially implemented, or still requires validation.

### 0.1 Closed Or Accepted Checkpoints

- Protected Live Scrub boundary is established in
  `docs/live_scrub_migration_mandate.md`.
- Scoped Layer Timeline is the accepted direction for layer-local animation and
  FX, documented in `docs/professional_scope_timeline.md`.
- Double tap / double click on supported layer content opens scoped timeline.
- Scoped text layer authoring exists as the first vertical slice.
- Scoped keyframe lanes use real authored keyframes, not visual mockups.
- Opacity, position, scale, rotation, and Gaussian blur have first real scoped
  authoring paths.
- Keyframe selection, value editing, and move-to-playhead behavior have been
  implemented enough for active testing.
- Keyframe identity issues are documented and the direction is identity-based
  keyframes, not index-based keyframes.
- Direct text effects and scriptable motion have a canonical architecture in
  `docs/professional_direct_text_effects_and_scriptable_motion.md`.
- Scoped text script import exists and is documented in
  `docs/scoped_text_motion_script_v1.md`.
- Professional interpolation rollout through Phase 5 is documented in
  `docs/professional_motion_interpolation_rollout.md`.
- The current script path supports canonical spring, bounce, and elastic
  interpolation payloads.
- First named text motion families exist in documentation and import guidance:
  `bounceIn`, `riseIn`, `slideIn`, `wordRiseIn`, `letterPopIn`,
  `wordCascade`, `letterBounce`, `slideBlurIn`, `blurRiseIn`, `rotateIn`, and
  `elasticPop`.
- Native preview resume recovery has a current checkpoint and is installed for
  device validation.
- Git checkpoint workflow is active: meaningful stable changes are committed
  and pushed to the feature branch before risky follow-up work.

### 0.2 Open Work Still Not Closed

- Shared Undo/Redo is not yet fully wired for every scoped command. It remains a
  shipping blocker for broad editing.
- Full universal scoped effect system is not complete yet. Text is the first
  path, but image, shape, and video scopes still need the same contract.
- Full effect sheet with default and advanced controls is not complete for all
  effects.
- FX stack reorder, enable/disable, conflict handling, and ownership UI remain
  open.
- Export parity for every authored effect must be validated before claiming
  production completeness.
- First-play smoothness still needs instrumentation and measured cache/prewarm
  work. Timing must not be patched by changing playback speed.
- Lifecycle preview recovery is implemented as a checkpoint but still needs
  user-device validation after background/resume.
- Image Scope and Video Scope remain future phases.
- Advanced graph editor, value graph, speed graph, Bezier handles, and advanced
  curve editing remain open.
- Full memory/cache hardening remains open, especially the Dart preview
  thumbnail cache policy.
- Professional transition authoring between timeline clips is not implemented
  yet. This document opens that track.

### 0.3 Work We Should Not Mix Together

The following systems must remain separate in planning and implementation:

- Scoped Layer Timeline: animation and FX inside one selected layer.
- Canvas and Timeline property graph: canonical transforms and keyframes.
- Direct text effects and script import: text motion authoring surface.
- Track transitions: boundary effects between clip A and clip B.
- Live Scrub engine: protected native hot path.

Transitions must not be hidden inside scoped layer work. They are root timeline
boundary operations.

## 1. Non-Negotiable Transition Directives

### 1.1 Do Not Build A Second Timeline Engine

Transitions must be represented as data on the existing root timeline and
rendered through the existing preview/export architecture.

Do not create:

- a transition-only timeline
- a transition-only playback clock
- a transition-only scrub engine
- a transition-only preview surface

The current `TimelinePanel` remains the UI foundation.

### 1.2 Do Not Regress Live Scrub

Live Scrub remains a protected system boundary.

Transition work must not modify Stage5 live scrub files unless the change is
explicitly approved as a Live Scrub task.

If a transition requires a new preview behavior during scrub, the required data
must be surfaced to the existing scrub/preview contract rather than bypassing
it.

### 1.3 Transitions Are Boundary Effects

A transition belongs to the boundary between two clips:

```text
clip A end  ->  transition boundary  ->  clip B start
```

It is not a text layer, not an image layer, and not a scoped layer animation.

### 1.4 Transitions Must Be Deterministic

The same transition definition must evaluate consistently in:

- root timeline preview
- playback
- scrub where supported
- export
- future project reload

If a transition can preview but cannot export, it must be marked as preview-only
and blocked from shipping as complete.

### 1.5 Shared History Is Required

Transition apply, remove, trim, parameter edit, and keyframe edit must enter the
same editor history as root timeline edits.

No separate transition undo stack is allowed.

## 2. Product Definition

A professional transition is a non-destructive effect instance attached to the
join or overlap of two clips.

Examples:

- Cross Dissolve
- Dip To Black / Dip To White
- Blur Dissolve
- Push
- Slide
- Wipe
- Zoom Blur
- Spin / Rotation transition
- Luma Fade
- Light Leak / Flash
- Glitch
- Match Cut helper later

The first release should start small and reliable:

1. Cross Dissolve
2. Dip To Black
3. Blur Dissolve
4. Push Left / Push Right

These cover the core engine requirements without introducing a complex shader
system too early.

## 3. Timeline Model

### 3.1 Transition Instance

Each transition should have stable identity.

```text
TimelineTransitionInstance
  id
  fromClipId
  toClipId
  boundaryTime
  duration
  alignment
  definitionId
  parameters
  parameterChannels
  enabled
  createdBy
```

### 3.2 Alignment

Professional editors generally support three transition alignments:

```text
centered_on_cut
start_at_cut
end_at_cut
```

Initial implementation may support only `centered_on_cut`, but the model must
not block the other two.

### 3.3 Handles And Valid Duration

A transition duration is limited by available source handles:

- `clip A` must have enough media after its visible end if the transition needs
  post-cut frames.
- `clip B` must have enough media before its visible start if the transition
  needs pre-cut frames.

If handles are missing, the app must not silently fake professional behavior.
It must either:

- clamp the transition duration,
- show a clear warning,
- or use a supported fallback mode.

### 3.4 Parameter Channels

Transition parameters must use the same property-channel philosophy as scoped
effects.

Examples:

```text
transition.progress
transition.opacityA
transition.opacityB
transition.blur.amount
transition.push.direction
transition.push.distance
transition.wipe.angle
transition.wipe.softness
```

For V1, many transitions can be driven by a normalized progress value from
`0..1`.

## 4. UI Contract

### 4.1 Root Timeline Entry Point

Transitions are added from the root timeline, not from scoped layer.

Possible entry points:

- tap the cut between two clips
- plus button between adjacent clips
- long press the boundary
- transition browser button when a boundary is selected

V1 should choose one clear path:

```text
select boundary between clip A and clip B -> open transition browser
```

### 4.2 Timeline Representation

The transition should appear as a small bridge over the cut:

```text
[ clip A ][ transition ][ clip B ]
```

It should not look like a separate media clip. It is a boundary effect.

Minimum visual states:

- normal
- selected
- disabled
- invalid because handles are insufficient

### 4.3 Transition Inspector

Selecting a transition opens a bottom sheet or inspector with:

- transition name
- duration
- alignment
- core parameters
- preview toggle if needed
- remove transition

The inspector must not push the timeline layout upward in a way that destabilizes
the root editing UI.

### 4.4 Transition Browser

The browser should use the same professional bottom-sheet language as Animate
and FX:

- search at top
- category list
- rectangular selectable rows/cards
- plus/apply action
- no unrelated tools

Initial categories:

- Basic
- Blur
- Motion
- Wipe
- Light
- Stylized

## 5. Evaluation Contract

### 5.1 Transition Evaluation Window

A transition is active only within its boundary window:

```text
boundaryStart <= timelineTime <= boundaryEnd
```

The evaluator receives:

```text
fromClipFrame
toClipFrame
progress
parameters
```

It returns a composed visual frame or a transition render instruction.

### 5.2 Progress

Progress is normalized:

```text
progress = (timelineTime - boundaryStart) / duration
```

Progress is clamped to `0..1`.

Easing may be applied to progress, but the raw progress should remain available
for deterministic export.

### 5.3 Render Order

Transition render order must be explicit:

1. sample clip A at the correct source time
2. sample clip B at the correct source time
3. apply transition definition using progress and parameters
4. composite result into the root preview/export frame
5. overlay layer-level scoped animations above the video background where
   appropriate

This order must be documented before implementation because it affects text,
image, and shape overlays during transitions.

## 6. Preview, Scrub, And Export

### 6.1 Preview

Preview should use the same root playback clock.

No transition-specific clock is allowed.

### 6.2 Live Scrub

Live Scrub parity is required, but must be added carefully.

For early implementation:

- transition UI and data may be authored first
- playback preview may be enabled first
- Live Scrub transition rendering may be gated until the safe bridge is proven

The app must never degrade current scrub responsiveness for all clips just to
preview a transition.

### 6.3 Export

Export parity is mandatory before calling a transition shippable.

Each transition definition must declare:

```text
previewSupport
scrubSupport
exportSupport
fallbackPolicy
```

No transition should silently export differently from preview.

## 7. Implementation Phases

### Phase 0 - Transition Baseline And Guardrails

Goal:

Document the current timeline transition-related UI and confirm no existing
transition work is being overwritten.

Deliverables:

- transition plan exists
- protected Live Scrub note copied into transition tasks
- current `TimelinePanel` boundary rendering audited
- current transition bottom-sheet widgets audited

Exit criteria:

- no runtime code changed
- exact insertion point for root boundary selection is known

### Phase 1 - Boundary Selection Model

Goal:

Allow the root timeline to identify the boundary between clip A and clip B.

Deliverables:

- stable boundary id
- selected boundary state
- boundary hit testing
- selected boundary visual state

Exit criteria:

- user can select a cut without selecting either clip
- selection does not interfere with clip trim, scroll, or Live Scrub gestures

### Phase 2 - Transition Data Model

Goal:

Represent a transition as durable timeline data.

Deliverables:

- `TimelineTransitionInstance`
- definition id
- from/to clip identity
- duration
- alignment
- parameters

Exit criteria:

- transition can be added and removed from state
- undo/redo contract is written before broad use
- no visual effect required yet

### Phase 3 - Transition Browser UI

Goal:

Add the professional transition browser for selected boundaries.

Deliverables:

- bottom sheet browser
- search
- initial transition list
- add/apply action

Exit criteria:

- adding Cross Dissolve creates a transition instance
- root timeline representation appears over the boundary
- no playback behavior changed yet

### Phase 4 - First Real Transition: Cross Dissolve

Goal:

Implement the smallest real transition with clear preview/export semantics.

Deliverables:

- `progress` evaluator
- opacity blend from A to B
- duration editing
- deterministic preview
- export path decision

Exit criteria:

- Cross Dissolve previews correctly
- playback timing stays unchanged
- root timeline selection remains stable

### Phase 5 - Dip And Blur Families

Goal:

Add visually useful professional transitions after the dissolve baseline.

Deliverables:

- Dip To Black
- Dip To White
- Blur Dissolve
- optional easing on progress

Exit criteria:

- all parameters are visible in inspector
- all transitions declare preview/export support
- no hidden preset-only behavior

### Phase 6 - Motion Transitions

Goal:

Add directional motion transitions.

Deliverables:

- Push Left
- Push Right
- Slide Up / Down later
- motion blur decision documented

Exit criteria:

- transition geometry is deterministic
- mobile preview remains stable

### Phase 7 - Live Scrub Parity Gate

Goal:

Bring transitions into scrub only after playback preview and export decisions are
stable.

Deliverables:

- performance check
- scrub behavior matrix
- fallback for unsupported transition previews

Exit criteria:

- current Live Scrub quality is not slower
- scrubbing over normal clips remains unchanged
- scrubbing over a transition has deterministic behavior or a documented safe
  fallback

### Phase 8 - Advanced Transition Stack Later

Future work:

- transition presets with editable internals
- shader-based transitions
- luma matte transitions
- transition keyframes
- AI-generated transition recipes
- transition script import

This phase must not begin until the basic boundary model is stable.

## 8. Validation Matrix

Every transition implementation must be validated against:

- add transition at a simple cut
- remove transition
- change duration
- trim clip A after adding transition
- trim clip B after adding transition
- split near a transition
- duplicate a clip with transition nearby
- undo add transition
- undo duration change
- playback over transition
- scrub before, inside, and after transition
- export the transition
- enter scoped layer before and after transition
- return from background and play over transition

## 8.1 Professional Video Transition Compositor Contract

The professional video transition compositor is a general system, not a
Zoom-specific system.

Every video transition must enter the native compositor through a shared
`ProfessionalVideoTransitionRenderPlan` shape:

- `definitionId`: the transition definition, such as `zoomInCamera`,
  `whipPan`, `motionBlurPush`, `lumaWipe`, or future definitions;
- `transitionId`: the authored transition instance id;
- canvas dimensions;
- seam timing and leading/trailing durations;
- source list with timeline range and source-media range;
- required capabilities;
- transition parameters;
- sampling policy;
- edge policy;
- motion blur policy.

The compositor decides whether it can render a transition by matching the
definition and its required capabilities against the native renderer registry.
If a transition is not supported, the renderer must return an explicit
`unsupported` result with missing capabilities. It must not silently fall back
to a Flutter overlay, a frozen frame, a thumbnail, Gaussian blur, decorative
speed lines, or a transformed single video surface.

The native foundation includes a renderer registry entry point. It can report
known definitions such as `crossDissolve`, `fadeBlack`, and `zoomInCamera`, then
classify requests as unknown definitions, missing capabilities, or renderer not
implemented. The registry is intentionally allowed to reject a known transition
until its real renderer is present.

Current authoring gate:

- no new video transition preset, manual transition lane, or AI-generated
  transition draft may be created while the native compositor reports the
  foundation/unavailable capability set;
- the browser may show transition categories as locked roadmap entries, but it
  must not return an apply/manual/AI result until the compositor reports every
  professional capability: dual video sampling, temporal motion blur,
  mirror-edge tiling, preview parity, Live Scrub parity, playback parity, and
  export parity;
- this strict gate intentionally applies to simpler definitions too. Cross
  Dissolve, Fade Black, and Zoom In Camera must all wait for the same general
  compositor readiness instead of each shipping a separate fallback path.

Native render-session foundation:

- `prepareRenderPlan` must parse the loose platform map into a strict
  two-source render session before a renderer is allowed to run;
- the session must validate positive canvas size, non-negative seam timing,
  positive transition duration, exactly two sources, `[outgoing, incoming]`
  roles, positive source timeline/source ranges, outgoing coverage through the
  boundary, and incoming coverage from the boundary through the trailing window;
- unsupported native responses should carry session metadata such as
  `renderSessionId`, transition start/end, source roles, and source times at the
  seam. This makes the future GPU renderer attach to a real contract without
  enabling any visual fallback.

`crossDissolve` now has a first domain-level frame planner. The planner reads
the shared `ProfessionalVideoTransitionRenderPlan` and computes normalized
progress, outgoing opacity, incoming opacity, and real source times for both
video streams. It also reports whether both source ranges cover the full
transition window. A renderer must not treat a cross dissolve as renderable when
coverage is false, because that would force one side to clamp to a still
boundary frame. This planner is the primitive math contract only; native
preview/export parity still requires a connected dual-video compositor. The
built-in default duration is two seconds split symmetrically around the seam.
Short windows below about 600ms should be treated as a stylistic quick fade,
not the professional default.

Scene Contents video-layer proxies must carry media-source timing, not their
scene-local timeline placement, into transition preview requests. For a
transition between layer A and layer B, outgoing boundary warmup samples the
last visible source frame of A and incoming boundary warmup samples the first
visible source frame of B at canvas resolution, not low-resolution fallback
thumbnail size. The interim Flutter preview bridge for Cross Dissolve is
seam-aware: before the seam the live native surface is outgoing A and the
incoming first boundary frame fades in; after the seam the live native surface
is incoming B and the outgoing last boundary frame fades out. This keeps the
visible handoff anchored to A-end/B-start until the full dual-video native
compositor renders both moving streams directly.

Zoom In Camera is the first demanding test case for this general compositor. It
is not the architecture itself.

## 8.2 Zoom In Camera Baseline

The `Zoom In Camera` preset is an After-Effects-inspired seam transition, not a
simple card overlay.

Strict current contract:

- Zoom In Camera is not allowed to ship through a Flutter overlay or transformed
  Android `PlatformView`. That path can only fake motion blur, can leak outside
  the preview canvas, and cannot composite A/B video streams.
- Zoom In Camera must be gated until a real professional video transition
  compositor exists. The compositor must read the playing end of clip A and the
  playing beginning of clip B as live video samples over the whole transition
  window.
- exact boundary-frame extraction remains available for AI transition seeds and
  non-live fallback transitions, but Zoom In Camera preview must not fall back
  to generic asset thumbnails or a frozen frame.
- no Stage5 Live Scrub internals are touched for exact boundary-frame warmup or
  compositor preparation unless a specific reviewed native preview task approves
  it first;
- scale velocity peaks at the seam, then resolves;
- opacity handoff is centered around the seam and must not become a slow
  cross-dissolve;
- motion blur must be temporal shutter sampling or an equivalent native/GPU
  compositor implementation. Gaussian blur and decorative speed lines are not
  valid motion blur for this preset.
- Motion Tile / mirror-edge expansion must happen before transform sampling so
  scaled or compressed incoming video never reveals black edges.

Professional compositor recipe at 30fps:

- duration: about 4 seconds by default, with the seam centered so roughly the
  last 2 seconds of A and first 2 seconds of B participate;
- inspector range: 1.2s..5.0s for shorter or more cinematic cuts;
- outgoing scale: `1.0 -> 3.0`, accelerated into the seam;
- incoming scale: `0.28 -> 1.0`, decelerated after the seam, matching the
  After Effects transform-adjustment-layer pattern where B continues from a
  compressed scale into normal framing;
- overlap handoff: roughly `42%..58%` of the transition window;
- incoming lead: no frozen pre-roll; B becomes live at the seam and settles
  after it;
- shutter angle: `180..360` degrees, with bounded temporal samples;
- mirror edges: enabled, with output overscan large enough to cover the largest
  scale/rotation in the transition;
- impact shake: `5px`;
- bridge darkness: `12%`.

Current gate:

- the previous Flutter-side Zoom In Camera preview has been removed from the
  preset picker and no longer draws fake speed lines, frozen-frame cards, or
  Gaussian motion blur.
- `ProfessionalZoomCameraCompositorPlanner` now defines the canonical timing
  contract for the future native compositor: outgoing and incoming source times
  are resolved from real timeline/source ranges, shutter sample times are
  generated from shutter angle and frame rate, and mirror-edge motion tiling is
  required by the render plan.
- a future `ProfessionalVideoTransitionCompositor` must own preview, scrub,
  playback, and export parity before any new video transition authoring path is
  exposed again as engine-backed.
- the Android app now exposes
  `com.refusion.app/professional_video_transition_compositor.getCapabilities`
  as the native capability bridge for this compositor. The current native
  response is deliberately unavailable for every required capability, so every
  new video transition authoring path remains locked until the real dual-video
  compositor, temporal motion blur, mirror-edge tiling, preview, scrub,
  playback, and export parity are all implemented and reported from native
  code.
- Flutter and Android now also share the generic `prepareRenderPlan` contract.
  Zoom In Camera lowers into this general render plan with canvas size, seam
  timing, outgoing/incoming source ranges, shutter settings, and mirror-edge
  tile overscan. The native foundation currently validates the required shape
  and returns a clear unsupported status instead of rendering. This is
  intentional: the next implementation slice must replace that unsupported
  response with real renderer capabilities, not a Flutter overlay fallback.
- Flutter and Android now also share `planVideoSourceBindings`. Every outgoing
  and incoming source may carry a concrete `sourceUri`, and the native
  foundation validates whether both sources are bound before exact decode can
  advance. `assetId` is identity metadata, not a decode source. If a source URI
  is missing, the decoder path stays blocked with
  `native_video_source_uri_missing`; asset-id-only decode and generated proxy
  decode are explicitly forbidden.
- Flutter now has `ProfessionalVideoTransitionRenderPlanAdapter` as the
  production-facing source-bound plan builder. It accepts adjacent
  `TimelineClipData` clips, the transition boundary, canvas size, and a
  `sourceUri` resolver, then builds the strict outgoing/incoming
  `ProfessionalVideoTransitionRenderPlan`. The adapter fails closed when either
  side lacks a concrete URI, visible timeline handle, source handle, or explicit
  source-rate support. Large editor screens must use this adapter instead of
  hand-assembling compositor sources.
- Flutter now also has `ProfessionalVideoTransitionReadinessPreflight`. It runs
  the full readiness chain against a render plan: native capabilities, strict
  render-session preparation, source binding, frame sampling, exact decode
  requests, dual decoder session, temporal accumulator, mirror-edge tiler,
  render-pass graph, output surface, and preview/scrub/playback/export parity.
  A transition authoring UI may only expose a preset when this report has no
  blocking stage; a single successful planning endpoint is not enough.
- Flutter now also has
  `ProfessionalVideoTransitionReadinessPresentationAdapter`. Any transition
  browser, inspector, script assistant, or future AI transition surface must use
  this readiness display model instead of inventing a loose "available" flag.
  Locked UI should name the exact blocked stages so users and agents understand
  why a preset is unavailable without mistaking a partial planning endpoint for
  a renderable transition.
- Flutter and Android now also share `planVideoSourceProbe`. This stage comes
  after concrete source URI binding and before exact frame decode. It must prove
  that both source URIs are real, openable video sources with video tracks
  before a decoder session can be considered professionally ready. Synthetic
  sources, asset-id-only decode, generated proxies, thumbnail fallback, and
  boundary-frame freezing remain forbidden. Android now uses `MediaExtractor`
  against `file://` and `content://` sources for this probe and reports video
  MIME type, dimensions, duration, and frame rate when available. Passing this
  probe only proves source truth; it does not unlock transitions until the dual
  decoder, temporal accumulator, mirror-edge tiler, output surface, and parity
  renderer also report readiness.
- Flutter and Android now share `planFrameSamples` as the next compositor
  foundation. A valid render plan is parsed into the same strict native render
  session, then a requested transition timeline frame is converted into:
  outgoing source time, incoming source time, normalized progress, and temporal
  shutter sample times for both sources. The method rejects frame times outside
  the transition window and still renders nothing. This contract exists so the
  future renderer samples live A/B video across the window instead of falling
  back to frozen frames or ambiguous thumbnails.
- Flutter and Android now also share `planFrameDecodeRequests`. This turns the
  frame-sample plan into explicit exact-video-frame decode requests for both
  source roles. Every request carries source role, clip id, asset id, timeline
  sample time, source sample time, sample index, and center-sample metadata.
  The request contract forbids thumbnail fallback and boundary-frame freeze, so
  a future decoder cannot silently turn a live transition into a still-image
  effect.
- Flutter and Android now also share `planDualVideoDecoderSession`. This groups
  exact outgoing and incoming decode requests into two native decoder tracks,
  preserves sample ids and source asset identity, and now depends on the real
  Android source probe before it can advance. The native manager also performs
  a strict center-sample `MediaCodec` decode probe for each side and reports
  MIME type, dimensions, duration, frame rate, requested source time, decoded
  frame time, and any decode blocker. Thumbnail fallback and boundary-frame
  freezing remain forbidden. This is the first concrete dual-video sampling
  slice; it still does not render a transition until temporal accumulation,
  mirror-edge tiling, output surface, and parity renderer are implemented.
- Flutter and Android now also share `planTemporalSampleAccumulator`. This binds
  the two decoder tracks into outgoing/incoming temporal accumulators with
  deterministic sample weights, exact-frame requirements, and explicit
  `allowGaussianFallback=false` / `allowDecorativeSpeedLines=false`. Current
  responses deliberately keep `accumulatorImplemented=false`, so temporal motion
  blur remains blocked until the native compositor can accumulate real shutter
  samples instead of poster-frame blur or decorative speed-line substitutes.
- Flutter and Android now also share `planMirrorEdgeTiling`. This binds temporal
  accumulator outputs into outgoing/incoming mirror-edge tile plans with
  deterministic overscan, canvas clipping, and explicit
  `allowBlackBorders=false`, `allowFlutterOverlay=false`, and
  `allowTimelineOverlay=false`. Current responses keep `tilerImplemented=false`,
  so zoom/push/camera transitions cannot hide black borders with stretched
  thumbnails, Flutter overlays, or timeline-area drawing.
- Flutter and Android now also share `planRenderPassGraph`. This is not a
  renderer; it is the renderer-agnostic execution graph every concrete native
  transition must satisfy: exact decode, temporal accumulation, optional
  mirror-edge tile, transition shader evaluation, and composition to the output
  transition surface. Current responses deliberately keep
  `rendererImplemented=false`, so this foundation cannot unlock presets or
  playback until a real compositor attaches to the graph.
- Flutter and Android now also share `planOutputSurface`. This binds the pass
  graph to the only acceptable output target for professional transitions: a
  native transition canvas surface clipped to the preview/export canvas. It
  explicitly forbids Flutter overlay drawing, timeline overlay drawing, and
  transformed PlatformView fallback paths, and remains blocked while
  `rendererImplemented=false`.
- Flutter and Android now also share `planParityOutputs`. This is the parity
  contract that prevents "works in preview but not in scrub/play/export"
  drift. Preview, Live Scrub, playback, and export must all point at the same
  native transition output contract, and all four modes remain blocked until a
  concrete native renderer reports that it can render them without fallback
  divergence.

## 9. Stop Conditions

Stop transition implementation immediately if:

- Live Scrub gets slower outside transition windows
- clip trim becomes less reliable
- transition is represented as a fake clip without a durable boundary contract
- preview and export diverge silently
- keyframe/effect work starts leaking into a transition-only state model
- undo/redo cannot represent the transition command

## 10. Definition Of Done For First Transition Release

The first professional transition release is done only when:

- Cross Dissolve is represented as a durable boundary transition
- it previews correctly
- it has duration editing
- it survives trim/undo/redo validation
- export parity is confirmed or explicitly gated
- Live Scrub is unchanged outside transition windows
- transition code does not create a second timeline engine
- documentation is updated with exact supported transitions and known gaps

## 11. Final Rule

Transitions are root timeline boundary effects. Scoped layer animation remains
layer-local. Live Scrub remains protected. If a transition implementation mixes
those three responsibilities, the architecture is drifting and must stop for
review.
