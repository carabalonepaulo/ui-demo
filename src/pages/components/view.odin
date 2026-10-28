package components_page

import ".."
import "../../components"
import "../../kit"
import "core:fmt"
import "core:strings"
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

			kit.draw_text_line(
				ui.id("cmp/name/label"),
				{0, 0},
				{inner.x, 18},
				"LINE_EDIT · name",
				kit.make_text_opts(self.font_bold, 10, kit.C_TEXT_DIM),
			)

			field_size := ui.Vec2{inner.x, 40}
			{
				ui.scope_at({0, 24}, field_size)
				draw_field_box(field_size)

				style := components.LINE_EDIT
				style.font = self.font_regular
				style.font_size = 14
				style.padding = 10
				style.text_color = kit.C_TEXT
				style.caret_color = kit.C_ACCENT
				style.selection_color = {94, 234, 212, 60}

				changed, submitted := components.line_edit(
					ui.id("cmp/name"),
					&self.name,
					field_size,
					style,
					"Type a name…",
				)

				if submitted {
					self.submits += 1
					delete(self.last)
					self.last = strings.clone(self.name)
				}
			}

			kit.draw_text_line(
				ui.id("cmp/note/label"),
				{0, 76},
				{inner.x, 18},
				"LINE_EDIT · second field (focus switches on click)",
				kit.make_text_opts(self.font_bold, 10, kit.C_TEXT_DIM),
			)

			{
				ui.scope_at({0, 100}, field_size)
				draw_field_box(field_size)

				style := components.LINE_EDIT
				style.font = self.font_regular
				style.font_size = 14
				style.padding = 10
				style.text_color = kit.C_TEXT
				style.caret_color = kit.C_ACCENT
				style.selection_color = {94, 234, 212, 60}

				components.line_edit(
					ui.id("cmp/note"),
					&self.note,
					field_size,
					style,
					"Another value…",
				)
			}

			// The button follows the same convention: draw and return the result.
			if components.button(
				ui.id("cmp/clear"),
				{0, 152},
				{96, 30},
				"Clear",
				components.BUTTON,
				self.font_regular,
			) {
				self.name = ""
				self.note = ""
			}

			status := fmt.aprintf(
				"submits %d   ·   last submitted %q   ·   value %q",
				self.submits,
				self.last,
				self.name,
				allocator = ui.get_temp_allocator(),
			)
			{
				// The status can be arbitrarily long; clip it to the row.
				status_size := ui.Vec2{max(1, inner.x - 112), 30}
				ui.scope_at({112, 152}, status_size, {.Clip})
				kit.draw_text_line(
					ui.id("cmp/status"),
					{0, 0},
					status_size,
					status,
					kit.make_text_opts(self.font_regular, 11, kit.C_TEXT_MUTED),
				)
			}

			kit.draw_text_line(
				ui.id("cmp/hint"),
				{0, 196},
				{inner.x, 18},
				"Enter submits · Esc blurs · Ctrl+A/C/X/V/Z · drag or shift+arrows to select",
				kit.make_text_opts(self.font_regular, 11, kit.C_TEXT_DIM),
			)
		}
	}
}

// The widget draws no chrome, so the page owns the box.
draw_field_box :: proc(size: ui.Vec2) {
	ui.fill_rect(kit.C_BG)
	ui.draw_rect({0, 0}, {size.x, 1}, kit.C_BORDER)
	ui.draw_rect({0, size.y - 1}, {size.x, 1}, kit.C_BORDER)
	ui.draw_rect({0, 0}, {1, size.y}, kit.C_BORDER)
	ui.draw_rect({size.x - 1, 0}, {1, size.y}, kit.C_BORDER)
}

