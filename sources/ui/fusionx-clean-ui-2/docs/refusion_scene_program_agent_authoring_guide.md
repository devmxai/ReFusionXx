# ReFusion Scene Program Agent Authoring Guide

Status: official agent-facing authoring guide
Schemas: `refusion.motion-director/v1` + `refusion.scene-program/v1`
Core pack: `refusion.core-design-pack/v1`
Purpose: give any coding or design agent enough rules to generate editable ReFusion motion scenes that import cleanly into the app.

## Non-Negotiable Output Rules

Return JSON only.

Do not return JSX, JavaScript, TypeScript, HTML, CSS, Markdown wrappers, comments, imports, executable code, shader source, or URLs that must execute code.

Return the complete object from the first `{` through the final `}`. A partial
object or a copied middle fragment will be rejected as incomplete JSON and
cannot be repaired safely by the app.

Preferred live-agent output is a Director-first wrapper:

```json
{
  "directorPlan": {
    "schemaVersion": "refusion.motion-director/v1",
    "name": "Readable Plan Name",
    "durationMs": 3200,
    "frameRate": 30,
    "canvasWidth": 1080,
    "canvasHeight": 1920,
    "beats": [],
    "components": [],
    "primitives": []
  },
  "sceneProgram": {
    "schemaVersion": "refusion.scene-program/v1",
    "name": "Readable Scene Name",
    "durationMs": 3200,
    "frameRate": 30,
    "layers": []
  }
}
```

Legacy pasted JSON may use a direct Scene Program root, but live generation
should return the wrapper above. The app imports and lints `directorPlan` before
accepting the executable `sceneProgram`.

`directorPlan` is the choreography source of truth. If a live model returns a
valid `directorPlan` but the paired `sceneProgram` does not implement it,
ReFusion may compile the Director Plan locally and ignore the mismatched
generated Scene Program. To preserve your exact visual intent, make the
`sceneProgram` represent every Director component and primitive directly.

The executable scene itself must remain declarative:

```json
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Readable Scene Name",
  "durationMs": 3200,
  "frameRate": 30,
  "layers": []
}
```

The generated file must be editable after import. Any motion must be represented as layers, elements, property channels, keyframes, and easing.

## Director-First Workflow

Do not jump straight from a prompt to random keyframes.

Before writing the final Scene Program JSON, explicitly plan:

1. **Beats**: ordered time blocks with clear intent.
2. **Semantic components**: prompt shell, typed text, send button, reveal circle,
   background, title, icon, image, etc.
3. **Primitives**: one intentional motion per component inside one beat.
4. **Compilation**: convert the primitives into real layers, elements, channels,
   and keyframes.

Professional timing example:

```text
0-520ms     Prompt shell enters
520-1900ms  Text types on with typewriterProgress 0 -> 1
1900-2140ms Send button press
2300-4200ms Circle expands and covers the screen
```

Every primitive must stay inside its owning beat. Beats may overlap only when
their `componentRefs` are explicit and disjoint, such as a background settling
while a prompt shell enters. If two motions affect the same component at the
same time, express them inside one intentional beat with several primitives.
One narrow handoff exception is allowed: two overlapping beats may share a
component only when the overlapping primitives animate disjoint property groups,
such as `scale` ending while `width` begins. If both beats animate the same
property group, such as two `scale` motions, combine them into one beat.

The returned `directorPlan` must include:

- `beats`: ordered time blocks with `id`, `label`, `startMs`, `endMs`,
  `intent`, and `componentRefs`;
- `components`: semantic targets with `id`, `role`, and `label`;
- `primitives`: motion intentions with `id`, `beatId`, `targetComponentId`,
  `kind`, `startMs`, `endMs`, optional `property`, `fromValue`, `toValue`, and
  `easing`.

Typewriter text must be one complete text element with one
`typewriterProgress` channel. Its Director primitive should declare
`property: "typewriterProgress"`, `fromValue: 0.0`, and `toValue: 1.0`.
Never create one layer or element per character.

Every Director component must be represented by a real Scene Program layer or
element. Use stable IDs when possible, for example `background`, `promptShell`,
`promptText`, `sendButton`, and `coverCircle`. Background/canvas components may
also be represented with clear aliases such as `bg-layer`, `bg-solid`,
`canvas-fill`, or `backdrop`, but any primitive such as `fade` still requires a
real animated channel such as `opacity`; a static `properties.opacity` value is
not enough to satisfy a fade primitive.

## Coordinate System

Default composition size is portrait `1080 x 1920`.

Positions use a center-origin canvas:

- `x: 0, y: 0` is the center of the composition.
- Negative `x` moves left, positive `x` moves right.
- Negative `y` moves up, positive `y` moves down.

Use this mental model:

```text
top left     x=-540 y=-960
center       x=0    y=0
bottom right x=540  y=960
```

## Supported Layer And Element Kinds

Use these layer kinds:

- `shape`
- `text`
- `image`

Use these element kinds:

- `shape`
- `solid`
- `text`
- `image`
- `icon`

`icon` is lowered into an editable generated shape with an `asset.icon` property from the ReFusion Core Pack.

## Supported Shape Primitives

Use:

- `rectangle`
- `roundedRectangle`
- `circle`
- `line`

Example:

```json
{
  "id": "card-bg",
  "kind": "shape",
  "properties": {
    "shapeKind": "roundedRectangle",
    "width": 840,
    "height": 280,
    "cornerRadius": 42,
    "color": "#171923",
    "opacity": 1
  }
}
```

## ReFusion Core Pack Icons

The app includes a small offline icon pack. Prefer these exact names:

```text
arrow-down, arrow-left, arrow-right, arrow-up,
bookmark, camera, check, chevron-left, chevron-right, close,
comment, crop, heart, image, lock, mic, music, paperclip,
pause, play, plus, search, send, settings, share, sparkles,
text, user, verified, video, volume
```

Accepted aliases:

```text
attach -> paperclip
attachment -> paperclip
microphone -> mic
voice -> mic
submit -> send
profile -> user
verification -> verified
favorite -> heart
chat -> comment
done -> check
add -> plus
```

Icon example:

```json
{
  "id": "send-icon",
  "kind": "icon",
  "properties": {
    "icon": "send",
    "width": 48,
    "height": 48,
    "color": "#FFFFFF",
    "position": { "x": 360, "y": 0 },
    "opacity": 1
  }
}
```

## Supported Properties

For shape and icon elements:

- `position`: `{ "x": 0, "y": 0 }`
- `positionX`
- `positionY`
- `scale`: number or `{ "x": 1, "y": 1 }`
- `scaleX`
- `scaleY`
- `rotation`
- `opacity`: `0..1`
- `blur`
- `color`: `"#RRGGBB"` or `"#AARRGGBB"`
- `width`
- `height`
- `cornerRadius`
- `icon` for `kind: "icon"`

Accepted aliases for agent convenience:

- `backgroundColor`, `bgColor`, `fillColor` -> `color`
- `size`, `iconSize`, `shapeSize` -> `width` + `height`
- `radius`, `borderRadius` -> `cornerRadius`

For text elements:

- `text`
- `position`
- `scale`
- `rotation`
- `opacity`
- `blur`
- `color`
- `fontSize`
- `fontWeight`: integer weight such as `400`, `700`, or `900`
- `fontFamily`: optional static font family name
- `fontStyle`: `normal` or `italic`
- `lineHeight`: text line-height multiplier, usually `1.0..1.3`
- `textAlign`: `left`, `center`, or `right`
- `letterSpacing`
- `reveal`: `0..1`

Use a consistent typography block for words that belong to the same title.
For example, do not make `Welcome` huge, `to` tiny, and `Codex` heavy unless
the user explicitly asked for that contrast. Vary the motion, not the basic
typographic system.

Accepted typing aliases:

- `typewriter`
- `typewriterProgress`
- `typing`
- `typingProgress`
- `letterReveal`
- `letterRevealProgress`
- `wordReveal`
- `wordRevealProgress`

These aliases are lowered to the same editable `reveal` channel. `typewriter`,
`typing`, and `letterReveal` create a letter-by-letter text binding. `wordReveal`
creates a word-by-word text binding.

For a keyboard/type-on effect, always animate reveal forward:

```json
{
  "property": "typewriterProgress",
  "keyframes": [
    { "timeMs": 0, "value": 0.0, "easing": "linear" },
    { "timeMs": 1400, "value": 1.0, "easing": "linear" }
  ]
}
```

Do not use `1.0 -> 0.0` unless you intentionally want a delete/backspace
effect where the visible text disappears over time.

Do not create one text element per character such as `char-h`, `char-e`,
`char-l`. That is not the professional ReFusion typewriter path and it creates
unnecessary timeline content. Use one text element with the complete string and
one `typewriterProgress` channel. ReFusion can compact simple
character-by-character scripts into one typewriter element, but agents should
author the clean form directly.

## Supported Channels

Every animated property is declared as a channel:

```json
{
  "property": "position",
  "keyframes": [
    { "timeMs": 0, "value": { "x": 0, "y": 120 }, "easing": "easeOut" },
    { "timeMs": 700, "value": { "x": 0, "y": 0 }, "easing": "spring" }
  ]
}
```

### Keyframe Time Rules

Layer timing fields must use canonical numeric JSON values:

```json
{ "startMs": 0, "durationMs": 2400 }
```

Do not write timing as strings such as `"startMs": "0"`, and do not prefer
aliases such as `start`, `startTimeMs`, or `duration`. ReFusion can repair
simple timing aliases and numeric strings with warnings, but professional
agent output should use `startMs` and `durationMs`.

By default, channel keyframes use **local layer time**:

- a layer with `startMs: 1800` and `durationMs: 800` accepts local keyframes from `0` to `800`;
- the app places those keyframes at project time `1800` to `2600`.
- every keyframe inside that layer or its elements must fit inside the layer's
  timeline range.

If you prefer writing absolute project/scene times, set:

```json
{
  "property": "opacity",
  "timeBasis": "project",
  "keyframes": [
    { "timeMs": 1800, "value": 0.0, "easing": "linear" },
    { "timeMs": 2400, "value": 1.0, "easing": "easeOut" }
  ]
}
```

Recommended for agents: use local time for simple scenes, or explicitly set
`"timeBasis": "project"` when staggering many layers on one global timeline.
Do not mix local and project times inside the same channel.

Layer `durationMs` must cover the latest keyframe in that layer:

- local-time layer example: if the latest keyframe is `timeMs: 4200`, the layer
  must have at least `"durationMs": 4200`;
- project-time layer example: if the layer starts at `startMs: 1000` and its
  latest project keyframe is `timeMs: 4200`, the layer must have at least
  `"durationMs": 3200`;
- keyframes must never be outside the scene `durationMs`.

ReFusion can repair a too-short layer duration when all keyframes are still
inside the scene, but this creates warnings. Prefer writing the correct
`durationMs` in the JSON.

Keyframes should be sorted by ascending `timeMs`. ReFusion can normalize
out-of-order keyframes during import, but sorted keyframes are preferred so the
script stays readable and warnings stay minimal.

Supported easing names:

- `linear`
- `easeIn`
- `easeOut`
- `easeInOut`
- `spring`

Use `spring` sparingly for a natural stop. Use `linear` for typing/reveal timing.

## Component Recipes

These are not separate executable components. They are recommended compositions made from primitives.

### Prompt Input Bar

Use:

- one rounded rectangle shell,
- `plus` or `paperclip` icon on the left,
- text with `reveal` channel for typing,
- `mic` icon near the right,
- white circular `send` button with black `send` icon.

### Social Post Header

Use:

- `circle` avatar,
- username text,
- `verified` icon,
- optional `settings` or `close` icon.

### Social Action Row

Use icons:

- `heart`
- `comment`
- `share`
- `bookmark`

## Quality Rules For Agents

Keep scenes clean:

- Prefer 3-8 layers for a small motion graphic.
- Use stable IDs: `prompt-shell`, `send-icon`, `title-text`.
- Use one visual purpose per layer.
- Use `durationMs` between 2000 and 6000 for demos.
- Do not animate everything at once; stagger motion by 80-300 ms.
- Use high contrast.
- Avoid tiny icon sizes under 36 px on 1080 x 1920.
- Keep text inside the canvas.
- For professional UI mockups, use rounded rectangles, generous padding, and restrained colors.

## Example: Prompt Input Typing Banner

```json
{
  "schemaVersion": "refusion.scene-program/v1",
  "name": "Prompt Input Typing Banner",
  "durationMs": 3200,
  "frameRate": 30,
  "layers": [
    {
      "id": "bg-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 3200,
      "elements": [
        {
          "id": "bg",
          "kind": "shape",
          "properties": {
            "shapeKind": "rectangle",
            "width": 1080,
            "height": 1920,
            "color": "#090A0F",
            "opacity": 1
          }
        }
      ]
    },
    {
      "id": "input-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 3200,
      "elements": [
        {
          "id": "input-shell",
          "kind": "shape",
          "properties": {
            "shapeKind": "roundedRectangle",
            "width": 900,
            "height": 132,
            "cornerRadius": 54,
            "color": "#191B24",
            "opacity": 1
          }
        }
      ]
    },
    {
      "id": "left-icon-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 3200,
      "elements": [
        {
          "id": "attach-icon",
          "kind": "icon",
          "properties": {
            "icon": "plus",
            "width": 54,
            "height": 54,
            "color": "#DDE2F2",
            "position": { "x": -360, "y": 0 }
          }
        }
      ]
    },
    {
      "id": "typing-layer",
      "kind": "text",
      "startMs": 0,
      "durationMs": 3200,
      "elements": [
        {
          "id": "typing-text",
          "kind": "text",
          "text": "hello world",
          "properties": {
            "fontSize": 58,
            "color": "#FFFFFF",
            "position": { "x": -74, "y": 2 },
            "opacity": 1,
            "reveal": 0
          },
          "channels": [
            {
              "property": "reveal",
              "keyframes": [
                { "timeMs": 620, "value": 0.0, "easing": "linear" },
                { "timeMs": 2050, "value": 1.0, "easing": "linear" }
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "right-icons-layer",
      "kind": "shape",
      "startMs": 0,
      "durationMs": 3200,
      "elements": [
        {
          "id": "mic-icon",
          "kind": "icon",
          "properties": {
            "icon": "mic",
            "width": 48,
            "height": 48,
            "color": "#DDE2F2",
            "position": { "x": 258, "y": 0 }
          }
        },
        {
          "id": "send-bg",
          "kind": "shape",
          "properties": {
            "shapeKind": "circle",
            "width": 76,
            "height": 76,
            "color": "#FFFFFF",
            "position": { "x": 364, "y": 0 },
            "opacity": 1
          }
        },
        {
          "id": "send-icon",
          "kind": "icon",
          "properties": {
            "icon": "send",
            "width": 42,
            "height": 42,
            "color": "#090A0F",
            "position": { "x": 364, "y": 0 }
          }
        }
      ]
    }
  ]
}
```

## What To Return To The User

When asked to generate a ReFusion scene, return:

1. valid JSON only, preferably `{"directorPlan": {...}, "sceneProgram": {...}}`,
2. no Markdown code fence unless explicitly requested,
3. no explanatory prose inside the JSON,
4. IDs and names that describe the design,
5. only supported properties and icons from this guide.
