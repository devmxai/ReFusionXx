# Professional Motion Director Engine

Status: official execution plan  
Package: `com.refusion.app`  
Date: 2026-04-28  
Depends on:

- `docs/professional_checkpoint_policy.md`
- `docs/professional_refusion_motion_keyframe_engine.md`
- `docs/professional_agent_scene_program_engine.md`
- `docs/professional_scene_container_and_mention_motion_plan.md`

## 0. Purpose

The Scene Program JSON is the editable execution format. It is not enough by
itself to guarantee professional choreography.

The Motion Director Engine is the planning layer above Scene Program. It gives
agents a disciplined way to think before writing keyframes:

```text
user prompt
-> director plan
-> ordered beats
-> semantic components
-> animation primitives
-> scene-program JSON
-> validation/lint/repair
-> editable scene clip
```

The goal is to stop random overlapping motion and make generated scenes feel
intentional, like a compact After Effects composition or a Remotion composition
with clear sequences.

## 1. Non-Negotiable Rules

### 1.1 Live Scrub Protection

This engine does not modify Live Scrub.

Protected paths remain off-limits unless the user explicitly asks for a specific
Live Scrub fix:

- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`
- `Stage5PreviewPlatformView`
- Flutter native scrub handoff paths

### 1.2 Checkpoints

Every implementation slice under this plan must be committed and pushed as a
focused checkpoint:

```text
implement safe slice
-> verify
-> commit related files only
-> push branch
-> install on connected device when available
```

Rollback note format:

```bash
git revert <commit-hash>
```

### 1.3 No Executable Agent Output

Agents may describe motion only as data:

- director plan,
- semantic components,
- primitives,
- Scene Program JSON,
- Motion Patch JSON.

Forbidden:

- JSX,
- JavaScript,
- Dart code,
- CSS animations,
- hidden runtime functions,
- remote code imports.

## 2. Director Contract

The Director Plan schema is:

```text
refusion.motion-director/v1
```

It contains:

- composition metadata: name, duration, fps, canvas size;
- `beats`: ordered narrative time blocks;
- `components`: semantic scene objects such as prompt shell, typed text, send
  button, cover circle;
- `primitives`: motion intentions attached to a beat and component.

Example choreography:

```text
0-520ms     prompt bar enters
520-1900ms  text types on
1900-2140ms send button press
2300-4200ms circle expands to cover the screen
```

The linter rejects:

- overlapping beats,
- primitives outside their beat,
- missing component targets,
- timing outside composition duration,
- backward typewriter primitives,
- empty IDs and invalid core metadata.

## 3. Agent Authoring Behavior

An agent must not jump straight from prompt to keyframes.

Required thinking order:

1. Name the visual idea.
2. Split the scene into beats.
3. Define semantic components.
4. Assign one primitive per intentional motion.
5. Compile primitives into Scene Program layers/channels/keyframes.
6. Return JSON only.

Good:

```text
Beat: type prompt
Component: typed prompt text
Primitive: typewriterProgress 0 -> 1 over 1200ms, linear
```

Bad:

```text
Create one text layer per character and fade each randomly.
```

Good:

```text
Beat: send action
Component: send button
Primitive: press scale 1.0 -> 0.92 -> 1.0
```

Bad:

```text
Move all layers and fade everything at the same time.
```

## 4. Execution Phases

### Phase D1 - Director Models And Linter

Status: completed foundation.

Files:

- `lib/features/editor/domain/models/refusion_motion_director_models.dart`
- `lib/features/editor/domain/services/refusion_motion_director_linter.dart`
- `test/refusion_motion_director_linter_test.dart`

Acceptance:

- ordered beat plans pass;
- overlapping beat plans fail;
- unknown component targets fail;
- primitives outside the owning beat fail;
- backward typewriter primitives fail.

### Phase D2 - Director Prompt Contract

Goal:

- make KIE/agent requests include a Director Plan requirement before returning
  executable Scene Program or Motion Patch JSON;
- expose a compact app-owned checklist to external agents;
- keep the final output JSON-only and editable.

Acceptance:

- model requests include beats/components/primitives rules;
- typewriter guidance is explicit;
- no API call happens during tests.

Status:

- completed foundation for Mention Motion requests. KIE motion-agent request
  previews now carry a `directorContract`, and the system instruction requires
  ordered beat planning before JSON output.
- full Scene Program generation UI will reuse the same contract in a later
  slice.

### Phase D3 - Director To Scene Program Compiler

Goal:

- compile known semantic components into supported scene-program primitives;
- start with `promptInputBar`, `typewriterText`, `sendButton`, and
  `circleCover`;
- generate one Scene Clip container with internal editable layers.

Acceptance:

- prompt-bar director plan lowers to one root Scene Clip;
- Scene Scope shows internal layers;
- Layer Scope shows editable keyframes.

### Phase D4 - Lint And Auto-Repair Before Apply

Goal:

- run Director lints and Scene Program validation before applying;
- perform safe repairs only when semantics are clear;
- reject unsafe or ambiguous scenes with actionable messages.

Acceptance:

- too-short layers can be extended when safe;
- project/local time confusion can be normalized with warnings;
- chaotic overlap is blocked rather than silently accepted.

### Phase D5 - Visual QA And Export Parity

Goal:

- preview and export evaluate the same generated graph;
- scene-only canvas export and authored shape/image export are completed
  without silent drops.

Acceptance:

- generated text/shape/icon scenes preview and export;
- export blocker sheet becomes clean for supported scene content;
- unsupported features stay blocked with precise blocker messages.

## 5. Current Priority

The next safest implementation is D2, then D3.

Do not bypass D2 by asking the model to invent raw keyframes freely. That would
return to the original problem: valid JSON that still feels visually random.
