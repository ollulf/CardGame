extends Node2D
class_name WonPile

const SPACING := 40.0
const MAX_LAYERS := 5
const RETURN_STAGGER := 0.08

var pile_owner: Card.Owner = Card.Owner.HUMAN
var count: int = 0

var _stack: Node2D
var _layers: Array[Bierdeckel] = []


func _ready() -> void:
	add_to_group(GameManager.WON_PILE_GROUP)
	_stack = Node2D.new()
	add_child(_stack)
	for i in MAX_LAYERS:
		var coaster := Bierdeckel.new()
		coaster.position = _slot(i)
		_stack.add_child(coaster)
		TableShadow.add_to(coaster)
		_layers.append(coaster)
	_refresh()


func _slot(i: int) -> Vector2:
	return Vector2((float(i) - float(MAX_LAYERS - 1) * 0.5) * SPACING, 0.0)


func top_position() -> Vector2:
	return global_position + _slot(clampi(count, 0, MAX_LAYERS - 1))


func add_turn() -> void:
	count += 1
	_refresh()


func clear(animate: bool) -> void:
	var stack: BierdeckelStack = get_tree().get_first_node_in_group(BierdeckelStack.GROUP)
	var shown := mini(count, MAX_LAYERS)
	var froms: Array[Vector2] = []
	for i in range(shown - 1, -1, -1):
		froms.append(_layers[i].global_position)
	count = 0
	_refresh()
	if stack == null:
		return
	if not animate:
		stack.reset()
		return
	for i in froms.size():
		_return_coaster(stack, froms[i], i * RETURN_STAGGER)


func _return_coaster(stack: BierdeckelStack, from: Vector2, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	var slot := stack.next_slot_position()
	await Bierdeckel.fly(get_parent(), from, slot)
	stack.return_one()


func _refresh() -> void:
	if _stack == null:
		return
	for i in _layers.size():
		_layers[i].visible = i < count
