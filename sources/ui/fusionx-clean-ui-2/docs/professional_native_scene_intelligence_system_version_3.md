# Professional Native Scene Intelligence System - VERSION 3

Status: official VERSION 3 execution plan  
Package: `com.refusion.app`  
Branch: `codex/unified-keyframe-ops-foundation-20260426`  
Date opened: 2026-05-08  
Primary predecessors:

- `professional_native_scene_intelligence_system.md`
- `professional_native_scene_intelligence_system_version_2.md`

Scope: Hierarchical Component Tree runtime, executable component contracts,
tree layout, beat-local time, frame-evaluated QA, strict enforcement,
blueprint entry, legacy migration, determinism, visual closure, and
professional taste grammar.

## 1. Why VERSION 3 Exists

VERSION 1 and VERSION 2 built the first serious Native Scene Intelligence
foundation:

- semantic blueprints;
- design tokens;
- component registry;
- text geometry contracts;
- constraint layout MVP;
- beat grammar MVP;
- deterministic blueprint compiler MVP;
- visual QA probe MVP;
- repair loop MVP;
- `refusion-skills` scene authoring rules;
- SpeedyGraph dependency checks.

The recent SaaS/premium promo scene trials proved an important truth:

```text
Valid JSON + metadata contracts are not enough.
```

The scene still looked weak because the runtime was still effectively a flat
element list. Text, card shells, icons, cursors, labels, and groups could carry
`parentId` or `layout` metadata, but those values were not yet the universal
runtime hierarchy. That means a card could move separately from its text, text
could exceed the card, icon/button positions could drift, and visual QA could
miss a defect that happens only after animation is evaluated at a real frame.

VERSION 3 turns the system from "validated scene data" into a professional
motion runtime:

```text
Semantic Blueprint
-> Closed Tokens
-> Executable Component Registry
-> Tree Layout Solver
-> Hierarchical Component Tree
-> Beat Time Scope
-> SpeedyGraph-backed Motion
-> Frame-Evaluated Visual QA
-> Strict Apply Gate
-> Visual Closure Loop
-> Approved Editable ReFusion Scene
```

## 2. Executive Decision

The runtime truth for professional scenes must be a:

```text
Hierarchical Component Tree (HCT)
```

It must not be:

```text
Flat SceneProgram layers + parentId metadata
```

`SceneProgram` remains the editable/exportable native scene format. However,
professional authoring, validation, preview admission, and QA must compile to
and evaluate a real runtime tree where transforms, opacity, bounds, lifecycle,
time scope, and motion ownership propagate from parent to descendants.

This is the same category of professional structure used by mature tools:

- After Effects: precomps, parented layers, property inheritance.
- Apple Motion: groups and behaviors.
- Rive/Lottie: deterministic animation structures.
- Remotion: component tree and `<Sequence>` timing.

ReFusionXx must remain native. VERSION 3 uses Remotion only as a reference
model for hierarchy and time scoping, not as a renderer, dependency, HTML path,
or authoring output. Remotion documents that `<Sequence>` shifts child timing,
nested sequences cascade, and children are unmounted outside their duration:
https://www.remotion.dev/docs/sequence

## 3. Current Confirmed State

### 3.1 Completed Before VERSION 3

- `NSI-01` through `NSI-12` are closed.
- `NSI-v2-00` through `NSI-v2-10` are closed as the current semantic
  blueprint and QA foundation.
- `refusion-skills` has Native Scene Intelligence v2 guidance.
- `MotionBezierVelocityBridge` exists.
- `MotionInterpolationTruthCompiler` exists.
- SpeedyGraph bridge/truth compiler tests exist.
- SceneProgram import, semantic validation, layout contracts, text geometry,
  visual QA, and repair payloads exist in MVP form.

### 3.2 The Gap VERSION 3 Must Close

The remaining weakness is not "write a better demo script." The weakness is
architectural:

- `parentId` is metadata, not universal runtime hierarchy.
- component slots are validated, but not always evaluated as executable bounds.
- child transforms do not universally inherit parent transforms.
- child opacity/lifecycle does not universally inherit parent opacity/lifecycle.
- beat timing exists, but children do not yet live inside local beat time scopes.
- visual QA is not fully frame-evaluated from runtime world bounds.
- visible defects may still be treated as warnings in some paths.
- AI/Generate/Paste can still bypass the semantic blueprint path in legacy flows.
- weak scenes can be applied before the system proves they are visually sound.

VERSION 3 makes these defects structurally impossible for official/professional
scene authoring paths.

## 4. Non-Negotiable Rules

1. Native output only.
   - No HTML, CSS, JavaScript, React, Remotion, GSAP, browser canvas, or remote
     web runtime as the source of truth.
   - Final scenes remain editable native ReFusion scenes.

2. HCT is runtime truth.
   - No professional scene is considered complete if it only has a flat element
     list with decorative `parentId`.
   - Known components lower to runtime parent nodes, slot nodes, and child leaf
     nodes.

3. SpeedyGraph remains motion truth.
   - VERSION 3 does not rebuild Bezier/Velocity.
   - All professional semantic motion references must compile through
     `MotionInterpolationTruthCompiler`.
   - No second easing catalog, second velocity compiler, or decorative motion
     curve path is allowed.

4. Component contracts are executable.
   - A component definition is not just validation metadata.
   - It defines slots, legal children, local bounds, text policies, icon rules,
     variants, motion ownership, and lifecycle behavior.

5. Frame-evaluated QA is required.
   - QA must inspect evaluated world bounds at real probe frames.
   - Static-only position checks are insufficient.

6. Visible defects are errors.
   - Text overflow, clipping, unsafe overlap, safe-area violation, parent-child
     desync, duplicate competing channels, and unreadable hold timing must block
     professional scene acceptance.

7. Blueprint entry is enforced.
   - AI/Generate/Paste authoring must enter through semantic blueprints.
   - Raw SceneProgram remains a legacy/manual/import path only, with clear
     labeling and migration.

8. One checkpoint per phase.
   - Each phase gets focused tests.
   - Each phase is committed and pushed separately.
   - Only related files are staged.

9. Protected native preview paths stay protected.
   - Do not touch Stage5, Live Scrub, Motion Tile, Motion Blur, or unrelated FX
     files unless a phase explicitly requires it and the change is documented.

## 5. Architecture

### 5.1 High-Level Flow

```text
Agent Prompt
  -> SemanticSceneBlueprint
  -> SceneSemanticTokenRegistry
  -> SceneSemanticComponentRegistry
  -> SceneSemanticConstraintLayoutSolver
  -> SceneRuntimeComponentTree (HCT)
  -> SceneRuntimeTimeScope
  -> MotionInterpolationTruthCompiler
  -> SceneProgram + HCT source maps
  -> SceneVisualFrameQaValidator
  -> ScenePreRenderSanityGate
  -> Approved editable scene
```

### 5.2 HCT Hybrid Data Structure

VERSION 3 must use a hybrid tree/index structure:

```text
SceneRuntimeComponentTree {
  rootNode: SceneRuntimeNode
  nodeById: Map<NodeId, SceneRuntimeNode>
  parentOf: Map<NodeId, NodeId?>
  childrenOf: Map<NodeId, List<NodeId>>

  worldTransformCache: Map<NodeId, Matrix4>
  worldBoundsCache: Map<NodeId, Rect>
  effectiveOpacityCache: Map<NodeId, double>
  activeLifecycleCache: Map<NodeId, bool>

  dirtySubtrees: Set<NodeId>
}
```

Why hybrid:

- object tree gives natural traversal;
- flat index gives fast lookup by id;
- cached parent/children maps make mutation and validation deterministic;
- dirty subtree invalidation protects realtime performance.

Do not choose a purely flat parent-ref model as runtime truth. That would
repeat the current failure mode.

### 5.3 Runtime Node Types

Minimum node types:

- `sceneRoot`
- `beatScope`
- `group`
- `component`
- `slot`
- `shape`
- `text`
- `icon`
- `image`
- `video`
- `effectAttachment`

Each runtime node must carry:

- stable `nodeId`;
- optional `sourceComponentId`;
- optional `sourceLayerId`;
- optional `slotId`;
- `localTransform`;
- `localBounds`;
- optional `contentBounds`;
- local opacity;
- active time scope;
- z-order within parent;
- diagnostics source map.

### 5.4 Lifecycle Propagation Rules

These rules are mandatory:

1. Opacity composition:

```text
child.effectiveOpacity = parent.effectiveOpacity * child.localOpacity
```

2. Visibility inheritance:

```text
parent.visible == false -> all descendants invisible and not rendered
```

3. Time boundary:

```text
globalTime < parent.startsAt -> descendants inactive
globalTime > parent.endsAt   -> descendants inactive
```

4. Transform cascade:

```text
child.worldTransform = parent.worldTransform * child.localTransform
```

5. Bounds containment:

```text
child.worldBounds must fit inside parent/slot worldBounds
```

Exceptions must be explicit, named, and validated:

- `allowOverflow: true` for intentional reveal masks;
- `elevateAbove: <nodeId>` for intentional overlay;
- `clipToSlot: true` for masked text or image content.

6. Z-order:

```text
children render in component slot order unless explicit elevation is declared
```

7. Lifecycle closure:

```text
when a beat, component, or group exits, descendants exit with it
```

No child may remain visually active after its parent scope is inactive unless a
named handoff contract exists.

### 5.5 Beat Time Scoping

Every professional beat has local time:

```text
beatLocalTime = (globalTimeMs - beat.startsAtMs) / beat.durationMs
```

Rules:

- local time is clamped for evaluation, but active state is false outside the
  beat scope unless the node declares a handoff.
- children use local beat/component time for enter/hold/exit phases.
- important motion must belong to a beat.
- global timeline keyframes are allowed in lowered SceneProgram, but semantic
  authoring and HCT evaluation must keep the beat source map.

### 5.6 Professional Taste Grammar

HCT prevents broken scenes. It does not automatically create beautiful scenes.
VERSION 3 must add a professional taste layer so agents do not merely produce
valid output.

Taste grammar must cover:

- visual hierarchy: one primary focal object per beat;
- typography scale: title/body/caption ratios appropriate to aspect ratio;
- density budgets: cards, labels, and icons per frame;
- spacing rhythm: consistent gaps and safe margins;
- icon sizing relative to label/body text;
- card sizing relative to body copy and hold duration;
- camera/match-cut recipes;
- SpeedyGraph timing recipes;
- readable hold timing;
- restrained motion blur and depth;
- brand mood/tone presets.

This layer is allowed to issue warnings for taste suggestions, but violations
that cause unreadability or structural breakage must be errors.

## 6. VERSION 3 Phase Order

### NSI-v3-00 - SpeedyGraph Truth Hardening Gate

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 00 - speedygraph truth hardening
```

Purpose:

Verify that VERSION 3 depends on the existing SpeedyGraph truth path and does
not rebuild it.

Required:

- Confirm `MotionBezierVelocityBridge` and `MotionInterpolationTruthCompiler`
  are used for semantic motion compilation.
- Add or strengthen tests proving HCT/Blueprint motion references resolve to
  Bezier-backed interpolation.
- Ensure no NSI code introduces a second easing catalog or direct decorative
  cubic curve path.
- Confirm aliases and semantic recipes map to canonical SpeedyGraph presets.

Acceptance:

- Easy Ease, Slow-Fast-Slow, Fast-Slow, Slow-Fast, Fast-Slow-Fast, and custom
  SpeedGraph references compile through the truth compiler.
- Semantic motion without a known SpeedyGraph recipe fails closed.
- Diagnostic coverage includes or references:
  - `TF_SPEED_GRAPH_BRIDGE_PROOF`
  - `TF_SPEED_GRAPH_TRUTH_COMPILER_PROOF`
  - `TF_SCENE_SPEEDYGRAPH_DEPENDENCY_PROOF`

Do not:

- rebuild Bezier/Velocity;
- change protected Stage5 or Live Scrub paths;
- add a parallel easing engine.

### NSI-v3-01 - Typed Hierarchical Component Contracts

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 01 - typed hierarchical component contracts
```

Purpose:

Define the type contracts that allow semantic components to become executable
runtime tree nodes.

Required:

- Extend semantic component contracts with:
  - `runtimeNodeType`;
  - `allowedParentTypes`;
  - `slotDefinitions`;
  - `allowedChildTypes`;
  - `localBoundsPolicy`;
  - `localTransformPolicy`;
  - `lifecyclePolicy`;
  - `zOrderPolicy`;
  - `textFitPolicy`;
  - `motionOwnershipPolicy`.
- Validate:
  - no cycles;
  - no orphan required slots;
  - no child in unsupported slot;
  - no unknown variant;
  - no unsupported text overflow policy;
  - no duplicate component ids.

Initial required components:

- `PromptInputBar`
- `FeedbackCard`
- `FeatureCard`
- `DashboardPanel`
- `CTAButton`

Acceptance:

- Known components cannot lower as loose unrelated shapes/text.
- Unsupported children fail before lowering.
- Component contracts expose deterministic slot definitions.
- Existing v2 component tests continue to pass.

### NSI-v3-02 - HCT Runtime Tree Core

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 02 - hct runtime tree core
```

Purpose:

Create the native runtime tree model.

Files to create:

- `scene_runtime_node.dart`
- `scene_runtime_component_tree.dart`

Required:

- Implement the hybrid tree/index data structure.
- Add depth-first traversal.
- Add stable node id generation.
- Add source maps back to blueprint/component/layer ids.
- Add tree validation:
  - exactly one root;
  - no cycles;
  - every non-root has a parent;
  - parent/children maps are consistent;
  - tree traversal order is deterministic.

Acceptance:

- Tree construction from a component hierarchy is deterministic.
- Looking up a node by id is O(1) via index.
- Traversal order is stable across runs.
- Moving a node in the tree updates parent/children maps.

### NSI-v3-03 - Transform, Opacity, Lifecycle Composer

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 03 - transform opacity lifecycle composer
```

Purpose:

Make parent transforms, opacity, bounds, and lifecycle apply to all descendants.

Files to create:

- `scene_runtime_transform_composer.dart`
- `scene_runtime_lifecycle_rules.dart`

Required:

- Compose world transforms by matrix multiplication.
- Compose effective opacity.
- Evaluate active/inactive lifecycle by parent and beat scopes.
- Compute world bounds from local bounds and world transform.
- Support dirty subtree cache invalidation.
- Detect parent-child desync.

Acceptance:

- Translating parent moves text, icon, and shape children automatically.
- Scaling parent scales descendants consistently.
- Parent opacity affects all descendants.
- Inactive parent hides descendants.
- A child cannot visibly remain after its parent lifecycle ends.

Diagnostics:

- `TF_SCENE_HCT_COMPOSITION_PROOF`
  - `nodeId`
  - `parentId`
  - `localTransform`
  - `worldTransform`
  - `localBounds`
  - `worldBounds`
  - `effectiveOpacity`
  - `active`
  - `dirtySubtree`

### NSI-v3-04 - Executable Component Registry And Slots

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 04 - executable component registry slots
```

Purpose:

Upgrade component definitions from validation metadata to executable layout and
runtime contracts.

Required:

For each initial component, define:

- root runtime node type;
- slots;
- padding/content insets;
- legal child types;
- icon/text sizing relationship;
- min/max dimensions per aspect profile;
- variants:
  - `default`
  - `focused`
  - `loading`
  - `disabled`
  - `error`
- allowed motion recipes;
- default SpeedyGraph timing.

Required slots:

- `PromptInputBar`: `textSlot`, `accessorySlot`, optional `leadingIconSlot`
- `FeedbackCard`: `headerIconSlot`, `titleSlot`, `bodySlot`
- `FeatureCard`: `iconSlot`, `titleSlot`, `bodySlot`, optional `metricSlot`
- `DashboardPanel`: `headerSlot`, `contentSlot`, `footerSlot`
- `CTAButton`: `labelSlot`, optional `iconSlot`

Acceptance:

- Text inside a slot inherits finite slot bounds.
- Icons are sized relative to slot and typography tokens.
- Variants cannot invent unsupported overrides.
- Component registry can produce an executable slot tree for HCT.

### NSI-v3-05 - Tree Layout Solver

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 05 - tree layout solver
```

Purpose:

Compute component, slot, and child bounds before lowering to SceneProgram.

Required:

- Solve slot bounds for:
  - `fill`
  - `hug`
  - `fixed`
  - `min`
  - `max`
  - `aspectRatio`
  - horizontal/vertical stack
  - safe area
  - content insets
  - gap tokens
- Support aspect profiles:
  - `story_9_16`
  - `landscape_16_9`
  - `square_1_1`
  - `portrait_4_5`
- Emit deterministic layout hashes.
- Reject unresolved, negative, NaN, or infinite bounds.

Acceptance:

- PromptInputBar text cannot exceed its `textSlot`.
- FeedbackCard body text cannot exceed body slot.
- Card/header/icon/body spacing is deterministic.
- Same blueprint produces same solved bounds across runs.

Diagnostics:

- `TF_SCENE_TREE_LAYOUT_SOLVER_PROOF`
  - `componentId`
  - `slotId`
  - `profile`
  - `localBounds`
  - `contentBounds`
  - `layoutHash`
  - `violations`

### NSI-v3-06 - Beat Time Scoping

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 06 - beat time scoping
```

Purpose:

Make each beat a local time scope like a native version of Remotion
`<Sequence>`, with lifecycle closure.

Files to create:

- `scene_runtime_time_scope.dart`

Required:

- Compute local time for each beat and component.
- Map enter/hold/exit phases to local time ranges.
- Ensure children evaluate inside parent beat time.
- Ensure children are inactive outside parent beat unless a handoff contract is
  declared.
- Prevent multiple beats from owning the same property at the same time unless
  explicitly composed.

Acceptance:

- A beat from 1000-2200ms reports local time 0 at 1000ms and 1 at 2200ms.
- Child motion recipes use local beat time.
- Orphaned child animation after beat end is rejected.
- Readable hold timing is enforced from evaluated beat phases.

Diagnostics:

- `TF_SCENE_BEAT_TIME_SCOPE_PROOF`
  - `beatId`
  - `globalTimeMs`
  - `localTime`
  - `phase`
  - `activeNodeCount`
  - `inactiveDescendantCount`
  - `handoffContract`

### NSI-v3-07 - HCT Blueprint Compiler

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 07 - hct blueprint compiler
```

Purpose:

Compile semantic blueprints to HCT and then to editable SceneProgram while
preserving trace metadata.

Required:

- Upgrade `SceneSemanticBlueprintCompiler` to produce:
  - `SceneRuntimeComponentTree`;
  - editable `SceneProgram`;
  - source maps from blueprint ids to runtime nodes and layers;
  - deterministic compile hashes.
- Known components must lower as parent component nodes with slot children.
- SceneProgram layers may remain flat for compatibility, but the runtime source
  map must preserve HCT relationships.
- Lowered concrete values may be native numbers. Agent-facing blueprints must
  still use tokens unless explicit raw override is allowed.

Acceptance:

- A PromptInputBar blueprint produces one component root, slot nodes, text leaf,
  and accessory leaf.
- Moving component root moves slot/text/accessory during HCT evaluation.
- Lowered SceneProgram remains editable in existing UI.
- Existing v2 semantic compiler tests still pass or are migrated intentionally.

### NSI-v3-08 - Frame-Evaluated Visual QA

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 08 - frame evaluated visual qa
```

Purpose:

Replace static/proxy checks with evaluated frame probes based on HCT world
bounds and evaluated motion.

Required:

- Evaluate at up to 9 probe frames:
  - 0%
  - 12.5%
  - 25%
  - 37.5%
  - 50%
  - 62.5%
  - 75%
  - 87.5%
  - 100%
- Heavy-scene fallback may use 5 probes, but must report fallback reason.
- At each probe:
  - evaluate HCT transforms;
  - evaluate SpeedyGraph-backed keyframes;
  - compute world bounds;
  - check text bounds inside slot;
  - check clipping;
  - check sibling overlap;
  - check safe area;
  - check parent-child desync;
  - check contrast where data is available;
  - check readable hold velocity.

Acceptance:

- Text overflow that occurs only at midpoint is detected.
- A card/text desync during animation is detected.
- Static text and typewriter/reveal text are both checked.
- QA report identifies frame time, node id, component id, slot id, and suggested
  repair.

Diagnostics:

- `TF_SCENE_VISUAL_FRAME_QA_PROOF`
  - `frameIndex`
  - `frameCount`
  - `timelineTimeMs`
  - `nodeId`
  - `componentId`
  - `slotId`
  - `worldBounds`
  - `slotBounds`
  - `overflowPx`
  - `clippingPx`
  - `overlapDetected`
  - `safeAreaViolation`
  - `parentChildDesync`
  - `severity`
  - `fallbackReason`

### NSI-v3-09 - Strict Enforcement Gates

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 09 - strict enforcement gates
```

Purpose:

Move from "infrastructure exists" to "bad scenes cannot be applied."

Required:

- Visual defects are errors by default:
  - text overflow;
  - clipping;
  - unsafe overlap;
  - safe-area violation;
  - duplicate competing property channels;
  - parent-child desync;
  - unreadable hold;
  - unsupported component/slot/lifecycle contract.
- Remove or disable "Valid with warnings" as an apply path for visual defects.
- Add a pre-render sanity gate before SceneProgram apply transaction completes.
- Block apply if HCT or frame QA fails.
- Keep non-blocking warnings only for taste/performance suggestions that do not
  break readability or geometry.

Files to modify:

- `scene_visual_frame_qa_validator.dart`
- `scene_program_import_bottom_sheet.dart`
- `scene_program_apply_transaction.dart`

File to create:

- `scene_pre_render_sanity_gate.dart`

Acceptance:

- Bad SaaS scene with loose card/text fails before apply.
- UI shows structured errors, not green "valid" messaging.
- No "render anyway" path exists for professional scene authoring.
- Pre-render sanity catches violations even if earlier validation was bypassed.

Diagnostics:

- `TF_SCENE_PRE_RENDER_GATE_PROOF`
  - `sceneId`
  - `hctValid`
  - `frameQaValid`
  - `blocked`
  - `issueCount`
  - `fallbackReason`

### NSI-v3-10 - Blueprint Entry Enforcement And Legacy Migration

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 10 - blueprint entry legacy migration
```

Purpose:

Ensure AI/Generate/Paste paths use the semantic blueprint pipeline, while
existing legacy projects remain manageable.

Required:

- In AI/Generate/Paste flows:
  - parse as semantic blueprint first;
  - compile blueprint to HCT + SceneProgram;
  - run HCT and frame QA gates;
  - reject unsupported raw agent output with actionable guidance.
- Raw SceneProgram path:
  - allowed for manual legacy import/debug;
  - clearly labeled as legacy;
  - subject to compatibility checks;
  - not marketed as professional AI authoring path.
- Create `scene_legacy_to_blueprint_migrator.dart`.

Migration tiers:

- Tier A: auto-convert known component-like raw scenes.
- Tier B: produce draft blueprint plus human review.
- Tier C: preserve as legacy with warning and deprecation marker.
- Tier D: reject raw SceneProgram from AI/production authoring.

Acceptance:

- Agent-authored raw SceneProgram is blocked in professional path.
- Blueprint-authored scene is accepted when valid.
- Existing presets do not disappear.
- Migrated known PromptInputBar/FeedbackCard structures become components.

Diagnostics:

- `TF_SCENE_BLUEPRINT_ENTRY_PROOF`
  - `inputKind`
  - `parsedAsBlueprint`
  - `legacyMode`
  - `migrationTier`
  - `blocked`
  - `reason`

### NSI-v3-11 - Determinism Validator

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 11 - determinism validator
```

Purpose:

Guarantee that the same blueprint produces the same HCT, SceneProgram, and
geometry outputs.

File to create:

- `scene_determinism_validator.dart`

Required:

- Canonical blueprint hash.
- Canonical HCT hash.
- Canonical SceneProgram hash.
- Canonical layout/geometry hash per probe frame.
- Stable id generation.
- Stable traversal order.
- Stable token resolution order.
- Reject non-deterministic maps/lists where order matters.

Acceptance:

- Same blueprint compiled 100 times produces identical HCT and SceneProgram
  hashes.
- Same blueprint frame QA probes produce identical geometry hashes.
- Floating point drift is bounded and normalized.
- Cross-device pixel hash is deferred unless Stage5 integration is explicitly
  approved.

Diagnostics:

- `TF_SCENE_DETERMINISM_PROOF`
  - `blueprintHash`
  - `hctHash`
  - `sceneProgramHash`
  - `geometryProbeHashes`
  - `drift`
  - `passed`

### NSI-v3-12 - Visual Closure Loop MVP

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 12 - visual closure loop mvp
```

Purpose:

Turn validation failures into structured repair data that an agent, deterministic
repair function, or human can act on.

File to create:

- `scene_visual_closure_loop_service.dart`

Required:

- Convert HCT/frame QA issues to repair payloads:
  - error code;
  - component id;
  - node id;
  - slot id;
  - frame time;
  - measured bounds;
  - expected bounds;
  - suggested repair action.
- Provide deterministic repairs first:
  - enable `shrinkToFit`;
  - increase slot width within safe bounds;
  - lower typography token;
  - increase hold duration;
  - move child into correct slot;
  - convert loose elements to component slots where possible.
- Limit closure loop to 3 attempts.
- If still failing, mark for human review with a concise issue report.

Acceptance:

- A scene with text overflow gets a machine-readable repair suggestion.
- A loose text/card pair can be suggested for component conversion.
- Loop stops after max attempts.
- Successful repair emits approved HCT and SceneProgram hashes.

Diagnostics:

- `TF_SCENE_VISUAL_CLOSURE_LOOP_PROOF`
  - `attempt`
  - `issueCountBefore`
  - `issueCountAfter`
  - `repairActions`
  - `approved`
  - `escalated`

### NSI-v3-13 - Professional Taste And Scene Grammar Pack

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 13 - professional taste grammar
```

Purpose:

Raise scene quality from merely valid to visually intentional and modern.

Required:

- Add a professional taste grammar service or ruleset covering:
  - focal hierarchy;
  - card density;
  - typography ratios;
  - icon/text scale relationship;
  - background contrast;
  - motion pacing;
  - cut/match-cut timing;
  - camera movement budgets;
  - SpeedyGraph recipe recommendations;
  - readable hold duration by text length;
  - aspect-aware composition.
- Add exemplar references for:
  - SaaS launch;
  - app promo;
  - dashboard reveal;
  - feedback cards;
  - prompt-to-result workflow.
- Add good/bad examples to `refusion-skills`.
- Make taste defects warnings unless they affect readability or geometry.

Acceptance:

- A valid but weak scene receives actionable taste suggestions.
- Scene grammar can recommend component replacements.
- Skills repo teaches agents to use HCT, components, slots, beats, and
  SpeedyGraph.
- The old "write arbitrary shapes and hope" authoring style is explicitly
  deprecated.

Diagnostics:

- `TF_SCENE_TASTE_GRAMMAR_PROOF`
  - `sceneId`
  - `profile`
  - `focalScore`
  - `densityScore`
  - `typeScaleScore`
  - `motionPacingScore`
  - `suggestions`

### NSI-v3-14 - Closure QA

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v3 14 - closure qa
```

Purpose:

Close VERSION 3 with verification, documentation status, build, and device
installation when available.

Required tests:

- SpeedyGraph dependency tests.
- HCT tree construction tests.
- transform/opacity/lifecycle tests.
- executable component registry tests.
- tree layout solver tests.
- beat time scope tests.
- HCT blueprint compiler tests.
- frame-evaluated visual QA tests.
- strict enforcement gate tests.
- legacy migration tests.
- determinism tests.
- visual closure loop tests.
- taste grammar tests.
- SaaS regression fixture:
  - old loose raw scene fails professional path;
  - migrated/blueprint scene passes.

Required build:

```text
flutter build apk --debug
```

Required install:

- Install on connected wireless Android device when available.
- If no device is connected, report clearly and do not fake install success.

Plan update:

- Mark `NSI-v3-00` through `NSI-v3-14` status.
- Include commit hashes.
- Include known risks.
- Include rollback commands.

## 7. Files To Create

Expected new files:

- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/scene_runtime_node.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_runtime_component_tree.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_runtime_transform_composer.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_runtime_lifecycle_rules.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_runtime_time_scope.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_pre_render_sanity_gate.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_legacy_to_blueprint_migrator.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_determinism_validator.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_visual_closure_loop_service.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_professional_taste_grammar.dart`
- `sources/ui/fusionx-clean-ui-2/test/scene_runtime_component_tree_test.dart`
- `sources/ui/fusionx-clean-ui-2/test/scene_runtime_transform_composer_test.dart`
- `sources/ui/fusionx-clean-ui-2/test/scene_runtime_time_scope_test.dart`
- `sources/ui/fusionx-clean-ui-2/test/scene_pre_render_sanity_gate_test.dart`
- `sources/ui/fusionx-clean-ui-2/test/scene_legacy_to_blueprint_migrator_test.dart`
- `sources/ui/fusionx-clean-ui-2/test/scene_determinism_validator_test.dart`
- `sources/ui/fusionx-clean-ui-2/test/scene_visual_closure_loop_service_test.dart`
- `sources/ui/fusionx-clean-ui-2/test/scene_professional_taste_grammar_test.dart`
- `sources/ui/fusionx-clean-ui-2/test/scene_runtime_performance_test.dart`

## 8. Files To Modify

Expected existing files:

- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/scene_semantic_blueprint_models.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_semantic_component_registry.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_semantic_constraint_layout_solver.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_semantic_blueprint_compiler.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_visual_frame_qa_validator.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/refusion_scene_program_authoring_service.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/kie_scene_program_agent_service.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/services/scene_program_apply_transaction.dart`
- `sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/scene_program_import_bottom_sheet.dart`
- `sources/ui/fusionx-clean-ui-2/docs/professional_native_scene_intelligence_system_version_3.md`
- `/Users/mx/Documents/refusion-skills` docs and generated skill bundle during
  `NSI-v3-13`.

## 9. Performance Budgets

VERSION 3 must not trade visual correctness for jank.

Mandatory budgets:

- HCT composition:
  - 100 nodes <= 1ms
  - 500 nodes <= 4ms
  - dirty subtree recomposition only when possible
- Frame-evaluated QA:
  - 9 probes <= 800ms total for normal scenes
  - fallback to 5 probes for heavy scenes with explicit fallback reason
- Visual closure loop:
  - structured error generation <= 100ms
  - max 3 attempts
- Realtime preview fast path:
  - drag/update to visible pixel target <= 16ms for supported operations
- Typical scene HCT memory:
  - target < 2MB

Performance tests must use practical budgets without introducing flaky tests.
If CI variance makes strict timing unreliable, tests should assert algorithmic
behavior and log measured timings while a manual profiling task verifies hard
budgets.

## 10. Regression Fixtures

VERSION 3 must keep these fixtures:

1. Bad SaaS loose-card scene.
   - Raw/professional path must fail.
   - Migrated HCT blueprint must pass.

2. Premium app promo.
   - Must author through semantic blueprint/HCT.
   - PromptInputBar text follows parent.
   - icon/button/text are bounded and synchronized.

3. Feedback cards.
   - Gmail/Slack/WhatsApp/Frame style cards must use `FeedbackCard`.
   - Header icon/title/body slots must stay aligned.
   - Body text must fit or apply approved text fit policy.

4. Orbital feature scene.
   - Orbit group owns child dots and labels.
   - Parent rotation/lifecycle controls children.

5. Prompt-to-result workflow.
   - App icon morph, input bar, typed prompt, result card, and CTA must be
     component-scoped and beat-scoped.

## 11. Final Acceptance Criteria

VERSION 3 is complete only when:

- official AI/Generate/Paste scenes enter through semantic blueprint;
- known components lower to HCT;
- parent movement visibly moves children;
- parent opacity and lifecycle affect descendants;
- beat-local time controls children;
- text cannot exceed its slot in accepted professional scenes;
- loose raw SceneProgram from agents is blocked or migrated;
- frame-evaluated QA catches midpoint defects;
- visible defects are errors;
- pre-render gate blocks violations before apply;
- same blueprint compiles deterministically;
- visual closure produces repair payloads;
- professional taste grammar gives actionable quality feedback;
- focused tests pass;
- debug APK builds;
- APK is installed when a device is connected.

## 12. Stop List

Do not:

- build another one-off SaaS scene as a substitute for VERSION 3;
- create a second easing or velocity system;
- rebuild `MotionBezierVelocityBridge`;
- rebuild `MotionInterpolationTruthCompiler`;
- use HTML, React, Remotion, GSAP, or browser output;
- treat `parentId` metadata as enough;
- keep flat element list as runtime truth for professional scenes;
- allow static-only visual QA to certify animated scenes;
- classify visible defects as warnings;
- keep "render anyway" for professional visual defects;
- accept raw SceneProgram from AI production paths;
- add many components before the first five components work perfectly;
- touch protected Stage5/Live Scrub files without explicit documented approval;
- stage unrelated screenshots, diagnostics, seam files, or unrelated FX work.

## 13. Deferred Beyond VERSION 3

These are important but not part of VERSION 3 closure:

- direct Stage5 native HCT rendering path;
- pixel-perfect cross-platform render hashes;
- full 3D camera/depth hierarchy;
- large component catalog beyond the initial core set;
- collaborative editing;
- nested reusable scene precomps;
- fully autonomous external AI provider loop;
- advanced spatial path editor.

VERSION 3 should prepare these features, not overreach into them.

## 14. Instruction For The Agent Writer

Start with `NSI-v3-00`. Work phase by phase. Do not skip ahead.

For each phase:

1. Read this plan and the checkpoint policy.
2. Check `git status -sb`.
3. Ignore unrelated untracked screenshots/diagnostics/seam files.
4. Implement only the phase scope.
5. Add focused tests.
6. Run the smallest relevant verification.
7. Stage only focused files.
8. Commit with the exact checkpoint message for the phase.
9. Push `codex/unified-keyframe-ops-foundation-20260426`.
10. Report rollback command:

```text
git -C /Users/mx/Documents/ReFusionXx revert <commit>
```

Do not claim VERSION 3 improves scene quality until `NSI-v3-09` is complete.
Before that point, the system may contain good infrastructure but still allow
bad scenes through legacy paths.

Do not author another proof scene as a substitute for runtime hierarchy. New
scenes become meaningful only after HCT, frame-evaluated QA, and strict gates
are active.

