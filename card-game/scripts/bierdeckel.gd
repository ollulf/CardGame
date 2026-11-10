extends Node2D
class_name Bierdeckel

const PIXEL_SCALE := 3.0
const RADIUS := 12.0
const RADIUS_PX := RADIUS * PIXEL_SCALE
const TEXTURE := preload("res://sprites/Bierdeckel.png")
const FLY_TIME := 0.55
const FLY_ARC := 70.0
const FLY_SPIN := TAU


func _init() -> void:
	scale = Vector2.ONE * PIXEL_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	draw_texture_rect(TEXTURE, Rect2(-RADIUS, -RADIUS, RADIUS * 2.0, RADIUS * 2.0), false)


static func fly(parent: Node, from: Vector2, to: Vector2, z: int = 20) -> void:
	var coaster := Bierdeckel.new()
	coaster.z_index = z
	parent.add_child(coaster)
	coaster.global_position = from
	Sfx.play_bierdeckel_move()
	var tween := coaster.create_tween()
	tween.tween_method(coaster._fly_step.bind(from, to), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	coaster.queue_free()


func _fly_step(t: float, from: Vector2, to: Vector2) -> void:
	global_position = from.lerp(to, t) + Vector2(0, -FLY_ARC * sin(t * PI))
	rotation = FLY_SPIN * t
	scale = Vector2.ONE * PIXEL_SCALE * (1.0 + 0.35 * sin(t * PI))
