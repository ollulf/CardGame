extends CanvasLayer

@onready var result_label: Label = %ResultLabel
@onready var confirm_button: Button = %ConfirmDeckButton

var _hand_parent: Node
var _hand_index := 0

func _ready() -> void:
	hide()
	GameManager.game_finished.connect(open)
	confirm_button.pressed.connect(_on_confirm_pressed)

func open(looser_ids: Array[int]) -> void:
	var names: Array[String] = []
	for id in looser_ids:
		names.append(GameManager.PLAYER_NAMES[id])
	result_label.text = " and ".join(names) + " lost all lives."
	InteractionManager.set_table_blocked(true)
	_lift_hand_pointer()
	show()

func _on_confirm_pressed() -> void:
	hide()
	_lower_hand_pointer()
	InteractionManager.skip_next_double_click()
	InteractionManager.set_table_blocked(false)
	GameManager.start_new_game()

func _lift_hand_pointer() -> void:
	var hand: Control = InteractionManager.hand
	_hand_parent = hand.get_parent()
	_hand_index = hand.get_index()
	hand.reparent(self)

func _lower_hand_pointer() -> void:
	var hand: Control = InteractionManager.hand
	hand.reparent(_hand_parent)
	_hand_parent.move_child(hand, _hand_index)
