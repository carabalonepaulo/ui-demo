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
just screenshot 3 1 4 textures.png
# or
odin run src -collection:ui=ui/ui -- --view 2 --scale 1.5 --screenshot screenshot.png
odin run src -collection:ui=ui/ui -- --view 3 --budget 4 --screenshot textures.png
```

`--view` is the page registration order: `0` Dashboard, `1` Typography,
`2` Scaling, `3` Textures, `4` Components. `--budget` sets the texture cache
budget in megabytes (default 8).

`--view` is the page registration order: `0` Dashboard, `1` Typography,
`2` Scaling.

## Controls

| Input | Action |
| --- | --- |
| Mouse wheel | Scroll the dashboard, the typography panel, or the textures grid |
| `-` / `=` | UI scale down / up (0.5x to 1.5x) |
| `S` | Toggle pixel snapping of filled rectangles |
| `R` | Reset scale to 1x and pixel snapping on |
| `D` | Toggle the UI profiler |
| Sidebar `-` / `+` | Same scale controls with the mouse |
| Sidebar `on` / `off` | Toggle pixel snapping |
| Textures `2/4/8/16 MB` | Set the texture cache budget (evicts immediately) |
| Text field | Type to edit, click or drag to move/select, shift+arrows, Ctrl+A/C/X/V/Z/Y |
| Text field `Enter` / `Esc` | Submit / blur |
| While a field is focused | The global shortcuts (`-`, `=`, `S`, `R`, `D`) are disabled |

## Structure

```text
ui/                    # git submodule -> carabalonepaulo/ui
src/
├── main.odin          # window, backend callbacks, frame loop, nbio + texture ticks
├── scale.odin         # rlgl modelview scale + physical-pixel callbacks
├── renderer.odin      # fontstash atlas, font registry, text quads
├── textures/          # budgeted LRU texture cache (nbio + libwebp)
│   └── webp/          # libwebp bindings and libraries (windows x64)
├── components/        # immediate-mode widgets (button, line_edit)
├── app.odin           # shell, page registry, lifecycle, Context implementation
├── kit/kit.odin       # colors, text helpers, page header
└── pages/
    ├── pages.odin     # Page enum, Interface, Context, payloads
    ├── dashboard/
    │   ├── main.odin  # state + lifecycle
    │   └── view.odin  # drawing
    ├── typography/
    ├── scaling/
    ├── gallery/       # textures page
    └── components/    # button + line_edit page
assets/
├── fonts/
└── images/            # generated by tools/gen_assets
tools/gen_assets/      # image generator (png + webp)
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
* `resolve_asset(path)` maps a repository-relative asset path for the current
  working directory (the demo runs from the repo root or from `src/`).

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

## Textures

`src/textures` is a budgeted LRU cache for GPU textures, so a page can call
`textures.get(path)` for anything on screen and never think about loading:

```odin
texture := textures.get(path)  // the placeholder while the file is read
rl.DrawTexturePro(texture, source, dest, {}, 0, rl.WHITE)
```

* The first `get` starts an `nbio` read and returns a placeholder. Decoding
  happens on the main thread in `textures.tick`: raylib for PNG/JPG, the bundled
  libwebp for WebP (detected by the RIFF/WEBP header, not the extension).
* Every `get` marks the entry as most recently used. When the resident pixel data
  would exceed the budget, the least recently used textures are unloaded first.
  Unloading drops the entry, so a later `get` reloads it (a miss).
* The cache progresses with two calls per frame:

```odin
assert(nbio.acquire_thread_event_loop() == nil)
defer nbio.release_thread_event_loop()

textures.init(8 * mem.Megabyte)
defer textures.deinit()   // drains in-flight reads before unloading

for !rl.WindowShouldClose() {
    nbio.tick(0)        // async reads complete here
    textures.tick()     // uploads what is ready
    // draw, calling textures.get(path) for visible textures
}
```

* `set_budget(bytes)` shrinks the cache immediately. The 2/4/8/16 MB buttons on
  the Textures page call it.
* `stats()` returns the budget, used bytes, counts, hits, misses and evictions.
* Only textures requested during the current frame are guaranteed to stay
  resident. Draw a texture from the value `get` returned in the same frame.

The Textures page (`--view 3`) shows 24 generated images (PNG and WebP
alternating) with live stats. `--budget` sets the startup budget in megabytes.

The WebP libraries in `src/textures/webp/lib` are Windows x64 for now. The demo
images are generated by `odin run tools/gen_assets` (or `just assets`).

## Components

`src/components` holds immediate-mode widgets: one call draws and returns the
result for the frame.

```odin
if components.button(id, {0, 0}, {96, 30}, "Clear", components.BUTTON, font) {
    // pressed this frame
}

changed, submitted := components.line_edit(
    ui.id("name"),
    &self.name,
    {area.x, 36},
    components.LINE_EDIT,
    "Type a name…",
)
```

`button` returns true on the frame it is pressed. `line_edit` is stateful
internally (text buffer, selection, undo/redo and key repeat live in the UI
store, driven by `core:text/edit`), but the API is immediate: the caller owns the
text.

After each call, `text^` points at the widget's internal `strings.Builder`, so
reading it is free — no copy per keystroke. The slice is **borrowed**: valid
until the next call for the same id, or until the widget stops being drawn and
its state is evicted. Clone it to keep the value; do not free it. To change the
text from outside, assign a different string to `text^` before the call; the
widget copies it into its buffer that frame.

`line_edit` draws only the text, caret and selection; the parent draws the box
(see the Components page). It reads keyboard and mouse from raylib. While a field
is focused, `components.focused_id()` is non-zero and the demo's global shortcuts
are skipped. `components.focus(id)` moves the focus programmatically.

## License

MIT. See `LICENSE`.
