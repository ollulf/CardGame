extends CanvasLayer
class_name BarScreen

signal opened
signal closed

@export var pointer: Control

@onready var back_button: Button = %BackButton
@onready var machine: CigaretteMachine = %CigaretteMachine

var _pointer_parent: Node
var _pointer_index: int


func _ready() -> void:
	hide()
	back_button.pressed.connect(close)


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
