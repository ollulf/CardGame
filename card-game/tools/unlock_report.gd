extends SceneTree

const CHECKPOINTS := [0, 3, 6, 10, 15, 25, 40]

func _init() -> void:
	var options := _options()
	var table := UnlockTable.load_file(options.get("file", UnlockTable.UNLOCKS_PATH))
	print("== Validation ==")
	for message in table.errors:
		print("ERROR   ", message)
	for message in table.warnings:
		print("WARNING ", message)
	if table.errors.is_empty() and table.warnings.is_empty():
		print("ok")
	if not table.errors.is_empty():
		quit(1)
		return
	print("\n== Timeline (matches played) ==")
	for step in table.played_timeline():
		print("%3d  %s" % [step.played, ", ".join(step.ids)])
	for entry in table.unlocks:
		if entry.has("won") or entry.has("runs_won"):
			print("  *  %s (won %d, runs won %d)" % [entry.id, int(entry.get("won", 0)), int(entry.get("runs_won", 0))])
	print("\n== Expected cards per booster ==")
	for played in CHECKPOINTS:
		var profile := {"played": played, "won": int(played * 0.6), "runs_won": played / 10}
		var open := table.unlocked_ids(profile)
		for booster in table.boosters:
			if not table.is_booster_open(booster, open):
				continue
			var odds := table.booster_odds(booster, open)
			var parts: Array = []
			for id in odds:
				parts.append("%s %.2f" % [id, odds[id]])
			print("%3d  %-9s %s" % [played, booster.id, ", ".join(parts)])
	var players := int(options.get("players", "500"))
	var runs := int(options.get("runs", "12"))
	var win := float(options.get("win", "0.6"))
	print("\n== Simulated players: %d players, %d runs each, %.0f%% match win chance ==" % [players, runs, win * 100.0])
	print("%-22s %7s %5s %7s" % ["unlock", "median", "p90", "never"])
	var sim := table.simulate_players(players, runs, win, int(options.get("seed", "1")))
	for entry in table.unlocks:
		var row: Dictionary = sim[entry.id]
		var median: String = "-" if row.median > runs else "run %d" % row.median
		var p90: String = "-" if row.p90 > runs else str(row.p90)
		print("%-22s %7s %5s %6.0f%%" % [entry.id, median, p90, 100.0 * row.never / players])
	quit(0)

func _options() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			result[parts[0]] = parts[1]
	return result
