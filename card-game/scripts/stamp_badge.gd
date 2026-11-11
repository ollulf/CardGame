extends Control
class_name StampBadge

const PIXEL := 2.0
const GRID := 13
const BORDER_COLOR := Color(0.1, 0.08, 0.07)
const GLYPH_COLOR := Color(1.0, 1.0, 1.0)
const SHAPE := [
	"....#####....",
	"..##ooooo##..",
	".#ooooooooo#.",
	".#ooooooooo#.",
	"#ooooooooooo#",
	"#ooooooooooo#",
	"#ooooooooooo#",
	"#ooooooooooo#",
	"#ooooooooooo#",
	".#ooooooooo#.",
	".#ooooooooo#.",
	"..##ooooo##..",
	"....#####....",
]

var stamp := CardStamp.Id.NONE
var pixel := PIXEL


static func create(stamp_id: int, pixel_size: float = PIXEL) -> StampBadge:
	var badge := StampBadge.new()
	badge.name = "StampBadge"
	badge.pixel = pixel_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_stamp(stamp_id)
	return badge


func set_stamp(stamp_id: int) -> void:
	stamp = stamp_id
	custom_minimum_size = Vector2(GRID, GRID) * pixel
	size = custom_minimum_size
	visible = stamp != CardStamp.Id.NONE
	queue_redraw()


func _draw() -> void:
	if stamp == CardStamp.Id.NONE:
		return
	var fill := CardStamp.color(stamp)
	for y in SHAPE.size():
		var row: String = SHAPE[y]
		for x in row.length():
			match row[x]:
				"#":
					draw_rect(Rect2(Vector2(x, y) * pixel, Vector2.ONE * pixel), BORDER_COLOR)
				"o":
					draw_rect(Rect2(Vector2(x, y) * pixel, Vector2.ONE * pixel), fill)
	var glyph := CardStamp.glyph(stamp)
	if glyph.is_empty():
		return
	var glyph_size := Vector2(String(glyph[0]).length(), glyph.size())
	var origin := ((Vector2(GRID, GRID) - glyph_size) * 0.5).floor()
	for y in glyph.size():
		var row: String = glyph[y]
		for x in row.length():
			if row[x] == "w":
				draw_rect(Rect2((origin + Vector2(x, y)) * pixel, Vector2.ONE * pixel), GLYPH_COLOR)
