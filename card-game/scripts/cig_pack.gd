extends Area2D
class_name CigPack

@export var normal_texture: Texture2D
@export var hover_texture: Texture2D
@export var hover_offset: Vector2 = Vector2(0, -10)

@export var cig_amount: int = 0:
	set(value):
		var had := cig_amount > 0
		cig_amount = max(value, 0)
		if is_node_ready():
			update_label()
			_refresh_visibility(had)
@onready var amount_label:= $Sprite2D/Amount

@onready var sprite: Sprite2D = $Sprite2D

const PACK_BOTTOM := 16.0
const SMOKE_ICON := preload("res://sprites/suit_Smoke.png")
const SMOKE_ICON_GAP := 1.0

var _base_position: Vector2
var _smoke_icon: Sprite2D
var _label_center: Vector2

func _ready() -> void:
	visible = true
	InteractionManager.cigPack = self
	
	_base_position = sprite.position
	_label_center = amount_label.position + amount_label.size * 0.5
	_smoke_icon = Sprite2D.new()
	_smoke_icon.texture = SMOKE_ICON
	_smoke_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	amount_label.add_sibling(_smoke_icon)
	TableShadow.add_to(sprite)
	InteractionManager.grow_touch_shape($CollisionShape2D, Vector2(84, 100))

	if normal_texture != null:
		_set_texture(normal_texture)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	update_label()
	visible = cig_amount > 0
	monitorable = visible
	input_pickable = visible


func _on_mouse_entered() -> void:
	if hover_texture != null:
		_set_texture(hover_texture)
	sprite.position = _base_position + hover_offset


func _on_mouse_exited() -> void:
	if normal_texture != null:
		_set_texture(normal_texture)
	sprite.position = _base_position


func _set_texture(texture: Texture2D) -> void:
	sprite.texture = texture
	var w := texture.get_width()
	var h := texture.get_height()
	sprite.offset = Vector2((w % 2) * 0.5, PACK_BOTTOM - h * 0.5)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		on_clicked()


func on_clicked() -> void:
	InteractionManager.pickedUpCig()
	update_label()

func update_label():
	amount_label.text = str(cig_amount)
	_place_smoke_icon()


func add_cigarettes(n: int) -> void:
	cig_amount += n
	TutorialPopups.tip("cigs", self)


func _refresh_visibility(had: bool) -> void:
	var has := cig_amount > 0
	monitorable = has
	input_pickable = has
	if has == had:
		return
	if has:
		modulate.a = 0.0
		visible = true
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.25)
		get_tree().call_group("ai_cigarettes_ui", "reveal")
	else:
		visible = false


func _place_smoke_icon() -> void:
	if _smoke_icon == null:
		return
	var font: Font = amount_label.get_theme_font("font")
	var text_width: float = font.get_string_size(amount_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, amount_label.get_theme_font_size("font_size")).x
	var icon_width := SMOKE_ICON.get_width() + SMOKE_ICON_GAP
	var shift := icon_width * 0.5
	amount_label.position.x = _label_center.x - amount_label.size.x * 0.5 - shift
	_smoke_icon.position = Vector2(_label_center.x + text_width * 0.5 - shift + SMOKE_ICON_GAP + SMOKE_ICON.get_width() * 0.5, _label_center.y)
