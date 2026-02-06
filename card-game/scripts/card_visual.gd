extends Control
class_name CardVisual

var card: Card
var face_down: bool = false

@onready var suit_icon: TextureRect = $SuitIcon
@onready var suit_icon_2: TextureRect = $SuitIcon2
@onready var rank_label: Label = $RankLabel
@onready var rank_label_2: Label = $RankLabel2

# --- Hover FX (driven externally) ---
@export var hover_scale: float = 1.4
@export var hover_z_index: int = 15
@export var hover_anim_time: float = 0.12

var _base_scale: Vector2
var _base_pos: Vector2
var _base_z: int
var _tween: Tween

func setup(data: Card, _face_down: bool) -> void:
	card = data
	face_down = _face_down

	card.values_changed.connect(update_visuals)
	card.removed.connect(destroy)

	if not face_down:
		update_visuals()

func destroy():
	queue_free()

func update_visuals():
	rank_label.text = str(card.rank)
	rank_label_2.text = str(card.rank)

	suit_icon.texture = suit_to_texture(card)
	suit_icon_2.texture = suit_to_texture(card)


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
	if face_down:
		return

	# Cache base at the moment of hover (so relayout restores correctly)
	_base_pos = position

	z_index = hover_z_index

	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", _base_scale * hover_scale, hover_anim_time)


func hover_exit() -> void:
	if face_down:
		return

	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", _base_scale, hover_anim_time)

	_tween.finished.connect(func ():
		if is_instance_valid(self):
			position = _base_pos
			z_index = _base_z
	)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
