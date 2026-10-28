package demo

import "core:math"
import ui "ui:."
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

// The UI is laid out in logical units. Instead of rendering into an offscreen
// target, the whole frame runs under an rlgl modelview scale of `ppu`, so every
// draw call lands in physical pixels:
//
//   pixels_per_unit = ui_scale * dpi_scale
//   logical_size    = window_size / pixels_per_unit
//
// There is no render target: no extra VRAM, no blit, nothing to recreate on
// resize. rlgl transforms vertices on submission, so drawing with the matrix
// active costs nothing extra.
//
// The matrix covers every `rl.Draw*` call, including calls a component makes
// directly without going through `ui.draw_rect` / `ui.draw_text`. The three
// things it cannot cover, because they are not geometry:
//
//   * mouse input -> ui_scale_mouse_pos (window px -> logical units)
//   * scissor     -> ui_scale_enable_scissors (glScissor is in framebuffer px)
//   * text        -> ui_scale_pop_matrix, draw at size * ppu, ui_scale_push_matrix
//
// Text is the only deliberate exception: glyphs come from a bitmap atlas, so
// scaling the quads with the matrix would blur them. Drawing at the physical
// size keeps them pixel-exact. See `draw_text` in main.odin.
UIScale :: struct {
	ui_scale:     f64,
	dpi_scale:    f64,
	// Window size in window/screen units. The UI always covers the whole window.
	dest_size:    ui.Vec2,
	logical_size: ui.Vec2,
	ppu:          f64,
	// Snap every filled rectangle to the physical pixel grid. Keeps 1px lines
	// and adjacent edges crisp at fractional scales. Turn it off to see the
	// difference (a 1px line becomes 1.4px and aliases).
	snap:         bool,
}

ui_scale_init :: proc(s: ^UIScale, ui_scale: f64 = 1, dpi_scale: f64 = 1, snap := true) {
	s.ui_scale = ui_scale
	s.dpi_scale = dpi_scale
	s.ppu = 1
	s.dest_size = {1, 1}
	s.logical_size = {1, 1}
	s.snap = snap
}

// Derives ppu and the logical root size from the window. Nothing is allocated,
// so resizing and scaling every frame are free.
ui_scale_update :: proc(s: ^UIScale, window_size: ui.Vec2) {
	s.dest_size = {max(1, window_size.x), max(1, window_size.y)}
	s.ui_scale = clamp(s.ui_scale, 0.25, 8)
	s.dpi_scale = clamp(s.dpi_scale, 0.5, 4)
	s.ppu = s.ui_scale * s.dpi_scale
	s.logical_size = s.dest_size / s.ppu
}

// Logical coordinate snapped to the physical pixel grid. Both edges of every
// rectangle go through this, so neighbours share the exact same edge instead of
// drifting by a texel.
snap_to_px :: proc(s: ^UIScale, v: f64) -> f64 {
	if !s.snap do return v
	return math.round(v * s.ppu) / s.ppu
}

// --- Matrix --------------------------------------------------------------

ui_scale_push_matrix :: proc(s: ^UIScale) {
	rlgl.PushMatrix()
	if s.ppu != 1 do rlgl.Scalef(f32(s.ppu), f32(s.ppu), 1)
}

ui_scale_pop_matrix :: proc(s: ^UIScale) {
	rlgl.PopMatrix()
}

// Frame scope: begin before `ui.frame()`, end after the last deferred draw.
ui_scale_begin :: proc(s: ^UIScale) {
	ui_scale_push_matrix(s)
}

ui_scale_end :: proc(s: ^UIScale) {
	ui_scale_pop_matrix(s)
}

// --- Backend callbacks ---------------------------------------------------

ui_scale_draw_rect :: proc(s: ^UIScale, x, y, w, h: f64, color: ui.Color) {
	x0 := snap_to_px(s, x)
	y0 := snap_to_px(s, y)
	x1 := snap_to_px(s, x + w)
	y1 := snap_to_px(s, y + h)

	if x1 <= x0 || y1 <= y0 do return

	rec := rl.Rectangle{f32(x0), f32(y0), f32(x1 - x0), f32(y1 - y0)}
	rl.DrawRectangleRec(rec, transmute(rl.Color)(color))
}

ui_scale_enable_scissors :: proc(s: ^UIScale, x, y, w, h: i32) {
	// glScissor is not part of the modelview, so this is the one callback that
	// still converts to physical pixels by hand.
	//
	// Raylib flips Y against the active framebuffer height internally; with no
	// render target bound that height is the window, so these stay top-left
	// coordinates. If the host app draws the UI into its own target, clamp to
	// that target's size instead of `dest_size`.
	px := i32(math.round(f64(x) * s.ppu))
	py := i32(math.round(f64(y) * s.ppu))
	pw := i32(math.round(f64(w) * s.ppu))
	ph := i32(math.round(f64(h) * s.ppu))

	if px < 0 {
		pw += px
		px = 0
	}
	if py < 0 {
		ph += py
		py = 0
	}

	tw := i32(s.dest_size.x)
	th := i32(s.dest_size.y)

	px = clamp(px, 0, tw)
	py = clamp(py, 0, th)
	pw = clamp(pw, 0, tw - px)
	ph = clamp(ph, 0, th - py)

	rl.BeginScissorMode(px, py, pw, ph)
}

ui_scale_disable_scissors :: proc() {
	rl.EndScissorMode()
}

// Maps a window-space mouse position into logical UI space.
ui_scale_mouse_pos :: proc(s: ^UIScale) -> ui.Vec2 {
	pos := rl.GetMousePosition()
	x := f64(pos.x) / s.ppu
	y := f64(pos.y) / s.ppu

	if x < 0 || y < 0 || x > s.logical_size.x || y > s.logical_size.y {
		return {-1e9, -1e9}
	}

	return {x, y}
}
