# Professional Composition Workspace And Scene Orchestration Plan

Status: official execution plan  
Package: `com.refusion.app`  
Date: 2026-04-29  
Depends on:

- `docs/professional_checkpoint_policy.md`
- `docs/professional_refusion_motion_keyframe_engine.md`
- `docs/professional_composition_timeline_migration_plan.md`
- `docs/professional_scene_container_and_mention_motion_plan.md`
- `docs/professional_motion_director_engine.md`
- `docs/super_professional_engine_like_after_effects.md`

## 1. Purpose

ReFusion must become a professional mobile composition workspace, not a
single-purpose video inserter and not a preset-only animation toy.

The target workflow is:

```text
Create Project Composition
-> create or insert Scene/Composition Clips
-> open a Scene Clip into its internal layers
-> open any layer into Unified Layer Scope
-> edit real properties, effects, keyframes, and timing
-> preview and export the same graph
```

The user must be able to build manually, generate scenes from scripts, animate
existing elements with `@mentions`, and sequence multiple scenes with
transitions. Every result must be visible, editable, and exportable from the
same canonical motion graph.

## 2. External Product Principles

This plan follows proven professional patterns without embedding or cloning
external apps:

- Lottie Creator: canvas, layer system, keyframe timeline, nested scenes, AI
  assistance, and Lottie-compliant export.
- Rive: hierarchy/outliner, selection-driven inspector, active-artboard
  timeline, parent-child transforms, assets panel, and key editing.
- After Effects: Project panel, compositions, precompositions/nesting,
  composition layers, source composition editing, and contextual Properties
  panel.
- Remotion: declarative `Composition`, `Sequence`, and `Series` timing as a
  deterministic mental model for scenes and scene sequencing.

ReFusion's mobile UI can differ, but the data model must preserve the same
professional separation:

```text
Outliner = hierarchy, ownership, draw order, assets, navigation
Timeline = time, clips, spans, keyframes, transitions
Inspector = selected-object properties, effects, motion controls
Canvas = visual edit and preview
```

Do not collapse these into one vague bottom sheet. The panels can be represented
as mobile sheets/sidebars, but the responsibilities must remain separate.

## 3. Non-Negotiable Rules

### 3.1 Checkpoint Rule

Every completed build step under this plan must follow
`docs/professional_checkpoint_policy.md`.

Required sequence:

```text
implement smallest safe slice
-> verify
-> commit focused files only
-> push checkpoint
-> install on connected Android device when available
-> report branch, commit, files, verification, install, rollback command
```

### 3.2 Live Scrub Protection

This plan must not use workspace/composition work as a reason to weaken Live
Scrub.

Do not touch these protected paths unless the user explicitly approves that
exact Live Scrub change:

- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`
- `Stage5PreviewPlatformView`
- Flutter Live Scrub handoff paths

If a workspace slice appears to require a Live Scrub change, stop and redesign
through a projection, clock, or adapter layer first.

### 3.3 Capability-First, Not Preset-First

Do not solve professional workflow by adding fixed ready-made cards or one-off
scene presets.

Build reusable capabilities:

- composition clips,
- layer types,
- shape/text/image/video/audio insertion,
- null and adjustment layers,
- parent groups,
- inspector properties,
- effects,
- timing contracts,
- transition objects,
- outliner navigation.

Presets may exist only as demos or examples that exercise reusable engine
capabilities. A preset must not be the only way to produce an effect.

### 3.4 Real Graph Or Nothing

No generated, manual, or imported visual motion may be hidden.

Every visible result must lower into:

```text
Composition Source
  Layer
    Element
      Effect Instance
        Property Channel
          Keyframe
```

UI lanes are projections. They are not source of truth.

## 4. Product Workflow Decision

### 4.1 Startup Flow

The first screen should not split the product into `Start from video` versus
`Create composition`.

Approved flow:

```text
Open app
-> Create New Composition
-> Recent Projects
```

`Start from video` becomes a shortcut inside `Create New Composition`:

```text
Create composition
-> optional first action: import video as first layer or first scene
```

This keeps the editor composition-first and prevents the user from being trapped
in a media-only workflow.

### 4.2 Create New Composition

The create sheet must define the root project composition:

- width,
- height,
- aspect preset,
- fps,
- duration,
- background color,
- optional initial empty scene,
- optional import video/image/audio after creation.

Default result:

```text
Root Composition
  Scene Clip 01, empty, duration = selected duration
```

This gives the timeline real content from the first frame, while still letting
the user open the scene and add layers manually.

Implementation note:

- Presets are shortcuts only. They must prefill editable values, not lock the
  user into fixed Story/Square/YouTube/Cinematic choices.
- Manual values must be stored as real project format/frame-rate/duration data
  and must not be overwritten later by preview defaults.
- The selected background color must be visible in the composition preview.
  Export/native render parity for this background is a required follow-up, not
  a reason to hide the value from preview.
- Background starts as project metadata/color in the current implementation,
  but the professional target is an editable root background layer. The create
  flow must eventually let the user choose between an empty Scene Clip over a
  transparent/default canvas, or a root background layer with one or more Scene
  Clips above it.

### 4.3 Root Timeline

The root timeline is for sequencing project-level Scene/Composition Clips.

It may contain:

- editable root background layers,
- scene clips,
- composition clips,
- transition clips between adjacent scenes,
- master audio/music tracks,
- optional root-level overlays when explicitly created.

The root timeline must not explode every generated internal text/shape into
many root tracks. A generated scene appears as one Scene Clip container.

Root composition layering contract:

- A root composition may contain an editable background layer behind Scene or
  Composition Clip instances.
- The root background belongs to the root composition. It is not silently copied
  into every nested Scene Source.
- A Scene Clip is a composition-layer instance. It can be positioned, scaled,
  rotated, faded, cropped/masked where supported, ordered by draw order, and
  receive supported effects without modifying its source scene internals.
- A Scene Clip can fill the whole canvas like a traditional full-screen scene,
  or it can be reduced to a card/window over the root background.
- Multiple Scene Clips may overlap in root time only when represented as
  explicit root composition layers/cards with deterministic draw order. Sequential
  story scenes remain the default behavior.
- This supports workflows such as a single branded background with several
  video or scene cards appearing one after another or simultaneously on top.
- Preview/export must evaluate in this order:

```text
root background layer(s)
-> root Scene Clip instance transform/effects
-> nested source composition render
-> root overlays/transitions
```

The instance/source boundary is strict:

- Scene Clip instance properties belong to the root instance.
- Opening the Scene Clip edits the nested source composition.
- Root instance transforms/effects must not explode source-scene internals onto
  the root timeline.
- Mention Motion must distinguish `@Scene01 instance` from `@Scene01 source`
  when both become addressable.

### 4.4 Scene Scope

Double tapping a Scene Clip opens its source composition.

Inside the Scene Scope, the user sees internal layers:

- video,
- image,
- text,
- shape,
- audio,
- null,
- adjustment layer,
- future camera/light when supported.

Scene Scope time is local to the scene, derived from root composition time. It
must not own a second clock.

Scene Scope layer timing rules:

- Scene Contents has one primary video storyline. Adding a normal Video Layer
  appends it after the last video in that scene and displays all scene videos on
  one video row. Additional free rows are for text, shape, image, audio, null,
  adjustment, and future explicit `Video Overlay` layers, not for the default
  main video sequence;
- dragging a Scene Contents layer clip must be a direct horizontal layer move,
  not a hidden long-press-only action, and must write back to the source
  `MotionLayerModel.visibleRange`, child element timing, and related graph
  channel/keyframe times;
- moving a layer in Scene Scope must not create a detached visual-only clip;
- overlapping video layers are composited by draw order (`zIndex`, then
  insertion order) when projected to preview playback;
- Scene Contents rows must be ordered top-to-bottom by the same draw order used
  for preview (`zIndex`, then insertion order), so the visually higher row is
  the higher-priority layer;
- time hidden under a higher video layer remains real elapsed source time for
  the lower layer. When the lower layer becomes visible later, playback must
  continue from its true source offset instead of restarting from frame zero.
- empty time is real time. If the playhead is on a gap before, between, or
  after Scene Contents media layers, preview must be blank/transparent rather
  than falling back to the previous, next, or first visual asset. Native preview
  transport may use a compact media program internally, but the app must map
  timeline time to media-program time only when the playhead is inside a real
  media interval.
- moving a Scene Contents layer may extend the source composition and owning
  Scene Clip instance when the layer's end exceeds the current scene duration;
  clamping a full-duration layer to start time zero is not acceptable because it
  turns the visible timeline into a fake, immovable representation.

### 4.5 Unified Layer Scope

Double tapping a supported layer opens the Unified Layer Scope timeline for that
layer.

The scope shows:

- layer span,
- property lanes,
- effect lanes,
- keyframes,
- graph/easing,
- value editor,
- move selected key to playhead,
- add/delete key.

This is the only future scope editing surface. Do not create a second special
timeline for transitions or generated scenes.

## 5. Context-Aware Commands

### 5.1 Add Button

`+ Add` must change according to active scope.

Root scope:

- New Scene,
- Insert Existing Composition,
- Import Video As Scene,
- Import Image As Scene,
- Audio,
- Project Asset.

Scene scope:

- Video Layer,
- Image Layer,
- Text Layer,
- Shape Layer,
- Audio Layer,
- Null Layer,
- Adjustment Layer.

Current W3 mobile command split:

- `Media` (`+`) opens only video/image import for the active Scene Scope and
  inserts the selected media as a scene-local layer.
- `Shape` and `Text` are direct bottom-dock layer creation commands.
- `Audio`, `Null`, and `Adjustment` are visible as explicit future layer
  commands so the workflow shape is stable before their engines are wired.
- Scene Scope must show content/navigation tools only. Keyframe docks and
  keyframe move/delete/value/graph controls belong only to Unified Layer Scope
  after an internal layer is opened.

Layer scope:

- Add Property,
- Add Effect,
- Add Keyframe,
- Add Mask where supported.

### 5.2 Scene Button

The Scene button must be selection-aware.

No selected Scene Clip:

```text
Create New Scene at playhead or after selected/root scene
```

Selected Scene Clip:

```text
Modify Scene
Edit Script
Regenerate selected scene
Replace selected scene source with validation
```

This prevents the current ambiguity where the user cannot tell whether Scene
means "insert another scene" or "edit the scene I selected".

### 5.3 Remotion/Mention Motion Button

Mention-driven motion must target the active context.

If the user is inside a scene and writes:

```text
animate @Logo and @Title
```

The prompt context must include only valid, stable entities from that scene or
from explicit parent context. The output is a motion patch against existing
IDs, not a new random scene unless the user asks for one.

## 6. Outliner And Inspector

### 6.1 Outliner

Add a top-left Outliner button. On mobile, it should open a side sheet or tall
sheet rather than consuming permanent screen width.

The outliner must show:

```text
Project
  Assets
  Root Composition
    Background Layers
    Scene Clip instances
  Source Compositions
    Layers
      Elements
        Effects
        Channels
```

Responsibilities:

- navigate compositions,
- select scene clips/layers/elements,
- reveal selected item in timeline,
- rename,
- duplicate,
- delete,
- change draw order where supported,
- inspect broken references,
- show lock/visibility/mute when implemented.

### 6.2 Inspector

The Inspector is selection-driven.

Current W5 foundation:

- `CompositionWorkspaceInspectorAdapter` projects the active workspace selection
  into a read-only inspector model.
- Supported selection targets are root composition, Scene Clip instance, source
  composition, source layer, source element, and keyframe.
- Scene Clip inspection preserves the root instance/source boundary by exposing
  instance timing, source binding, transform, opacity, effects, and draw order
  without exploding nested source layers onto the root timeline.
- Layer, element, and keyframe inspection resolves real graph/channel ownership
  and reports missing targets instead of inventing fake values.
- A mobile read-only Inspector bottom sheet is now wired from the top bar. It
  shows the current selection's projected sections and keeps write-back as a
  future W5 slice.

Root composition selected:

- canvas size,
- fps,
- duration,
- background metadata,
- root background layer controls when present,
- safe-area guides.

Scene Clip selected:

- start,
- duration,
- trim,
- source scene,
- instance transform,
- instance opacity,
- instance crop/mask where supported,
- instance effects,
- draw order,
- transition handles,
- regenerate/modify controls.

Layer selected:

- transform,
- style,
- effects,
- timing,
- parent/null binding,
- visibility/lock.

Keyframe selected:

- time,
- value,
- interpolation,
- easing,
- move/delete/copy.

On mobile, Inspector can be implemented as a bottom sheet with tabs:

```text
Transform | Style | Effects | Timing | Advanced
```

## 7. Transitions Between Scenes

Transitions must become first-class timeline objects between two adjacent Scene
Clips.

Transition data:

- outgoing scene clip ID,
- incoming scene clip ID,
- seam time,
- duration,
- presentation/effect recipe,
- editable property channels,
- optional transition source composition.

Do not bury a transition as hidden keyframes on Scene A or Scene B without a
selectable transition object. The user must be able to select the transition,
open its scope, edit keyframes, and remove it.

## 8. Agent And Script Requirements

### 8.1 Generate Scene From Scratch

The agent may create a complete Scene Program only when the user asks for a new
scene.

Result:

```text
one root Scene Clip
one source composition
internal layers/elements/channels/keyframes
```

The root timeline must show one container, not every internal layer.

### 8.2 Modify Existing Scene

When a Scene Clip is selected, generated changes must target that source scene.

Required behavior:

- preserve stable IDs when modifying existing elements,
- add new layers only when requested,
- delete only when requested,
- report broken/unsupported operations,
- keep every generated keyframe editable.

### 8.3 Animate Existing Elements

Mention Motion must never create unrelated elements unless the prompt asks for
new elements.

It applies motion patches to existing IDs:

```text
@Title.position
@Card.opacity
@Logo.scale
```

## 9. Implementation Phases

### Phase W0: Documentation Lock

Deliverables:

- this plan exists,
- master motion plan links to it,
- composition migration plan links to it,
- `refusion-skills` documents the workspace model for external agents.

Exit criteria:

- documentation checkpoint pushed,
- no app behavior change.

### Phase W1: Composition Workspace Domain

Deliverables:

- `CompositionWorkspaceModel` or equivalent domain projection,
- root composition settings,
- editable root background layer model,
- source composition registry,
- scene clip instances,
- Scene Clip instance visual properties:
  position, scale, rotation, opacity, crop/mask where supported, z-order, and
  supported effects,
- selected scope/selection model,
- insertion target resolver.

Exit criteria:

- tests prove root/source/local time mapping,
- no UI wiring,
- no Stage5/Live Scrub changes.

Implementation status:

- `CompositionWorkspaceModel` is the domain source for root composition,
  reusable source compositions, scene clip instances, active scope, and
  selection.
- `CompositionWorkspaceInsertionTargetResolver` defines the first strict
  contracts for Scene/Add/selection edit intent resolution before UI wiring.
- Guard tests cover root/source/local time mapping, scene clip modification
  targets, layer insertion targets, and missing composition validation.
- Root background as a true layer and Scene Clip instance transforms/effects are
  not implemented yet. They are now part of the W1/W4/W5/W9 contract, not a
  separate side plan.
- W1 root-layering domain foundation is now implemented: `CompositionSceneClip`
  carries instance visual style data for transform, opacity, crop, effects, and
  draw order without modifying its source scene, and
  `CompositionWorkspaceModel` carries root background layer projections with
  time visibility and draw-order sorting.

### Phase W2: Create Composition Startup Flow

Deliverables:

- first screen: Create New Composition and Recent Projects,
- remove separate `Start from video` decision path,
- create root composition with default empty Scene Clip,
- preserve ability to import video after creation.

Exit criteria:

- user can start with empty composition,
- Add remains available,
- video import remains possible,
- no Live Scrub regression for video projects.

Implementation status:

- Startup is composition-first: `Start from Video` is no longer a separate
  first-screen decision.
- Create Composition now creates a root composition plus an empty default
  source composition.
- The root timeline receives one real empty Scene Clip container immediately,
  so the project starts with editable composition structure instead of a blank
  media-only state.
- Timeline rows now carry explicit visual kinds, so root Scene Clips render as
  composition containers while Scene Scope layers can render text/image/shape
  icons according to their actual layer type.

### Phase W3: Universal Add Sheet

Deliverables:

- context-aware add menu,
- root insert actions,
- root background create/replace actions,
- root Scene/Composition Clip as card/window actions,
- scene layer insert actions,
- layer-scope property/effect actions,
- explicit unsupported blockers.

Exit criteria:

- can manually build a scene from text/shape/image/video,
- inserted layers are real graph layers,
- out-of-scope insertion is rejected clearly.

Implementation status:

- First UI slice completed: the bottom-dock `Add` action now opens a
  context-aware sheet for root composition, Scene Scope, and Layer Scope
  contexts instead of jumping straight to video/image media import.
- Root composition can create a real empty `Scene NN` composition clip appended
  after the current scene sequence.
- Scene Scope can create a real text layer inside the open source composition.
  Text authoring now has an explicit `reuseExistingLayer` contract so scene
  insertion can create a new layer instead of silently merging into the first
  text layer.
- Scene Scope can create a real generated shape layer with editable transform,
  opacity, size, and corner-radius assignments. This is a graph layer, not a
  UI-only placeholder.
- Scene Contents keeps media insertion separate from element commands. The
  `Media`/plus action opens only Video Layer and Image Layer import for the open
  source scene. Shape and Text remain direct bottom-dock commands, while
  Audio/Null/Adjustment remain visible planned dock commands and must not create
  fake UI-only layers.
- Scene Contents media import now treats image and video gallery permissions as
  type-specific access. Image permission must not satisfy video import, and
  partial visual access is remembered per media tab after the user grants it.
- Scene Contents media playback projection now adapts nested video/image layers
  into real preview/scrub media tracks for the currently open Scene Scope and
  for root Scene Clip playback. This preserves the root timeline as one Scene
  Clip container while still giving the native preview and Live Scrub catalog a
  truthful media segment list. Stage5/Live Scrub internals remain untouched.
- Scene Contents layer clips can be time-shifted on the scoped timeline. The
  operation writes the new time into the source motion graph and reprojects
  preview/scrub transport; it is not a UI-only drag.
- When nested video layers overlap, the playback projection must flatten them
  into visible intervals by draw order so the hidden portion of a lower video is
  not replayed after the upper video ends.
- Scene Contents video insertion preserves the selected asset's natural
  duration. If the inserted video extends beyond the current source Scene Clip,
  the source composition and root Scene Clip instance must extend together and
  later sequential Scene Clips must shift forward instead of truncating the
  imported video to the generic text/shape default.
- Scene Contents media timing uses two separate clocks: authored
  composition/source time and compact native media-program time. Native duration
  is transport-internal only and must never replace the visible timeline
  duration of a composition, source scene, Scene Clip, or scoped layer timeline.
- `MotionLayerModel.visibleRange` owns source-scene placement. Newly inserted
  media elements should use layer-local `localRange` values, normally
  `0..layer.duration`, so moving a layer does not double-offset the element.
  Legacy scene-absolute element ranges may be read for compatibility, but new
  authoring must prefer layer-local ranges.
- Scene Contents native preview/scrub uses scene-local transport time while the
  professional timeline clock remains in root time. Adapter code must map
  `root <-> scene local` at the native transport boundary; Stage5 scrub files
  remain protected and must not be changed for this workflow.
- Scene Contents and nested Layer Scope must share the root timeline's native
  scrub handoff whenever the open composition scope contains playable video.
  Scoped scrub code must not immediately confirm `scrubSettled` after finger
  lift while a native video player is active; it must wait for the native
  transport to settle on the mapped scene-local target frame first.
- Empty Scene Contents time is real. If the playhead is on a gap before,
  between, or after media layers, preview must show the composition background
  and authored overlays instead of seeking native playback to the previous,
  next, or first video. Native transport may stay compact internally, but the UI
  must map into it only while the playhead is inside a real media interval.
- Project composition aspect is authoritative after composition creation.
  Imported media metadata and native rendered video dimensions must not flip,
  resize, or relock the canvas format.
- Future W3 root actions must allow adding/replacing a root background layer and
  inserting Scene Clips as full-screen scenes or as transformable cards over the
  root background.

### Phase W4: Outliner

Deliverables:

- mobile outliner sheet, implemented for inspect/select navigation,
- project/assets/compositions/layers tree, implemented as projection-backed UI,
- root background layers under Root Composition, visible in the tree,
- Scene Clip instances shown as root composition layers with draw order, visible
  in the tree,
- selection sync with timeline/canvas, partially implemented for selecting root
  Scene Clips and opening source composition/layer context from the tree,
- rename/delete/duplicate where safe.

Exit criteria:

- selected outliner item matches timeline selection,
- double tap/navigation remains stable,
- no hidden duplicate source truth.

### Phase W5: Inspector

Deliverables:

- selection-driven inspector projection, implemented as
  `CompositionWorkspaceInspectorAdapter`,
- selection-driven inspector sheet,
- transform/style/effects/timing tabs,
- root background layer controls,
- Scene Clip instance transform/opacity/crop/effects/draw-order controls,
- property changes write graph channels or static graph values,
- key buttons beside animatable properties.

Exit criteria:

- selecting a text/shape/image layer shows relevant controls,
- setting a value updates preview,
- keying a value creates editable keyframes.

Current status:

- Inspector projection foundation is complete and covered by
  `test/composition_workspace_inspector_adapter_test.dart`.
- Mobile read-only sheet wiring is complete. Visual property editors, key
  buttons, and graph/static value write-back are still open.

### Phase W6: Scene Create/Modify Flow

Deliverables:

- Scene button selection semantics,
- create new scene at playhead/after selection,
- modify selected scene script,
- replace selected scene safely,
- keep stable IDs for modified scenes where possible.

Exit criteria:

- second scene can be inserted after first scene,
- selected scene can be edited without creating unwanted extra clips,
- gaps/overlaps are explicit.

Implementation status:

- Root composition `Add > New Scene` now respects the selected Scene Clip as
  the insertion anchor. The new empty Scene Clip is inserted immediately after
  the selected clip, and later sequential Scene Clips are shifted forward by the
  new clip duration so the story sequence remains non-overlapping. With no
  selected Scene Clip, New Scene still appends at the end of the current scene
  sequence.

### Phase W7: Scene Transition Objects

Deliverables:

- selectable transition clip between scenes,
- transition add/remove UI,
- transition scope opens in Unified Layer Scope mode,
- transition recipes write graph channels.

Exit criteria:

- two scene clips can be connected by a real transition object,
- transition keyframes are visible/editable,
- preview/export blockers are explicit.

### Phase W8: Agent Context Integration

Deliverables:

- scene generate prompt includes active workspace context,
- modify prompt includes selected scene source and stable IDs,
- mention prompt includes active outliner entities,
- skills repo documents root/scene/layer scope rules.

Exit criteria:

- agents can reliably create first scene, create second scene, or modify the
  selected scene without ambiguity.

### Phase W9: Preview And Export Parity

Deliverables:

- root scene clip renderer evaluates nested source compositions,
- root background layer renderer,
- Scene Clip instance transform/effect renderer,
- scene-only canvas preview/export parity gates,
- image/shape/text/video/audio layer export paths,
- transition export parity.

Exit criteria:

- accepted visual content appears in export,
- unsupported effects block export with clear reason,
- preview and export evaluate the same graph.

## 10. Acceptance Matrix

Every behavior phase must validate the relevant subset:

- create empty composition,
- add video layer,
- add image layer,
- add text layer,
- add shape layer,
- add second scene after first scene,
- double tap root scene into scene scope,
- double tap layer into layer scope,
- add/move/value/delete keyframes,
- return from scopes without losing time,
- Live Scrub remains stable on video projects,
- scene-only scrub/play remains stable,
- selected scene modify does not create extra scene,
- transition can be selected and removed,
- preview/export blockers are explicit.

## 11. Rejection Criteria

Reject or revert a slice if:

- Live Scrub regresses,
- root timeline shows generated internals instead of one scene container,
- Add creates fake UI without graph layers,
- Scene button creates new clips while a selected scene should be modified,
- scope time becomes independent from composition time,
- keyframes are hidden or uneditable,
- outliner selection disagrees with timeline selection,
- preview accepts content that export silently drops,
- agent-generated scenes cannot be opened and edited.

## 12. Current Known Code Gaps

Current code already has useful foundations:

- `CompositionSceneClipModel`,
- `SceneProgramApplyTransaction`,
- `RootSceneClipProjectionAdapter`,
- `RootCompositionLayerProjectionAdapter`,
- `CompositionWorkspaceOutlinerAdapter`,
- `SceneScopeSessionResolver`,
- Scene Layer Scope projection and keyframe operations,
- Mention Motion patch import/apply path,
- Director Plan timing gates.

Current gaps for this plan:

- startup still exposes a media-oriented path,
- create composition does not create an editable default Scene Clip by default,
- Add is not a full layer insertion system,
- the project/composition/layer outliner projection exists, but the mobile
  outliner sheet is not wired to production UI yet,
- no formal selection-driven inspector,
- root background and Scene Clip instance visual projections are not wired to
  production outliner, canvas preview, inspector, or export yet,
- Scene button does not fully separate create-new from modify-selected,
- transition between Scene Clips is not yet a first-class workspace object,
- video layers inside Scene Contents can open Layer Scope and author shared
  visual graph properties; Flutter preview now wraps the native video surface
  with graph-evaluated transform/opacity/blur samples, while full production
  export parity for authored video surfaces still needs explicit renderer work,
- the export contract now carries authored video surface nodes with their
  source asset identity and graph channels, and `SceneExportParityGate` reports
  exact authored visual kinds (`videoClip`, `image`, `shape`, `mask`) in
  blockers instead of a generic shape/image message,
- preview/export parity for scene-only generated visual content is still gated,
  with nested media preview/scrub projection now partially wired for manual
  Scene Contents media layers,
- true empty visual gaps between playable video intervals still need full
  renderer/export parity; overlapping nested video timing is now projected as
  visible source intervals instead of replaying hidden source time.

## 13. Practical Rule

When uncertain, choose the professional workspace model:

```text
Composition first.
Scenes are clips.
Scene internals are layers.
Layer motion is graph keyframes.
Outliner navigates hierarchy.
Timeline owns time.
Inspector edits selected properties.
Scripts and agents author real data only.
Checkpoint after every slice.
Protect Live Scrub.
```
