extends CanvasLayer
class_name BarScreen

signal opened
signal closed

const NOT_ENOUGH_MONEY_TEXT := "Not enough money"
const WAIT_TEXT := "Wait..."
const ROUND_ORDERED_TEXT := "Round ordered!"
const PULSE_COLOR := Color(1.35, 1.25, 0.85, 1)

@export var pointer: Control

@onready var back_button: Button = %BackButton
@onready var machine: CigaretteMachine = %CigaretteMachine
@onready var booster_stand: CigaretteMachine = %BoosterStand
@onready var drinks_tap: CigaretteMachine = %DrinksTap
@onready var cash_label: Label = %CashLabel

var _pointer_parent: Node
var _pointer_index: int
var booster_shelf: BoosterShelf
var booster_window: BoosterWindow
var _cash_tween: Tween
var _machine_busy := false
var _round_ordered := false
var _stand_pulse: Tween


func _ready() -> void:
	hide()
	$PostFX.hide()
	back_button.pressed.connect(close)
	machine.set_label_text("Buy Cigarettes (%d$)" % PlayerDataManager.CIGARETTE_PACK_PRICE)
	booster_stand.set_label_text("Booster Shelf")
	booster_stand.needs_confirm = false
	drinks_tap.set_label_text("Round of Drinks (%d$)" % PlayerDataManager.DRINK_ROUND_PRICE)
	drinks_tap.clicked.connect(_on_drinks_tap_clicked)
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
	if visible or SceneTransition.is_running() or DialogueManager.is_open() or InteractionManager.is_table_blocked():
		return

	InteractionManager.cancel_press()
	get_tree().paused = true
	await SceneTransition.play(_show_bar, false)
	opened.emit()


func _show_bar() -> void:
	_pointer_parent = pointer.get_parent()
	_pointer_index = pointer.get_index()
	pointer.reparent(self)
	pointer.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	pointer.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	_refresh_cash()
	_refresh_drinks_tap()
	_refresh_stand_pulse()
	show()
	$PostFX.show()


func close() -> void:
	if not visible or SceneTransition.is_running():
		return

	await SceneTransition.play(_hide_bar, true)
	InteractionManager.skip_next_double_click()
	get_tree().paused = false
	closed.emit()
	_serve_ordered_round()


func _hide_bar() -> void:
	hide()
	$PostFX.hide()
	_stop_stand_pulse()
	pointer.reparent(_pointer_parent)
	_pointer_parent.move_child(pointer, _pointer_index)


func _on_cig_machine_changed(unlocked: bool) -> void:
	machine.set_out_of_order(not unlocked)


func _on_machine_clicked() -> void:
	if _machine_busy:
		machine.deny(WAIT_TEXT)
		return
	if not PlayerDataManager.buy_cigarettes():
		machine.deny(NOT_ENOUGH_MONEY_TEXT)
		_flash_cash(Color(1.0, 0.35, 0.3))
		return
	_machine_busy = true
	var length := Sfx.play_cig_machine()
	await get_tree().create_timer(length, true).timeout
	PlayerDataManager.deliver_cigarettes()
	_machine_busy = false


func _refresh_drinks_tap() -> void:
	drinks_tap.visible = PlayerDataManager.is_round_of_drinks_available()


func _on_drinks_tap_clicked() -> void:
	if _round_ordered:
		drinks_tap.deny(ROUND_ORDERED_TEXT)
		return
	if not PlayerDataManager.buy_round_of_drinks():
		drinks_tap.deny(NOT_ENOUGH_MONEY_TEXT)
		_flash_cash(Color(1.0, 0.35, 0.3))
		return
	_round_ordered = true
	drinks_tap.set_label_text(ROUND_ORDERED_TEXT)


func _serve_ordered_round() -> void:
	if not _round_ordered:
		return
	_round_ordered = false
	drinks_tap.set_label_text("Round of Drinks (%d$)" % PlayerDataManager.DRINK_ROUND_PRICE)
	GameManager.serve_round_of_drinks(GameManager.HUMAN_ID)


func _on_booster_stand_clicked() -> void:
	booster_shelf.show_hint = _guide_suggests_booster()
	_stop_stand_pulse()
	booster_shelf.open()


func _on_booster_window_finished() -> void:
	if visible:
		booster_shelf.show_hint = false
		booster_shelf.open()


func _guide_suggests_booster() -> bool:
	var guide := get_tree().get_first_node_in_group("deck_screen")
	return guide != null and guide.suggests_booster()


func _refresh_stand_pulse() -> void:
	_stop_stand_pulse()
	if not _guide_suggests_booster():
		return
	_stand_pulse = create_tween().set_loops()
	_stand_pulse.tween_property(booster_stand.sprite, "self_modulate", PULSE_COLOR, 0.6).set_trans(Tween.TRANS_SINE)
	_stand_pulse.tween_property(booster_stand.sprite, "self_modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)


func _stop_stand_pulse() -> void:
	if _stand_pulse:
		_stand_pulse.kill()
		_stand_pulse = null
	booster_stand.sprite.self_modulate = Color.WHITE


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
