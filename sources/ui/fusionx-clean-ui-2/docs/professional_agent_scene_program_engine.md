# Professional Agent Scene Program Engine

Status: official execution plan
Package: `com.refusion.app`
Scope: agent-authored motion graphics, declarative scene programs, scene lowering, editable composition graph, preview parity, export parity

## 0. Mandatory Policies

This plan is governed by:

- `docs/professional_checkpoint_policy.md`
- `docs/professional_refusion_motion_keyframe_engine.md`
- `docs/professional_composition_timeline_migration_plan.md`

Every completed build step must be a focused checkpoint:

```text
finish scoped change
-> verify the smallest relevant behavior
-> commit only related files
-> push to GitHub
-> install on the connected Android device when a device is available
-> report branch, commit hash, verification, install result, and rollback command
```

Rollback note format:

```text
git revert <commit-hash>
```

## 1. Non-Negotiable Live Scrub Protection

This engine must not damage Live Scrub.

The following paths are protected and must not be touched unless the user explicitly approves a specific Live Scrub fix:

- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TimelineScrubPlatformView.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5NativeScrubEngine.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5SurfaceScrubDecoder.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubOverlayTextureView.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5PreviewPlatformView.kt`
- `lib/features/editor/presentation/widgets/native_timeline_scrub_surface.dart`
- Flutter handoff code around Live Scrub and native scrub surface configuration

Scene Program work must start in domain services and tests. UI, preview, export, and native media work are later gates.

## 2. Product Goal

ReFusion must become an editable motion graphics engine that can accept a prompt-driven scene from an agent and turn it into real app objects:

```text
Prompt
-> Agent writes ReFusion Scene Program JSON
-> App validates JSON
-> App lowers JSON into MotionProject graph
-> User sees layers, elements, channels, and keyframes
-> User edits the generated scene manually
-> Preview and export evaluate the same graph
```

The generated scene must never become an opaque baked video when the user expects editable motion graphics.

## 3. Architectural Inspiration

### 3.1 Remotion Inspiration

Use Remotion as architectural inspiration only, not as embedded code.

Important ideas to adopt:

- composition metadata: width, height, fps, duration;
- frame-based time: the current visual state is evaluated for a frame;
- sequence/local time: nested content receives local frame/time;
- interpolation primitives: value mapping over frame ranges;
- spring/easing primitives: physics-like motion from deterministic inputs;
- render determinism: preview and export should use the same evaluator.

Do not copy:

- React component runtime;
- JSX as the authoring format;
- Chromium frame rendering;
- DOM or CSS layout semantics;
- arbitrary executable code as the editable scene source.

Official reference points:

- https://www.remotion.dev/docs/the-fundamentals
- https://www.remotion.dev/docs/composition
- https://www.remotion.dev/docs/sequence
- https://www.remotion.dev/docs/interpolate
- https://www.remotion.dev/docs/spring

### 3.2 After Effects Inspiration

Use After Effects as the editing and motion-design behavior reference:

- composition contains layers over time;
- each layer owns properties;
- properties can have keyframes;
- keyframes are stable identity objects, not list indexes;
- values between keyframes are interpolated;
- changing a keyframe changes real evaluated motion;
- generated motion must remain editable in the timeline.

Official reference points:

- https://helpx.adobe.com/after-effects/using/setting-selecting-deleting-keyframes.html
- https://helpx.adobe.com/after-effects/using/keyframe-interpolation.html

## 4. Current ReFusion Baseline

Already present:

- `ReFusionSceneProgram` model:
  `lib/features/editor/domain/models/refusion_scene_program_models.dart`
- `ReFusionSceneProgramImportService` validator:
  `lib/features/editor/domain/services/refusion_scene_program_import_service.dart`
- `MotionProjectModel`, `MotionSceneModel`, `MotionLayerModel`, `MotionElementModel`:
  `lib/features/editor/domain/models/professional_motion_models.dart`
- `MotionPropertyChannelModel`, `MotionKeyframeModel`, interpolation specs:
  `lib/features/editor/domain/models/professional_motion_animation_models.dart`
- `ScopeMotionPropertyCatalog` for shared text/image/shape properties:
  `lib/features/editor/domain/services/scope_motion_property_catalog.dart`
- `CompositionTimelineProjectionResolver`:
  `lib/features/editor/domain/services/composition_timeline_projection.dart`

Missing:

- no `ReFusionSceneProgramLowerer`;
- no official mapping from scene-program property names to `MotionPropertyDefinition`;
- no conversion from scene-program values to `MotionPropertyValue`;
- no application facade that turns a validated scene program into an editable project transaction;
- no UI for paste/upload/generate scene;
- no full preview/export parity for imported scene programs.

## 5. Canonical Authoring Format

The agent must output declarative JSON only.

Forbidden in scene programs:

- JSX;
- JavaScript;
- Dart code;
- functions;
- `eval`;
- remote imports;
- embedded shader source;
- hidden runtime logic.

The schema version remains:

```text
refusion.scene-program/v1
```

The minimum V1 scene program must describe:

- scene name;
- duration;
- frame rate;
- layers;
- elements;
- properties;
- channels;
- keyframes;
- easing.

## 6. First Generated Scene Definition

The first successful generated scene is intentionally small:

```text
1080x1920 composition
3 seconds
30 fps
solid background
one editable text layer
one editable shape layer
text opacity and position animation
shape scale and opacity animation
all keyframes visible and editable
```

This is the first true acceptance point. API integration is not required for this milestone.

## 7. Execution Phases

### Phase A0 - Plan And Contract Freeze

Goal:

- create and maintain this document as the official engine plan;
- make checkpointing, Live Scrub protection, JSON-only scripting, and preview/export parity explicit.

Files:

- `docs/professional_agent_scene_program_engine.md`
- `docs/professional_refusion_motion_keyframe_engine.md`

Verification:

- inspect docs;
- no app build required unless other files changed.

User inspection:

- required only as a plan review.
- No visible app behavior is expected.

### Phase A1 - SceneProgramLowerer Foundation

Goal:

- add `ReFusionSceneProgramLowerer`;
- lower validated scene programs into `MotionProjectModel` and `MotionPropertyChannelModel`;
- support only text, shape, and solid background for the first slice.

Expected file:

- `lib/features/editor/domain/services/refusion_scene_program_lowerer.dart`
- `test/refusion_scene_program_lowerer_test.dart`

Supported in this phase:

- text layer;
- shape layer;
- solid element;
- start/duration;
- opacity;
- position;
- scale;
- rotation;
- linear/ease keyframes.

Verification:

```bash
flutter test test/refusion_scene_program_import_service_test.dart test/refusion_scene_program_lowerer_test.dart
```

User inspection:

- not necessary.
- This is domain-only and should not change the visible app.

### Phase A2 - Property And Value Resolver

Goal:

- resolve scene-program property names through the existing motion property catalog;
- convert JSON values into typed motion values;
- collect warnings for unsupported properties without crashing the whole program.

Examples:

```text
position -> point/vector value
scale -> percent/vector value
opacity -> normalized scalar
rotation -> degrees
blur -> pixels
```

Verification:

```bash
flutter test test/refusion_scene_program_lowerer_test.dart test/scope_motion_property_catalog_test.dart
```

User inspection:

- not necessary unless a debug/sample screen is added.

### Phase A3 - First Local Scene Fixture

Goal:

- add a canonical sample scene program fixture;
- prove a real sample can validate and lower into a graph with real layers/channels/keyframes.

Expected files:

- `test/fixtures/refusion_scene_programs/first_generated_scene.json`
- lowerer tests that load the fixture.

Verification:

```bash
flutter test test/refusion_scene_program_lowerer_test.dart
```

User inspection:

- not necessary yet.
- This proves the engine contract, not UI.

### Phase A4 - Import Facade

Goal:

- create a single domain service for:

```text
validate JSON
-> lower to MotionProject graph
-> return project/channels/issues
```

Expected file:

- `lib/features/editor/domain/services/refusion_scene_program_authoring_service.dart`

Verification:

```bash
flutter test test/refusion_scene_program_import_service_test.dart test/refusion_scene_program_lowerer_test.dart
```

User inspection:

- not necessary.

### Phase A5 - Composition Projection Dry Run

Goal:

- prove that lowered scene-program output can pass through existing composition projection services;
- do not wire production UI yet.

Verification:

```bash
flutter test test/composition_timeline_projection_test.dart test/refusion_scene_program_lowerer_test.dart
```

User inspection:

- not necessary.

### Phase A6 - Paste/Upload Scene Program UI

Goal:

- add a controlled UI entry for manually testing JSON scene programs;
- this is not the final agent flow yet.

UI:

```text
Bottom Dock
-> Generate Scene or Import Scene
-> Bottom Sheet
-> Paste JSON
-> Done
-> Validation report
```

Rules:

- invalid JSON must show errors;
- valid JSON may be accepted into a preview/import path;
- no API calls yet;
- no generated scene should be applied silently.

Verification:

```bash
flutter analyze
flutter build apk --debug
```

User inspection:

- required.
- Check that the bottom sheet opens.
- Check invalid JSON gives clear errors.
- Check valid fixture JSON is accepted.
- No Live Scrub regression should be observed.

### Phase A7 - Apply Generated Scene To Editable Composition

Goal:

- apply the lowered scene as editable motion graph data;
- generated layers should appear as real layers.

Acceptance:

- generated text appears as a text layer;
- generated shape appears as a shape layer;
- keyframes appear in the scope/layer timeline;
- selecting a keyframe shows/edit values;
- moving keyframes changes real motion.

Verification:

```bash
flutter analyze
flutter build apk --debug
```

User inspection:

- required.
- Paste the sample JSON.
- Confirm text and shape appear.
- Enter the relevant scope timeline.
- Confirm keyframes are visible.
- Move a keyframe and confirm motion changes.

### Phase A8 - Preview Evaluator Parity

Goal:

- ensure generated scene motion uses the same frame evaluator as manual motion;
- preview should not use a private special path.

Verification:

```bash
flutter test test/refusion_scene_program_lowerer_test.dart
flutter analyze
flutter build apk --debug
```

User inspection:

- required.
- Play the generated scene.
- Scrub the timeline.
- Confirm preview frame matches timeline frame.
- Confirm no Live Scrub regression.

### Phase A9 - Export Parity

Goal:

- exported video must include generated text/shape motion;
- preview and export must evaluate the same channels and keyframes.

Verification:

```bash
flutter analyze
flutter build apk --debug
```

User inspection:

- required.
- Export the sample scene.
- Compare exported motion against preview.
- Report any missing effect/property.

### Phase A10 - Agent Prompt Contract

Goal:

- write a prompt/documentation package that can be sent to ChatGPT, Claude, Codex, or another agent;
- the agent must return valid ReFusion Scene Program JSON only.

Expected document:

- `docs/refusion_scene_program_agent_prompt_v1.md`

Verification:

- use at least 3 sample prompts and validate the returned JSON locally.

User inspection:

- useful but not required.
- The user can send the document to an external agent and paste the result.

### Phase A11 - Generate Scene API Integration

Goal:

- connect the UI to an LLM/agent service through a secure boundary;
- the service returns Scene Program JSON, not final video.

Rules:

- do not expose production API keys directly in the mobile app;
- prefer backend/proxy for real production usage;
- KIE video/image models may generate assets later, but editable motion must come back as JSON scene data.

Verification:

```bash
flutter analyze
flutter build apk --debug
```

User inspection:

- required.
- Type a prompt.
- Confirm generated scene appears as editable layers/keyframes.
- Confirm failed generation shows recoverable errors.

### Phase A12 - Advanced Motion Primitives

Goal:

- add professional motion primitives after the first scene works.

Candidates:

- spring;
- bounce;
- elastic;
- stagger;
- word-by-word text reveal;
- letter-by-letter text reveal;
- trim path;
- repeater;
- gradient fill;
- shadow/glow;
- blur/motion blur;
- camera zoom/pan.

Verification:

- targeted domain tests for each primitive;
- preview/export checks before declaring each primitive complete.

User inspection:

- required for any visually new primitive.

## 8. Required User Validation After Each Build

Use this rule to avoid wasting real-device time:

```text
domain-only or test-only change -> user app inspection is not required
UI entry or visible behavior -> user app inspection is required
preview/export change -> user app inspection is required
timeline/scope behavior change -> user app inspection is required
Live Scrub-adjacent change -> stop unless explicitly approved
```

### User Check Matrix

| Phase | Visible in app? | User must inspect? | What to check |
| --- | --- | --- | --- |
| A0 | No | Review only | Plan correctness |
| A1 | No | No | Tests only |
| A2 | No | No | Tests only |
| A3 | No | No | Fixture lowers correctly |
| A4 | No | No | Import facade result |
| A5 | No | No | Projection dry run |
| A6 | Yes | Yes | Paste/upload sheet and errors |
| A7 | Yes | Yes | Layers/keyframes appear and edit |
| A8 | Yes | Yes | Preview and scrub frame match |
| A9 | Yes | Yes | Export matches preview |
| A10 | No/partial | Optional | Agent prompt clarity |
| A11 | Yes | Yes | Prompt generates editable scene |
| A12 | Yes | Yes | Each new primitive motion quality |

## 9. Stop Conditions

Stop and report before continuing if any of these happen:

- a proposed change touches protected Live Scrub paths;
- generated motion cannot be represented as editable layers/channels/keyframes;
- preview requires a separate private evaluator;
- export cannot share the same evaluated graph;
- a script requires executable code;
- a checkpoint cannot be pushed;
- tests reveal timeline clock or keyframe identity regression.

## 10. First Build Recommendation

Start with:

```text
Phase A1: SceneProgramLowerer Foundation
```

Reason:

- it does not touch Live Scrub;
- it gives the app the missing bridge between validated JSON and editable motion graph;
- it can be proven with tests before any UI risk;
- it is the shortest real path toward the first generated scene.
