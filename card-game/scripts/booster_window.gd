extends Control
class_name BoosterWindow

signal finished

enum State { HIDDEN, CLOSED, OPENING, REVEAL, COLLECTING }

const CARD_SCENE := preload("res://scenes/Card.tscn")
const CARDS_PER_BOOSTER := 5
const SPECIAL_SUIT_CHANCE := 0.15
const NORMAL_SUITS: Array[Card.Suit] = [Card.Suit.DIAMONDS, Card.Suit.HEARTS, Card.Suit.SPADES, Card.Suit.CLUBS]
const MIN_RANK := 0
const MAX_RANK := 9

const PANEL_RECT := Rect2(176, 124, 800, 400)
const PACK_SIZE := Vector2(110, 170)
const CARD_SIZE := Vector2(60, 90)
const CARD_SCALE := 1.5
const CARD_GAP := 16.0
const ROW_LEFT := 350.0

var state: State = State.HIDDEN
var cards: Array[Card] = []
var card_visuals: Array[CardVisual] = []
var flipped: Array[bool] = []

var _panel: Panel
var _pack: Control
var _flap: ColorRect
var _hint: Label
var _collection_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	hide()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.position = PANEL_RECT.position
	_panel.size = PANEL_RECT.size
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.35, 0.35, 0.35, 1)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.85, 0.8, 0.7, 1)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	_pack = Control.new()
	_pack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pack.size = PACK_SIZE
	_pack.pivot_offset = PACK_SIZE / 2.0
	add_child(_pack)

	var body := ColorRect.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.color = Color(0.1, 0.1, 0.1, 1)
	body.size = PACK_SIZE
	_pack.add_child(body)

	var tear := ColorRect.new()
	tear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tear.color = Color(0.45, 0.45, 0.45, 1)
	tear.position = Vector2(4, 22)
	tear.size = Vector2(PACK_SIZE.x - 8, 4)
	_pack.add_child(tear)

	var logo := Label.new()
	logo.text = "BOOSTER"
	logo.add_theme_color_override("font_color", Color(0.98, 0.84, 0.55, 1))
	logo.add_theme_font_size_override("font_size", 16)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.position = Vector2(0, 60)
	logo.size = Vector2(PACK_SIZE.x, 50)
	_pack.add_child(logo)

	_flap = ColorRect.new()
	_flap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flap.color = Color(0.16, 0.16, 0.16, 1)
	_flap.size = Vector2(PACK_SIZE.x, 22)
	_flap.pivot_offset = Vector2(PACK_SIZE.x, 22)
	_pack.add_child(_flap)

	_collection_button = Button.new()
	_collection_button.text = "Collection"
	_collection_button.focus_mode = Control.FOCUS_NONE
	_collection_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collection_button.size = Vector2(120, 32)
	_collection_button.position = PANEL_RECT.end - Vector2(140, 48)
	add_child(_collection_button)

	_hint = Label.new()
	_hint.text = "click\nto flip"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 1))
	_hint.add_theme_font_size_override("font_size", 13)
	var hint_style := StyleBoxFlat.new()
	hint_style.bg_color = Color(1, 1, 1, 1)
	hint_style.set_content_margin_all(5)
	_hint.add_theme_stylebox_override("normal", hint_style)
	_hint.z_index = 20
	add_child(_hint)


func open() -> void:
	for visual in card_visuals:
		visual.queue_free()
	card_visuals.clear()
	cards = roll_cards()
	flipped.clear()
	flipped.resize(cards.size())
	flipped.fill(false)

	_pack.position = PANEL_RECT.get_center() - PACK_SIZE / 2.0
	_pack.modulate = Color.WHITE
	_flap.position = Vector2.ZERO
	_flap.rotation = 0.0
	_flap.modulate = Color.WHITE
	_hint.hide()
	_collection_button.modulate = Color.WHITE
	state = State.CLOSED
	show()


func roll_cards() -> Array[Card]:
	var result: Array[Card] = []
	for i in CARDS_PER_BOOSTER:
		result.append(Card.new(_roll_suit(), randi_range(MIN_RANK, MAX_RANK), Card.Owner.HUMAN, false))
	return result


func _roll_suit() -> Card.Suit:
	var roll := randf()
	if roll < SPECIAL_SUIT_CHANCE:
		return Card.Suit.SMOKE
	if roll < SPECIAL_SUIT_CHANCE * 2.0:
		return Card.Suit.ALK
	return NORMAL_SUITS.pick_random()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		click_at(event.position)


func click_at(point: Vector2) -> void:
	match state:
		State.CLOSED:
			if Rect2(_pack.position, PACK_SIZE).has_point(point):
				_rip_open()
		State.REVEAL:
			for i in card_visuals.size():
				if not flipped[i] and _card_rect(i).has_point(point):
					flip(i)
					return


func _card_center(index: int) -> Vector2:
	var step := CARD_SIZE.x * CARD_SCALE + CARD_GAP
	return Vector2(ROW_LEFT + CARD_SIZE.x * CARD_SCALE / 2.0 + index * step, PANEL_RECT.get_center().y)


func _card_rect(index: int) -> Rect2:
	var visual_size := CARD_SIZE * CARD_SCALE
	return Rect2(_card_center(index) - visual_size / 2.0, visual_size)


func _rip_open() -> void:
	state = State.OPENING
	var rip := create_tween()
	rip.set_parallel(true)
	rip.tween_property(_flap, "position", Vector2(30, -50), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rip.tween_property(_flap, "rotation", 0.6, 0.35)
	rip.tween_property(_flap, "modulate:a", 0.0, 0.35)
	rip.tween_property(_pack, "rotation", -0.06, 0.08)
	rip.chain().tween_property(_pack, "rotation", 0.0, 0.1)
	rip.chain().tween_property(_pack, "position:x", PANEL_RECT.position.x + 30, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await rip.finished

	var pack_center := _pack.position + PACK_SIZE / 2.0
	var deal := create_tween()
	deal.set_parallel(true)
	for i in cards.size():
		var visual: CardVisual = CARD_SCENE.instantiate()
		_ignore_mouse(visual)
		visual.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		visual.size = CARD_SIZE
		visual.pivot_offset = CARD_SIZE / 2.0
		visual.hover_enabled = false
		visual.z_index = 1
		add_child(visual)
		move_child(visual, _hint.get_index())
		visual.setup(cards[i], true)
		visual.position = pack_center - CARD_SIZE / 2.0
		visual.scale = Vector2.ONE * 0.6
		visual.modulate.a = 0.0
		card_visuals.append(visual)
		var delay := i * 0.08
		deal.tween_property(visual, "position", _card_center(i) - CARD_SIZE / 2.0, 0.35).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		deal.tween_property(visual, "scale", Vector2.ONE * CARD_SCALE, 0.35).set_delay(delay)
		deal.tween_property(visual, "modulate:a", 1.0, 0.15).set_delay(delay)
	await deal.finished
	state = State.REVEAL
	_update_hint()


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func flip(index: int) -> void:
	if state != State.REVEAL or flipped[index]:
		return
	flipped[index] = true
	_update_hint()
	var visual := card_visuals[index]
	var turn := create_tween()
	turn.tween_property(visual, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	turn.tween_callback(func() -> void:
		visual.face_down = false
		visual.update_visuals())
	turn.tween_property(visual, "scale:x", CARD_SCALE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not flipped.has(false):
		state = State.COLLECTING
		await turn.finished
		_collect()


func _update_hint() -> void:
	var next := flipped.find(false)
	if next == -1:
		_hint.hide()
		return
	_hint.reset_size()
	var rect := _card_rect(next)
	_hint.position = Vector2(rect.get_center().x - _hint.size.x / 2.0, rect.position.y - _hint.size.y - 10)
	_hint.show()


func _collect() -> void:
	await get_tree().create_timer(0.8, true, false, true).timeout
	var target := _collection_button.position + _collection_button.size / 2.0 - CARD_SIZE / 2.0
	var fly := create_tween()
	fly.set_parallel(true)
	for i in card_visuals.size():
		var visual := card_visuals[i]
		var delay := i * 0.07
		fly.tween_property(visual, "position", target, 0.4).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.tween_property(visual, "scale", Vector2.ONE * 0.3, 0.4).set_delay(delay)
		fly.tween_property(visual, "modulate:a", 0.0, 0.1).set_delay(delay + 0.3)
	await fly.finished
	PlayerDataManager.add_to_collection(cards)
	var pulse := create_tween()
	pulse.tween_property(_collection_button, "modulate", Color(1.4, 1.3, 0.9), 0.1)
	pulse.tween_property(_collection_button, "modulate", Color.WHITE, 0.2)
	await pulse.finished
	await get_tree().create_timer(0.3, true, false, true).timeout
	close()


func close() -> void:
	for visual in card_visuals:
		visual.queue_free()
	card_visuals.clear()
	cards = []
	state = State.HIDDEN
	hide()
	finished.emit()
