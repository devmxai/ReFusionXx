# Scoped Text Motion Script V1

Status: first import contract for `Add Script` inside text scoped layer.

This document defines the first practical script format that AI agents can
generate for ReFusion without needing target IDs.

## Core Rule

The script is always applied to the **currently opened scoped text layer**.

Do not ask the user for:

- `targetId`
- `elementId`
- `layerId`
- `sceneId`

Those are resolved by the app from the active scoped layer context.

## Goal

Allow an AI agent to generate motion that:

- applies to the selected text layer
- creates real channels and real keyframes
- appears immediately inside the scoped timeline
- stays editable after import through:
  - keyframe move
  - keyframe value edits
  - graph/easing edits
  - manual timeline retiming

## Supported Input Formats

Current supported input:

- `JSON`
- `YAML`

Current unsupported direct input:

- `JSX`
- `TSX`
- executable JavaScript

If an AI system starts from JSX or Remotion-style code, it must first convert
that motion into this canonical JSON/YAML contract.

## Recommended Agent Prompt

Use this prompt when asking an AI agent to generate a ReFusion motion script:

```text
Write a ReFusion Scoped Text Motion Script v1 in JSON only.

Important rules:
- Do not include targetId, elementId, layerId, or sceneId.
- The script will be applied to the currently opened scoped text layer.
- Prefer explicit channels and keyframes so the result stays editable.
- Use timeMs for timing.
- Use supported properties only: opacity, position, positionX, positionY,
  scale, scaleX, scaleY, rotation, blur, revealProgress.
- For revealProgress, also include reveal.by and reveal.direction when needed.
- Use easing values only from: hold, linear, easeIn, easeOut, easeInOut,
  easyEase, bounce, elastic.
- Return only valid JSON, with no markdown fences and no explanation.
```

## Contract

### Minimum Shape

```json
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Pop Bounce In",
  "channels": [
    {
      "property": "opacity",
      "keyframes": [
        { "timeMs": 0, "value": 0, "easing": "linear" },
        { "timeMs": 220, "value": 100, "easing": "easeOut" }
      ]
    }
  ]
}
```

### Optional Top-Level Fields

```text
schemaVersion
name
fps
reveal
channels
animationBlocks
```

### Reveal Metadata

```json
{
  "reveal": {
    "by": "letter",
    "direction": "forward"
  }
}
```

Supported values:

- `by`: `word`, `letter`, `wholeText`
- `direction`: `forward`, `reverse`

## Property Rules

### Scalar Properties

These expect numeric values:

- `opacity` (0 to 100)
- `positionX`
- `positionY`
- `rotation` (degrees)
- `blur` (0 to 100)
- `revealProgress` (0 to 100)
- `scaleX` (percent)
- `scaleY` (percent)

### Vector Properties

`position` expects:

```json
{ "x": 0, "y": 36 }
```

`scale` supports either:

```json
100
```

or:

```json
{ "x": 100, "y": 112 }
```

## Easing Rules

Supported easing strings:

- `hold`
- `linear`
- `easeIn`
- `easeOut`
- `easeInOut`
- `easyEase`
- `bounce`
- `elastic`

## High-Level Block Import

If an AI agent cannot author explicit channels yet, it may use:

- `animationBlocks`
- `motions`
- `blocks`

Example:

```json
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Quick Fade Scale In",
  "animationBlocks": [
    {
      "kind": "fadeIn",
      "startMs": 0,
      "durationMs": 260
    },
    {
      "kind": "scaleIn",
      "startMs": 0,
      "durationMs": 760,
      "parameters": {
        "fromScale": 74,
        "toScale": 100
      }
    }
  ]
}
```

Supported block kinds:

- `fadeIn`
- `fadeOut`
- `wordReveal`
- `letterReveal`
- `typewriter`
- `elasticPop`
- `scaleIn`
- `scaleOut`
- `blurIn`
- `blurOut`
- `rotationSettle`
- `cinematicEntrance`
- `cinematicExit`

## Best Practice

Prefer `channels` when:

- the AI should create precise editable motion
- the user will retime or reshape keyframes manually after import
- the animation uses bounce, overshoot, or layered timing

Prefer `animationBlocks` only when:

- the AI is sketching a fast starting point
- the motion is closer to a named preset than fully custom choreography

## Example: Pop + Bounce + Fade

```json
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Punchy Bounce In",
  "channels": [
    {
      "property": "opacity",
      "keyframes": [
        { "timeMs": 0, "value": 0, "easing": "linear" },
        { "timeMs": 180, "value": 100, "easing": "easeOut" }
      ]
    },
    {
      "property": "scale",
      "keyframes": [
        { "timeMs": 0, "value": 68, "easing": "easeOut" },
        { "timeMs": 320, "value": 118, "easing": "easeOut" },
        { "timeMs": 760, "value": 100, "easing": "easyEase" }
      ]
    },
    {
      "property": "positionY",
      "keyframes": [
        { "timeMs": 0, "value": 52, "easing": "easeOut" },
        { "timeMs": 760, "value": 0, "easing": "easyEase" }
      ]
    }
  ]
}
```

## Example: Type On

```json
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Letter Type On",
  "reveal": {
    "by": "letter",
    "direction": "forward"
  },
  "channels": [
    {
      "property": "revealProgress",
      "keyframes": [
        { "timeMs": 0, "value": 0, "easing": "linear" },
        { "timeMs": 1400, "value": 100, "easing": "linear" }
      ]
    }
  ]
}
```

## Validation Philosophy

The app should validate before apply:

- supported format
- supported properties
- valid timing
- valid easing
- reveal semantics if `revealProgress` is used

The app should reject invalid scripts rather than guessing.

## Product Intent

This format is intentionally:

- target-free for the user
- AI-friendly
- deterministic
- editable after import
- compatible with the existing ReFusion motion engine

It is not a second engine, and it is not a preview-only trick.
