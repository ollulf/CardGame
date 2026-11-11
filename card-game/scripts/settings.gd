extends Node

const SETTINGS_PATH := "user://settings.cfg"
const BUSES := ["Master", "Music", "Ambience", "SFX"]
const DEFAULT_VOLUME := 1.0
const SILENT_LINEAR := 0.001

var volumes := {}
var muted := false
var fullscreen := false
var enabled := Engine.get_write_movie_path() == "" and DisplayServer.get_name() != "headless"

func _ready() -> void:
	for bus in BUSES:
		volumes[bus] = DEFAULT_VOLUME
	load_settings()
	apply_all()

func load_settings() -> void:
	if not enabled:
		return
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus in BUSES:
		volumes[bus] = clampf(float(cfg.get_value("audio", bus, DEFAULT_VOLUME)), 0.0, 1.0)
	muted = cfg.get_value("audio", "muted", false) == true
	fullscreen = cfg.get_value("display", "fullscreen", false) == true

func save_settings() -> void:
	if not enabled:
		return
	fullscreen = is_fullscreen()
	var cfg := ConfigFile.new()
	for bus in BUSES:
		cfg.set_value("audio", bus, volumes[bus])
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)

func apply_all() -> void:
	for bus in BUSES:
		_apply_volume(bus)
	_apply_mute()
	if enabled and fullscreen != is_fullscreen():
		_apply_fullscreen()

func get_volume(bus: String) -> float:
	return float(volumes.get(bus, DEFAULT_VOLUME))

func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)

func set_muted(value: bool) -> void:
	muted = value
	_apply_mute()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

func _apply_volume(bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var value := get_volume(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, SILENT_LINEAR)))
	if bus != "Master":
		AudioServer.set_bus_mute(index, value <= 0.0)
	else:
		_apply_mute()

func _apply_mute() -> void:
	var index := AudioServer.get_bus_index("Master")
	if index >= 0:
		AudioServer.set_bus_mute(index, muted or get_volume("Master") <= 0.0)

func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
