extends RefCounted
class_name HorstArt

const SIZE := Vector2i(36, 66)
const OUTLINE := Color("1a1412")
const SKIN := Color("c9a07a")
const SKIN_DARK := Color("a37e5c")
const HAIR := Color("b0aca4")
const EYE := Color("2a2020")
const CARDIGAN := Color("7a5a2e")
const CARDIGAN_DARK := Color("64481f")
const SHIRT := Color("c8c0a8")
const BUTTON := Color("3a2a18")
const TROUSERS := Color("4a4438")
const SHOES := Color("201814")
const CIGARETTE := Color("e8e4d8")
const EMBER := Color("e0763a")
const SMOKE := Color(0.75, 0.75, 0.78, 0.55)
const BOX := Color("8a6a48")
const BOX_DARK := Color("6a4e34")
const BOX_LABEL := Color("d8c8a0")
const CARD_BACKS := [Color("f3e6c4"), Color("c84a3a"), Color("3a5ab8"), Color("f3e6c4")]

static var _texture: ImageTexture


static func texture() -> ImageTexture:
	if _texture != null:
		return _texture
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_draw_body(image)
	_draw_box(image)
	_outline(image)
	_draw_smoke(image)
	_texture = ImageTexture.create_from_image(image)
	return _texture


static func _draw_body(image: Image) -> void:
	_rect(image, 6, 33, 4, 26, TROUSERS)
	_rect(image, 13, 33, 4, 26, TROUSERS)
	_rect(image, 5, 28, 13, 6, TROUSERS)
	_rect(image, 5, 58, 6, 4, SHOES)
	_rect(image, 12, 58, 6, 4, SHOES)
	_rect(image, 4, 12, 15, 17, CARDIGAN)
	_rect(image, 3, 13, 3, 15, CARDIGAN_DARK)
	_rect(image, 17, 13, 3, 15, CARDIGAN_DARK)
	_rect(image, 10, 12, 3, 4, SHIRT)
	for y in [17, 21, 25]:
		image.set_pixel(11, y, BUTTON)
	_rect(image, 3, 27, 3, 3, SKIN)
	_rect(image, 17, 27, 3, 3, SKIN)
	_rect(image, 10, 10, 3, 2, SKIN_DARK)
	_rect(image, 7, 1, 9, 10, SKIN)
	_rect(image, 7, 3, 1, 5, HAIR)
	_rect(image, 15, 3, 1, 5, HAIR)
	_rect(image, 8, 2, 1, 2, HAIR)
	_rect(image, 14, 2, 1, 2, HAIR)
	image.set_pixel(9, 5, EYE)
	image.set_pixel(13, 5, EYE)
	_rect(image, 11, 6, 1, 2, SKIN_DARK)
	_rect(image, 9, 9, 5, 1, HAIR)
	_rect(image, 12, 8, 4, 1, CIGARETTE)
	image.set_pixel(16, 8, EMBER)


static func _draw_box(image: Image) -> void:
	for i in CARD_BACKS.size():
		_rect(image, 24 + i * 3, 44 + (i % 2), 2, 5, CARD_BACKS[i])
	_rect(image, 22, 48, 14, 16, BOX)
	_rect(image, 22, 48, 14, 2, BOX_DARK)
	_rect(image, 25, 54, 8, 3, BOX_LABEL)


static func _draw_smoke(image: Image) -> void:
	for point in [Vector2i(17, 6), Vector2i(18, 4), Vector2i(17, 2), Vector2i(19, 1)]:
		image.set_pixelv(point, SMOKE)


static func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	image.fill_rect(Rect2i(x, y, w, h), color)


static func _outline(image: Image) -> void:
	var edge: Array[Vector2i] = []
	for y in SIZE.y:
		for x in SIZE.x:
			if image.get_pixel(x, y).a > 0.0:
				continue
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var other: Vector2i = Vector2i(x, y) + offset
				if other.x >= 0 and other.y >= 0 and other.x < SIZE.x and other.y < SIZE.y and image.get_pixelv(other).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for point in edge:
		image.set_pixelv(point, OUTLINE)
