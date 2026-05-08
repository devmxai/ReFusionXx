# ReFusion Coordinate System Canon

Status: mandatory canonical reference  
Scope: SceneProgram, semantic blueprint compilation, HCT evaluation, visual QA,
pre-render gate, preview overlays, diagnostics, and related tests.

## 1. Canonical Space

ReFusion scene authoring and evaluation use:

```text
SceneCoordinateSpace.centerOriginV1
```

Definition:

- origin: center of the canvas
- positive X: right
- positive Y: down
- unit: design pixels
- `position.x` / `position.y`: element center coordinates unless a component
  contract explicitly overrides anchor behavior

Top-left coordinates are display-space derivatives, not authoring truth.

## 2. Canvas Profiles

Common canvases:

- Story 9:16: `1080 x 1920`
- Landscape 16:9: `1920 x 1080`
- Square 1:1: `1080 x 1080`
- Portrait 4:5: `1080 x 1350`

For a canvas `(W,H)`:

```text
centerX = W / 2
centerY = H / 2
```

## 3. Point Conversion

Center-origin point `(x,y)` to viewport/top-left point `(left,top)`:

```text
left = centerX + x
top  = centerY + y
```

Viewport/top-left point `(left,top)` to center-origin point `(x,y)`:

```text
x = left - centerX
y = top  - centerY
```

Examples on `1080 x 1920`:

- center `(0,0)` -> viewport `(540,960)`
- center `(-540,-960)` -> viewport `(0,0)`
- center `(452,640)` -> viewport `(992,1600)`

## 4. Rect Conversion

For center-origin rect:

```text
RectC(centerX, centerY, width, height)
```

Viewport/top-left rect:

```text
RectV(left, top, width, height)
```

Conversions:

```text
RectV.left = (canvas.centerX + RectC.centerX) - RectC.width / 2
RectV.top  = (canvas.centerY + RectC.centerY) - RectC.height / 2

RectC.centerX = (RectV.left + RectV.width / 2) - canvas.centerX
RectC.centerY = (RectV.top  + RectV.height / 2) - canvas.centerY
```

## 5. Containment Rules

Containment checks should run in one explicit space per comparison.

Preferred in engine/domain:

```text
center-origin rect containment
```

Allowed for UI overlay:

```text
viewport rect containment derived from center-origin
```

Do not compare a center rect against a viewport rect without explicit
conversion.

## 6. Enforcement Rules

1. Validators must not invent implicit top-left root geometry for authoring
   values.
2. Visual QA, pre-render gate, and preview overlays must consume bounds from
   the same evaluated frame truth pipeline.
3. Any new code that handles scene position/bounds must use typed conversion
   helpers from `scene_coordinate_system.dart`.
4. Mixed-space math is a correctness bug, not a warning.

## 7. Migration Rule

If a legacy scene uses top-left semantics in numeric values:

1. detect legacy coordinate contract explicitly;
2. convert once to canonical center-origin values;
3. mark scene metadata with migration source and version;
4. persist canonical values in the new authoritative path.

Do not run dual coordinate systems indefinitely.
