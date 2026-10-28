package components

import "core:strings"
import "core:text/edit"
import "core:unicode/utf8"
import rl "vendor:raylib"
import ui "ui:."

// Shared pieces of the text editors (`line_edit`, `multiline_edit`).

// Repeats a held key after a delay.
Input_Repeat :: struct {
	command:      edit.Command,
	key:          rl.KeyboardKey,
	timer:        f64,
	is_repeating: bool,
}

// Width of a prefix, in logical units, through the same font pipeline `ui.text`
// uses. Measuring a prefix is how the caret and the selection get their x.
measure :: proc(text: string, opts: ^ui.Text_Options) -> f64 {
	return ui.measure_text(ui.id("edit/measure"), {ui.AUTO, ui.AUTO}, text, opts).x
}

// Byte slice holding the first `count` runes of `text`.
prefix_runes :: proc(text: string, count: int) -> string {
	index := 0
	for _ in 0 ..< count {
		if index >= len(text) do break
		_, size := utf8.decode_rune(text[index:])
		index += size
	}
	return text[:index]
}

// Byte index of the first character of rune number `count`.
byte_index_of_rune :: proc(text: string, count: int) -> int {
	index := 0
	for _ in 0 ..< count {
		if index >= len(text) do break
		_, size := utf8.decode_rune(text[index:])
		index += size
	}
	return index
}

// Byte index of the caret closest to `x`, where `x` is in the text's own
// coordinate space (padding and scroll already removed).
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

// Commands that edit the text, as opposed to moving the caret or copying.
command_changes_text :: proc(command: edit.Command) -> bool {
	#partial switch command {
	case .Backspace, .Delete, .Delete_Word_Left, .Delete_Word_Right, .New_Line:
		return true
	}
	return false
}

clipboard_set :: proc(user_data: rawptr, text: string) -> bool {
	rl.SetClipboardText(strings.clone_to_cstring(text, context.temp_allocator))
	return true
}

clipboard_get :: proc(user_data: rawptr) -> (string, bool) {
	text := rl.GetClipboardText()
	if text == nil do return "", false
	return string(text), true
}

// Replaces CRLF and CR with `replacement` (usually "\n" or " ").
@(private)
normalize_newlines :: proc(text: string, replacement: string) -> string {
	if !strings.contains_rune(text, '\r') && !strings.contains_rune(text, '\n') do return text

	builder := strings.builder_make(context.temp_allocator)
	index := 0
	for index < len(text) {
		character, size := utf8.decode_rune(text[index:])

		if character == '\r' {
			index += size
			if index < len(text) && text[index] == '\n' do index += 1
			strings.write_string(&builder, replacement)
			continue
		}

		if character == '\n' {
			index += size
			strings.write_string(&builder, replacement)
			continue
		}

		strings.write_string(&builder, text[index:index + size])
		index += size
	}

	return strings.to_string(builder)
}


@(private)
clipboard_get_single :: proc(user_data: rawptr) -> (string, bool) {
	text := rl.GetClipboardText()
	if text == nil do return "", false
	return normalize_newlines(string(text), " "), true
}
