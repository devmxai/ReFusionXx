# Professional Native Scene Intelligence System - VERSION 4

Status: official VERSION 4 execution plan  
Package: `com.refusion.app`  
Branch: `codex/unified-keyframe-ops-foundation-20260426`  
Date opened: 2026-05-09  
Primary predecessors:

- `professional_native_scene_intelligence_system.md`
- `professional_native_scene_intelligence_system_version_2.md`
- `professional_native_scene_intelligence_system_version_3.md`

Scope: coordinate-system canon, single evaluated-frame truth pipeline, render
truth alignment, executable HCT parity, visual QA/renderer parity, strict
pre-render enforcement, scene regression fixtures, and skills guidance updates.

## 0. Executive Summary

VERSION 3 built the correct professional infrastructure: typed components,
HCT, transform composition, lifecycle rules, visual QA, pre-render gates,
determinism, and professional taste grammar. The real-device scene trial proved
that infrastructure alone is not enough when different subsystems evaluate the
same scene in different coordinate spaces or with different hierarchy semantics.

VERSION 4 exists to close that gap:

```text
QA truth == Preview truth == Lowerer truth == Apply gate truth
```

The system is not considered professional until the same evaluated frame truth
is consumed by:

- visual QA;
- pre-render sanity gate;
- preview overlays;
- SceneProgram lowerer/adapters;
- diagnostics and tests;
- future native Stage5 handoff paths.

The most important decision:

```text
There must be one canonical scene coordinate system and one evaluation pipeline.
```

Do not write another demo scene until VERSION 4 proves that the system can keep
text inside cards, icons inside buttons, and children synchronized with parents
after full lowering and evaluated-frame rendering.

## 1. Why VERSION 4 Exists

The current device screenshot showed a critical quality failure:

- cards were misplaced and clipped;
- text did not stay inside cards;
- title/body text overlapped feature cards;
- parent/child motion did not behave like a professional group;
- the scene import test still passed.

That means the current gates can certify a scene that the user sees as broken.
The core failure is not one bad JSON scene. It is a render-truth divergence:

```text
SceneProgram JSON
  -> Visual QA geometry path      (one coordinate interpretation)
  -> Preview/render/lowerer path  (another coordinate interpretation)
```

The system must never again allow this:

```text
test passes + device screen fails
```

VERSION 4 is the correction layer.

## 2. Confirmed Technical Diagnosis

### 2.1 Coordinate Space Drift

The preview/render side treats SceneProgram positions as center-origin:

```text
screenX = canvasWidth / 2 + positionX
screenY = canvasHeight / 2 + positionY
```

The existing visual QA path builds a layer root using a top-left-like canvas
root:

```text
root.x = 0
root.y = 0
root.width = 1080
root.height = 1920
localLeft = 0
localTop = 0
```

This creates phantom validation geometry. Example:

```text
JSON position: x=452, y=640

Renderer center-origin:
  screenX = 540 + 452 = 992
  screenY = 960 + 640 = 1600

QA top-left-like interpretation:
  screenX = 452
  screenY = 640
```

The element is validated in one place and rendered in another.

### 2.2 HCT Exists But Is Not Yet The Universal Render Truth

VERSION 3 introduced HCT classes and transform composition. The problem is not
that no HCT code exists. The problem is that some paths still lower or render
flat `MotionElementModel` elements without consuming HCT world transforms as
the final truth.

Current failure mode:

```text
Visual QA:
  parentId -> runtime tree -> composed bounds

Lowerer/preview:
  element -> flat MotionElementModel -> independent transform
```

This allows a card shell and its text to desynchronize.

### 2.3 Tests Verify Import, Not Render Truth

A scene can currently pass import/authoring tests while failing visually on the
device. VERSION 4 must add tests that evaluate the same geometry the preview
uses. A passing import test is no longer enough.

## 3. Non-Negotiable Decisions

1. Canonical coordinate system:

```text
SceneCoordinateSystem.centerOriginV1
origin: canvas center
+X: right
+Y: down
unit: design pixels
position: element center unless an explicit anchor contract says otherwise
rects: stored and compared as center-origin world rects plus viewport rects
```

2. No implicit top-left math in validators.

Top-left may exist only as a derived viewport-space representation produced by
explicit conversion helpers.

3. One evaluated-frame truth.

All gates must consume `EvaluatedFrameTruth`. They must not rebuild geometry
with local ad hoc rules.

4. HCT is executable.

`parentId`, component slots, lifecycle, opacity, and transforms must affect the
actual evaluated frame, not only diagnostics.

5. Strict gates block broken scenes.

Any text overflow, clipping, safe-area failure, parent-child desync, duplicate
competing channel, or unreadable hold is an error in professional authoring.

6. Protected native paths remain protected.

Do not touch Stage5, Live Scrub, Motion Tile, Motion Blur, or unrelated FX
files unless a phase explicitly proves it is required and documents the change.
VERSION 4 should first align Flutter/domain evaluation and preview overlays.

7. No scene rewrite before pipeline proof.

The prompt-burst scene may be rewritten only after tests prove the coordinate
canon and evaluated-frame pipeline.

## 4. Canonical Architecture

### 4.1 Coordinate Canon

Create a typed coordinate API:

```text
SceneCoordinateSpace.centerOriginV1
SceneCanvasMetrics(width, height)
ScenePoint.center(x, y)
SceneRect.centerOrigin(centerX, centerY, width, height)
SceneViewportPoint(left, top)
SceneViewportRect(left, top, width, height)
```

Required conversion helpers:

```text
centerToViewport(point, canvas)
viewportToCenter(point, canvas)
rectFromCenter(center, size)
rectCenterToViewport(rect, canvas)
rectViewportToCenter(rect, canvas)
containsRect(parent, child, space)
```

Every conversion must state its input and output coordinate space.

### 4.2 Single Evaluation Pipeline

Create one pipeline that evaluates a scene at a frame:

```text
Input:
  SceneProgram or SemanticSceneBlueprint
  globalTimeMs
  canvas metrics

Process:
  1. resolve coordinate system
  2. compile blueprint if needed
  3. build HCT source map
  4. evaluate keyframes at globalTimeMs
  5. compose parent transforms and opacity
  6. compute local, world, and viewport bounds
  7. compute effective lifecycle and visibility
  8. return EvaluatedFrameTruth

Output:
  EvaluatedFrameTruth
```

Consumers:

```text
SceneVisualFrameQaValidator
ScenePreRenderSanityGate
SceneProgramApplyTransaction
Motion shape/text preview overlays
Diagnostics
Regression tests
Future Stage5 adapter parity layer
```

Forbidden:

```text
QA evaluates JSON geometry separately.
Preview evaluates different transforms.
Lowerer ignores parent-child world transforms.
Tests validate only parse/import when visual truth is required.
```

### 4.3 Evaluated Frame Truth

Minimum model:

```text
EvaluatedFrameTruth {
  coordinateSystem
  canvas
  globalTimeMs
  sceneId
  frameHash
  nodesById: Map<String, EvaluatedSceneNode>
  sourceMaps
  diagnostics
}

EvaluatedSceneNode {
  nodeId
  sourceLayerId
  sourceElementId
  parentNodeId
  nodeType
  localTransform
  worldTransform
  localBoundsCenter
  worldBoundsCenter
  viewportBounds
  slotBoundsCenter
  contentBoundsCenter
  effectiveOpacity
  active
  visible
  textMetrics
  zOrder
}
```

The same `EvaluatedSceneNode.viewportBounds` must be what preview overlays use
for screen positioning.

## 5. VERSION 4 Phase Order

### NSI-v4-00 - Failure Reproduction And Render Truth TDD

Checkpoint:

```text
checkpoint: 2026-05-09 professional native scene intelligence v4 00 - render truth failure reproduction
```

Purpose:

Lock the current failure into tests before changing architecture.

Required:

- Add a failing regression fixture for the prompt-burst/feature-card failure.
- Add a test proving that a card text child must remain inside its card after
  full lowering/evaluation.
- Add a test proving that a center-origin position converts to viewport
  position with `canvas / 2` offsets.
- Add a test proving visual QA and preview geometry currently diverge, if
  possible, before the fix.

Suggested tests:

- `scene_coordinate_system_canon_test.dart`
- `scene_render_truth_alignment_test.dart`
- `scene_prompt_burst_regression_test.dart`

Acceptance:

- At least one new test fails before implementation or is documented as a
  current failure with a skipped marker and explicit TODO linked to v4.
- The test names describe the user-visible failure, not only internal classes.

Do not:

- rewrite the scene asset to hide the failure;
- relax assertions;
- stage unrelated screenshots or diagnostics.

### NSI-v4-01 - Coordinate System Canon

Checkpoint:

```text
checkpoint: 2026-05-09 professional native scene intelligence v4 01 - coordinate system canon
```

Purpose:

Make center-origin the explicit typed coordinate truth for SceneProgram
evaluation and preview.

Files to create:

- `scene_coordinate_system.dart`
- `docs/refusion_coordinate_system_canon.md`

Required:

- Define `SceneCoordinateSpace.centerOriginV1`.
- Define canvas metrics and typed point/rect value objects.
- Add conversion helpers for center-origin and viewport/top-left display
  coordinates.
- Document:
  - origin;
  - axis direction;
  - unit;
  - anchor semantics;
  - migration math from top-left to center-origin;
  - examples for 1080x1920, 1920x1080, 1080x1080, 1080x1350.
- Add scan/test coverage to catch new top-left assumptions in visual QA files.

Acceptance:

- `position: {x: 0, y: 0}` evaluates to canvas center.
- `position: {x: -540, y: -960}` evaluates to viewport top-left on 1080x1920.
- `position: {x: 452, y: 640}` evaluates to viewport `992,1600` on 1080x1920.
- No visual QA code may construct a top-left canvas root without explicit
  conversion.

Diagnostics:

- `TF_SCENE_COORDINATE_CANON_PROOF`
  - `coordinateSystem`
  - `canvasWidth`
  - `canvasHeight`
  - `centerPoint`
  - `viewportPoint`
  - `conversionDirection`
  - `passed`
  - `fallbackReason`

### NSI-v4-02 - Evaluated Frame Truth Model

Checkpoint:

```text
checkpoint: 2026-05-09 professional native scene intelligence v4 02 - evaluated frame truth model
```

Purpose:

Create the shared data model consumed by QA, preview, pre-render, and tests.

Files to create:

- `evaluated_frame_truth.dart`
- `scene_evaluation_diagnostics.dart`

Required:

- Define immutable evaluated-frame truth models.
- Include center-origin and viewport bounds for every node.
- Include source maps to layer/element/component ids.
- Include frame hash and geometry hash.
- Include text metrics for bounded text nodes.
- Include parent-child relation in the evaluated result.

Acceptance:

- Evaluated nodes expose both `worldBoundsCenter` and `viewportBounds`.
- Geometry hashes are deterministic for the same input.
- Frame truth can be serialized to a compact diagnostic map.

### NSI-v4-03 - Single Scene Evaluation Pipeline

Checkpoint:

```text
checkpoint: 2026-05-09 professional native scene intelligence v4 03 - single scene evaluation pipeline
```

Purpose:

Build one code path for per-frame scene evaluation.

Files to create:

- `scene_evaluation_pipeline.dart`

Required:

- Input can be a `ReFusionSceneProgram`.
- Use canonical coordinate helpers.
- Build or consume HCT relationships.
- Evaluate static properties and channels at `globalTimeMs`.
- Compose parent transforms, opacity, lifecycle, and bounds.
- Produce `EvaluatedFrameTruth`.
- Preserve existing SpeedyGraph/easing semantics through
  `MotionInterpolationTruthCompiler` where applicable.

Acceptance:

- Parent translation changes child viewport bounds automatically.
- Parent scale changes child viewport bounds automatically.
- Parent opacity affects child effective opacity.
- Child lifecycle is inactive outside parent lifecycle.
- Same input and time produce identical frame truth hash across runs.

Diagnostics:

- `TF_SCENE_EVALUATED_FRAME_TRUTH_PROOF`
  - `sceneId`
  - `globalTimeMs`
  - `coordinateSystem`
  - `nodeCount`
  - `geometryHash`
  - `frameHash`
  - `hctApplied`
  - `usedCanonicalCoordinates`
  - `fallbackReason`

### NSI-v4-04 - Visual QA Consumes EvaluatedFrameTruth

Checkpoint:

```text
checkpoint: 2026-05-09 professional native scene intelligence v4 04 - visual qa evaluated truth
```

Purpose:

Remove phantom geometry validation. Visual QA must inspect the same evaluated
frame truth used by preview.

Required:

- Refactor `SceneVisualFrameQaValidator` to call `SceneEvaluationPipeline`.
- Stop building a separate QA-only coordinate root.
- Compare text bounds, slot bounds, safe-area bounds, and sibling overlap using
  canonical evaluated frame truth.
- Keep up to 9 probe frames.
- Emit proof logs using evaluated truth hashes.

Acceptance:

- If preview would place a node off-canvas, QA reports off-canvas.
- If text is outside its card in evaluated truth, QA fails.
- No duplicated evaluator logic remains for position/channel interpolation in
  the visual QA validator.
- Existing visual QA tests are migrated to frame truth.

Diagnostics:

- `TF_SCENE_VISUAL_FRAME_QA_PROOF`
  - existing fields plus:
  - `geometryHash`
  - `evaluatedFrameTruthHash`
  - `coordinateSystem`
  - `qaUsedSharedPipeline=true`

### NSI-v4-05 - Lowerer And Preview Render Truth Alignment

Checkpoint:

```text
checkpoint: 2026-05-09 professional native scene intelligence v4 05 - lowerer preview render truth alignment
```

Purpose:

Ensure the editable `MotionProject` and preview overlays do not ignore HCT or
canonical coordinates.

Required:

- Audit `ReFusionSceneProgramLowerer`.
- Preserve HCT source maps during lowering.
- Ensure `parentId` is either:
  - compiled into evaluated world transforms before preview; or
  - rejected as unsupported in professional paths until compiled correctly.
- Align shape/text preview overlays with `EvaluatedFrameTruth.viewportBounds`
  where possible.
- If direct overlay refactor is too large, add an adapter layer that converts
  evaluated truth into the existing overlay node format.
- Do not touch protected Stage5/Live Scrub native files.

Acceptance:

- A parent card movement moves child title/body/icon in preview geometry.
- PromptInputBar shell, prompt text, plus icon, and send button stay grouped.
- Text inside a feature card remains inside the card after lowering.
- Preview and QA geometry hashes match for tested frames.

Diagnostics:

- `TF_SCENE_RENDER_TRUTH_ALIGNMENT_PROOF`
  - `sceneId`
  - `globalTimeMs`
  - `nodeId`
  - `qaViewportBounds`
  - `previewViewportBounds`
  - `boundsDeltaPx`
  - `matched`
  - `fallbackReason`

### NSI-v4-06 - Strict Apply And Pre-Render Gate On Shared Truth

Checkpoint:

```text
checkpoint: 2026-05-09 professional native scene intelligence v4 06 - strict shared truth apply gate
```

Purpose:

Block bad scenes using the same evaluated truth that preview uses.

Required:

- Refactor `ScenePreRenderSanityGate` to consume
  `SceneEvaluationPipeline`.
- Block professional apply/import when evaluated frame truth fails.
- Show structured errors with:
  - error code;
  - node id;
  - source layer/element/component id;
  - frame time;
  - measured bounds;
  - suggested repair.
- Ensure "valid with warnings" cannot admit visual defects.

Acceptance:

- The current broken prompt-burst scene is rejected until fixed.
- Raw professional SceneProgram that uses `parentId` without executable HCT
  support is rejected or migrated.
- Apply transaction refuses scenes with QA/render-truth mismatch.

Diagnostics:

- `TF_SCENE_PRE_RENDER_GATE_PROOF`
  - existing fields plus:
  - `evaluatedFrameTruthHash`
  - `sharedPipeline=true`
  - `renderTruthAligned`

### NSI-v4-07 - Prompt Burst Regression Rewrite Through Canonical Pipeline

Checkpoint:

```text
checkpoint: 2026-05-09 professional native scene intelligence v4 07 - prompt burst canonical scene rewrite
```

Purpose:

Only after the pipeline is aligned, rewrite the demo scene as a professional
fixture that proves the system.

Required:

- Rebuild `revival_prompt_burst_feature_cards_scene.json` using center-origin
  coordinates and component-safe grouping.
- Keep a white opening canvas with centered `R` icon.
- Morph into a centered PromptInputBar.
- Type `build a new app for my business` inside bounded text slot.
- Keep plus icon and send button locked to the prompt shell.
- Use a burst transition into feature cards.
- Cards must form a balanced grid inside 9:16 safe area.
- Card titles/body/icons must be inside slots.
- Motion must use SpeedyGraph presets, not decorative timings.

Acceptance:

- Scene passes shared truth QA.
- Scene passes prompt text containment at hold frame.
- Scene passes card text containment at card hold frame.
- Scene looks centered on device, not in corners.
- No text/card mismatch is visible in screenshot.

### NSI-v4-08 - Skills And Agent Contract Update

Checkpoint:

```text
checkpoint: 2026-05-09 professional native scene intelligence v4 08 - skills coordinate render truth update
```

Repository:

```text
/Users/mx/Documents/refusion-skills
```

Required:

- Update skills to state the canonical coordinate system:
  - center-origin;
  - +X right;
  - +Y down;
  - pixels;
  - position is center by default.
- Add examples converting common top-left layouts to center-origin.
- Add explicit rule:
  - never rely on `parentId` unless the component contract supports executable
    hierarchy;
  - prefer semantic components and slots.
- Add good/bad examples for PromptInputBar, FeatureCard, FeedbackCard.
- Add repair examples using structured evaluated-frame errors.
- Rebuild `REFUSION_SCENE_SKILL_FULL.md`.
- Run the skills validator.
- Commit and push `refusion-skills` separately.

Acceptance:

- A generic agent reading the skills understands ReFusion's coordinate space.
- Skills forbid top-left absolute coordinates unless explicitly converted.
- Skills explain that QA/render share `EvaluatedFrameTruth`.

### NSI-v4-09 - Closure QA, Build, Install, Status Update

Checkpoint:

```text
checkpoint: 2026-05-09 professional native scene intelligence v4 09 - closure qa
```

Required:

- Run focused tests:
  - `scene_coordinate_system_canon_test.dart`
  - `scene_render_truth_alignment_test.dart`
  - `scene_prompt_burst_regression_test.dart`
  - `scene_visual_frame_qa_validator_test.dart`
  - `scene_program_component_contract_test.dart`
  - `scene_pre_render_sanity_gate_test.dart`
  - `refusion_scene_program_authoring_service_test.dart`
  - `premium_app_promo_scene_program_preset_test.dart`
- Run broader targeted tests touched by lowerer/preview if needed.
- Run `flutter build apk --debug`.
- Install on connected wireless Android device if available.
- Capture screenshot for the prompt-burst scene.
- Update this VERSION 4 document with final phase status and commit hashes.

Final acceptance:

- QA and preview agree on coordinates.
- `parentId`/HCT semantics are either executable or fail closed.
- Broken scenes cannot pass apply/import.
- Prompt-burst scene is centered and visually coherent on device.
- Tests prove containment after full evaluation, not only JSON validation.

## 6. Integration Gates

After each phase:

- run the smallest targeted verification;
- stage only related files;
- commit with the checkpoint message;
- push the branch;
- install only when behavior or assets that affect the app change;
- report rollback command.

Do not combine unrelated phases.

Gate requirements:

```text
v4-00 -> failing/reproduction tests exist
v4-01 -> coordinate conversions pass
v4-02 -> evaluated frame truth models deterministic
v4-03 -> pipeline computes parent-child world bounds
v4-04 -> visual QA consumes pipeline
v4-05 -> preview/lowerer align with pipeline
v4-06 -> apply gate blocks shared-truth failures
v4-07 -> prompt-burst scene passes and looks correct
v4-08 -> refusion-skills updated
v4-09 -> tests/build/install/status closed
```

## 7. Required Regression Tests

### 7.1 Card Text Containment

```text
Given a FeatureCard component with a title child,
when the parent card moves/scales,
then title viewport bounds remain inside card viewport bounds
after full evaluated-frame pipeline.
```

### 7.2 PromptInputBar Containment

```text
Given a PromptInputBar with prompt text, plus icon, and send button,
when the shell morphs from icon to input,
then all children remain in their slots at every probe frame.
```

### 7.3 Coordinate Conversion

```text
Given 1080x1920 canvas and center-origin point x=0,y=0,
then viewport point is x=540,y=960.
```

### 7.4 QA/Preview Parity

```text
Given the same scene and time,
when visual QA and preview evaluate bounds,
then bounds delta is <= 0.5px for tested nodes.
```

### 7.5 Broken Scene Rejection

```text
Given a raw SceneProgram whose card text is outside the card in render truth,
then import/apply is blocked with structured error.
```

## 8. Stop List

Do not:

- write another demo scene before v4-00 through v4-06 are complete;
- patch coordinates manually to make one screenshot look better;
- allow QA-only HCT to certify scenes that render flat;
- allow implicit top-left math in visual QA;
- create a second renderer, HTML path, Remotion path, or web canvas path;
- touch protected Stage5 or Live Scrub native files without explicit approval;
- weaken visual defects from errors to warnings;
- claim professional scene quality from parse/import tests alone;
- stage unrelated screenshots, diagnostics, seam files, or old experiments;
- rewrite SpeedyGraph or create a parallel easing system.

## 9. Agent Writer Instruction

Start with `NSI-v4-00`.

This is not a creative scene-writing task. It is a render-truth alignment task.
The agent writer must prove the current failure first, then make QA, preview,
lowerer, and pre-render gate consume the same coordinate and evaluated-frame
truth.

Critical rules:

- Do not modify the prompt-burst scene until `NSI-v4-07`.
- Do not change protected native Stage5/Live Scrub files.
- Do not fix by hardcoding current scene coordinates.
- Do not add a new plan version.
- Do not mark the phase complete unless targeted tests pass.
- Commit and push each phase separately.

Expected final report per phase:

- commit hash;
- files changed;
- tests run;
- build/install result if applicable;
- diagnostics observed;
- remaining risks;
- rollback command.

## 10. Final Definition Of Done

VERSION 4 is complete only when all are true:

- The coordinate canon is documented and enforced in code.
- Visual QA no longer evaluates a different coordinate space than preview.
- `EvaluatedFrameTruth` is the shared contract between QA, gate, and preview.
- HCT parent-child transforms are executable in the render/evaluation path.
- Bad scenes are blocked before reaching the user.
- The prompt-burst scene is rebuilt and passes on a connected device.
- The screenshot no longer shows elements in corners, clipped cards, or text
  outside its container.
- `refusion-skills` teaches agents the same coordinate and component truth.
- Closure QA is committed and pushed.

In one line:

```text
VERSION 4 makes the pixel on screen the same truth that the validator approved.
```
