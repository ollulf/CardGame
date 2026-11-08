extends Node2D
class_name PrizePot

const COIN_TEXTURE := preload("res://sprites/coin.png")
const COIN_SCALE := 3.0
const COINS_PER_STACK := 10
const MAX_COINS := 40
const STACK_STEP := 0.3
const DROP_TIME := 0.4
const COIN_DELAY := 0.06
const ARC_HEIGHT := 70.0
const LAND_SQUASH := Vector2(1.25, 0.75)
const PAYOUT_TIME := 0.5
const AI_SEAT_OFFSET := Vector2(0, -40)

var amount := 0
var _coins: Array[Sprite2D] = []
var _label: Label

func _ready() -> void:
	add_to_group("prize_pot")
	z_index = 5
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_label.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.0))
	_label.add_theme_constant_override("outline_size", 6)
	_label.size = Vector2(120, 28)
	_label.position = Vector2(-60, _coin_size().y * 0.6)
	_label.visible = false
	add_child(_label)

func pay(seat: int, value: int) -> void:
	if value <= 0:
		return
	if seat == 0:
		value = mini(value, PlayerDataManager.money)
		if value <= 0:
			return
		PlayerDataManager.set_money(PlayerDataManager.money - value)
	var start := _seat_position(seat)
	var new_coins := mini(value, MAX_COINS - _coins.size())
	amount += value
	var last: Tween = null
	for i in new_coins:
		last = _drop_coin(start, _coins.size(), i * COIN_DELAY)
	if last != null:
		await last.finished
	_refresh_label()

func pay_out(winner_ids: Array[int]) -> void:
	if amount <= 0 or winner_ids.is_empty():
		clear()
		return
	var share := amount / winner_ids.size()
	var rest := amount - share * winner_ids.size()
	var flights: Array = []
	for i in _coins.size():
		flights.append([_coins[_coins.size() - 1 - i], winner_ids[i % winner_ids.size()]])
	_coins.clear()
	amount = 0
	_label.visible = false
	var last: Tween = null
	for i in flights.size():
		last = _fly_to_winner(flights[i][0], flights[i][1], i * COIN_DELAY)
	if last != null:
		await last.finished
	for i in winner_ids.size():
		if winner_ids[i] == 0:
			PlayerDataManager.add_money(share + (rest if i == 0 else 0))

func _drop_coin(start: Vector2, slot: int, delay: float) -> Tween:
	var coin := Sprite2D.new()
	coin.texture = COIN_TEXTURE
	coin.scale = Vector2.ONE * COIN_SCALE
	coin.global_position = start
	coin.modulate.a = 0.0
	add_child(coin)
	_coins.append(coin)
	var target := _slot_position(slot)
	var from := coin.position
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(coin, "modulate:a", 1.0, 0.05)
	tween.tween_method(func(t: float): coin.position = from.lerp(target, t) + Vector2(0, -ARC_HEIGHT * sin(t * PI)), 0.0, 1.0, DROP_TIME).set_ease(Tween.EASE_IN)
	tween.tween_property(coin, "scale", LAND_SQUASH * COIN_SCALE, 0.05)
	tween.tween_property(coin, "scale", Vector2.ONE * COIN_SCALE, 0.08)
	return tween

func _fly_to_winner(coin: Sprite2D, seat: int, delay: float) -> Tween:
	var from := coin.global_position
	var target := _seat_position(seat)
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_method(func(t: float): coin.global_position = from.lerp(target, t) + Vector2(0, -ARC_HEIGHT * sin(t * PI)), 0.0, 1.0, PAYOUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(coin, "modulate:a", 0.0, 0.15).set_delay(PAYOUT_TIME - 0.15)
	tween.tween_callback(coin.queue_free)
	return tween

func _slot_position(slot: int) -> Vector2:
	var size := _coin_size()
	var stack := slot / COINS_PER_STACK
	var height := slot % COINS_PER_STACK
	var column := (stack + 1) / 2 * (1 if stack % 2 == 1 else -1)
	return Vector2(column * size.x * 1.05, -height * size.y * STACK_STEP)

func _coin_size() -> Vector2:
	return COIN_TEXTURE.get_size() * COIN_SCALE

func _seat_position(seat: int) -> Vector2:
	if seat == 0:
		var wallet = get_tree().get_first_node_in_group("wallet")
		if wallet:
			return wallet.global_position
	var player := GameManager.id_to_player(seat)
	if player != null and is_instance_valid(player):
		return player.global_position + AI_SEAT_OFFSET
	return global_position

func _refresh_label() -> void:
	_label.text = str(amount)
	_label.visible = amount > 0

func clear() -> void:
	for coin in _coins:
		coin.queue_free()
	_coins.clear()
	amount = 0
	_label.visible = false
