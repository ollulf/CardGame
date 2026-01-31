extends Area2D
class_name Card

signal double_clicked(card_view: Card)

var card_data: Dictionary = {}

@onready var suit_icon: Sprite2D = $SuitIcon
@onready var rank_label: Label = $RankLabel


func setup(data: Dictionary, show: bool) -> void:	
	card_data = data

	if show:
		var suit_key: String = str(card_data.get("suit"))
		var rank_value = card_data.get("rank")

		rank_label.text = str(rank_value)

		var tex: Texture2D = GameManager.suit_textures.get(suit_key)
		suit_icon.texture = tex


func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	# Godot 4 gives us a built-in double_click flag
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			emit_signal("double_clicked", self)
