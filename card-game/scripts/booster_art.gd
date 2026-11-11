class_name BoosterArt

const PACK_TEXTURE := preload("res://sprites/booster_pack.png")
const SHINE_SHADER := preload("res://shaders/booster_shine.gdshader")
const SHADING_MAP := preload("res://sprites/booster_pack_map.png")
const SHINE_STAGGER := 0.35
const PACK_COLOR := Color(0.8, 0.8, 0.84, 1)
const BADGE_RECT := Rect2i(8, 29, 27, 24)
const GLYPH_SCALE := 2
const BADGE_FILL := Color(0.97, 0.96, 0.92)
const BADGE_EDGE := Color(0.22, 0.21, 0.25)
const INK := {
	"#": Color(0.16, 0.15, 0.19),
	"w": Color(1.0, 1.0, 1.0),
	"f": Color(0.85, 0.55, 0.3),
	"o": Color(0.95, 0.35, 0.2),
	"y": Color(0.98, 0.78, 0.3),
	"s": Color(0.6, 0.6, 0.64),
}
const SYMBOLS := {
	"Common Pack": [
		"..#######..",
		"..#.....#..",
		"..#..#..#..",
		"..#.###.#..",
		"..#.###.#..",
		"..#.###.#..",
		"..#..#..#..",
		"..#.....#..",
		"..#.....#..",
		"..#######..",
	],
	"Random Pack": [
		"...#####...",
		"..##...##..",
		"..##...##..",
		".......##..",
		"......##...",
		".....##....",
		".....##....",
		"...........",
		".....##....",
		".....##....",
	],
	"Smoke Pack": [
		"........s..",
		".......s...",
		"........s..",
		".......s...",
		"...........",
		"...........",
		"###########",
		"#ff#wwwwwo#",
		"###########",
		"...........",
	],
	"Drink Pack": [
		".wwwwww....",
		".#######...",
		".#yyyyy####",
		".#yyyyy#..#",
		".#yyyyy#..#",
		".#yyyyy#..#",
		".#yyyyy####",
		".#yyyyy#...",
		".#yyyyy#...",
		".#######...",
	],
	"Special Pack": [
		".....#.....",
		"....###....",
		"....###....",
		"###########",
		".#########.",
		"..#######..",
		"..#######..",
		".####.####.",
		".###...###.",
		".#.......#.",
	],
	"Zero Pack": [
		"...#####...",
		"..###.###..",
		".###...###.",
		".###...###.",
		".###...###.",
		".###...###.",
		".###...###.",
		".###...###.",
		"..###.###..",
		"...#####...",
	],
}

static var _pack_cache := {}


static func pack_tint(booster: Dictionary) -> Color:
	return booster.get("tint", PACK_COLOR)


static func pack_texture(booster: Dictionary) -> Texture2D:
	var key := String(booster.get("name", ""))
	if not SYMBOLS.has(key):
		return PACK_TEXTURE
	if _pack_cache.has(key):
		return _pack_cache[key]
	var image := PACK_TEXTURE.get_image()
	image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	_draw_badge(image)
	_draw_symbol(image, SYMBOLS[key])
	var texture := ImageTexture.create_from_image(image)
	_pack_cache[key] = texture
	return texture


static func _draw_badge(image: Image) -> void:
	var r := BADGE_RECT
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var edge := x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1
			var corner := (x == r.position.x or x == r.end.x - 1) and (y == r.position.y or y == r.end.y - 1)
			if corner:
				continue
			image.set_pixel(x, y, BADGE_EDGE if edge else BADGE_FILL)


static func _draw_symbol(image: Image, rows: Array) -> void:
	var height := rows.size()
	var width := String(rows[0]).length()
	var origin := BADGE_RECT.position + (BADGE_RECT.size - Vector2i(width, height) * GLYPH_SCALE) / 2
	for y in height:
		var row := String(rows[y])
		for x in width:
			var key := row[x]
			if INK.has(key):
				image.fill_rect(Rect2i(origin + Vector2i(x, y) * GLYPH_SCALE, Vector2i.ONE * GLYPH_SCALE), INK[key])
