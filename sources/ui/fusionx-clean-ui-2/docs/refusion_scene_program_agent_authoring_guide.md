# ReFusion Scene Program Agent Authoring Guide

Status: official agent-facing authoring guide  
Schema: `refusion.scene-program/v1`  
Core pack: `refusion.core-design-pack/v1`  
Purpose: give any coding or design agent enough rules to generate editable ReFusion motion scenes that import cleanly into the app.

## Non-Negotiable Output Rules

Return JSON only.

Do not return JSX, JavaScript, TypeScript, HTML, CSS, Markdown wrappers, comments, imports, executable code, shader source, or URLs that must execute code.

Every scene must be declarative:

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

For text elements:

- `text`
- `position`
- `scale`
- `rotation`
- `opacity`
- `blur`
- `color`
- `fontSize`
- `letterSpacing`
- `reveal`: `0..1`

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

By default, channel keyframes use **local layer time**:

- a layer with `startMs: 1800` and `durationMs: 800` accepts local keyframes from `0` to `800`;
- the app places those keyframes at project time `1800` to `2600`.

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

1. valid JSON only,
2. no Markdown code fence unless explicitly requested,
3. no explanatory prose inside the JSON,
4. IDs and names that describe the design,
5. only supported properties and icons from this guide.
