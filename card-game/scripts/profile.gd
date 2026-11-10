extends Node

signal changed

const PROFILE_PATH := "user://profile.json"
const PROFILE_VERSION := 1

var enabled := Engine.get_write_movie_path() == "" and DisplayServer.get_name() != "headless"
var profile_path := PROFILE_PATH
var matches_played := 0

func _ready() -> void:
	load_profile()
	GameManager.match_finished.connect(_on_match_over)
	GameManager.player_kicked.connect(_on_match_over)
	GameManager.run_won.connect(_on_match_over)

func load_profile() -> void:
	matches_played = 0
	if not enabled or not FileAccess.file_exists(profile_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	if not data is Dictionary:
		push_warning("Profile file %s is unreadable, ignoring it" % profile_path)
		return
	var value = data.get("matches_played")
	if value is float or value is int:
		matches_played = maxi(0, int(value))

func save_profile() -> void:
	if not enabled:
		return
	var data := {"version": PROFILE_VERSION, "matches_played": matches_played}
	var temp_path := profile_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write profile file %s" % temp_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if DirAccess.rename_absolute(temp_path, profile_path) != OK:
		push_warning("Could not replace profile file %s" % profile_path)

func set_matches_played(value: int) -> void:
	matches_played = maxi(0, value)
	save_profile()
	changed.emit()

func _on_match_over(_loosers = null) -> void:
	if GameManager.replaying_finish:
		return
	set_matches_played(matches_played + 1)
