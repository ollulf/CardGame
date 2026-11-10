extends Node2D
class_name Bierdeckel

const PIXEL_SCALE := 3.0
const RADIUS := 7.5
const RADIUS_PX := RADIUS * PIXEL_SCALE
const OUTLINE_COLOR := Color("4a2e1c")
const BASE_COLOR := Color("efe2c4")
const SHADE_COLOR := Color("d6c39c")
const PRINT_COLOR := Color("b8322a")
const PRINT_DARK_COLOR := Color("8c2420")
const FLY_TIME := 0.55
const FLY_ARC := 70.0
const FLY_SPIN := TAU


func _init() -> void:
	scale = Vector2.ONE * PIXEL_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	var r := int(ceil(RADIUS))
	for y in range(-r, r):
		for x in range(-r, r):
			var c := Vector2(x + 0.5, y + 0.5)
			var d := c.length()
			if d > RADIUS:
				continue
			var color := BASE_COLOR
			if d > RADIUS - 1.0:
				color = OUTLINE_COLOR
			elif d > RADIUS - 2.5 and d <= RADIUS - 1.5:
				color = PRINT_COLOR
			elif d <= 1.6 or (absf(c.x) < 1.0 and absf(c.y) < 3.2) or (absf(c.y) < 1.0 and absf(c.x) < 3.2):
				color = PRINT_DARK_COLOR if c.x + c.y > 0.0 else PRINT_COLOR
			elif c.x + c.y > RADIUS * 0.9:
				color = SHADE_COLOR
			draw_rect(Rect2(x, y, 1, 1), color)


static func fly(parent: Node, from: Vector2, to: Vector2, z: int = 20) -> void:
	var coaster := Bierdeckel.new()
	coaster.z_index = z
	parent.add_child(coaster)
	coaster.global_position = from
	var tween := coaster.create_tween()
	tween.tween_method(coaster._fly_step.bind(from, to), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	coaster.queue_free()


func _fly_step(t: float, from: Vector2, to: Vector2) -> void:
	global_position = from.lerp(to, t) + Vector2(0, -FLY_ARC * sin(t * PI))
	rotation = FLY_SPIN * t
	scale = Vector2.ONE * PIXEL_SCALE * (1.0 + 0.35 * sin(t * PI))
