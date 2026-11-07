extends CanvasLayer
class_name BarScreen

signal opened
signal closed

const NOT_ENOUGH_MONEY_TEXT := "Not enough money"

@export var pointer: Control

@onready var back_button: Button = %BackButton
@onready var machine: CigaretteMachine = %CigaretteMachine
@onready var booster_stand: CigaretteMachine = %BoosterStand

var _pointer_parent: Node
var _pointer_index: int


func _ready() -> void:
	hide()
	back_button.pressed.connect(close)
	machine.set_label_text("Buy Cigarettes (%d$)" % PlayerDataManager.CIGARETTE_PACK_PRICE)
	booster_stand.set_label_text("Buy Booster (%d$)" % PlayerDataManager.BOOSTER_PRICE)
	machine.clicked.connect(_on_machine_clicked)
	booster_stand.clicked.connect(_on_booster_stand_clicked)


func open() -> void:
	if visible or DialogueManager.is_open() or InteractionManager.is_table_blocked():
		return

	InteractionManager.cancel_press()
	get_tree().paused = true
	_pointer_parent = pointer.get_parent()
	_pointer_index = pointer.get_index()
	pointer.reparent(self)
	pointer.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	pointer.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	show()
	opened.emit()


func close() -> void:
	if not visible:
		return

	hide()
	pointer.reparent(_pointer_parent)
	_pointer_parent.move_child(pointer, _pointer_index)
	InteractionManager.skip_next_double_click()
	get_tree().paused = false
	closed.emit()


func _on_machine_clicked() -> void:
	if not PlayerDataManager.buy_cigarettes():
		machine.deny(NOT_ENOUGH_MONEY_TEXT)


func _on_booster_stand_clicked() -> void:
	if not PlayerDataManager.buy_booster():
		booster_stand.deny(NOT_ENOUGH_MONEY_TEXT)
		return
	print("Booster bought: booster window coming soon")
