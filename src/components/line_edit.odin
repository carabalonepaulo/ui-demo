// A single-line text editor.
//
//	changed, submitted := components.line_edit(
//		ui.id("name"),
//		&self.name,
//		{area.x, 36},
//		components.LINE_EDIT,
//		"Type a name…",
//	)
//
// `text^` is the source of truth for the caller. After every call it points at
// the editor's internal `strings.Builder`, so reading it costs nothing and the
// widget never allocates a copy per keystroke. That also means the slice is
// *borrowed*: it is valid until the next call for the same id (or until the
// widget stops being drawn and its state is evicted). Clone it if you need to
// keep the text around; do not free it.
//
// To change the text from the outside, assign a different string to `text^`
// before the call. The widget copies it into the builder on that frame.
//
// The widget draws no background or border: style the parent scope. Only the
// text, caret and selection are drawn, through the library's font pipeline.
//
// Keyboard and mouse come straight from raylib. The mouse position is read from
// the backend callback so it is already in logical units.
package components

import "core:mem"
import "core:strings"
import "core:text/edit"
import "core:unicode/utf8"
import rl "vendor:raylib"
import ui "ui:."

CARET_WIDTH :: 1.0
CARET_BLINK :: 0.5
REPEAT_DELAY :: 0.40
REPEAT_INTERVAL :: 0.04

Line_Edit_Style :: struct {
	font:              ui.Font,
	font_size:         f64,
	letter_spacing:    f64,
	padding:           f64,
	text_color:        ui.Color,
	caret_color:       ui.Color,
	selection_color:   ui.Color,
	placeholder_color: ui.Color,
}

LINE_EDIT :: Line_Edit_Style {
	font_size         = 14,
	letter_spacing    = 0,
	padding           = 8,
	text_color        = {232, 236, 244, 255},
	caret_color       = {94, 234, 212, 255},
	selection_color   = {94, 234, 212, 70},
	placeholder_color = {92, 101, 117, 255},
}

@(private = "file")
Input_Repeat :: struct {
	command:      edit.Command,
	key:          rl.KeyboardKey,
	timer:        f64,
	is_repeating: bool,
}

Line_Edit :: struct {
	builder:     strings.Builder,
	edit:        edit.State,
	repeat:      Input_Repeat,
	scroll_x:    f64,
	blink:       f64,
	allocator: mem.Allocator,
}

// The focused field. One per process is enough for a demo; clicking another
// field moves the focus.
@(private = "file")
focused: ui.Id

// focus moves the keyboard focus to `id`, or clears it with 0.
focus :: proc(id: ui.Id) {
	focused = id
}

// focused_id returns the id that owns the keyboard focus, or 0.
focused_id :: proc() -> ui.Id {
	return focused
}

line_edit :: proc(
	id: ui.Id,
	text: ^string,
	size: ui.Vec2,
	style: Line_Edit_Style,
	placeholder := "",
	allocator := context.allocator,
) -> (
	changed: bool,
	submitted: bool,
) {
	state, created := ui.get(ui.id(id, "line_edit"), Line_Edit, destroy = destroy_line_edit)
	if created {
		state.allocator = allocator
		state.builder = strings.builder_make_none(allocator)
		edit.init(&state.edit, allocator, allocator)
		state.edit.set_clipboard = clipboard_set
		state.edit.get_clipboard = clipboard_get
		edit.setup_once(&state.edit, &state.builder)
	}

	// `text^` is the source of truth. When the caller assigned something else,
	// copy it into the editor's buffer.
	current := strings.to_string(state.builder)
	if current != text^ {
		strings.builder_reset(&state.builder)
		strings.write_string(&state.builder, text^)
		// Caret at the end, no selection.
		state.edit.selection = {len(text^), len(text^)}
		state.scroll_x = 0
		current = text^
	}

	opts := ui.Text_Options {
		wrap           = .None,
		font           = style.font,
		font_size      = style.font_size,
		letter_spacing = style.letter_spacing,
		font_color     = style.text_color,
	}

	// Use the mouse directly instead of the `.Hovered` interest: focus and the
	// caret should react on the click frame, not one frame later.
	origin := ui.get_screen_pos()
	mouse := ui.ctx.callbacks.get_mouse_pos()
	inside :=
		mouse.x >= origin.x &&
		mouse.y >= origin.y &&
		mouse.x <= origin.x + size.x &&
		mouse.y <= origin.y + size.y

	ui.scope(size)

	inner_x := style.padding
	inner_w := max(1, size.x - style.padding * 2)
	text_y := (size.y - style.font_size) * 0.5

	// Focus and caret placement.
	if rl.IsMouseButtonPressed(.LEFT) {
		if inside {
			focused = id
			state.blink = 0
			index := caret_at(current, &opts, mouse.x - origin.x - inner_x + state.scroll_x)
			state.edit.selection = {index, index}
		} else if focused == id {
			focused = 0
		}
	} else if focused == id && rl.IsMouseButtonDown(.LEFT) {
		state.edit.selection[0] = caret_at(
			current,
			&opts,
			mouse.x - origin.x - inner_x + state.scroll_x,
		)
	}

	if focused == id {
		submitted, changed = handle_keyboard(state)
	}

	current = strings.to_string(state.builder)
	caret := clamp(state.edit.selection[0], 0, len(current))

	// Keep the caret inside the visible area.
	caret_x := measure(current[:caret], &opts)
	if caret_x - state.scroll_x > inner_w do state.scroll_x = caret_x - inner_w
	if caret_x - state.scroll_x < 0 do state.scroll_x = caret_x
	state.scroll_x = max(0, state.scroll_x)

	{
		ui.scope_at({inner_x, 0}, {inner_w, size.y}, {.Clip})

		if focused == id {
			if start, end := edit.sorted_selection(&state.edit); start != end {
				x0 := measure(current[:start], &opts)
				x1 := measure(current[:end], &opts)
				ui.draw_rect(
					{x0 - state.scroll_x, text_y},
					{x1 - x0, style.font_size},
					style.selection_color,
				)
			}
		}

		if len(current) > 0 {
			ui.scope_at({-state.scroll_x, text_y}, {ui.AUTO, style.font_size})
			ui.text(ui.id(id, "text"), {ui.AUTO, style.font_size}, current, opts)
		} else if len(placeholder) > 0 {
			placeholder_opts := opts
			placeholder_opts.font_color = style.placeholder_color

			ui.scope_at({-state.scroll_x, text_y}, {ui.AUTO, style.font_size})
			ui.text(ui.id(id, "placeholder"), {ui.AUTO, style.font_size}, placeholder, placeholder_opts)
		}

		if focused == id && state.blink < CARET_BLINK {
			ui.draw_rect(
				{caret_x - state.scroll_x, text_y},
				{CARET_WIDTH, style.font_size},
				style.caret_color,
			)
		}
	}

	// Publish the buffer as the caller's borrowed string. No copy: `text^` is a
	// slice of the builder.
	text^ = strings.to_string(state.builder)

	return changed, submitted
}

@(private = "file")
handle_keyboard :: proc(state: ^Line_Edit) -> (submitted: bool, changed: bool) {
	state.blink += f64(rl.GetFrameTime())
	state.blink = state.blink - f64(int(state.blink))

	edit.update_time(&state.edit)

	for char := rl.GetCharPressed(); char > 0; char = rl.GetCharPressed() {
		edit.input_rune(&state.edit, char)
		state.blink = 0
		changed = true
	}

	ctrl :=
		rl.IsKeyDown(.LEFT_CONTROL) ||
		rl.IsKeyDown(.RIGHT_CONTROL) ||
		rl.IsKeyDown(.LEFT_SUPER) ||
		rl.IsKeyDown(.RIGHT_SUPER)
	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)

	if ctrl && rl.IsKeyPressed(.C) do edit.perform_command(&state.edit, .Copy)
	if ctrl && rl.IsKeyPressed(.A) do edit.perform_command(&state.edit, .Select_All)
	if ctrl && rl.IsKeyPressed(.V) {
		edit.perform_command(&state.edit, .Paste)
		changed = true
	}
	if ctrl && rl.IsKeyPressed(.X) {
		edit.perform_command(&state.edit, .Cut)
		changed = true
	}
	if ctrl && rl.IsKeyPressed(.Z) {
		edit.perform_command(&state.edit, .Undo)
		changed = true
	}
	if ctrl && rl.IsKeyPressed(.Y) {
		edit.perform_command(&state.edit, .Redo)
		changed = true
	}
	if rl.IsKeyPressed(.HOME) do edit.perform_command(&state.edit, shift ? .Select_Start : .Start)
	if rl.IsKeyPressed(.END) do edit.perform_command(&state.edit, shift ? .Select_End : .End)

	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) {
		submitted = true
		state.blink = 0
	}

	if rl.IsKeyPressed(.ESCAPE) {
		focused = 0
	}

	// Held keys repeat after a delay.
	active_command := edit.Command.None
	active_key := rl.KeyboardKey.KEY_NULL

	if rl.IsKeyDown(.BACKSPACE) {
		active_key = .BACKSPACE
		active_command = ctrl ? .Delete_Word_Left : .Backspace
	} else if rl.IsKeyDown(.DELETE) {
		active_key = .DELETE
		active_command = ctrl ? .Delete_Word_Right : .Delete
	} else if rl.IsKeyDown(.LEFT) {
		active_key = .LEFT
		active_command =
			shift ? (ctrl ? .Select_Word_Left : .Select_Left) : (ctrl ? .Word_Left : .Left)
	} else if rl.IsKeyDown(.RIGHT) {
		active_key = .RIGHT
		active_command =
			shift ? (ctrl ? .Select_Word_Right : .Select_Right) : (ctrl ? .Word_Right : .Right)
	}

	if active_command != .None {
		state.blink = 0

		if state.repeat.key != active_key {
			state.repeat.key = active_key
			state.repeat.command = active_command
			state.repeat.timer = 0
			state.repeat.is_repeating = false
			edit.perform_command(&state.edit, active_command)
			if command_changes_text(active_command) do changed = true
		} else {
			state.repeat.timer += f64(rl.GetFrameTime())
			threshold := state.repeat.is_repeating ? REPEAT_INTERVAL : REPEAT_DELAY

			if state.repeat.timer >= threshold {
				edit.perform_command(&state.edit, active_command)
				if command_changes_text(active_command) do changed = true
				state.repeat.timer = 0
				state.repeat.is_repeating = true
			}
		}
	} else {
		state.repeat.key = .KEY_NULL
		state.repeat.command = .None
	}

	return submitted, changed
}

// Width of a prefix, in logical units, through the same font pipeline `ui.text`
// uses. Measuring a prefix is how the caret and the selection get their x.
@(private = "file")
measure :: proc(text: string, opts: ^ui.Text_Options) -> f64 {
	return ui.measure_text(ui.id("line_edit/measure"), {ui.AUTO, ui.AUTO}, text, opts).x
}

// Commands that edit the text, as opposed to moving the caret or copying.
@(private = "file")
command_changes_text :: proc(command: edit.Command) -> bool {
	#partial switch command {
	case .Backspace, .Delete, .Delete_Word_Left, .Delete_Word_Right:
		return true
	}
	return false
}

// Byte index of the caret closest to `x`, where `x` is in the text's own
// coordinate space (padding and scroll already removed).
@(private = "file")
caret_at :: proc(text: string, opts: ^ui.Text_Options, x: f64) -> int {
	if x <= 0 do return 0

	previous := 0.0
	index := 0

	for index < len(text) {
		_, rune_size := utf8.decode_rune(text[index:])
		next := index + rune_size
		width := measure(text[:next], opts)

		if x < width {
			if x - previous < width - x do return index
			return next
		}

		index = next
		previous = width
	}

	return len(text)
}

@(private = "file")
destroy_line_edit :: proc(state: ^Line_Edit) {
	edit.destroy(&state.edit)
	strings.builder_destroy(&state.builder)
}

@(private = "file")
clipboard_set :: proc(user_data: rawptr, text: string) -> bool {
	rl.SetClipboardText(strings.clone_to_cstring(text, context.temp_allocator))
	return true
}

@(private = "file")
clipboard_get :: proc(user_data: rawptr) -> (string, bool) {
	text := rl.GetClipboardText()
	if text == nil do return "", false
	return string(text), true
}



