extends Node2D
class_name DrinkArt

const WIDTH := 12.0
const HEIGHT := 18.0
const LIQUID_HEIGHT := 14.0
const FOAM_HEIGHT := 3.0
const OUTLINE_COLOR := Color("2a1c14")
const GLASS_COLOR := Color(0.85, 0.93, 0.97, 0.35)
const LIQUID_COLOR := Color("f0a028")
const LIQUID_DARK_COLOR := Color("c4741a")
const FOAM_COLOR := Color("fff4dc")
const SHINE_COLOR := Color(1, 1, 1, 0.55)
const BUBBLE_COLOR := Color(1, 0.95, 0.75, 0.8)
const BUBBLE_COUNT := 4
const BUBBLE_SPEED := 5.0

var fill := 1.0:
	set(value):
		fill = clampf(value, 0.0, 1.0)
		queue_redraw()

var _time := 0.0


signal sipped

const LIFT := 18.0
const TILT := 0.8
const LIFT_TIME := 0.25
const SIP_TIME := 0.55


func play_sip(target_fill: float, direction: float) -> void:
	var base := position
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", base + Vector2(-direction * 2.0, -LIFT), LIFT_TIME)
	tween.parallel().tween_property(self, "rotation", -TILT * direction, LIFT_TIME)
	tween.tween_property(self, "fill", target_fill, SIP_TIME)
	tween.tween_callback(sipped.emit)
	tween.tween_property(self, "rotation", 0.0, LIFT_TIME)
	tween.parallel().tween_property(self, "position", base, LIFT_TIME)
	await tween.finished


func _process(delta: float) -> void:
	if fill <= 0.0 or not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var half := WIDTH * 0.5
	var body := Rect2(-half, -HEIGHT, WIDTH, HEIGHT)
	draw_arc(Vector2(half, -HEIGHT * 0.5), 4.0, -PI * 0.5, PI * 0.5, 10, OUTLINE_COLOR, 3.0)
	draw_arc(Vector2(half, -HEIGHT * 0.5), 4.0, -PI * 0.5, PI * 0.5, 10, GLASS_COLOR.lightened(0.3), 1.0)
	draw_rect(body, GLASS_COLOR)
	if fill > 0.0:
		var top := -1.0 - LIQUID_HEIGHT * fill
		draw_rect(Rect2(-half + 1.0, top, WIDTH - 2.0, -1.0 - top), LIQUID_COLOR)
		draw_rect(Rect2(half - 4.0, top, 3.0, -1.0 - top), LIQUID_DARK_COLOR)
		for i in BUBBLE_COUNT:
			var rise := fmod(_time * BUBBLE_SPEED + i * 3.7, maxf(-1.0 - top, 1.0))
			var x := -half + 2.5 + fmod(i * 2.9, WIDTH - 5.0)
			draw_rect(Rect2(x, -2.0 - rise, 1.0, 1.0), BUBBLE_COLOR)
		var foam_top := top - FOAM_HEIGHT * minf(fill * 3.0, 1.0)
		draw_rect(Rect2(-half, foam_top, WIDTH, top - foam_top + 0.5), FOAM_COLOR)
		for i in 3:
			draw_circle(Vector2(-half + 2.0 + i * 4.0, foam_top), 2.0, FOAM_COLOR)
	draw_rect(Rect2(-half + 1.5, -HEIGHT + 2.0, 1.0, HEIGHT - 4.0), SHINE_COLOR)
	draw_rect(body, OUTLINE_COLOR, false, 1.0)
	draw_line(Vector2(-half - 0.5, -0.5), Vector2(half + 0.5, -0.5), OUTLINE_COLOR, 1.5)
