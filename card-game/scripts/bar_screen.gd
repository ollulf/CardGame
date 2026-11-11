extends CanvasLayer
class_name BarScreen

signal opened
signal closed

const NOT_ENOUGH_MONEY_TEXT := "Not enough money"
const WAIT_TEXT := "Wait..."
const NO_CARD_TEXT := "No card can take it"
const STAMPS_LOCKED_TEXT := "Stamps: between matches only"
const ROUND_ORDERED_TEXT := "Round ordered!"
const SMOKES_TEXT := "Buy cigarettes (%d$)"
const SMOKES_LOCKED_TEXT := "Machine out of order"
const DRINKS_TEXT := "Round of drinks (%d$)"
const MATCH_TEXT := "Match %d of %d"
const DENY_COLOR := Color(1.0, 0.35, 0.3)

@export var pointer: Control

@onready var room: Control = $Room
@onready var back_button: Button = %BackButton
@onready var deck_button: Button = %DeckButton
@onready var cash_label: Label = %CashLabel

var _pointer_parent: Node
var _pointer_index: int
var counter: BarCounter
var booster_window: BoosterWindow
var stamp_shop: StampShop
var _cash_tween: Tween
var _machine_busy := false
var _round_ordered := false
var _bought: Array[String] = []
var _stand_arrow: GuideArrow


func _ready() -> void:
	hide()
	$PostFX.hide()
	counter = BarCounter.new()
	room.add_child(counter)
	room.move_child(counter, 0)
	back_button.pressed.connect(close)
	deck_button.pressed.connect(_on_deck_pressed)
	counter.stamp_clicked.connect(_on_stamp_clicked)
	counter.booster_clicked.connect(_on_booster_clicked)
	counter.smokes_clicked.connect(_on_smokes_clicked)
	counter.drinks_clicked.connect(_on_drinks_clicked)
	_stand_arrow = GuideArrow.new()
	add_child(_stand_arrow)
	booster_window = BoosterWindow.new()
	add_child(booster_window)
	PlayerDataManager.booster_bought.connect(booster_window.open)
	PlayerDataManager.booster_bought.connect(_note_purchase.bind("bought_booster").unbind(1))
	booster_window.finished.connect(PlayerDataManager.mark_booster_collected)
	booster_window.finished.connect(_refresh_counter)
	stamp_shop = StampShop.new()
	add_child(stamp_shop)
	stamp_shop.denied.connect(_flash_cash.bind(DENY_COLOR))
	stamp_shop.closed.connect(_refresh_counter)
	stamp_shop.stamp_applied.connect(_note_purchase.bind("bought_stamp").unbind(1))
	PlayerDataManager.money_changed.connect(_on_money_changed)
	PlayerDataManager.cig_machine_changed.connect(_refresh_counter.unbind(1))
	PlayerDataManager.stamp_offers_changed.connect(_refresh_counter)
	PlayerDataManager.booster_offers_changed.connect(_refresh_counter)
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
	_refresh_counter()
	show()
	$PostFX.show()
	if counter.drinks.visible:
		TutorialPopups.tip("drinks", counter.drinks)


func close() -> void:
	if not visible or SceneTransition.is_running() or stamp_shop.pending_stamp != CardStamp.Id.NONE:
		return

	stamp_shop.close()
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


func _refresh_counter() -> void:
	var match_number := DialogueManager.upcoming_match()
	counter.set_mess(match_number)
	counter.set_match_text(MATCH_TEXT % [match_number, Missions.matches.size()])
	counter.show_stamps(PlayerDataManager.get_stamp_offers(), GameManager.match_active, STAMPS_LOCKED_TEXT)
	counter.show_boosters(PlayerDataManager.get_booster_offers())
	var cigs := PlayerDataManager.cig_machine_unlocked
	counter.show_smokes(cigs, SMOKES_TEXT % PlayerDataManager.CIGARETTE_PACK_PRICE if cigs else SMOKES_LOCKED_TEXT)
	var drink_text := ROUND_ORDERED_TEXT if _round_ordered else DRINKS_TEXT % PlayerDataManager.DRINK_ROUND_PRICE
	counter.show_drinks(PlayerDataManager.is_round_of_drinks_available(), drink_text)
	var screen := _deck_screen()
	deck_button.visible = screen != null and screen.can_edit_deck()


func _on_stamp_clicked(index: int) -> void:
	var item := counter.stamp_items[index]
	if GameManager.match_active:
		item.deny(STAMPS_LOCKED_TEXT)
		return
	if not PlayerDataManager.has_stampable_card():
		item.deny(NO_CARD_TEXT)
		return
	var stamp := PlayerDataManager.buy_stamp(index)
	if stamp == CardStamp.Id.NONE:
		item.deny(NOT_ENOUGH_MONEY_TEXT)
		_flash_cash(DENY_COLOR)
		return
	stamp_shop.begin_pick(stamp)


func _on_booster_clicked(index: int) -> void:
	if not PlayerDataManager.buy_booster_offer(index):
		counter.booster_items[index].deny(NOT_ENOUGH_MONEY_TEXT)
		_flash_cash(DENY_COLOR)


func _on_smokes_clicked() -> void:
	if not PlayerDataManager.cig_machine_unlocked:
		counter.smokes.deny(SMOKES_LOCKED_TEXT)
		return
	if _machine_busy:
		counter.smokes.deny(WAIT_TEXT)
		return
	if not PlayerDataManager.buy_cigarettes():
		counter.smokes.deny(NOT_ENOUGH_MONEY_TEXT)
		_flash_cash(DENY_COLOR)
		return
	_machine_busy = true
	_note_purchase("bought_cigs")
	var length := Sfx.play_cig_machine()
	await get_tree().create_timer(length, true).timeout
	PlayerDataManager.deliver_cigarettes()
	_machine_busy = false


func _on_drinks_clicked() -> void:
	if _round_ordered:
		counter.drinks.deny(ROUND_ORDERED_TEXT)
		return
	if not PlayerDataManager.buy_round_of_drinks():
		counter.drinks.deny(NOT_ENOUGH_MONEY_TEXT)
		_flash_cash(DENY_COLOR)
		return
	_round_ordered = true
	_refresh_counter()


func _on_deck_pressed() -> void:
	var screen := _deck_screen()
	if screen == null:
		return
	await close()
	screen.open_deck_builder()


func _note_purchase(trigger: String) -> void:
	if not trigger in _bought:
		_bought.append(trigger)


func _serve_ordered_round() -> void:
	if not _round_ordered:
		return
	_round_ordered = false
	GameManager.serve_round_of_drinks(GameManager.HUMAN_ID)


func open_stamp_shop() -> void:
	stamp_shop.open()


func _deck_screen() -> Node:
	return get_tree().get_first_node_in_group("deck_screen")


func _guide_wants_booster() -> bool:
	var guide := _deck_screen()
	return guide != null and guide.guide_wants_booster()


func _process(_delta: float) -> void:
	var wants_booster := visible and not booster_window.visible and not stamp_shop.visible and _guide_wants_booster()
	_stand_arrow.target = counter.first_booster_sprite() if wants_booster else null


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
