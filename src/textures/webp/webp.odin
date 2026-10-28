package webp

import "core:c"

@(export)
foreign import lib {"lib/libwebp.lib", "lib/libsharpyuv.lib"}

@(default_calling_convention = "c")
foreign lib {
	WebPDecodeRGBA :: proc(data: ^u8, data_size: c.size_t, width: ^c.int, height: ^c.int) -> ^u8 ---
	WebPEncodeRGBA :: proc(rgba: ^u8, width: c.int, height: c.int, stride: c.int, quality_factor: c.float, output: ^^u8) -> c.size_t ---
	WebPFree :: proc(ptr: rawptr) ---
}

decode_rgba :: proc(webp_bytes: []u8) -> (pixels: []u8, width: int, height: int, success: bool) {
	if len(webp_bytes) == 0 do return nil, 0, 0, false

	w, h: c.int
	raw_pixels := WebPDecodeRGBA(raw_data(webp_bytes), c.size_t(len(webp_bytes)), &w, &h)
	if raw_pixels == nil do return nil, 0, 0, false

	width = int(w)
	height = int(h)
	total_bytes := width * height * 4

	pixels = ([^]u8)(raw_pixels)[:total_bytes]
	return pixels, width, height, true
}

encode_rgba :: proc(
	rgba_pixels: []u8,
	width: int,
	height: int,
	quality: f32,
) -> (
	webp_bytes: []u8,
	success: bool,
) {
	if len(rgba_pixels) == 0 do return nil, false

	q_factor := c.float(quality * 100.0)
	if q_factor < 0.0 do q_factor = 0.0
	if q_factor > 100.0 do q_factor = 100.0

	stride := c.int(width * 4)

	output_ptr: ^u8 = nil
	encoded_size := WebPEncodeRGBA(
		raw_data(rgba_pixels),
		c.int(width),
		c.int(height),
		stride,
		q_factor,
		&output_ptr,
	)

	if encoded_size == 0 || output_ptr == nil do return nil, false

	webp_bytes = ([^]u8)(output_ptr)[:int(encoded_size)]
	return webp_bytes, true
}

free :: proc(buffer: []u8) {
	if len(buffer) > 0 {
		WebPFree(raw_data(buffer))
	}
}

