extends Control
class_name BoosterWindow

signal finished

enum State { HIDDEN, CLOSED, OPENING, REVEAL, DONE, LEAVING }

const CARD_SCENE := preload("res://scenes/Card.tscn")
const MAX_ROW_CARDS := 5
const HOVER_TINT := Color(1.15, 1.1, 0.95)
const TAKE_ARROW_SCALE := 3.0
const NORMAL_SUITS: Array[Card.Suit] = [Card.Suit.DIAMONDS, Card.Suit.HEARTS, Card.Suit.SPADES, Card.Suit.CLUBS]
const MIN_RANK := 1
const NORMAL_SUIT_WEIGHT := 3
const MAX_RANK := 9

const PANEL_RECT := Rect2(176, 124, 800, 400)
const FLIP_FX_SHADER := preload("res://shaders/booster_flip_fx.gdshader")
const CARD_MASK := preload("res://sprites/card_Background.png")
const PACK_SCALE := 2
const FLAP_PIXELS := 8
const LOGO_PADDING := 12
const PACK_SIZE := Vector2(43, 80) * PACK_SCALE
const CARD_SIZE := Vector2(60, 90)
const CARD_SCALE := 1.5
const CARD_GAP := 16.0
const ROW_LEFT := 350.0
const FLIP_FX_TIME := 0.35
const SPECIAL_FX_TIME := 0.8

var state: State = State.HIDDEN
var cards: Array[Card] = []
var card_visuals: Array[CardVisual] = []
var flipped: Array[bool] = []

var _panel: Panel
var _pack: Control
var _body: TextureRect
var _flap: TextureRect
var _take_arrow: ContinueArrow
var _hovered := -1
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
	panel_style.set_corner_radius_all(6)
	panel_style.bg_color = Color("17161c")
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color("6b6390")
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	_pack = Control.new()
	_pack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pack.size = PACK_SIZE
	_pack.pivot_offset = PACK_SIZE / 2.0
	add_child(_pack)

	var shine := ShaderMaterial.new()
	shine.shader = BoosterArt.SHINE_SHADER
	shine.set_shader_parameter("shading_map", BoosterArt.SHADING_MAP)

	_body = _pack_piece(Rect2(0, FLAP_PIXELS, BoosterArt.PACK_TEXTURE.get_width(), BoosterArt.PACK_TEXTURE.get_height() - FLAP_PIXELS), shine)
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
	_logo.position = Vector2(LOGO_PADDING, 20)
	_logo.size = Vector2(PACK_SIZE.x - LOGO_PADDING * 2, 36)
	_pack.add_child(_logo)

	_flap = _pack_piece(Rect2(0, 0, BoosterArt.PACK_TEXTURE.get_width(), FLAP_PIXELS), shine)
	_flap.pivot_offset = _flap.size
	_pack.add_child(_flap)

	_take_arrow = ContinueArrow.new()
	_take_arrow.scale = Vector2(TAKE_ARROW_SCALE, TAKE_ARROW_SCALE)
	_take_arrow.position = Vector2(PANEL_RECT.get_center().x - 5.0 * TAKE_ARROW_SCALE, PANEL_RECT.end.y - 30)
	_take_arrow.hide()
	add_child(_take_arrow)
	_take_arrow.set_process_input(false)


func _pack_piece(region: Rect2, shine: ShaderMaterial) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = BoosterArt.PACK_TEXTURE
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
	var pack := BoosterArt.pack_texture(booster)
	(_body.texture as AtlasTexture).atlas = pack
	(_flap.texture as AtlasTexture).atlas = pack
	var tint := BoosterArt.pack_tint(booster)
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
	_take_arrow.hide()
	_hovered = -1
	state = State.CLOSED
	show()


func roll_cards() -> Array[Card]:
	return roll(_booster, DialogueManager.upcoming_match())


static func roll(booster: Dictionary, match_number: int) -> Array[Card]:
	var count: int = booster.get("cards", MAX_ROW_CARDS)
	var min_rank := lowest_rank(booster, match_number)
	var max_rank: int = clampi(booster.get("max_rank", MAX_RANK), min_rank, MAX_RANK)
	var suits := pack_suits(booster, match_number)
	var effects := special_effects()
	var special_count := 0 if effects.is_empty() else mini(int(booster.get("specials", 0)), count)
	var result: Array[Card] = []
	for i in count:
		var effect: CardEffect.Id = effects.pick_random() if i < special_count else CardEffect.Id.NONE
		result.append(Card.new(suits.pick_random(), randi_range(min_rank, max_rank), Card.Owner.HUMAN, false, effect))
	result.shuffle()
	return result


static func lowest_rank(booster: Dictionary, match_number: int) -> int:
	return clampi(maxi(int(booster.get("min_rank", MIN_RANK)), Missions.lowest_rank(match_number)), 0, MAX_RANK)


static func pack_suits(booster: Dictionary, match_number: int) -> Array[Card.Suit]:
	var suits: Array[Card.Suit] = []
	match String(booster.get("suits", "normal")):
		"smoke":
			suits.append(Card.Suit.SMOKE)
		"drink":
			suits.append(Card.Suit.ALK)
		"all":
			for i in NORMAL_SUIT_WEIGHT:
				suits.append_array(NORMAL_SUITS)
			suits.append_array(trump_suits(match_number))
		_:
			suits.append_array(NORMAL_SUITS)
	return suits


static func trump_suits(match_number: int) -> Array[Card.Suit]:
	var suits: Array[Card.Suit] = [Card.Suit.SMOKE]
	if match_number >= PlayerDataManager.ALK_BOOSTER_CARDS_FROM_MATCH:
		suits.append(Card.Suit.ALK)
	return suits


static func special_effects() -> Array:
	var effects: Array = CardEffect.Id.values()
	effects.erase(CardEffect.Id.NONE)
	return effects


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_at(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		click_at(event.position)


func hover_at(point: Vector2) -> void:
	var index := -1
	if state == State.REVEAL or state == State.DONE:
		for i in card_visuals.size():
			if flipped[i] and _card_rect(i).has_point(point):
				index = i
				break
	_set_hovered(index)


func _set_hovered(index: int) -> void:
	if index == _hovered:
		return
	if _hovered >= 0 and _hovered < card_visuals.size():
		card_visuals[_hovered].modulate = Color.WHITE
		BuffTooltip.hide_for(card_visuals[_hovered])
	_hovered = index
	if index < 0:
		return
	var visual := card_visuals[index]
	visual.modulate = HOVER_TINT
	Sfx.play_hover_card()
	var canvas := get_canvas_layer_node()
	BuffTooltip.show_for(visual, (canvas.layer if canvas != null else 0) + 1)


func click_at(point: Vector2) -> void:
	match state:
		State.CLOSED:
			if Rect2(_pack.position, PACK_SIZE).has_point(point):
				Sfx.play_booster_rip()
				_rip_open()
		State.REVEAL:
			for i in card_visuals.size():
				if not flipped[i] and _card_rect(i).has_point(point):
					flip(i)
					return
		State.DONE:
			if InteractionManager.uses_touch():
				var before := _hovered
				hover_at(point)
				if _hovered >= 0 and _hovered != before:
					return
			_send_off()


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
		visual.show_back()
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
	Sfx.play_card_flip()
	if _is_rare(cards[index]) or _is_special(cards[index]):
		Sfx.play_booster_cheer()
	var visual := card_visuals[index]
	var turn := create_tween()
	turn.tween_property(visual, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	turn.tween_callback(func() -> void:
		visual.show_front()
		_play_flip_effect(visual, cards[index]))
	turn.tween_property(visual, "scale:x", CARD_SCALE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await turn.finished
	if state != State.REVEAL:
		return
	hover_at(get_local_mouse_position())
	if not flipped.has(false):
		state = State.DONE
		_take_arrow.modulate.a = 0.0
		_take_arrow.show()
		create_tween().tween_property(_take_arrow, "modulate:a", 1.0, 0.25)


func _play_flip_effect(visual: CardVisual, card: Card) -> void:
	_flash_effect(visual)
	_sparks_effect(visual, card)
	if _is_special(card):
		_special_effect(visual, card)


func _flip_overlay(visual: CardVisual) -> ShaderMaterial:
	var fx := ShaderMaterial.new()
	fx.shader = FLIP_FX_SHADER
	var overlay := TextureRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.texture = CARD_MASK
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.size = CARD_SIZE
	overlay.material = fx
	visual.add_child(overlay)
	get_tree().create_timer(FLIP_FX_TIME + 0.05, true, false, true).timeout.connect(overlay.queue_free)
	return fx


func _flash_effect(visual: CardVisual) -> void:
	var fx := _flip_overlay(visual)
	fx.set_shader_parameter("flash", 0.9)
	var fade := create_tween()
	fade.tween_method(func(value: float) -> void:
		fx.set_shader_parameter("flash", value), 0.9, 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var punch := create_tween()
	punch.tween_property(visual, "scale:y", CARD_SCALE * 1.12, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(visual, "scale:y", CARD_SCALE, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _is_rare(card: Card) -> bool:
	return card.suit == Card.Suit.SMOKE or card.suit == Card.Suit.ALK


func _is_special(card: Card) -> bool:
	return card.has_effect()


func _fx_color(card: Card) -> Color:
	if _is_special(card):
		return CardEffect.color(card.effect)
	match card.suit:
		Card.Suit.SMOKE:
			return Color(1.0, 0.55, 0.25)
		Card.Suit.ALK:
			return Color(0.45, 0.8, 1.0)
	return Color(1.0, 0.95, 0.8)


func _sparks_effect(visual: CardVisual, card: Card) -> void:
	var rare := _is_rare(card) or _is_special(card)
	var color := _fx_color(card)
	var sparks := _spark_emitter()
	sparks.amount = 28 if rare else 14
	sparks.lifetime = FLIP_FX_TIME
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = CARD_SIZE * CARD_SCALE / 2.0
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	sparks.gravity = Vector2(0, 240)
	sparks.initial_velocity_min = 60.0 if rare else 40.0
	sparks.initial_velocity_max = 150.0 if rare else 90.0
	sparks.damping_min = 80.0
	sparks.damping_max = 140.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.0 if rare else 1.5
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	sparks.color_ramp = fade
	sparks.position = visual.position + CARD_SIZE / 2.0
	sparks.z_index = 2
	add_child(sparks)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
	var glow_color := color.lerp(Color.WHITE, 0.5) * 1.4 if rare else Color(1.25, 1.22, 1.15)
	var glow := create_tween()
	glow.tween_property(visual, "modulate", Color(glow_color, 1.0), 0.05)
	glow.tween_property(visual, "modulate", Color.WHITE, 0.25)


func _spark_emitter() -> CPUParticles2D:
	var dot := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	dot.fill(Color.WHITE)
	var sparks := CPUParticles2D.new()
	sparks.texture = ImageTexture.create_from_image(dot)
	sparks.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	return sparks


func _ramp(start: Color, middle: Color, middle_offset: float, end: Color) -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, middle_offset, 1.0])
	ramp.colors = PackedColorArray([start, middle, end])
	return ramp


func _special_effect(visual: CardVisual, card: Card) -> void:
	var color := _fx_color(card)
	var ring := _spark_emitter()
	ring.amount = 40
	ring.lifetime = SPECIAL_FX_TIME
	ring.spread = 180.0
	ring.gravity = Vector2.ZERO
	ring.initial_velocity_min = 180.0
	ring.initial_velocity_max = 240.0
	ring.damping_min = 220.0
	ring.damping_max = 260.0
	ring.scale_amount_min = 2.0
	ring.scale_amount_max = 3.0
	ring.color_ramp = _ramp(Color.WHITE, color.lightened(0.3), 0.25, Color(color, 0.0))
	ring.position = visual.position + CARD_SIZE / 2.0
	ring.z_index = 3
	add_child(ring)
	ring.emitting = true
	ring.finished.connect(ring.queue_free)

	var fountain := _spark_emitter()
	fountain.amount = 36
	fountain.explosiveness = 0.6
	fountain.lifetime = SPECIAL_FX_TIME
	fountain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fountain.emission_rect_extents = Vector2(CARD_SIZE.x * CARD_SCALE / 2.0, 4.0)
	fountain.direction = Vector2.UP
	fountain.spread = 25.0
	fountain.gravity = Vector2(0, 160)
	fountain.initial_velocity_min = 120.0
	fountain.initial_velocity_max = 220.0
	fountain.scale_amount_min = 1.0
	fountain.scale_amount_max = 2.5
	var gold := Color(1.0, 0.85, 0.4)
	fountain.color_ramp = _ramp(gold, color, 0.5, Color(color, 0.0))
	fountain.position = visual.position + Vector2(CARD_SIZE.x / 2.0, CARD_SIZE.y / 2.0 + CARD_SIZE.y * CARD_SCALE / 2.0)
	fountain.z_index = 2
	add_child(fountain)
	get_tree().create_timer(0.12, true, false, true).timeout.connect(func() -> void:
		fountain.emitting = true)
	fountain.finished.connect(fountain.queue_free)

	var wobble := create_tween()
	for angle in [-0.09, 0.07, -0.04, 0.0]:
		wobble.tween_property(visual, "rotation", angle, 0.07).set_trans(Tween.TRANS_SINE)

	var pulse_color := Color(color.lerp(Color.WHITE, 0.35) * 1.6, 1.0)
	var pulse := create_tween()
	pulse.tween_interval(0.3)
	for i in 3:
		pulse.tween_property(visual, "modulate", pulse_color, 0.1)
		pulse.tween_property(visual, "modulate", Color.WHITE, 0.18)

	var fx := _flip_overlay(visual)
	fx.set_shader_parameter("flash", 0.0)
	var flash := create_tween()
	flash.tween_interval(0.18)
	flash.tween_method(func(value: float) -> void:
		fx.set_shader_parameter("flash", value), 0.7, 0.0, 0.17)


func _send_off() -> void:
	state = State.LEAVING
	_set_hovered(-1)
	_take_arrow.hide()
	PlayerDataManager.add_to_collection(cards)
	Sfx.play_booster_whoosh()
	var exit_x := get_viewport_rect().size.x + CARD_SIZE.x * CARD_SCALE
	var fly := create_tween()
	fly.set_parallel(true)
	var count := card_visuals.size()
	for i in count:
		var visual := card_visuals[i]
		var delay := (count - 1 - i) * 0.06
		Sfx.play_card_move(delay)
		fly.tween_property(visual, "position:x", exit_x, 0.45).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		fly.tween_property(visual, "rotation", randf_range(0.15, 0.35), 0.45).set_delay(delay)
	await fly.finished
	close()


func close() -> void:
	_set_hovered(-1)
	for visual in card_visuals:
		visual.queue_free()
	card_visuals.clear()
	cards = []
	state = State.HIDDEN
	hide()
	finished.emit()
