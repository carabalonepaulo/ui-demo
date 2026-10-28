package components_page

import ".."
import "../../components"
import "../../kit"
import "core:fmt"
import ui "ui:."

view :: proc(self: ^State) {
	ui.padding({28, 28, 28, 28})
	area := ui.get_available_size()

	kit.draw_page_header(
		ui.id("page/components"),
		"Components",
		"Immediate-mode widgets: one call draws and returns the result for this frame.",
		self.font_bold,
		self.font_regular,
	)

	rest := ui.Vec2{area.x, max(80, area.y - 82)}
	{
		ui.scope_at({0, 82}, rest)
		ui.fill_rect(kit.C_PANEL)
		ui.draw_rect({0, 0}, {rest.x, 1}, kit.C_BORDER)
		ui.draw_rect({0, 0}, {1, rest.y}, kit.C_BORDER)
		ui.draw_rect({rest.x - 1, 0}, {1, rest.y}, kit.C_BORDER)

		{
			ui.padding({24, 24, 24, 24})
			inner := ui.get_available_size()

			gap := 28.0
			left_w := max(150, (inner.x - gap) * 0.46)
			right_x := left_w + gap
			right_w := max(120, inner.x - right_x)
			field_h := 40.0

			font := self.font_choice == 1 ? self.font_bold : self.font_regular
			label_opts := kit.make_text_opts(self.font_bold, 10, kit.C_TEXT_DIM)

			// --- left: text fields -----------------------------------------
			kit.draw_text_line(
				ui.id("cmp/name/label"),
				{0, 0},
				{left_w, 18},
				"LINE_EDIT · name",
				label_opts,
			)

			field_style := components.LINE_EDIT
			field_style.font = font
			field_style.font_size = self.font_size
			field_style.padding = 10
			field_style.text_color = kit.C_TEXT
			field_style.caret_color = kit.C_ACCENT
			field_style.selection_color = {94, 234, 212, 60}
			field_style.placeholder_color = kit.C_TEXT_DIM

			{
				ui.scope_at({0, 22}, {left_w, field_h})
				draw_field_box({left_w, field_h})

				_, submitted := components.line_edit(
					ui.id("cmp/name"),
					&self.name,
					{left_w, field_h},
					field_style,
					"Type a name…",
				)
				if submitted do self.submits += 1
			}

			kit.draw_text_line(
				ui.id("cmp/pass/label"),
				{0, 74},
				{left_w, 18},
				"LINE_EDIT · password (mask)",
				label_opts,
			)

			{
				ui.scope_at({0, 96}, {left_w, field_h})
				draw_field_box({left_w, field_h})

				components.line_edit(
					ui.id("cmp/pass"),
					&self.password,
					{left_w, field_h},
					field_style,
					"Password…",
					'*',
				)
			}

			kit.draw_text_line(
				ui.id("cmp/hint"),
				{0, 148},
				{left_w, 54},
				"Enter submits · Esc blurs · Ctrl+A/C/X/V/Z",
				kit.make_text_opts(self.font_regular, 10, kit.C_TEXT_DIM, .Word, 2),
			)

			// --- right: checkbox, combobox, slider -------------------------
			kit.draw_text_line(
				ui.id("cmp/options/label"),
				{right_x, 0},
				{right_w, 18},
				"CHECKBOX · COMBOBOX · SLIDER",
				label_opts,
			)

			checkbox_style := components.CHECKBOX
			checkbox_style.font = font
			components.checkbox(
				ui.id("cmp/enabled"),
				{right_x, 24},
				"Enable feature",
				&self.enabled,
				checkbox_style,
			)

			combo_style := components.COMBOBOX
			combo_style.font = font
			components.combobox(
				ui.id("cmp/font"),
				{right_x, 56},
				{right_w, 32},
				FONT_OPTIONS[:],
				&self.font_choice,
				combo_style,
			)

			size_label := fmt.aprintf(
				"FONT SIZE · %.0f",
				self.font_size,
				allocator = ui.get_temp_allocator(),
			)
			kit.draw_text_line(
				ui.id("cmp/size/label"),
				{right_x, 100},
				{right_w, 18},
				size_label,
				label_opts,
			)

			components.slider(
				ui.id("cmp/size"),
				{right_x, 124},
				{right_w, 24},
				&self.font_size,
				10,
				28,
				2,
				components.SLIDER,
			)

			clear_style := components.BUTTON
			clear_style.font = self.font_regular
			if components.button(
				ui.id("cmp/clear"),
				{right_x, 160},
				{96, 30},
				"Clear",
				clear_style,
			) {
				self.name = ""
				self.password = ""
			}

			status := fmt.aprintf("submits %d", self.submits, allocator = ui.get_temp_allocator())
			{
				status_size := ui.Vec2{max(1, right_w - 108), 30}
				ui.scope_at({right_x + 108, 160}, status_size, {.Clip})
				kit.draw_text_line(
					ui.id("cmp/status"),
					{0, 0},
					status_size,
					status,
					kit.make_text_opts(self.font_regular, 11, kit.C_TEXT_MUTED),
				)
			}
		}
	}
}

// The widgets draw no chrome, so the page owns the boxes.
draw_field_box :: proc(size: ui.Vec2) {
	ui.fill_rect(kit.C_BG)
	ui.draw_rect({0, 0}, {size.x, 1}, kit.C_BORDER)
	ui.draw_rect({0, size.y - 1}, {size.x, 1}, kit.C_BORDER)
	ui.draw_rect({0, 0}, {1, size.y}, kit.C_BORDER)
	ui.draw_rect({size.x - 1, 0}, {1, size.y}, kit.C_BORDER)
}
