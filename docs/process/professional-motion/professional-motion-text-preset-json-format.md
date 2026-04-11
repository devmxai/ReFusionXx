# Professional Motion Text Preset JSON Format

This is the first supported custom text preset format for the Professional Motion text preset pipeline.

## Current input mode

- Current UI input mode: `paste JSON`
- Future file mode: `.fxtextpreset.json`
- The file payload should be the same JSON object shown below

## Required top-level fields

- `id`
- `kind`
- `label`
- `defaultText`
- `animationBlocks`

## Optional top-level fields

- `description`
- `parameters`
- `staticProperties`

## Supported animation kinds right now

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

## Supported interpolation kinds right now

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
- `bounce` and `elastic` are accepted by the schema now
- current runtime still evaluates them with simple progress behavior
- they are accepted for forward compatibility, not as full physical motion yet

## Supported static property ids right now

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

## Example

```json
{
  "id": "custom.cinematic_soft",
  "kind": "custom",
  "label": "Cinematic Soft",
  "defaultText": "CINEMATIC",
  "description": "Soft cinematic text entrance.",
  "parameters": [
    {
      "id": "blurStrength",
      "label": "Blur Strength",
      "default": 16,
      "min": 0,
      "max": 64
    }
  ],
  "animationBlocks": [
    {
      "id": "intro.fade",
      "kind": "fadeIn",
      "startMs": 0,
      "endMs": 320,
      "interpolation": "easeOut"
    },
    {
      "id": "intro.blur",
      "kind": "blurIn",
      "startMs": 0,
      "endMs": 700,
      "interpolation": "easeOut",
      "parameters": {
        "fromBlur": 16,
        "toBlur": 0
      }
    },
    {
      "id": "intro.scale",
      "kind": "scaleIn",
      "startMs": 0,
      "endMs": 820,
      "interpolation": "easeOut",
      "parameters": {
        "fromScale": 1.12,
        "toScale": 1.0
      }
    }
  ]
}
```
