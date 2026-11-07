extends Control
class_name CardVisual

var card: Card
var face_down: bool = false
var hover_enabled: bool = true
var dragging: bool = false

const RANK_INCREASED_COLOR := Color(0.4, 1.0, 0.45)
const RANK_DECREASED_COLOR := Color(1.0, 0.4, 0.4)

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

func set_playable(playable: bool) -> void:
	$PlayableOutline.visible = playable

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

	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", _base_scale * hover_scale, hover_anim_time)


func hover_exit() -> void:
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
	global_position = from.origin

	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", target_position, float_anim_time)
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
