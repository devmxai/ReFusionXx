# Professional Motion Visual Harmony Runtime Plan

Status: execution plan  
Short name: PMVHR  
Scope: the visual harmony layer that makes ReFusion motion components render
with professional typography, icon ratios, cursor behavior, text fitting, and
component-aware proportions on the real device, not only in validators.

## 0. Executive Decision

The current PromptInputBar scene is no longer failing because the preset cannot
be applied. It now fails at a deeper quality layer:

```text
SceneProgram imports and applies.
Prompt bar shell, border, plus, mic, send, and text appear.
But the text renderer, caret, and component ratios are not yet professional.
```

The missing layer is **Visual Harmony Runtime**:

```text
SceneProgram JSON
  -> EvaluatedFrameTruth
  -> MotionText Render Truth
  -> Component Ratio Rules
  -> Expression Bindings
  -> Visual Harmony QA
  -> Device Pixel Acceptance
```

This plan must be executed before writing more demo scenes. Any new scene will
repeat the same visual problems if the renderer and component harmony contracts
remain weak.

## 1. Current Failure Model

The latest device screenshot proves these facts:

1. The prompt shell exists and no longer fills the canvas.
2. The shell border is visible.
3. System icons are rendered.
4. The text is inside the bar but looks like a motion title, not input text.
5. The text uses a visual weight heavier than the SceneProgram asks for.
6. The text frame is treated as a QA/evaluation fact more than a drawing
   contract.
7. The caret/cursor is a separate static shape; it does not follow the visible
   text width produced by `typewriterProgress`.
8. The visual system has no formal ratio check for:
   - text height to input height;
   - icon size to text height;
   - button size to bar height;
   - caret height to text line height;
   - text slot width to trailing controls.

The root cause is not one bad number. It is this:

```text
MotionText renderer and component ratio contracts are not the same truth.
```

For example:

```text
SceneProgram says: fontWeight = 400
Renderer draws:    FontWeight.w700
```

That single mismatch can make a correctly sized input text look oversized and
unprofessional. Therefore visual harmony starts with render truth.

## 2. Non-Negotiable Rules

1. The renderer must not hard-code text weight, line height, alignment, or frame
   behavior when the SceneProgram provides those values.
2. `EvaluatedFrameTruth` and on-device preview must agree on text metrics.
3. A bounded text element must be rendered inside its `textFrame`, not merely
   validated against it.
4. `fitPolicy: shrinkToFit` must affect actual rendered font size or fail
   closed with a named error.
5. Input-like components must default to regular text weight unless explicitly
   overridden.
6. Carets must be bound to the revealed text end, not placed by fixed keyframes.
7. Component ratio tables must decide default text, icon, button, and padding
   proportions.
8. Visual harmony violations must block professional presets before they reach
   the user.
9. Device screenshot acceptance is mandatory for the PromptInputBar proof.
10. Do not touch protected Live Scrub/native scrub files for this plan.

## 3. What This Plan Does Not Do

This is not a new scene-authoring plan.

This plan does not:

- add another one-off PromptInputBar JSON patch;
- invent a new scene format;
- rewrite Stage5;
- change protected Live Scrub paths;
- hide problems by making the text smaller manually;
- accept QA-only success when pixels still look wrong.

The plan fixes the runtime contracts that all future scenes must use.

## 4. Dependency And Inheritance

This plan inherits the completed and in-progress foundations:

- Coordinate Canon and center-origin evaluation;
- EvaluatedFrameTruth;
- Component render truth repairs;
- intrinsic component sizing;
- slot layout contracts;
- strict pre-render gate;
- professional present preset flow.

It extends them with the missing visual-quality layer:

```text
Render truth -> visual harmony -> device proof
```

## 5. Phase Plan

### PMVHR-00 - Failure Proof And Measurement Baseline

Goal: capture the current visual mismatch as a failing, measurable contract.

Required work:

- Add or update the PromptInputBar regression fixture using the current present
  scene: white background, pill shell, plus, text, mic, send button, typewriter
  caret.
- Evaluate the hold/typewriter frames at multiple times:
  - before typewriter starts;
  - 25%;
  - 50%;
  - 75%;
  - 100%;
- Record expected geometry:
  - shell bounds;
  - text frame bounds;
  - rendered text bounds;
  - full text width;
  - visible text width;
  - caret x;
  - icon bounds;
  - button bounds.
- Create failing tests proving:
  - `fontWeight: 400` does not survive to render truth;
  - bounded text is not measured through the same path used for painting;
  - caret position does not equal visible text end;
  - text appears visually title-like inside an input component.

Acceptance:

```text
At least one test fails before PMVHR-01.
The failure must name the layer: text render contract, text measurement,
caret binding, or component harmony ratio.
```

### PMVHR-01 - MotionText Render Contract

Goal: make MotionText preview/render consume the same text properties declared
by SceneProgram and EvaluatedFrameTruth.

Required work:

- Replace hard-coded text drawing values with node values:
  - `fontWeight`;
  - `fontStyle`;
  - `fontSize`;
  - `letterSpacing`;
  - `lineHeight`;
  - `textAlignment`;
  - `fontFamily`;
  - `color`;
  - `opacity`;
  - `textFrame`.
- Ensure regular input text draws as regular weight, not title weight.
- Keep title/hero presets able to use heavy weights through explicit values.
- Add tests for at least:
  - regular 400;
  - medium 500;
  - semibold 600;
  - bold 700.

Acceptance:

```text
SceneProgram fontWeight=400 renders and measures as 400.
No hard-coded FontWeight.w700 remains in the general MotionText drawing path.
```

### PMVHR-02 - Real Text Measurement And Frame Contract

Goal: use a real text measurement path for bounded component text.

Required work:

- Introduce a shared text measurement service, for example
  `scene_text_measurement_engine.dart`.
- The measurement engine must return:
  - full text width;
  - visible text width at reveal progress;
  - line height in pixels;
  - rendered glyph bounds;
  - frame bounds;
  - effective font size after fitting;
  - fit status.
- Use Flutter `TextPainter` semantics in Flutter preview tests where possible.
- Keep the service deterministic for tests.
- Replace rough character-width estimates in professional component QA when a
  real measurement path is available.

Acceptance:

```text
The same measurement result is consumed by:
  - MotionText preview/render;
  - EvaluatedFrameTruth;
  - Visual QA;
  - caret bindings.
```

### PMVHR-03 - Bounded TextFrame Rendering

Goal: a `textFrame` must be a drawing contract, not only validation metadata.

Required work:

- Render bounded text inside its frame.
- Respect:
  - width;
  - height;
  - anchor;
  - alignment;
  - maxLines;
  - overflow;
  - fitPolicy;
  - minFontSize;
  - maxFontSize;
  - measure mode.
- Implement actual `shrinkToFit`:
  - start from requested font size;
  - measure full text;
  - reduce to fit within frame;
  - clamp to `minFontSize`;
  - fail closed if it still overflows and no ellipsis/wrap policy is allowed.
- Make the effective rendered font size visible in diagnostics.

Acceptance:

```text
Text inside PromptInputBar cannot render outside its textFrame.
If it cannot fit, scene apply is rejected with TEXT_FRAME_RENDER_OVERFLOW.
```

### PMVHR-04 - Typewriter Text Reveal Truth

Goal: typewriter progress must affect the actual visible text, measurement, and
caret position.

Required work:

- Normalize typewriter execution so one source of truth produces:
  - visible substring;
  - visible text width;
  - full text width;
  - reveal end x;
  - reveal diagnostics.
- Do not create one text element per character.
- Preserve editability: typewriter remains a single text element with
  `typewriterProgress`.
- Ensure render preview uses visible text or a clipping/masking equivalent that
  yields the same measured reveal end.

Acceptance:

```text
At 0%, visible text width is 0.
At 50%, visible text width is less than full text width.
At 100%, visible text width equals full text width.
```

### PMVHR-05 - Element Expression Binding Engine

Goal: support deterministic element-to-element bindings needed by professional
motion components.

Required work:

- Add binding model support for expressions such as:

```text
target.promptCursor.position.x = source.promptText.revealedEndX + 2
target.promptCursor.height = source.promptText.lineHeight * 0.9
target.promptCursor.opacity = pulse(1.1Hz)
```

- Bindings must resolve during evaluation before final composition.
- Bindings must be deterministic and testable.
- Bindings must not introduce arbitrary scripting.
- Initial expression vocabulary:
  - `revealedEndX`;
  - `lineHeight`;
  - `pulse(hz)`;
  - `add`;
  - `multiply`;
  - `clamp`;
  - `parent.active`.

Acceptance:

```text
The cursor moves as the text reveal progresses without manual cursor x
keyframes.
```

### PMVHR-06 - PromptInputBar Default Internal Bindings

Goal: every PromptInputBar gets professional caret behavior automatically.

Required work:

- Add PromptInputBar component defaults:

```text
caret.x = promptText.revealedEndX + caretGap
caret.height = promptText.lineHeight * 0.9
caret.opacity = pulse(1.1Hz)
caret.y = promptText.baselineAlignedCenter
```

- Remove one-off static cursor positioning from professional prompt presets.
- Keep explicit overrides possible only with a named `overrideBindings` flag.

Acceptance:

```text
PromptInputBar cursor follows the visible text in the present preset and in
component tests.
```

### PMVHR-07 - Component Ratio Table System

Goal: define the proportions that make each component visually professional.

Required work:

- Add a ratio table service, for example
  `scene_component_visual_ratio_registry.dart`.
- Define ratios for at least:
  - PromptInputBar;
  - SearchBar;
  - TextField;
  - CTAButton;
  - IconButton;
  - FeatureCard;
  - Toast;
  - Chip.
- PromptInputBar baseline:

```text
barHeight: adaptive 56-72
textFontSize: barHeight * 0.28-0.34, clamped by type role
lineHeight: textFontSize * 1.0-1.15
textVisualWeight: 400 default
iconSize: barHeight * 0.34-0.42
sendButtonSize: barHeight * 0.62-0.72
caretHeight: lineHeight * 0.85-0.95
horizontalPadding: barHeight * 0.30-0.42
slotGap: barHeight * 0.16-0.24
```

Important: the validator must distinguish:

- font size;
- line box height;
- visible glyph height;
- text frame height;
- container height.

These are not interchangeable.

Acceptance:

```text
PromptInputBar cannot use title-like font size/weight unless explicitly
configured as a hero/search variant.
```

### PMVHR-08 - Visual Harmony Validator

Goal: reject scenes that are geometrically valid but visually unprofessional.

Required checks:

- `TEXT_TOO_HEAVY_FOR_COMPONENT`
  - input-like components should not default to heavy title weights.
- `TEXT_TOO_LARGE_FOR_SLOT`
  - rendered text bounds exceed slot/frame.
- `TEXT_TOO_SMALL_FOR_CONTAINER`
  - text becomes visually lost inside the component.
- `ICON_TEXT_RATIO_MISMATCH`
  - icon size is not compatible with text height.
- `BUTTON_CONTAINER_RATIO_MISMATCH`
  - button does not fit component height.
- `CARET_DETACHED_FROM_TEXT`
  - caret x is not close to visible text end.
- `CARET_HEIGHT_MISMATCH`
  - caret height not related to line height.
- `STATIC_CARET_WITH_TYPEWRITER`
  - cursor has fixed x while text has typewriter reveal.

Severity:

```text
Professional preset: error
Experimental/custom scene: warning unless strict mode is enabled
```

Acceptance:

```text
The current bad PromptInputBar visual state fails before repair and passes
after PMVHR-01 through PMVHR-07.
```

### PMVHR-09 - Render/Evaluation Parity Gate

Goal: prevent QA from passing while the screen draws different typography.

Required work:

- Add parity assertions for:
  - font weight;
  - effective font size;
  - text frame;
  - visible text;
  - caret position;
  - icon bounds;
  - shell bounds.
- Emit diagnostic:

```text
TF_SCENE_VISUAL_HARMONY_PARITY_PROOF
  sceneId
  componentId
  textElementId
  requestedFontWeight
  renderedFontWeight
  requestedFontSize
  effectiveFontSize
  textFrameBounds
  renderedTextBounds
  caretExpectedX
  caretRenderedX
  passed
```

Acceptance:

```text
If SceneProgram says fontWeight=400 and preview draws 700, the scene fails.
```

### PMVHR-10 - Professional PromptInputBar Regression Scene

Goal: maintain one official proof scene for this whole layer.

Required scene:

- white background;
- circle spring pop;
- circle morphs into pill bar;
- visible dark border;
- plus icon left;
- mic icon right;
- send button right;
- regular input text;
- typewriter effect;
- caret follows every revealed character;
- send press at the end;
- coherent exit or clean hold.

The scene should be named:

```text
Smart Test App Prompt
```

Acceptance:

```text
The preset imports, applies, passes pre-render, passes visual harmony, and
renders acceptably on the connected Android device.
```

### PMVHR-11 - Device Screenshot Acceptance

Goal: prove the runtime on real device pixels.

Required work:

- Install the build on the connected Android device.
- Open the present preset.
- Capture screenshot at:
  - 25% typewriter;
  - 50% typewriter;
  - 100% typewriter or readable hold.
- Measure or manually verify:
  - border visible against white background;
  - text is regular, not bold title;
  - text is inside prompt shell;
  - caret is adjacent to last visible character;
  - plus/mic/send are in expected slots;
  - no child outlives the shell.

Acceptance:

```text
Device screenshot must be attached or saved with clear pass/fail notes.
```

### PMVHR-12 - Skills And Authoring Rules Update

Goal: prevent future agents from writing static cursors or raw UI proportions.

Required work:

- Update ReFusion scene authoring skill/reference docs:
  - input text must use component ratio tokens;
  - input text defaults to regular weight;
  - typewriter cursors must use bindings;
  - do not hand-keyframe caret x;
  - do not use title presets inside input bars;
  - do not create one layer per character.
- Add good and bad examples.

Acceptance:

```text
Skills explain that PromptInputBar is component-driven, not a loose collection
of shape/text/icon layers.
```

## 6. Required Tests

Minimum test suite:

```text
PMVHR-00:
  - current prompt fixture exposes font/caret mismatch

PMVHR-01:
  - MotionText honors fontWeight 400/500/600/700

PMVHR-02:
  - measurement engine returns stable full/visible widths

PMVHR-03:
  - bounded textFrame applies shrinkToFit in render truth

PMVHR-04:
  - typewriter visible width changes with progress

PMVHR-05:
  - expression binding resolves cursor.x from revealedEndX

PMVHR-06:
  - PromptInputBar default caret follows text

PMVHR-07:
  - PromptInputBar ratios produce professional values

PMVHR-08:
  - bad ratios fail visual harmony validator

PMVHR-09:
  - renderer/evaluator font mismatch fails parity gate

PMVHR-10:
  - Smart Test App Prompt applies through SceneProgramApplyTransaction

PMVHR-11:
  - device screenshot captured and reviewed
```

## 7. Implementation Order

The order is mandatory:

```text
1. PMVHR-00 - prove failure
2. PMVHR-01 - make text renderer truthful
3. PMVHR-02 - add real measurement
4. PMVHR-03 - make textFrame a render contract
5. PMVHR-04 - typewriter visible text truth
6. PMVHR-05 - expression bindings
7. PMVHR-06 - PromptInputBar default bindings
8. PMVHR-07 - component ratio tables
9. PMVHR-08 - harmony validator
10. PMVHR-09 - parity gate
11. PMVHR-10 - rebuild proof scene
12. PMVHR-11 - device acceptance
13. PMVHR-12 - skills update
```

Do not start ratio tables before the renderer consumes font weight and text
frame correctly. Otherwise the ratio system will validate a fiction.

## 8. Performance Budgets

```text
Text measurement:
  - <= 0.25ms per simple one-line input text after cache
  - <= 2ms uncached for common component text

Expression binding:
  - <= 0.1ms for a PromptInputBar caret binding
  - <= 1ms for 100 simple bindings

Visual harmony validation:
  - <= 100ms per professional preset

Device proof:
  - no visible jank from caret binding or typewriter reveal
```

Caching is required for repeated text measurement during drag/preview.

## 9. Stop List

Do not:

- patch the PromptInputBar JSON by only lowering font size;
- keep `FontWeight.w700` hard-coded in the general text renderer;
- add manual cursor x keyframes for typewriter;
- validate `textFrame` without enforcing it in render;
- rely on rough glyph-width estimates when a real measurement path exists;
- accept a scene where QA and preview disagree;
- add new professional scene presets before the proof scene passes;
- touch protected Live Scrub/native scrub files;
- mark this plan complete without device screenshot acceptance.

## 10. Definition Of Done

PMVHR is complete only when all are true:

1. `Smart Test App Prompt` imports and applies.
2. Text inside the prompt is regular weight unless explicitly overridden.
3. Text is measured and rendered inside its `textFrame`.
4. `shrinkToFit` changes actual rendered size or fails closed.
5. Typewriter reveal changes visible text and visible measured width.
6. The caret follows the last visible character.
7. The caret pulses and uses line-height-derived height.
8. PromptInputBar ratios pass visual harmony validation.
9. Renderer/evaluator parity blocks font and bounds mismatches.
10. Device screenshot shows professional prompt bar proportions.
11. Authoring skills prevent static cursor and raw ratio mistakes.

## 11. Final Principle

The AI should not guess UI proportions. The system must know them.

```text
Professional motion component =
  truthful renderer
  + real measurement
  + component ratio table
  + expression bindings
  + visual harmony gate
  + device proof
```

That is the missing bridge between a scene that technically applies and a scene
that feels professionally designed.
