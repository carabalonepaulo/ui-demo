package components

import "../kit"
import ui "ui:."

Checkbox_Style :: struct {
	font:       ui.Font,
	font_size:  f64,
	box:        f64,
	gap:        f64,
	label:      ui.Color,
	background: ui.Color,
	hover:      ui.Color,
	border:     ui.Color,
	check:      ui.Color,
}

CHECKBOX :: Checkbox_Style {
	font_size  = 13,
	box        = 18,
	gap        = 8,
	label      = kit.C_TEXT,
	background = kit.C_PANEL,
	hover      = kit.C_PANEL_HOVER,
	border     = kit.C_BORDER,
	check      = kit.C_ACCENT,
}

// checkbox draws a box followed by a label. The label is part of the click area
// and the check state is owned by the caller.
checkbox :: proc(
	id: ui.Id,
	pos: ui.Vec2,
	label: string,
	checked: ^bool,
	style: Checkbox_Style,
) -> bool {
	opts := ui.Text_Options {
		font       = style.font,
		font_size  = style.font_size,
		font_color = style.label,
	}
	label_size := ui.measure_text(ui.id(id, "measure"), {ui.AUTO, ui.AUTO}, label, &opts)

	height := max(style.box, style.font_size)
	size := ui.Vec2{style.box + style.gap + label_size.x, height}

	hovered := ui.get(ui.id(id, "hover"), bool)
	pressed := ui.get(ui.id(id, "pressed"), bool)

	ui.scope_at(pos, size)
	ui.bind(.Hovered, hovered)
	ui.bind(.Pressed, pressed)

	changed := false
	if pressed^ {
		checked^ = !checked^
		changed = true
	}

	box_y := (height - style.box) * 0.5
	background := style.background
	if hovered^ do background = style.hover

	ui.draw_rect({0, box_y}, {style.box, style.box}, background)
	ui.draw_rect({0, box_y}, {style.box, 1}, style.border)
	ui.draw_rect({0, box_y + style.box - 1}, {style.box, 1}, style.border)
	ui.draw_rect({0, box_y}, {1, style.box}, style.border)
	ui.draw_rect({style.box - 1, box_y}, {1, style.box}, style.border)

	if checked^ {
		inset := max(2, style.box * 0.24)
		ui.draw_rect(
			{inset, box_y + inset},
			{style.box - inset * 2, style.box - inset * 2},
			style.check,
		)
	}

	text_in(
		ui.id(id, "label"),
		{style.box + style.gap, 0},
		{label_size.x, height},
		label,
		opts,
	)

	return changed
}
