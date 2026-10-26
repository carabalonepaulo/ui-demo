# UI Demo / Starter

A standalone starter application for [`carabalonepaulo/ui`](https://github.com/carabalonepaulo/ui).
It contains the raylib + fontstash backend, the page architecture, the dashboard,
the typography page, and the scaling inspector.

The library is linked as a git submodule at `ui/` and resolved with an Odin
collection (`ui:ui`). That keeps the library and the application separate while
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
odin run src -collection:ui=ui
```

### Using a local checkout of the library

The submodule pins a commit of `carabalonepaulo/ui`. If you are working on the
library and the app at the same time, either replace the submodule checkout
with your local work or point the collection elsewhere:

```sh
odin run src -collection:ui=../odin/ui
```

For editor/OLS support, update `ols.json`:

```json
{
  "collections": [
    { "name": "ui", "path": "../odin/ui" }
  ]
}
```

The collection root must be the root of the `ui` repository (the repository that
contains the `ui/` package), so imports are `ui:ui`.

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
odin run src -collection:ui=ui
odin build src -out:ui-demo.exe -collection:ui=ui
```

Headless screenshot:

```sh
just screenshot 2 1.5 3
# or
odin run src -collection:ui=ui -- --view 2 --scale 1.5 --ssaa 3 --screenshot screenshot.png
```

`--view` is the page registration order: `0` Dashboard, `1` Typography,
`2` Scaling.

## Controls

| Input | Action |
| --- | --- |
| Mouse wheel | Scroll the grid or the typography panel |
| `-` / `=` | UI scale down / up (0.5x to 1.5x) |
| `[` / `]` | Supersampling down / up (1x to 4x) |
| `R` | Reset scale to 1x and supersampling to 2x |
| `D` | Toggle the UI profiler |
| Sidebar `-` / `+` | Same scale controls with the mouse |

## Structure

```text
ui/                    # git submodule -> carabalonepaulo/ui
src/
├── main.odin          # window, backend callbacks, frame loop
├── scale.odin         # offscreen target + physical-pixel callbacks
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
* `scale_info()` reports window/logical/target sizes and scale factors.

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

The UI works in logical pixels. For a destination of `dest_size`:

```text
pixels_per_unit = ui_scale * render_scale
texture_size    = ceil(dest_size * render_scale)
logical_size    = texture_size / pixels_per_unit
```

The UI renders into an offscreen texture and the texture is downsampled to the
window. Text is rasterized at `font_size * pixels_per_unit`. See
`src/scale.odin` and `src/renderer.odin`.

## License

MIT. See `LICENSE`.
