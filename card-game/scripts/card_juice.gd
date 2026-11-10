extends RefCounted
class_name CardJuice

const ENABLED := true

const FOLLOW_SPEED := 14.0
const DRAG_FOLLOW_SPEED := 22.0
const ROTATION_SPEED := 12.0
const HOVER_SPEED := 16.0

const IDLE_SWAY_DEG := 0.6
const IDLE_SWAY_SPEED := 1.3
const IDLE_BOB_PX := 2.0
const IDLE_BOB_SPEED := 1.7

const FAN_ANGLE_DEG := 2.0
const FAN_DROP_PX := 2.5

const HOVER_LIFT_PX := 12.0
const HOVER_TILT_DEG := 4.0
const HOVER_SQUISH := 0.04

const DRAG_TILT_PER_SPEED := 0.025
const DRAG_TILT_MAX_DEG := 14.0

const SQUASH_STIFFNESS := 320.0
const SQUASH_DAMPING := 14.0
const SQUASH_MAX := 0.25
const PICKUP_SQUASH := -2.2
const RANK_POP_SQUASH := 2.4
const DEAL_LAND_SQUASH := 1.8
const DEAL_SPIN_DEG := 18.0

const DENY_WOBBLE_DEG := 7.0
const DENY_FREQ := 38.0
const DENY_DECAY := 7.0

const TABLE_LAND_PUNCH := Vector2(1.12, 0.88)
const TABLE_LAND_TIME := 0.22

const WIN_POP_SCALE := 1.22
const WIN_SHAKE_PX := 5.0
const WIN_SHAKE_TIME := 0.25
const WIN_SPARKS := 26
const WIN_SPARK_COLOR := Color(1.0, 0.85, 0.3)

const NUMBER_POP_RISE_PX := 34.0
const NUMBER_POP_TIME := 0.8
const NUMBER_POP_FONT_SIZE := 22

const SHINE_INTERVAL := 3.4
const SHINE_SWEEP_TIME := 0.7
const SHINE_STRENGTH := 0.45

const GRID_HOVER_SCALE := 1.08
const GRID_HOVER_TILT_DEG := 2.5
const GRID_HOVER_TIME := 0.18

const PIXEL := 3

static var _shake_tween: Tween
static var _shake_viewport: Viewport


static func shake(node: Node, strength: float, duration: float) -> void:
	if not ENABLED or node == null or not node.is_inside_tree():
		return
	var viewport := node.get_viewport()
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		_reset_shake()
	_shake_viewport = viewport
	_shake_tween = node.get_tree().create_tween()
	var view_size := viewport.get_visible_rect().size
	var center := view_size * 0.5
	_shake_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(viewport):
			var amount := strength * (1.0 - t)
			var offset := (Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount).round()
			var zoom := 1.0 + (amount * 2.0 + 2.0) / minf(view_size.x, view_size.y)
			viewport.canvas_transform = Transform2D(0.0, Vector2.ONE * zoom, 0.0, center - center * zoom + offset), 0.0, 1.0, duration)
	_shake_tween.tween_callback(_reset_shake)


static func _reset_shake() -> void:
	if is_instance_valid(_shake_viewport):
		_shake_viewport.canvas_transform = Transform2D.IDENTITY
	_shake_viewport = null


static func sparks(parent: Node, global_center: Vector2, color: Color, amount: int, extents: Vector2) -> void:
	if not ENABLED or parent == null:
		return
	var dot := Image.create(PIXEL, PIXEL, false, Image.FORMAT_RGBA8)
	dot.fill(Color.WHITE)
	var burst := CPUParticles2D.new()
	burst.texture = ImageTexture.create_from_image(dot)
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = amount
	burst.lifetime = 0.6
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	burst.emission_rect_extents = extents
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2(0, 260)
	burst.initial_velocity_min = 70.0
	burst.initial_velocity_max = 170.0
	burst.damping_min = 90.0
	burst.damping_max = 150.0
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.0
	var fade := Gradient.new()
	fade.set_color(0, color.lerp(Color.WHITE, 0.4))
	fade.set_color(1, Color(color, 0.0))
	burst.color_ramp = fade
	burst.z_index = 80
	burst.top_level = true
	parent.add_child(burst)
	burst.global_position = global_center
	burst.emitting = true
	burst.finished.connect(burst.queue_free)


static func number_pop(parent: Node, global_top_center: Vector2, text: String, color: Color) -> void:
	if not ENABLED or parent == null:
		return
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", NUMBER_POP_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.04))
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 90
	label.top_level = true
	parent.add_child(label)
	label.reset_size()
	label.pivot_offset = label.size * 0.5
	var start := (global_top_center - Vector2(label.size.x * 0.5, label.size.y)).round()
	label.global_position = start
	label.scale = Vector2.ONE * 0.4
	var tween := label.create_tween()
	tween.set_parallel()
	tween.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position:y", start.y - NUMBER_POP_RISE_PX, NUMBER_POP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, NUMBER_POP_TIME * 0.4).set_delay(NUMBER_POP_TIME * 0.6)
	tween.chain().tween_callback(label.queue_free)


static func grid_hover(node: Control, on: bool) -> void:
	if not ENABLED or node == null:
		return
	node.pivot_offset = node.size * 0.5
	var previous: Variant = node.get_meta("juice_tween", null)
	if previous is Tween and previous.is_valid():
		previous.kill()
	var tween := node.create_tween()
	node.set_meta("juice_tween", tween)
	tween.set_parallel()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	var tilt := deg_to_rad(GRID_HOVER_TILT_DEG) * (1.0 if randf() < 0.5 else -1.0)
	tween.tween_property(node, "scale", Vector2.ONE * (GRID_HOVER_SCALE if on else 1.0), GRID_HOVER_TIME)
	tween.tween_property(node, "rotation", tilt if on else 0.0, GRID_HOVER_TIME)
