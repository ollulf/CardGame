extends Control
class_name StampBadge

const PIXEL := 2.0

var stamp := CardStamp.Id.NONE
var pixel := PIXEL


static func create(stamp_id: int, pixel_size: float = PIXEL) -> StampBadge:
	var badge := StampBadge.new()
	badge.name = "StampBadge"
	badge.pixel = pixel_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.set_stamp(stamp_id)
	return badge


func set_stamp(stamp_id: int) -> void:
	stamp = stamp_id
	custom_minimum_size = Vector2(StampArt.SIZE, StampArt.SIZE) * pixel
	size = custom_minimum_size
	visible = stamp != CardStamp.Id.NONE
	queue_redraw()


func _draw() -> void:
	if stamp == CardStamp.Id.NONE:
		return
	draw_texture_rect(StampArt.imprint(stamp), Rect2(Vector2.ZERO, size), false)
