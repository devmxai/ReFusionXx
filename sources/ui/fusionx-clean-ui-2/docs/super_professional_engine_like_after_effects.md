# Super Professional Engine like After Effects

Status: official capability-growth plan  
Package: `com.refusion.app`  
Purpose: grow ReFusion from prompt/script scene generation into a disciplined
professional motion engine inspired by After Effects, without copying After
Effects internals or adding one-off tutorial hacks.

## 1. Core Rule

Every tutorial transcript, prompt, or external motion reference must be treated
as source material for reusable engine capability.

Do not implement a tutorial as a closed preset.

Do extract the reusable motion grammar:

```text
tutorial transcript
-> technique extraction
-> capability proposal
-> capability registry entry
-> schema/model support
-> compiler/lowerer support
-> preview/export readiness or explicit blocker
-> agent documentation
-> validation fixtures
-> optional Present demo scene
```

The result must be a reusable tool that can appear in future scenes, prompts,
motion patches, and manual scoped timelines.

## 2. Capability Registry Taxonomy

Every capability must live in one official category. This prevents effect
sprawl and keeps the UI, agent docs, and engine aligned.

```text
Transform
  position
  scale
  rotation
  anchorPoint
  opacity

Text
  typewriter
  wordReveal
  letterReveal
  rangeSelector
  tracking
  lineReveal

Shape
  size
  cornerRadius
  fill
  stroke
  morph

Mask
  maskPath
  maskFeather
  maskExpansion
  invertedMask
  movingMaskReveal

Effects
  blur
  shadow
  glow
  tint
  gradientRamp
  noise

Layout
  alignCenter
  safeArea
  padding
  gap
  align
  justify
  readableHold

Composition
  precompose
  parentGroup
  nullTransform
  adjustmentLayer

Choreography
  beat
  handoff
  leaderFollower
  completionPolicy
  contrastPolicy
```

When a new tutorial uses a capability such as `scale`, it must be registered
under `Transform`, not as a new random effect. When a tutorial uses a soft
blurred ellipse under text, the reusable capability is `Effects > Shadow`, not
`Design Tutorial Shadow`.

## 3. Capability Entry Contract

Each capability must be documented with this shape before it is advertised to
agents:

```text
id
category
professionalName
aliases
supportedTargets
parameters
defaultTiming
defaultEasing
editableInScope
previewSupport
exportSupport
sceneProgramSyntax
directorPrimitiveSyntax
motionPatchSyntax
validationRules
unsupportedCases
goldenExamples
status
```

Allowed status values:

```text
planned
documented
implemented-domain
preview-ready
export-ready
blocked
```

No capability may be described as supported unless the registry says where it is
supported and how it is evaluated.

## 4. Tutorial Intake Protocol

For every tutorial the user sends as text:

1. Preserve the raw transcript under a tutorial note or issue.
2. Identify the visual goal.
3. List every tool used by the tutorial.
4. Map each tool to an existing registry capability or propose a new one.
5. Mark tutorial-specific steps as examples only.
6. Identify preview and export gaps.
7. Choose the smallest reusable implementation slice.
8. Add or update agent documentation.
9. Add validation fixtures.
10. Add a Present demo only after the underlying capabilities are real.

## 5. Professional Choreography Rules

Agents must not create random simultaneous keyframes.

Every generated scene should follow a Director-first shape:

```text
enter
-> reveal
-> readable hold
-> action / transformation
-> exit or transition
```

Strict rules:

- A scene may not end before all child animations finish.
- Important text must have a readable hold unless the user explicitly asks for
  fast kinetic typography.
- Text color must contrast with the resolved background during its readable
  window.
- Two primitives may not animate the same target/property at the same time
  unless a merge/blend rule is explicit.
- A transition may not consume the readable hold of the previous beat unless the
  Director Plan says so.
- A handoff between two motions must be modeled as a beat dependency, not as
  accidental overlap.
- Every generated layer/element must remain editable through Scene Scope and
  Layer Scope.

## 6. Present Library

`Present` is the user-facing demo library for capability validation.

It is not the raw JSON/script import path.

Use `Scene` for:

- paste JSON;
- upload JSON;
- live full-scene generation.

Use `Present` for:

- curated demo scenes;
- tutorial-derived capability examples;
- regression-safe visual checks;
- showing a named motion result without asking the user to paste JSON.

Every Present item must point to real Scene Program data and must be safe to
apply as an editable Scene Clip.

## 7. Required First Capability Packs

The first tutorial-derived packs should be:

### AE Typography Pack V1

- `text.rangeSelector`
- `text.trackingSettle`
- `mask.movingReveal`
- `shape.morphCircleRect`
- `effects.softShadow`
- `effects.gradientRamp`
- `choreography.leaderFollower`
- `choreography.completionPolicy`

### UI Promo Pack V1

- `promptInputBar`
- `buttonPress`
- `typewriterText`
- `circleCoverTransition`
- `readableHold`
- `contrastPolicy`

## 8. Tutorial Intake Log

Every tutorial intake must have its own note under `docs/tutorial_intakes/`.

Current intakes:

- `docs/tutorial_intakes/design_reveal_tutorial_001.md`: extracts the first
  design-title reveal tutorial into reusable capabilities such as
  `mask.movingReveal`, `shape.morphCircleRect`, `effects.softShadow`, and
  `choreography.leaderFollower`, plus planned capabilities such as
  `effects.gradientRamp`, `text.rangeSelector`, and `choreography.snappyEase`.
  The Present demo `Design Reveal Study` is an approximation built only from
  already-supported Scene Program capabilities, so the gap between current
  engine support and full After Effects-style parity remains explicit.

## 9. Capability Status Notes

### `effects.softShadow`

Category: Effects

Professional name: Soft Shadow / Drop Shadow

Supported targets: shape and icon Scene Program elements

Scene Program properties:

```text
shadowOpacity
shadowBlur
shadowOffset / shadowOffsetX / shadowOffsetY
shadowSpread
shadowColor
```

Aliases:

```text
softShadowOpacity, dropShadowOpacity
softShadowBlur, dropShadowBlur
softShadowOffset, dropShadowOffset
softShadowColor, dropShadowColor
```

Status:

```text
implemented-domain: yes
editableInScope: scalar controls for shapes
previewSupport: shape/icon preview
exportSupport: blocked until authored visual native compositor parity
```

Rules:

- use shadow for reusable UI depth, not tutorial-specific fake ellipses;
- shadow timing must follow the same enter/hold/exit choreography as the owning
  component;
- do not describe text shadows as supported yet;
- if a scene needs export-perfect shadows, mark the current export limitation
  instead of pretending parity is complete.

### `shape.trimPath`

Category: Shape

Professional name: Trim Paths / Line Reveal

Supported targets: `shapeKind: "line"` Scene Program elements

Scene Program properties:

```text
trimStart
trimEnd
trimOffset
```

Aliases:

```text
lineReveal, lineRevealProgress, trimPathEnd
trimPathStart, lineTrimStart
trimPathOffset, lineTrimOffset
```

Status:

```text
implemented-domain: yes
editableInScope: scalar controls for shapes
previewSupport: line reveal preview
exportSupport: blocked until authored visual native compositor parity
```

Rules:

- animate `trimEnd` from `0` to `1` for a clean horizontal line reveal;
- accepted values may be normalized `0..1` or percent-like `0..100`;
- do not fake trim paths by generating many small rectangles;
- circular progress, arcs, dashed paths, and wraparound offset are still future
  renderer work.

### `text.rangeSelector`

Category: Text

Professional name: Text Range Selector / Word Reveal / Character Reveal

Supported targets: text Scene Program elements

Scene Program properties:

```text
wordRangeSelectorProgress
letterRangeSelectorProgress
rangeSelectorProgress
trackingAmount
```

Aliases:

```text
rangeSelector, rangeSelectorStart
wordRangeSelector, wordRangeSelectorStart
letterRangeSelector, letterRangeSelectorStart
characterRangeSelector, charRangeSelector
tracking, textTracking
```

Status:

```text
implemented-domain: yes
editableInScope: revealProgress and letterSpacing controls for text
previewSupport: text preview resolves word/letter visible text
exportSupport: existing text motion export path for reveal/letterSpacing
```

Rules:

- use `wordRangeSelectorProgress` for After Effects-style animate-by-words
  title reveals;
- use `letterRangeSelectorProgress` for character-by-character reveals that are
  not keyboard typing;
- use `typewriterProgress` for keyboard typing;
- use `trackingAmount` to animate AE tracking from tight/wide spacing back to
  the final readable typography.

### `composition.parentGroup`

Category: Composition

Professional name: Parent Group / Container Relationship

Supported targets: Scene Program elements through metadata

Scene Program metadata properties:

```text
parentId
containerId
parentGroup
layoutRole
layoutMode
padding
gap
align
justify
anchor
safeArea
constraints
zIndex
```

Status:

```text
implemented-domain: yes
editableInScope: metadata preserved for future scope adapters
previewSupport: blocked until inherited group transforms are evaluated
exportSupport: blocked until authored visual compositor consumes parent metadata
```

Rules:

- use parent metadata to describe a designed UI hierarchy, not fixed ready-made
  cards;
- every `parentId` must reference a real element in the same Scene Program;
- parent chains may not contain cycles;
- a child layer's lifetime must stay inside the parent layer's lifetime;
- parent elements should declare `layoutRole: "container"` or
  `layoutRole: "group"` so future UI, mention, and export adapters can inspect
  the composition cleanly;
- do not claim inherited group transforms are active until the runtime
  evaluator consumes this metadata.

## 10. Non-Negotiable Safety

This plan does not modify Live Scrub directly.

Protected native Live Scrub paths remain off-limits unless the user explicitly
asks for a specific Live Scrub fix.

Every implementation slice must follow:

- `docs/professional_checkpoint_policy.md`
- `docs/professional_refusion_motion_keyframe_engine.md`
- focused verification
- focused checkpoint commit
- push to GitHub
