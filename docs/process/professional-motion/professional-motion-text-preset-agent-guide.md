# Professional Motion Text Preset Agent Guide

This document defines the exact JSON shapes that `InGeneBMFPro` accepts for
custom text presets.

Use this guide when asking any agent or model to generate a text preset for the
app.

## Primary Goal

The safest generation mode is:

- the agent generates only `motion-only JSON`
- the app auto-generates required preset identity fields
- the agent focuses only on:
  - displayed text
  - motion blocks
  - timing
  - optional motion parameters

## Best Input Mode

Preferred minimal shape:

```json
{
  "text": "Your Text Here",
  "animationBlocks": [
    {
      "kind": "fadeIn",
      "startMs": 0,
      "durationMs": 700
    }
  ]
}
```

## Auto-Generated Fields

If omitted, the app generates these automatically:

- `id`
- `kind`
- `label`
- `defaultText`
- `animationBlocks[].id`

Generation rules:

- root `kind` defaults to `custom`
- root `defaultText` is taken from `text`, `defaultText`, or `content`
- root `label` is generated from text when missing
- root `id` is generated from the label and timestamp when missing
- block `id` is generated from motion kind and start time when missing

## Accepted Root Aliases

The app accepts these root text fields:

- `text`
- `defaultText`
- `content`

The app accepts these motion array fields:

- `animationBlocks`
- `blocks`
- `motions`

## Accepted Block Time Aliases

The app accepts:

- `startMs` or `start`
- `durationMs` or `duration`
- `endMs` or `end`

Rules:

- each block must have `kind`
- each block must have `startMs` or `start`
- each block must have either:
  - `durationMs` / `duration`
  - or `endMs` / `end`
- resolved end time must be greater than start time

## Supported Motion Kinds

Only these kinds are supported:

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

## Supported Interpolation Values

Only these interpolation values are accepted:

- `hold`
- `linear`
- `easeIn`
- `easeOut`
- `easeInOut`
- `cubicBezier`
- `spring`
- `bounce`
- `elastic`

## Optional Block Parameters By Motion Kind

`scaleIn`, `elasticPop`, `scaleOut`

- `fromScale`
- `toScale`

`blurIn`, `blurOut`

- `fromBlur`
- `toBlur`

`rotationSettle`

- `fromRotation`
- `toRotation`
- `fromLetterSpacing`
- `toLetterSpacing`

`cinematicEntrance`

- `fromScale`
- `toScale`
- `fromOpacity`
- `toOpacity`

`cinematicExit`

- `fromOpacity`
- `toOpacity`

## Reveal Spec

These motion kinds may also use `revealSpec`:

- `wordReveal`
- `letterReveal`
- `typewriter`

Shape:

```json
{
  "revealSpec": {
    "unit": "letter",
    "staggerMs": 42
  }
}
```

Allowed `unit` values:

- `wholeText`
- `word`
- `letter`

## Practical Safe Ranges

The parser itself is flexible, but these are the recommended safe ranges:

- `startMs`: `>= 0`
- `durationMs`: `150` to `2000`
- `opacity`: `0` to `1`
- `scale`: `0.6` to `1.4`
- `blur`: `0` to `32`
- `rotation`: `-12` to `12`
- `letterSpacing`: `0` to `30`

## Valid Examples

### Minimal Fade In

```json
{
  "text": "Hello Motion",
  "animationBlocks": [
    {
      "kind": "fadeIn",
      "startMs": 0,
      "durationMs": 500,
      "interpolation": "easeOut"
    }
  ]
}
```

### Simple Cinematic Intro

```json
{
  "text": "Fusion Text",
  "animationBlocks": [
    {
      "kind": "blurIn",
      "startMs": 0,
      "durationMs": 400,
      "interpolation": "easeOut"
    },
    {
      "kind": "scaleIn",
      "startMs": 0,
      "durationMs": 800,
      "interpolation": "easeOut",
      "parameters": {
        "fromScale": 1.5,
        "toScale": 1.0
      }
    },
    {
      "kind": "fadeOut",
      "startMs": 800,
      "durationMs": 500,
      "interpolation": "easeIn"
    }
  ]
}
```

### Typewriter

```json
{
  "text": "Review this now",
  "animationBlocks": [
    {
      "kind": "typewriter",
      "startMs": 0,
      "durationMs": 1400,
      "interpolation": "linear",
      "revealSpec": {
        "unit": "letter",
        "staggerMs": 42
      }
    }
  ]
}
```

## Invalid Inputs

These will fail or should be avoided:

- non-JSON text
- markdown code fences
- explanations before or after the JSON
- unsupported motion kinds
- empty `animationBlocks`
- block without `kind`
- block without time fields
- `endMs <= startMs`

## Recommended Prompt For Any Agent

```text
Return one raw motion-only JSON object for InGeneBMFPro text preset import.
Do not include explanation, Markdown, code fences, or comments.
Use this minimal schema:
{
  "text": "Your Text Here",
  "animationBlocks": [
    {
      "kind": "fadeIn",
      "startMs": 0,
      "durationMs": 700
    }
  ]
}
Use only supported motion kinds and valid timing fields.
Do not include id, label, kind, or defaultText unless explicitly requested.
```

## Final Rule

When possible, keep generation in `motion-only JSON` mode.

That gives the lowest error rate and keeps the agent focused on motion rather
than preset identity boilerplate.
