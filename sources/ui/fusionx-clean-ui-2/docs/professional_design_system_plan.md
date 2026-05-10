# Professional Design System Plan

Status: execution plan  
Scope: ReFusionXx professional motion scene authoring, component runtime, design
authority, Director Brief compilation, and strict scene quality gates.

## 0. Executive Decision

The professional path is not another hand-authored scene. The path is one
integrated system:

```text
PMCR runtime truth
  -> component contracts
  -> component-aware lowering and evaluation
  -> strict apply gates
  -> Design System Authority
  -> Director Brief compiler
  -> professional templates and repair loop
```

PMCR is the plumbing. It makes parent/child, text, border, lifecycle, and
render truth deterministic.

Design System Authority is the furniture. It makes typography, spacing,
proportion, optical alignment, motion, icons, backgrounds, templates, and
composition professional by default.

Neither half is sufficient alone:

- PMCR without design authority produces technically coherent but visually weak
  scenes.
- Design authority without PMCR produces attractive specs over a runtime that
  can still separate cards from children, clip text, lose borders, or mix old
  and new scenes.

## 1. Current Baseline

The current implementation has already completed the PMCR foundation through
`PMCR-06`:

- runtime baseline audit;
- global parent graph;
- component runtime tree indexes;
- transform, opacity, and lifecycle propagation foundation;
- slot layout solver;
- shared text layout engine;
- shape stroke and border render contract.

The remaining runtime phases are:

1. `PMCR-07` - PromptInputBar Runtime Component Proof
2. `PMCR-08` - FeatureCard Runtime Component
3. `PMCR-09` - CTAButton Runtime Component
4. `PMCR-10` - Component Choreography Compiler
5. `PMCR-11` - Component-Aware SceneProgram Lowerer
6. `PMCR-12` - Component-Aware Evaluation Pipeline
7. `PMCR-13` - Strict Component QA Gate
8. `PMCR-14` - Agent Director Integration
9. `PMCR-15` - Professional Regression Suite

This plan starts from that reality. It does not restart PMCR from zero.

## 2. Failure Model This Plan Must Eliminate

The plan is successful only if these failures become structurally impossible:

- a parent card exits while icon/text children remain visible;
- a prompt bar shell disappears while icons remain;
- text is larger than its slot or card;
- body text is clipped mid-sentence;
- a border/stroke is required but visually invisible after scale;
- an icon or glyph is geometrically centered but optically off-center;
- a scene contains old preset layers mixed with a new scene;
- the validator checks one geometry while preview/apply/render use another;
- raw `x`, `y`, `fontSize`, `padding`, `width`, or `height` values appear in
  professional blueprints without explicit override proof;
- four cards all use the same fade animation and pass as "professional";
- Director or AI output invents child coordinates inside known components;
- a scene passes import with warnings even though it has structural visual
  defects.

## 3. Core Architecture

### 3.1 Runtime Truth

Runtime truth is a component tree, not a flat element list:

```text
SceneRoot
  Beat
    Component
      Slot
        Leaf
```

Rules:

- parent transform cascades to all descendants;
- parent opacity multiplies descendant opacity;
- parent visibility controls descendant visibility;
- child lifetime must be inside parent lifetime unless explicitly detached;
- slots own child placement;
- shared text layout owns text measurement and fit;
- stroke contracts own border visibility;
- `EvaluatedFrameTruth` is consumed by QA, apply, preview, and export.

### 3.2 Design Authority

Design authority is a tested vocabulary:

```text
TypeScale + SpacingScale + RadiusScale + MotionScale
  -> ProportionalRules
  -> ComponentLibrary
  -> MotionPatternLibrary
  -> BrandIconRegistry
  -> BackgroundPairing
  -> SceneTemplates
  -> DirectorBriefCompiler
```

The AI does not invent coordinates. The AI chooses intent, components, content,
and mood. The engine resolves professional values.

## 4. Non-Negotiable Rules

1. Professional scenes use components, not loose raw layers, when a known
   component exists.
2. Prompt bars, feature cards, CTA buttons, panels, grids, and text fields must
   use runtime component contracts.
3. No child may outlive its parent.
4. No text may render without a text frame, fit policy, and shared text layout
   result.
5. No required border may render below the effective visible threshold.
6. No professional blueprint may use raw design values unless marked with
   `rawValueOverride` and proof.
7. No brand asset may be bundled or referenced without source, license status,
   fallback, and safe-zone metadata.
8. Motion recipes compile to editable native channels. They are not decorative
   metadata.
9. QA, apply, preview, and export must consume the same evaluated truth.
10. Agent Director starts after strict component gates exist. It must not
    compensate for missing runtime behavior.

## 5. Gate-First Execution Model

Every phase must define:

- entry prerequisites;
- exact files or modules expected;
- fatal errors introduced or enforced;
- required passing fixtures;
- required failing fixtures;
- smallest verification command;
- checkpoint commit and push;
- rollback command.

No phase may be considered complete because a scene "looks better" in one
preview. Completion requires proof tags and tests.

Required proof tags:

- `PDS_TOKEN_RESOLUTION_PROOF`
- `PDS_PARENT_GRAPH_PROOF`
- `PDS_COMPONENT_TREE_PROOF`
- `PDS_SLOT_LAYOUT_PROOF`
- `PDS_TEXT_LAYOUT_PROOF`
- `PDS_STROKE_VISIBILITY_PROOF`
- `PDS_CHOREOGRAPHY_PROOF`
- `PDS_LOWERING_PROOF`
- `PDS_EVALUATED_FRAME_TRUTH_PROOF`
- `PDS_COMPONENT_QA_PROOF`
- `PDS_APPLY_TRANSACTION_PROOF`
- `PDS_DESIGN_SCORE_PROOF`

## 6. Phase Plan

### PDS-00 - Baseline Freeze And Failure Fixtures

Goal: establish the current truth before building the next layers.

Required work:

- map completed PMCR-00 through PMCR-06 files and tests;
- freeze the remaining PMCR phases as the runtime critical path;
- create or document failure fixtures for:
  - prompt bar child outliving shell;
  - feature card text overflow;
  - CTA icon drifting from label;
  - invisible border after scaling;
  - raw values inside professional blueprint;
  - legacy scene mixed with new scene;
  - repeated fade-only cards;
  - optically off-center app icon glyph.

Exit gate:

- every listed failure has a named expected error;
- no implementation phase starts without a matching failure fixture or test
  note.

### PDS-01 - PromptInputBar Runtime Component Proof

Maps to: `PMCR-07`.

Goal: build the first professional runtime component and prove the entire
parent/slot/text/border/lifecycle system on one vertical slice.

Component contract:

```text
PromptInputBar
  shell
  leftIconSlot
  textSlot
  micSlot
  sendButtonSlot
  optional accessorySlot
```

Design constraints:

- shell fill: white or tokenized surface;
- border: required and visibly >= 1px after scale;
- radius: tokenized pill radius;
- text: regular weight, baseline-centered, slot-fit;
- icons: optical center inside slots;
- prompt text never begins before the text slot is stable.

Choreography:

```text
shell spring in
left icon pop
right controls pop staggered
text typewriter
send press
group exit together
```

Fatal errors:

- `PROMPT_CHILD_OUTLIVES_SHELL`
- `PROMPT_TEXT_EXCEEDS_TEXT_SLOT`
- `PROMPT_BORDER_NOT_VISIBLE`
- `PROMPT_ICON_OUT_OF_SLOT`
- `PROMPT_RAW_CHILD_COORDINATE`

Exit gate:

- component works in 9:16, 16:9, 1:1, and 4:5;
- no child remains visible after shell exit;
- `Professional Test Version 2` can be rebuilt through component path, not
  manual raw layers;
- targeted tests pass.

### PDS-02 - FeatureCard Runtime Component

Maps to: `PMCR-08`.

Goal: make cards professional by default.

Component contract:

```text
FeatureCard
  shell
  iconContainer
  iconGlyph
  titleSlot
  bodySlot
  optionalAccent
```

Design constraints:

- title/body are a vertical stack with measured bounds;
- body uses `wrapToLines` or `shrinkToFit` by default;
- body text cannot end with dangling phrase fragments;
- icon size is proportional to card height;
- padding and gap are tokenized;
- baseline alignment is stable across card groups.

Choreography:

```text
shell spring or slide in
icon container pop
icon glyph settle
title word cascade
body soft reveal
hold
group exit together
```

Fatal errors:

- `FEATURE_TEXT_CLIPPED`
- `FEATURE_SENTENCE_CUT_MID_PHRASE`
- `FEATURE_ICON_MISALIGNED`
- `FEATURE_BODY_BASELINE_OUT_OF_SLOT`
- `FEATURE_CHILD_VISIBLE_AFTER_CARD_EXIT`

Exit gate:

- three stacked analysis cards pass;
- four-card feature grid pass;
- long body fixture fails without fit policy and passes with policy;
- all children exit with card shell.

### PDS-03 - CTAButton Runtime Component

Maps to: `PMCR-09`.

Goal: make final CTA pills and action buttons coherent.

Component contract:

```text
CTAButton
  shell
  labelSlot
  trailingIconSlot
```

Design constraints:

- label and icon are optically centered as a group;
- arrow aligns to label baseline, not raw bounding box;
- border/shadow/shape are predictable;
- CTA hold is readable.

Fatal errors:

- `CTA_LABEL_OVERFLOW`
- `CTA_ICON_BASELINE_DRIFT`
- `CTA_BORDER_NOT_VISIBLE`
- `CTA_CHILD_OUTLIVES_SHELL`

Exit gate:

- `Available now` CTA passes in all supported aspect ratios;
- trailing icon does not drift independently;
- group entrance/hold/exit are coherent.

### PDS-04 - Component Choreography Compiler

Maps to: `PMCR-10`.

Goal: compile component-level choreography to editable native channels without
breaking runtime truth.

Required model:

```text
ComponentChoreography
  prepare
  enter
  internalReveal
  hold
  action
  exit
```

Required semantics:

- child delays are relative to parent local time;
- stagger policies are deterministic;
- component exit terminates descendants;
- overlapping same target/property channels are rejected unless intentionally
  merged;
- fade is a primitive, not the default professional recipe.

Fatal errors:

- `DUPLICATE_CHANNEL_OVERLAP`
- `CHILD_TIMING_OUTSIDE_PARENT`
- `GROUP_EXIT_INCOHERENT`
- `FADE_ONLY_PROFESSIONAL_RECIPE`

Exit gate:

- PromptInputBar, FeatureCard, and CTAButton choreography compile
  deterministically;
- generated channels remain editable;
- target/property conflicts are caught before lowering.

### PDS-05 - Component-Aware SceneProgram Lowerer

Maps to: `PMCR-11`.

Goal: lower components to SceneProgram while preserving component truth.

Required work:

- preserve component ids;
- preserve slot ids and bounds;
- preserve parent graph metadata;
- preserve source maps;
- respect `timeBasis`;
- avoid double-offsetting project-time keyframes;
- keep layer-time keyframes supported.

Fatal errors:

- `LOWERER_COMPONENT_METADATA_LOST`
- `LOWERER_SLOT_METADATA_LOST`
- `LOWERER_PARENT_GRAPH_DRIFT`
- `LOWERER_TIMEBASIS_DOUBLE_OFFSET`

Exit gate:

- component scenes apply without manual timing patches;
- source maps can trace every rendered child to component/slot;
- professional raw-layer fallback is blocked unless marked legacy.

### PDS-06 - Component-Aware Evaluation Pipeline

Maps to: `PMCR-12`.

Goal: make `EvaluatedFrameTruth` report component truth, not only raw element
truth.

Required outputs:

- component bounds;
- slot bounds;
- child bounds;
- text layout result;
- effective opacity;
- effective visibility;
- lifecycle diagnostics;
- hierarchy diagnostics;
- stroke visibility diagnostics;
- optical alignment diagnostics.

Fatal errors:

- `EVALUATION_COMPONENT_TRUTH_MISSING`
- `EVALUATION_SLOT_TRUTH_MISSING`
- `EVALUATION_QA_RENDER_TRUTH_DRIFT`

Exit gate:

- QA can answer whether text is inside its slot at every probe frame;
- QA can answer whether child is visible after parent exit;
- preview/apply/export can consume the same truth shape.

### PDS-07 - Strict Component QA And Apply Gate

Maps to: `PMCR-13`.

Goal: reject component-invalid scenes before they reach the user.

Required checks:

- child outlives parent;
- child visible while parent invisible;
- text exceeds slot;
- icon exceeds slot;
- border required but invisible;
- unsupported raw coordinates inside known component;
- repeated uncoordinated fades;
- component exit is not group-coherent;
- active scene has legacy layers outside current source map.

Fatal errors:

- all component structural defects are errors, never warnings;
- "valid with warnings" is not allowed for professional scenes.

Exit gate:

- raw-layer prompt bar is rejected when marked professional;
- component-authored prompt bar passes;
- errors include repair payloads;
- apply transaction blocks invalid scenes.

### PDS-08 - Transactional Apply And Legacy Isolation

Goal: prevent old and new scenes from mixing.

Required work:

- apply by `sceneId` and `sourceProgramId`;
- replace active scene scope atomically;
- clear old present-scene elements before applying replacement;
- preserve unrelated project data only when outside active scene scope;
- record `PDS_APPLY_TRANSACTION_PROOF`.

Fatal errors:

- `LEGACY_LAYER_MIXED_WITH_ACTIVE_SCENE`
- `SCENE_ID_REPLACEMENT_SCOPE_MISSING`
- `ACTIVE_PROGRAM_SOURCE_MISMATCH`

Exit gate:

- selecting a new professional preset cannot render any old preset layers;
- apply failure reports exact blocking reason;
- migration path is explicit for legacy presets.

### PDS-09 - Agent Director Integration On Components

Maps to: `PMCR-14`.

Goal: allow AI/Director only after deterministic component runtime gates exist.

Required work:

- Director Brief chooses components, not raw layers;
- Director selects from component registry;
- Director selects motion recipes from allowed vocabulary;
- Director cannot invent child positions inside components;
- repair loop receives component-level errors.

Required repair codes:

- `TEXT_EXCEEDS_TEXT_SLOT`
- `CHILD_OUTLIVES_PARENT`
- `BORDER_NOT_VISIBLE`
- `GROUP_EXIT_INCOHERENT`
- `RAW_LAYER_USED_WHERE_COMPONENT_EXISTS`
- `MOTION_VARIETY_LOW`
- `ICON_OPTICAL_MISALIGNMENT`

Exit gate:

- Director Brief can generate prompt bar, word swap, analysis cards, and CTA
  without raw coordinate guessing;
- vague briefs are rejected with missing intent/hierarchy errors;
- failed output receives repair payloads tied to component contracts.

### PDS-10 - Runtime Professional Regression Suite

Maps to: `PMCR-15`.

Goal: prove runtime professionalism before adding broad design authority.

Required fixtures:

- centered prompt bar intro;
- word swap headline;
- three analysis cards;
- final available-now CTA;
- SaaS feedback cards;
- app icon intro;
- feature grid;
- dashboard panel.

Exit gate:

- all fixtures pass component QA;
- all fixtures pass visual QA;
- all fixtures pass render truth alignment;
- all fixtures pass apply transaction;
- at least one fixture passes 9:16, 16:9, 1:1, and 4:5;
- no fixture uses loose raw coordinates inside known components.

## 7. Design System Authority Phases

Design System Authority starts implementation only after `PDS-07` is passing
and ideally after `PDS-10` is green. Its documentation and token names may be
prepared earlier, but it must not bypass runtime gates.

### PDS-11 - Design Token Resolver

Goal: define the values AI may choose from.

Required token groups:

- type scale;
- spacing scale;
- radius scale;
- stroke scale;
- shadow scale;
- duration scale;
- easing scale;
- motion energy scale;
- safe-area scale;
- color roles.

Type scale:

```text
caption = 14
body = 18
bodyLg = 22
titleSm = 28
title = 35
titleLg = 44
display = 56
hero = 70
```

Spacing scale:

```text
4, 8, 12, 16, 24, 32, 48, 64, 96
```

Rules:

- no raw design values in professional blueprints;
- token resolution is deterministic;
- token values adapt by aspect profile where needed;
- token overrides require proof and diagnostics.

Expected files:

- `design_type_scale.dart`
- `design_spacing_scale.dart`
- `design_radius_scale.dart`
- `design_duration_scale.dart`
- `design_token_resolver.dart`

### PDS-12 - Proportional Rules And Aspect Policy

Goal: make component sizing professional by relationship, not guesses.

Rules:

- `card.minWidth = title.fontSize * 6`;
- `card.minPadding = body.fontSize * 1.5`;
- inline icon size is near related text size;
- heading icon size is about `title * 1.4`;
- content width is usually 60-75% of container;
- portrait layouts prefer vertical flow;
- landscape layouts prefer horizontal/diagonal flow;
- square layouts prefer centered stacked balance;
- 4:5 feed layouts protect top/bottom captions.

Exit gate:

- same component scene adapts to 9:16, 16:9, 1:1, and 4:5 without clipping;
- every proportional decision is traceable in diagnostics.

### PDS-13 - Optical Alignment Engine

Goal: center by visual mass, not raw bounds.

Rules:

- `R`: shift right around 3% when used as a glyph icon;
- `A/V/W`: shift down around 2%;
- `O/C/G`: scale around 102%;
- up triangle: shift down around 3%;
- arrows use optical center corrections;
- logos use stored optical bounds and safe zones.

Exit gate:

- app icon `R` center delta <= 1.5px at design scale;
- button icon center delta <= 1px;
- brand icons respect safe zone metadata.

### PDS-14 - Component Library v1

Goal: provide a tested professional component vocabulary.

Minimum components:

- PromptInputBar
- SearchBar
- TextField
- FeatureCard
- StatCard
- TestimonialCard
- ProductCard
- ImageCard
- CTAButton
- IconButton
- FAB
- ToggleButton
- DashboardPanel
- FeatureGrid
- FeatureList
- HeroSection
- AppIconIntro
- BrandLogo
- AvatarBadge
- Toast
- AlertCard
- ProgressIndicator
- VideoPlayer
- AudioWaveform
- ColorGradePanel
- MotionTextBlock
- KineticTitle
- TypingPrompt
- QuoteBlock
- OrbitalRing

Every component requires:

- HCT contract;
- slots;
- states/variants;
- type tokens;
- spacing tokens;
- motion defaults;
- internal choreography;
- QA tests;
- good fixture;
- bad fixture;
- snapshot/reference visual.

### PDS-15 - Motion Pattern Library And Variety Gate

Goal: replace fade-only output with a professional motion vocabulary.

Required recipe families:

- entrance;
- exit;
- group;
- attention;
- text;
- icon;
- transition;
- brand-aware motion.

Minimum recipes:

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
- `typewriterFixedFrame`
- `wordCascadeUp`
- `lineRevealMask`
- `iconPop`
- `sendPress`
- `cardSpringEntrance`
- `cardStackCascade`
- `gridStaggerProfessional`
- `morphIconToPromptBar`
- `promptBarToFullscreenCircle`
- `matchCutSlide`
- `scaleThrough`

Exit gate:

- more than 60% repeated sibling motion recipe fails unless declared as a
  group recipe;
- duplicate channels for the same target/property fail;
- each recipe compiles to editable native channels.

### PDS-16 - Brand And Icon Registry

Goal: provide legal, traceable, optically aligned icons.

Registry metadata:

- id;
- category;
- display name;
- source kind;
- source path or user-provided reference;
- license status;
- color modes;
- viewBox;
- optical bounds;
- safe zones;
- fallback icon id;
- preferred motion feel.

Rule:

Do not bundle third-party brand logos unless source and usage status are
documented. Unknown brands require user-provided assets or generic semantic
fallbacks.

### PDS-17 - Background Semantic Pairing

Goal: make backgrounds support the foreground subject.

Examples:

- audio/voice -> waveform pulses;
- AI/chatbot -> prompt cursor glints and node links;
- video editing -> timeline strips and cut markers;
- color grading -> gradient wash and color chips;
- speed/performance -> directional motion lines;
- cloud/sync -> soft dots and paths;
- code/builder -> subtle grid and module blocks;
- social -> connection nodes and message bubbles.

Rules:

- background opacity does not compete with foreground;
- background motion is slower than foreground except during transitions;
- background elements have lifecycle and density budgets;
- background may be disabled only with explicit `noBackground` intent.

### PDS-18 - Composition Rules And Design Scorecard

Goal: make scenes balanced like a strong web/app layout.

Rules:

- one primary focal element per beat;
- negative space target: 40-70%;
- foreground/background visual weight follows 60/30/10 where applicable;
- max five major simultaneous animations unless deliberate climax;
- z-order comes from importance, not JSON order alone;
- card grids require container contracts;
- card groups require stagger or group choreography.

Scorecard:

- typography hierarchy;
- spacing rhythm;
- component cohesion;
- visual hierarchy;
- icon/text proportion;
- motion polish;
- responsive adaptation;
- density and negative space;
- brand/legal correctness;
- render/apply truth alignment.

### PDS-19 - Scene Template Library

Goal: provide professional scene defaults instead of requiring AI to invent
scene structure.

Minimum templates:

- product_launch_4cards
- ai_features_cascade
- before_after_split
- testimonial_reveal
- stat_counter_grid
- hero_with_cta
- feature_list_horizontal
- timeline_journey
- countdown_with_action
- pricing_comparison
- team_introduction
- benefit_highlight
- tutorial_step_by_step
- promo_3card_horizontal
- voice_editor_demo
- video_editor_demo
- social_app_promo
- tech_brand_intro
- premium_app_promo
- saas_launch

Every template requires:

- Director Brief example;
- component graph;
- tokenized layout;
- motion plan;
- background pairing;
- good fixture;
- bad fixture;
- multi-aspect test.

### PDS-20 - Director Brief Compiler

Goal: compile intent to professional blueprint.

Input:

```text
intent
audience
mood
primaryFocus
rhythm
aspect
durationIntent
brandContext
visualStyle
elements
```

Compiler responsibilities:

- choose template;
- resolve components;
- resolve tokens;
- resolve composition;
- resolve motion recipes;
- resolve background motif;
- resolve brand/icon assets;
- produce Semantic Blueprint;
- produce SceneProgram through component-aware path.

Exit gate:

- a 15-30 line brief generates a complete professional scene;
- unsupported/contradictory briefs fail with repairable errors;
- no raw component child coordinates are generated.

### PDS-21 - Visual Closure Loop v2

Goal: turn failures into structured repairs.

Repair payload must include:

- error code;
- component id;
- slot id when relevant;
- frame/probe time;
- measured value;
- allowed value;
- suggested token/component/motion fix;
- visual description;
- attempt count.

Hard rule:

- max three repair attempts;
- after three failures, escalate to human review;
- never silently downgrade fatal visual defects to warnings.

### PDS-22 - Lovable Parity Acceptance Suite

Goal: prove ReFusion can generate professional scenes with the same default
quality users expect from modern AI web builders.

Parity dimensions:

- typography hierarchy;
- card sizing;
- icon/text ratio;
- spacing rhythm;
- visual balance;
- responsive adaptation;
- motion choreography;
- component state quality;
- absence of clipping/overlap;
- speed and determinism.

Acceptance:

- 10 blind reviewers choose ReFusion output at least 50% of the time against a
  comparable modern AI-built web/app layout adapted to motion;
- all objective scorecard checks pass;
- no scene reaches the user with a fatal component or design defect.

### PDS-23 - Closure QA, Build, Install, And Release Note

Goal: close the plan with proof.

Required:

- targeted tests for every service;
- regression fixtures;
- `flutter build apk --debug`;
- install on connected Android device when available;
- status report with commit hashes and rollback commands;
- no protected Live Scrub files touched unless explicitly approved.

## 8. Expected Fatal Error Catalog

The following must be errors, not warnings, for professional scenes:

- `MISSING_PARENT`
- `CYCLE_IN_PARENT_GRAPH`
- `CHILD_OUTLIVES_PARENT`
- `CHILD_VISIBLE_WHILE_PARENT_INVISIBLE`
- `TEXT_EXCEEDS_TEXT_SLOT`
- `TEXT_CLIPPED_WITHOUT_POLICY`
- `SENTENCE_CUT_MID_PHRASE`
- `ICON_EXCEEDS_SLOT`
- `ICON_OPTICAL_MISALIGNMENT`
- `BORDER_NOT_VISIBLE`
- `RAW_DESIGN_VALUE`
- `DUPLICATE_CHANNEL_OVERLAP`
- `MOTION_VARIETY_LOW`
- `RENDER_TRUTH_DRIFT`
- `LOWERER_METADATA_LOST`
- `LEGACY_LAYER_MIXED_WITH_ACTIVE_SCENE`
- `BRAND_ASSET_UNVERIFIED`
- `DIRECTOR_BRIEF_VAGUE`

## 9. Verification Matrix

Minimum verification by layer:

| Layer | Required verification |
|---|---|
| Runtime component | targeted Flutter unit tests |
| Text/layout | shared text layout tests and visual QA tests |
| Choreography | deterministic compile tests and conflict tests |
| Lowerer | source-map and time-basis tests |
| Evaluation | evaluated frame truth tests |
| QA gate | passing and failing fixtures |
| Apply | transaction and legacy-isolation tests |
| Design tokens | raw-value rejection and token resolution tests |
| Templates | multi-aspect fixture tests |
| Closure | build APK and install when device is connected |

## 10. Stop List

Do not:

- build new production demo scenes before component apply gates pass;
- patch professional scenes by manually nudging raw child layers;
- solve text fit by one-off font-size edits;
- solve borders by one-off stroke-width edits;
- let children keyframes outlive parent ranges;
- let Director output raw child coordinates inside known components;
- accept raw design values in professional blueprints;
- bundle unverified third-party brand logos;
- let visual defects pass as warnings;
- touch protected Stage5/Live Scrub paths unless explicitly approved;
- claim professional quality until runtime gates and design score gates pass.

## 11. Immediate Next Step

The next implementation step is:

```text
PDS-01 / PMCR-07 - PromptInputBar Runtime Component Proof
```

This is the correct first vertical proof because it touches the exact problems
the user saw:

- prompt bar position and size;
- visible border;
- text weight and slot fit;
- icon alignment;
- typewriter timing;
- shell/children lifecycle;
- group exit;
- apply without mixing old scenes.

After PDS-01 passes, continue PDS-02 and PDS-03, then the compiler/lowerer/
evaluation/gate sequence. Design System Authority implementation begins only
after the runtime can enforce component truth.
