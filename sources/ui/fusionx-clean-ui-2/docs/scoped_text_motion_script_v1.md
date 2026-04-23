# Scoped Text Motion Script V1

Status: active authoring contract after interpolation rollout Phases 1-5.

This document defines the practical script format that AI agents should now
generate for ReFusion without needing target IDs.

After the interpolation rollout updates, agents should prefer canonical
interpolation objects for spring/bounce/elastic motion instead of faking those
behaviors with dense manual scale keyframes.

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

## What Changed After The Motion Update

Older scripts may still import successfully, but they may not benefit from the
new motion path if they were authored like this:

- many tiny scale keyframes trying to imitate bounce manually
- only `linear` or generic `easeOut` easing
- no explicit interpolation payload for spring/bounce/elastic

The updated authoring direction is:

- prefer fewer, clearer keyframes
- place the important poses at meaningful times
- express motion character through canonical interpolation objects
- let ReFusion evaluate spring/bounce/elastic from the interpolation spec

In practice, that means an AI agent should now prefer:

- `easing: { "kind": "spring", ... }`
- `easing: { "kind": "bounce", ... }`
- `easing: { "kind": "elastic", ... }`

instead of manually simulating the same feel with many baked keys unless the
user explicitly asks for handcrafted frame-by-frame timing.

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
  easyEase, spring, bounce, elastic.
- For `spring`, `bounce`, and `elastic`, prefer object form with explicit
  parameters so the authored meaning stays stable.
- Do not fake bounce or elastic with many tiny scale keys unless the user
  explicitly asks for a hand-shaped animation.
- Prefer 2 to 4 key poses per property for entrances and settles, then attach
  the motion character through interpolation objects.
- Return only valid JSON, with no markdown fences and no explanation.
```

Related:

- `docs/professional_motion_interpolation_rollout.md` defines the canonical
  interpolation contract and rollout phases

## Contract

## Agent Interpretation Rules

If an agent is asked to create motion such as:

- bounce in
- elastic pop
- text rises in and settles
- pop-up headline entrance

the agent should think in this order:

1. choose the minimum set of properties needed:
   - usually `opacity`
   - `scale` and/or `position`
   - sometimes `rotation`
2. place the main poses at meaningful times
3. attach canonical interpolation specs to the transitions
4. keep the result editable after import

The agent should not require:

- IDs
- internal engine names
- hidden timeline references

The opened scoped text layer is the target.

## Interpolation Guidance

Recommended canonical object forms:

```json
{
  "kind": "spring",
  "stiffness": 220,
  "damping": 18,
  "mass": 1,
  "initialVelocity": 0
}
```

```json
{
  "kind": "bounce",
  "amplitude": 0.18,
  "bounces": 3,
  "decay": 8.0
}
```

```json
{
  "kind": "elastic",
  "amplitude": 0.14,
  "period": 0.28,
  "decay": 8.0
}
```

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

### Recommended Shape For Professional Motion

For professional entrances, prefer explicit channels with interpolation objects.

Example: bounce-style headline pop

```json
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Headline Bounce In",
  "channels": [
    {
      "property": "opacity",
      "keyframes": [
        {
          "timeMs": 0,
          "value": 0,
          "easing": "linear"
        },
        {
          "timeMs": 140,
          "value": 100,
          "easing": "easeOut"
        }
      ]
    },
    {
      "property": "position",
      "keyframes": [
        {
          "timeMs": 0,
          "value": { "x": 0, "y": 42 },
          "easing": {
            "kind": "spring",
            "stiffness": 240,
            "damping": 20,
            "mass": 1.0,
            "initialVelocity": 0
          }
        },
        {
          "timeMs": 520,
          "value": { "x": 0, "y": 0 },
          "easing": "easeOut"
        }
      ]
    },
    {
      "property": "scale",
      "keyframes": [
        {
          "timeMs": 0,
          "value": 72,
          "easing": {
            "kind": "bounce",
            "amplitude": 0.2,
            "bounces": 3,
            "decay": 8.0
          }
        },
        {
          "timeMs": 440,
          "value": 100,
          "easing": "easeOut"
        }
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
- `spring`
- `bounce`
- `elastic`

Preferred advanced easing form:

```json
{
  "kind": "spring",
  "stiffness": 220,
  "damping": 18,
  "mass": 1.0,
  "initialVelocity": 0
}
```

Use object form when:

- the motion should feel intentionally springy
- the agent wants stable authored meaning
- the result should survive future parser changes more predictably

If an unsupported easing is supplied, the importer may warn and fall back to
`easeInOut`. Agents should therefore avoid vague or unofficial easing labels.

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
- `bounceIn`
- `riseIn`
- `slideIn`
- `blurRiseIn`
- `rotateIn`
- `elasticPop`
- `scaleIn`
- `scaleOut`
- `blurIn`
- `blurOut`
- `rotationSettle`
- `cinematicEntrance`
- `cinematicExit`

Use high-level blocks when:

- the agent cannot yet author explicit channels
- the user wants a quick first pass

Prefer explicit `channels` when:

- the user wants professional control
- bounce/elastic feel matters
- the user may retime or reshape keys by hand after import

Named professional families are allowed when the user asks for a direct effect.
The first supported families are:

- `bounceIn`: lowers into opacity, scale, and vertical position channels with
  canonical `bounce`
- `riseIn`: lowers into opacity, vertical position, and subtle scale channels
  with canonical `spring`
- `slideIn`: lowers into opacity and horizontal position channels with
  canonical `spring`
- `blurRiseIn`: lowers into opacity, blur, vertical position, and subtle scale
  channels with canonical `spring`
- `rotateIn`: lowers into opacity, rotation, and scale channels with canonical
  `spring`
- `elasticPop`: lowers into opacity and scale channels with canonical `elastic`

These families still create editable channels and keyframes. They are not
preview-only presets.

## Best Practice

Prefer `channels` when:

- the AI should create precise editable motion
- the user will retime or reshape keyframes manually after import
- the animation uses bounce, overshoot, or layered timing

## Practical Authoring Guidance For Agents

When writing scripts for the updated engine:

- do not assume that old hand-baked bounce scripts are the best path
- do use canonical interpolation objects for `spring`, `bounce`, and `elastic`
- do keep the number of keyframes modest and meaningful
- do combine `opacity` with `scale` or `position` for stronger entrances
- do write scripts so that imported lanes remain readable in the scoped
  timeline

Recommended first choices:

- headline pop: `opacity + scale`
- soft rise in: `opacity + position`
- elastic pop: `opacity + scale + slight position settle`
- letter or word reveal: `revealProgress` plus reveal metadata

## Current Limitation

As of this document update:

- canonical interpolation authoring is implemented
- Dart preview/runtime evaluation is implemented
- import normalization is implemented
- native export evaluation is implemented for spring/bounce/elastic
- first named professional families are implemented:
  - `bounceIn`
  - `riseIn`
  - `slideIn`
  - `blurRiseIn`
  - `rotateIn`
  - `elasticPop`

That means a generated script should now look better in scoped playback and
editing, and advanced interpolation can now travel through the native export
path. Use named effect families when the request is about a familiar direct
effect, and use explicit channels when the request needs custom choreography.

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

## Example: Named Bounce In Family

Use this when the user asks for a simple professional bounce entrance and does
not need custom choreography yet:

```json
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Professional Bounce In",
  "animationBlocks": [
    {
      "kind": "bounceIn",
      "startMs": 0,
      "durationMs": 760
    }
  ]
}
```

This imports as real editable channels for opacity, scale, and vertical
position.

## Example: Named Rise In Family

```json
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Soft Rise In",
  "animationBlocks": [
    {
      "kind": "riseIn",
      "startMs": 0,
      "durationMs": 680
    }
  ]
}
```

## Example: Named Slide In Family

```json
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Slide In",
  "animationBlocks": [
    {
      "kind": "slideIn",
      "startMs": 0,
      "durationMs": 720,
      "parameters": {
        "fromOffsetX": -180,
        "toOffsetX": 0
      }
    }
  ]
}
```

## Example: Named Blur Rise In Family

```json
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Cinematic Blur Rise In",
  "animationBlocks": [
    {
      "kind": "blurRiseIn",
      "startMs": 0,
      "durationMs": 760,
      "parameters": {
        "fromBlur": 18,
        "fromOffsetY": 44
      }
    }
  ]
}
```

## Example: Named Rotate In Family

```json
{
  "schemaVersion": "refusion.scope-text-script/v1",
  "name": "Rotate In",
  "animationBlocks": [
    {
      "kind": "rotateIn",
      "startMs": 0,
      "durationMs": 720,
      "parameters": {
        "fromRotation": -12,
        "fromScale": 88
      }
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
