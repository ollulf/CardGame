extends CanvasLayer
class_name BarScreen

signal opened
signal closed

const NOT_ENOUGH_MONEY_TEXT := "Not enough money"
const WAIT_TEXT := "Wait..."
const STAMPS_LOCKED_TEXT := "Stamps: between matches only"
const ROUND_ORDERED_TEXT := "Round ordered!"
const HORST_LABEL_TEXT := "Horst (%d cards = %d$)"
const HORST_COUNTING_TEXT := "Horst is counting"
const HORST_LOCKED_TEXT := "Horst: between matches only"
const HORST_DONE_TEXT := "Come back next round."
const ROOM_TEXTURES := [
	preload("res://sprites/bar/bar_room_1.png"),
	preload("res://sprites/bar/bar_room_2.png"),
	preload("res://sprites/bar/bar_room_3.png"),
	preload("res://sprites/bar/bar_room_4.png"),
	preload("res://sprites/bar/bar_room_5.png"),
]
const HAZE_ALPHA := [0.25, 0.4, 0.55, 0.75, 0.95]
const HAZE_SPEED := 6.0
const FLICKER_CHANCE := [0.0, 0.0, 0.004, 0.012, 0.03]

@export var pointer: Control

@onready var back_button: Button = %BackButton
@onready var machine: CigaretteMachine = %CigaretteMachine
@onready var booster_stand: CigaretteMachine = %BoosterStand
@onready var drinks_tap: CigaretteMachine = %DrinksTap
@onready var stamp_stand: CigaretteMachine = %StampStand
@onready var horst: CigaretteMachine = %Horst
@onready var cash_label: Label = %CashLabel
@onready var room_art: TextureRect = %RoomArt
@onready var lamp_left: TextureRect = %LampGlowLeft
@onready var lamp_right: TextureRect = %LampGlowRight
@onready var haze: Control = %Haze

var _pointer_parent: Node
var _pointer_index: int
var booster_shelf: BoosterShelf
var booster_window: BoosterWindow
var stamp_shop: StampShop
var horst_shop: HorstShop
var _cash_tween: Tween
var _machine_busy := false
var _round_ordered := false
var _bought: Array[String] = []
var _stand_arrow: GuideArrow
var _mess_level := 1
var _flicker_left := 0.0
var _flicker_right := 0.0


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
	_stand_arrow = GuideArrow.new()
	add_child(_stand_arrow)
	booster_shelf = BoosterShelf.new()
	add_child(booster_shelf)
	booster_shelf.denied.connect(_flash_cash.bind(Color(1.0, 0.35, 0.3)))
	booster_window = BoosterWindow.new()
	add_child(booster_window)
	PlayerDataManager.booster_bought.connect(booster_window.open)
	PlayerDataManager.booster_bought.connect(_note_purchase.bind("bought_booster").unbind(1))
	booster_window.finished.connect(PlayerDataManager.mark_booster_collected)
	booster_window.finished.connect(_on_booster_window_finished)
	stamp_stand.set_label_text("Stamp Stand")
	stamp_stand.needs_confirm = false
	stamp_stand.clicked.connect(_on_stamp_stand_clicked)
	stamp_shop = StampShop.new()
	add_child(stamp_shop)
	stamp_shop.denied.connect(_flash_cash.bind(Color(1.0, 0.35, 0.3)))
	horst.sprite.texture = HorstArt.texture()
	horst.clicked.connect(_on_horst_clicked)
	horst_shop = HorstShop.new()
	add_child(horst_shop)
	horst_shop.denied.connect(_flash_cash.bind(Color(1.0, 0.35, 0.3)))
	horst_shop.closed.connect(_refresh_horst)
	PlayerDataManager.horst_changed.connect(_refresh_horst)
	horst_shop.sold.connect(_note_purchase.bind("sold_to_horst"))
	stamp_shop.stamp_applied.connect(_note_purchase.bind("bought_stamp").unbind(1))
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
	_refresh_stamp_stand()
	_refresh_horst()
	_refresh_room()
	show()
	$PostFX.show()
	if drinks_tap.visible:
		TutorialPopups.tip("drinks", drinks_tap)
	if horst.visible and not GameManager.match_active:
		TutorialPopups.tip("horst", horst)


func close() -> void:
	if not visible or SceneTransition.is_running() or stamp_shop.pending_stamp != CardStamp.Id.NONE:
		return

	stamp_shop.close()
	horst_shop.close()
	await SceneTransition.play(_hide_bar, true)
	InteractionManager.skip_next_double_click()
	get_tree().paused = false
	closed.emit()
	DialogueManager.play_bar_purchases(_bought)
	_bought.clear()
	_serve_ordered_round()


func _hide_bar() -> void:
	hide()
	$PostFX.hide()
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
	_note_purchase("bought_cigs")
	var length := Sfx.play_cig_machine()
	await get_tree().create_timer(length, true).timeout
	PlayerDataManager.deliver_cigarettes()
	_machine_busy = false


func _note_purchase(trigger: String) -> void:
	if not trigger in _bought:
		_bought.append(trigger)


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
	booster_shelf.show_hint = _guide_wants_booster()
	booster_shelf.open()


func _on_stamp_stand_clicked() -> void:
	if GameManager.match_active:
		stamp_stand.deny(STAMPS_LOCKED_TEXT)
		return
	open_stamp_shop()


func _refresh_stamp_stand() -> void:
	var locked := GameManager.match_active
	stamp_stand.set_label_text(STAMPS_LOCKED_TEXT if locked else "Stamp Stand")
	stamp_stand.sprite.modulate = Color(0.55, 0.55, 0.55) if locked else Color.WHITE


func _on_horst_clicked() -> void:
	if GameManager.match_active:
		horst.deny(HORST_LOCKED_TEXT)
		return
	if PlayerDataManager.horst_deals_left() <= 0 and not PlayerDataManager.is_horst_offer_available():
		horst.deny(HORST_DONE_TEXT)
		return
	Sfx.play_cough(DialogueManager.upcoming_match())
	horst_shop.open()


func _refresh_horst() -> void:
	horst.visible = PlayerDataManager.is_horst_available()
	var locked := GameManager.match_active
	var counting := PlayerDataManager.horst_deals_left() <= 0
	if locked:
		horst.set_label_text(HORST_LOCKED_TEXT)
	elif counting:
		horst.set_label_text(HORST_COUNTING_TEXT)
	else:
		horst.set_label_text(HORST_LABEL_TEXT % [PlayerDataManager.HORST_CARDS_PER_DEAL, PlayerDataManager.HORST_DEAL_PAY])
	var greyed := locked or (counting and not PlayerDataManager.is_horst_offer_available())
	horst.sprite.modulate = Color(0.55, 0.55, 0.55) if greyed else Color.WHITE


func open_stamp_shop() -> void:
	stamp_shop.open()


func _on_booster_window_finished() -> void:
	if visible:
		booster_shelf.show_hint = false
		booster_shelf.open()


func _guide_wants_booster() -> bool:
	var guide := get_tree().get_first_node_in_group("deck_screen")
	return guide != null and guide.guide_wants_booster()


func _refresh_room() -> void:
	_mess_level = clampi(DialogueManager.upcoming_match(), 1, ROOM_TEXTURES.size())
	room_art.texture = ROOM_TEXTURES[_mess_level - 1]
	haze.modulate.a = HAZE_ALPHA[_mess_level - 1]
	lamp_left.visible = _mess_level < 5
	lamp_left.modulate.a = 1.0
	lamp_right.modulate.a = 1.0
	_flicker_left = 0.0
	_flicker_right = 0.0


func _animate_room(delta: float) -> void:
	haze.position.x = fmod(haze.position.x + HAZE_SPEED * delta, 1152.0)
	var chance: float = FLICKER_CHANCE[_mess_level - 1]
	if _mess_level == 4:
		_flicker_left = _step_flicker(lamp_left, _flicker_left, chance * 0.5, delta)
	_flicker_right = _step_flicker(lamp_right, _flicker_right, chance, delta)


func _step_flicker(lamp: CanvasItem, timer: float, chance: float, delta: float) -> float:
	if timer > 0.0:
		timer -= delta
		lamp.modulate.a = 0.15 if fmod(timer, 0.1) < 0.06 else 0.6
		if timer <= 0.0:
			lamp.modulate.a = 1.0
		return timer
	if randf() < chance:
		return randf_range(0.1, 0.45)
	return 0.0


func _process(delta: float) -> void:
	if visible:
		_animate_room(delta)
	var wants_stand := visible and not booster_shelf.visible and not booster_window.visible and not stamp_shop.visible and not horst_shop.visible and _guide_wants_booster()
	_stand_arrow.target = booster_stand.sprite if wants_stand else null


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
