# Professional Motion Text Modify v1

This document defines the current supported modify workflow for text clips
inside `InGeneBMFPro`.

Use this as the source of truth when asking any agent to reason about editing an
existing text preset after it has been inserted on the timeline.

## Supported Modify Entry Points

- double tap a text clip in the timeline
- double tap the selected text directly on the canvas

Both entry points open the same edit tray.

The tray must stay inside the lower editor pane only and must never overlay the
preview canvas.

## Supported Modify Controls In v1

These controls are supported now:

- text content
- font size
- preset-exposed scalar parameters from the active text preset

Examples of preset-exposed parameters already used by the built-in presets:

- `blurStrength`
- `spacingAmount`

## Supported Canvas Interactions In v1

These interactions are supported now:

- tap text on canvas to select it
- drag the selected text to move it
- drag a corner handle to resize it uniformly

The resize interaction changes `text.fontSize`.

The move interaction changes:

- `transform.position.x`
- `transform.position.y`

## Current Architectural Rules

- The timeline is a derived view only.
- The selected text element uses the same ID as the text clip in the generated
  text track.
- Canvas chrome is tied to edit mode only.
- The selection rectangle and resize handles must be visible only while the edit
  tray is open.
- Text content and element style changes are persisted into `MotionProjectModel`.
- Preset parameter edits are persisted into `MotionTextAnimationBindingModel`.
- The render overlay stays render-only.
- Interactive selection and transform behavior must live in a separate overlay
  above the render layer.
- Edit controls should be compact: short labels, thin borders, minimal helper
  copy, and thin slider styling.

## What Is Intentionally Deferred

These items are intentionally not part of v1 yet:

- font family selection
- animation speed multiplier editing
- rotation handle
- multi-select
- stroke and fill styling controls

Reason:

- font family is not modeled in the current motion property pipeline yet
- animation speed needs a dedicated binding-level timing strategy, not a quick UI
  hack
- stroke and fill need real render/domain support before exposing UI

## Safe Agent Guidance

When an agent modifies an existing text clip, it should only assume these
editable fields are guaranteed:

- `text`
- `text.fontSize`
- `transform.position.x`
- `transform.position.y`
- preset scalar parameters already declared by the preset definition

An agent must not assume support for:

- font family
- arbitrary color systems
- stroke width
- fill/stroke toggles
- animation speed override

until those features are added to the domain and render pipelines.
