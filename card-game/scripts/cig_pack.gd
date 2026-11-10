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

var _base_position: Vector2

func _ready() -> void:
	visible = true
	InteractionManager.cigPack = self
	
	_base_position = sprite.position
	TableShadow.add_to(sprite)
	InteractionManager.grow_touch_shape($CollisionShape2D, Vector2(84, 100))

	if normal_texture != null:
		sprite.texture = normal_texture

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	update_label()
	visible = cig_amount > 0
	monitorable = visible
	input_pickable = visible


func _on_mouse_entered() -> void:
	if hover_texture != null:
		sprite.texture = hover_texture
	sprite.position = _base_position + hover_offset


func _on_mouse_exited() -> void:
	if normal_texture != null:
		sprite.texture = normal_texture
	sprite.position = _base_position


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		on_clicked()


func on_clicked() -> void:
	InteractionManager.pickedUpCig()
	update_label()

func update_label():
	amount_label.text = str(cig_amount);


func add_cigarettes(n: int) -> void:
	cig_amount += n


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
