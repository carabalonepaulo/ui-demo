// Immediate-mode widgets shared by demos and applications.
//
// A widget draws itself and returns its result for the frame: `button` returns
// true when it was pressed, `line_edit` returns the edited text and flags.
//
// Everything visual comes from the widget's `Style`, including the font and the
// font size, so a theme can replace a whole Style at once.
package components

import "../kit"
import ui "ui:."

Button_Style :: struct {
	bg:        ui.Color,
	hover:     ui.Color,
	pressed:   ui.Color,
	border:    ui.Color,
	text:      ui.Color,
	font:      ui.Font,
	font_size: f64,
}

BUTTON :: Button_Style {
	bg        = kit.C_PANEL,
	hover     = kit.C_PANEL_HOVER,
	pressed   = kit.C_PANEL_PRESSED,
	border    = kit.C_BORDER,
	text      = kit.C_TEXT,
	font_size = 13,
}

// button draws a label centered in `size` and returns true on the frame the
// button is pressed. Style the surrounding area by drawing in the parent scope.
button :: proc(
	id: ui.Id,
	pos, size: ui.Vec2,
	label: string,
	style: Button_Style,
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

	opts := ui.Text_Options {
		font       = style.font,
		font_size  = style.font_size,
		font_color = style.text,
	}

	text_in(ui.id(id, "label"), {}, size, label, opts, .Center)

	return pressed^
}
