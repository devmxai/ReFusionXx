# Professional Native Scene Intelligence System - VERSION 5

Status: official VERSION 5 execution plan  
Package: `com.refusion.app`  
Branch: `codex/unified-keyframe-ops-foundation-20260426`  
Date opened: 2026-05-09  
Primary predecessors:

- `professional_native_scene_intelligence_system.md`
- `professional_native_scene_intelligence_system_version_2.md`
- `professional_native_scene_intelligence_system_version_3.md`
- `professional_native_scene_intelligence_system_version_4.md`

Scope: professional motion vocabulary, shared text layout enforcement, brand/icon
intelligence, optical alignment, component choreography, scene composition
intelligence, contextual micro-scenes, taste validation, and agent-facing skills
so ReFusionXx can author native editable scenes with professional motion-design
quality instead of one-off demo fixes.

## 0. Current Baseline

VERSION 4 is closed and gave ReFusionXx a real render-truth foundation:

- canonical center-origin coordinate system;
- `EvaluatedFrameTruth`;
- QA/preview/gate truth alignment;
- strict apply/pre-render gates;
- prompt-burst regression rewrite through canonical geometry.

The device trials after VERSION 4 showed genuine geometric improvement:

- cards no longer escaped the canvas;
- primary grid alignment improved;
- title/subtitle readability improved;
- old coordinate drift was reduced.

However, the output still does not feel professionally directed. The remaining
failures are no longer mostly coordinate failures. They are artistic-system
failures:

- text fitting is not governed by one shared text layout engine across every
  path;
- the app has no rich executable motion recipe library;
- scenes can repeat the same fade/opacity behavior and still pass;
- icons and glyphs are not optically centered or brand-aware;
- component children do not have a professional internal choreography grammar;
- cards, text, icons, and background elements do not yet share a scene-level
  composition intelligence model;
- agents have too much freedom to guess sizes, timings, placements, and icon
  treatments.

VERSION 5 exists to make the system artistically intelligent, not merely
geometrically valid.

## 1. The VERSION 5 Decision

The controlling decision:

```text
Professional output must be generated from executable vocabularies:
TextLayout + IconRegistry + MotionRecipes + ComponentChoreography + SceneTaste.
```

The agent must not guess:

- whether an icon is centered;
- how large an icon should be inside a card;
- whether body text can fit;
- which animation should be used;
- how cards should cascade;
- how children exit with their parent;
- whether a brand logo can be used;
- how a scene should adapt to portrait, square, or landscape.

The system must provide those answers through contracts and validators.

## 2. Non-Negotiable Rules

1. ReFusion scenes remain native editable scene programs.

No HTML, CSS, JS, React, GSAP, Remotion, Lottie-only, or rendered-video-only
source of truth may become the authoring output.

2. Motion recipes must compile to real channels.

`$motion.scaleInBounce` is not metadata. It must compile to editable
SceneProgram channels and SpeedyGraph/Bezier timing.

3. Text fit must be a shared renderer truth.

If QA says text fits, preview/export must use the same effective text layout.
No validator-only shrink. No renderer-only clipping.

4. Icons must be slot-aware and optically aligned.

An `R` inside an app icon, or a brand logo inside a button, must be centered by
visual centroid and safe-zone rules, not by naive bounding box placement.

5. Brand assets must be legal and traceable.

Brand logos may be referenced only through an asset registry that stores source,
license/usage status, visual variants, safe zone, and fallback behavior. If an
official/authorized asset is unavailable, use a generic semantic icon, not an
invented trademark logo.

6. Every component must have internal choreography.

A card is not one rectangle plus random text. A card is:

```text
card shell -> icon container -> icon glyph -> title -> body -> accent/details
```

Each child has a timed relationship to the parent.

7. Scene taste validation is mandatory.

Scenes must be blocked or repaired when they are visually childish, repetitive,
misaligned, over-dense, under-spaced, or rhythmically flat.

8. Protected native paths remain protected.

Do not touch Stage5, Live Scrub, Motion Tile, Motion Blur, or unrelated FX files
unless a phase explicitly proves it is required and documents the reason.

## 3. Architecture Overview

```text
Agent Prompt
  -> Semantic Blueprint v5
  -> Token Resolver
  -> Brand/Icon Registry
  -> Component Registry
  -> Shared Text Layout Engine
  -> Motion Recipe Compiler
  -> Component Choreography Compiler
  -> Scene Composition Solver
  -> SceneProgram
  -> EvaluatedFrameTruth
  -> Visual QA + Taste QA + Motion Variety QA
  -> Apply/Preview/Export
```

Every stage must be observable through diagnostics and testable through focused
fixtures.

## 4. Core Contracts

### 4.1 Shared Text Layout Contract

Text layout must produce an explicit result:

```text
SceneTextLayoutResult
  inputText
  displayedText
  fontSizePx
  lineHeight
  lineCount
  maxLines
  frameWidth
  frameHeight
  contentWidth
  contentHeight
  overflowResolved
  overflowReason
  fitPolicy
  clipped
  sentenceCutMidPhrase
```

Supported fit policies:

- `shrinkToFit`: reduce size by token-bound steps until width and height fit;
- `wrapToLines`: wrap naturally up to `maxLines`;
- `ellipsisAfterMaxLines`: wrap, then ellipsis only at a valid phrase boundary;
- `shorten`: semantic shortening for labels and captions;
- `scaleXForNumericOnly`: only for numeric labels, never prose;
- `error`: reject if text does not fit.

Required rule:

```text
No body text may end with dangling phrase fragments:
",", "and", "or", "the", "with", "for", "to"
```

unless the string is explicitly a typed-in-progress typewriter frame.

### 4.2 Brand/Icon Intelligence Contract

Every icon is resolved through a typed registry:

```text
ReFusionIconToken
  id
  category: brand | product | social | ai | editing | audio | image | generic
  displayName
  sourceKind: bundledAuthorized | userProvided | generatedGeneric | systemIcon
  sourceUrlOrAssetPath
  licenseStatus: allowed | userMustProvide | restricted | unknown
  colorModes: fullColor | monochrome | inverse | duotone
  viewBox
  opticalBounds
  opticalCenter
  safeZoneInsets
  minDisplaySize
  preferredSlotRatio
  fallbackIconId
```

Initial registry groups:

- AI and assistant tools:
  - OpenAI / ChatGPT
  - Claude
  - Gemini
  - generic AI sparkle
- Social and creator platforms:
  - Meta
  - Facebook
  - Instagram
  - TikTok
  - X / Twitter
  - YouTube
  - LinkedIn
  - generic social bubble
- Communication and collaboration:
  - Gmail / Google Mail
  - Slack
  - WhatsApp
  - Discord
  - Teams
  - generic message
- Creative and design:
  - Figma
  - Canva
  - Adobe generic category token when allowed
  - generic vector/design tool
- ReFusion semantic icons:
  - montage
  - captions
  - dubbing
  - audio engineering
  - color grade
  - image retouch
  - presentation
  - app builder
  - upload/plus
  - send/up-arrow

Legal rule:

```text
Do not bundle third-party brand logos unless the asset source and usage status
are documented. For unclear brands, require user-provided asset or use generic
semantic fallback.
```

### 4.3 Optical Alignment Contract

Every icon and glyph must be centered by optical center, not raw bounds:

```text
IconSlotAlignmentResult
  slotBounds
  iconVisualBounds
  iconOpticalCenter
  slotCenter
  centerDeltaPx
  safeZonePassed
  scaleRatio
```

Acceptance:

- app icon glyph such as `R` must have center delta <= 1.5 px at design scale;
- button icons must have center delta <= 1 px;
- brand icons must respect their safe zone;
- visually asymmetric symbols such as arrows may use optical correction offsets;
- if an icon is in a circle, its visual mass must be centered inside the circle.

This directly prevents the observed issue where the `R` appears shifted left
inside the app icon card.

### 4.4 Motion Recipe Contract

Motion recipes are executable templates:

```text
MotionRecipe
  id
  category: entrance | exit | emphasis | transition | text | icon | card | group
  channels
  defaultDurationToken
  easingToken
  speedyGraphPreset
  staggerPolicy
  motionBlurPolicy
  allowedTargets
  aspectBias
  tasteNotes
```

Minimum recipe set:

Entrance:

- `slideInFromLeft`
- `slideInFromRight`
- `slideInFromTop`
- `slideInFromBottom`
- `softFadeUp`
- `scaleIn`
- `scaleInBounce`
- `popInSpring`
- `rotateIn`
- `blurIn`
- `stampDown`
- `drawOn`

Exit:

- `slideOutToLeft`
- `slideOutToRight`
- `slideOutToTop`
- `slideOutToBottom`
- `scaleOut`
- `pushBack`
- `whipPan`
- `fadeCollapse`
- `maskWipeOut`

Text:

- `typewriterFixedFrame`
- `wordCascadeUp`
- `lineRevealMask`
- `captionPop`
- `headlineBlurSettle`

Icon:

- `iconPop`
- `iconPress`
- `iconPulse`
- `iconOrbitMicro`
- `plusPressToFill`
- `sendPress`

Card and group:

- `cardSpringEntrance`
- `cardStackCascade`
- `cardFlipSoft`
- `cardLiftHover`
- `groupBounceIn`
- `cascadeSlideIn`
- `cascadeScaleIn`
- `gridStaggerProfessional`

Transitions:

- `morphIconToPromptBar`
- `promptBarToFullscreenCircle`
- `matchCutSlide`
- `scaleThrough`
- `wipeByShape`
- `pushDepth`

Every recipe must compile to real editable channels. Recipes must never be only
decorative metadata.

### 4.5 Component Choreography Contract

Components define internal timelines.

Example `FeatureCard`:

```text
FeatureCard enter:
  t+000ms parent shell: cardSpringEntrance
  t+060ms icon container: iconPop
  t+110ms icon glyph: iconPulse subtle
  t+150ms title: wordCascadeUp
  t+230ms body: lineRevealMask
  t+320ms accent detail: softFadeUp

FeatureCard exit:
  children fade/slide first
  shell exits last or carries children through parent transform
```

Example `PromptInputBar`:

```text
PromptInputBar morph:
  icon square pops in
  press depression occurs
  square stretches into input bar
  plus icon enters left slot
  send circle enters right slot
  text frame becomes active
  typewriter begins only after the text frame is stable
  send press triggers fullscreen circle expansion
```

Rules:

- child motion is scoped to parent beat-local time;
- no child may remain visible after parent exit unless explicitly detached;
- internal child timings must not overlap incoherently;
- typewriter text must not start while its container is still resizing unless
  the motion recipe declares a safe fixed-frame reveal.

### 4.6 Scene Composition Intelligence Contract

The scene solver must understand:

- canvas aspect ratio:
  - 9:16 story / mobile;
  - 16:9 YouTube / widescreen;
  - 1:1 square;
  - 4:5 feed;
- safe areas;
- focal zones;
- golden regions;
- card grid capacity;
- visual density;
- title/body hierarchy;
- icon/card proportions;
- background element budget;
- simultaneous motion budget.

Minimum rules:

- no card grid is allowed without a container contract;
- no card body may exceed its text slot;
- icon size inside card should usually be 18-26% of card height;
- title should usually be 15-24% of card height;
- body text should usually be 9-14% of card height;
- card inner padding must be tokenized;
- cards in the same group must share baseline alignment;
- portrait layouts prefer vertical flow and staggered depth;
- landscape layouts prefer horizontal/diagonal flow;
- no more than five major simultaneous animations in one beat unless marked as
  deliberate climax.

## 5. Diagnostics

Add these diagnostics:

### `TF_SCENE_TEXT_LAYOUT_PROOF`

Fields:

- `componentId`
- `elementId`
- `textFrame`
- `inputText`
- `displayedText`
- `fontSizeBefore`
- `fontSizeAfter`
- `lineCount`
- `fitPolicy`
- `overflowResolved`
- `clipped`
- `sentenceCutMidPhrase`
- `fallbackReason`

### `TF_SCENE_ICON_ALIGNMENT_PROOF`

Fields:

- `iconId`
- `brandKey`
- `slotBounds`
- `visualBounds`
- `opticalCenter`
- `slotCenter`
- `centerDeltaPx`
- `safeZonePassed`
- `sourceKind`
- `licenseStatus`
- `fallbackReason`

### `TF_SCENE_MOTION_RECIPE_PROOF`

Fields:

- `recipeId`
- `targetId`
- `targetKind`
- `compiledChannels`
- `durationMs`
- `easingToken`
- `speedyGraphPreset`
- `curveHash`
- `motionBlurPolicy`
- `fallbackReason`

### `TF_SCENE_COMPONENT_CHOREOGRAPHY_PROOF`

Fields:

- `componentId`
- `componentType`
- `beatId`
- `enterRecipe`
- `holdIntent`
- `exitRecipe`
- `childTimeline`
- `parentLifecycleApplied`
- `orphanChildren`
- `fallbackReason`

### `TF_SCENE_TASTE_VALIDATION_PROOF`

Fields:

- `sceneId`
- `aspectRatio`
- `densityScore`
- `hierarchyScore`
- `motionVarietyScore`
- `alignmentScore`
- `textFitScore`
- `iconQualityScore`
- `issues`
- `passed`

## 6. Execution Phases

### NSI-v5-00 - Failure Fixtures And Professional Quality Baselines

Goal: capture the current visible failures as tests before building new
systems.

Required:

- Add fixtures for:
  - app icon `R` shifted off-center;
  - card body text clipped or ending mid-phrase;
  - four cards using repetitive motion;
  - icon/text/card child choreography not synchronized;
  - brand icon missing and falling back incorrectly;
  - prompt icon-to-input morph with text starting too early.
- Add baseline assertions that fail before implementation.
- Keep fixtures native SceneProgram/SemanticBlueprint only.

Tests:

- `scene_text_layout_engine_test.dart`
- `scene_icon_alignment_validator_test.dart`
- `scene_motion_recipe_library_test.dart`
- `scene_component_choreography_test.dart`
- `scene_taste_validation_test.dart`

Acceptance:

- At least one test reproduces the `R` optical centering failure.
- At least one test reproduces clipped body text inside a card.
- At least one test rejects fade-only repetitive card motion.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 00 - quality baselines
```

### NSI-v5-01 - Shared Text Layout Engine

Goal: make text fit a shared truth, not a QA-only assumption.

Create:

- `scene_text_layout_engine.dart`
- `scene_text_layout_contract.dart`
- `scene_text_fit_policy.dart`

Required:

- Implement shrink/wrap/ellipsis/shorten/error policies.
- Expose effective font size and displayed text.
- Detect clipped text and dangling phrase endings.
- Ensure evaluator, QA, preview, and pre-render gate consume the same layout
  result or equivalent shared contract.
- Preserve editable text in the scene program; do not rasterize text.

Acceptance:

- Long card body text fits through shrink/wrap or is rejected.
- QA and preview agree on displayed bounds.
- No sentence ending in dangling `and`, `or`, comma, or incomplete phrase is
  accepted as final hold text.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 01 - shared text layout
```

### NSI-v5-02 - Brand And Icon Intelligence Registry

Goal: provide professional icon and brand handling without illegal or random
assets.

Create:

- `scene_icon_registry.dart`
- `scene_icon_token.dart`
- `scene_brand_asset_policy.dart`

Required:

- Register ReFusion semantic icons for editing, dubbing, captions, audio,
  retouching, color, presentations, upload, send, and app building.
- Add brand token slots for major platforms and products:
  - OpenAI / ChatGPT
  - Claude
  - Gemini
  - Meta
  - Facebook
  - Instagram
  - TikTok
  - X / Twitter
  - YouTube
  - LinkedIn
  - Google / Gmail
  - Slack
  - WhatsApp
  - Figma
  - Canva
  - Notion
- For third-party brands, store license/source status.
- If an allowed bundled asset is not present, use a generic semantic fallback
  and emit a diagnostic.
- Support color modes: full color, monochrome, inverse, duotone.

Acceptance:

- Unknown brand does not create an invented logo.
- Restricted/unknown brand asset falls back safely.
- Registered generic semantic icons are available for native scenes.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 02 - brand icon registry
```

### NSI-v5-03 - Optical Icon And Glyph Alignment

Goal: make icon/glyph placement visually centered and professional.

Create:

- `scene_icon_alignment_engine.dart`
- `scene_optical_bounds.dart`
- `scene_icon_alignment_validator.dart`

Required:

- Compute or store optical bounds and optical center.
- Align icons inside square, circle, pill, and card slots.
- Add correction offsets for asymmetric glyphs.
- Validate app icon glyph centering.
- Validate plus/send icons in prompt bar slots.
- Validate brand icon safe zones.

Acceptance:

- `R` inside app icon square is optically centered.
- Plus icon is centered in its left slot.
- Send arrow is optically centered in its circle.
- Center delta violations are errors, not warnings.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 03 - optical icon alignment
```

### NSI-v5-04 - Motion Recipe Library v1

Goal: give agents professional executable animation vocabulary.

Create:

- `scene_motion_recipe_library.dart`
- `scene_motion_recipe_compiler.dart`
- `scene_motion_recipe_models.dart`

Required:

- Implement the minimum recipe set listed in section 4.4.
- Every recipe compiles to real SceneProgram channels.
- Recipes must use SpeedyGraph/Bezier truth.
- Recipes must preserve editability.
- Recipes must support target scopes:
  - component parent;
  - card shell;
  - icon;
  - title;
  - body;
  - group;
  - background element.

Acceptance:

- `$motion.popInSpring` produces scale/opacity channels with professional
  timing.
- `$motion.morphIconToPromptBar` produces connected parent/child motion.
- `$motion.gridStaggerProfessional` staggers card children without duplicated
  manual keyframes.
- No recipe silently falls back to linear.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 04 - motion recipe library
```

### NSI-v5-05 - Component Choreography Engine

Goal: make cards, prompt bars, buttons, and panels animate as directed
components, not independent random layers.

Create:

- `scene_component_choreography_engine.dart`
- `scene_component_choreography_models.dart`

Required:

- Add choreography definitions for:
  - `AppIconIntro`
  - `PromptInputBar`
  - `FeatureCard`
  - `BrandFeedbackCard`
  - `DashboardPanel`
  - `AudioFeatureCard`
  - `CaptionFeatureCard`
  - `ImageRetouchCard`
  - `ColorGradeCard`
- Choreography must define child order, delays, recipes, and lifecycle.
- Parent exit must carry or clean children.
- Text starts only after its container is stable unless recipe allows it.

Acceptance:

- A `FeatureCard` enters through shell, icon, title, body in a coherent sequence.
- Parent exit removes all children or carries them through the same transform.
- Prompt icon-to-input morph is one connected choreography, not two unrelated
  objects appearing/disappearing.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 05 - component choreography
```

### NSI-v5-06 - Scene Composition Intelligence Solver

Goal: understand the whole canvas, not isolated components.

Create:

- `scene_composition_solver.dart`
- `scene_composition_rules.dart`
- `scene_visual_density_budget.dart`

Required:

- Solve professional layout for:
  - one hero element;
  - prompt input bar;
  - 2x2 feature card grid;
  - floating feedback cards;
  - circular hub scene;
  - multi-brand feedback wall;
  - audio/caption/image feature showcase.
- Enforce aspect-aware safe regions and focal zones.
- Compute card sizes from canvas, grid, density, and text needs.
- Use tokenized spacing and type scale.

Acceptance:

- Same blueprint adapts to 9:16, 16:9, 1:1, and 4:5 without overlap.
- Card grids never leave the canvas.
- Text/icon ratios stay professional.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 06 - scene composition solver
```

### NSI-v5-07 - Motion Variety And Rhythm Validator

Goal: reject visually boring or repetitive animation.

Create:

- `scene_motion_variety_validator.dart`
- `scene_motion_rhythm_validator.dart`

Required:

- Reject fade-only professional scenes.
- Reject siblings where more than 60% use the same recipe unless the group is
  explicitly a cascade.
- Enforce enter recipe != exit recipe.
- Enforce readable holds after complex motion.
- Enforce aspect-aware motion preferences.
- Limit simultaneous major animations per beat.

Acceptance:

- Four feature cards all using opacity-only fade are rejected.
- A professional grid stagger passes.
- Enter/exit symmetry is accepted only when declared as a deliberate mirror.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 07 - motion variety validator
```

### NSI-v5-08 - Professional Taste Validator

Goal: enforce modern design taste through measurable rules.

Create:

- `scene_professional_taste_validator.dart`
- `scene_component_proportion_validator.dart`

Required:

- Validate:
  - card inner padding;
  - icon-to-card ratio;
  - title/body hierarchy;
  - text baseline alignment;
  - line count;
  - contrast;
  - over-density;
  - under-composed empty space;
  - repeated motion;
  - random background decoration;
  - orphan children;
  - visual centroid errors.

Acceptance:

- A card with huge title and tiny body is rejected.
- A card with body outside its frame is rejected.
- A prompt icon with shifted `R` is rejected.
- A scene with excessive simultaneous motion is rejected or warned according to
  severity.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 08 - professional taste validator
```

### NSI-v5-09 - Contextual Micro-Scene Library

Goal: give feature cards meaningful internal visuals instead of generic icons.

Create:

- `scene_micro_scene_registry.dart`
- `scene_feature_visual_motifs.dart`

Required:

- Add native editable motifs for:
  - audio engineering: waveform, EQ bars, noise gate dots;
  - captions: kinetic text lines, highlighted word pill;
  - montage: timeline strips, cut markers, playhead;
  - image retouch: before/after chip, sparkle retouch path;
  - color grade: color wheels/chips, LUT slider;
  - presentations: slide stack, chart bars;
  - app builder: prompt bar, app tile, module blocks.
- Motifs must be shapes/text/icons, not raster-only screenshots.
- Motifs must have their own choreography hooks.

Acceptance:

- An audio card can show a small waveform motif.
- A captions card can show a highlighted text motif.
- Motifs fit inside card bounds and obey parent lifecycle.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 09 - contextual micro scenes
```

### NSI-v5-10 - Semantic Blueprint v5 Agent Contract

Goal: make agent authoring use the new vocabulary by default.

Required:

- Extend blueprint schema with:
  - `iconToken`
  - `brandToken`
  - `motionRecipe`
  - `componentChoreography`
  - `fitPolicy`
  - `compositionIntent`
  - `microScene`
  - `tasteProfile`
- Reject loose values where a token/recipe/component contract exists.
- Preserve lowered native values as editable SceneProgram data.

Acceptance:

- Agent can author:

```json
{
  "use": "$component.FeatureCard",
  "iconToken": "$icon.audioEngineering",
  "motionRecipe": "$motion.cardSpringEntrance",
  "microScene": "$microScene.audioWaveform",
  "fitPolicy": "$textFit.wrapToLines"
}
```

and compiler produces editable native shapes, text, icons, and channels.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 10 - semantic blueprint v5
```

### NSI-v5-11 - Visual Closure Repair Payloads v5

Goal: make the system capable of telling the agent exactly how to repair visual
defects.

Required:

- Add structured repair payloads for:
  - text overflow;
  - bad phrase cut;
  - icon off-center;
  - missing brand asset;
  - repetitive motion;
  - weak component choreography;
  - density/layout problems;
  - unsafe simultaneous motion.
- Include suggested token-level repairs, not vague prose.

Example:

```json
{
  "code": "ICON_OPTICAL_CENTER_OFF",
  "componentId": "appIconIntro",
  "measured": {"deltaX": -7.4, "deltaY": 0.8},
  "suggestedFix": {
    "action": "setIconAlignment",
    "path": "components.appIconIntro.iconSlot.opticalCorrection",
    "value": "auto"
  }
}
```

Acceptance:

- Broken scenes produce actionable repair payloads.
- Repair payloads refer to blueprint paths and token fixes.
- The agent is not asked to guess pixel coordinates manually.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 11 - visual repair payloads
```

### NSI-v5-12 - refusion-skills VERSION 5 Update

Repository:

```text
/Users/mx/Documents/refusion-skills
```

Goal: any external agent given the skills repo should author scenes with the new
professional vocabulary.

Required:

- Add:
  - motion recipe guide;
  - brand/icon usage guide;
  - component choreography guide;
  - text layout guide;
  - scene composition guide;
  - professional taste checklist;
  - good/bad examples;
  - repair loop examples.
- Update the full skill bundle.
- Validate example scenes.
- Commit and push `refusion-skills`.

Acceptance:

- Skills explain that brand logos require registry/source handling.
- Skills forbid random raw coordinates for professional scenes.
- Skills require motion variety and child choreography.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 12 - refusion skills v5
```

### NSI-v5-13 - Professional Scene Examples And Regression Fixtures

Goal: prove the system with real examples.

Required examples:

1. Prompt icon to input bar to fullscreen circle.
2. ReFusion premium app feature grid.
3. SaaS feedback card wall with brand/generic icons.
4. Audio engineering feature card.
5. Captions kinetic text feature card.
6. Image retouch/color-grade feature card.
7. Multi-aspect adaptation test scene.

Required:

- Add fixtures to assets or tests as appropriate.
- Old weak scenes must either be migrated or intentionally rejected.
- New examples must pass strict QA.

Acceptance:

- R glyph is optically centered.
- Prompt bar icons are centered.
- Card body text fits.
- Cards animate with varied recipes.
- Internal card child choreography is visible and coherent.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 13 - professional examples
```

### NSI-v5-14 - Closure QA, Build, Install, Status Update

Required tests:

- text layout tests;
- icon registry tests;
- optical alignment tests;
- motion recipe compiler tests;
- component choreography tests;
- scene composition solver tests;
- motion variety validator tests;
- professional taste validator tests;
- visual closure repair tests;
- prompt burst regression tests;
- existing v4 render-truth tests;
- existing SpeedyGraph tests touched by motion recipes.

Required build:

```bash
flutter build apk --debug
```

Install:

- detect connected wireless Android device;
- install APK if available.

Documentation:

- update this VERSION 5 file with final status table;
- list commits;
- list tests;
- list build/install result;
- list remaining risks.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 14 - closure qa
```

## 7. Integration Gates

Gate after v5-01:

- QA and preview agree on effective text layout.

Gate after v5-03:

- App icon `R`, plus icon, and send icon are optically centered.

Gate after v5-04:

- At least 12 motion recipes compile to editable channels.

Gate after v5-05:

- `FeatureCard` and `PromptInputBar` demonstrate child choreography.

Gate after v5-07:

- Fade-only scenes are rejected.

Gate after v5-08:

- bad proportions and bad icon/text/card ratios are rejected.

Gate after v5-13:

- professional examples pass on device or screenshot review.

## 8. Performance Budgets

Text layout:

- 100 text nodes evaluated under 8ms in QA mode;
- preview path caches stable layouts;
- repeated frames reuse layout when text/frame/style unchanged.

Icon alignment:

- registry lookup under 0.1ms;
- optical alignment under 0.05ms per icon after cache.

Motion recipe compilation:

- 100 recipes compile under 20ms;
- runtime evaluation remains based on normal channels.

Visual QA:

- 9 probe frames under 800ms for a medium scene;
- professional taste validation under 150ms.

Preview:

- interaction path remains under 16ms for common edits.

## 9. Stop List

Do not:

- add raw random coordinates when component/layout contract exists;
- bundle unlicensed third-party brand logos;
- invent brand logos;
- accept an icon that is visibly off-center;
- accept card body text that is clipped;
- accept sentence fragments as final displayed body text;
- accept fade-only professional scenes;
- create motion recipes that do not compile to real channels;
- use renderer-only fixes that QA cannot see;
- use QA-only fixes that preview/export cannot render;
- rasterize text or icons as a shortcut;
- touch protected Stage5/Live Scrub/native files without explicit approval;
- solve this by rewriting one preset only.

## 10. Final Acceptance

VERSION 5 is complete only when:

- any text inside a professional component is laid out by the shared text engine;
- app icon glyphs and button icons are optically centered;
- brand/generic icons are resolved through the icon registry;
- motion recipes are executable and editable;
- feature cards have internal choreography;
- scene composition solver controls card placement and density;
- motion variety validator rejects repetitive fade-only scenes;
- professional taste validator catches childish proportions;
- Visual Closure emits repair payloads;
- refusion-skills teaches the new vocabulary;
- example scenes pass strict QA and build/install verification.

The practical user-facing proof:

```text
Prompt:
  "Create a premium ReFusion app promo with an R icon morphing into a prompt
   bar, typewriter text, send-circle transition, and four feature cards."

Expected:
  - R centered inside the app icon;
  - prompt bar icons centered;
  - text fits naturally;
  - cards enter with varied motion;
  - card children animate coherently;
  - no clipping, no overlap, no random fade-only behavior;
  - output remains editable as native ReFusion scene data.
```

## 11. Agent Execution Instruction

Task for Codex:

```text
Implement Professional Native Scene Intelligence System VERSION 5.

Project:
 /Users/mx/Documents/ReFusionXx

Branch:
 codex/unified-keyframe-ops-foundation-20260426

Plan:
 sources/ui/fusionx-clean-ui-2/docs/professional_native_scene_intelligence_system_version_5.md

Current baseline:
 - VERSION 4 completed render-truth alignment.
 - Current remaining weakness is professional scene intelligence:
   text layout, icon alignment, motion vocabulary, component choreography,
   scene composition, taste validation, and skills.

Rules:
 - Do not rewrite one demo scene as the solution.
 - Do not create a second render/easing system.
 - Motion recipes compile to real SceneProgram channels and SpeedyGraph truth.
 - Text fit must be shared by QA/preview/export.
 - Brand icons must be registry-backed and legally traceable.
 - Do not touch Stage5/Live Scrub/native protected files unless explicitly
   required and documented.
 - Commit and push each phase separately.

Start:
 NSI-v5-00

Then continue in order through:
 NSI-v5-01 ... NSI-v5-14
```
