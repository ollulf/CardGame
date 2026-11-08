extends Control
class_name BoosterWindow

signal finished

enum State { HIDDEN, CLOSED, OPENING, REVEAL, COLLECTING }

const CARD_SCENE := preload("res://scenes/Card.tscn")
const MAX_ROW_CARDS := 5
const NORMAL_SUITS: Array[Card.Suit] = [Card.Suit.DIAMONDS, Card.Suit.HEARTS, Card.Suit.SPADES, Card.Suit.CLUBS]
const MIN_RANK := 1
const MAX_RANK := 9

const PANEL_RECT := Rect2(176, 124, 800, 400)
const PACK_TEXTURE := preload("res://sprites/booster_pack.png")
const SHINE_SHADER := preload("res://shaders/booster_shine.gdshader")
const SHADING_MAP := preload("res://sprites/booster_pack_map.png")
const PACK_SCALE := 2
const FLAP_PIXELS := 8
const LOGO_PADDING := 12
const PACK_SIZE := Vector2(43, 80) * PACK_SCALE
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
var _body: TextureRect
var _flap: TextureRect
var _collection_button: Button
var _logo: Label
var _booster: Dictionary = {}


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

	var shine := ShaderMaterial.new()
	shine.shader = SHINE_SHADER
	shine.set_shader_parameter("shading_map", SHADING_MAP)

	_body = _pack_piece(Rect2(0, FLAP_PIXELS, PACK_TEXTURE.get_width(), PACK_TEXTURE.get_height() - FLAP_PIXELS), shine)
	_body.position = Vector2(0, FLAP_PIXELS * PACK_SCALE)
	_pack.add_child(_body)

	_logo = Label.new()
	_logo.text = "BOOSTER"
	_logo.add_theme_color_override("font_color", Color(0.98, 0.84, 0.55, 1))
	_logo.add_theme_color_override("font_outline_color", Color(0.12, 0.12, 0.15, 1))
	_logo.add_theme_constant_override("outline_size", 4)
	_logo.add_theme_font_size_override("font_size", 11)
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_logo.position = Vector2(LOGO_PADDING, 45)
	_logo.size = Vector2(PACK_SIZE.x - LOGO_PADDING * 2, 70)
	_pack.add_child(_logo)

	_flap = _pack_piece(Rect2(0, 0, PACK_TEXTURE.get_width(), FLAP_PIXELS), shine)
	_flap.pivot_offset = _flap.size
	_pack.add_child(_flap)

	_collection_button = Button.new()
	_collection_button.text = "Collection"
	_collection_button.focus_mode = Control.FOCUS_NONE
	_collection_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collection_button.size = Vector2(120, 32)
	_collection_button.position = PANEL_RECT.end - Vector2(140, 48)
	add_child(_collection_button)


func _pack_piece(region: Rect2, shine: ShaderMaterial) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = PACK_TEXTURE
	atlas.region = region
	var piece := TextureRect.new()
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piece.texture = atlas
	piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	piece.stretch_mode = TextureRect.STRETCH_SCALE
	piece.size = region.size * PACK_SCALE
	piece.material = shine
	return piece


func open(booster: Dictionary = PlayerDataManager.BOOSTERS[0]) -> void:
	_booster = booster
	_logo.text = String(booster.get("name", "Booster")).to_upper().replace(" ", "\n")
	var tint := BoosterShelf.pack_tint(maxi(PlayerDataManager.BOOSTERS.find(booster), 0))
	_body.self_modulate = tint
	_flap.self_modulate = tint
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
	_collection_button.modulate = Color.WHITE
	state = State.CLOSED
	show()


func roll_cards() -> Array[Card]:
	var count: int = _booster.get("cards", MAX_ROW_CARDS)
	var min_rank: int = clampi(_booster.get("min_rank", MIN_RANK), 0, MAX_RANK)
	var max_rank: int = clampi(_booster.get("max_rank", MAX_RANK), min_rank, MAX_RANK)
	var smoke_count := mini(_roll_smoke_count(), count)
	var result: Array[Card] = []
	for i in count:
		var suit: Card.Suit
		if i < smoke_count:
			suit = Card.Suit.SMOKE
		elif _booster.get("any_suit", false):
			suit = _roll_any_suit()
		else:
			suit = NORMAL_SUITS.pick_random()
		result.append(Card.new(suit, randi_range(min_rank, max_rank), Card.Owner.HUMAN, false))
	result.shuffle()
	return result


func _roll_any_suit() -> Card.Suit:
	var suits: Array = Card.Suit.values()
	if not Missions.allows_alk(DialogueManager.upcoming_match()):
		suits.erase(Card.Suit.ALK)
	return suits.pick_random()


func _roll_smoke_count() -> int:
	var low: int = _booster.get("smoke_min", 0)
	var high: int = _booster.get("smoke_max", 0)
	if high <= 0:
		return 0
	return randi_range(low, high)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		click_at(event.position)


func click_at(point: Vector2) -> void:
	match state:
		State.CLOSED:
			if Rect2(_pack.position, PACK_SIZE).has_point(point):
				Sfx.play_button()
				_rip_open()
		State.REVEAL:
			for i in card_visuals.size():
				if not flipped[i] and _card_rect(i).has_point(point):
					flip(i)
					return


func _card_center(index: int) -> Vector2:
	var visual_size := CARD_SIZE * CARD_SCALE
	var rows := ceili(cards.size() / float(MAX_ROW_CARDS))
	var columns := ceili(cards.size() / float(maxi(rows, 1)))
	var row := floori(float(index) / columns)
	var column := index % columns
	var row_offset := (row - (rows - 1) / 2.0) * (visual_size.y + CARD_GAP)
	return Vector2(ROW_LEFT + visual_size.x / 2.0 + column * (visual_size.x + CARD_GAP), PANEL_RECT.get_center().y + row_offset)


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


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func flip(index: int) -> void:
	if state != State.REVEAL or flipped[index]:
		return
	flipped[index] = true
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
