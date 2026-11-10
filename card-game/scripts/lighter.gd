extends Area2D
class_name Lighter
@export var hover_offset: Vector2 = Vector2(0, -4)

const GROUP := "table_lighter"
const FLY_TIME := 0.55
const RETURN_TIME := 0.5
const ARC_HEIGHT := 90.0
const FLAME_GAP := 4.0
const LIGHT_LEAN := 0.45
const ART_LEAN := 0.0
const FLY_Z_INDEX := 51

signal returned

@onready var sprite: Sprite2D = $Sprite2D

var _base_position: Vector2
var _busy := false

func _ready() -> void:

	_base_position = sprite.position
	add_to_group(GROUP)
	TableShadow.add_to(sprite)
	InteractionManager.grow_touch_shape($CollisionShape2D, Vector2(60, 84))

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


static func find_in(tree: SceneTree) -> Lighter:
	return tree.get_first_node_in_group(GROUP) as Lighter


func is_away() -> bool:
	return _busy


func light_cigarette(smoke: AiSmoke, side: float) -> void:
	while _busy:
		await returned
	if not is_instance_valid(smoke):
		return
	if DisplayServer.get_name() == "headless":
		smoke.ignite()
		return

	_busy = true
	input_pickable = false
	sprite.position = _base_position
	var home_position := global_position
	var home_rotation := global_rotation
	var home_z := z_index
	z_index = FLY_Z_INDEX

	if not smoke.has_appeared:
		await smoke.appeared
	if is_instance_valid(smoke):
		var tilt := -LIGHT_LEAN * side - ART_LEAN
		var top := _nozzle_offset() - Vector2(0.0, FLAME_GAP)
		var target := smoke.tip_global_position() - top.rotated(tilt)
		await _fly(home_position, target, home_rotation, tilt, FLY_TIME)
		if is_instance_valid(smoke):
			smoke.ignite()
			await get_tree().create_timer(AiSmoke.LIGHT_TIME, false).timeout

	await _fly(global_position, home_position, global_rotation, home_rotation, RETURN_TIME)
	global_position = home_position
	global_rotation = home_rotation
	z_index = home_z
	input_pickable = true
	_busy = false
	returned.emit()


func _nozzle_offset() -> Vector2:
	var art := sprite.get_rect()
	var local_top := Vector2(art.position.x + art.size.x * 0.5, art.position.y)
	var image := sprite.texture.get_image() if sprite.texture != null else null
	if image != null:
		var used := image.get_used_rect()
		if used.has_area():
			var row := used.position.y
			var first := -1
			var last := -1
			for x in range(used.position.x, used.end.x):
				if image.get_pixel(x, row).a > 0.5:
					if first < 0:
						first = x
					last = x
			if first >= 0:
				local_top = art.position + Vector2((first + last + 1) * 0.5, row)
	return sprite.transform * local_top


func _fly(from: Vector2, to: Vector2, from_rotation: float, to_rotation: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_method(_fly_step.bind(from, to, from_rotation, to_rotation), 0.0, 1.0, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tween.finished


func _fly_step(t: float, from: Vector2, to: Vector2, from_rotation: float, to_rotation: float) -> void:
	global_position = from.lerp(to, t) + Vector2(0.0, -ARC_HEIGHT * 4.0 * t * (1.0 - t))
	global_rotation = lerp_angle(from_rotation, to_rotation, t) + sin(t * PI) * 0.25 * signf(to.x - from.x)


func _on_mouse_entered() -> void:
	if _busy:
		return
	sprite.position = _base_position + hover_offset


func _on_mouse_exited() -> void:
	sprite.position = _base_position


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if _busy:
		return
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		on_clicked()


func on_clicked() -> void:
	if _busy:
		return
	InteractionManager.usedLighter()
