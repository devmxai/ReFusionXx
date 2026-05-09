# Professional Motion Component Runtime Plan

Status: new execution plan  
Package: `com.refusion.app`  
Branch: `codex/unified-keyframe-ops-foundation-20260426`  
Opened: 2026-05-10  

## 0. Why This Plan Exists

The latest device review exposed the real gap.

The issue is not one bad `Professional Test Version 2` scene. The issue is that
ReFusion can describe component-like relationships in JSON, but the runtime
still behaves too much like a flat layer/keyframe system. That means a prompt
bar can be written as if it were one component, while the renderer evaluates it
as separate layers:

- `promptShell`
- `promptPlusIcon`
- `promptText`
- `promptCursor`
- `promptMicIcon`
- `sendButton`
- `promptVoiceIcon`

This is why the output still feels weak:

- the card/shell can exit before its children;
- icons can remain visible after the shell is gone;
- text sizing is guessed instead of laid out inside a slot;
- borders and strokes are not guaranteed by a shape render contract;
- child motion is not automatically synchronized with parent motion;
- validators can report relationships that the runtime itself does not enforce.

The professional fix is not more manual JSON patching. The professional fix is
to build the missing runtime layer:

```text
Motion Component Runtime =
  global parent graph
  + component slots
  + layout pass
  + text layout pass
  + inherited transforms/opacity/lifecycle
  + component choreography compiler
  + strict render/apply gates
```

This is the equivalent of giving ReFusion its own CSS/Flutter-style component
system for motion scenes.

## 1. Executive Decision

The controlling decision for this plan:

```text
Components are runtime truth.
Layers are only the editable compiled representation.
```

An agent, preset, or Director Brief must not author a professional UI-like scene
as unrelated raw layers. It must author components with slots and beats. The
runtime/compiler then lowers those components into editable SceneProgram layers
without losing parent-child truth.

The correct path is:

```text
Prompt / Agent
  -> Director Brief
  -> Component Blueprint
  -> Motion Component Runtime
  -> SceneProgram layers/channels
  -> EvaluatedFrameTruth
  -> Visual QA / Apply / Preview / Export
```

The wrong path is:

```text
Prompt / Agent
  -> raw layers with x/y/fontSize/keyframes
  -> hope validators catch problems
```

## 2. Non-Negotiable Rules

1. No professional scene may rely on loose child layers when a component
   contract exists.

2. `parentId` must be runtime truth, not decorative metadata.

3. A child must inherit parent transform, opacity, visibility, and lifecycle
   unless it explicitly opts out through a validated override.

4. Text inside bounded UI must be measured and fitted by a shared text layout
   engine before render.

5. The renderer, visual QA, and apply gate must consume the same evaluated
   component truth.

6. Component motion must be choreographed as enter, internal reveal, hold, and
   exit. Independent child fades are not acceptable for professional components.

7. Borders/strokes must be render contracts, not optional visual hints.

8. The AI Director is not the source of rendering truth. It is a planner above a
   deterministic component runtime.

## 3. Current Failure Model

### 3.1 Prompt Bar Failure

The prompt bar currently demonstrates all core failures:

- the shell is visually one object, but stored as one layer;
- text and icons are separate layers;
- cross-layer parenting is incomplete or inconsistently consumed;
- child keyframes can have independent timing and outlive the shell;
- text fit is manually tuned instead of computed from slot width;
- shell border rendering is not guaranteed strongly enough;
- entry and exit are not one group choreography.

### 3.2 Why React/Flutter/Lovable Look Better

React, Flutter, Tailwind, shadcn/ui, Radix UI, and similar systems provide
default professionalism through:

- component trees;
- layout constraints;
- flex/grid distribution;
- padding/gap/alignment primitives;
- typography scales;
- overflow handling;
- component states;
- design tokens;
- predictable render contracts.

AI builders look strong because they generate code inside those mature systems.
They do not draw every pixel from scratch.

ReFusion needs the same idea for motion:

- not CSS, but Scene Layout;
- not React DOM, but Motion Component Tree;
- not Tailwind classes, but visual + motion tokens;
- not browser flow, but beat-aware layout and choreography;
- not only linting, but runtime-enforced component truth.

## 4. Target Architecture

```text
Director Brief
  -> Component Blueprint
  -> Component Registry
  -> Slot Layout Solver
  -> Text Layout Engine
  -> Motion Choreography Compiler
  -> Global Parent Graph
  -> SceneProgram Lowerer
  -> Evaluated Component Frame Truth
  -> Preview / QA / Apply / Export
```

### 4.1 Component Runtime Node

Each component must lower into a runtime tree:

```text
ComponentNode(PromptInputBar)
  shellSlot
    ShapeNode(roundedRectangle)
  leftIconSlot
    IconNode(plus)
  textSlot
    TextNode(promptText)
    CursorNode(typeCursor)
  micSlot
    IconNode(mic)
  sendButtonSlot
    ShapeNode(circle)
    IconNode(volume)
```

Each node exposes:

- stable id;
- kind;
- local bounds;
- world bounds;
- local transform;
- world transform;
- local opacity;
- effective opacity;
- local time range;
- effective active state;
- parent id;
- child ids;
- z order;
- layout role;
- slot id;
- component id.

### 4.2 Parent Inheritance

Every frame:

```text
child.worldTransform = parent.worldTransform * child.localTransform
child.effectiveOpacity = parent.effectiveOpacity * child.localOpacity
child.active = parent.active && child.localActive
child.visible = parent.visible && child.localVisible
```

If a parent exits, its children cannot remain visible unless a validated
`detachOnExit` override is present. That override is forbidden for core UI
components such as prompt bars, cards, buttons, panels, and CTAs.

### 4.3 Slot Layout

Component children do not guess `x/y`.

They receive slot bounds:

```text
PromptInputBar
  height: token.inputBar.height
  width: min(canvas.safeWidth - margins, token.inputBar.maxWidth)
  padding: token.inputBar.padding
  gap: token.inputBar.gap
  slots:
    leftIconSlot: fixed square
    textSlot: fill remaining
    micSlot: fixed square
    sendButtonSlot: fixed circle
```

### 4.4 Text Layout

Text inside a slot must not use raw `fontSize` as final truth.

Pipeline:

```text
input text + desired typography token + slot bounds
  -> paragraph measurement
  -> shrink/wrap/ellipsis policy
  -> effective font size
  -> effective line count
  -> baseline
  -> rendered text bounds
```

QA and preview must use this same effective text layout result.

## 5. Phase Plan

### PMCR-00 - Runtime Baseline Audit

Goal: prove current gaps with failing tests before changing behavior.

Required work:

- Add a focused test showing cross-layer `parentId` does not produce true
  lifecycle inheritance for `PromptInputBar`.
- Add a focused test showing text fit is metadata-only for bounded text.
- Add a focused test showing shell and children can desynchronize on exit.
- Add diagnostics that identify whether a child resolved its parent globally,
  within layer only, or not at all.

Acceptance:

- tests fail before implementation;
- diagnostics name the exact missing runtime contract;
- no production behavior changes.

Expected files:

- `test/scene_component_runtime_parenting_test.dart`
- `test/scene_component_text_layout_contract_test.dart`

### PMCR-01 - Global Scene Parent Graph

Goal: resolve parent-child relationships across the full SceneProgram, not only
within one layer.

Required work:

- Build a global parent graph from every layer and element.
- Detect missing parents, cycles, duplicate parent candidates, and forbidden
  detached children.
- Preserve layer editability while making parent relationships runtime-valid.
- Emit `TF_SCENE_PARENT_GRAPH_PROOF`.

Acceptance:

- a child in a different layer can resolve `parentId` correctly;
- cycles are rejected;
- missing parent is an error for professional components;
- existing legacy scenes can still run in legacy mode when explicitly marked.

Expected files:

- `scene_global_parent_graph.dart`
- `scene_global_parent_graph_test.dart`

### PMCR-02 - Component Runtime Tree

Goal: create a real runtime tree consumed by evaluation, QA, and apply gates.

Required work:

- Create `SceneComponentRuntimeTree`.
- Create node types for scene, group, component, slot, shape, text, icon, image.
- Provide deterministic traversal order.
- Provide maps by node id, component id, element id, and slot id.
- Preserve source references back to SceneProgram layers/elements.

Acceptance:

- `PromptInputBar` evaluates as one component subtree;
- each child has a stable parent;
- traversal order is deterministic across 100 runs;
- runtime tree hash is stable.

Expected files:

- `scene_component_runtime_tree.dart`
- `scene_component_runtime_node.dart`
- `scene_component_runtime_tree_test.dart`

### PMCR-03 - Transform, Opacity, And Lifecycle Propagation

Goal: make parent motion and visibility apply to all descendants.

Required work:

- Implement world transform composition.
- Implement effective opacity composition.
- Implement active range inheritance.
- Implement visibility inheritance.
- Add parent exit cascade.
- Add blocked diagnostics for child-outlives-parent defects.

Acceptance:

- moving the prompt shell moves text/icons automatically;
- scaling the shell scales children unless slot policy says otherwise;
- fading the shell fades all children;
- after shell exit, no child remains visible;
- visual QA rejects any professional component child that outlives parent.

Expected files:

- `scene_component_lifecycle_engine.dart`
- `scene_component_transform_composer.dart`
- `scene_component_lifecycle_engine_test.dart`

### PMCR-04 - Slot Layout Solver

Goal: give components real layout behavior similar to Flutter constraints or CSS
flex, but deterministic for motion scenes.

Required work:

- Define slot layout primitives:
  - fixed;
  - fill;
  - hug;
  - stack horizontal;
  - stack vertical;
  - grid;
  - overlay;
  - center;
  - safe area inset.
- Implement content box and padding/inset math.
- Implement gap and alignment.
- Implement aspect adaptation hooks.
- Emit `TF_SCENE_SLOT_LAYOUT_PROOF`.

Acceptance:

- `PromptInputBar` computes slots from shell size;
- `FeatureCard` computes icon/title/body slots;
- child positions come from slots, not raw guessed coordinates;
- changing component width recomputes text slot safely.

Expected files:

- `scene_slot_layout_solver.dart`
- `scene_slot_layout_models.dart`
- `scene_slot_layout_solver_test.dart`

### PMCR-05 - Shared Text Layout Engine

Goal: make text sizing and fitting a render truth, not metadata.

Required work:

- Measure text using the same logic for QA and preview.
- Support:
  - max lines;
  - line height;
  - letter spacing;
  - shrink to fit;
  - wrap;
  - ellipsis;
  - clip only when explicitly allowed;
  - baseline alignment.
- Generate effective text layout output.
- Reject text that cannot fit within policy.
- Emit `TF_SCENE_TEXT_LAYOUT_PROOF`.

Acceptance:

- prompt text fits the `textSlot` without manual width tuning;
- body text in feature cards cannot be cut mid-sentence;
- QA and preview agree on text bounds;
- font size is derived from typography token + slot constraints.

Expected files:

- `scene_shared_text_layout_engine.dart`
- `scene_shared_text_layout_models.dart`
- `scene_shared_text_layout_engine_test.dart`

### PMCR-06 - Shape Stroke And Border Render Contract

Goal: make component borders predictable and visible.

Required work:

- Define stroke alignment:
  - inside;
  - center;
  - outside.
- Define minimum visible stroke at scale.
- Define anti-aliasing expectations.
- Define fill + stroke composition order.
- Make QA able to report a missing or visually too-weak border.

Acceptance:

- prompt bar border is visible at the designed scale;
- border does not disappear under scale animations;
- stroke stays inside safe bounds when requested;
- QA can detect missing border on a component that requires one.

Expected files:

- `scene_shape_stroke_contract.dart`
- `scene_shape_stroke_contract_test.dart`

### PMCR-07 - PromptInputBar Runtime Component Proof

Goal: build the first truly professional component and use it as the proof of
the whole runtime.

Required component contract:

```text
PromptInputBar
  shell:
    rounded rectangle
    visible border
    white fill
    subtle shadow
  slots:
    leftIconSlot
    textSlot
    micSlot
    sendButtonSlot
  text:
    regular weight
    slot-fit
    baseline-centered
  controls:
    optically centered icons
```

Required choreography:

```text
shell spring in
left icon pop
right controls pop staggered
text typewriter
send button press
group exit together
```

Acceptance:

- one component drives all children;
- no child remains visible after shell exit;
- no child has independent exit that breaks group coherence;
- text is automatically sized inside `textSlot`;
- prompt bar works in 9:16, 16:9, 1:1, and 4:5;
- `Professional Test Version 2` can be rebuilt using the component path, not
  manually patched raw layers.

Expected files:

- `scene_prompt_input_bar_component.dart`
- `scene_prompt_input_bar_component_test.dart`
- updated fixture for `professional_test_version_2_scene.json` only after the
  component contract passes.

### PMCR-08 - FeatureCard Runtime Component

Goal: make cards professional by default.

Required component contract:

```text
FeatureCard
  shell
  iconContainer
  iconGlyph
  title
  body
  optional accent
```

Required layout:

- icon slot fixed;
- title/body vertical stack;
- body max lines and shrink/wrap policy;
- card padding and gap tokens;
- safe internal alignment;
- no text cut mid-phrase.

Required choreography:

```text
card shell spring/slide in
icon pop
title slide/fade in
body soft fade/slide in
hold
group exit together
```

Acceptance:

- three analysis cards render with readable title/body;
- no body text is clipped or cut mid-sentence;
- icon and text maintain alignment through entry and exit;
- all children exit with card shell.

Expected files:

- `scene_feature_card_component.dart`
- `scene_feature_card_component_test.dart`

### PMCR-09 - CTAButton Runtime Component

Goal: make final CTA pills coherent and polished.

Required component contract:

```text
CTAButton
  shell
  labelSlot
  trailingIconSlot
```

Required behavior:

- label and icon remain optically centered;
- group spring pop;
- trailing arrow aligns to label baseline;
- group exit/final hold is coherent.

Acceptance:

- `Available now` CTA has stable text bounds;
- arrow does not drift independently;
- no apply-gate mismatch for CTA text;
- border/shadow/shape render predictably.

Expected files:

- `scene_cta_button_component.dart`
- `scene_cta_button_component_test.dart`

### PMCR-10 - Component Choreography Compiler

Goal: compile component-level choreography into editable channels without
breaking parent-child runtime truth.

Required work:

- Define choreography phases:
  - prepare;
  - enter;
  - internal reveal;
  - hold;
  - action;
  - exit.
- Define stagger semantics.
- Define child delays relative to parent local time.
- Compile to channels while preserving group lifecycle.
- Prevent overlapping same-property channels unless intentionally merged.

Acceptance:

- prompt bar choreography compiles deterministically;
- feature card choreography compiles deterministically;
- group exit always terminates descendants;
- generated channels remain editable.

Expected files:

- `scene_component_choreography_compiler.dart`
- `scene_component_choreography_models.dart`
- `scene_component_choreography_compiler_test.dart`

### PMCR-11 - Component-Aware SceneProgram Lowerer

Goal: lower components into SceneProgram without losing component truth.

Required work:

- Preserve component metadata.
- Preserve slot metadata.
- Preserve parent graph metadata.
- Respect `timeBasis`.
- Avoid double-offsetting project-time keyframes.
- Emit lowerer proof diagnostics.

Acceptance:

- project-time keyframes do not receive accidental extra layer offsets;
- layer-time keyframes remain supported;
- parent/slot metadata survives lowering;
- `Professional Test Version 2` applies without manual timing patches.

Expected files:

- updates to `refusion_scene_program_lowerer.dart`;
- `scene_program_component_lowering_test.dart`.

### PMCR-12 - Component-Aware Evaluation Pipeline

Goal: make `EvaluatedFrameTruth` report component truth, not only raw element
truth.

Required work:

- Evaluate runtime component tree every probe frame.
- Report component bounds, slot bounds, child bounds, text layout output, and
  effective opacity.
- Expose lifecycle diagnostics.
- Expose hierarchy diagnostics.

Acceptance:

- QA can answer "is promptText inside promptShell textSlot?";
- QA can answer "is child visible after parent exit?";
- preview/apply/export can consume the same component truth.

Expected files:

- updates to `scene_evaluation_pipeline.dart`;
- updates to `evaluated_frame_truth.dart`;
- `scene_component_evaluated_frame_truth_test.dart`.

### PMCR-13 - Strict Component QA Gate

Goal: reject scenes that are geometrically valid but component-invalid.

Required checks:

- child outlives parent;
- child visible while parent invisible;
- text exceeds slot;
- icon exceeds slot;
- missing required border;
- unsupported loose coordinates inside component;
- repeated uncoordinated fades;
- component exit is not group-coherent.

Acceptance:

- the current raw-layer prompt bar style is rejected when marked professional;
- component-authored prompt bar passes;
- errors include repair payloads;
- no "valid with warnings" for component structural defects.

Expected files:

- `scene_component_quality_validator.dart`
- `scene_component_quality_validator_test.dart`

### PMCR-14 - Agent Director Integration

Goal: introduce AI/Director intelligence only after deterministic runtime truth
exists.

Required work:

- Director Brief chooses components, not raw layers.
- Agent selects from component registry.
- Agent selects motion recipes from allowed vocabulary.
- Agent cannot invent child positions inside components.
- Repair loop receives component-level errors:
  - `TEXT_EXCEEDS_TEXT_SLOT`
  - `CHILD_OUTLIVES_PARENT`
  - `BORDER_NOT_VISIBLE`
  - `GROUP_EXIT_INCOHERENT`
  - `RAW_LAYER_USED_WHERE_COMPONENT_EXISTS`

Acceptance:

- Director Brief can generate prompt bar + word swap + analysis cards + CTA
  without raw coordinate guessing;
- if the brief is vague, validator asks for missing intent/hierarchy;
- if output fails, repair payload points to component contract, not vague
  visual advice.

Expected files:

- updates to director brief planner;
- updates to `refusion-skills`;
- good/bad examples.

### PMCR-15 - Professional Regression Suite

Goal: prove the system creates professional scenes by default.

Required fixtures:

- centered prompt bar intro;
- word swap headline;
- three analysis cards;
- final available-now CTA;
- SaaS feedback cards;
- app icon intro;
- feature grid;
- dashboard panel.

Acceptance:

- all fixtures pass component QA;
- all fixtures pass visual QA;
- all fixtures pass render truth alignment;
- all fixtures pass apply transaction;
- at least one fixture tested across 9:16, 16:9, 1:1, and 4:5;
- no fixture uses loose raw coordinates inside a known component.

Expected files:

- `test/fixtures/component_runtime/`;
- `scene_component_runtime_regression_test.dart`.

## 6. Implementation Order

Critical path:

```text
PMCR-00 Audit
PMCR-01 Global Parent Graph
PMCR-02 Runtime Tree
PMCR-03 Lifecycle Propagation
PMCR-04 Slot Layout
PMCR-05 Text Layout
PMCR-06 Stroke Contract
PMCR-07 PromptInputBar Proof
PMCR-08 FeatureCard
PMCR-09 CTAButton
PMCR-10 Choreography Compiler
PMCR-11 Lowerer
PMCR-12 Evaluation Pipeline
PMCR-13 QA Gate
PMCR-14 Agent Director Integration
PMCR-15 Regression Suite
```

Do not start PMCR-14 before PMCR-01 through PMCR-13 are functional. The Agent
Director must orchestrate a reliable deterministic engine, not compensate for
missing runtime behavior.

## 7. Definition Of Done

The plan is complete only when:

- `PromptInputBar` is a runtime component, not loose layers;
- `FeatureCard` is a runtime component, not loose layers;
- `CTAButton` is a runtime component, not loose layers;
- parent transform/opacity/lifecycle inheritance is enforced;
- text layout is shared by QA and preview;
- component children cannot outlive parent;
- component slots determine child placement;
- borders/strokes render predictably;
- component choreography compiles to editable channels;
- visual/apply gates reject raw-layer professional components;
- Director Briefs produce component blueprints, not raw coordinates;
- `Professional Test Version 2` is rebuilt through components and passes apply;
- the same component scene adapts to multiple aspect ratios.

## 8. Stop List

Do not:

- keep patching `Professional Test Version 2` by manually nudging child layers;
- solve text fit by hard-coding one scene's font size;
- solve border visibility by only increasing one scene's stroke width;
- allow professional prompt bars/cards/CTAs as unrelated raw layers;
- let child keyframes outlive parent ranges;
- rely on validator-only layout;
- introduce AI Director as the renderer truth;
- touch Stage5, Live Scrub, Motion Tile, Motion Blur, or unrelated FX files
  unless a later phase explicitly documents and proves the need;
- claim "super professional" until component QA and apply transaction pass.

## 9. First Slice To Execute

The first implementation slice should be:

```text
PMCR-00 + PMCR-01
```

This gives the team a failing proof and then the first real fix:

```text
global parent graph across all SceneProgram layers
```

Expected first checkpoint:

```text
checkpoint: add global scene parent graph proof
```

Minimum tests:

- cross-layer parent resolves;
- missing parent fails;
- cycle fails;
- prompt bar child can find prompt shell globally.

Only after that should the runtime tree and lifecycle propagation be built.

## 10. Why This Is The Professional Path

This plan makes ReFusion behave more like a mature UI system:

- React has components. ReFusion gets motion components.
- CSS has layout. ReFusion gets slot layout.
- Flutter has constraints. ReFusion gets component bounds and text fit.
- UI libraries have variants. ReFusion gets component contracts.
- Web apps have DOM hierarchy. ReFusion gets runtime component hierarchy.
- Motion design has beats. ReFusion gets component choreography.

The goal is not to imitate web development. The goal is to give motion scenes
the same structural intelligence that makes modern app builders feel polished.

When this plan is complete, an agent can safely write:

```json
{
  "use": "$component.PromptInputBar",
  "layout": "$layout.centeredHeroInput",
  "text": "Our smartest, fastest model",
  "motion": "$motion.promptBar.springTypeSubmit"
}
```

And the system will decide:

- exact shell size;
- exact slot positions;
- exact text size;
- exact icon alignment;
- exact border rendering;
- exact child choreography;
- exact group exit.

That is the difference between a scene drawn as layers and a scene authored as a
professional motion component.
