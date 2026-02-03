extends Node2D
class_name Cigarette

enum State { UNLIT, LIT, STUMP }

@export var burn_textures: Array[Texture2D] = []
@onready var sprite: Sprite2D = $Sprite2D
@onready var burn_timer: Timer = Timer.new()

var _state: int = State.UNLIT
var _burn_index: int = -1  # -1 = unlit, 0..n = burning


func _ready() -> void:
	add_child(burn_timer)
	burn_timer.wait_time = 2.0
	burn_timer.one_shot = false
	burn_timer.timeout.connect(advance_burn)

	_apply_visual()


func set_state(new_state: int) -> void:
	_state = new_state

	match _state:
		State.UNLIT:
			_burn_index = -1
			burn_timer.stop()

		State.LIT:
			_burn_index = 0
			burn_timer.start()

		State.STUMP:
			_burn_index = burn_textures.size() - 1
			burn_timer.stop()

	_apply_visual()


func get_state() -> int:
	return _state


func advance_burn() -> void:
	if _state != State.LIT:
		return

	_burn_index += 1

	# 🔥 last burn reached → become stump automatically
	if _burn_index >= burn_textures.size() - 1:
		_burn_index = burn_textures.size() - 1
		_state = State.STUMP
		burn_timer.stop()

	_apply_visual()


func _apply_visual() -> void:
	if _state == State.UNLIT:
		sprite.texture = burn_textures[0]
		return

	if _burn_index >= 0 and _burn_index < burn_textures.size():
		sprite.texture = burn_textures[_burn_index]
