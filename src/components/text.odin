package components

import ui "ui:."

Text_Align :: enum {
	Left,
	Center,
	Right,
}

// Draws `text` inside `area`, vertically centered on the font size. Every widget
// uses this so labels line up the same way.
@(private)
text_in :: proc(
	uid: ui.Id,
	pos, area: ui.Vec2,
	text: string,
	opts: ui.Text_Options,
	align: Text_Align = .Left,
) {
	options := opts
	measured := ui.measure_text(uid, {ui.AUTO, ui.AUTO}, text, &options)

	x := pos.x
	switch align {
	case .Left:
	case .Center:
		x += (area.x - measured.x) * 0.5
	case .Right:
		x += area.x - measured.x
	}

	y := pos.y + (area.y - opts.font_size) * 0.5

	ui.scope_at({x, y}, measured)
	ui.text(uid, measured, text, opts)
}

