package scaling

import ".."
import "../../kit"
import ui "ui:."
import "core:fmt"
import rl "vendor:raylib"

view :: proc(self: ^State) {
	ui.padding({28, 28, 28, 28})
	area := ui.get_available_size()

	kit.draw_page_header(
		ui.id("page/scaling"),
		"Scaling",
		"One modelview scale for the whole frame: no render target, no extra VRAM.",
		self.font_bold,
		self.font_regular,
	)

	rest := ui.Vec2{area.x, max(80, area.y - 82)}
	{
		ui.scope_at({0, 82}, rest)
		draw_panels(self, rest, self.ctx.scale_info())
	}
}

draw_panels :: proc(self: ^State, size: ui.Vec2, info: pages.Scale_Info) {
	left_w := size.x * 0.46
	gap := 16.0

	{
		ui.scope_at({0, 0}, {left_w, size.y})
		ui.fill_rect(kit.C_PANEL)
		ui.draw_rect({0, 0}, {left_w, 1}, kit.C_BORDER)
		ui.draw_rect({0, 0}, {1, size.y}, kit.C_BORDER)
		ui.draw_rect({left_w - 1, 0}, {1, size.y}, kit.C_BORDER)

		{
			ui.padding({24, 24, 24, 24})
			area := ui.get_available_size()

			kit.draw_text_line(
				ui.id("scaling/title"),
				{0, 0},
				{area.x, 22},
				"How it works",
				kit.make_text_opts(self.font_bold, 16, kit.C_TEXT),
			)

			body := "The UI is laid out in logical pixels. The whole frame runs under one rlgl modelview scale, so every draw call becomes physical pixels: including raylib calls a component makes directly. Text is rasterized at the physical size, never resampled. Nothing is rendered offscreen."
			{
				ui.scope_at({0, 26}, {area.x, 122})
				ui.text(
					ui.id("scaling/body"),
					ui.get_size(),
					body,
					kit.make_text_opts(self.font_regular, 12, kit.C_TEXT_MUTED, .Word, 4),
					{.Clip},
				)
			}

			values := [?]struct {
				label: string,
				value: string,
			} {
				{"window", fmt.aprintf("%d x %d", info.window_size.x, info.window_size.y, allocator = ui.get_temp_allocator())},
				{"logical", fmt.aprintf("%.0f x %.0f", info.logical_size.x, info.logical_size.y, allocator = ui.get_temp_allocator())},
				{"pixels / unit", fmt.aprintf("%.2f", info.pixels_per_unit, allocator = ui.get_temp_allocator())},
				{"ui scale", fmt.aprintf("%.2fx", info.ui_scale, allocator = ui.get_temp_allocator())},
				{"render target", "none (0 MB)"},
				{"glyph atlas", fmt.aprintf("%d x %d", info.atlas_size.x, info.atlas_size.y, allocator = ui.get_temp_allocator())},
			}

			for value, i in values {
				y := 164 + f64(i) * 26
				if y + 24 > area.y do break

				kit.draw_text_line(
					ui.id("scaling/label", i),
					{0, y},
					{area.x * 0.52, 24},
					value.label,
					kit.make_text_opts(self.font_regular, 12, kit.C_TEXT_DIM),
				)
				kit.draw_text_line(
					ui.id("scaling/value", i),
					{area.x * 0.52, y},
					{area.x * 0.48, 24},
					value.value,
					kit.make_text_opts(self.font_bold, 12, kit.C_TEXT),
					.Right,
				)
				ui.draw_rect({0, y + 25}, {area.x, 1}, kit.C_BORDER)
			}
		}
	}

	{
		right_w := size.x - left_w - gap
		ui.scope_at({left_w + gap, 0}, {right_w, size.y})
		ui.fill_rect(kit.C_PANEL)
		ui.draw_rect({0, 0}, {right_w, 1}, kit.C_BORDER)
		ui.draw_rect({0, 0}, {1, size.y}, kit.C_BORDER)
		ui.draw_rect({right_w - 1, 0}, {1, size.y}, kit.C_BORDER)

		{
			ui.padding({20, 20, 20, 20})
			area := ui.get_available_size()

			kit.draw_text_line(
				ui.id("scaling/pattern/title"),
				{0, 0},
				{area.x * 0.62, 18},
				"1 LOGICAL PX GRID · 8 PX PITCH",
				kit.make_text_opts(self.font_bold, 10, kit.C_TEXT_DIM),
			)
			kit.draw_text_line(
				ui.id("scaling/pattern/snap"),
				{area.x * 0.62, 0},
				{area.x * 0.38, 18},
				info.snap ? "snap on · S toggles" : "snap off · S toggles",
				kit.make_text_opts(self.font_regular, 10, kit.C_TEXT_DIM),
				.Right,
			)

			pattern_h := max(1, area.y - 28)
			{
				ui.scope_at({0, 28}, {area.x, pattern_h}, {.Clip})
				ui.fill_rect(kit.C_BG)

				// Grid: 1 logical px lines every 8 units. With pixel snap on they
				// stay one physical pixel wide instead of aliasing.
				x: f64 = 0
				for x < area.x {
					ui.draw_rect({x, 0}, {1, pattern_h}, kit.C_ACCENT_DIM)
					x += 8
				}

				y: f64 = 0
				for y < pattern_h {
					ui.draw_rect({0, y}, {area.x, 1}, kit.C_ACCENT_DIM)
					y += 8
				}

				ui.draw_rect({0, 0}, {area.x, 1}, kit.C_ACCENT)
				ui.draw_rect({0, pattern_h - 1}, {area.x, 1}, kit.C_ACCENT)
				ui.draw_rect({0, 0}, {1, pattern_h}, kit.C_ACCENT)
				ui.draw_rect({area.x - 1, 0}, {1, pattern_h}, kit.C_ACCENT)

				// Raw backend calls, deliberately bypassing ui.draw_*: this is a
				// component calling raylib directly. The frame-wide matrix handles
				// the ui scale and the active scissor still clips. The one thing
				// these calls need is the current scope origin.
				strip_h := 92.0
				top := pattern_h - strip_h - 26
				ui.draw_rect({0, top - 12}, {area.x, pattern_h - top + 12}, kit.C_BG)

				origin := ui.get_screen_pos()
				pad := 14.0
				rect_w := min(150.0, area.x * 0.36)

				rec := rl.Rectangle{f32(origin.x + pad), f32(origin.y + top), f32(rect_w), 52}
				rl.DrawRectangleRounded(rec, 0.35, 10, transmute(rl.Color)(kit.C_PANEL_HOVER))
				rl.DrawRectangleRoundedLinesEx(rec, 0.35, 10, 1, transmute(rl.Color)(kit.C_ACCENT))

				cx := pad + rect_w + 44
				if cx + 30 < area.x {
					center := rl.Vector2{f32(origin.x + cx), f32(origin.y + top + 26)}
					rl.DrawCircleV(center, 21, transmute(rl.Color)(kit.C_ACCENT_DIM))
					rl.DrawRing(center, 24, 26, 0, 360, 40, transmute(rl.Color)(kit.C_ACCENT))

					sx := cx + 56
					if sx + 46 < area.x {
						rl.DrawRectanglePro(
							rl.Rectangle{f32(origin.x + sx), f32(origin.y + top + 4), 44, 44},
							{22, 22},
							f32(rl.GetTime()) * 40,
							transmute(rl.Color)(kit.C_ACCENT),
						)
					}
				}

				rl.DrawLineEx(
					{f32(origin.x + area.x - 16), f32(origin.y + top + 4)},
					{f32(origin.x + area.x - 16), f32(origin.y + top + 48)},
					2,
					transmute(rl.Color)(kit.C_BORDER),
				)

				kit.draw_text_line(
					ui.id("scaling/raw/caption"),
					{12, pattern_h - 24},
					{area.x - 24, 18},
					"raw rl.* calls from the component · same matrix, same clip",
					kit.make_text_opts(self.font_regular, 10, kit.C_TEXT_MUTED),
				)
			}
		}
	}
}
