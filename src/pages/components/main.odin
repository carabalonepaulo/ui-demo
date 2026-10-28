package components_page

import ".."
import "../../components"
import ui "ui:."

FONT_OPTIONS := [2]string{"Regular", "Bold"}

State :: struct {
	ctx:         pages.Context,
	font_bold:   ui.Font,
	font_regular: ui.Font,
	name:        string,
	password:    string,
	enabled:     bool,
	font_choice: int,
	font_size:   f64,
	submits:     int,
}

create :: proc() -> pages.Interface {
	return pages.Interface {
		self      = new(State),
		page      = .Components,
		label     = "Components",
		on_ready  = auto_cast on_ready,
		on_enter  = auto_cast on_enter,
		on_update = auto_cast on_update,
		on_exit   = auto_cast on_exit,
		destroy   = auto_cast destroy,
	}
}

destroy :: proc(self: ^State) {
	// The field text is borrowed from the widgets' buffers; nothing is owned here.
	free(self)
}

on_ready :: proc(self: ^State, ctx: pages.Context) {
	self.ctx = ctx
	self.font_bold = ctx.load_font("bold", 16)
	self.font_regular = ctx.load_font("regular", 14)
	self.name = "Jelly UI"
	self.font_size = 14
}

on_enter :: proc(self: ^State, payload: ^pages.Components_Payload) {
	components.focus(ui.id("cmp/name"))
}

on_update :: proc(self: ^State) {
	view(self)
}

on_exit :: proc(self: ^State) {}
