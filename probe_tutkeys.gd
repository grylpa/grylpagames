extends Node

# TEMPORARY PROBE — delete after use.
#
# Every keyboard action and bottom-bar (hamburger) option, fired WHILE A TUTORIAL IS RUNNING, for
# each game that has one. After each, the state has to be one of exactly two things:
#
#   still coaching   the runner is alive and `tutorial_mode` is true, and the runner is not wedged
#                    on a board that was rebuilt underneath it;
#   cleanly ended    the runner is gone AND `tutorial_mode` is false.
#
# The state that must never happen is `tutorial_mode` true with no runner: every guard in
# generic_game_util.gd goes on suppressing the player's REAL scores, for the rest of the session.

const ACTIONS: Array = [
	"help", "mainmenu", "new_board", "esc", "scores", "instructions",
	"pause", "mute", "zoom", "clue", "faster", "slower", "stop", "reminder",
]

var _fails: Array = []
var _cur: String = ""

func _fail(m: String) -> void:
	_fails.append("[%s] %s" % [_cur, m])

func _ready() -> void:
	MainGlobals.init_globals(Vector2(680, 788))
	var games: Array = OS.get_environment("PROBE_GAMES").split(",", false)
	if games.is_empty():
		games = ["gorilla"]
	if OS.get_environment("PROBE_SEQ") == "1":
		for g: String in games:
			for seq: Array in [["help", "esc"], ["help", "esc", "esc"],
					["help", "mainmenu"], ["instructions", "esc"], ["scores", "esc"]]:
				await _case(g, seq)
	else:
		for g: String in games:
			for act: String in ACTIONS:
				await _case(g, [act])
	print("")
	if _fails.is_empty():
		print("PROBE OK")
	else:
		for f: String in _fails:
			print("PROBE FAIL ", f)
	get_tree().quit()

func _case(folder: String, actions: Array) -> void:
	_cur = "%s / %s" % [folder, " + ".join(actions)]
	var main: Node = load("res://%s/scenes/main.tscn" % folder).instantiate()
	add_child(main)
	for _i in 10:
		await get_tree().process_frame
	if not main.has_method("start_tutorial"):
		main.queue_free()
		return
	var game: GenericGameUtil = main.get("game")
	main.call("start_tutorial")
	for _i in 40:
		await get_tree().process_frame
	if _runner(main) == null:
		print("  %-22s (tutorial did not start; skipped)" % _cur)
		main.queue_free()
		for _i in 4:
			await get_tree().process_frame
		return
	var step_before = _runner(main).get("_idx")
	# A RESTART and a WEDGE both leave the coach on step 0. The instance id is what tells them
	# apart: a restart is a new runner, a wedge is the old one that never moved.
	var runner_before: int = _runner(main).get_instance_id()

	var had_dialog: bool = false
	var overlays_seen: Array = []
	for action: String in actions:
		MainGlobals.sim_action(action)
		for _i in 25:
			await get_tree().process_frame
		for k in MainGlobals.visible_screens.keys():
			if not (k in overlays_seen):
				overlays_seen.append(k)
		# A confirm dialog counts as "not decided yet" — say Yes, which is the destructive branch
		# and therefore the one worth checking.
		var yes: Button = _button(get_tree().root, "Yes")
		if yes != null:
			had_dialog = true
			yes.emit_signal("pressed")
			for _i in 30:
				await get_tree().process_frame

	var runner = _runner(main)
	var mode: bool = game.tutorial_mode
	var state: String
	if runner == null and not mode:
		state = "cleanly ended"
	elif runner != null and mode:
		state = "still coaching (step %s)" % str(runner.get("_idx"))
	elif runner == null and mode:
		state = "*** tutorial_mode STUCK TRUE with no runner ***"
	else:
		state = "*** runner alive but tutorial_mode false ***"
	if actions == ["new_board"] and runner != null \
			and runner.get_instance_id() == runner_before:
		_fail("N did not restart the tutorial — same runner, still on step %s" % str(step_before))
	print("  %-30s dialog=%-5s -> %-34s  help_up=%s  menu_up=%s"
		% [_cur, had_dialog, state, MainGlobals.is_screen_visible("help"),
		   _menu_visible(main)])
	# Which overlays were actually up matters: an action that opened nothing is not evidence about
	# who owns ESC. "tutorial" is the runner's own freeze marker and is always there.
	print("        overlays up: %s" % str(overlays_seen))

	if runner == null and mode:
		_fail("left tutorial_mode true with no runner — real scores stay suppressed")
	if runner != null and not mode:
		_fail("left the runner alive with tutorial_mode false")
	# Wedged: still coaching, but the board was rebuilt under it and the step never moves again.
	if runner != null and mode:
		var restarted: bool = runner.get_instance_id() != runner_before
		if restarted:
			state += " [RESTARTED]"
		var t: float = 0.0
		while t < 2.0 and _runner(main) != null:
			await get_tree().process_frame
			t += get_process_delta_time()
		var still = _runner(main)
		if still != null and not restarted and still.get("_idx") == step_before \
				and still.get_instance_id() == runner_before and had_dialog:
			_fail("a confirmed dialog rebuilt the board and the coach is stuck on step %s"
				% str(step_before))
	main.queue_free()
	for _i in 6:
		await get_tree().process_frame

# Is the game's own main menu the thing on screen?
func _menu_visible(main: Node) -> bool:
	var mm = main.get("main_menu")
	return mm != null and is_instance_valid(mm) and mm.visible

func _runner(main: Node):
	for n in _all(main):
		var s: Script = n.get_script()
		if s != null and s.resource_path.ends_with("/tutorial.gd") and not n.get("_finished"):
			return n
	return null

func _button(root: Node, word: String) -> Button:
	for n in _all(root):
		if n is Button and n.visible and String(n.text).contains(word):
			return n
	return null

func _all(n: Node) -> Array:
	var out: Array = []
	if n == null or not is_instance_valid(n):
		return out
	for c in n.get_children():
		out.append(c)
		out.append_array(_all(c))
	return out
