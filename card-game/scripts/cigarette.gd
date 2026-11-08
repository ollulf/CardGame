extends Control
class_name Cigarette

enum State { UNLIT, LIT, STUMP }

var _state: int = State.UNLIT
var _visual: AiSmoke


func _ready() -> void:
	_visual = AiSmoke.new()
	_visual.burned_out.connect(_on_burned_out)
	add_child(_visual)
	_apply_visual()


func set_state(new_state: int) -> void:
	_state = new_state
	_apply_visual()


func get_state() -> int:
	return _state


func _on_burned_out() -> void:
	if _state == State.LIT:
		_state = State.STUMP


func _apply_visual() -> void:
	if _visual == null:
		return

	match _state:
		State.UNLIT:
			_visual.show_unlit()
		State.LIT:
			_visual.ignite()
		State.STUMP:
			_visual.show_stub()
