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

static var _texture: ImageTexture


static func texture() -> ImageTexture:
	if _texture != null:
		return _texture
	var width := String(ROWS[0]).length()
	var image := Image.create(width, ROWS.size(), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in ROWS.size():
		var row: String = ROWS[y]
		for x in row.length():
			if PALETTE.has(row[x]):
				image.set_pixel(x, y, PALETTE[row[x]])
	_texture = ImageTexture.create_from_image(image)
	return _texture
