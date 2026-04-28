# Professional Scene Container And Mention Motion Plan

Status: official execution plan  
Package: `com.refusion.app`  
Date: 2026-04-28  
Depends on:

- `docs/professional_checkpoint_policy.md`
- `docs/professional_refusion_motion_keyframe_engine.md`
- `docs/professional_composition_timeline_migration_plan.md`
- `docs/professional_agent_scene_program_engine.md`

## Execution Status

- Phase S1 foundation: `CompositionSceneClipModel` defines the root-timeline
  Scene Clip container contract, source-scene binding, stable clip IDs,
  root/source/local time mapping, source reuse, and validation. This is
  domain-only infrastructure; it is not wired to UI, preview, export, or Live
  Scrub.
- Phase S2 foundation: `SceneProgramApplyTransaction` converts a valid
  ReFusion Scene Program authoring result into one root `Scene Clip` plus one
  nested source scene. It preserves internal layers/channels/text bindings under
  a source-scene namespace and keeps the root scene from exploding into many
  generated tracks. This is domain-only infrastructure; it is not wired to UI,
  preview, export, or Live Scrub.
- Phase S3 foundation: `RootSceneClipProjectionAdapter` projects
  `CompositionSceneClipModel` instances into one root scene timeline track with
  one clip per generated scene, preserves root-time gaps, rejects overlaps, and
  does not expose internal layers on the root timeline. This is projection
  infrastructure; it is not wired to production UI, preview, export, or Live
  Scrub yet.
- Phase S3 UI wiring: Scene Program import now applies through
  `SceneProgramApplyTransaction` and `RootSceneClipProjectionAdapter`, so the
  root timeline receives one Scene Clip container instead of many generated
  text/shape fragments. The nested source scene, channels, and text animation
  bindings are preserved for future Scene Scope editing. This checkpoint does
  not modify preview/export semantics, Scene Scope opening, or Live Scrub.
- Phase S4 foundation: `SceneScopeSessionResolver` and `ScopeStack` define how
  a root Scene Clip opens into a nested Scene Scope with root/source/local time
  mapping and projected internal layers/elements/channels. This is domain-only
  navigation infrastructure; it is not wired to production UI, preview, export,
  or Live Scrub yet.
- Phase S4 UI wiring: double tapping a root Scene Clip now opens a Scene Scope
  timeline view that projects the nested source scene layers as local tracks and
  provides a back action to return to the root timeline. This checkpoint keeps
  element-level editing, native Scene Scope scrub, and export nesting for later
  phases, and does not modify Stage5 Live Scrub.
- Phase S5 foundation: double tapping a supported internal Scene Scope layer
  opens a Unified Layer Scope style timeline for that layer. The scope projects
  graph channels/keyframes into timeline lanes with correct scene/source/local
  time mapping while preserving the root Scene Clip container. Keyframe mutation
  from this nested scope remains a future checkpoint, and Stage5 Live Scrub is
  untouched.
- Phase S5 keyframe drag wiring: existing keyframes in Scene Layer Scope can be
  dragged on the timeline. The edit flows through `LayerScopeCompositionAdapter`
  and is merged back into source-scene graph time. Add/value/delete/graph
  controls remain future checkpoints, and Stage5 Live Scrub is untouched.
- Phase S5 keyframe add wiring: the Key button in Scene Layer Scope can add a
  new keyframe to the selected animation row at the current scoped playhead time.
  The edit uses the same `LayerScopeCompositionAdapter` graph path as drag.
  Value/delete/graph controls remain future checkpoints, and Stage5 Live Scrub
  is untouched.
- Phase S5 keyframe value wiring: the Value button in Scene Layer Scope can edit
  selected scalar/integer/boolean graph keyframe values and merge them back into
  source-scene time through `LayerScopeCompositionAdapter`. Delete/graph controls
  and nested export semantics remain future checkpoints, and Stage5 Live Scrub is
  untouched.
- Phase S5 keyframe tool wiring: Scene Layer Scope now shows a focused keyframe
  toolbar instead of disabled clip-edit tools. Selected graph keyframes can move
  to the current playhead or be deleted through `LayerScopeCompositionAdapter`.
  Nested export semantics remain future checkpoints, and Stage5 Live Scrub is
  untouched.
- Phase S5 graph/ease wiring: the Graph button in Scene Layer Scope can apply or
  remove Easy Ease interpolation on the selected graph keyframe through
  `LayerScopeCompositionAdapter`. Nested export semantics remain future
  checkpoints, and Stage5 Live Scrub is untouched.
- Phase S6 foundation: `SceneMentionIndex` builds the stable `@mention`
  entity list for a scene. It indexes Scene Clip containers and animatable
  scene elements, preserves stable IDs across renames, exposes supported motion
  properties, disambiguates duplicate display names, and treats deleted
  elements as invalid mentions on the rebuilt index. This is domain-only
  infrastructure for future prompt/autocomplete UI and does not touch Stage5 or
  Live Scrub.
- Phase S7 foundation: Scene Program import now includes a Mention Motion Prompt
  panel. Typing `@` shows current scope entities, selecting a suggestion inserts
  a stable mention chip, and `SceneMentionPromptContextBuilder` produces a
  resolved prompt payload with broken mention diagnostics. This checkpoint does
  not call an API, mutate graph data, or touch Stage5/Live Scrub.
- Performance watch note: if repeated keyframe drag/edit or repeated scene
  script edits show intermittent heaviness on real devices, capture it as a
  profiling task after the mutation surface is complete. Do not treat Live Scrub
  as the tuning knob for that issue.

## 1. Final Product Goal

ReFusion must support two professional agent-assisted motion workflows without
creating hidden, fake, or uneditable animation.

```text
Workflow A: Generate Scene From Scratch
User prompt or pasted JSON
-> Agent creates a complete ReFusion Scene Program
-> App validates it
-> App creates a real Scene/Composition container
-> Main timeline shows one Scene Clip
-> Double tap opens the generated layers and elements
-> Double tap an element opens its editable keyframes
-> Preview and export evaluate the same graph

Workflow B: Animate Existing Elements With @mentions
User creates/uploads assets manually inside a Scene/Composition
-> User writes a prompt with @mentions for existing elements
-> App resolves mentions to stable graph IDs
-> Agent returns a Motion Patch targeting those IDs
-> App validates and applies channels/keyframes to existing elements
-> User edits the real keyframes in the same Scope Timeline
-> Preview and export evaluate the same graph
```

Both workflows must end in the same canonical motion graph:

```text
Composition
  Scene/Composition Clip
    Layer
      Element
        Effect Instance
          Property Channel
            Keyframe
            Interpolation
```

The prompt is only an authoring interface. The graph is the truth.

## 2. Non-Negotiable Safety Rules

### 2.1 Live Scrub Protection

Live Scrub is protected production infrastructure.

This plan must not modify or weaken:

- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`
- `Stage5PreviewPlatformView`
- Flutter Live Scrub handoff paths

If any phase appears to require touching Live Scrub, stop and redesign through a
projection/adapter layer first.

Acceptance for every UI-facing phase:

- existing video Live Scrub remains fast;
- composition-only scrub remains stable;
- slow scrub remains frame-accurate;
- reverse scrub does not jump;
- zoomed timeline scrub does not regress.

### 2.2 Checkpoint Rule

Every completed implementation slice must follow:

```text
implement smallest safe slice
-> run targeted verification
-> commit only related files
-> push checkpoint to GitHub
-> install on connected Android device when available
-> report branch, commit, verification, install, rollback
```

Rollback note format:

```bash
git revert <commit-hash>
```

No large multi-feature batch may be pushed without intermediate checkpoints.

### 2.3 No Private Motion Engines

No feature may keep permanent motion data outside the canonical graph.

Forbidden:

- hidden script-only animation;
- visual-only UI tracks that cannot be edited;
- JSON that executes code;
- agent output that describes motion in prose only;
- duplicated keyframe storage;
- preview-only effects without export blockers or parity.

Allowed:

- declarative JSON;
- graph patches;
- validated presets;
- generated layers/elements/channels/keyframes;
- preview/export blockers for unsupported operations.

## 3. Architectural Decision

ReFusion will use a composition/precomposition-style model.

The main timeline must stay clean and high-level:

```text
Root/Main Composition Timeline
  Video Clip
  Scene Clip: "Intro Prompt Bar"       0s -> 7s
  Scene Clip: "Offer Reveal"           7s -> 12s
```

The generated scene must not explode into many unrelated clips on the main
timeline. It appears as one `Scene Clip` / `Composition Clip`.

Opening the Scene Clip reveals its internal composition:

```text
Scene Scope: Intro Prompt Bar
  Background Shape Layer          0s -> 7s
  Input Bar Shape Layer           0s -> 7s
  Attach Icon Shape Layer         0.3s -> 7s
  Text Layer "Hello World"        2.0s -> 5s
  Send Button Shape Layer         4.8s -> 7s
```

Opening an internal element reveals its editable motion:

```text
Layer Scope: Text Layer "Hello World"
  position.x keyframes
  position.y keyframes
  opacity keyframes
  typewriterProgress keyframes
  blur keyframes
  scale keyframes
```

The same timeline engine, clock, geometry mapper, and keyframe operation layer
must be used at every level. Scopes are projections, not separate timelines.

## 4. UX Contract

### 4.1 Starting A Project

The app can start from:

```text
Create Composition
Start From Video
```

Create Composition creates an empty root composition with chosen format:

- story / 9:16;
- square / 1:1;
- landscape / 16:9;
- custom size later.

Start From Video imports video as media on the root timeline.

Both paths must support:

- play;
- pause;
- scrub;
- zoom;
- add scene;
- export.

### 4.2 Generate Scene From Scratch

From the root composition:

```text
Bottom Dock -> Scene / Generate Scene
```

The user may:

- paste a ReFusion Scene Program JSON;
- upload a JSON file;
- type a prompt for an agent;
- choose a preset scene template.

When applied:

- main timeline receives one Scene Clip;
- the Scene Clip has name, duration, thumbnail/summary, and source scene ID;
- internal layers are not shown on the root timeline by default;
- double tap opens Scene Scope.

### 4.3 Manual Scene Building

Inside a Scene Scope, the user can manually add:

- text;
- shape;
- image;
- icon;
- video/media layer later;
- audio later;
- generated/remote asset later.

Each element gets:

- stable ID;
- human name;
- type;
- layer range;
- source binding;
- editable property channels.

The user can rename elements to make them easy to mention:

```text
Logo
Product Image
Headline
CTA Button
Prompt Bar
```

### 4.4 Animate Existing Elements With @mentions

Inside a Scene Scope or Layer Scope:

```text
Generate Motion
```

The prompt input supports `@`.

When the user types `@`, autocomplete lists valid elements in the current scope:

```text
@Logo            shape / image
@Headline        text
@ProductImage    image
@PromptBar       shape
```

Selecting an item creates a mention chip:

```json
{
  "display": "@Logo",
  "entityId": "element_logo_123",
  "entityType": "element",
  "scopeId": "scene_intro"
}
```

The agent receives both prompt text and resolved IDs:

```json
{
  "mode": "animate_existing",
  "prompt": "Move @Logo from left to center, then make @Headline type on.",
  "mentions": [
    {
      "display": "@Logo",
      "entityId": "element_logo_123",
      "entityType": "element"
    },
    {
      "display": "@Headline",
      "entityId": "element_headline_456",
      "entityType": "element"
    }
  ],
  "scope": {
    "compositionId": "root_comp",
    "sceneId": "scene_intro"
  }
}
```

The returned patch must target real IDs:

```json
{
  "schemaVersion": "refusion.motion-patch/v1",
  "operation": "update_existing_scene",
  "scope": {
    "sceneId": "scene_intro"
  },
  "actions": [
    {
      "type": "animate",
      "targetId": "element_logo_123",
      "channels": [
        {
          "property": "position",
          "keyframes": [
            { "timeMs": 0, "value": { "x": -420, "y": 0 } },
            { "timeMs": 900, "value": { "x": 0, "y": 0 }, "easing": "easeOut" }
          ]
        }
      ]
    }
  ]
}
```

The patch is rejected if:

- target ID does not exist;
- target is outside allowed scope;
- property is unsupported for that element type;
- keyframe values do not match the property type;
- keyframe time is outside the target scope;
- it tries to execute code;
- it creates an uneditable runtime-only animation.

## 5. Data Model Requirements

### 5.1 Scene Clip

A root timeline Scene Clip must represent a nested composition instance.

Required fields:

```text
id
sourceSceneId
name
startTime
duration
sourceIn
sourceOut
timeScale
thumbnail/summary
enabled
locked
metadata
```

It is an instance. Later, multiple Scene Clips may reference the same source
scene with different start times or transforms.

### 5.2 Scene Source

A Scene Source is the editable nested composition.

Required fields:

```text
id
name
duration
frameRate/timebase
canvasSize
layers
metadata
```

### 5.3 Layer

Required fields:

```text
id
sceneId
name
kind
visibleRange
zIndex
blendMode
elements
effects
metadata
```

### 5.4 Element

Required fields:

```text
id
layerId
kind: text | shape | image | icon | video | solid
name
localRange
sourceBinding
staticProperties
propertyChannels
metadata
```

### 5.5 Mention Entity

Mentions are generated from real graph objects.

Required fields:

```text
displayName
entityId
entityType
sceneId
layerId?
elementId?
kind
thumbnail?
isSelectable
isAnimatable
supportedProperties
```

The mention display name may change; the `entityId` must remain stable.

### 5.6 Motion Patch

Motion Patch is for modifying existing graph data.

It must not replace Scene Program. It complements it.

```text
Scene Program = create a new scene or full content block
Motion Patch = modify existing scene/layers/elements/channels
```

## 6. Preview And Export Contract

Every accepted generated scene or motion patch must be exportable.

Rules:

- Preview uses normalized composition graph.
- Export uses the same normalized graph.
- Unsupported effects produce blockers, not silent omissions.
- Text, shape, image, opacity, transform, blur, typewriter, and color animation
  must each have preview/export parity before marked production-ready.
- Scene Clip nesting must be represented in export as nested timeline
  evaluation, not as UI-only grouping.

Accepted operation states:

```text
supported_preview_and_export
supported_preview_only_with_export_blocker
rejected_unsupported
```

No operation may be silently accepted if export ignores it.

## 7. Execution Plan

### Phase S0: Documentation And Baseline Freeze

Purpose:

- make this plan official;
- explicitly protect Live Scrub;
- define both agent workflows;
- define Scene Clip and Motion Patch direction.

Deliverables:

- this document;
- links from master motion docs;
- no behavior change.

Verification:

```bash
rg "professional_scene_container_and_mention_motion_plan" docs
git diff --check
```

User inspection:

- plan review only.

### Phase S1: Scene Clip Domain Model

Purpose:

- introduce root timeline representation for nested scene clips without UI
  behavior change.

Deliverables:

- domain model for `SceneClip` or composition instance;
- stable IDs;
- time mapping fields;
- tests for:
  - root time to scene local time;
  - scene local time to root time;
  - clip duration and source range;
  - multiple instances referencing same scene source.

Rules:

- no UI wiring;
- no Live Scrub changes.

Verification:

```bash
flutter test test/scene_clip_*_test.dart
```

User inspection:

- not required.

### Phase S2: Scene Container Apply Transaction

Purpose:

- change Scene Program application from “merge layers directly into main scene”
  to “create a Scene Source plus root Scene Clip”.

Deliverables:

- `SceneProgramApplyTransaction` domain service;
- creates/updates:
  - root Scene Clip;
  - nested Scene Source;
  - channels;
  - text bindings;
  - metadata;
- preserves imported graph without losing layers.

Exit criteria:

- pasted Scene Program creates one root scene clip in data;
- internal layers remain available through projections;
- existing direct-layer import path remains behind compatibility flag if needed.

Verification:

```bash
flutter test test/refusion_scene_program_*_test.dart test/scene_program_apply_transaction_test.dart
```

User inspection:

- not yet, unless UI flag is enabled.

### Phase S3: Root Timeline Scene Clip Projection

Purpose:

- show generated scenes as one clip on the main timeline.

Deliverables:

- root timeline projection adapter from Scene Clip to `TimelineClipData`;
- clip type/category for scene/composition;
- visual label and duration;
- selection support;
- no internal layers shown at root level by default.

Exit criteria:

- after apply, root timeline shows one Scene Clip;
- playhead duration matches Scene Clip duration;
- root timeline does not show extra text-only fragments;
- existing video timeline remains unchanged.

Verification:

```bash
flutter analyze
flutter build apk --debug
```

User inspection:

- create composition;
- import sample scene;
- confirm one Scene Clip appears;
- playback displays full generated scene.

### Phase S4: Scene Scope Session

Purpose:

- double tap Scene Clip opens nested Scene Scope.

Deliverables:

- `ScopeStack`;
- `SceneScopeSession`;
- root-to-scene time mapping;
- back navigation;
- scene-local ruler/duration;
- internal layer projection.

Exit criteria:

- double tap root Scene Clip opens Scene Scope;
- internal text/shape/image layers appear at correct local times;
- back returns to root timeline with same root playhead relation;
- no separate timeline clock is created.

Verification:

```bash
flutter test test/composition_timeline_projection_test.dart
flutter analyze
flutter build apk --debug
```

User inspection:

- import scene;
- double tap Scene Clip;
- confirm internal layers appear with correct timing.

### Phase S5: Unified Element Scope For Text, Shape, Image

Purpose:

- make double tap on an internal element open the existing unified layer scope.

Deliverables:

- element hit-test/selection for text, shape, image;
- layer/element scope session;
- keyframe lane projection for selected element;
- value editor and graph editor use existing unified keyframe operations.

Exit criteria:

- text typewriter keyframes visible and editable;
- shape position/scale/opacity keyframes visible and editable;
- image transform keyframes visible and editable;
- moving keyframes changes real preview.

Verification:

```bash
flutter test test/layer_scope_composition_adapter_test.dart test/unified_scope_timeline_projection_adapter_test.dart
flutter analyze
flutter build apk --debug
```

User inspection:

- open generated scene;
- double tap a text/shape/image;
- move a keyframe;
- confirm preview changes.

### Phase S6: Mention Entity Index

Purpose:

- create a reliable list of animatable targets for `@mentions`.

Deliverables:

- `SceneMentionIndex` or equivalent service;
- indexes current scope elements and clips;
- produces stable mention entities;
- supports names, types, thumbnails, supported properties;
- detects duplicate display names and disambiguates.

Exit criteria:

- given a scene, service returns mentionable elements;
- renaming changes display label but not ID;
- deleted elements produce invalid mention state.

Verification:

```bash
flutter test test/scene_mention_index_test.dart
```

User inspection:

- not required yet.

### Phase S7: Mention Prompt UI

Purpose:

- add modern prompt input with `@` autocomplete in Scene Scope.

Deliverables:

- prompt field;
- mention autocomplete;
- mention chips;
- context payload builder;
- no API call yet required.

Exit criteria:

- typing `@` shows current scene elements;
- selecting an item inserts a chip;
- generated request payload contains resolved IDs;
- broken mentions are visible.

Verification:

```bash
flutter analyze
flutter build apk --debug
```

User inspection:

- create scene with text/shape/image;
- type `@`;
- confirm autocomplete shows real elements.

### Phase S8: Motion Patch Schema And Validator

Purpose:

- define patch format for animating existing elements.

Deliverables:

- `ReFusionMotionPatch` model;
- validator;
- property resolver;
- target resolver;
- no graph mutation until validation succeeds.

Rules:

- reject unknown targets;
- reject unsupported property/type combinations;
- reject time outside scope unless explicit extension is allowed;
- reject executable code;
- reject hidden runtime-only operations.

Verification:

```bash
flutter test test/refusion_motion_patch_import_service_test.dart
```

User inspection:

- not required.

### Phase S9: Motion Patch Applicator

Purpose:

- apply validated patch to existing graph channels.

Deliverables:

- `MotionPatchApplicator`;
- updates/creates `MotionPropertyChannelModel`;
- uses `UnifiedKeyframeOperations` where possible;
- preserves stable keyframe identities;
- creates text animation bindings for typewriter/reveal patches when needed.

Exit criteria:

- patch can animate existing text;
- patch can animate existing shape;
- patch can animate existing image once image graph target exists;
- no duplicate element creation unless action explicitly says create.

Verification:

```bash
flutter test test/refusion_motion_patch_applicator_test.dart test/unified_keyframe_operations_test.dart
```

User inspection:

- not required until UI/API wiring.

### Phase S10: Local Prompt-To-Patch Test Mode

Purpose:

- test the full B workflow without remote API risk.

Deliverables:

- paste Motion Patch JSON into Generate Motion sheet;
- apply to mentioned existing elements;
- show changes in Scene Scope and Layer Scope.

Exit criteria:

- user creates/imports elements manually;
- user applies patch targeting their IDs;
- preview changes;
- keyframes are visible and editable.

Verification:

```bash
flutter analyze
flutter build apk --debug
```

User inspection:

- required.

### Phase S11: Agent API Integration

Purpose:

- connect prompt/mentions to remote agent provider.

Deliverables:

- provider-agnostic request interface;
- sends prompt context, mention entities, schema docs, constraints;
- receives Scene Program or Motion Patch JSON;
- validation before application;
- human-readable error display.

Rules:

- remote agent never writes directly to graph;
- app applies only validated JSON;
- API failures do not corrupt current scene;
- user can preview changes before commit later.

Verification:

```bash
flutter analyze
flutter build apk --debug
```

User inspection:

- generate simple scene from prompt;
- animate existing `@mentions`;
- confirm editable keyframes.

### Phase S12: Export Parity Gate

Purpose:

- make generated scenes and mention patches production safe.

Deliverables:

- export consumes Scene Clips and nested Scene Sources;
- export consumes Motion Patch-created channels;
- unsupported operations produce blockers;
- parity tests for supported operations.

Minimum supported export set:

- text;
- shape;
- image;
- opacity;
- position;
- scale;
- rotation;
- blur when accepted;
- typewriter/reveal;
- color/fill where accepted.

Exit criteria:

- exported video matches preview for supported scene programs;
- unsupported effect is blocked before export, not silently dropped.

Verification:

```bash
flutter test test/export_*_test.dart
flutter analyze
flutter build apk --debug
```

User inspection:

- export generated scene;
- compare preview/export visually.

## 8. Implementation Ordering

The safest order is:

```text
S0 document plan
S1 domain scene clip model
S2 apply transaction creates nested scene source
S3 root timeline shows one scene clip
S4 double tap opens scene scope
S5 double tap internal element opens unified layer scope
S6 mention index
S7 mention prompt UI
S8 patch validator
S9 patch applicator
S10 local patch UI test mode
S11 agent API integration
S12 export parity
```

Do not start API integration before:

- Scene Clip container exists;
- Scene Scope exists;
- at least text/shape keyframes are visible and editable;
- mentions resolve to real IDs;
- patch validator exists.

## 9. What The User Should Test After Each Visible Phase

### After S3

- Import a generated scene.
- Confirm the root timeline shows one Scene Clip.
- Confirm playback shows all generated content.
- Confirm no extra random text-only fragments appear on the root timeline.

### After S4

- Double tap the Scene Clip.
- Confirm internal layers appear.
- Confirm local timeline begins at 0 and ends at scene duration.
- Confirm Back returns to root timeline.

### After S5

- Double tap a text/shape/image layer.
- Confirm keyframes appear.
- Move a keyframe.
- Confirm preview changes.

### After S7

- Type `@` in Generate Motion.
- Confirm autocomplete lists real elements.
- Rename an element and confirm mention display updates but still targets same
  object.

### After S10

- Create/upload elements manually.
- Apply a patch to `@Logo` and `@Title`.
- Confirm only those elements move.
- Confirm generated keyframes are editable.

### After S12

- Export a generated scene.
- Confirm preview and exported video match for accepted effects.

## 10. Current Code Gap Summary

Current system already has:

- Scene Program validation;
- Scene Program lowering;
- Motion graph models;
- composition projection foundation;
- unified keyframe operations foundation;
- text-focused timeline projection;
- shape preview overlay;
- import sheet.

Current system still lacks:

- Scene Clip / Composition Clip type on root timeline;
- Scene Scope UI as nested composition view;
- production wiring for shape/image selection and keyframe scope;
- mention index/resolver;
- motion patch schema for existing elements;
- patch applicator;
- export parity for nested Scene Clips and all accepted effects.

## 11. Acceptance Definition

This system is not complete until all of these are true:

- a generated scene appears as one Scene Clip on the root timeline;
- double tap opens the exact generated layers;
- each generated layer can open its own keyframe scope;
- manually added assets can be mentioned with `@`;
- agent motion patches target real IDs;
- invalid targets are rejected;
- keyframes are visible and editable;
- preview and export use the same graph;
- Live Scrub remains stable;
- every phase has a GitHub checkpoint and rollback command.

## 12. External Reference Principles

This plan follows these professional references conceptually:

- After Effects precompositions/nested compositions: generated or grouped
  layers can appear as one composition layer while remaining editable inside.
- Remotion compositions/sequences: a composition has duration, fps, canvas size,
  and nested/local timing; interpolation and spring-like primitives map time to
  values deterministically.

ReFusion must not embed After Effects or Remotion. It must implement the same
professional ideas inside its own editable Flutter/native motion graph.
