# Blur architecture

How KWin background blur works in Caelestia, and how to add it to a new panel.

---

## Overview

Caelestia uses KWin's native background-blur effect, exposed through Quickshell's
`BackgroundEffect.blurRegion`. Rather than blurring the whole layer-shell window, it
registers a set of **Wayland surface regions** that KWin blurs behind. Every panel that
wants blur must register its on-screen rectangle in that region, and keep it in sync as
the panel moves or resizes.

`BlurMask` (in `shell/modules/drawers/blur/`) is the component that owns this
responsibility for a single panel. It lives in `ContentWindow`'s region tree.

---

## Components

### `BackgroundEffect.blurRegion` (`ContentWindow.qml`)

The root `StyledWindow` sets `BackgroundEffect.blurRegion` to a combined `Region`
tree. This is the single Wayland protocol surface sent to KWin. Everything else is
additive.

```qml
BackgroundEffect.blurRegion: Region {
    // static baseline + bar strips + border-rounding corners …
    BlurMask { target: bar; … }
    BlurMask { target: panels.launcher; … }
    BlurMask { target: panels.notifications; … }
    …
}
```

### `BlurMask` (`shell/modules/drawers/blur/BlurMask.qml`)

A `Region` subtype that wraps three helpers:

| Helper | Job |
|---|---|
| `BlurOffsets` | Computes the panel's on-screen rect, accounting for `blurOffset*` and the deform matrix |
| `BlurBodies` | Emits the main rectangular region |
| `BlurCorners` | Emits per-corner rounded-rect mask regions when `blurMask` is enabled |

**Required properties:**

| Property | Source |
|---|---|
| `target` | The `Item` to blur behind (set to `null` when hidden) |
| `contentItem` | `root.contentItem` — the layer shell's surface item |
| `blurOffsetTop/Bottom/Left/Right` | `root.blurOffset*` — per-edge crop for the bar border |

**Optional properties** (pulled from `target` automatically if present):

| Property | Default | Usage |
|---|---|---|
| `vAnchor` | `"bottom"` | `"top"`, `"bottom"`, or `"both"` |
| `hAnchor` | `"right"` | `"left"`, `"right"`, or `"both"` |
| `offsetScale` | `0` | Fraction of the panel's slide-in animation offset already applied |
| `deformMatrix` | identity | Transform applied by a `BlobRect` background shape |

Setting `target: null` when the panel is closed is important — it collapses the
region to zero so KWin stops blurring that area immediately.

---

## How to add blur to a new panel

### 1. Expose the panel item

`BlurMask.target` must be the concrete `Item` whose on-screen bounds KWin blurs.
If that item is internal to a component, expose it via a `readonly property alias`.

```qml
// MyPanel.qml
Item {
    id: root
    readonly property alias panelItem: card   // ← expose the inner rect

    Rectangle {
        id: card
        // … panel visuals …
    }
}
```

This mirrors the pattern `Controls.Menu` uses for `backgroundItem`.

### 2. Register a `BlurMask` in `ContentWindow.qml`

Inside the existing `BackgroundEffect.blurRegion` block, add one entry:

```qml
BlurMask {
    target: myPanel.visible ? myPanel.panelItem : null
    contentItem: root.contentItem
    blurOffsetTop:    root.blurOffsetTop
    blurOffsetBottom: root.blurOffsetBottom
    blurOffsetLeft:   root.blurOffsetLeft
    blurOffsetRight:  root.blurOffsetRight
}
```

- Use `vAnchor`/`hAnchor` only when the panel slides in from an edge
  (e.g. `"left"` for a left-anchored sidebar).
- Add `deformMatrix: myPanelBg.deformMatrix` only if the panel has a `BlobRect`
  background (wave-deform shape panels).
- Omit both if the panel is a free-floating popup (like `WidgetGallery`).

### 3. Verify

Run `verify_qml_conventions` on both modified files. The blur region updates live
with no build step needed.

---

## `vAnchor` / `hAnchor` reference

| Panel type | `vAnchor` | `hAnchor` |
|---|---|---|
| Top bar | `"top"` | `"both"` |
| Bottom bar | `"bottom"` | `"both"` |
| Left sidebar | `"both"` | `"left"` |
| Right sidebar | `"both"` | `"right"` |
| Overview (full-screen) | `"both"` | `"both"` |
| Free-floating popup | *(omit)* | *(omit)* |

---

## Config guards

`BlurMask` and `BlurCorners` internally respect `GlobalConfig.appearance.blur` and
`GlobalConfig.appearance.blurMask`. You do **not** need to wrap your `BlurMask` in
a condition — when the user disables blur the component emits zero-sized regions
automatically.

---

## Files

| File | Role |
|---|---|
| [`shell/modules/drawers/ContentWindow.qml`](../../shell/modules/drawers/ContentWindow.qml) | Hosts all `BlurMask` entries inside `BackgroundEffect.blurRegion` |
| [`shell/modules/drawers/blur/BlurMask.qml`](../../shell/modules/drawers/blur/BlurMask.qml) | Per-panel blur region component |
| [`shell/modules/drawers/blur/BlurOffsets.qml`](../../shell/modules/drawers/blur/BlurOffsets.qml) | Geometry computation |
| [`shell/modules/drawers/blur/BlurBodies.qml`](../../shell/modules/drawers/blur/BlurBodies.qml) | Main rectangular region |
| [`shell/modules/drawers/blur/BlurCorners.qml`](../../shell/modules/drawers/blur/BlurCorners.qml) | Rounded-corner mask regions |
