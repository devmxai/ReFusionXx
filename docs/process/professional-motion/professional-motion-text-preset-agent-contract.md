# Professional Motion Text Preset Agent Contract

This document is the practical contract for any agent or person generating
custom text presets for the current app import flow.

It reflects the current parser and UI import path in:

- `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/text_preset_bottom_sheet.dart`
- `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_text_preset_serialization.dart`
- `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_text_runtime_helpers.dart`

## Executive Rule

Agents should prefer the simplified `motion-only preset JSON` format.

Do not force the agent to manually generate:

- `id`
- `kind`
- `label`
- `defaultText`

unless there is a real reason to override them.

The app now auto-generates those fields when they are omitted.

## Recommended Input Shape

Minimal recommended shape:

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

This is the safest format for agents.

## What The App Auto-Generates

If omitted, the app generates:

- `id`
  - generated automatically from label/text plus timestamp
- `kind`
  - defaults to `custom`
- `label`
  - derived from `label`, then `name`, then `title`, then `text`, then first motion kind
- `defaultText`
  - derived from `defaultText`, then `text`, then `content`, else `Your Text`
- animation block `id`
  - generated as `<kind>_<startMs>` if omitted

## Accepted Root Aliases

The parser accepts these aliases:

- `animationBlocks`
- `motions`
- `blocks`

Recommended canonical key:

- `animationBlocks`

## Accepted Time Aliases

Inside each animation block, the parser accepts:

- `startMs` or `start`
- `durationMs` or `duration`
- `endMs` or `end`

Each block must still resolve to:

- a valid start time
- a valid end time
- `end > start`

## Hard Requirements

The minimum valid preset import still requires:

1. one JSON object
2. one non-empty motion block array
3. every motion block must contain:
   - `kind`
   - `startMs` or `start`
   - `durationMs` or `duration`, or `endMs` or `end`

## Supported Motion Kinds

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

## Supported Interpolation Kinds

- `hold`
- `linear`
- `easeIn`
- `easeOut`
- `easeInOut`
- `cubicBezier`
- `spring`
- `bounce`
- `elastic`

Note:

- `bounce` and `elastic` are schema-accepted
- current runtime still treats them simply
- do not assume physically accurate motion from them yet

## Supported Per-Block Parameters

### `fadeIn`

- no required parameters

### `fadeOut`

- no required parameters

### `wordReveal`

- no required parameters
- optional `revealSpec` is accepted

### `letterReveal`

- no required parameters
- optional `revealSpec` is accepted

### `typewriter`

- no required parameters
- optional `revealSpec` is accepted

### `scaleIn`

- `fromScale`
- `toScale`

### `elasticPop`

- `fromScale`
- `toScale`

### `scaleOut`

- `fromScale`
- `toScale`

### `blurIn`

- `fromBlur`
- `toBlur`
- optional preset-level fallback parameter: `blurStrength`

### `blurOut`

- `fromBlur`
- `toBlur`
- optional preset-level fallback parameter: `blurStrength`

### `rotationSettle`

- `fromRotation`
- `toRotation`
- `fromLetterSpacing`
- `toLetterSpacing`
- optional preset-level fallback parameter: `spacingAmount`

### `cinematicEntrance`

- `fromScale`
- `toScale`
- `fromOpacity`
- `toOpacity`

### `cinematicExit`

- `fromOpacity`
- `toOpacity`

## Optional `revealSpec`

Accepted shape:

```json
{
  "unit": "word",
  "staggerMs": 40
}
```

Accepted `unit` values:

- `wholeText`
- `word`
- `letter`

Note:

- the parser accepts `revealSpec`
- current visible behavior is still driven mainly by the animation kind
- use it only when needed

## Optional `staticProperties`

If used, each item must contain:

- `propertyId`
- `value`

Supported `propertyId` values:

- `transform.position.x`
- `transform.position.y`
- `transform.scale.x`
- `transform.scale.y`
- `transform.rotation.degrees`
- `visual.opacity`
- `visual.blur.amount`
- `text.fontSize`
- `text.letterSpacing`
- `text.revealProgress`
- `shape.width`
- `shape.height`
- `shape.cornerRadius`

## Safe Value Ranges

These are recommended ranges, not strict parser limits.

### Time

- recommended block duration: `150` to `2000`
- time unit: milliseconds
- hard rule: `end > start`

### Scale

- recommended: `0.6` to `1.4`

### Opacity

- recommended: `0.0` to `1.0`

### Blur

- recommended: `0` to `32`

### Rotation

- recommended: `-12` to `12`

### Letter Spacing

- recommended: `0` to `30`

## Parser Tolerance Added For Agents

The parser now also tolerates:

- Markdown fenced JSON blocks such as ```json ... ```
- nested JSON strings for:
  - `animationBlocks`
  - `motions`
  - `blocks`
  - `parameters`
  - `staticProperties`

This is a compatibility layer only.

Agents should still prefer raw clean JSON.

## Valid Example

```json
{
  "text": "Fusion Title",
  "animationBlocks": [
    {
      "kind": "blurIn",
      "startMs": 0,
      "durationMs": 400,
      "interpolation": "easeOut",
      "parameters": {
        "fromBlur": 18,
        "toBlur": 0
      }
    },
    {
      "kind": "scaleIn",
      "startMs": 0,
      "durationMs": 800,
      "interpolation": "easeOut",
      "parameters": {
        "fromScale": 1.08,
        "toScale": 1.0
      }
    }
  ]
}
```

## Invalid Example

This is invalid:

```json
{
  "text": "Fusion Title",
  "animationBlocks": "[{\"kind\":\"blurIn\",\"startMs\":0,\"durationMs\":400}]"
}
```

Why invalid in the strict sense:

- `animationBlocks` is encoded as a string instead of a real array

Why it may still import now:

- the parser has a compatibility attempt for nested JSON strings

Why agents should still avoid it:

- it is fragile
- it is harder to debug
- it becomes unreadable quickly

## Required Prompt Pattern For Any Agent

Use this instruction pattern:

```text
Return one raw motion-only preset JSON object for InGeneBMFPro.
Do not return Markdown.
Do not return explanations.
Use the minimal app-friendly shape:
{"text":"Your Text","animationBlocks":[{"kind":"fadeIn","startMs":0,"durationMs":700}]}
Keep animationBlocks as a real JSON array, not a string.
Use only supported motion kinds.
If parameters are needed, put them inside the block.parameters object.
Return only the final JSON object.
```

## Diagnostic Note About The Reported Screenshot

If the app shows the old helper text:

- `Paste a preset JSON object. It will appear as a new card inside Text Presets.`

then the visible screen is from an older build than the current source tree.

The current source tree now shows:

- support for simplified motion-only JSON
- a helper note that the app auto-generates `id`, `kind`, `label`, and `defaultText`
- a minimal example directly inside the sheet
