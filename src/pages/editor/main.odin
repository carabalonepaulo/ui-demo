package editor

import ".."
import "../../components"
import ui "ui:."

SAMPLE :: "The quick brown fox jumps over the lazy dog.\n\nThis is a multi-line editor. Click or drag to place the caret, shift+arrows to select, Ctrl+A/C/X/V/Z for the usual.\n\nHome and End work per line; Ctrl+Home and Ctrl+End jump to the document ends.\n\nVertical scroll keeps the caret in view and long lines scroll horizontally. Ctrl+Enter submits."

State :: struct {
	ctx:          pages.Context,
	font_bold:    ui.Font,
	font_regular: ui.Font,
	text:         string,
	submits:      int,
}

create :: proc() -> pages.Interface {
	return pages.Interface {
		self      = new(State),
		page      = .Editor,
		label     = "Editor",
		on_ready  = auto_cast on_ready,
		on_enter  = auto_cast on_enter,
		on_update = auto_cast on_update,
		on_exit   = auto_cast on_exit,
		destroy   = auto_cast destroy,
	}
}

destroy :: proc(self: ^State) {
	// `text` is borrowed from the widget's buffer.
	free(self)
}

on_ready :: proc(self: ^State, ctx: pages.Context) {
	self.ctx = ctx
	self.font_bold = ctx.load_font("bold", 16)
	self.font_regular = ctx.load_font("regular", 14)
	self.text = SAMPLE
}

on_enter :: proc(self: ^State, payload: ^pages.Editor_Payload) {
	components.focus(ui.id("editor/body"))
}

on_update :: proc(self: ^State) {
	view(self)
}

on_exit :: proc(self: ^State) {}
