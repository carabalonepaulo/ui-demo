// Immediate-mode widgets shared by demos and applications.
//
// A widget draws itself and returns its result for the frame: `button` returns
// true when it was pressed, `line_edit` returns the edited text and flags.
package components

import "../kit"
import ui "ui:."

Button_Style :: struct {
	bg:      ui.Color,
	hover:   ui.Color,
	pressed: ui.Color,
	border:  ui.Color,
	text:    ui.Color,
}

BUTTON :: Button_Style {
	bg      = kit.C_PANEL,
	hover   = kit.C_PANEL_HOVER,
	pressed = kit.C_PANEL_PRESSED,
	border  = kit.C_BORDER,
	text    = kit.C_TEXT,
}

// button draws a label centered in `size` and returns true on the frame the
// button is pressed. Style the surrounding area by drawing in the parent scope.
button :: proc(
	id: ui.Id,
	pos, size: ui.Vec2,
	label: string,
	style: Button_Style,
	font: ui.Font,
	text_size: f64 = 13,
) -> bool {
	hovered := ui.get(ui.id(id, "hover"), bool)
	pressed := ui.get(ui.id(id, "pressed"), bool)

	ui.scope_at(pos, size)
	ui.bind(.Hovered, hovered)
	ui.bind(.Pressed, pressed)

	bg := style.bg
	if pressed^ {
		bg = style.pressed
	} else if hovered^ {
		bg = style.hover
	}

	ui.fill_rect(bg)
	ui.draw_rect({0, 0}, {size.x, 1}, style.border)
	ui.draw_rect({0, size.y - 1}, {size.x, 1}, style.border)
	ui.draw_rect({0, 0}, {1, size.y}, style.border)
	ui.draw_rect({size.x - 1, 0}, {1, size.y}, style.border)

	opts := kit.make_text_opts(font, text_size, style.text)
	kit.draw_text_line(ui.id(id, "label"), {}, size, label, opts, .Center)

	return pressed^
}
