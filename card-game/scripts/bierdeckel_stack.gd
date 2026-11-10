extends Node2D
class_name BierdeckelStack

const GROUP := "bierdeckel_stack"
const TOTAL := 5
const LAYER_STEP := Vector2(0, -3)

var count: int = TOTAL

var _layers: Array[Bierdeckel] = []


func _ready() -> void:
	add_to_group(GROUP)
	for i in TOTAL:
		var coaster := Bierdeckel.new()
		coaster.position = LAYER_STEP * float(i)
		add_child(coaster)
		TableShadow.add_to(coaster)
		_layers.append(coaster)
	_refresh()


func top_position() -> Vector2:
	return global_position + LAYER_STEP * float(clampi(count - 1, 0, TOTAL - 1))


func next_slot_position() -> Vector2:
	return global_position + LAYER_STEP * float(clampi(count, 0, TOTAL - 1))


func take() -> Vector2:
	var from := top_position()
	count = maxi(count - 1, 0)
	_refresh()
	return from


func return_one() -> void:
	count = mini(count + 1, TOTAL)
	_refresh()


func reset() -> void:
	count = TOTAL
	_refresh()


func _refresh() -> void:
	for i in _layers.size():
		_layers[i].visible = i < count
