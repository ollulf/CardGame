class_name LifeCard
extends Control

const SPLIT_DISTANCE := 2.0
const SPLIT_TILT_DEGREES := 5.0
const SPLIT_DURATION := 0.3

@onready var left_half: Control = %LeftHalf
@onready var right_half: Control = %RightHalf
@onready var left_rest_position: Vector2 = left_half.position
@onready var right_rest_position: Vector2 = right_half.position

var split_tween: Tween

func split() -> void:
	if split_tween:
		split_tween.kill()
	split_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_half(left_half, left_rest_position, -1.0)
	_tween_half(right_half, right_rest_position, 1.0)

func restore() -> void:
	if split_tween:
		split_tween.kill()
	left_half.position = left_rest_position
	left_half.rotation = 0.0
	right_half.position = right_rest_position
	right_half.rotation = 0.0

func _tween_half(half: Control, rest_position: Vector2, direction: float) -> void:
	split_tween.tween_property(half, "position:x", rest_position.x + direction * SPLIT_DISTANCE, SPLIT_DURATION)
	split_tween.tween_property(half, "rotation", deg_to_rad(direction * SPLIT_TILT_DEGREES), SPLIT_DURATION)
