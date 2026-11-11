class_name BoosterArt

const PACK_TEXTURE := preload("res://sprites/booster_pack.png")
const SHINE_SHADER := preload("res://shaders/booster_shine.gdshader")
const SHADING_MAP := preload("res://sprites/booster_pack_map.png")
const SHINE_STAGGER := 0.35
const PACK_COLOR := Color(0.8, 0.8, 0.84, 1)


static func pack_tint(booster: Dictionary) -> Color:
	return booster.get("tint", PACK_COLOR)
