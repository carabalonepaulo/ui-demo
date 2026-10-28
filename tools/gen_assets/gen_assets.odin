// Generates the demo image set used by the textures page.
//
//	odin run tools/gen_assets
//
// Writes assets/images/00.png, 01.webp, ... alternating the two formats so the
// cache exercises both raylib's decoder and the bundled libwebp.
package main

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

import webp "../../src/textures/webp"

COUNT :: 24
WIDTH :: 400
HEIGHT :: 300
DIR :: "assets/images"

main :: proc() {
	if !os.exists(DIR) {
		if err := os.make_directory(DIR); err != nil {
			fmt.eprintfln("cannot create %s: %v", DIR, err)
			return
		}
	}

	for i in 0 ..< COUNT {
		hue := f32(i) / f32(COUNT) * 360

		image := rl.GenImageGradientLinear(
			WIDTH,
			HEIGHT,
			c.int((i * 13) % 360),
			rl.ColorFromHSV(hue, 0.62, 0.32),
			rl.ColorFromHSV(hue + 55, 0.55, 0.92),
		)

		// A few shapes so every image is distinguishable at a glance.
		rl.ImageDrawCircle(
			&image,
			WIDTH / 3,
			HEIGHT / 2,
			HEIGHT / 5,
			rl.ColorFromHSV(hue + 180, 0.55, 0.95),
		)
		rl.ImageDrawRectangle(
			&image,
			WIDTH / 2,
			HEIGHT / 4,
			WIDTH / 3,
			HEIGHT / 10,
			{255, 255, 255, 190},
		)
		rl.ImageDrawRectangle(
			&image,
			WIDTH / 2,
			HEIGHT / 4 + HEIGHT / 6,
			WIDTH / 4,
			HEIGHT / 10,
			{0, 0, 0, 120},
		)

		use_webp := i % 2 == 1
		path := fmt.aprintf(
			"%s/%02d.%s",
			DIR,
			i,
			use_webp ? "webp" : "png",
			allocator = context.temp_allocator,
		)

		if use_webp {
			rl.ImageFormat(&image, .UNCOMPRESSED_R8G8B8A8)
			pixels := ([^]u8)(image.data)[:WIDTH * HEIGHT * 4]

			bytes, ok := webp.encode_rgba(pixels, WIDTH, HEIGHT, 0.88)
			if !ok {
				fmt.eprintfln("failed to encode %s", path)
			} else {
				if err := os.write_entire_file(path, bytes); err != nil {
					fmt.eprintfln("failed to write %s: %v", path, err)
				} else {
					fmt.println("wrote", path)
				}
				webp.free(bytes)
			}
		} else {
			name := strings.clone_to_cstring(path, context.temp_allocator)
			if rl.ExportImage(image, name) {
				fmt.println("wrote", path)
			} else {
				fmt.eprintfln("failed to write %s", path)
			}
		}

		rl.UnloadImage(image)
	}
}

