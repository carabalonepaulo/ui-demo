package components

import "../kit"
import "core:math"
import rl "vendor:raylib"
import ui "ui:."

Slider_Style :: struct {
	track:        ui.Color,
	track_fill:   ui.Color,
	knob:         ui.Color,
	knob_hover:   ui.Color,
	border:       ui.Color,
	track_height: f64,
	knob_radius:  f64,
}

SLIDER :: Slider_Style {
	track        = kit.C_BG,
	track_fill   = kit.C_ACCENT,
	knob         = kit.C_TEXT,
	knob_hover   = kit.C_ACCENT,
	border       = kit.C_BORDER,
	track_height = 4,
	knob_radius  = 8,
}

@(private = "file")
Slider_State :: struct {
	dragging: bool,
}

// slider edits `value` between `min` and `max`. When `step` is greater than
// zero the value snaps to multiples of it, counted from `min`. Returns true when
// the value changed this frame.
slider :: proc(
	id: ui.Id,
	pos, size: ui.Vec2,
	value: ^f64,
	minimum, maximum, step: f64,
	style: Slider_Style,
) -> bool {
	state := ui.get(ui.id(id, "slider"), Slider_State)

	ui.scope_at(pos, size)
	origin := ui.get_screen_pos()
	mouse := mouse_pos()

	radius := style.knob_radius
	usable := max(1, size.x - radius * 2)

	set_from_mouse :: proc(
		value: ^f64,
		mouse_x, origin_x, radius, usable, minimum, maximum, step: f64,
	) -> bool {
		t := clamp((mouse_x - origin_x - radius) / usable, 0, 1)
		raw := minimum + t * (maximum - minimum)

		if step > 0 {
			raw = clamp(minimum + math.round((raw - minimum) / step) * step, minimum, maximum)
		}

		if raw != value^ {
			value^ = raw
			return true
		}
		return false
	}

	changed := false

	if rl.IsMouseButtonPressed(.LEFT) {
		if point_in_rect(origin, size, mouse) {
			state.dragging = true
			if set_from_mouse(value, mouse.x, origin.x, radius, usable, minimum, maximum, step) {
				changed = true
			}
		}
	} else if rl.IsMouseButtonDown(.LEFT) {
		if state.dragging {
			if set_from_mouse(value, mouse.x, origin.x, radius, usable, minimum, maximum, step) {
				changed = true
			}
		}
	} else {
		state.dragging = false
	}

	t := clamp((value^ - minimum) / max(1e-9, maximum - minimum), 0, 1)
	knob_x := radius + t * usable
	track_y := (size.y - style.track_height) * 0.5

	ui.draw_rect({radius, track_y}, {usable, style.track_height}, style.track)
	ui.draw_rect({radius, track_y}, {max(0, t * usable), style.track_height}, style.track_fill)
	ui.draw_rect({radius, track_y}, {usable, 1}, style.border)

	knob := style.knob
	if point_in_rect(origin, size, mouse) || state.dragging do knob = style.knob_hover

	rl.DrawCircleV(
		{f32(origin.x + knob_x), f32(origin.y + size.y * 0.5)},
		f32(radius),
		transmute(rl.Color)(knob),
	)

	return changed
}

