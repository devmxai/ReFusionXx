# Professional Native Scene Intelligence System - VERSION 5

Status: VERSION 5 execution active (v5-18 QA/build complete, device install pending connection)  
Package: `com.refusion.app`  
Branch: `codex/unified-keyframe-ops-foundation-20260426`  
Date opened: 2026-05-09  
Primary predecessors:

- `professional_native_scene_intelligence_system.md`
- `professional_native_scene_intelligence_system_version_2.md`
- `professional_native_scene_intelligence_system_version_3.md`
- `professional_native_scene_intelligence_system_version_4.md`

Scope: director-first authoring, professional motion vocabulary, shared text
layout enforcement, brand/icon intelligence, optical alignment, component
choreography, inter-component choreography, background semantic pairing, scene
composition intelligence, contextual micro-scenes, taste validation, visual
closure repair, and agent-facing skills so ReFusionXx can author native editable
scenes with professional motion-design quality instead of one-off demo fixes.

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
The agent writes a Director Brief.
The system translates that brief into professional native scene data through
executable vocabularies:
TextLayout + IconRegistry + MotionRecipes + ComponentChoreography
+ BackgroundPairing + SceneComposition + SceneTaste.
```

The agent must not guess:

- how to translate intent into a composition;
- where the primary focus should live;
- whether an icon is centered;
- how large an icon should be inside a card;
- whether body text can fit;
- which animation should be used;
- how cards should cascade;
- how children exit with their parent;
- whether a brand logo can be used;
- whether the background supports the foreground subject;
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
  -> Director Brief v5
  -> Director Intelligence Planner
  -> Semantic Blueprint v5
  -> Token Resolver
  -> Brand/Icon Registry
  -> Component Registry
  -> Background Semantic Pairing
  -> Shared Text Layout Engine
  -> Motion Recipe Compiler
  -> Component Choreography Compiler
  -> Inter-Component Choreography Solver
  -> Scene Composition Solver
  -> SceneProgram
  -> EvaluatedFrameTruth
  -> Visual QA + Taste QA + Motion Variety QA
  -> Apply/Preview/Export
```

Every stage must be observable through diagnostics and testable through focused
fixtures.

## 4. Core Contracts

### 4.0 Director Brief Contract

The highest-level agent-facing format is a Director Brief, not a loose element
list. The brief describes intent, mood, rhythm, audience, feature hierarchy, and
semantic content. The system then plans composition, motion, background, icons,
and timing.

Required shape:

```text
DirectorBrief
  intent
  audience
  mood
  primaryFocus
  rhythm
  aspect
  durationIntent
  brandContext
  visualStyle
  elements[]
```

Example:

```json
{
  "directorBrief": {
    "intent": "showcase 4 features of a native motion editor",
    "audience": "content creators and small business owners",
    "mood": "energetic professional modern",
    "primaryFocus": "smart kinetic typography",
    "rhythm": "intro slow -> feature cascade -> snap exit",
    "aspect": "$canvas.vertical9x16",
    "elements": [
      {
        "kind": "title",
        "text": "Everything your launch needs",
        "importance": "primary"
      },
      {
        "kind": "featureCardGroup",
        "importance": "primary",
        "cards": [
          {
            "icon": "$icon.montage",
            "label": "Fast",
            "body": "Polish edits in minutes"
          },
          {
            "icon": "$icon.audioEngineering",
            "label": "Voice",
            "body": "Clean voiceovers in one tap"
          }
        ]
      }
    ]
  }
}
```

Director Intelligence must produce:

- scene beat plan;
- focal hierarchy;
- aspect-aware composition;
- component choices;
- brand/icon choices;
- background semantic pairing;
- motion recipe assignments;
- component and inter-component choreography;
- repairable Semantic Blueprint v5.

The Director Brief is not rendered directly. It is compiled into Semantic
Blueprint v5, then into editable native SceneProgram data.

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
  - Perplexity
  - Grok
  - Copilot
  - Mistral
  - Llama
  - generic AI sparkle
- Social and creator platforms:
  - Meta
  - Facebook
  - Instagram
  - TikTok
  - Snapchat
  - Threads
  - Bluesky
  - X / Twitter
  - YouTube
  - LinkedIn
  - Reddit
  - Pinterest
  - generic social bubble
- Tech giants:
  - Apple
  - Microsoft
  - Amazon
  - Oracle
  - IBM
  - Samsung
- Cloud and storage:
  - iCloud
  - Google Drive
  - Dropbox
  - OneDrive
  - AWS
  - GitHub
- Communication and collaboration:
  - Gmail / Google Mail
  - Slack
  - WhatsApp
  - Telegram
  - Discord
  - Signal
  - Zoom
  - Teams
  - generic message
- Creative and design:
  - Figma
  - Canva
  - Adobe generic category token when allowed
  - generic vector/design tool
- Productivity and commerce:
  - Notion
  - Trello
  - Asana
  - Shopify
  - Stripe
  - PayPal
  - eBay
- Creator and audio platforms:
  - Twitch
  - Spotify
  - SoundCloud
  - Apple Music
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

Brand identity rules:

- brand colors may not be overridden unless the brand token declares an allowed
  monochrome or inverse variant;
- aspect ratio must be preserved;
- wordmarks require explicit safe-zone and minimum-size metadata;
- unsupported brand name must fail closed or fall back to a generic semantic
  icon with a visible diagnostic;
- AI may reference `$brand.chatgpt`; it may not write raw SVG paths, arbitrary
  brand colors, or invented logo geometry.

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

### 4.7 Background Semantic Pairing Contract

Backgrounds must support the foreground subject. They are not random
decoration. A background motif is chosen from the Director Brief topic,
foreground components, and mood.

Pairing map:

| Topic | Background motif |
|---|---|
| Audio / Voice | subtle waveform pulses, EQ bars, low-opacity sound rings |
| AI / Chatbot | particle network, prompt cursor glints, soft node links |
| Video editing | timeline strips, cut markers, frame guides |
| Color grading | gradient wash, color chips, wheel arcs |
| Speed / Performance | directional motion lines, compressed streaks |
| Cloud / Sync | small cloud dots, sync paths |
| Code / Builder | subtle grid, monospace particles, module blocks |
| Music | equalizer bars, beat ticks |
| Photography / Retouch | focus rings, crop grid, before/after wipe |
| Social | connection nodes, message bubbles |
| Privacy | shield/lock pattern, calm safe zones |

Rules:

- background opacity must not compete with primary content;
- background motion must be slower than foreground motion unless the beat is a
  transition;
- background elements must have lifecycle and density budgets;
- background may be disabled only through explicit `noBackground` intent;
- background motifs must be native editable shapes/text/icons when possible.

### 4.8 Brand-Aware Motion Mapping Contract

Brand and semantic categories influence default motion feel.

| Category | Motion feel | Defaults |
|---|---|---|
| AI / Tech | precise, snappy, clean | `$motion.brand.tech` |
| Social / Creator | playful, elastic, friendly | `$motion.brand.playful` |
| Premium / Luxury | restrained, slow, minimal | `$motion.brand.minimal` |
| Media / Cinematic | deliberate, deep, smooth | `$motion.brand.cinematic` |
| Productivity | efficient, low-noise | `$motion.brand.productivity` |
| Audio / Music | rhythmic, wave-like | `$motion.brand.rhythmic` |

Rules:

- if a card uses `$brand.chatgpt`, AI/tech recipes are preferred;
- if a card uses a playful social platform, bouncy recipes are allowed;
- if a scene mood is luxury/minimal, high-bounce recipes are blocked unless
  explicitly justified;
- brand-aware motion may suggest recipes, but final compiled channels still go
  through the Motion Recipe Compiler and SpeedyGraph truth.

### 4.9 Inter-Component Choreography Contract

Components in the same scene must know each other. A feature-card group,
feedback-wall, prompt-to-result transition, or hub scene is directed as a
relationship, not as isolated independent elements.

Rules:

- more than two siblings of the same type must use stagger or a declared group
  recipe;
- mirrored cards should use counter-directional entrances when visually useful;
- one beat may have only one primary focal element;
- high-energy motion must be balanced by lower-energy neighbors;
- group exits must be coherent unless the scene intentionally breaks apart;
- z-order and focus are solved from importance, not from JSON order alone.

### 4.10 Director Plan Validation Contract

Director Briefs must be validated before blueprint compilation.

Required:

- `intent` is specific;
- `mood` is from a known vocabulary or mapped to one;
- `rhythm` describes intro/hold/transition/outro behavior;
- every element has `importance`;
- feature groups have no duplicate cards unless intentionally repeated;
- mood, brand, and motion do not contradict each other;
- duration and aspect are present or inferred through explicit defaults.

Invalid brief examples:

- "make something cool" without intent;
- "luxury calm" plus all cards using `scaleInBounce`;
- feature card group with four primary cards and no hierarchy;
- brand references with missing registry tokens.

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

### `TF_SCENE_DIRECTOR_BRIEF_PROOF`

Fields:

- `briefHash`
- `intent`
- `mood`
- `rhythm`
- `aspect`
- `primaryFocus`
- `elementCount`
- `validated`
- `rejectionReason`
- `fallbackReason`

### `TF_SCENE_BACKGROUND_PAIRING_PROOF`

Fields:

- `sceneId`
- `topic`
- `selectedMotif`
- `backgroundElements`
- `opacityBudget`
- `motionBudget`
- `semanticMatchScore`
- `fallbackReason`

### `TF_SCENE_BRAND_ASSET_PROOF`

Fields:

- `brandId`
- `assetPath`
- `sourceKind`
- `licenseStatus`
- `colorVariant`
- `aspectPreserved`
- `safeZonePassed`
- `fallbackIconId`
- `fallbackReason`

### `TF_SCENE_INTER_COMPONENT_CHOREOGRAPHY_PROOF`

Fields:

- `groupId`
- `componentIds`
- `primaryFocus`
- `staggerMs`
- `counterDirectionApplied`
- `energyBalance`
- `zOrderResolved`
- `simultaneousMotionCount`
- `fallbackReason`

## 6. Execution Phases

Authoritative VERSION 5 phase order:

| Phase | Name |
|---|---|
| NSI-v5-00 | Failure fixtures and VERSION 4 foundation verification |
| NSI-v5-01 | Shared Text Layout Engine |
| NSI-v5-02 | Brand/Icon Registry |
| NSI-v5-03 | Brand Asset Pipeline and Legal Manifest |
| NSI-v5-04 | Optical Icon and Glyph Alignment |
| NSI-v5-05 | Motion Recipe Library v2 |
| NSI-v5-06 | Brand-Aware Motion Mapping |
| NSI-v5-07 | Component Internal Choreography |
| NSI-v5-08 | Inter-Component Choreography Solver |
| NSI-v5-09 | Background Semantic Pairing and Contextual Micro-Scenes |
| NSI-v5-10 | Scene Composition Intelligence Solver |
| NSI-v5-11 | Director Brief Schema and Director Plan Validator |
| NSI-v5-12 | Director Intelligence Planner |
| NSI-v5-13 | Rhythm, Density, Motion Variety, and Taste Validators |
| NSI-v5-14 | Semantic Blueprint v5 Agent Contract |
| NSI-v5-15 | Visual Closure Loop v2 |
| NSI-v5-16 | refusion-skills VERSION 5 Update |
| NSI-v5-17 | Comprehensive Director-Brief Templates and Regression Fixtures |
| NSI-v5-18 | Closure QA, Build, Install, Status Update |

The detailed sections below are the implementation requirements.

Execution status snapshot (2026-05-09):

| Phase | Status | Checkpoint |
|---|---|---|
| NSI-v5-00 | Completed | baseline fixtures and v4 truth checks integrated in test suite |
| NSI-v5-01 | Completed | shared text layout contract active in validators and compiler defaults |
| NSI-v5-02 | Completed | `d076bd0c` |
| NSI-v5-03 | Completed | `73559205` |
| NSI-v5-04 | Completed | `efa2cbe0` |
| NSI-v5-05 | Completed | `8d42c1d0` |
| NSI-v5-06 | Completed | `02d8442b` |
| NSI-v5-07 | Completed | `5d67f3d0` |
| NSI-v5-08 | Completed | `93ddf444` |
| NSI-v5-09 | Completed | `a0f06187`, `2ce6f04e` |
| NSI-v5-10 | Completed | `ff8e1d32` |
| NSI-v5-11 | Completed | `6e3b13cd` |
| NSI-v5-12 | Completed | `983a6e22` |
| NSI-v5-13 | Completed | `51b2b49d` |
| NSI-v5-14 | Completed | `2c01bafe` |
| NSI-v5-15 | Completed | `5ba4487b` |
| NSI-v5-16 | Completed | `refusion-skills: 03aac27` |
| NSI-v5-17 | Completed | `d0b9f0fd` |
| NSI-v5-18 | Completed (install pending device attach) | current checkpoint (this update) |

### NSI-v5-00 - Failure Fixtures And Professional Quality Baselines

Goal: capture the current visible failures as tests before building new
systems, and verify that VERSION 4 truth alignment is still intact.

Required:

- Re-run VERSION 4 foundation checks:
  - same blueprint evaluated repeatedly produces deterministic frame truth;
  - QA and preview consume `EvaluatedFrameTruth`;
  - coordinate-system canon remains center-origin;
  - HCT parent/child transform truth is still active.
- Add fixtures for:
  - app icon `R` shifted off-center;
  - card body text clipped or ending mid-phrase;
  - four cards using repetitive motion;
  - icon/text/card child choreography not synchronized;
  - brand icon missing and falling back incorrectly;
  - prompt icon-to-input morph with text starting too early.
  - background motif missing or semantically mismatched;
  - Director Brief with vague intent or contradictory mood/motion.
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
- At least one test rejects vague Director Brief input.

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
assets, and create the asset pipeline that makes brand usage traceable.

Create:

- `scene_icon_registry.dart`
- `scene_icon_token.dart`
- `scene_brand_asset_policy.dart`
- `scene_brand_asset_pipeline.dart`

Required:

- Register ReFusion semantic icons for editing, dubbing, captions, audio,
  retouching, color, presentations, upload, send, and app building.
- Add Tier 1 brand token slots for major platforms and products:
  - OpenAI / ChatGPT
  - Claude
  - Gemini
  - Perplexity
  - Grok
  - Copilot
  - Mistral
  - Llama
  - Meta
  - Facebook
  - Instagram
  - TikTok
  - Snapchat
  - Threads
  - Bluesky
  - X / Twitter
  - YouTube
  - LinkedIn
  - Reddit
  - Pinterest
  - Apple
  - Microsoft
  - Amazon
  - Oracle
  - IBM
  - Samsung
  - iCloud
  - Google Drive
  - Dropbox
  - OneDrive
  - AWS
  - GitHub
  - Google / Gmail
  - Slack
  - WhatsApp
  - Telegram
  - Discord
  - Signal
  - Zoom
  - Figma
  - Canva
  - Notion
  - Adobe generic category token when allowed
  - Trello
  - Asana
  - Shopify
  - Stripe
  - PayPal
  - eBay
  - Twitch
  - Spotify
  - SoundCloud
  - Apple Music
- For third-party brands, store license/source status.
- If an allowed bundled asset is not present, use a generic semantic fallback
  and emit a diagnostic.
- Support color modes: full color, monochrome, inverse, duotone.
- Load canonical SVG metadata when bundled assets are allowed.
- Validate color override rules.
- Generate or reference monochrome/inverse variants only when allowed by token
  metadata.
- Cache brand asset resolution.

Acceptance:

- Unknown brand does not create an invented logo.
- Restricted/unknown brand asset falls back safely.
- Registered generic semantic icons are available for native scenes.
- Brand color override is blocked unless the brand token allows it.
- `TF_SCENE_BRAND_ASSET_PROOF` is emitted for brand lookup and fallback.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 02 - brand icon registry
```

### NSI-v5-03 - Brand Asset Pipeline And Legal Manifest

Goal: make brand assets loadable, traceable, cacheable, and legally safe.

Create:

- `scene_brand_asset_pipeline.dart`
- `scene_brand_asset_manifest.dart`
- `scene_brand_asset_cache.dart`

Required:

- Define a manifest format for every bundled brand asset:
  - brand id;
  - asset paths;
  - source;
  - usage notes;
  - license/trademark status;
  - file hash;
  - canonical colors;
  - allowed variants;
  - fallback token.
- Load canonical SVGs only through the registry.
- Block raw color override unless allowed.
- Generate or reference monochrome/inverse variants only when allowed.
- Support user-provided brand assets with explicit `sourceKind=userProvided`.
- Emit `TF_SCENE_BRAND_ASSET_PROOF`.

Acceptance:

- Missing brand asset does not crash or invent a logo.
- Unknown license status fails closed or falls back to a generic semantic icon.
- Manifest hash mismatch is detected.
- Brand color override is rejected unless explicitly allowed.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 03 - brand asset pipeline
```

### NSI-v5-04 - Optical Icon And Glyph Alignment

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
checkpoint: professional native scene intelligence v5 04 - optical icon alignment
```

### NSI-v5-05 - Motion Recipe Library v2

Goal: give agents professional executable animation vocabulary.

Create:

- `scene_motion_recipe_library.dart`
- `scene_motion_recipe_compiler.dart`
- `scene_motion_recipe_models.dart`

Required:

- Implement the minimum recipe set listed in section 4.4.
- Add recipe categories, compatibility matrix, aspect bias, and taste notes.
- Add recipe-to-SpeedyGraph mapping.
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
checkpoint: professional native scene intelligence v5 05 - motion recipe library
```

### NSI-v5-06 - Brand-Aware Motion Mapping

Goal: map brand and semantic categories to professional motion feel.

Create:

- `scene_brand_motion_mapping.dart`
- `scene_brand_motion_profile.dart`

Required:

- Map AI/tech brands to precise/snappy motion.
- Map social/creator brands to playful/bouncy motion.
- Map premium/luxury brands to restrained/minimal motion.
- Map cinematic/media subjects to deliberate smooth motion.
- Map productivity subjects to clean efficient motion.
- Map audio/music subjects to rhythmic wave-like motion.
- Ensure mapping selects defaults only; final output still compiles through
  Motion Recipe Compiler and SpeedyGraph truth.

Acceptance:

- `$brand.chatgpt` prefers AI/tech recipe profile.
- playful social brand cards may use elastic recipes.
- luxury mood blocks excessive bounce unless explicitly justified.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 06 - brand aware motion mapping
```

### NSI-v5-07 - Component Internal Choreography Engine

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
checkpoint: professional native scene intelligence v5 07 - component choreography
```

### NSI-v5-08 - Inter-Component Choreography Solver

Goal: coordinate sibling components so scenes feel directed, not independently
animated.

Create:

- `scene_inter_component_choreography.dart`
- `scene_group_choreography_solver.dart`

Required:

- Apply cascade stagger for groups of similar siblings.
- Apply counter-direction entrances when useful for balance.
- Resolve z-order from importance and focal hierarchy.
- Apply energy conservation:
  - high-energy primary element;
  - calmer supporting neighbors.
- Keep group exits coherent.
- Prevent more than one primary focal element in the same beat.
- Emit `TF_SCENE_INTER_COMPONENT_CHOREOGRAPHY_PROOF`.

Acceptance:

- Four feature cards enter as a planned group, not four unrelated animations.
- Two opposing cards can mirror motion direction.
- Group exit is coherent and does not leave orphan children.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 08 - inter component choreography
```

### NSI-v5-09 - Background Semantic Pairing And Contextual Micro-Scenes

Goal: connect the background and feature-card internal visuals to the semantic
subject of the scene.

Create:

- `scene_background_semantic_pairing.dart`
- `scene_micro_scene_registry.dart`
- `scene_feature_visual_motifs.dart`

Required:

- Implement the background pairing map in section 4.7.
- Add native editable motifs for:
  - audio engineering: waveform, EQ bars, noise gate dots;
  - captions: kinetic text lines, highlighted word pill;
  - montage: timeline strips, cut markers, playhead;
  - image retouch: before/after chip, sparkle retouch path;
  - color grade: color wheels/chips, LUT slider;
  - presentations: slide stack, chart bars;
  - app builder: prompt bar, app tile, module blocks.
- Motifs must be shapes/text/icons, not raster-only screenshots.
- Motifs must have choreography hooks and parent lifecycle.
- Emit `TF_SCENE_BACKGROUND_PAIRING_PROOF`.

Acceptance:

- A voice/audio scene gets a subtle waveform or EQ motif by default.
- A code/app-builder scene gets grid/module motifs.
- Background opacity and motion never compete with foreground content.
- Feature-card motifs fit inside card bounds.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 09 - background pairing micro scenes
```

### NSI-v5-10 - Scene Composition Intelligence Solver

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
checkpoint: professional native scene intelligence v5 10 - scene composition solver
```

### NSI-v5-11 - Director Brief Schema And Director Plan Validator

Goal: make the highest-level authoring input explicit and reject vague,
contradictory, or unprofessional briefs before planning.

Create:

- `scene_director_brief_models.dart`
- `scene_director_plan_validator.dart`

Required:

- Validate `intent`, `audience`, `mood`, `rhythm`, `aspect`, `durationIntent`,
  `primaryFocus`, and `elements`.
- Require every element to declare `importance`.
- Reject contradictory mood/motion/brand combinations.
- Reject duplicate elements unless intentionally repeated.
- Reject briefs with no clear focal hierarchy.
- Emit `TF_SCENE_DIRECTOR_BRIEF_PROOF`.

Acceptance:

- "make something cool" is rejected.
- "luxury calm" with all components bouncy is rejected or repaired.
- Feature groups with four primary cards and no hierarchy are rejected.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 11 - director brief validator
```

### NSI-v5-12 - Director Intelligence Planner

Goal: compile `DirectorBrief -> SemanticBlueprint v5` with professional
composition, rhythm, background, icon, and choreography decisions.

Create:

- `scene_director_intelligence.dart`
- `scene_director_planner.dart`
- `scene_director_blueprint_compiler.dart`

Required:

- Convert Director Brief to Semantic Blueprint v5.
- Plan composition from importance and aspect ratio.
- Plan beat structure from rhythm.
- Assign motion recipes from mood, brand, and component role.
- Attach background semantic pairing.
- Attach component and inter-component choreography.
- Preserve repairable paths back to the original brief.

Acceptance:

- A 30-line Director Brief can produce a complete editable scene blueprint.
- Primary element receives stronger motion than supporting elements.
- Background and motion choices match subject and mood.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 12 - director intelligence planner
```

### NSI-v5-13 - Rhythm, Density, Motion Variety, And Taste Validators

Goal: reject visually boring, crowded, under-composed, or proportionally weak
scenes.

Create:

- `scene_motion_variety_validator.dart`
- `scene_motion_rhythm_validator.dart`
- `scene_rhythm_density_validator.dart`
- `scene_professional_taste_validator.dart`
- `scene_component_proportion_validator.dart`

Required:

- Reject fade-only professional scenes.
- Reject siblings where more than 60% use the same recipe unless the group is
  explicitly a cascade.
- Enforce enter recipe != exit recipe.
- Enforce readable holds after complex motion.
- Enforce aspect-aware motion preferences.
- Limit simultaneous major animations per beat.
- Validate tempo, negative space, visual density, focal point count, and
  simultaneous motion budget.
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

- Four feature cards all using opacity-only fade are rejected.
- A professional grid stagger passes.
- Enter/exit symmetry is accepted only when declared as a deliberate mirror.
- A card with huge title and tiny body is rejected.
- A card with body outside its frame is rejected.
- A prompt icon with shifted `R` is rejected.
- A scene with excessive simultaneous motion is rejected or warned according to
  severity.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 13 - rhythm density taste validators
```

### NSI-v5-14 - Semantic Blueprint v5 Agent Contract

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
checkpoint: professional native scene intelligence v5 14 - semantic blueprint v5
```

### NSI-v5-15 - Visual Closure Loop v2 And Repair Payloads

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
- Add loop orchestration:
  - max 3 repair attempts;
  - visual descriptions for each failed probe;
  - suggested motion alternatives;
  - suggested text/icon/layout token fixes;
  - exemplar saving for approved scenes.

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
- `MOTION_VARIETY_LOW` suggests specific replacement recipes per card.
- `ICON_OPTICAL_CENTER_OFF` suggests optical correction, not manual x/y.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 15 - visual closure loop v2
```

### NSI-v5-16 - refusion-skills VERSION 5 Update

Repository:

```text
/Users/mx/Documents/refusion-skills
```

Goal: any external agent given the skills repo should author scenes with the new
professional vocabulary.

Required:

- Add:
  - Director Brief authoring guide;
  - Director Plan validator rules;
  - motion recipe guide;
  - brand-aware motion guide;
  - brand/icon usage guide;
  - brand asset/legal fallback guide;
  - component choreography guide;
  - inter-component choreography guide;
  - background semantic pairing map;
  - text layout guide;
  - scene composition guide;
  - rhythm/density principles;
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
- Skills teach that agents write Director Briefs first, not raw element lists.
- Skills include at least 10 good examples and 10 rejected examples with reasons.

Checkpoint:

```text
checkpoint: professional native scene intelligence v5 16 - refusion skills v5
```

### NSI-v5-17 - Comprehensive Director-Brief Templates And Regression Fixtures

Goal: prove the system with real examples.

Required examples:

1. Prompt icon to input bar to fullscreen circle.
2. ReFusion premium app feature grid.
3. SaaS feedback card wall with brand/generic icons.
4. Audio engineering feature card.
5. Captions kinetic text feature card.
6. Image retouch/color-grade feature card.
7. Multi-aspect adaptation test scene.
8. AI features cascade.
9. Social app promo.
10. Tech brand intro.
11. Testimonial quote.
12. Before/after split.

Required:

- Add Director Brief-only templates where possible.
- Add good/bad pairs with rejection reasons.
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
checkpoint: professional native scene intelligence v5 17 - professional examples
```

### NSI-v5-18 - Closure QA, Build, Install, Status Update

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
checkpoint: professional native scene intelligence v5 18 - closure qa
```

Execution result (2026-05-09):

- Focused closure tests executed and passed:
  - `scene_program_layout_contract_test.dart`
  - `scene_semantic_constraint_layout_solver_test.dart`
  - `scene_icon_registry_test.dart`
  - `scene_icon_alignment_validator_test.dart`
  - `scene_motion_recipe_compiler_test.dart`
  - `scene_component_choreography_engine_test.dart`
  - `scene_inter_component_choreography_test.dart`
  - `scene_composition_solver_test.dart`
  - `scene_rhythm_density_validator_test.dart`
  - `scene_professional_taste_grammar_test.dart`
  - `scene_visual_closure_loop_service_test.dart`
  - `scene_semantic_repair_loop_service_test.dart`
  - `scene_prompt_burst_regression_test.dart`
  - `scene_render_truth_alignment_test.dart`
  - `scene_render_truth_alignment_validator_test.dart`
  - `scene_director_brief_templates_regression_test.dart`
  - `motion_bezier_velocity_bridge_test.dart`
  - `professional_speed_graph_preset_catalog_test.dart`
- Build executed and passed:
  - `flutter build apk --debug`
  - artifact: `build/app/outputs/flutter-apk/app-debug.apk`
- Device install status:
  - `adb devices -l` returned no attached devices at execution time.
  - install step is pending device reconnect.

Commits in this final stretch:

- App repo:
  - `5ba4487b` - v5-15 visual closure loop v2
  - `d0b9f0fd` - v5-17 templates and regression fixtures
- Skills repo:
  - `03aac27` - v5-16 refusion-skills v5 update

Remaining risks:

1. No connected Android device was available for live install verification in
   this checkpoint.
2. Existing preset scene visual style can still be improved artistically; core
   enforcement and director-first pipeline now block structural quality
   regressions, but curated preset polish remains an iterative content task.

## 7. Integration Gates

Gate after v5-01:

- QA and preview agree on effective text layout.

Gate after v5-03:

- brand assets resolve through manifest, license status, fallback, and hash.

Gate after v5-04:

- App icon `R`, plus icon, and send icon are optically centered.

Gate after v5-05:

- At least 12 motion recipes compile to editable channels.

Gate after v5-06:

- brand category maps to motion feel without bypassing SpeedyGraph truth.

Gate after v5-07:

- `FeatureCard` and `PromptInputBar` demonstrate child choreography.

Gate after v5-08:

- sibling components demonstrate cascade, counter-direction, or coherent group
  timing.

Gate after v5-09:

- background semantic pairing and micro-scenes match scene topic without
  competing with foreground.

Gate after v5-11:

- vague or contradictory Director Briefs are rejected.

Gate after v5-12:

- Director Brief compiles to Semantic Blueprint with composition, motion,
  background, and choreography decisions.

Gate after v5-13:

- Fade-only scenes are rejected.
- bad proportions and bad icon/text/card ratios are rejected.

Gate after v5-17:

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

- allow agent-facing professional authoring to bypass Director Brief when a
  Director Brief path exists;
- add raw random coordinates when component/layout contract exists;
- bundle unlicensed third-party brand logos;
- invent brand logos;
- allow raw brand color override when a brand token forbids it;
- allow background decoration that is not semantically paired unless explicitly
  disabled;
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

- Director Brief is the preferred agent-facing authoring layer;
- Director Brief validator rejects vague, contradictory, or hierarchy-free
  briefs;
- Director Intelligence compiles brief intent into Semantic Blueprint v5;
- any text inside a professional component is laid out by the shared text engine;
- app icon glyphs and button icons are optically centered;
- brand/generic icons are resolved through the icon registry;
- brand assets are source/usage/fallback traceable;
- background semantic pairing supports scene intent;
- motion recipes are executable and editable;
- brand-aware motion maps category to feel without bypassing recipe compilation;
- feature cards have internal choreography;
- component groups have inter-component choreography;
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
   Director Brief planning, text layout, brand/icon assets, optical alignment,
   motion vocabulary, background pairing, component choreography,
   inter-component choreography, scene composition, taste validation, visual
   closure, and skills.

Rules:
 - Do not rewrite one demo scene as the solution.
 - Do not leave Director Intelligence as documentation only; implement
   DirectorBrief -> SemanticBlueprint planning as a real phase.
 - Do not create a second render/easing system.
 - Motion recipes compile to real SceneProgram channels and SpeedyGraph truth.
 - Text fit must be shared by QA/preview/export.
 - Brand icons must be registry-backed and legally traceable.
 - Brand assets must be legal/source/fallback traceable.
 - Background motifs must be semantically paired or explicitly disabled.
 - Do not touch Stage5/Live Scrub/native protected files unless explicitly
   required and documented.
 - Commit and push each phase separately.

Start:
 NSI-v5-00

Then continue in order through:
 NSI-v5-01 ... NSI-v5-18
```
