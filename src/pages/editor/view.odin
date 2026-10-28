package editor

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
		ui.id("page/editor"),
		"Editor",
		"Multi-line text: hard lines, selection across lines and vertical scroll.",
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
			ui.padding({20, 20, 20, 20})
			inner := ui.get_available_size()

			field_size := ui.Vec2{inner.x, max(60, inner.y - 28)}
			{
				ui.scope_at({0, 0}, field_size)
				draw_box(field_size)

				style := components.MULTILINE_EDIT
				style.font = self.font_regular
				style.font_size = 14
				style.line_spacing = 4
				style.padding = 12
				style.text_color = kit.C_TEXT
				style.caret_color = kit.C_ACCENT
				style.selection_color = {94, 234, 212, 60}
				style.placeholder_color = kit.C_TEXT_DIM

				_, submitted := components.multiline_edit(
					ui.id("editor/body"),
					&self.text,
					field_size,
					style,
					"Write something…",
				)
				if submitted do self.submits += 1
			}

			line_count := strings.count(self.text, "\n") + 1
			status := fmt.aprintf(
				"Ctrl+Enter submits   ·   submits %d   ·   %d lines",
				self.submits,
				line_count,
				allocator = ui.get_temp_allocator(),
			)
			kit.draw_text_line(
				ui.id("editor/status"),
				{0, field_size.y + 8},
				{inner.x, 18},
				status,
				kit.make_text_opts(self.font_regular, 11, kit.C_TEXT_MUTED),
			)
		}
	}
}

// The editor draws no chrome, so the page owns the box.
draw_box :: proc(size: ui.Vec2) {
	ui.fill_rect(kit.C_BG)
	ui.draw_rect({0, 0}, {size.x, 1}, kit.C_BORDER)
	ui.draw_rect({0, size.y - 1}, {size.x, 1}, kit.C_BORDER)
	ui.draw_rect({0, 0}, {1, size.y}, kit.C_BORDER)
	ui.draw_rect({size.x - 1, 0}, {1, size.y}, kit.C_BORDER)
}
