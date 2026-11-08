extends CanvasLayer
class_name BarScreen

signal opened
signal closed

const NOT_ENOUGH_MONEY_TEXT := "Not enough money"

@export var pointer: Control

@onready var back_button: Button = %BackButton
@onready var machine: CigaretteMachine = %CigaretteMachine
@onready var booster_stand: CigaretteMachine = %BoosterStand
@onready var cash_label: Label = %CashLabel

var _pointer_parent: Node
var _pointer_index: int
var booster_shelf: BoosterShelf
var booster_window: BoosterWindow
var _cash_tween: Tween


func _ready() -> void:
	hide()
	back_button.pressed.connect(close)
	machine.set_label_text("Buy Cigarettes (%d$)" % PlayerDataManager.CIGARETTE_PACK_PRICE)
	booster_stand.set_label_text("Booster Shelf")
	booster_stand.needs_confirm = false
	machine.clicked.connect(_on_machine_clicked)
	booster_stand.clicked.connect(_on_booster_stand_clicked)
	booster_shelf = BoosterShelf.new()
	add_child(booster_shelf)
	booster_shelf.denied.connect(_flash_cash.bind(Color(1.0, 0.35, 0.3)))
	booster_window = BoosterWindow.new()
	add_child(booster_window)
	PlayerDataManager.booster_bought.connect(booster_window.open)
	booster_window.finished.connect(PlayerDataManager.mark_booster_collected)
	booster_window.finished.connect(_on_booster_window_finished)
	PlayerDataManager.money_changed.connect(_on_money_changed)
	PlayerDataManager.cig_machine_changed.connect(_on_cig_machine_changed)
	_on_cig_machine_changed(PlayerDataManager.cig_machine_unlocked)
	_refresh_cash()


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
	_refresh_cash()
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


func _on_cig_machine_changed(unlocked: bool) -> void:
	machine.set_out_of_order(not unlocked)


func _on_machine_clicked() -> void:
	if not PlayerDataManager.buy_cigarettes():
		machine.deny(NOT_ENOUGH_MONEY_TEXT)
		_flash_cash(Color(1.0, 0.35, 0.3))


func _on_booster_stand_clicked() -> void:
	booster_shelf.open()


func _on_booster_window_finished() -> void:
	if visible:
		booster_shelf.open()


func _refresh_cash() -> void:
	cash_label.text = "%d$" % PlayerDataManager.money


func _on_money_changed(_money: int) -> void:
	_refresh_cash()
	_flash_cash(Color(1.0, 1.0, 0.7))


func _flash_cash(color: Color) -> void:
	if _cash_tween:
		_cash_tween.kill()
	cash_label.modulate = color
	cash_label.scale = Vector2(1.2, 1.2)
	_cash_tween = create_tween().set_parallel(true)
	_cash_tween.tween_property(cash_label, "modulate", Color.WHITE, 0.5)
	_cash_tween.tween_property(cash_label, "scale", Vector2.ONE, 0.3)
