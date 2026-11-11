extends RefCounted
class_name StampArt

const SIZE := 15
const RIM := 7.3
const RING_IN := 5.5
const RING_OUT := 6.3
const TOOL_SIZE := Vector2i(11, 16)
const OUTLINE := Color("1a1412")
const WOOD := Color("5a3820")
const WOOD_LIGHT := Color("8a5a34")
const WOOD_DARK := Color("3a2618")
const RUBBER := Color("161216")
const GLYPHS := {
	CardStamp.Id.COLORLESS: [
		"..###..",
		".#...#.",
		"#...#.#",
		"#..#..#",
		"#.#...#",
		".#...#.",
		"..###..",
	],
	CardStamp.Id.DRAW_FIRST: [
		"...#...",
		"..###..",
		".#####.",
		"...#...",
		"...#...",
		".#####.",
	],
	CardStamp.Id.PLUS_2: [
		"....###",
		".#....#",
		"###.###",
		".#..#..",
		"....###",
	],
	CardStamp.Id.PLUS_3: [
		"....###",
		".#....#",
		"###.###",
		".#....#",
		"....###",
	],
	CardStamp.Id.PLUS_4: [
		"....#.#",
		".#..#.#",
		"###.###",
		".#....#",
		"......#",
	],
	CardStamp.Id.GAMBLE: [
		"...#...",
		".#####.",
		"#..#...",
		".#####.",
		"...#..#",
		".#####.",
		"...#...",
	],
	CardStamp.Id.ZERO: [
		"..###..",
		".#...#.",
		".#..##.",
		".#.#.#.",
		".##..#.",
		".#...#.",
		"..###..",
	],
}

static var _imprints := {}
static var _tools := {}


static func imprint(id: int) -> ImageTexture:
	if _imprints.has(id):
		return _imprints[id]
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ink := CardStamp.color(id)
	var mask := _glyph_mask(id)
	var center := Vector2(SIZE, SIZE) * 0.5
	for y in SIZE:
		for x in SIZE:
			var d := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(center)
			if d > RIM or mask.has(Vector2i(x, y)):
				continue
			var roll := _roll(x, y, id)
			if d > RING_OUT + 0.5 and roll < 14:
				continue
			if d > RING_IN and d <= RING_OUT and roll < 5:
				continue
			var shade := ink
			if d > RING_OUT:
				shade = ink.darkened(0.3)
			elif roll < 12:
				shade = ink.lightened(0.15)
			image.set_pixel(x, y, shade)
	_imprints[id] = ImageTexture.create_from_image(image)
	return _imprints[id]


static func tool(id: int) -> ImageTexture:
	if _tools.has(id):
		return _tools[id]
	var image := Image.create(TOOL_SIZE.x, TOOL_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var knob := CardStamp.color(id).darkened(0.15)
	_fill(image, Rect2i(3, 0, 5, 1), OUTLINE)
	_fill(image, Rect2i(2, 1, 7, 4), OUTLINE)
	_fill(image, Rect2i(3, 1, 5, 4), knob)
	_fill(image, Rect2i(3, 1, 2, 1), knob.lightened(0.3))
	_fill(image, Rect2i(6, 4, 2, 1), knob.darkened(0.3))
	_fill(image, Rect2i(4, 5, 3, 4), OUTLINE)
	_fill(image, Rect2i(5, 5, 1, 4), WOOD_LIGHT)
	_fill(image, Rect2i(0, 9, 11, 5), OUTLINE)
	_fill(image, Rect2i(1, 10, 9, 3), WOOD)
	_fill(image, Rect2i(1, 10, 9, 1), WOOD_LIGHT)
	_fill(image, Rect2i(1, 12, 9, 1), WOOD_DARK)
	_fill(image, Rect2i(0, 14, 11, 2), RUBBER)
	_fill(image, Rect2i(1, 15, 9, 1), CardStamp.color(id).darkened(0.35))
	_tools[id] = ImageTexture.create_from_image(image)
	return _tools[id]


static func _glyph_mask(id: int) -> Dictionary:
	var mask := {}
	var glyph: Array = GLYPHS.get(id, [])
	if glyph.is_empty():
		return mask
	var origin := Vector2i(((Vector2(SIZE, SIZE) - Vector2(String(glyph[0]).length(), glyph.size())) * 0.5).floor())
	for y in glyph.size():
		var row: String = glyph[y]
		for x in row.length():
			if row[x] == "#":
				mask[origin + Vector2i(x, y)] = true
	return mask


static func _roll(x: int, y: int, id: int) -> int:
	return absi(hash(Vector3i(x * 7 + 3, y * 13 + 1, id * 31))) % 100


static func _fill(image: Image, area: Rect2i, color: Color) -> void:
	image.fill_rect(area, color)
