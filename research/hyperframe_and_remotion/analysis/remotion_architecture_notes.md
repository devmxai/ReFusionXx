# Remotion Architecture Notes For ReFusionXx

Source snapshot:

- Local path: `/Users/mx/Documents/ReFusionXx/research/hyperframe_and_remotion/repos/remotion`
- Commit: `6bef89f`
- Date in upstream log: `2026-05-13`
- File count: `10,528`
- Packages: `121`
- License: custom Remotion License. The local license file states free eligibility for individuals, non-profits, evaluation, and for-profit organizations up to 3 employees; larger for-profit organizations require a company license.

## What Remotion Is Optimized For

Remotion is built around React components as video source. Its most valuable lessons for ReFusionXx:

- explicit composition metadata: width, height, fps, duration
- frame-driven rendering with `useCurrentFrame()`
- composition context with `useVideoConfig()`
- deterministic interpolation and spring helpers
- `Sequence` as a timeline primitive
- reusable packages for effects, transitions, shapes, captions, fonts, media, renderer, player, studio
- one-frame render checks and render diagnostics
- skills/rules for agents

## Important Source Areas

| Area | Path | Lesson for ReFusionXx |
|---|---|---|
| Core | `packages/core` | Composition context, frame clock, interpolation, Sequence, spring, media timing |
| Renderer | `packages/renderer` | Browser/frame capture/render orchestration, audio/video mux and diagnostics |
| Player | `packages/player` | Embeddable preview/player behavior |
| Studio | `packages/studio` | Preview/editing environment patterns |
| Transitions | `packages/transitions` | Transition series, timing/presentation separation |
| Effects | `packages/effects`, `packages/motion-blur`, `packages/light-leaks`, `packages/noise` | Effect component packaging |
| Shapes | `packages/shapes` | Shape primitives and generated geometry |
| Skills | `packages/skills` | Agent-facing rules for Remotion authoring |
| Templates | `packages/template-*` | Starter packs for common production use cases |

## Core Mental Model

Remotion exposes a simple mental model:

- a composition declares width, height, fps, duration
- current frame is the deterministic clock
- visual values are functions of frame
- media timing is part of the timeline
- transitions and sequences compose over frame ranges

### ReFusion Translation

ReFusion should express the same idea without React:

```text
CompositionMetadata(width, height, fps, durationMs)
        ↓
MasterFrameEvaluator(timeMs/frame)
        ↓
Node properties = evaluated channels at that frame
        ↓
Preview and Export use identical evaluated visual program
```

Remotion's `useCurrentFrame()` maps to ReFusion's master frame evaluator. Remotion's `interpolate()` maps to canonical motion channels and easing curves. Remotion's `Sequence` maps to timeline clips and start/duration. Remotion's `Composition` maps to ReFusion composition identity and metadata.

## Skills And Rules

Remotion has agent skills under:

`repos/remotion/packages/skills/skills/remotion`

Key rules include:

- composition setup
- timing
- sequencing
- transitions
- text animations
- audio
- captions/subtitles
- trimming
- media dimensions/duration
- fonts
- light leaks
- measuring DOM/text

### ReFusion Translation

ReFusion should create equivalent skill packs, but they must target ReFusion DSL/tools:

- before spatial operations: query canvas and element geometry
- never animate by storing metadata only
- use update commands for existing targets
- use timeline clips for duration
- use motion channels for animation
- verify appApplied proof after writes
- prefer semantic components/effects from the registry

## Effect And Transition Lessons

Remotion separates effect packages and transition presentation/timing. For ReFusion:

- effect identity should be separate from parameters
- effect applicability should be explicit per node kind
- preview/export support should be declared
- timing should be separate from visual presentation
- transitions should be timeline entities, not ad hoc layer metadata

Recommended ReFusion contracts:

```text
EffectDefinition(id, supportedNodeKinds, parameterSchema, rendererSupport)
EffectInstance(id, effectDefinitionId, targetNodeId, params, startMs, durationMs)
TransitionDefinition(id, parameterSchema, defaultTiming)
TransitionInstance(id, fromClipId, toClipId, timing, params)
```

## Shape And Geometry Lessons

Remotion's shapes package is useful as a reference for treating shapes as first-class primitives with geometry generators and tests. ReFusion should model:

- rect
- rounded rect
- circle
- ellipse
- triangle
- polygon
- star
- arrow
- heart
- pie

as editable native shape nodes, not as flattened images.

## What Not To Copy

- Do not make React components the source of truth.
- Do not make browser rendering the default ReFusion preview path.
- Do not copy Remotion source code into ReFusion without legal review.
- Do not depend on Remotion packages as mobile runtime dependencies unless there is a separate licensed sidecar decision.

## What To Adopt

- explicit composition metadata
- frame-driven deterministic evaluation
- interpolation/easing/spring vocabulary
- sequence/timeline discipline
- transition presentation/timing split
- effect package boundaries
- shape primitive coverage
- skills/rules structure
- one-frame render/proof checks
