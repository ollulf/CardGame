extends Node2D
class_name TableShadow

const OFFSET := Vector2(3, 6)
const COLOR := Color(0, 0, 0, 0.4)
const NODE_NAME := "TableShadow"

var _source: CanvasItem
var _twin: CanvasItem
var _synced: Array[StringName] = []
var lift := 0.0


static func add_to(item: CanvasItem, synced_properties: Array[StringName] = []) -> TableShadow:
	if item == null:
		return null
	var existing := item.get_node_or_null(NODE_NAME) as TableShadow
	if existing != null:
		return existing
	var shadow := TableShadow.new()
	shadow.name = NODE_NAME
	shadow._source = item
	shadow._synced = synced_properties
	shadow.show_behind_parent = true
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.self_modulate = COLOR
	if not (item is Sprite2D or item is TextureRect) and item.get_script() != null:
		shadow._twin = item.get_script().new()
		shadow._twin.self_modulate = COLOR
		shadow.self_modulate = Color.WHITE
		shadow.add_child(shadow._twin)
	item.add_child(shadow, false, Node.INTERNAL_MODE_FRONT)
	return shadow


func _process(_delta: float) -> void:
	_follow()
	if _twin != null:
		_sync_twin()
	else:
		queue_redraw()


func _follow() -> void:
	var parent_xform := _source.get_global_transform()
	if absf(parent_xform.determinant()) < 0.0001:
		return
	position = parent_xform.affine_inverse().basis_xform(OFFSET + Vector2(lift * 0.5, lift))
	if _twin == null:
		self_modulate.a = COLOR.a * (1.0 - lift * 0.05)


func _sync_twin() -> void:
	var twin_2d := _twin as Node2D
	if twin_2d != null:
		twin_2d.transform = Transform2D.IDENTITY
	for property in _synced:
		var value: Variant = _source.get(property)
		if _twin.get(property) != value:
			_twin.set(property, value)


func _draw() -> void:
	if _source is Sprite2D:
		_draw_sprite(_source)
	elif _source is TextureRect:
		var rect_source := _source as TextureRect
		if rect_source.texture != null:
			draw_texture_rect(rect_source.texture, Rect2(Vector2.ZERO, rect_source.size), false)


func _draw_sprite(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return
	var dest := sprite.get_rect()
	var src: Rect2
	if sprite.region_enabled:
		src = sprite.region_rect
	else:
		var frame_size := sprite.texture.get_size() / Vector2(sprite.hframes, sprite.vframes)
		src = Rect2(Vector2(sprite.frame_coords) * frame_size, frame_size)
	if sprite.flip_h:
		dest.size.x = -dest.size.x
	if sprite.flip_v:
		dest.size.y = -dest.size.y
	draw_texture_rect_region(sprite.texture, dest, src)
