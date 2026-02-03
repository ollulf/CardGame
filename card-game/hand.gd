extends Node2D
class_name Hand

@export var follow_speed: float = 12.0
@export var max_distance: float = 500.0
@export var slot_spacing: float = 26.0

# Store actual Cigarette nodes we hold
var _cigs: Array[Cigarette] = []


func _ready() -> void:
	InteractionManager.hand = self


func _process(delta: float) -> void:
	var target_pos := get_global_mouse_position()

	var diff := target_pos - global_position
	if diff.length() > max_distance:
		target_pos = global_position + diff.normalized() * max_distance

	global_position = global_position.lerp(
		target_pos,
		1.0 - exp(-follow_speed * delta)
	)


# --- Inventory / actions ---

func get_total_count() -> int:
	return _cigs.size()


func add_cigarette(cig: Cigarette, state: int) -> void:
	add_child(cig)
	_cigs.append(cig)
	cig.set_state(state)
	_layout()


func remove_one_unlit() -> bool:
	for i in range(_cigs.size()):
		var c := _cigs[i]
		if c.get_state() == Cigarette.State.UNLIT:
			_cigs.remove_at(i)
			if is_instance_valid(c):
				c.queue_free()
			_layout()
			return true
	return false


func light_all_unlit() -> int:
	var count := 0
	for c in _cigs:
		if c.get_state() == Cigarette.State.UNLIT:
			c.set_state(Cigarette.State.LIT)
			count += 1
	if count > 0:
		_layout()
	return count


func burn_finished_to_stumps() -> void:
	for c in _cigs:
		if c.get_state() == Cigarette.State.LIT:
			c.set_state(Cigarette.State.STUMP)
	_layout()


func remove_all_stumps() -> int:
	var removed := 0
	for i in range(_cigs.size() - 1, -1, -1):
		var c := _cigs[i]
		if c.get_state() == Cigarette.State.STUMP:
			_cigs.remove_at(i)
			removed += 1
			if is_instance_valid(c):
				c.queue_free()
	if removed > 0:
		_layout()
	return removed


func _layout() -> void:
	# Arrange in a small row centered on hand
	var n := _cigs.size()
	if n <= 0:
		return

	var total_w := (n - 1) * slot_spacing
	var start_x := -total_w * 0.5

	for i in range(n):
		var c := _cigs[i]
		if is_instance_valid(c):
			c.position = Vector2(start_x + i * slot_spacing, 0)
			c.rotation = deg_to_rad(-10 + i * 10) # tiny fan for vibe
