extends Node


func _ready() -> void:
	CardManager.special_played.connect(_on_special_played)


func _on_special_played(card: Card, _seat: int) -> void:
	var visual := _played_visual(card)
	if visual == null:
		return
	await get_tree().create_timer(visual.float_anim_time, false).timeout
	if not is_instance_valid(visual) or not visual.is_inside_tree():
		return
	if card.has_effect():
		CardFx.special_pop(visual, card.effect)
	if card.has_stamp():
		CardFx.stamp_splat(visual, card.stamp)


func _played_visual(card: Card) -> CardVisual:
	var root := CardManager.table_root
	if root == null:
		return null
	var children := root.get_children()
	children.reverse()
	for child in children:
		if child is CardVisual and child.card == card:
			return child
	return null
