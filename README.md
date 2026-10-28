# UI Demo / Starter

A standalone starter application for [`carabalonepaulo/ui`](https://github.com/carabalonepaulo/ui).
It contains the raylib + fontstash backend, the page architecture, the dashboard,
the typography page, and the scaling inspector.

The library is linked as a git submodule at `ui/` and resolved with an Odin
collection (`ui:.`). The collection points at the package folder `ui/ui`, not
the repository root. That keeps the library and the application separate while
pinning an exact library commit.

## Requirements

* [Odin](https://odin-lang.org/) (a recent compiler; the demo uses raylib from
  the Odin vendor collection).
* [just](https://github.com/casey/just) optional; plain Odin commands are below.
* Git.

## Quick start

```sh
git clone --recurse-submodules https://github.com/carabalonepaulo/ui-demo.git my-app
cd my-app
just run
```

If you cloned without `--recurse-submodules`:

```sh
git submodule update --init --recursive
just run
```

`just run`, `build`, `check`, and `screenshot` all depend on `setup`, which runs
`git submodule update --init --recursive`; the separate step is optional.

Without `just`:

```sh
git submodule update --init --recursive
odin run src -collection:ui=ui/ui
```

`ols.json` is already configured for the package folder:

```json
{
  "collections": [
    { "name": "ui", "path": "ui/ui" }
  ]
}
```

Sources import it as:

```odin
import ui "ui:."
```

### Using a local checkout of the library

The submodule pins a commit of `carabalonepaulo/ui`. If you are working on the
library and the app at the same time, either replace the submodule checkout
with your local work or point the collection elsewhere:

```sh
odin run src -collection:ui=../odin/ui/ui
```

For editor/OLS support, update `ols.json`:

```json
{
  "collections": [
    { "name": "ui", "path": "../odin/ui/ui" }
  ]
}
```

The collection root must be the library package folder (the inner `ui/ui`
directory), not the repository root, so imports are `ui:.`.

### Updating the pinned library

```sh
# update the submodule to the latest main
git submodule update --remote ui
git add ui
git commit -m "Update ui"

# or pin an exact tag/commit
git -C ui fetch --tags
git -C ui checkout v0.1.0
git add ui
git commit -m "Pin ui v0.1.0"
```

### OpenCode skill

`opencode.json` points the OpenCode skill loader at the submodule:

```json
{
  "skills": ["./ui/.opencode/skills"]
}
```

After the submodule is initialized, the `ui-app` skill is available in this
project. If you use a different library path, update that entry (or copy
`ui/.opencode/skills/ui-app` into your project's `.opencode/skills/`). For a
global install, copy it to `~/.config/opencode/skills/ui-app`.

## Run and build

```sh
just run
just build
odin run src -collection:ui=ui/ui
odin build src -out:ui-demo.exe -collection:ui=ui/ui
```

Headless screenshot:

```sh
just screenshot 2 1.5
# or
odin run src -collection:ui=ui/ui -- --view 2 --scale 1.5 --screenshot screenshot.png
```

`--view` is the page registration order: `0` Dashboard, `1` Typography,
`2` Scaling.

## Controls

| Input | Action |
| --- | --- |
| Mouse wheel | Scroll the grid or the typography panel |
| `-` / `=` | UI scale down / up (0.5x to 1.5x) |
| `S` | Toggle pixel snapping of filled rectangles |
| `R` | Reset scale to 1x and pixel snapping on |
| `D` | Toggle the UI profiler |
| Sidebar `-` / `+` | Same scale controls with the mouse |
| Sidebar `on` / `off` | Toggle pixel snapping |

## Structure

```text
ui/                    # git submodule -> carabalonepaulo/ui
src/
├── main.odin          # window, backend callbacks, frame loop
├── scale.odin         # rlgl modelview scale + physical-pixel callbacks
├── renderer.odin      # fontstash atlas, font registry, text quads
├── app.odin           # shell, page registry, lifecycle, Context implementation
├── kit/kit.odin       # colors, text helpers, buttons, page header
└── pages/
    ├── pages.odin     # Page enum, Interface, Context, payloads
    ├── dashboard/
    │   ├── main.odin  # state + lifecycle
    │   └── view.odin  # drawing
    ├── typography/
    └── scaling/
assets/fonts/
```

## Pages

A page owns one enum value, one state object, and a small lifecycle. The shell
owns the header, sidebar, content area, and footer; pages never draw chrome.

```odin
State :: struct {
    ctx:       pages.Context,
    font_bold: ui.Font,
}

create :: proc() -> pages.Interface {
    return pages.Interface {
        self      = new(State),
        page      = .Dashboard,
        label     = "Dashboard",
        on_ready  = auto_cast on_ready,
        on_enter  = auto_cast on_enter,
        on_update = auto_cast on_update,
        on_exit   = auto_cast on_exit,
        destroy   = auto_cast destroy,
    }
}

on_ready :: proc(self: ^State, ctx: pages.Context) {
    self.ctx = ctx
    self.font_bold = ctx.load_font("bold", 16)
}
```

The app injects the same `Context` into every page:

* `go_to(page, payload)` queues a page change; the app applies it at the end of
  the frame (so frame-arena payloads are still valid).
* `load_font(name, size)` returns a `ui.Font`. Fontstash is size-independent, so
  `size` is a hint; a backend with per-size atlases can use it in the cache key.
* `set_scroll_modifier(modifier)` tunes the wheel speed.
* `scale_info()` reports window/logical sizes, scale factors, pixel snapping, and
  the glyph atlas size.

Add a page by creating `State` + `create`, registering it in `PAGE_CTORS` in
`src/app.odin`, and adding its enum value. The sidebar and navigation pick it up
automatically. Add it to `PAGE_ORDER` only if you use `--view`.

## Using it as a template

Use this repository as a template (or copy the tree) and start adding pages. Keep
`.gitmodules`, `ols.json`, and the collection setup. If you re-initialize git,
run `git submodule update --init --recursive` (or `just setup`) and commit the
`ui` gitlink at the version you want. The shell and core code do not need to
change to add screens.

## Scaling

The UI works in logical units. For a window of `dest_size`:

```text
pixels_per_unit = ui_scale * dpi_scale
logical_size    = dest_size / pixels_per_unit
```

The whole frame runs under one rlgl modelview scale of `pixels_per_unit`, so
every `rl.Draw*` call becomes physical pixels: `ui.draw_rect`, `ui.draw_text`,
and any raylib call a component makes directly. Nothing is rendered offscreen
and no extra VRAM is allocated, so resizing and zooming cost nothing.

Three things cannot go through the matrix, because they are not geometry:

| Concern | Handling |
| --- | --- |
| Mouse input | `ui_scale_mouse_pos` divides by `pixels_per_unit` |
| Scissor | `glScissor` is in framebuffer pixels; `ui_scale_enable_scissors` converts |
| Text | Glyphs are bitmaps; the text callback drops the matrix and draws at `font_size * pixels_per_unit` |

`rlgl` transforms vertices on submission, so dropping and restoring the matrix
around a text call does not flush the batch or change draw order.

Pixel snap (`S`) rounds both edges of every `ui.draw_rect` to the physical pixel
grid. At fractional scales it keeps 1px lines exactly one pixel and makes
neighbouring rectangles share an edge; turn it off to see the aliasing it
prevents.

A component that draws with raylib directly needs one thing the UI does not pass
through the draw callbacks: the current scope origin.

```odin
origin := ui.get_screen_pos()          // logical, already includes the scale
rl.DrawCircleV({f32(origin.x + 40), f32(origin.y + 40)}, 20, rl.WHITE)
```

The matrix only covers UI drawing. A 2D/3D world drawn by a component goes into
its own texture (or its own window area) and is presented as a texture inside the
UI; do not run `BeginMode3D` between the UI matrix push and pop, because
`EndMode3D` resets the modelview that the matrix stack is using.

See `src/scale.odin` and `src/renderer.odin`.

## License

MIT. See `LICENSE`.
