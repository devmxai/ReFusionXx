# HyperFrames And Remotion Research Workspace

Purpose: keep a local, inspectable research copy of HyperFrames and Remotion so ReFusionXx can extract architecture patterns, authoring rules, registry design, component catalogs, motion recipes, and QA practices into a ReFusion-native creative engine.

This folder is a research workspace, not application runtime code.

## Local Repositories

| Project | Local path | Upstream | Local commit | Clone mode | License note |
|---|---|---|---|---|---|
| HyperFrames | `repos/hyperframes` | `https://github.com/heygen-com/hyperframes` | `57b6858` | `--depth=1` HEAD working tree | Apache-2.0 |
| Remotion | `repos/remotion` | `https://github.com/remotion-dev/remotion` | `6bef89f` | `--depth=1` HEAD working tree | Custom Remotion License |

`--depth=1` keeps the full current working tree for source analysis without downloading the complete Git history. This is enough for architecture extraction, registry design, API study, skills study, and component/effect/motion mapping.

## Analysis Files

- `analysis/hyperframes_architecture_notes.md`
- `analysis/remotion_architecture_notes.md`
- `analysis/refusion_native_extraction_map.md`

## Core Rule

Do not embed HyperFrames or Remotion as a second truth/runtime inside ReFusionXx.

The professional path is:

```text
HyperFrames / Remotion source study
        ↓
ReFusion-native registries, recipes, components, skills, validators
        ↓
Canonical SceneCommand
        ↓
Unified Apply Engine
        ↓
Canonical Creative Graph
        ↓
Timeline Graph + Motion Channels + Effect Instances
        ↓
Preview Renderer + Export Renderer
```

That preserves editability, native preview, native export, one timeline, one frame evaluator, and one source of truth.
