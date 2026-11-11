class_name CardFx

const FX_PIXEL := 3.0
const ICON_PIXEL := 4.0
const POP_TIME := 0.18
const POP_HOLD := 0.35
const POP_FADE := 0.3
const POP_RISE := 34.0
const BURST_COUNT := 12
const BURST_RADIUS := 64.0
const BURST_TIME := 0.45
const THUMP_SCALE := 0.9
const THUMP_TIME := 0.08
const THUMP_SETTLE := 0.22
const SPLAT_COUNT := 14
const SPLAT_RADIUS := 52.0
const SPLAT_TIME := 0.4
const STAMP_LENGTH := 0.5


static func special_pop(visual: CardVisual, effect: int) -> void:
	if not is_instance_valid(visual) or not visual.is_inside_tree():
		return
	var layer := _layer_over(visual)
	var center := _center(visual)
	var color := CardEffect.color(effect)
	_burst(layer, center, color, BURST_COUNT, BURST_RADIUS, BURST_TIME, FX_PIXEL * 2.0)
	var texture: Texture2D = EffectBadge.TEXTURES.get(effect)
	if texture == null:
		return
	var icon := Sprite2D.new()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = center.round()
	icon.scale = Vector2.ZERO
	layer.add_child(icon)
	var tween := icon.create_tween()
	tween.tween_property(icon, "scale", Vector2.ONE * ICON_PIXEL * 1.25, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2.ONE * ICON_PIXEL, POP_TIME * 0.6)
	tween.tween_interval(POP_HOLD)
	tween.tween_property(icon, "position:y", icon.position.y - POP_RISE, POP_FADE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(icon, "modulate:a", 0.0, POP_FADE)
	tween.tween_callback(layer.queue_free)


static func stamp_thump(visual: CardVisual, stamp: int) -> void:
	if not is_instance_valid(visual) or not visual.is_inside_tree():
		return
	var layer := _layer_over(visual)
	var center := _center(visual)
	var base_scale := visual.scale
	var base_pivot := visual.pivot_offset
	visual.pivot_offset = visual.size * 0.5
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", base_scale * THUMP_SCALE, THUMP_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "scale", base_scale, THUMP_SETTLE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: visual.pivot_offset = base_pivot)
	_burst(layer, center, CardStamp.color(stamp), SPLAT_COUNT, SPLAT_RADIUS, SPLAT_TIME, FX_PIXEL * 3.0)
	layer.get_tree().create_timer(SPLAT_TIME + 0.1, true).timeout.connect(layer.queue_free)


static func _burst(layer: CanvasLayer, center: Vector2, color: Color, count: int, radius: float, time: float, size: float) -> void:
	for i in count:
		var angle := TAU * float(i) / float(count) + randf_range(-0.2, 0.2)
		var dot := ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.color = color.lightened(0.15) if i % 2 == 0 else color
		dot.size = Vector2.ONE * (size if i % 3 else size * 0.5)
		dot.position = (center - dot.size * 0.5).round()
		layer.add_child(dot)
		var target := (center + Vector2.from_angle(angle) * radius * randf_range(0.7, 1.0) - dot.size * 0.5).round()
		var tween := dot.create_tween().set_parallel(true)
		tween.tween_property(dot, "position", target, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(dot, "modulate:a", 0.0, time * 0.45).set_delay(time * 0.55)


static func _layer_over(visual: CanvasItem) -> CanvasLayer:
	var host := visual.get_canvas_layer_node()
	var layer := CanvasLayer.new()
	layer.layer = (host.layer if host != null else 0) + 1
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	visual.get_tree().root.add_child(layer)
	return layer


static func _center(visual: Control) -> Vector2:
	return visual.get_global_transform_with_canvas() * (visual.size * 0.5)


static func stamp_splat(visual: CardVisual, stamp: int) -> void:
	if not is_instance_valid(visual) or not visual.is_inside_tree():
		return
	var layer := _layer_over(visual)
	_burst(layer, _center(visual), CardStamp.color(stamp), SPLAT_COUNT, SPLAT_RADIUS * 1.3, SPLAT_TIME, FX_PIXEL * 3.0)
	layer.get_tree().create_timer(SPLAT_TIME + 0.1, true).timeout.connect(layer.queue_free)
