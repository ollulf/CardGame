extends RefCounted
class_name StampStandArt

const ROWS := [
	"...##.......##.......##.",
	"..#rr#.....#gg#.....#vv#",
	"..#rr#.....#gg#.....#vv#",
	"...##.......##.......##.",
	"...#m#.....#m#......#m#.",
	"...#m#.....#m#......#m#.",
	"..#bbb#...#bbb#....#bbb#",
	"..#kkk#...#kkk#....#kkk#",
	"########################",
	"#wwwwwwwwwwwwwwwwwwwwww#",
	"#wwppppppppwwwwwwwwwwww#",
	"#wwpiiiiiipwwwwwwwwwwww#",
	"#wwpiiiiiipwwwwwwwwwwww#",
	"#wwppppppppwwwwwwwwwwww#",
	"#dddddddddddddddddddddd#",
	"########################",
]
const PALETTE := {
	"#": Color("1a1412"),
	"r": Color("d8483c"),
	"g": Color("4fc4a0"),
	"v": Color("8a5ad8"),
	"m": Color("b8b0a0"),
	"b": Color("6a4a30"),
	"k": Color("2a2030"),
	"w": Color("8a5a34"),
	"d": Color("5a3820"),
	"p": Color("3a3a48"),
	"i": Color("3a5ab8"),
}

const SIGN_TEXT := "STAMPS"
const SIGN_BOARD := Color("f3e6c4")
const SIGN_INK := Color("1a1412")
const SIGN_HEIGHT := 9
const GLYPHS := {
	"S": ["###", "#..", "###", "..#", "###"],
	"T": ["###", ".#.", ".#.", ".#.", ".#."],
	"A": ["###", "#.#", "###", "#.#", "#.#"],
	"M": ["#.#", "###", "###", "#.#", "#.#"],
	"P": ["###", "#.#", "###", "#..", "#.."],
}

static var _texture: ImageTexture


static func texture() -> ImageTexture:
	if _texture != null:
		return _texture
	var stand_width := String(ROWS[0]).length()
	var width := SIGN_TEXT.length() * 4 + 3
	var image := Image.create(width, ROWS.size() + SIGN_HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_draw_sign(image, width)
	var stand_x := (width - stand_width) / 2
	for y in ROWS.size():
		var row: String = ROWS[y]
		for x in row.length():
			if PALETTE.has(row[x]):
				image.set_pixel(stand_x + x, SIGN_HEIGHT + y, PALETTE[row[x]])
	_texture = ImageTexture.create_from_image(image)
	return _texture


static func _draw_sign(image: Image, width: int) -> void:
	for y in SIGN_HEIGHT - 1:
		for x in width:
			var edge := x == 0 or x == width - 1 or y == 0 or y == SIGN_HEIGHT - 2
			image.set_pixel(x, y, SIGN_INK if edge else SIGN_BOARD)
	for i in SIGN_TEXT.length():
		var glyph: Array = GLYPHS[SIGN_TEXT[i]]
		for gy in glyph.size():
			var line: String = glyph[gy]
			for gx in line.length():
				if line[gx] == "#":
					image.set_pixel(2 + i * 4 + gx, 2 + gy, SIGN_INK)
