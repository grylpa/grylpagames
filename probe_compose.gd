extends Node

func _ready() -> void:
	var lv = load("res://whack/scenes/level.tscn").instantiate()
	add_child(lv)
	await get_tree().process_frame
	lv.game.initial_score = 100
	randomize()
	print("%3s %6s  %-26s %-26s %s" % ["lvl", "want", "round = target only", "round = decoys only", "min/max decoys seen"])
	var bad: int = 0
	for lvl in range(1, WhackLevelConfig.LEVELS.size() + 1):
		WhackG.starting_level = lvl
		lv.new_game()
		lv.game.score = 100
		lv.game.time_left_sec = 99999
		lv.game.playing = true
		await get_tree().process_frame
		var n: int = 3000
		var target_only: int = 0
		var decoys_only: int = 0
		var blank: int = 0
		var dmin: int = 99999
		var dmax: int = -1
		for i in range(n):
			lv._round_active = false
			lv._spawn_round()
			var nd: int = lv._decoys.size()
			dmin = min(dmin, nd)
			dmax = max(dmax, nd)
			if lv._target_active and nd == 0:
				target_only += 1
			elif not lv._target_active and nd > 0:
				decoys_only += 1
			elif not lv._target_active:
				blank += 1
		if lvl > 1 and target_only > 0:
			bad += 1
		print("%3d %6d  %8d (%5.1f%%)         %8d (%5.1f%%)         %d..%d   blank %d" % [
			lvl, lv._num_decoys, target_only, 100.0 * target_only / n,
			decoys_only, 100.0 * decoys_only / n, dmin, dmax, blank])
	print("COMPOSE PROBE ", "OK" if bad == 0 else "FAIL (%d levels above 1 can show a lone target)" % bad)
	get_tree().quit()
