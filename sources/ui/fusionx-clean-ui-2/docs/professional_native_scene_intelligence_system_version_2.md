# Professional Native Scene Intelligence System - VERSION 2

Status: official VERSION 2 execution plan  
Package: `com.refusion.app`  
Branch: `codex/unified-keyframe-ops-foundation-20260426`  
Date opened: 2026-05-08  
Primary plan predecessor: `professional_native_scene_intelligence_system.md`  
Scope: semantic scene blueprints, closed vocabulary, component contracts, text geometry, constraint layout, beat grammar, SpeedyGraph timing, deterministic compilation, visual QA, structured repair, skills/exemplars

## 1. Executive Decision

VERSION 2 is the professional continuation of the Native Scene Intelligence system.

The goal is not to patch one SaaS promo scene. The goal is to make bad scenes structurally impossible:

- no loose text floating over rectangles;
- no text larger than its input, card, button, or panel;
- no unsupported icons or invented component names;
- no random coordinates when a component contract exists;
- no cinematic motion without SpeedyGraph truth;
- no visual QA claim without measured or rendered proof;
- no scene accepted merely because JSON is syntactically valid.

The correct architecture is:

```text
Agent Prompt
-> Semantic Scene Blueprint
-> Closed Vocabulary Tokens
-> Component Registry
-> Constraint Layout Solver
-> Beat Grammar + SpeedyGraph Motion Rules
-> Deterministic Blueprint Compiler
-> Native SceneProgram
-> Geometry/Text/Motion/Visual QA
-> Approved editable ReFusion scene
```

ReFusion remains a native motion graphics application. VERSION 2 must not turn the app into HTML, CSS, React, Remotion, GSAP, or a browser-rendered authoring system.

## 2. Current Confirmed State

### 2.1 Completed Before VERSION 2

- `NSI-01` through `NSI-12` are completed and closed.
- `refusion-skills` has been updated for Native Scene Intelligence v1.
- Premium App Promo v1 fixture exists.
- SceneProgram import, timing, component, typewriter, motion continuity, and visual QA gates exist in initial form.

### 2.2 Completed In Active v2 Track

- `NSI-v2-00` SpeedyGraph Foundation Dependency Gate is completed.
  - Semantic motion intent easing now routes through
    `MotionInterpolationTruthCompiler`.
  - Direct bezier literals in semantic motion intents are rejected as bypass.
  - `TF_SCENE_SPEEDYGRAPH_DEPENDENCY_PROOF` exists in lowering diagnostics.

- `NSI-v2-01` Design Token Registry is completed.
  - Token resolver exists.
  - Strict unknown-token errors exist.
  - `TF_SCENE_TOKEN_REGISTRY_PROOF` exists.

- `NSI-v2-02` Semantic Scene Blueprint Schema is completed.
  - Semantic blueprint model exists.
  - Unsupported-field validation exists.
  - Initial PromptInputBar lowering exists.
  - `TF_SCENE_BLUEPRINT_COMPILER_PROOF` exists.

- `NSI-v2-03A` Component Registry v2 + Variants is completed.
  - Closed component vocabulary now validates component type aliases,
    required slots, optional slots, and unsupported slot rejection.
  - Variant contracts now fail closed for unsupported variants.
  - Semantic blueprint validation now emits
    `TF_SCENE_COMPONENT_REGISTRY_PROOF`.

- `NSI-v2-03B` Generic Text Geometry + Multi-Policy Text Fit is completed.
  - Semantic blueprint validation now enforces bounded text contracts with
    finite `textFrame` dimensions, `maxLines`, `overflowPolicy`, and
    `fitPolicy`.
  - Unsupported `fitPolicy`/`overflowPolicy` now fail closed.
  - PromptInputBar fallback text-frame defaults remain deterministic.
  - Visual frame QA now checks bounded static text and reveal text, not reveal
    text only.
  - Semantic diagnostics now emit `TF_SCENE_TEXT_GEOMETRY_PROOF`.

### 2.3 SpeedyGraph Foundation Status

SpeedyGraph foundation is already implemented as a separate system and must not be rebuilt inside NSI:

- `MotionBezierVelocityBridge` exists.
- `MotionInterpolationTruthCompiler` exists.
- SpeedGraph tests exist for bridge and truth compiler.
- NSI must depend on this path and must not introduce a second easing or velocity system.

Therefore VERSION 2 uses `NSI-v2-00` as a dependency verification gate, not a rebuild phase.

## 3. Failure That VERSION 2 Must Eliminate

The recent SaaS Launch scene exposed the key remaining gap.

The scene passed import because it was valid JSON, but it rendered badly because:

- cards and text were unrelated siblings;
- card children had no universal `parentId`, `slotId`, `layoutRole`, or `contentInsets`;
- feedback text had `textFrame` metadata, but not every render path honored it as a finite layout width;
- static bounded text was not checked as strictly as typewriter/reveal text;
- component validation was too specific to PromptInputBar;
- the scene used coordinate-authored rectangles and loose text instead of component-authored cards;
- no generic visual QA blocked visible text overflow before user inspection.

VERSION 2 must make this class of failure impossible for every component, not only for SaaS cards.

## 4. Non-Negotiable Rules

1. Native output only.
   - Final executable scene remains editable ReFusion `SceneProgram`.
   - No HTML/CSS/JS/React/Remotion/GSAP output.

2. Semantic input first.
   - Agents author semantic blueprints with components, slots, tokens, beats, and motion recipes.
   - Lowered SceneProgram may contain concrete native values.
   - Concrete values must retain trace metadata where practical.

3. Component contracts before coordinates.
   - If a component exists in the registry, the agent must use it.
   - Raw absolute placement is allowed only for explicitly supported freeform/artistic elements.

4. Text geometry is executable truth.
   - Bounded text must have finite layout constraints.
   - `textFrame` must survive lowering and be honored by preview/export rendering.
   - Static text and typewriter text are both checked.

5. SpeedyGraph is motion truth.
   - Professional motion compiles through `MotionInterpolationTruthCompiler`.
   - No second easing system inside NSI.
   - Linear timing is allowed only for mechanical/progress/typewriter cases when intentional.

6. Visual QA is a gate, not decoration.
   - Warnings are not enough for visible broken output.
   - Overflow, clipping, unsafe overlaps, and unsupported contracts must fail.

7. One checkpoint per phase.
   - Each phase gets focused tests.
   - Each phase is committed and pushed separately.
   - Stage only related files.

## 5. VERSION 2 Phase Order

### NSI-v2-00 - SpeedyGraph Foundation Dependency Gate

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 00 - speedygraph dependency gate
```

Purpose:

Verify that the already-built SpeedyGraph foundation is the only professional motion path used by NSI.

Required:

- Do not rebuild `MotionBezierVelocityBridge`.
- Do not rebuild `MotionInterpolationTruthCompiler`.
- Add or strengthen an NSI dependency test proving semantic easing tokens compile through `MotionInterpolationTruthCompiler`.
- Reject any NSI implementation that introduces:
  - a second easing catalog;
  - a second velocity compiler;
  - raw decorative cubic curves that bypass SpeedyGraph truth.
- Confirm these proofs exist:
  - `TF_SPEED_GRAPH_BRIDGE_PROOF`
  - `TF_SPEED_GRAPH_TRUTH_COMPILER_PROOF`

Acceptance:

- Easy Ease, Slow-Fast-Slow, Fast-Slow, Slow-Fast, Fast-Slow-Fast, and custom SpeedGraph references resolve to Bezier-backed interpolation.
- NSI motion compilation depends on SpeedyGraph truth.
- No duplicate motion truth path is introduced.

### NSI-v2-03A - Component Registry v2 + Variants

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 03a - component registry variants
```

Purpose:

Create the closed component vocabulary used by agents and the compiler.

Required components:

- `PromptInputBar`
- `FeedbackCard`
- `FeatureCard`
- `ResultCard`
- `DashboardPanel`
- `AppIconIntro`
- `CTAButton`
- `IconButton`
- `MotionTextBlock`
- `FloatingWindowCard`
- `OrbitalFeatureRing`

Each component definition must include:

- stable component id;
- required slots;
- optional slots;
- allowed child kinds;
- disallowed child kinds;
- default size rules;
- min/max size rules;
- content insets;
- gap;
- typography roles;
- icon slots;
- safe-area behavior;
- allowed motion recipes;
- validation rules.

Each component must support variants where useful:

```text
default
focused
loading
disabled
error
success
selected
```

Variant behavior:

- Variants apply controlled overrides only.
- Variants must not redefine the component structure.
- Unsupported variants fail closed with explicit reason.

Diagnostic:

```text
TF_SCENE_COMPONENT_REGISTRY_PROOF
```

Fields:

```text
componentId
variant
requiredSlots
providedSlots
missingSlots
unsupportedSlots
allowedChildKinds
passed
failureReason
```

Acceptance:

- Unsupported component names fail.
- Unsupported slot names fail.
- Unsupported variants fail.
- A `FeedbackCard` cannot be authored as a loose rectangle plus loose text.
- A `PromptInputBar` must include content and accessory slots.

### NSI-v2-03B - Generic Text Geometry + Multi-Policy Text Fit

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 03b - text geometry fit policies
```

Purpose:

Make text overflow structurally impossible in all bounded UI components.

Required:

Every meaningful text element inside a bounded component must have:

- `parentId`;
- `slotId` or `layoutRole`;
- finite `textFrame.width`;
- finite `textFrame.height`;
- `maxLines`;
- `lineHeight`;
- `textAlign`;
- `overflowPolicy`;
- `fitPolicy`;
- `fontFitRange` or typography token range.

Required `overflowPolicy` values:

```text
error
ellipsis
clip
```

Required `fitPolicy` values:

```text
none
shrinkToFit
wrapToLines
ellipsisAfterMaxLines
clipToFrame
shorten
scaleXForNumericOnly
```

Rules:

- `shrinkToFit` reduces font size only within token-bound `fontFitRange`.
- `wrapToLines` may increase line count only up to `maxLines`.
- `scaleXForNumericOnly` is allowed for numbers, dates, counters, and compact metrics only.
- `shorten` may apply only to labels or marketing copy where semantic shortening is allowed.
- Body copy in cards should default to wrap/ellipsis, not centered overflow.
- Bounded text overflow is an error unless the selected fit policy is implemented and proven.
- Static text and typewriter text must use the same fixed-frame contract.
- The render model must receive finite text bounds, not metadata-only `textFrame`.

Diagnostic:

```text
TF_SCENE_TEXT_GEOMETRY_PROOF
```

Fields:

```text
componentId
textId
parentId
slotId
textFrame
measuredWidth
measuredHeight
maxLines
overflowPolicy
fitPolicy
fontFitRange
renderedWithFiniteMaxWidth
passed
failureReason
```

Acceptance:

- Text inside any card/input/button/panel cannot render with infinite max width.
- Current failed SaaS feedback text fails before repair.
- Repaired SaaS feedback card text passes.
- Typewriter text reveals inside a fixed frame without relayout jitter.

### NSI-v2-04 - Constraint Layout Solver

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 04 - constraint layout solver
```

Purpose:

Replace coordinate guessing with deterministic component layout.

Required layout modes:

```text
horizontalStack
verticalStack
overlay
grid
anchored
absoluteAllowed
```

Required sizing modes:

```text
fixed
hugContent
fillContainer
minMax
aspectLocked
```

Required canvas profiles:

```text
story_9_16
landscape_16_9
square_1_1
portrait_4_5
cinema_21_9
```

Rules:

- Layout solver outputs deterministic bounds for every component and slot.
- Safe area is enforced for important text and UI.
- Decorative/full-bleed elements must declare that intent.
- Child bounds cannot exceed parent content rect unless explicitly allowed.
- Overlap is illegal for UI components unless the component contract allows it.
- Same blueprint must solve correctly across supported aspect profiles.

Diagnostic:

```text
TF_SCENE_LAYOUT_SOLVER_PROOF
```

Fields:

```text
canvasProfile
componentId
layoutType
parentBounds
contentBounds
childBounds
safeArea
overlapDetected
overflowDetected
deterministicLayoutHash
passed
failureReason
```

Acceptance:

- Five representative layouts solve deterministically.
- PromptInputBar, FeedbackCard, DashboardPanel, FeatureCard, and CTAButton solve without loose child geometry.
- Same blueprint adapts to `9:16`, `16:9`, `1:1`, and `4:5`.

### NSI-v2-05 - Beat Grammar + SpeedyGraph Motion Rules

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 05 - beat grammar speedygraph rules
```

Purpose:

Make timing readable, intentional, and musically structured.

Required:

Every important motion belongs to a beat with:

- `enter`;
- `hold`;
- `exit`;
- optional `transition`;
- component references;
- motion intent;
- SpeedyGraph timing.

Hold guidance:

```text
short label: 250-400ms
normal text: 500-900ms
complex card/UI: 900-1400ms
hero/final shot: explicit final hold unless transitioning
```

Rules:

- Important text cannot finish revealing at the scene boundary.
- Component exit must be intentional, not caused only by layer lifetime ending.
- Same target/property cannot have duplicate overlapping channels.
- Cinematic component movement must use SpeedyGraph presets or explicit Bezier/custom graph.
- `linear` is allowed only for mechanical motion, progress, and typewriter reveal when declared.
- Transition cuts should happen at motion peaks or after stable holds.

Diagnostic:

```text
TF_SCENE_BEAT_GRAMMAR_PROOF
```

Fields:

```text
beatId
componentRefs
phase
startMs
endMs
holdMs
easing
curveHash
readable
overlapPolicy
duplicateChannelDetected
passed
failureReason
```

Acceptance:

- Beat timing catches unreadable text/card timing.
- Duplicate same-property channels are rejected or merged.
- SpeedyGraph references compile through `MotionInterpolationTruthCompiler`.

### NSI-v2-06 - Deterministic Blueprint To SceneProgram Compiler

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 06 - deterministic blueprint compiler
```

Purpose:

Compile semantic blueprints into editable native ScenePrograms deterministically.

Required:

- Components lower to editable native shape/text/icon/image/video elements.
- Tokens resolve to concrete native values.
- Resolution trace metadata is retained where practical.
- Slot layout becomes `parentId` plus executable bounds.
- Text frames become renderable text layout contracts.
- Beats lower to keyframes/channels.
- SpeedyGraph tokens lower through `MotionInterpolationTruthCompiler`.

Determinism contract:

- Same normalized blueprint must produce the same SceneProgram hash.
- Same blueprint compiled 100 times must produce identical output.
- Raw numbers in agent-facing blueprint are rejected unless explicit `rawValueOverride` is used.
- Lowered SceneProgram may contain resolved native numbers.

Diagnostic:

```text
TF_SCENE_DETERMINISM_PROOF
```

Fields:

```text
blueprintHash
sceneProgramHash
compileIteration
rawValuesDetected
rawValueOverrides
tokenResolutionHash
deterministic
passed
failureReason
```

Acceptance:

- `hash(blueprint)` maps deterministically to `hash(sceneProgram)`.
- Direct loose SceneProgram authoring remains supported for compatibility but must pass the same visual safety gates.
- Professional presets should prefer semantic blueprints.

### NSI-v2-07 - Visual QA Thumbnail Renderer MVP

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 07 - visual qa thumbnail renderer
```

Purpose:

Validate visual truth with rendered or render-proxy probes.

Required probe frames:

- scene start;
- each important hold frame;
- transition peak frames;
- final frame.

Default probe budget:

```text
target: up to 9 probes
fallback: 5 probes for heavy scenes
MVP time budget: <= 800ms when practical for probe analysis
```

Metrics:

- text overflow;
- element clipping;
- parent/child containment;
- unsafe overlap;
- safe-area violation;
- contrast;
- final-frame stability;
- unfinished animation at boundary.

Diagnostic:

```text
TF_SCENE_VISUAL_FRAME_QA_PROOF
```

Fields:

```text
frameMs
probeIndex
probeCount
componentId
textOverflow
clipped
overlap
safeAreaViolation
contrastPass
unfinishedMotion
probeDurationMs
performanceBudgetExceeded
passed
failureReason
```

Acceptance:

- Current bad SaaS layout is detected.
- Repaired SaaS layout passes.
- QA does not claim success without probe evidence.
- Performance budget is measured and reported.

### NSI-v2-08 - Structured Repair Feedback Loop

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 08 - structured repair loop
```

Purpose:

Turn failed validation into machine-readable repair instructions for agents.

Required:

Every failure must produce:

- error code;
- component id;
- element id;
- frame time if visual;
- measured problem;
- severity;
- suggested fix;
- retry-safe payload.

Required repair codes:

```text
TEXT_OVERFLOW_RIGHT
TEXT_OVERFLOW_HEIGHT
MISSING_PARENT_SLOT
CARD_CHILD_FLOATING
UNSUPPORTED_ICON
UNSUPPORTED_COMPONENT
UNSUPPORTED_VARIANT
SAFE_AREA_VIOLATION
DUPLICATE_PROPERTY_CHANNEL
UNREADABLE_HOLD
UNFINISHED_BOUNDARY_MOTION
SPEEDYGRAPH_BYPASS
NON_DETERMINISTIC_COMPILATION
```

Rules:

- Max repair attempts: 3.
- After 3 failures, return human-readable failure summary.
- Do not silently accept a broken scene after repair exhaustion.

Diagnostic:

```text
TF_SCENE_REPAIR_LOOP_PROOF
```

Fields:

```text
attempt
errorCode
componentId
elementId
frameMs
suggestedAction
repairApplied
remainingErrors
converged
passed
failureReason
```

Acceptance:

- Failed scenes can be converted into actionable repair payloads.
- Repair loop does not run indefinitely.
- At least one bad SaaS-style fixture repairs or clearly fails with reasons.

### NSI-v2-09 - Skills, Exemplars, Migration

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 09 - skills exemplars migration
```

Purpose:

Make external agents write correct scenes by reading `refusion-skills`.

Repository:

```text
/Users/mx/Documents/refusion-skills
```

Required skills updates:

- Semantic Blueprint rules.
- Component Registry rules.
- Text geometry and fit rules.
- Icon slot and supported icon rules.
- Beat Grammar rules.
- SpeedyGraph motion rules.
- Determinism rules.
- Visual QA self-check rules.
- Repair payload interpretation rules.
- Good/bad examples.
- SaaS scene as regression example, not the only target.

Migration requirements:

- Provide a v1-to-v2 migration guide.
- Existing direct SceneProgram remains importable.
- Legacy scenes may enter a compatibility path, but professional presets should migrate to semantic blueprints.
- Add migration tests for representative existing fixtures.

Acceptance:

- Skills repo can teach an external agent to author a component-safe scene.
- Rebuilt skill bundle includes VERSION 2 rules.
- Examples validate.
- Migration story is documented and tested where practical.

### NSI-v2-10 - Closure QA

Checkpoint:

```text
checkpoint: 2026-05-08 professional native scene intelligence v2 10 - closure qa
```

Purpose:

Close VERSION 2 with proof that the full system works.

Required verification:

- focused tests from all VERSION 2 phases;
- existing SceneProgram import tests;
- existing PromptInputBar tests;
- existing typewriter fixed-frame tests;
- SpeedGraph bridge/truth compiler tests;
- semantic token registry tests;
- semantic blueprint tests;
- component registry tests;
- text geometry tests;
- layout solver tests;
- beat grammar tests;
- deterministic compiler tests;
- visual QA tests;
- repair loop tests;
- migration tests where added.

Build/install:

```text
flutter build apk --debug
install on connected wireless Android device if available
```

Final plan update:

- mark `NSI-v2-00` through `NSI-v2-10` completed;
- list commits;
- list known risks;
- list rollback commands.

## 6. Integration Gates

Each phase must close with a gate before the next phase starts.

| Gate | Required Proof |
|---|---|
| `v2-00` | SpeedyGraph dependency tests pass; no second easing system |
| `v2-03A` | 3+ components validate with slots and variants |
| `v2-03B` | bounded static and typewriter text cannot overflow |
| `v2-04` | 5 layouts solve deterministically across aspect profiles |
| `v2-05` | beats own important motion and readable holds |
| `v2-06` | same blueprint compiled 100 times gives same hash |
| `v2-07` | visual probes detect bad fixtures and pass repaired fixtures |
| `v2-08` | failed scenes produce structured repair payloads in <= 3 attempts |
| `v2-09` | skills examples validate and migration story exists |
| `v2-10` | all focused tests plus build pass |

## 7. Required Regression Fixtures

VERSION 2 must include more than one SaaS fixture.

Required fixtures:

1. Bad SaaS feedback cards.
   - Must fail when authored as loose rectangles plus loose text.
   - Must pass when authored as `FeedbackCard` components.

2. Prompt input bar.
   - Must fail when prompt text is larger than input.
   - Must pass with fixed text frame and accessory slot.

3. Dashboard panel.
   - Must prove dense UI text and cards fit.

4. Feature card grid.
   - Must prove grid layout adapts across aspect ratios.

5. App icon to input morph.
   - Must prove beat continuity and no disconnected fade trick.

6. Motion text promo.
   - Must prove typewriter/reveal remains inside fixed frame.

## 8. Required Performance Budgets

| System | MVP Budget |
|---|---|
| Token registry full load | < 4 MB when practical |
| Component registry full load | < 4 MB when practical |
| Blueprint compile | deterministic and fast enough for authoring loop |
| Visual QA probes | target <= 800ms for MVP probe analysis when practical |
| Repair loop | max 3 attempts |
| Preview render path | no Stage5/Live Scrub changes unless explicitly required |

If a budget cannot be met, the phase must report:

- measured cost;
- reason;
- fallback;
- follow-up plan.

## 9. Stop List

Do not:

- rebuild SpeedyGraph inside NSI;
- create another easing/velocity system;
- fix only the SaaS scene;
- allow loose text over rectangles for professional components;
- allow bounded UI text to render with infinite max width;
- allow cards without parent/slot ownership;
- allow unsupported icons or invented icon ids;
- allow visual warnings where output is visibly broken;
- claim Visual Closure without probe evidence and repair payloads;
- touch Stage5, Live Scrub, Motion Tile, Motion Blur, or unrelated FX files unless explicitly required and documented;
- stage unrelated screenshots, diagnostics, seam files, or local artifacts;
- break direct SceneProgram compatibility without a migration path.

## 10. Agent Writer Instruction

Use this exact execution discipline:

1. Read:
   - `docs/professional_checkpoint_policy.md`
   - `docs/professional_native_scene_intelligence_system.md`
   - `docs/professional_native_scene_intelligence_system_version_2.md`
   - `docs/professional_speed_graph_system.md`
   - `docs/professional_agent_scene_program_engine.md`
   - `docs/refusion_scene_program_agent_authoring_guide.md`
2. Run `git status -sb`.
3. Identify unrelated dirty/untracked files and leave them alone.
4. Implement exactly one VERSION 2 phase.
5. Add focused tests for that phase.
6. Run the smallest relevant tests.
7. Broaden tests only when the phase touches shared contracts.
8. Build/install only when app behavior changes.
9. Stage only focused files.
10. Commit with the exact checkpoint name.
11. Push the branch.
12. Report:
    - commit hash;
    - changed files;
    - tests run;
    - build/install result;
    - remaining risks;
    - rollback command.

Rollback format:

```bash
git -C /Users/mx/Documents/ReFusionXx revert <commit-hash>
```

## 11. Final Definition Of Done

VERSION 2 is complete only when:

- external agents can author semantic blueprints using closed vocabulary;
- semantic blueprints compile deterministically to native SceneProgram;
- cards, inputs, panels, and buttons use component contracts;
- text geometry is enforced for static and animated text;
- layout is solved by constraints across supported aspect ratios;
- important motion is owned by beats and uses SpeedyGraph truth;
- Visual QA catches overflow, clipping, overlap, and unsafe frames;
- repair payloads are structured enough for an agent to fix scenes;
- skills repo includes VERSION 2 rules and examples;
- existing direct SceneProgram compatibility remains documented;
- all focused tests pass;
- debug APK builds;
- install succeeds when a wireless Android device is connected.
