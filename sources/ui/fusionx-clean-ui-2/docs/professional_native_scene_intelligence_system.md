# Professional Native Scene Intelligence System

Status: official implementation plan  
Package: `com.refusion.app`  
Branch: `codex/unified-keyframe-ops-foundation-20260426`  
Date opened: 2026-05-08  
Scope: agent-authored native scenes, DirectorPlan, SceneProgram, semantic components, layout intelligence, text fit, motion continuity, SpeedyGraph timing, visual frame QA, skills repository, preview/export parity

## Implementation Status Snapshot (2026-05-08)

- Completed: `NSI-01` through `NSI-12`.
- `NSI-10` updated and pushed `devmxai/refusion-skills` with Native Scene
  Intelligence, PromptInputBar, Closed Vocabulary, Beat Grammar, Visual Closure
  preparation, validation updates, and corrected Premium App Promo examples.
- `NSI-11` closed the app-side Premium App Promo fixture with an explicit
  PromptInputBar fixed-frame/text-fit hold assertion.
- `NSI-12` closure QA passed focused tests and debug APK build. Device install
  was attempted, but no wireless Android device was connected (`adb devices`
  empty; known wireless ports timed out).
- `NSI-v2-01` Design Token Registry is completed in this checkpoint with a
  deterministic token resolver, strict unknown-token errors, and
  `TF_SCENE_TOKEN_REGISTRY_PROOF`.
- Strategic extension accepted: `Closed Vocabulary + Visual Closure Loop` is
  the official v2 direction after `NSI-12`. Active work has started with
  `NSI-v2-01` complete; next is `NSI-v2-02`.

## 0. Purpose

This plan defines the professional scene intelligence system for ReFusion.

The goal is to make prompt/script-authored scenes reliable, editable, and visually professional:

```text
Prompt
-> Creative Direction
-> DirectorPlan
-> Semantic Component Blueprint
-> SceneProgram
-> Native Layout/Text/Motion Validators
-> MotionProject / Canonical Render Graph
-> Preview / Live Scrub / Playback / Export
```

The system must prevent scenes like the broken Premium App Promo prompt bar, where text overflows the input field, controls are placed by guessed coordinates, and motion is visually disconnected.

ReFusion is not HTML, CSS, React, GSAP, Remotion, or Open Design as a render surface. ReFusion output must remain native editable Shapes, Text, Image, Video, layers, channels, keyframes, SpeedyGraph timing, and official effects.

## 0.1 Why This Plan Exists

The current scene pipeline can accept structurally valid SceneProgram JSON while still allowing visually invalid composition.

Example failure:

```text
prompt-shell: width=860 height=118
prompt-text: x=-135 fontSize=38
send-button: x=355 width=76
```

This passes basic import because the JSON is valid, but it fails professionally because:

- the text is not parented to the input shell;
- the text has no text box;
- there is no max width;
- there is no padding;
- there is no trailing accessory slot;
- there is no clipping policy;
- there is no measured text-fit validation;
- typewriter text is remeasured as a changing substring instead of revealed inside a fixed text frame;
- the icon-to-prompt transition is two unrelated fade/scale animations, not a real morph or handoff.

This plan fixes the root cause: scene generation must become component-aware and contract-validated, not coordinate-guessing.

## 0.2 Strategic Refinement: Closed Vocabulary + Visual Closure Loop

The accepted long-term architecture is:

```text
Closed Vocabulary + Constraint-Solved Layout + Beat Grammar + Visual Closure Loop
```

This is not a replacement for the current plan. It is the professional direction
that the current plan prepares for.

The immediate plan (`NSI-01` through `NSI-12`) builds the first app-side safety
gates:

- component-aware prompt bars;
- text frames;
- geometry and text-fit checks;
- fixed-frame typewriter reveal;
- motion continuity checks;
- visual frame QA probes;
- skills repository rules.

The v2 plan then turns those gates into a full authoring compiler:

```text
Semantic Blueprint
-> Closed Vocabulary tokens
-> Component Registry
-> Constraint Layout Solver
-> Beat Grammar
-> Blueprint-to-SceneProgram Compiler
-> Visual Closure Loop
-> Approved native SceneProgram
```

### 0.2.1 Principle

Agents should not guess raw geometry, typography, timing, or motion.

They should choose from a controlled professional vocabulary:

```text
$component.PromptInputBar
$spacing.lg
$typography.input
$duration.medium
$easing.slowFastSlow
$motion.morphFromIcon
$beat.featureIntro
```

The app is still allowed to lower those references into concrete native values
such as pixels, milliseconds, colors, and keyframes. The rule is:

```text
Agent-facing semantic blueprints prefer tokens.
Lowered SceneProgram may contain resolved numeric execution values.
```

This distinction is mandatory. Requiring every lowered SceneProgram value to
remain a token would make runtime execution brittle and would block existing
valid scenes.

### 0.2.2 What Must Be Adopted

Adopt these parts of the recommendation:

- closed vocabulary for agent-facing scene authoring;
- design tokens for spacing, typography, color, radius, shadow, duration,
  easing, canvas anchors, components, beats, and motion recipes;
- component-first authoring before coordinates;
- constraint-solved layout for components such as prompt bars, cards, panels,
  controls, badges, and text blocks;
- beat-driven temporal grammar with `enter`, `hold`, and `exit` phases;
- structured validation errors that are readable by both humans and agents;
- visual QA probes that can grow into rendered thumbnail QA;
- a refinement loop where failed scenes produce machine-readable repair
  instructions.

### 0.2.3 What Must Not Be Adopted Literally

Do not make these strict rules in the current phase:

- do not forbid all raw numbers in the lowered `SceneProgram`;
- do not require 100 percent token coverage before the compiler exists;
- do not claim pixel-perfect preview/export hash equality as the first target;
- do not build 30 components before proving 6 to 10 core components;
- do not mix this scene intelligence work with Motion Tile, Motion Blur,
  Stage5 native shader work, or Live Scrub internals;
- do not delay `NSI-10` waiting for the full visual closure system.

The first quality bar is semantic parity and visible safety. Pixel-level parity
and full thumbnail-based self-repair are v2/v3 goals.

## 0.3 External Professional Patterns To Adopt

Use external systems as architecture references, not execution surfaces.

### Remotion

Borrow:

- composition metadata: width, height, fps, duration;
- exact frame/time evaluation;
- sequences/local time;
- deterministic preview/render semantics;
- reusable scene blocks.

Do not borrow:

- React;
- JSX;
- DOM;
- CSS;
- `useCurrentFrame`;
- `Sequence` syntax as output.

### Open Design

Borrow:

- skill packaging;
- typed inputs;
- schema-first generation;
- composer scripts;
- craft references;
- design-system thinking;
- self-check and QA loops.

Do not borrow:

- HTML artifacts;
- CSS;
- scroll interactions;
- web responsiveness as scene layout truth;
- iframe/browser preview as ReFusion output.

### Figma / Auto Layout

Borrow:

- padding;
- gap;
- alignment;
- fixed/hug/fill sizing;
- parent-child layout;
- content rects;
- safe area;
- component slots.

### Lottie / dotLottie

Borrow:

- strict portable schema;
- layer/property/time-based animation document;
- validation before playback;
- deterministic animation representation.

### Rive

Borrow:

- stateful components;
- animation graph discipline;
- explicit interpolation/easing;
- no random unowned motion.

## 1. Non-Negotiable Principles

### 1.1 Native ReFusion Is The Source Of Truth

Final scene output must be:

```json
{
  "directorPlan": {},
  "sceneProgram": {}
}
```

Forbidden final scene source:

```text
HTML
CSS
JS
JSX
React
GSAP
Remotion code
Open Design artifact
one baked MP4 as the source of truth
```

### 1.2 Skills Teach, App Contracts Enforce

The skills repository teaches any agent how to write professional scenes.

The app must still enforce correctness.

```text
refusion-skills
  -> reduces bad output

app-side compiler/validators
  -> reject or repair bad output
```

Skills alone are not a guarantee. The app must fail closed when a scene violates layout, text, timing, effect, or capability contracts.

### 1.3 Components Before Coordinates

Agents must not author professional UI scenes as loose elements:

```json
{ "text": "generate...", "position": { "x": -135, "y": -28 } }
```

They must author semantic components:

```json
{
  "component": "PromptInputBar",
  "id": "hero-prompt",
  "text": {
    "slot": "primaryText",
    "value": "generate new offer for my business"
  },
  "accessory": {
    "slot": "trailing",
    "kind": "sendButton"
  }
}
```

The compiler/layout engine then resolves exact native Shapes/Text/Icon elements.

### 1.4 Layout Is Executable Truth, Not Prose

DirectorPlan may say:

```text
text must be inside the input bar with safe padding
```

But SceneProgram must contain executable layout truth:

```json
{
  "parentId": "prompt-shell",
  "layout": {
    "slot": "primaryText",
    "anchor": "centerLeft",
    "maxWidth": "parent.contentWidth",
    "maxLines": 1,
    "overflow": "clip"
  }
}
```

If the layout truth is missing, the scene is incomplete.

### 1.5 Exact Time Everywhere

Every scene must be explainable as:

```text
scene clock
-> beats / markers
-> component lifetimes
-> property tracks
-> SpeedyGraph keyframes
-> holds / handoffs / completion
```

No private clocks, ad-hoc progress, or wall-clock animation.

### 1.6 SpeedyGraph Owns Professional Motion

Any professional movement must compile through the official SpeedyGraph truth:

```text
Preset / velocity / graph handle / AI easing
-> MotionInterpolationTruthCompiler
-> Bezier execution truth
-> MasterKeyframeValueEvaluator
```

Silent linear fallback is forbidden.

### 1.7 Preview And Export Must Share Semantics

Preview may use lower visual quality, but it must not change:

- layout;
- text fit;
- timing;
- easing;
- transform order;
- effect order;
- source bindings;
- frame ownership.

### 1.8 Seeded Randomness Only

Random design variation is allowed only with explicit seed:

```json
{ "randomSeed": "revival-promo-001" }
```

Unseeded random layout, color, timing, or stagger is forbidden.

## 2. Current Baseline

Already present:

- `ReFusionSceneProgram` data model;
- `DirectorPlan` / motion director models;
- SceneProgram import service;
- SceneProgram lowerer;
- timing validation;
- basic layout parent validation;
- refusion native motion scene skill;
- refusion-skills external repo;
- SpeedyGraph truth compiler;
- official effects planning and renderer boundaries.

Known gaps:

- no typed component registry;
- no component props/slots compiler;
- no parent content rect solver;
- no text frame contract;
- no text fit validation;
- no typewriter fixed-frame reveal;
- no visual bounds validator;
- no component-specific QA;
- no DirectorPlan layout requirement enforcement;
- no automatic frame-probe QA;
- no strict guarantee that external agents cannot output visually broken scenes.

## 3. Target Architecture

```text
User Prompt
  |
  v
Creative Director Brief
  |
  v
DirectorPlan
  |
  v
Semantic Component Blueprint
  |
  v
Native Scene Composer
  |
  v
SceneProgram v1/v2
  |
  +--> Schema Validator
  +--> Director Alignment Validator
  +--> Component Contract Validator
  +--> Layout Geometry Solver
  +--> Text Fit Validator
  +--> Motion Continuity Validator
  +--> SpeedyGraph Validator
  +--> Effects Capability Validator
  +--> Visual Frame QA Probe
  |
  v
MotionProject / Master Frame Evaluation
  |
  v
Preview / Live Scrub / Playback / Export
```

## 4. Official Subsystems

### 4.1 Semantic Component Registry

Add a central registry of professional native scene components.

Each component must declare:

- component id;
- role;
- supported canvas modes;
- required props;
- optional props;
- slots;
- default dimensions;
- min/max dimensions;
- text policies;
- motion policies;
- effect policies;
- QA probes;
- preview/export support;
- lowering strategy.

Initial components:

```text
PromptInputBar
AppIconIntro
FeatureCard
ResultCard
DashboardPanel
TimelineStrip
AudioWaveform
ColorGradePanel
MotionTextBlock
CTAButton
HeroLogoLockup
GeneratedPreviewPanel
MediaEditPanel
ComparisonSplit
```

### 4.2 Component Blueprint

The agent may write a component blueprint inside DirectorPlan or as an intermediate payload:

```json
{
  "id": "hero-prompt",
  "component": "PromptInputBar",
  "role": "hero.prompt",
  "position": { "x": 0, "y": -40 },
  "width": 900,
  "height": 118,
  "padding": { "left": 48, "right": 24, "top": 18, "bottom": 18 },
  "text": {
    "slot": "primaryText",
    "value": "generate new offer for my business",
    "maxLines": 1,
    "fit": "shrinkToFit",
    "clipToParent": true
  },
  "accessory": {
    "slot": "trailing",
    "kind": "sendButton",
    "size": 76,
    "gap": 24
  }
}
```

The Native Scene Composer resolves this into executable SceneProgram elements.

### 4.3 Layout Constraint Contract

SceneProgram elements must support layout metadata with real enforcement:

```json
{
  "parentId": "prompt-shell",
  "layoutRole": "content",
  "layout": {
    "coordinateSpace": "parent",
    "slot": "primaryText",
    "anchor": "centerLeft",
    "x": "parent.contentLeft",
    "y": "parent.centerY",
    "maxWidth": "parent.contentWidth - trailingSlot.width - gap",
    "maxHeight": "parent.contentHeight",
    "maxLines": 1,
    "overflow": "error",
    "clipToParent": true
  }
}
```

Supported sizing modes:

```text
fixed
hug
fill
fitContent
shrinkToFit
```

Supported alignment:

```text
topLeft
topCenter
topRight
centerLeft
center
centerRight
bottomLeft
bottomCenter
bottomRight
```

Supported layout policies:

```text
absolute
stackHorizontal
stackVertical
overlay
slotBased
```

### 4.4 Text Frame Contract

Every professional text element must declare one of:

- explicit text frame;
- parent slot;
- approved canvas-safe standalone role.

Text frame fields:

```json
{
  "textFrame": {
    "width": 640,
    "height": 72,
    "anchor": "centerLeft",
    "maxLines": 1,
    "overflow": "error",
    "clip": true,
    "verticalAlign": "center",
    "fitPolicy": "shrinkToFit",
    "minFontSize": 24,
    "maxFontSize": 38,
    "measure": "fullText"
  }
}
```

Forbidden:

```text
important UI text with only position + fontSize
```

### 4.5 Typewriter Fixed-Frame Contract

Typewriter must not remeasure shrinking/growing substrings as the layout truth.

Required behavior:

```text
measure full final text
resolve stable text frame
render/reveal visible portion inside that frame
clip/mask reveal to text frame
do not shift text origin as characters appear
```

Diagnostic:

```text
TF_SCENE_TEXT_REVEAL_FRAME_PROOF
```

Required fields:

- elementId;
- fullTextWidth;
- visibleTextWidth;
- frameWidth;
- originStable;
- revealProgress;
- overflowPolicy;
- fallbackReason.

### 4.6 Motion Continuity Contract

Any beat that claims `morph`, `transform`, `expand`, `collapse`, or `becomes` must prove continuity.

Required:

- source component;
- target component;
- shared anchor or explicit anchor path;
- timing handoff;
- property ownership;
- no unrelated fade unless declared as dissolve;
- readable resolve hold.

Example:

```text
app icon -> prompt input
```

must compile as one of:

- shell geometry morph;
- parent transform handoff;
- masked reveal through the icon;
- intentional dissolve with declared reason.

It must not silently become:

```text
icon opacity 1 -> 0
prompt opacity 0 -> 1
```

without continuity proof.

Diagnostic:

```text
TF_SCENE_MOTION_CONTINUITY_PROOF
```

### 4.7 Visual Frame QA Contract

Before accepting/importing agent-authored scenes, sample risk frames:

```text
scene first frame
scene final frame
each beat start
each beat midpoint
each beat end
each text reveal completion
each readable hold midpoint
each morph handoff midpoint
each transition boundary
```

For each probe, compute or render-check:

- text inside frame;
- child inside parent;
- no collision with accessory slot;
- safe area respected;
- readable contrast;
- opacity/scale not accidentally invisible;
- no unfinished motion at scene end;
- no unsupported effect visible as if supported.

Diagnostic:

```text
TF_SCENE_VISUAL_FRAME_QA_PROOF
```

## 5. App-Side Validators

### 5.1 Schema Validator

Required:

- root wrapper validation;
- scene schema version;
- director schema version;
- layer kind whitelist;
- element kind whitelist;
- property whitelist;
- channel/keyframe structure;
- forbidden executable keys.

### 5.2 Director Alignment Validator

Required:

- every beat references existing components;
- every primitive references existing beat and component;
- every primitive maps to a real SceneProgram layer/element/channel;
- every semantic component has a scene representation;
- DirectorPlan prose cannot be the only place where layout constraints exist.

### 5.3 Component Contract Validator

Required:

- known component type;
- required props present;
- slots declared;
- child slot ownership;
- no loose child coordinates for structured components;
- component-specific QA rules.

### 5.4 Layout Geometry Validator

Required:

- derive parent bounds;
- derive content rect;
- derive slot rects;
- transform child rect into parent/root coordinate space;
- verify child AABB inside allowed rect;
- verify no overlap between text and accessory controls;
- respect safe area;
- include tolerance no greater than 1 px unless documented.

Diagnostic:

```text
TF_SCENE_LAYOUT_GEOMETRY_PROOF
```

Fields:

- componentId;
- elementId;
- parentId;
- parentRect;
- contentRect;
- childMeasuredRect;
- insideParent;
- overlapsAccessory;
- tolerancePx;
- fallbackReason.

### 5.5 Text Fit Validator

Required:

- measure full text, not current reveal substring;
- include fontSize;
- include fontWeight;
- include fontFamily;
- include lineHeight;
- include letterSpacing;
- include scale;
- include textFrame width/height;
- reject or shrink according to policy;
- no silent overflow.

Diagnostic:

```text
TF_SCENE_TEXT_FIT_PROOF
```

Fields:

- elementId;
- textLength;
- fullTextWidth;
- frameWidth;
- fontSizeBefore;
- fontSizeAfter;
- fitPolicy;
- maxLines;
- overflow;
- accepted;
- fallbackReason.

### 5.6 Timing And Hold Validator

Continue using the professional timing contract, strengthened with:

- required readable hold for important text;
- typewriter must finish before hold;
- no last-keyframe-on-scene-boundary for important visible components;
- no same target/property overlap;
- no accidental component disappearance due to layer end.

### 5.7 SpeedyGraph Validator

Required:

- no professional motion with unsupported easing string;
- all cinematic/easy/professional movement compiles through `MotionInterpolationTruthCompiler`;
- curveHash exists for custom curves;
- no silent linear fallback.

### 5.8 Effects Capability Validator

Required:

- official effect id only;
- renderer path known;
- preview/playback/export support known;
- unsupported effects blocked explicitly;
- effect order documented.

### 5.9 Visual QA Reporter

Provide a structured report that can be shown to the agent and the app:

```json
{
  "accepted": false,
  "issues": [
    {
      "code": "text_overflows_parent",
      "elementId": "prompt-text",
      "parentId": "prompt-shell",
      "frameMs": 4449,
      "message": "Prompt text exceeds parent content rect by 31px."
    }
  ]
}
```

## 6. Skills Repository Requirements

Repository:

```text
https://github.com/devmxai/refusion-skills
```

The skills repo must become the external-agent source of truth.

### 6.1 Required Skill Files

Add/update:

```text
skills/refusion-skills/rules/native-scene-intelligence.md
skills/refusion-skills/rules/semantic-components.md
skills/refusion-skills/rules/layout-bounds-contract.md
skills/refusion-skills/rules/text-fit-contract.md
skills/refusion-skills/rules/typewriter-fixed-frame.md
skills/refusion-skills/rules/motion-continuity-contract.md
skills/refusion-skills/rules/visual-frame-qa.md
skills/refusion-skills/rules/prompt-input-bar-component.md
skills/refusion-skills/examples/premium-app-promo-component-safe.json
```

Update:

```text
skills/refusion-skills/SKILL.md
skills/refusion-skills/rules/validation.md
skills/refusion-skills/rules/scene-program-json.md
skills/refusion-skills/rules/open-design-adaptation.md
skills/refusion-skills/rules/remotion-principles-for-refusion.md
skills/refusion-skills/rules/professional-timing-contract.md
REFUSION_SCENE_SKILL_FULL.md
```

### 6.2 Agent Rules To Add

Every external agent must follow:

- build hero frame first;
- use semantic components;
- never place important text by position alone;
- every UI-like component must have parent/slot/padding/textFrame;
- every typewriter has fixed full-text frame;
- every motion handoff has continuity proof;
- every scene must list QA frames;
- every generated JSON must be complete and paste-safe;
- long 50-60s scenes must be compact or delivered as a file artifact.

### 6.3 Open Design Adaptation Rule

Borrow:

- typed input schemas;
- fixed-arity sections;
- craft references;
- design tokens;
- QA rubrics;
- composer pipeline.

Exclude:

- HTML;
- CSS;
- DOM layout;
- React;
- scroll web sections;
- iframe preview;
- external scripts.

### 6.4 Remotion Adaptation Rule

Borrow:

- composition metadata;
- frame/time determinism;
- sequences/local time;
- reusable blocks;
- preview/export semantic parity.

Exclude:

- React runtime;
- JSX output;
- `useCurrentFrame`;
- `Sequence` syntax;
- browser rendering as truth.

## 7. Implementation Phases

Each phase must be a separate checkpoint. Stage only focused files. Push after each checkpoint. Install on connected Android device when the phase changes app behavior.

### NSI-01 - Plan And Baseline Audit

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence 01 - plan and baseline audit
```

Required:

- add this plan;
- inspect current SceneProgram import/lowerer/validators;
- document Premium App Promo failure as regression fixture;
- add no behavior changes yet.

Verification:

- docs inspected;
- `rg` confirms plan references.

### NSI-02 - Scene Layout Contract Model

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence 02 - layout contract model
```

Required:

- add domain models for:
  - layout bounds;
  - parent/child layout relation;
  - content insets;
  - slot rect;
  - text frame;
  - text fit policy;
  - overflow policy;
  - anchor;
  - coordinate space.
- preserve backward compatibility for existing SceneProgram JSON.

Tests:

- parse layout metadata;
- normalize aliases;
- reject invalid sizing/anchor values;
- serialize/deserialize contract models.

### NSI-03 - Semantic Component Registry

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence 03 - semantic component registry
```

Required:

- add `SceneSemanticComponentRegistry`;
- add `PromptInputBar` v1;
- add component props/slots/defaults;
- add registry lookup and validation;
- do not change renderer yet.

Tests:

- PromptInputBar has shell, primaryText, trailingAccessory slots;
- required props enforced;
- default safe geometry computed.

### NSI-04 - Native Scene Composer

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence 04 - native scene composer
```

Required:

- compile component blueprints into SceneProgram elements;
- generate shell/text/button/icon elements with parent/slot metadata;
- output stable IDs;
- support PromptInputBar first;
- keep output editable.

Tests:

- blueprint -> SceneProgram;
- PromptInputBar text has parentId/textFrame;
- send button has accessory slot;
- no loose prompt text.

### NSI-05 - Layout Geometry Validator

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence 05 - layout geometry validator
```

Required:

- compute parent rects;
- compute content rects;
- compute slot rects;
- compute child rects;
- detect child outside parent;
- detect text/accessory overlap;
- emit `TF_SCENE_LAYOUT_GEOMETRY_PROOF`.

Tests:

- broken Premium App Promo prompt text is rejected;
- corrected PromptInputBar is accepted;
- accessory overlap is rejected;
- 1 px tolerance is enforced.

### NSI-06 - Text Fit Validator

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence 06 - text fit validator
```

Required:

- measure full text;
- validate max width/height;
- support fit policies:
  - reject;
  - shrinkToFit;
  - ellipsis when supported;
  - clip when explicitly allowed.
- emit `TF_SCENE_TEXT_FIT_PROOF`.

Tests:

- long text rejected when policy is reject;
- shrinkToFit reduces fontSize within min/max;
- important prompt text cannot overflow shell;
- typewriter full text measured, not substring.

### NSI-07 - Typewriter Fixed-Frame Reveal

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence 07 - typewriter fixed frame reveal
```

Required:

- update preview text path so typewriter keeps stable origin/frame;
- reveal visible substring inside full-text frame;
- no layout drift during typing;
- emit `TF_SCENE_TEXT_REVEAL_FRAME_PROOF`.

Tests:

- origin stable at reveal progress 0, 0.5, 1;
- full text frame remains constant;
- visible text does not move outside textFrame.

Protected boundary:

- Do not touch Stage5 or Live Scrub native files.

### NSI-08 - Motion Continuity Validator

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence 08 - motion continuity validator
```

Required:

- inspect DirectorPlan beats claiming morph/transform/handoff;
- verify source/target components and property ownership;
- reject unrelated fade/scale masquerading as morph;
- emit `TF_SCENE_MOTION_CONTINUITY_PROOF`.

Tests:

- icon-to-prompt crossfade without morph proof is rejected/warned;
- explicit dissolve accepted only when declared;
- geometry morph channel accepted.

### NSI-09 - Visual Frame QA Probes

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence 09 - visual frame qa probes
```

Required:

- generate QA probe times from beats/keyframes/text reveals;
- run layout/text/motion checks at those times;
- produce structured QA report;
- emit `TF_SCENE_VISUAL_FRAME_QA_PROOF`.

Tests:

- probe list includes beat midpoints and readable holds;
- prompt text overflow detected at hold frame;
- scene final frame checks completion hold.

### NSI-10 - Skills Repository Upgrade

Status: completed and pushed to `devmxai/refusion-skills` as commit `ebb1de7`.

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence 10 - refusion skills scene intelligence
```

Required:

- update `/Users/mx/Documents/refusion-skills`;
- add native scene intelligence rules;
- add PromptInputBar component rules;
- add Closed Vocabulary rules for agent-facing authoring:
  - components must be chosen from named component recipes;
  - important spacing, typography, timing, easing, and motion should use
    vocabulary names/tokens when authoring semantic blueprints;
  - lowered SceneProgram JSON may contain resolved native values after compile.
- add Beat Grammar rules:
  - every important animation belongs to a named beat;
  - each beat should have `enter`, `hold`, and `exit` intent;
  - professional motion should use SpeedyGraph easing names rather than silent
    linear fallback.
- add Visual Closure Loop preparation rules:
  - agents must self-check generated scenes against layout, text fit, timing,
    contrast, and continuity before final output;
  - skills examples must include QA notes and common repair actions.
- update validation rules;
- add corrected Premium App Promo example;
- rebuild `REFUSION_SCENE_SKILL_FULL.md`;
- push `devmxai/refusion-skills`.

Verification:

- rule files exist;
- full bundle includes new rules;
- example validates with repository validator.
- full bundle contains `Closed Vocabulary`, `PromptInputBar`, `Beat Grammar`,
  `Visual Closure`, and `SpeedyGraph` guidance.

### NSI-11 - Premium App Promo Rewrite

Status: completed as commit `96eb1015`.

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence 11 - premium promo component-safe scene
```

Required:

- rewrite Premium App Promo preset using component-safe PromptInputBar;
- use stable text frame;
- use real icon-to-prompt continuity;
- use SpeedyGraph curves;
- document which parts are v1 resolved SceneProgram values and which parts
  would become v2 semantic blueprint tokens later;
- add visual QA fixture test.

Tests:

- preset imports;
- broken old geometry fails validator;
- new geometry passes validator;
- current frame around prompt hold has contained text.
- prompt beat timing has a readable enter/hold/exit rhythm.

Build:

```bash
flutter build apk --debug
```

Install connected Android device when available.

### NSI-12 - Closure QA

Status: completed in this checkpoint.

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence 12 - closure qa
```

Required:

- run final focused tests;
- build debug APK;
- install on wireless device;
- update this plan with completed phases;
- explicitly mark the v2 `Closed Vocabulary + Visual Closure Loop` work as the
  next official plan, not an untracked idea;
- report remaining risks.

Required focused tests:

```text
flutter test test/scene_program_layout_contract_test.dart
flutter test test/refusion_scene_program_lowerer_test.dart
flutter test test/refusion_scene_program_import_service_test.dart
flutter test test/premium_app_promo_scene_program_preset_test.dart
flutter test test/professional_scene_timing_contract_test.dart
flutter test test/universal_motion_engine_guard_test.dart
```

Add new tests as created:

```text
scene_program_component_contract_test.dart
scene_typewriter_fixed_frame_test.dart
scene_motion_continuity_validator_test.dart
scene_visual_frame_qa_validator_test.dart
```

Closure verification run:

```text
flutter test test/scene_program_layout_contract_test.dart
flutter test test/refusion_scene_program_lowerer_test.dart
flutter test test/refusion_scene_program_import_service_test.dart
flutter test test/premium_app_promo_scene_program_preset_test.dart
flutter test test/professional_scene_timing_contract_test.dart
flutter test test/universal_motion_engine_guard_test.dart
flutter test test/scene_typewriter_fixed_frame_test.dart
flutter test test/scene_motion_continuity_validator_test.dart
flutter test test/scene_visual_frame_qa_validator_test.dart
flutter test test/scene_program_component_contract_test.dart
flutter build apk --debug
```

Install status:

```text
Not installed during NSI-12 because no Android device was connected.
adb devices returned an empty list.
adb connect 192.168.0.149:39047 timed out.
adb connect 192.168.0.149:34775 timed out.
```

## 7.1 Professional Native Scene Intelligence v2

The following phases are the official continuation after `NSI-12`. They should
not be mixed into the v1 closure checkpoints unless a specific item is required
to close a bug.

### NSI-v2-01 - Design Token Registry

Status: completed in this checkpoint.

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 01 - design token registry
```

Required:

- add token registry models for:
  - spacing;
  - typography;
  - colors;
  - radius;
  - shadows;
  - duration;
  - easing;
  - canvas anchors;
  - motion recipes;
  - beat presets.
- add resolver from `$token.path` to native values;
- support project/theme overrides later without changing the SceneProgram
  runtime format;
- forbid unknown token names in semantic blueprints.

Acceptance:

- semantic blueprint tokens resolve deterministically;
- invalid token references fail with structured errors;
- lowered SceneProgram receives concrete values.

### NSI-v2-02 - Semantic Scene Blueprint Schema

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 02 - semantic blueprint schema
```

Required:

- add a `SemanticSceneBlueprint` schema above SceneProgram;
- support component declarations, slots, tokens, beats, and motion intents;
- keep SceneProgram as the editable native execution output;
- add import/compile diagnostics for unsupported blueprint fields.

Acceptance:

- agents can author components without raw coordinates;
- compiler can lower a simple PromptInputBar blueprint to valid SceneProgram;
- existing SceneProgram import remains backward compatible.

### NSI-v2-03 - Component Registry v2

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 03 - component registry v2
```

Required:

- add first stable component recipes:
  - `PromptInputBar`;
  - `FeatureCard`;
  - `AppIconIntro`;
  - `ResultCard`;
  - `MotionTextBlock`;
  - `IconButton`;
  - `DashboardPanel`;
  - `TimelineStrip`;
  - `AudioWaveform`;
  - `ColorGradePanel`.
- define required slots, allowed children, sizing modes, and defaults;
- emit `TF_SCENE_COMPONENT_REGISTRY_PROOF`.

Acceptance:

- unsupported component names fail closed;
- required slots are enforced;
- each recipe can lower into editable native shapes/text/icons.

### NSI-v2-04 - Constraint Layout Solver

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 04 - constraint layout solver
```

Required:

- implement native layout primitives:
  - horizontal stack;
  - vertical stack;
  - fixed;
  - hug content;
  - fill container;
  - padding;
  - gap;
  - alignment;
  - safe area;
  - slots.
- solve layout to deterministic bounds;
- emit structured overlap/out-of-bounds errors;
- emit `TF_SCENE_NATIVE_COMPOSER_PROOF` when lowering succeeds.

Acceptance:

- prompt text cannot overlap send button;
- children cannot escape parent content rect;
- layouts adapt to 9:16, 16:9, 1:1, and 4:5 canvas formats.

### NSI-v2-05 - Beat Grammar Engine

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 05 - beat grammar engine
```

Required:

- define beat models with `enter`, `hold`, and `exit` phases;
- enforce readable hold durations for important text;
- cap excessive overlaps;
- require SpeedyGraph timing for professional movement;
- add repair diagnostics for motion without a beat.

Acceptance:

- important motion is attached to a beat;
- typewriter and feature reveal scenes contain readable holds;
- icon-to-prompt handoff is represented as one beat, not unrelated fades.

### NSI-v2-06 - Blueprint To SceneProgram Compiler

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 06 - blueprint compiler
```

Required:

- compile semantic blueprints into SceneProgram;
- preserve stable IDs and editability;
- lower tokens, components, slots, beats, and motion recipes;
- preserve source metadata for inspector/debugging.

Acceptance:

- blueprint output imports through the existing authoring pipeline;
- generated SceneProgram passes v1 validators;
- no HTML/CSS/JS/React output is introduced.

### NSI-v2-07 - Visual QA Thumbnail Renderer MVP

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 07 - visual qa thumbnail mvp
```

Required:

- produce low-resolution QA probes at first:
  - start;
  - important beat midpoint;
  - final hold.
- later expand to 9 canonical probes;
- collect text bounds, element bounds, canvas bounds, contrast estimates, and
  motion continuity summaries.

Acceptance:

- obvious text overflow is detected visually;
- clipped elements are reported with frame time;
- probe generation does not require user inspection.

### NSI-v2-08 - Structured Repair Feedback Loop

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 08 - structured repair feedback loop
```

Required:

- convert validator/probe failures into machine-readable repair payloads;
- include:
  - error code;
  - component id;
  - frame time;
  - violated rect/value;
  - suggested action;
  - suggested token/component replacement when possible.
- support up to three agent repair attempts in future orchestration;
- do not auto-retry inside the mobile app until orchestration is explicitly
  designed.

Acceptance:

- bad scenes return actionable structured errors;
- skills can teach agents how to repair those errors;
- the system fails closed if repair cannot produce a valid scene.

### NSI-v2-09 - Skills And Exemplar Expansion

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 09 - skills and exemplar expansion
```

Required:

- update `refusion-skills` with v2 blueprint authoring rules;
- add good/bad examples for:
  - prompt input;
  - feature cards;
  - dashboards;
  - app promo scenes;
  - text-heavy scenes;
  - color/effect scenes.
- add an exemplar QA checklist.

Acceptance:

- external agents can author blueprints using components/tokens/beats;
- examples compile and validate;
- common mistakes are represented with repair guidance.

### NSI-v2-10 - Closure QA

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 10 - closure qa
```

Required:

- run focused tests for token registry, blueprint compiler, components,
  layout solver, beat grammar, visual QA, and repair feedback;
- build APK if app behavior changed;
- install on connected Android device when available;
- update this plan with final status.

Acceptance:

- v1 SceneProgram path remains compatible;
- v2 semantic blueprint path produces valid native SceneProgram;
- no decorative graph/layout path exists;
- unsupported component, token, beat, or motion request fails with a clear
  reason.

## 8. Diagnostics Summary

Required final diagnostics:

```text
TF_SCENE_LAYOUT_GEOMETRY_PROOF
TF_SCENE_TEXT_FIT_PROOF
TF_SCENE_TEXT_REVEAL_FRAME_PROOF
TF_SCENE_MOTION_CONTINUITY_PROOF
TF_SCENE_VISUAL_FRAME_QA_PROOF
TF_SCENE_COMPONENT_REGISTRY_PROOF
TF_SCENE_NATIVE_COMPOSER_PROOF
TF_SCENE_TOKEN_REGISTRY_PROOF
TF_SCENE_BLUEPRINT_COMPILER_PROOF
TF_SCENE_BEAT_GRAMMAR_PROOF
TF_SCENE_VISUAL_REPAIR_PROOF
```

## 9. Stop List

Do not:

- solve this only by manually resizing one prompt text;
- rely only on agent instructions;
- accept UI text without a text frame;
- allow prompt/input/card children without parent/slot metadata;
- allow typewriter to shift origin while typing;
- claim morph when elements only crossfade;
- let agents guess prompt bars, cards, panels, or important text blocks from
  loose coordinates when a component contract exists;
- introduce semantic blueprint tokens without a deterministic resolver;
- mix spatial path editing, clip speed ramp, Motion Tile, Motion Blur, or
  Stage5 shader changes into Scene Intelligence checkpoints;
- claim Visual Closure Loop is complete before rendered probes and structured
  repair payloads exist;
- add HTML/CSS/JS/React/Remotion output;
- bypass SpeedyGraph for professional motion;
- silently downgrade unsupported effects;
- touch protected Stage5/Live Scrub native files without explicit approval;
- commit unrelated diagnostics/screenshots/seam files.

## 10. Final Acceptance

The system is complete only when:

- any external agent can read `refusion-skills` and produce component-aware ReFusion JSON;
- the app rejects visually unsafe prompt bars/cards/text blocks;
- important text cannot overflow its container;
- typewriter reveal is stable inside a fixed text frame;
- PromptInputBar uses shell/content/accessory slots;
- icon-to-prompt transitions require continuity proof;
- visual QA probes catch bad frames before user inspection;
- SpeedyGraph remains the timing truth;
- preview/playback/export share the same scene semantics;
- Premium App Promo imports and looks professional without hand-tuned guesswork;
- all focused tests pass;
- debug APK builds and installs.

The v2 extension is complete only when:

- agents can author semantic blueprints using closed vocabulary tokens;
- tokens resolve into deterministic native SceneProgram values;
- component layouts are solved by constraints rather than guessed coordinates;
- beats own important timing and readable holds;
- visual QA can produce thumbnail/probe evidence;
- failed visual QA returns structured repair instructions;
- the old direct SceneProgram path remains valid for backward compatibility.

## 11. Agent Writer Instruction (v2 Active Track)

When implementing this plan:

1. Read:
   - `docs/professional_checkpoint_policy.md`
   - this plan
   - `docs/professional_speed_graph_system.md`
   - `docs/professional_agent_scene_program_engine.md`
   - `docs/refusion_scene_program_agent_authoring_guide.md`
2. Run `git status -sb`.
3. Identify unrelated dirty files and leave them alone.
4. Implement one NSI phase only.
5. Add focused tests for that phase.
6. Run the smallest relevant tests.
7. Build/install only when behavior changes.
8. Commit with the exact checkpoint name for that phase.
9. Push the branch.
10. Report files, tests, build/install result, risks, and rollback command.

v1 closure status:

- `NSI-01` through `NSI-12` are complete and closed.
- Do not reopen v1 checkpoints unless a specific regression requires it.

Immediate active order (v2 only):

1. `NSI-v2-01` Design Token Registry
   status: completed
2. `NSI-v2-02` Semantic Scene Blueprint Schema
3. `NSI-v2-03` Component Registry v2
4. `NSI-v2-04` Constraint Layout Solver
5. `NSI-v2-05` Beat Grammar Engine
6. `NSI-v2-06` Blueprint To SceneProgram Compiler
7. `NSI-v2-07` Visual QA Thumbnail Renderer MVP
8. `NSI-v2-08` Structured Repair Feedback Loop
9. `NSI-v2-09` Skills And Exemplar Expansion
10. `NSI-v2-10` Closure QA

Phase gating rules:

- implement exactly one phase per checkpoint;
- run focused tests for that phase only, then broaden in `NSI-v2-10`;
- stage only related files;
- do not mix FX/timeline/native Stage5 work into NSI-v2 checkpoints;
- if a phase depends on a missing contract, add the contract first and stop.

Compatibility rule for all v2 phases:

- direct SceneProgram import remains supported;
- semantic blueprint is additive;
- tokens compile to concrete native values;
- unsupported tokens/components/beats fail with explicit reasons.

Quality rule for all v2 phases:

- no HTML/CSS/JS/React/Remotion output;
- no UI-only quality claims;
- no Visual Closure completion claims before probe evidence plus repair payloads
  exist.

Rollback format:

```bash
git -C /Users/mx/Documents/ReFusionXx revert <commit-hash>
```
