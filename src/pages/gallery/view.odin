package gallery

import ".."
import "../../components"
import "../../kit"
import "../../textures"
import ui "ui:."
import "core:fmt"
import rl "vendor:raylib"

view :: proc(self: ^State) {
	ui.padding({28, 28, 28, 28})
	area := ui.get_available_size()

	kit.draw_page_header(
		ui.id("page/textures"),
		"Textures",
		"get(path) at any time. Resident pixels are capped by a budget; the least recently used are unloaded first.",
		self.font_bold,
		self.font_regular,
	)

	rest := ui.Vec2{area.x, max(80, area.y - 82)}
	{
		ui.scope_at({0, 82}, rest)

		draw_stats(self, {0, 0}, {rest.x, 44})
		draw_budget_buttons(self, rest)

		grid_pos := ui.Vec2{0, 56}
		grid_size := ui.Vec2{rest.x, max(1, rest.y - grid_pos.y)}
		{
			ui.scope_at(grid_pos, grid_size)
			ui.grid_with_poly(
				&self.offset,
				grid_size,
				IMAGE_COUNT,
				CARD_SIZE,
				{16, 16},
				self,
				proc(i: int, self: ^State) {
					draw_tile(self, i)
				},
				{.Clip},
				{.Clip},
			)
		}
	}
}

draw_stats :: proc(self: ^State, pos, size: ui.Vec2) {
	stats := textures.stats()

	line_a := fmt.aprintf(
		"used %s / %s   ·   resident %d   ·   loading %d",
		ui.format_bytes(u64(stats.used)),
		ui.format_bytes(u64(stats.budget)),
		stats.ready,
		stats.loading,
		allocator = ui.get_temp_allocator(),
	)
	line_b := fmt.aprintf(
		"hits %d   ·   misses %d   ·   evictions %d",
		stats.hits,
		stats.misses,
		stats.evictions,
		allocator = ui.get_temp_allocator(),
	)

	kit.draw_text_line(
		ui.id("tex/stats/a"),
		pos,
		{size.x, 20},
		line_a,
		kit.make_text_opts(self.font_bold, 12, kit.C_TEXT),
	)
	kit.draw_text_line(
		ui.id("tex/stats/b"),
		{pos.x, pos.y + 20},
		{max(60, size.x - BUDGETS_W - 16), 18},
		line_b,
		kit.make_text_opts(self.font_regular, 11, kit.C_TEXT_MUTED),
	)
}

draw_budget_buttons :: proc(self: ^State, area: ui.Vec2) {
	x := area.x - BUDGETS_W
	current := textures.stats().budget / (1024 * 1024)

	for mb, i in BUDGETS_MB {
		label := fmt.aprintf("%d MB", mb, allocator = ui.get_temp_allocator())

		style := components.BUTTON
		if current == mb {
			style.border = kit.C_ACCENT
			style.text = kit.C_ACCENT
		}

		if components.button(
			ui.id("tex/budget", i),
			{x + f64(i) * (BUDGET_BUTTON_W + BUDGET_BUTTON_GAP), 16},
			{BUDGET_BUTTON_W, 28},
			label,
			style,
			self.font_regular,
		) {
			textures.set_budget(mb * 1024 * 1024)
		}
	}
}

draw_tile :: proc(self: ^State, index: int) {
	size := ui.get_size()
	path := self.paths[index]

	// One call per visible tile per frame. That marks it as recently used and
	// brings it back (as a placeholder, then a miss) if it was evicted.
	texture := textures.get(path)
	ready := textures.is_ready(path)

	hover := ui.get(ui.id("tex/hover", index), bool)

	ui.fill_rect(kit.C_PANEL)
	ui.bind(.Hovered, hover)

	origin := ui.get_screen_pos()
	source := rl.Rectangle {
		0,
		0,
		f32(texture.width),
		f32(texture.height),
	}
	dest := rl.Rectangle{f32(origin.x + 1), f32(origin.y + 1), f32(size.x - 2), IMAGE_HEIGHT}
	rl.DrawTexturePro(texture, source, dest, {0, 0}, 0, rl.WHITE)

	border := hover^ ? kit.C_ACCENT : kit.C_BORDER
	ui.draw_rect({0, 0}, {size.x, 1}, border)
	ui.draw_rect({0, size.y - 1}, {size.x, 1}, border)
	ui.draw_rect({0, 0}, {1, size.y}, border)
	ui.draw_rect({size.x - 1, 0}, {1, size.y}, border)

	name := fmt.aprintf(
		"%02d · %s",
		index,
		index % 2 == 0 ? "png" : "webp",
		allocator = ui.get_temp_allocator(),
	)
	kit.draw_text_line(
		ui.id("tex/name", index),
		{12, IMAGE_HEIGHT + 8},
		{size.x - 24, 20},
		name,
		kit.make_text_opts(self.font_bold, 12, kit.C_TEXT),
	)

	status := "loading…"
	color := kit.C_ACCENT
	if ready {
		width, height := textures.size_of(path)
		status = fmt.aprintf("%d x %d", width, height, allocator = ui.get_temp_allocator())
		color = kit.C_TEXT_DIM
	}
	kit.draw_text_line(
		ui.id("tex/status", index),
		{12, IMAGE_HEIGHT + 26},
		{size.x - 24, 16},
		status,
		kit.make_text_opts(self.font_regular, 10, color),
	)
}

