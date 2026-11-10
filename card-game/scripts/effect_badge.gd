extends Control
class_name EffectBadge

const PIXEL := 2.0
const BORDER_COLOR := Color(0.1, 0.08, 0.07)
const PAPER_COLOR := Color(0.97, 0.95, 0.9)
const INK_COLOR := Color(0.1, 0.08, 0.07)

var effect := CardEffect.Id.NONE
var pixel := PIXEL


static func create(effect_id: int, pixel_size: float = PIXEL) -> EffectBadge:
	var badge := EffectBadge.new()
	badge.name = "EffectBadge"
	badge.pixel = pixel_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_effect(effect_id)
	return badge


func set_effect(effect_id: int) -> void:
	effect = effect_id
	var rows := CardEffect.icon(effect)
	var width := 0 if rows.is_empty() else String(rows[0]).length()
	custom_minimum_size = Vector2(width, rows.size()) * pixel
	size = custom_minimum_size
	visible = not rows.is_empty()
	queue_redraw()


func _draw() -> void:
	var rows := CardEffect.icon(effect)
	var fill := CardEffect.color(effect)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var color: Color
			match row[x]:
				"#":
					color = BORDER_COLOR
				"o":
					color = fill
				"w":
					color = PAPER_COLOR
				"k":
					color = INK_COLOR
				_:
					continue
			draw_rect(Rect2(Vector2(x, y) * pixel, Vector2.ONE * pixel), color)
