// A multi-line text editor.
//
//	changed, submitted := components.multiline_edit(
//		ui.id("body"),
//		&self.text,
//		area,
//		components.MULTILINE_EDIT,
//		"Write something…",
//	)
//
// Same contract as `line_edit`: `text^` is the caller's source of truth and,
// after each call, points at the editor's internal builder (borrowed until the
// next call). Enter inserts a newline; Ctrl+Enter reports `submitted`. Tab
// inserts four spaces. Up/Down keep the preferred column, Home/End work per
// line, and Ctrl+Home/End jump to the ends of the document.
//
// Lines are hard-split on newlines (no soft wrapping): long lines scroll
// horizontally, and the caret is kept visible vertically and horizontally.
// Selection, undo/redo, clipboard and key repeat come from `core:text/edit`,
// the same engine as `line_edit`.
package components

import "core:mem"
import "core:strings"
import "core:text/edit"
import "core:unicode/utf8"
import rl "vendor:raylib"
import ui "ui:."

Multiline_Edit_Style :: struct {
	font:              ui.Font,
	font_size:         f64,
	letter_spacing:    f64,
	line_spacing:      f64,
	padding:           f64,
	text_color:        ui.Color,
	caret_color:       ui.Color,
	selection_color:   ui.Color,
	placeholder_color: ui.Color,
}

MULTILINE_EDIT :: Multiline_Edit_Style {
	font_size         = 14,
	letter_spacing    = 0,
	line_spacing      = 4,
	padding           = 10,
	text_color        = {232, 236, 244, 255},
	caret_color       = {94, 234, 212, 255},
	selection_color   = {94, 234, 212, 70},
	placeholder_color = {92, 101, 117, 255},
}

// A line is [start, end) in the text, without the newline.
@(private = "file")
Line :: struct {
	start, end: int,
}

@(private = "file")
Multiline_Edit :: struct {
	builder:   strings.Builder,
	edit:      edit.State,
	repeat:    Input_Repeat,
	lines:     [dynamic]Line,
	scroll_x:  f64,
	scroll_y:  f64,
	desired_x: f64,
	blink:     f64,
	allocator: mem.Allocator,
}

multiline_edit :: proc(
	id: ui.Id,
	text: ^string,
	size: ui.Vec2,
	style: Multiline_Edit_Style,
	placeholder := "",
	allocator := context.allocator,
) -> (
	changed: bool,
	submitted: bool,
) {
	state, created := ui.get(ui.id(id, "multiline_edit"), Multiline_Edit, destroy = destroy_multiline_edit)
	if created {
		state.allocator = allocator
		state.builder = strings.builder_make_none(allocator)
		state.lines = make([dynamic]Line, 0, 16, allocator)
		edit.init(&state.edit, allocator, allocator)
		state.edit.set_clipboard = clipboard_set
		state.edit.get_clipboard = clipboard_get_multiline
		edit.setup_once(&state.edit, &state.builder)
		state.edit.selection = {0, 0}
	}

	current := strings.to_string(state.builder)
	if current != text^ {
		strings.builder_reset(&state.builder)
		strings.write_string(&state.builder, normalize_newlines(text^, "\n"))
		// Caret at the end, no selection.
		state.edit.selection = {len(state.builder.buf), len(state.builder.buf)}
		state.scroll_x = 0
		state.scroll_y = 0
		state.desired_x = 0
		current = strings.to_string(state.builder)
	}

	opts := ui.Text_Options {
		wrap           = .None,
		font           = style.font,
		font_size      = style.font_size,
		letter_spacing = style.letter_spacing,
		font_color     = style.text_color,
	}

	ui.scope(size)
	origin := ui.get_screen_pos()
	mouse := mouse_pos()
	inside := point_in_rect(origin, size, mouse)

	inner_x := style.padding
	inner_y := style.padding
	inner_w := max(1, size.x - style.padding * 2)
	inner_h := max(1, size.y - style.padding * 2)
	line_height := style.font_size + style.line_spacing

	build_lines(current, &state.lines)

	// Focus and caret placement.
	if rl.IsMouseButtonPressed(.LEFT) {
		if inside {
			focused = id
			state.blink = 0
			index := caret_from_mouse(state, current, &opts, mouse, origin, inner_x, inner_y, line_height)
			state.edit.selection = {index, index}
		} else if focused == id {
			focused = 0
		}
	} else if focused == id && rl.IsMouseButtonDown(.LEFT) {
		state.edit.selection[0] = caret_from_mouse(
			state,
			current,
			&opts,
			mouse,
			origin,
			inner_x,
			inner_y,
			line_height,
		)
	}

	vertical_held := false
	if focused == id {
		submitted, changed, vertical_held = handle_multiline_keyboard(state, current, &opts)
	}

	current = strings.to_string(state.builder)
	build_lines(current, &state.lines)

	caret := clamp(state.edit.selection[0], 0, len(current))
	caret_line := line_of(state.lines[:], caret)
	caret_row := state.lines[caret_line]
	caret_x := measure(current[caret_row.start:caret], &opts)
	caret_y := f64(caret_line) * line_height

	// Keep the caret visible. Vertical scroll snaps to lines, horizontal scroll
	// follows the caret's own line.
	if caret_y - state.scroll_y < 0 do state.scroll_y = caret_y
	if caret_y + line_height - state.scroll_y > inner_h {
		state.scroll_y = caret_y + line_height - inner_h
	}
	content_height := f64(len(state.lines)) * line_height
	state.scroll_y = clamp(state.scroll_y, 0, max(0, content_height - inner_h))

	if caret_x - state.scroll_x > inner_w do state.scroll_x = caret_x - inner_w
	if caret_x - state.scroll_x < 0 do state.scroll_x = caret_x
	state.scroll_x = max(0, state.scroll_x)

	// A vertical move keeps the preferred column for the next one.
	if !vertical_held do state.desired_x = caret_x

	{
		ui.scope_at({inner_x, inner_y}, {inner_w, inner_h}, {.Clip})

		first_line := max(0, int(state.scroll_y / line_height))
		last_line := min(len(state.lines) - 1, int((state.scroll_y + inner_h) / line_height) + 1)

		sel_lo, sel_hi := edit.sorted_selection(&state.edit)
		if sel_lo != sel_hi {
			for i in first_line ..= last_line {
				row := state.lines[i]
				lo := clamp(sel_lo, row.start, row.end)
				hi := clamp(sel_hi, row.start, row.end)
				y := f64(i) * line_height - state.scroll_y

				if hi > lo {
					x0 := measure(current[row.start:lo], &opts)
					x1 := measure(current[row.start:hi], &opts)
					ui.draw_rect(
						{x0 - state.scroll_x, y},
						{x1 - x0, style.font_size},
						style.selection_color,
					)
				} else if row.start == row.end && sel_lo <= row.start && row.start < sel_hi {
					// Empty line inside the selection: leave a marker.
					ui.draw_rect({-state.scroll_x, y}, {2, style.font_size}, style.selection_color)
				}
			}
		}

		for i in first_line ..= last_line {
			row := state.lines[i]
			if row.start == row.end do continue

			{
				ui.scope_at(
					{-state.scroll_x, f64(i) * line_height - state.scroll_y},
					{ui.AUTO, style.font_size},
				)
				ui.text(
					ui.id(id, "line", i),
					{ui.AUTO, style.font_size},
					current[row.start:row.end],
					opts,
				)
			}
		}

		if len(current) == 0 && len(placeholder) > 0 {
			placeholder_opts := opts
			placeholder_opts.font_color = style.placeholder_color

			ui.scope_at({-state.scroll_x, 0}, {ui.AUTO, style.font_size})
			ui.text(ui.id(id, "placeholder"), {ui.AUTO, style.font_size}, placeholder, placeholder_opts)
		}

		if focused == id && state.blink < CARET_BLINK {
			ui.draw_rect(
				{caret_x - state.scroll_x, caret_y - state.scroll_y},
				{CARET_WIDTH, style.font_size},
				style.caret_color,
			)
		}
	}

	// Publish the buffer as the caller's borrowed string.
	text^ = strings.to_string(state.builder)

	return changed, submitted
}

@(private = "file")
handle_multiline_keyboard :: proc(
	state: ^Multiline_Edit,
	text: string,
	opts: ^ui.Text_Options,
) -> (
	submitted: bool,
	changed: bool,
	vertical_held: bool,
) {
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

	// Enter breaks the line; Ctrl+Enter submits.
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) {
		if ctrl {
			submitted = true
		} else {
			edit.perform_command(&state.edit, .New_Line)
			changed = true
		}
		state.blink = 0
	}

	// Tab inserts spaces: a raw tab would need tab stops in the layout.
	if rl.IsKeyPressed(.TAB) && !ctrl {
		edit.input_text(&state.edit, "    ")
		changed = true
		state.blink = 0
	}

	caret := clamp(state.edit.selection[0], 0, len(text))
	line_start, line_end := line_bounds(text, caret)
	state.edit.line_start = line_start
	state.edit.line_end = line_end

	if rl.IsKeyPressed(.HOME) {
		command := edit.Command.Line_Start
		if ctrl {
			command = shift ? .Select_Start : .Start
		} else if shift {
			command = .Select_Line_Start
		}
		edit.perform_command(&state.edit, command)
		state.blink = 0
	}
	if rl.IsKeyPressed(.END) {
		command := edit.Command.Line_End
		if ctrl {
			command = shift ? .Select_End : .End
		} else if shift {
			command = .Select_Line_End
		}
		edit.perform_command(&state.edit, command)
		state.blink = 0
	}

	delta := 0
	if rl.IsKeyDown(.UP) {
		delta = -1
	} else if rl.IsKeyDown(.DOWN) {
		delta = 1
	}

	active_command := edit.Command.None
	active_key := rl.KeyboardKey.KEY_NULL

	if delta != 0 {
		vertical_held = true
		state.blink = 0
		key := delta < 0 ? rl.KeyboardKey.UP : .DOWN

		move := false
		if state.repeat.key != key {
			state.repeat.key = key
			state.repeat.timer = 0
			state.repeat.is_repeating = false
			move = true
		} else {
			state.repeat.timer += f64(rl.GetFrameTime())
			threshold := state.repeat.is_repeating ? REPEAT_INTERVAL : REPEAT_DELAY
			if state.repeat.timer >= threshold {
				move = true
				state.repeat.timer = 0
				state.repeat.is_repeating = true
			}
		}

		if move {
			target := vertical_target(state, text, opts, delta)
			if shift {
				state.edit.selection[0] = target
			} else {
				state.edit.selection = {target, target}
			}
		}
	} else if rl.IsKeyDown(.BACKSPACE) {
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
	} else if delta == 0 {
		state.repeat.key = .KEY_NULL
		state.repeat.command = .None
	}

	return submitted, changed, vertical_held
}

// Byte index closest to the mouse, in the whole text.
@(private = "file")
caret_from_mouse :: proc(
	state: ^Multiline_Edit,
	text: string,
	opts: ^ui.Text_Options,
	mouse, origin: ui.Vec2,
	inner_x, inner_y, line_height: f64,
) -> int {
	if len(state.lines) == 0 do return 0

	local_y := mouse.y - origin.y - inner_y + state.scroll_y
	line_index := clamp(int(local_y / line_height), 0, len(state.lines) - 1)
	row := state.lines[line_index]

	local_x := mouse.x - origin.x - inner_x + state.scroll_x
	return row.start + caret_at(text[row.start:row.end], opts, local_x)
}

// One line up or down, keeping the preferred column.
@(private = "file")
vertical_target :: proc(
	state: ^Multiline_Edit,
	text: string,
	opts: ^ui.Text_Options,
	delta: int,
) -> int {
	caret := clamp(state.edit.selection[0], 0, len(text))
	current_line := line_of(state.lines[:], caret)
	target_line := clamp(current_line + delta, 0, len(state.lines) - 1)
	if target_line == current_line do return caret

	row := state.lines[target_line]
	return row.start + caret_at(text[row.start:row.end], opts, state.desired_x)
}

@(private = "file")
line_of :: proc(lines: []Line, index: int) -> int {
	for row, i in lines {
		if index <= row.end do return i
	}
	return len(lines) - 1
}

@(private = "file")
line_bounds :: proc(text: string, index: int) -> (start, end: int) {
	index := clamp(index, 0, len(text))

	start = index
	for start > 0 && text[start - 1] != '\n' do start -= 1

	end = index
	for end < len(text) && text[end] != '\n' do end += 1

	return
}

@(private = "file")
build_lines :: proc(text: string, lines: ^[dynamic]Line) {
	clear(lines)

	start := 0
	for i in 0 ..< len(text) {
		if text[i] == '\n' {
			append(lines, Line{start, i})
			start = i + 1
		}
	}
	append(lines, Line{start, len(text)})
}

@(private = "file")
clipboard_get_multiline :: proc(user_data: rawptr) -> (string, bool) {
	text := rl.GetClipboardText()
	if text == nil do return "", false
	return normalize_newlines(string(text), "\n"), true
}

@(private = "file")
destroy_multiline_edit :: proc(state: ^Multiline_Edit) {
	edit.destroy(&state.edit)
	strings.builder_destroy(&state.builder)
	delete(state.lines)
}




