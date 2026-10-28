package components

import "../kit"
import rl "vendor:raylib"
import ui "ui:."

Combobox_Style :: struct {
	font:        ui.Font,
	font_size:   f64,
	text:        ui.Color,
	background:  ui.Color,
	hover:       ui.Color,
	border:      ui.Color,
	item_hover:  ui.Color,
	padding:     f64,
	item_height: f64,
}

COMBOBOX :: Combobox_Style {
	font_size   = 13,
	text        = kit.C_TEXT,
	background  = kit.C_PANEL,
	hover       = kit.C_PANEL_HOVER,
	border      = kit.C_BORDER,
	item_hover  = kit.C_PANEL_HOVER,
	padding     = 8,
	item_height = 26,
}

@(private = "file")
Combobox_State :: struct {
	open:        bool,
	just_opened: bool,
	picked:      bool,
}

@(private = "file")
Combobox_Payload :: struct {
	id:          ui.Id,
	options:     []string,
	style:       Combobox_Style,
	selected:    ^int,
	state:       ^Combobox_State,
	just_opened: bool,
}

// combobox draws the current option and, when open, a list on top of the UI. It
// returns true on the call after an option was clicked; `selected` is already
// updated when the click happens.
combobox :: proc(
	id: ui.Id,
	pos, size: ui.Vec2,
	options: []string,
	selected: ^int,
	style: Combobox_Style,
) -> bool {
	state := ui.get(ui.id(id, "combobox"), Combobox_State)

	clicked := state.picked
	state.picked = false

	hovered := ui.get(ui.id(id, "hover"), bool)
	pressed := ui.get(ui.id(id, "pressed"), bool)

	ui.scope_at(pos, size)
	ui.bind(.Hovered, hovered)
	ui.bind(.Pressed, pressed)

	if pressed^ {
		state.open = !state.open
		state.just_opened = state.open
	}

	origin := ui.get_screen_pos()

	background := style.background
	if hovered^ do background = style.hover

	ui.fill_rect(background)
	ui.draw_rect({0, 0}, {size.x, 1}, style.border)
	ui.draw_rect({0, size.y - 1}, {size.x, 1}, style.border)
	ui.draw_rect({0, 0}, {1, size.y}, style.border)
	ui.draw_rect({size.x - 1, 0}, {1, size.y}, style.border)

	label := ""
	if selected^ >= 0 && selected^ < len(options) do label = options[selected^]

	opts := ui.Text_Options {
		font       = style.font,
		font_size  = style.font_size,
		font_color = style.text,
	}
	text_in(
		ui.id(id, "value"),
		{style.padding, 0},
		{max(1, size.x - style.padding * 2 - 16), size.y},
		label,
		opts,
	)

	// Three rows make a small down arrow.
	arrow_x := size.x - style.padding - 8
	arrow_y := size.y * 0.5 - 2
	ui.draw_rect({arrow_x, arrow_y}, {8, 2}, style.text)
	ui.draw_rect({arrow_x + 2, arrow_y + 2}, {4, 2}, style.text)

	if state.open && len(options) > 0 {
		height := style.padding * 2 + f64(len(options)) * style.item_height

		ui.popup_with_poly(
			origin + {0, size.y},
			{size.x, height},
			Combobox_Payload {
				id = id,
				options = options,
				style = style,
				selected = selected,
				state = state,
				just_opened = state.just_opened,
			},
			draw_list,
		)
	} else {
		state.open = false
		state.just_opened = false
	}

	return clicked
}

@(private = "file")
draw_list :: proc(payload: Combobox_Payload) {
	style := payload.style
	origin := ui.get_screen_pos()
	size := ui.get_size()
	mouse := mouse_pos()

	ui.fill_rect(style.background)
	ui.draw_rect({0, 0}, {size.x, 1}, style.border)
	ui.draw_rect({0, size.y - 1}, {size.x, 1}, style.border)
	ui.draw_rect({0, 0}, {1, size.y}, style.border)
	ui.draw_rect({size.x - 1, 0}, {1, size.y}, style.border)

	opts := ui.Text_Options {
		font       = style.font,
		font_size  = style.font_size,
		font_color = style.text,
	}

	for option, i in payload.options {
		item_pos := ui.Vec2{0, style.padding + f64(i) * style.item_height}
		item_size := ui.Vec2{size.x, style.item_height}

		if point_in_rect(origin + item_pos, item_size, mouse) {
			ui.draw_rect(item_pos, item_size, style.item_hover)
		}

		text_in(
			ui.id(payload.id, "item", i),
			item_pos + {style.padding, 0},
			{max(1, size.x - style.padding * 2), style.item_height},
			option,
			opts,
		)
	}

	if rl.IsMouseButtonPressed(.LEFT) {
		if point_in_rect(origin, size, mouse) {
			for option, i in payload.options {
				item_pos := ui.Vec2{0, style.padding + f64(i) * style.item_height}
				item_size := ui.Vec2{size.x, style.item_height}

				if point_in_rect(origin + item_pos, item_size, mouse) {
					payload.selected^ = i
					payload.state.picked = true
					payload.state.open = false
					break
				}
			}
		} else if !payload.just_opened {
			// A click anywhere else closes the list. The click that opened it is
			// on the header, which is outside the popup, so skip that frame.
			payload.state.open = false
		}
	}

	payload.state.just_opened = false
}
