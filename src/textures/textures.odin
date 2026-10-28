// Package textures is a budgeted LRU cache for GPU textures.
//
// `get(path)` is safe to call every frame: it returns a texture immediately, or
// a placeholder while the file is being read. Files are read with nbio, so the
// cache needs the event loop to be ticked once per frame.
//
//	textures.init(16 * mem.Megabyte)
//	defer textures.deinit()
//
//	for !rl.WindowShouldClose() {
//	    nbio.tick(0)        // one tick, in the main loop
//	    textures.tick()     // uploads finished reads
//	    // draw, calling textures.get(path) for what is visible
//	}
//
// Resident pixel data is capped by the budget. When a new texture would exceed
// it, the least recently used textures are unloaded first. Unloading drops the
// entry: a later `get` starts the load again, which is a miss.
//
// Only textures requested during the current frame are guaranteed to stay
// resident. Draw a texture from the value `get` returned in the same frame.
package textures

import "core:mem"
import "core:nbio"
import "core:strings"
import rl "vendor:raylib"

import "webp"

DEFAULT_BUDGET :: 8 * mem.Megabyte
PLACEHOLDER_PIXELS :: 16

Status :: enum {
	// The file is being read, or the pixels are waiting to be uploaded.
	Loading,
	Ready,
	Failed,
}

Entry :: struct {
	path:    string,
	status:  Status,
	// Last time `get` returned this entry.
	tick:    u64,
	texture: rl.Texture2D,
	bytes:   int,
	// Raw file bytes, owned, until the next `tick` decodes and uploads them.
	data:    []u8,
	prev:    ^Entry,
	next:    ^Entry,
}

Stats :: struct {
	budget:    int,
	used:      int,
	entries:   int,
	ready:     int,
	loading:   int,
	failed:    int,
	evictions: u64,
	hits:      u64,
	misses:    u64,
	uploads:   u64,
}

State :: struct {
	entries:     map[string]^Entry,
	// Most recently used first, least recently used last.
	head:        ^Entry,
	tail:        ^Entry,
	placeholder: rl.Texture2D,
	budget:      int,
	used:        int,
	tick:        u64,
	allocator:   mem.Allocator,
	initialized: bool,
	hits:        u64,
	misses:      u64,
	evictions:   u64,
	uploads:     u64,
}

@(private = "file")
state: State

// init creates the placeholder texture and the cache. It needs a window/GL
// context. `budget` is the cap on resident pixel data, in bytes.
init :: proc(budget := DEFAULT_BUDGET) {
	assert(!state.initialized, "textures.init called twice")

	state.allocator = context.allocator
	state.budget = max(budget, 0)
	state.entries = make(map[string]^Entry, 64, state.allocator)

	// A recognizable checker, so a pending tile reads as "loading" and not as a
	// broken image.
	image := rl.GenImageChecked(
		PLACEHOLDER_PIXELS,
		PLACEHOLDER_PIXELS,
		4,
		4,
		{34, 37, 44, 255},
		{26, 29, 35, 255},
	)
	state.placeholder = rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	rl.SetTextureFilter(state.placeholder, .POINT)

	state.initialized = true
}

// deinit waits for in-flight reads and releases every texture. Call it before
// releasing the nbio event loop and before closing the window.
deinit :: proc() {
	if !state.initialized do return

	// Callbacks still write into entry memory, so drain the event loop first.
	nbio.run()

	for _, entry in state.entries {
		lru_remove(entry)
		destroy(entry)
	}

	delete(state.entries)
	state.entries = nil

	if state.placeholder.id != 0 do rl.UnloadTexture(state.placeholder)
	state.placeholder = {}
	state.head = nil
	state.tail = nil
	state.used = 0
	state.initialized = false
}

// tick advances the LRU clock and uploads the reads that finished. Call it once
// per frame, after ticking nbio.
tick :: proc() {
	assert(state.initialized, "textures.init was not called")

	state.tick += 1
	upload_pending()
}

// get returns the texture for `path`, or the placeholder while it loads. Call it
// every frame for every texture that is on screen: that is what marks it as
// recently used.
get :: proc(path: string) -> rl.Texture2D {
	assert(state.initialized, "textures.init was not called")

	if entry, ok := state.entries[path]; ok {
		touch(entry)
		state.hits += 1
		return entry.status == .Ready ? entry.texture : state.placeholder
	}

	entry := new(Entry, state.allocator)
	entry.path = strings.clone(path, state.allocator)
	entry.status = .Loading
	entry.tick = state.tick

	state.entries[entry.path] = entry
	lru_push_front(entry)
	state.misses += 1

	nbio.read_entire_file(entry.path, entry, on_read, state.allocator)

	return state.placeholder
}

is_ready :: proc(path: string) -> bool {
	if entry, ok := state.entries[path]; ok do return entry.status == .Ready
	return false
}

// size_of returns the pixel size of a resident texture, or zeros.
size_of :: proc(path: string) -> (width, height: int) {
	if entry, ok := state.entries[path]; ok && entry.status == .Ready {
		return int(entry.texture.width), int(entry.texture.height)
	}
	return 0, 0
}

placeholder :: proc() -> rl.Texture2D {
	return state.placeholder
}

// set_budget changes the cap and unloads least recently used textures until the
// cache fits again.
set_budget :: proc(budget: int) {
	assert(state.initialized, "textures.init was not called")

	state.budget = max(budget, 0)
	make_space(nil)
}

stats :: proc() -> Stats {
	result: Stats
	result.budget = state.budget
	result.used = state.used
	result.hits = state.hits
	result.misses = state.misses
	result.evictions = state.evictions
	result.uploads = state.uploads

	for _, entry in state.entries {
		result.entries += 1
		switch entry.status {
		case .Loading:
			result.loading += 1
		case .Ready:
			result.ready += 1
		case .Failed:
			result.failed += 1
		}
	}

	return result
}

// ---------------------------------------------------------------------------

@(private = "file")
on_read :: proc(user_data: rawptr, data: []byte, err: nbio.Read_Entire_File_Error) {
	entry := cast(^Entry)user_data

	if err != {} || len(data) == 0 {
		if data != nil do delete(data, state.allocator)
		entry.status = .Failed
		return
	}

	// The callback owns the buffer. Keep it until the next tick uploads it.
	entry.data = data
}

@(private = "file")
upload_pending :: proc() {
	// Eviction mutates the map, so collect the finished reads first.
	pending: [dynamic]^Entry
	defer delete(pending)

	for _, entry in state.entries {
		if entry.data == nil do continue
		if pending == nil do pending = make([dynamic]^Entry, 0, len(state.entries), state.allocator)
		append(&pending, entry)
	}

	for entry in pending {
		data := entry.data
		entry.data = nil

		texture, width, height, ok := decode(data, entry.path)
		delete(data, state.allocator)

		if !ok {
			entry.status = .Failed
			continue
		}

		entry.texture = texture
		entry.bytes = width * height * 4
		entry.status = .Ready
		entry.tick = state.tick
		state.used += entry.bytes
		state.uploads += 1

		make_space(entry)
	}
}

@(private = "file")
decode :: proc(
	data: []u8,
	path: string,
) -> (
	texture: rl.Texture2D,
	width, height: int,
	ok: bool,
) {
	if is_webp(data) {
		pixels, w, h, decoded := webp.decode_rgba(data)
		if !decoded do return {}, 0, 0, false

		image := rl.Image {
			data    = raw_data(pixels),
			width   = i32(w),
			height  = i32(h),
			mipmaps = 1,
			format  = .UNCOMPRESSED_R8G8B8A8,
		}
		texture = rl.LoadTextureFromImage(image)
		webp.free(pixels)

		width, height = w, h
	} else {
		extension := rl.GetFileExtension(strings.clone_to_cstring(path, context.temp_allocator))
		image := rl.LoadImageFromMemory(extension, raw_data(data), i32(len(data)))
		if image.data == nil do return {}, 0, 0, false

		rl.ImageFormat(&image, .UNCOMPRESSED_R8G8B8A8)
		width, height = int(image.width), int(image.height)
		texture = rl.LoadTextureFromImage(image)
		rl.UnloadImage(image)
	}

	if texture.id == 0 do return {}, 0, 0, false

	rl.SetTextureFilter(texture, .BILINEAR)
	return texture, width, height, true
}

@(private = "file")
is_webp :: proc(data: []u8) -> bool {
	if len(data) < 12 do return false
	return data[0] == 'R' &&
	       data[1] == 'I' &&
	       data[2] == 'F' &&
	       data[3] == 'F' &&
	       data[8] == 'W' &&
	       data[9] == 'E' &&
	       data[10] == 'B' &&
	       data[11] == 'P'
}

// Unloads least recently used textures until `used` fits the budget. `protect`
// is the entry that just finished uploading and must not be evicted.
@(private = "file")
make_space :: proc(protect: ^Entry) {
	for state.used > state.budget {
		victim := state.tail
		for victim != nil {
			if victim != protect && victim.status == .Ready do break
			victim = victim.prev
		}
		if victim == nil do break

		evict(victim)
	}
}

@(private = "file")
evict :: proc(entry: ^Entry) {
	state.used -= entry.bytes
	state.evictions += 1
	release(entry)
}

@(private = "file")
release :: proc(entry: ^Entry) {
	lru_remove(entry)
	delete_key(&state.entries, entry.path)
	destroy(entry)
}

@(private = "file")
destroy :: proc(entry: ^Entry) {
	if entry.texture.id != 0 do rl.UnloadTexture(entry.texture)
	if entry.data != nil do delete(entry.data, state.allocator)

	delete(entry.path, state.allocator)
	free(entry, state.allocator)
}

@(private = "file")
touch :: proc(entry: ^Entry) {
	entry.tick = state.tick

	if state.head == entry do return

	lru_remove(entry)
	lru_push_front(entry)
}

@(private = "file")
lru_remove :: proc(entry: ^Entry) {
	if entry.prev != nil {
		entry.prev.next = entry.next
	} else if state.head == entry {
		state.head = entry.next
	}

	if entry.next != nil {
		entry.next.prev = entry.prev
	} else if state.tail == entry {
		state.tail = entry.prev
	}

	entry.prev = nil
	entry.next = nil
}

@(private = "file")
lru_push_front :: proc(entry: ^Entry) {
	entry.prev = nil
	entry.next = state.head

	if state.head != nil do state.head.prev = entry
	state.head = entry

	if state.tail == nil do state.tail = entry
}
