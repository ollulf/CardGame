class_name LifeCard
extends Control

signal loss_finished

const SPLIT_DISTANCE := 2.0
const SPLIT_TILT_DEGREES := 5.0
const SPLIT_DURATION := 0.3
const RIP_DISTANCE := 5.0
const RIP_TILT_DEGREES := 14.0
const RIP_SOUND := preload("res://sounds/booster_rip.wav")
const LOSS_SCALE := 3.0
const LOSS_Z_INDEX := 100
const LOSS_FLY_DURATION := 0.9
const LOSS_PAUSE_BEFORE_RIP := 0.6
const LOSS_PAUSE_AFTER_RIP := 0.9
const LOSS_RETURN_DURATION := 1.0

@onready var left_half: Control = %LeftHalf
@onready var right_half: Control = %RightHalf
@onready var left_rest_position: Vector2 = left_half.position
@onready var right_rest_position: Vector2 = right_half.position

var split_tween: Tween
var loss_tween: Tween
var loss_rest_position: Vector2
var losing := false

func split(distance := SPLIT_DISTANCE, tilt_degrees := SPLIT_TILT_DEGREES) -> void:
	if split_tween:
		split_tween.kill()
	split_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_half(left_half, left_rest_position, -1.0, distance, tilt_degrees)
	_tween_half(right_half, right_rest_position, 1.0, distance, tilt_degrees)

func play_loss(center: Vector2) -> void:
	_stop_loss()
	losing = true
	loss_rest_position = position
	pivot_offset = size / 2.0
	z_index = LOSS_Z_INDEX
	var target := position + center - size / 2.0 - global_position
	loss_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	loss_tween.tween_property(self, "position", target, LOSS_FLY_DURATION)
	loss_tween.parallel().tween_property(self, "scale", Vector2.ONE * LOSS_SCALE, LOSS_FLY_DURATION)
	loss_tween.tween_interval(LOSS_PAUSE_BEFORE_RIP)
	loss_tween.tween_callback(_rip)
	loss_tween.tween_interval(LOSS_PAUSE_AFTER_RIP)
	loss_tween.tween_callback(split.bind(SPLIT_DISTANCE, SPLIT_TILT_DEGREES))
	loss_tween.tween_property(self, "position", loss_rest_position, LOSS_RETURN_DURATION)
	loss_tween.parallel().tween_property(self, "scale", Vector2.ONE, LOSS_RETURN_DURATION)
	loss_tween.tween_callback(_finish_loss)
	await loss_finished

func restore() -> void:
	if split_tween:
		split_tween.kill()
	left_half.position = left_rest_position
	left_half.rotation = 0.0
	right_half.position = right_rest_position
	right_half.rotation = 0.0
	_stop_loss()

func _rip() -> void:
	Sfx.play(RIP_SOUND, 0.05)
	split(RIP_DISTANCE, RIP_TILT_DEGREES)

func _stop_loss() -> void:
	if loss_tween:
		loss_tween.kill()
	if not losing:
		return
	position = loss_rest_position
	scale = Vector2.ONE
	_finish_loss()

func _finish_loss() -> void:
	z_index = 0
	losing = false
	loss_finished.emit()

func _tween_half(half: Control, rest_position: Vector2, direction: float, distance: float, tilt_degrees: float) -> void:
	split_tween.tween_property(half, "position:x", rest_position.x + direction * distance, SPLIT_DURATION)
	split_tween.tween_property(half, "rotation", deg_to_rad(direction * tilt_degrees), SPLIT_DURATION)
