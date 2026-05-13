# HyperFrames Architecture Notes For ReFusionXx

Source snapshot:

- Local path: `/Users/mx/Documents/ReFusionXx/research/hyperframe_and_remotion/repos/hyperframes`
- Commit: `57b6858`
- Date in upstream log: `2026-05-13`
- File count: `1,442`
- Packages: `7`
- License: Apache-2.0

## What HyperFrames Is Optimized For

HyperFrames is built around HTML-native video composition with first-class AI agent support. Its strongest ideas for ReFusionXx are not just the renderer; they are the whole authoring system:

- clear composition metadata in markup
- deterministic seek-driven timeline playback
- registry blocks and components
- agent skills that teach composition rules
- CLI workflows that are non-interactive and machine-friendly
- preview/render/conformance tooling
- adapter pattern for GSAP, CSS, WAAPI, Lottie, Three.js, Anime.js, Tailwind, and related web runtimes

## Important Source Areas

| Area | Path | Lesson for ReFusionXx |
|---|---|---|
| Core package | `packages/core` | Typed composition contracts, compiler/linter/runtime guard patterns |
| Engine package | `packages/engine` | Deterministic frame capture, screenshot/render service, virtual-time ideas |
| Player package | `packages/player` | Seek/play/pause adapters and runtime bridge strategy |
| Producer package | `packages/producer` | Render orchestration, parity/regression/conformance harnesses |
| CLI package | `packages/cli` | Agent-friendly command design and machine-readable workflows |
| Registry | `registry` | Catalog system for reusable blocks/components |
| Skills | `skills` | Agent instruction packs by capability/runtime |

## Registry Design

HyperFrames has a concrete registry schema at:

`repos/hyperframes/packages/core/schemas/registry-item.json`

The registry index at:

`repos/hyperframes/registry/registry.json`

currently contains:

- total items: `63`
- examples: `8`
- blocks: `51`
- components: `4`

Important registry fields:

- `name`
- `type`
- `title`
- `description`
- `tags`
- `dimensions`
- `duration`
- `files`
- `preview.video`
- `preview.poster`
- `relatedSkill`

### ReFusion Translation

ReFusion should build a `ProfessionalCreativeLibraryRegistry` with the same spirit, but native fields:

- `id`
- `kind`: component, effect, motionRecipe, template, transition, iconPack, sceneBlock
- `title`
- `description`
- `tags`
- `supportedNodeKinds`
- `parameterSchema`
- `defaultDurationMs`
- `supportedAspectRatios`
- `previewPosterAsset`
- `previewMotionAsset`
- `compileToSceneCommands`
- `loweringContract`
- `previewRendererSupport`
- `exportRendererSupport`
- `manualUiSurface`
- `mcpToolSurface`
- `agentSkillExamples`
- `qaRules`

## Skills Model

HyperFrames ships many skills:

- `hyperframes`
- `hyperframes-cli`
- `hyperframes-registry`
- `hyperframes-media`
- `gsap`
- `css-animations`
- `waapi`
- `lottie`
- `three`
- `animejs`
- `tailwind`
- `website-to-hyperframes`
- `remotion-to-hyperframes`

The lesson is important: the skills are not random docs. They are capability-specific operating manuals. ReFusion should mirror this with generated or registry-backed skills:

- `refusion-composition-author`
- `refusion-motion-recipes`
- `refusion-effects`
- `refusion-components`
- `refusion-spatial-layout`
- `refusion-video-editing`
- `refusion-text-design`
- `refusion-verification`

## Runtime/Player Lessons

HyperFrames uses deterministic seek/playback ideas:

- composition metadata in `data-composition-id`, dimensions, start, duration, track index
- direct timeline adapters
- runtime bridge
- same-origin seek paths
- render-time virtual clock
- conformance and parity harnesses

### ReFusion Translation

ReFusion should not use HTML as runtime truth, but should adopt the same invariants:

- every composition has explicit width, height, fps, duration
- every node has explicit start, duration, track, z-order
- every animation is seekable from frame/time, not wall-clock-only
- every preview and export frame uses the same frame evaluator
- player, scrubber, MCP, manual UI, and export all evaluate the same graph

## Catalog Lessons

HyperFrames registry includes social overlays, transitions, charts, VFX, cards, notifications, and examples. The main lesson is not to copy HTML files into ReFusion. The lesson is to create equivalent ReFusion-native packs:

- Social overlay pack
- Lower-third pack
- Data/chart pack
- VFX transition pack
- Texture/effect pack
- Kinetic type pack
- Product promo pack
- UI showcase pack

Each pack should be editable after insertion and must compile into ReFusion nodes, clips, effects, and motion channels.

## What Not To Copy

- Do not make HTML the source of truth.
- Do not make GSAP timelines the source of truth.
- Do not make a browser runtime the default preview/export path.
- Do not let registry blocks become flattened videos unless explicitly marked as prerendered/non-editable.

## What To Adopt

- Registry schema discipline
- Skills-per-capability structure
- Catalog previews
- Agent-friendly CLI/discovery ideas
- Deterministic seek contract
- Render conformance tests
- Adapter architecture, but targeting ReFusion-native graph outputs
