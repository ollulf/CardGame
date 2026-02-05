extends Control
class_name Card

var card_data: Dictionary = {}
var _show: bool = false

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


func _ready() -> void:
	_base_scale = scale
	_base_pos = position
	_base_z = z_index


func setup(data: Dictionary, show: bool) -> void:
	card_data = data
	_show = show

	if not _show:
		return

	var suit_key: String = str(card_data.get("suit", ""))
	var rank_value = card_data.get("rank", "")

	rank_label.text = str(rank_value)
	rank_label_2.text = str(rank_value)

	var tex: Texture2D = GameManager.suit_textures.get(suit_key, null)
	suit_icon.texture = tex
	suit_icon_2.texture = tex


func hover_enter() -> void:
	if not _show:
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
	if not _show:
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
