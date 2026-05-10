# Professional Component Render Truth Repair Plan

Status: execution plan  
Scope: root repair for PromptInputBar and every professional component that must
render with correct size, border, icons, text fit, parent-child behavior, and
pixel-level proof.

## 0. Executive Decision

The current failure is not a single bad scene. It is a render-truth gap:

```text
Component contract / SceneProgram says:
  prompt bar has shell, border, icons, text slot, button, lifecycle

Preview/render currently proves:
  some of those contracts are metadata only, or are evaluated in a different
  place than the pixels actually drawn on screen.
```

The fix is a focused repair layer before any more scene authoring:

```text
Intrinsic component sizing
  -> slot layout from component bounds
  -> stroke/icon/text lowering parity
  -> parent transform/lifecycle parity
  -> pre-render proof
  -> pixel regression
```

This plan extends the six-point diagnosis with the strongest addition from the
latest review: professional components must declare intrinsic size. That review
is directionally correct. However, intrinsic size alone is not enough because
the current preview renderer also ignores border properties and does not fully
consume parent/child render truth. Therefore this plan fixes both:

1. component size truth;
2. render contract truth.

## 1. Final Root Cause Model

The PromptInputBar failure is caused by a cascade:

1. Professional components do not have a mandatory intrinsic size contract.
2. Slot layout can fall back to oversized container/canvas geometry or manual
   raw dimensions.
3. Proportional typography can use the wrong container if component bounds are
   not explicit.
4. Borders are present in SceneProgram JSON but not rendered by the current
   preview decoration path.
5. Icons are represented inconsistently across authoring and rendering paths.
6. `parentId` can be validated as metadata while preview/render still draw
   children with direct positions.
7. Tests validate import/QA but do not require the exact pixels: shell border,
   icon placement, text fit, and group lifecycle.

The professional rule is:

```text
If a component exists in the professional registry, every renderer must draw it
from the same component truth. Metadata-only success is failure.
```

## 2. Non-Negotiable Rules

1. No professional component may be resolved without `intrinsicSize`.
2. No professional component may silently fall back to `fillContainer`.
3. No `borderColor`, `borderWidth`, `strokeColor`, or `strokeWidth` contract may
   pass validation unless the active renderer consumes it.
4. Icons must use one normalized render contract across SceneProgram, lowerer,
   preview, evaluation, and export.
5. Children must inherit parent transform, opacity, visibility, and lifetime in
   the render path, not only in QA.
6. Text size must be computed from text slot and component intrinsic height, not
   from canvas height.
7. The PromptInputBar proof must fail if the shell is canvas-sized, borderless,
   iconless, or text-only.
8. No new present scene should be used as proof until this plan passes.

## 3. Phase Plan

### PCTR-00 - Failure Fixture And Pixel Baseline

Goal: freeze the current bug so the repair cannot be cosmetic.

Required work:

- add a PromptInputBar fixture matching the current requested reference:
  white background, pill shell, plus icon, prompt text, mic icon, circular audio
  button, typewriter cursor;
- create a failing test that evaluates the scene at the hold frame;
- capture or compute required frame facts:
  - shell is not canvas-sized;
  - shell border is visible;
  - plus icon is inside left slot;
  - mic icon is inside trailing area;
  - audio button is inside right slot;
  - text is inside text slot;
  - font height is proportionate to bar height;
  - children do not outlive shell.

Acceptance:

```text
PromptInputBar fixture must fail before the repair.
Failure must name the exact contract: size, border, icon, text, or lifecycle.
```

### PCTR-01 - Intrinsic Component Size Contract

Goal: every professional component declares its natural size.

PromptInputBar contract:

```text
intrinsicSize:
  width:
    mode: adaptive
    min: 640
    preferred: 972
    max: 1020
    aspectAware:
      vertical9x16: 0.90 * canvasWidth
      square1x1: 0.74 * canvasWidth
      horizontal16x9: 0.48 * canvasWidth
  height:
    mode: fixed
    value: 96
```

Required work:

- add intrinsic size to PromptInputBar runtime component definition;
- add intrinsic size to FeatureCard and CTAButton while touching the registry;
- make missing intrinsic size fatal for professional registry components;
- make `fillContainer` opt-in only, never a silent fallback.

Acceptance:

```text
PromptInputBar shell width < 0.95 * canvasWidth.
PromptInputBar shell height == 96 at the hold frame.
No professional component resolves size from canvas unless explicitly declared.
```

### PCTR-02 - Slot Layout From Intrinsic Bounds

Goal: children are placed from component-local slots, not raw canvas positions.

PromptInputBar slot rules:

```text
shell:
  bounds: intrinsicSize
  radius: height / 2

leadingIconSlot:
  width: 88
  centerX: shell.left + 66
  centerY: shell.centerY

textSlot:
  left: leadingIconSlot.right + 26
  right: micSlot.left - 36
  height: 58
  centerY: shell.centerY

micSlot:
  width: 64
  centerX: sendButtonSlot.left - 46

sendButtonSlot:
  size: 72
  centerX: shell.right - 58
  centerY: shell.centerY
```

Required work:

- resolve child local bounds from slots;
- write world bounds through parent transform composition;
- reject prompt bar children with raw positions when slot exists;
- expose `PCTR_SLOT_LAYOUT_PROOF`.

Acceptance:

```text
plusIcon.bounds is contained by leadingIconSlot.
promptText.bounds is contained by textSlot.
micIcon.bounds is contained by micSlot.
audioButton.bounds is contained by sendButtonSlot.
```

### PCTR-03 - Stroke And Border Render Parity

Goal: a border in the contract must become pixels.

Required work:

- lower `borderColor`, `borderWidth`, `strokeColor`, and `strokeWidth` into
  MotionProperty definitions or normalized visual metadata consumed by preview;
- update the preview shape decoration path to draw `Border.all(...)`;
- make Stage/preview/export adapters consume the same stroke fields where
  applicable;
- make `SceneShapeStrokeContract` compare against actual evaluated/rendered
  stroke truth, not only JSON metadata;
- expose `PCTR_STROKE_RENDER_PROOF`.

Acceptance:

```text
PromptInputBar shell border >= 1px effective width.
Border color contrast against background is above visible threshold.
No shape with required border may pass if renderer cannot consume border.
```

### PCTR-04 - Single Icon Render Contract

Goal: icons never disappear because different layers speak different icon
formats.

Required decision:

```text
Canonical icon leaf:
  kind: "shape"
  asset.icon: "<normalized-core-icon-id>"
```

Compatibility:

- `kind: "icon"` is accepted at import but lowered immediately to canonical
  shape icon form;
- unsupported icon id is an error for professional components, not a fallback
  glyph;
- `plus`, `mic`, `volume`, `send`, `paperclip`, `search`, `play`, `pause`,
  `arrow-up`, `arrow-right`, `check`, and `close` must be seeded and tested.

Required work:

- normalize icon authoring in the lowerer;
- keep the core icon registry and preview icon map in parity;
- add a test that fails if an icon becomes `sparkles` or a fallback glyph inside
  a professional component;
- expose `PCTR_ICON_RENDER_PROOF`.

Acceptance:

```text
PromptInputBar plus, mic, and audio icons are visible at the hold frame.
All three icons are inside their slots.
No fallback glyph is rendered.
```

### PCTR-05 - Parent Transform, Opacity, And Lifecycle Render Parity

Goal: parent/child truth exists in pixels, not only diagnostics.

Required work:

- make preview/render consume evaluated parent graph or the same
  `EvaluatedFrameTruth` composition result;
- apply:
  - `child.worldTransform = parent.worldTransform * child.localTransform`;
  - `child.effectiveOpacity = parent.effectiveOpacity * child.localOpacity`;
  - `child.active = parent.active && child.localActive`;
- reject children whose time range exceeds parent time range unless a validated
  detach override exists;
- expose `PCTR_PARENT_RENDER_PROOF`.

Acceptance:

```text
If prompt shell opacity is 0, every child effective opacity is 0.
If prompt shell exits, plus/text/mic/button do not remain visible.
Moving/scaling prompt shell moves/scales all children coherently.
```

### PCTR-06 - Container-Aware Text Measurement

Goal: text size is professional by construction.

Required rules:

```text
PromptInputBar.text.fontSize:
  preferred: clamp(28, shell.height * 0.32, 32)
  max: shell.height * 0.36
  min: 22

PromptInputBar.textFrame:
  width: textSlot.width
  height: textSlot.height
  maxLines: 1
  fitPolicy: shrinkToFit
  overflow: clip only after fit succeeds
```

Required work:

- compute font size from component intrinsic height, not canvas height;
- measure full text before typewriter reveal;
- shrink to fit before render;
- reject if text still overflows after min font size;
- expose `PCTR_TEXT_FIT_PROOF`.

Acceptance:

```text
Prompt text height is within [22, 34].
Full prompt text fits the text slot after shrink.
Typewriter reveal never draws outside the text frame.
```

### PCTR-07 - Unified PromptInputBar Component Proof

Goal: remove split-object tricks.

Required work:

- replace separate `morphShell` + `promptFrame` patterns with one component
  shell that morphs from circle to pill and remains the parent for children;
- children start only after the shell has real pill bounds;
- internal choreography:
  - shell spring pop;
  - width spring morph;
  - plus/mic/button pop in;
  - text typewriter;
  - cursor blink or hold;
- no QA-only visible shell may be rendered.

Acceptance:

```text
The same shell id is used for morph, hold, parent graph, border, and children.
The scene does not contain duplicate visible prompt-bar shells.
```

### PCTR-08 - Pre-Render Strict Gate

Goal: a bad component cannot reach the user.

Fatal errors:

- `COMPONENT_INTRINSIC_SIZE_MISSING`;
- `COMPONENT_SIZED_AS_CANVAS`;
- `BORDER_CONTRACT_NOT_RENDERED`;
- `ICON_CONTRACT_NOT_RENDERED`;
- `TEXT_EXCEEDS_TEXT_SLOT`;
- `CHILD_OUTLIVES_PARENT`;
- `RAW_CHILD_POSITION_INSIDE_KNOWN_COMPONENT`;
- `PROMPT_BAR_SPLIT_SHELL_FRAME`.

Acceptance:

```text
Current bad prompt bar fixture is rejected before render.
Corrected prompt bar fixture passes.
```

### PCTR-09 - Pixel Regression And Device Verification

Goal: prove the actual screen, not only JSON.

Required work:

- render/capture hold-frame thumbnail;
- assert simple pixel facts:
  - non-white border exists around pill boundary;
  - left icon dark pixels exist inside leading slot;
  - mic icon dark pixels exist inside mic slot;
  - audio button circle has visible contrast;
  - text does not cross slot right edge;
- install on connected device only after tests pass;
- save before/after screenshots as diagnostic artifacts.

Acceptance:

```text
Prompt bar reference scene appears with shell, border, icons, text, cursor,
and correct proportions on device.
```

## 4. Implementation Order

Do not reorder:

1. `PCTR-00` failure fixture.
2. `PCTR-01` intrinsic size.
3. `PCTR-02` slot layout.
4. `PCTR-03` stroke render parity.
5. `PCTR-04` icon render parity.
6. `PCTR-05` parent render parity.
7. `PCTR-06` text measurement.
8. `PCTR-07` unified component proof.
9. `PCTR-08` strict gate.
10. `PCTR-09` pixel/device proof.

Rationale:

- Size must be correct before slots.
- Slots must be correct before text and icons.
- Stroke/icon render parity must be proven before visual approval.
- Parent parity must be proven before choreography.
- Pixel proof must come after strict gates.

## 5. Stop List

Do not:

- write another present scene as a workaround before `PCTR-00` through `PCTR-08`;
- solve this by manually moving plus/mic/text coordinates;
- keep `morphShell` and `promptFrame` as two visible prompt bars;
- allow `fillContainer` fallback for known professional components;
- allow icon fallback glyphs inside professional components;
- accept a border contract that only exists in JSON;
- use canvas height to compute prompt input text size;
- claim success from import tests without a rendered hold-frame proof;
- touch protected Live Scrub or Stage5 handoff files unless the exact change is
  separately approved.

## 6. Definition Of Done

This plan is done only when:

- the bad PromptInputBar fixture fails before repair;
- the corrected PromptInputBar fixture passes strict gate;
- the same shell performs morph, hold, border render, and parent lifecycle;
- all icons render inside slots;
- text is measured, fitted, and visually proportionate;
- children inherit parent transform, opacity, and lifecycle in preview;
- a captured device screenshot matches the requested prompt bar structure;
- no legacy present scene is used as proof;
- the final scene can be selected from Present without `Scene program could not
  be applied`.

