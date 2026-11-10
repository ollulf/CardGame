extends Control
class_name CardVisual

var card: Card
var face_down: bool = false
var hover_enabled: bool = true
var dragging: bool = false

const RANK_INCREASED_COLOR := Color(0.4, 1.0, 0.45)
const RANK_DECREASED_COLOR := Color(1.0, 0.4, 0.4)
const LOCKED_COLOR := Color(0.5, 0.5, 0.5)
const CARD_BACK := preload("res://sprites/card_backside.png")
const CARD_FACE_SIZE := Vector2(60, 90)

# --- Hover FX (driven externally) ---
@export var hover_scale: float = 1.4
@export var hover_z_index: int = 15
@export var hover_anim_time: float = 0.12
@export var drag_z_index: int = 50
@export var float_anim_time: float = 0.35
@export var deal_anim_time: float = 0.4

var _base_scale: Vector2
var _base_z: int
var _tween: Tween
var _hover_active: bool = false

func setup(data: Card, _face_down: bool) -> void:
	card = data
	face_down = _face_down

	card.values_changed.connect(update_visuals)
	card.removed.connect(destroy)

	update_layout()
	
	if not face_down:
		update_visuals()

func update_layout():
	_base_z = z_index
	if _hover_active:
		z_index = drag_z_index if dragging else hover_z_index
		return
	_base_scale = scale

func add_table_shadow() -> void:
	TableShadow.add_to($Background)

func set_playable(playable: bool) -> void:
	$PlayableOutline.visible = playable

func set_locked(locked: bool) -> void:
	modulate = LOCKED_COLOR if locked else Color.WHITE

func set_winner(active: bool) -> void:
	var outline := get_node_or_null("WinnerOutline")
	if not active:
		if outline != null:
			outline.queue_free()
		return
	if outline == null:
		outline = $PlayableOutline.duplicate()
		outline.name = "WinnerOutline"
		outline.modulate = Color(1.0, 0.85, 0.2)
		add_child(outline)
	outline.visible = true
	var pulse := create_tween()
	pulse.set_trans(Tween.TRANS_SINE)
	pulse.tween_property(self, "scale", scale * 1.15, 0.25)
	pulse.tween_property(self, "scale", scale, 0.25)

func destroy():
	queue_free()

func update_visuals():
	if face_down:
		return

	$RankLabel.text = str(card.rank)
	$RankLabel2.text = str(card.rank)

	$SuitIcon.texture = suit_to_texture(card)
	$SuitIcon2.texture = suit_to_texture(card)

	update_rank_color($RankLabel)
	update_rank_color($RankLabel2)
	update_effect_badge()

func update_effect_badge() -> void:
	var badge := get_node_or_null("EffectBadge") as EffectBadge
	if not card.has_effect():
		if badge != null:
			badge.queue_free()
		return
	if badge == null:
		badge = EffectBadge.create(card.effect)
		add_child(badge)
		var back := get_node_or_null("Back")
		if back != null:
			move_child(badge, back.get_index())
	else:
		badge.set_effect(card.effect)
	badge.position = ((CARD_FACE_SIZE - badge.size) * 0.5).round()

func update_rank_color(label: Label) -> void:
	if card.rank > card.base_rank:
		label.add_theme_color_override("font_color", RANK_INCREASED_COLOR)
	elif card.rank < card.base_rank:
		label.add_theme_color_override("font_color", RANK_DECREASED_COLOR)
	else:
		label.remove_theme_color_override("font_color")

func suit_to_texture(card : Card) -> Texture2D:
	match card.suit:
		Card.Suit.DIAMONDS: 
			return preload("res://sprites/suit_Karo.png")
		Card.Suit.HEARTS: 
			return preload("res://sprites/suit_Herz.png")
		Card.Suit.SPADES:
			return preload("res://sprites/suit_Pik.png")
		Card.Suit.CLUBS:
			return preload("res://sprites/suit_Kreuz.png")
		Card.Suit.ALK:
			return preload("res://sprites/suit_Alk.png")
		Card.Suit.SMOKE:
			return preload("res://sprites/suit_Smoke.png")
		_:
			return null

func hover_enter() -> void:
	if face_down or not hover_enabled:
		return

	_hover_active = true
	z_index = hover_z_index
	BuffTooltip.show_for(self)

	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", _base_scale * hover_scale, hover_anim_time)


func hover_exit() -> void:
	BuffTooltip.hide_for(self)
	if face_down or not hover_enabled:
		return

	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", _base_scale, hover_anim_time)

	_tween.finished.connect(func ():
		if is_instance_valid(self):
			_hover_active = false
			scale = _base_scale
			z_index = _base_z
	)


func begin_drag() -> void:
	dragging = true
	_hover_active = true
	z_index = drag_z_index


func end_drag() -> void:
	dragging = false
	z_index = hover_z_index
	hover_exit()


func float_in_from(from: Transform2D) -> void:
	var target_position := position
	var target_scale := scale
	var target_z := z_index

	hover_enabled = false
	z_index = drag_z_index
	scale = from.get_scale()
	pivot_offset = size * 0.5
	rotation = from.get_rotation()
	global_position = from.origin

	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", target_position, float_anim_time)
	_tween.tween_property(self, "rotation", 0.0, float_anim_time)
	_tween.tween_property(self, "scale", target_scale, float_anim_time)
	_tween.finished.connect(_on_float_finished.bind(target_z))


func deal_from(from: Transform2D, reveal: bool) -> void:
	var target_position := position
	var target_scale := scale
	var target_z := z_index
	var start_scale := from.get_scale()

	hover_enabled = false
	z_index = drag_z_index
	scale = start_scale
	global_position = from.origin

	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", target_position, deal_anim_time)
	_tween.tween_method(_deal_step.bind(start_scale, target_scale, reveal), 0.0, 1.0, deal_anim_time)
	_tween.finished.connect(_on_float_finished.bind(target_z))


func fly_off_top(top: float, delay: float, duration: float) -> void:
	hover_enabled = false
	var target := global_position
	target.y = top - size.y * scale.y * 2.0 - 40.0
	var spin := deg_to_rad(randf_range(-20.0, 20.0))

	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "global_position", target, duration).set_delay(delay)
	_tween.tween_property(self, "rotation", rotation + spin, duration).set_delay(delay)
	_tween.chain().tween_callback(queue_free)


func collect_to(gather_center: Vector2, pile_center: Vector2, pile_scale: Vector2, gather_time: float, flip_time: float, fly_time: float) -> void:
	hover_enabled = false
	pivot_offset = size * 0.5
	var flat_scale := scale.x

	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", gather_center - size * 0.5, gather_time)
	_tween.parallel().tween_property(self, "rotation", 0.0, gather_time)
	_tween.tween_property(self, "scale:x", 0.0, flip_time * 0.5).set_ease(Tween.EASE_IN)
	_tween.tween_callback(show_back)
	_tween.tween_property(self, "scale:x", flat_scale, flip_time * 0.5)
	_tween.tween_property(self, "global_position", pile_center - size * 0.5, fly_time).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(self, "scale", pile_scale, fly_time).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(queue_free)


func show_back(show_suit: bool = false) -> void:
	face_down = true
	set_winner(false)
	if has_node("Back"):
		return
	var back := TextureRect.new()
	back.name = "Back"
	back.texture = CARD_BACK
	back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	if show_suit and card != null:
		var icon := TextureRect.new()
		icon.name = "BackSuit"
		icon.texture = suit_to_texture(card)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
		icon.grow_vertical = Control.GROW_DIRECTION_BOTH
		back.add_child(icon)


func flip_face_up(duration: float) -> void:
	pivot_offset = size * 0.5
	var flat_scale := scale.x
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "scale:x", 0.0, duration * 0.5).set_ease(Tween.EASE_IN)
	_tween.tween_callback(show_front)
	_tween.tween_property(self, "scale:x", flat_scale, duration * 0.5).set_ease(Tween.EASE_OUT)


func show_front() -> void:
	face_down = false
	var back := get_node_or_null("Back")
	if back != null:
		back.free()
	update_visuals()


func shake_and_dim(dim_color: Color) -> void:
	var start := position
	_kill_tween()
	_tween = create_tween()
	for offset in [8.0, -8.0, 6.0, -6.0, 3.0, 0.0]:
		_tween.tween_property(self, "position:x", start.x + offset, 0.05)
	_tween.tween_property(self, "modulate", dim_color, 0.2)


func _deal_step(t: float, start_scale: Vector2, target_scale: Vector2, reveal: bool) -> void:
	var s := start_scale.lerp(target_scale, t)
	if reveal:
		s.x *= maxf(absf(cos(t * PI)), 0.05)
		if t >= 0.5 and face_down:
			face_down = false
			update_visuals()
	scale = s


func _on_float_finished(target_z: int) -> void:
	z_index = target_z
	update_layout()
	hover_enabled = true
	if InteractionManager.hovered_card == self:
		hover_enter()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
