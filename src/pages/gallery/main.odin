package gallery

import ".."
import "core:fmt"
import "core:strings"
import ui "ui:."

IMAGE_COUNT :: 24
CARD_SIZE :: ui.Vec2{230, 192}
IMAGE_HEIGHT :: 150

// Budget presets, in megabytes. Each image is 400x300 RGBA (~469 KB), so the 24
// of them need ~11 MB; the lower presets force eviction while scrolling.
BUDGETS_MB :: [4]int{2, 4, 8, 16}

BUDGET_BUTTON_W :: 62.0
BUDGET_BUTTON_GAP :: 6.0
BUDGETS_W :: f64(len(BUDGETS_MB)) * BUDGET_BUTTON_W + f64(len(BUDGETS_MB) - 1) * BUDGET_BUTTON_GAP

State :: struct {
	ctx:          pages.Context,
	font_bold:    ui.Font,
	font_regular: ui.Font,
	offset:       f64,
	paths:        []string,
}

create :: proc() -> pages.Interface {
	return pages.Interface {
		self      = new(State),
		page      = .Textures,
		label     = "Textures",
		on_ready  = auto_cast on_ready,
		on_enter  = auto_cast on_enter,
		on_update = auto_cast on_update,
		on_exit   = auto_cast on_exit,
		destroy   = auto_cast destroy,
	}
}

destroy :: proc(self: ^State) {
	for path in self.paths do delete(path)
	delete(self.paths)
	free(self)
}

on_ready :: proc(self: ^State, ctx: pages.Context) {
	self.ctx = ctx
	self.font_bold = ctx.load_font("bold", 16)
	self.font_regular = ctx.load_font("regular", 12)

	// Alternate PNG and WebP so both decode paths are exercised.
	self.paths = make([]string, IMAGE_COUNT)
	for i in 0 ..< IMAGE_COUNT {
		extension := i % 2 == 0 ? "png" : "webp"
		name := fmt.aprintf(
			"assets/images/%02d.%s",
			i,
			extension,
			allocator = context.temp_allocator,
		)
		self.paths[i] = strings.clone(ctx.resolve_asset(name))
	}
}

on_enter :: proc(self: ^State, payload: ^pages.Textures_Payload) {}

on_update :: proc(self: ^State) {
	view(self)
}

on_exit :: proc(self: ^State) {}
