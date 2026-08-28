extends Node

# TEMPORARY PROBE — delete after use.
#
# The two games whose level rule is an ALLOWANCE plus a CLOCK rather than a quota:
#
#   parkem  — creatures may reach their parking spot `allowed_arrivals` times; the counter at the
#             top ticks down with each one that parks, and at zero the session is over.
#   pneumo  — the same shape, spent by COLLISIONS instead (`allowed_collisions`).
#
# In both, surviving the level's own clock IS passing the level: there is nothing to finish.
# Both used to end the level when a delivery quota hit zero, and both wore a HUD icon that said
# something else, so what is checked here is that the counter now means what the icon claims.

const GAMES: Array = [
	{"folder": "parkem", "key": "allowed_arrivals", "config": "ParkemLevelConfig", "min_key": "", "counter": ""},
	# pneumo also has to have DELIVERED something: surviving the clock while touching nothing
	# crashes nothing, and used to promote the player with not one capsule landed.
	{"folder": "pneumo", "key": "allowed_collisions", "config": "PneumoLevelConfig",
	 "min_key": "min_deliveries", "counter": "_deliveries"},
]

const TEST_LEVEL: int = 2

var _fails: Array = []
var _cur: String = ""
var _game: GenericGameUtil = null
var _main: Node = null
var _level: Node = null
var _game_done: Array = []

func _fail(m: String) -> void:
	_fails.append("[%s] %s" % [_cur, m])

func _ready() -> void:
	MainGlobals.init_globals(Vector2(680, 788))
	for spec: Dictionary in GAMES:
		await _run_game(spec)
	print("")
	if _fails.is_empty():
		print("PROBE OK (%d games)" % GAMES.size())
	else:
		for f: String in _fails:
			print("PROBE FAIL ", f)
	get_tree().quit()

func _run_game(spec: Dictionary) -> void:
	_cur = String(spec["folder"])
	_main = load("res://%s/scenes/main.tscn" % _cur).instantiate()
	add_child(_main)
	for _i in 8:
		await get_tree().process_frame
	_game = _main.get("game")
	_level = _main.get_node_or_null("Level")
	if _game == null or _level == null:
		_fail("could not reach the game")
		return
	var before: Dictionary = _snap()
	# The app's own save handler writes a score row to disk when the session ends.
	for c: Dictionary in _game.sig_game_is_done.get_connections():
		var cb: Callable = c["callable"]
		if cb.get_object() == _main:
			_game.sig_game_is_done.disconnect(cb)
	_game.sig_game_is_done.connect(_on_game_done)

	var cfg: Dictionary = _cfg(spec, TEST_LEVEL)
	var allowed: int = int(cfg[String(spec["key"])])
	var level_time: int = int(cfg["level_time"])

	if bool(_game.game_over_on_time_out):
		_fail("game_over_on_time_out is still on, so running the clock out ends the SESSION instead of passing the level")

	# --- the level starts on its own allowance and its own clock ---------------------------------
	_level.set("level", TEST_LEVEL)
	_game.tutorial_mode = false
	if _level.get("_tutorial_board") != null:
		_level.set("_tutorial_board", false)
	_game.need_to_increase_level = false
	_level.new_game(false)
	for _i in 4:
		await get_tree().process_frame
	if int(_game.packets_left) != allowed:
		_fail("the counter starts at %d, expected the level's %s of %d" % [_game.packets_left, spec["key"], allowed])
	if int(_game.time_left_sec) != level_time:
		_fail("the clock starts at %ds, expected the level's level_time of %ds" % [_game.time_left_sec, level_time])

	# --- running the clock out passes the level --------------------------------------------------
	var min_key: String = String(spec["min_key"])
	var need: int = int(cfg[min_key]) if min_key != "" else 0
	if min_key != "":
		_level.set(String(spec["counter"]), need)
	_game.level_is_done = false
	_game.need_to_increase_level = false
	_level.call("on_time_over")
	for _i in 6:
		await get_tree().process_frame
	if not bool(_game.need_to_increase_level):
		_fail("surviving the clock did not pass the level")
	if not bool(_game.level_is_done):
		_fail("surviving the clock did not end the level")
	_check_card(allowed)

	# --- ...but only if the level's own minimum was met -------------------------------------------
	if min_key != "":
		_level.set("level", TEST_LEVEL)
		_game.need_to_increase_level = false
		_game.level_is_done = false
		_level.new_game(false)
		for _i in 4:
			await get_tree().process_frame
		_level.set(String(spec["counter"]), need - 1)
		_game.level_is_done = false
		_level.call("on_time_over")
		for _i in 6:
			await get_tree().process_frame
		if bool(_game.need_to_increase_level):
			_fail("%d of the %d required %s still passed the level" % [need - 1, need, min_key])
		var body: String = _card_body()
		if not body.contains("of %d" % need):
			_fail("the card never says how many were required")
		if not body.contains("at least %d" % need):
			_fail("the card never says what the player has to do to pass")
	# The HUD re-emits sig_time_over every tick while the clock sits at zero, so a second one must
	# not re-run the ending.
	_level.call("on_time_over")
	for _i in 2:
		await get_tree().process_frame
	if _cards().size() > 0:
		_fail("a repeat time-over put a second level card on the screen")

	# --- spending the allowance ends the session -------------------------------------------------
	_game_done = []
	# Back to the same level: the time-over above set need_to_increase_level, and new_game() would
	# otherwise start level 3 — whose allowance is a different number.
	_level.set("level", TEST_LEVEL)
	_game.need_to_increase_level = false
	_game.level_is_done = false
	_level.new_game(false)
	for _i in 4:
		await get_tree().process_frame
	_game.playing = true
	for i in allowed:
		if not _game_done.is_empty():
			_fail("the session ended after %d of the %d allowed" % [i, allowed])
			break
		_game.dec_packet()
		await get_tree().process_frame
	for _i in 4:
		await get_tree().process_frame
	if _game_done.is_empty():
		_fail("spending all %d of the allowance did not end the session" % allowed)
	else:
		if bool(_game_done[0]):
			_fail("the session ended as a WIN when the allowance ran out")
		if bool(_game.playing):
			_fail("the session ended but the game is still playing")

	var after: Dictionary = _snap()
	for p: String in before:
		if before[p] != after[p]:
			_fail("wrote to %s" % p.get_file())
	_main.queue_free()
	_main = null
	for _i in 4:
		await get_tree().process_frame

func _cfg(spec: Dictionary, level_id: int) -> Dictionary:
	var script: Script = load("res://%s/scripts/level_config.gd" % spec["folder"])
	return script.get_level(level_id)

func _on_game_done(didwin: bool, _wasaborted: bool) -> void:
	_game_done.append(didwin)

func _cards() -> Array:
	var out: Array = []
	for c in _all_nodes(_level):
		if c.has_method("set_passed") and c.has_method("set_title"):
			out.append(c)
	return out

func _check_card(allowed: int) -> void:
	var body: String = _card_body()
	if body == "":
		_fail("no level card appeared when the clock ran out")
		return
	if not body.contains("of %d" % allowed):
		_fail("the card never says how much of the allowance was spent")

# Reads the level card's text and takes it off the screen, so the next case starts clean.
func _card_body() -> String:
	var cards: Array = _cards()
	if cards.is_empty():
		return ""
	var body: String = ""
	for n in _all_nodes(cards[0]):
		if n is Label or n is RichTextLabel:
			body += String(n.get("text")) + "\n"
	MainGlobals.set_visible("level_done", false)
	for c in cards:
		c.free()
	return body

func _all_nodes(n: Node) -> Array:
	var out: Array = []
	if n == null or not is_instance_valid(n):
		return out
	for c in n.get_children():
		out.append(c)
		out.append_array(_all_nodes(c))
	return out

func _snap() -> Dictionary:
	var out: Dictionary = {}
	for p: String in [_game.get_settings_fname(), _game.get_scores_fname(),
			_game.get_ongoing_score_fname(), _game.get_uploaded_scores_fname(),
			_game._new_best_flag_path()]:
		if FileAccess.file_exists(p):
			var f: FileAccess = FileAccess.open(p, FileAccess.READ)
			out[p] = f.get_buffer(f.get_length()) if f != null else PackedByteArray()
			if f != null:
				f.close()
		else:
			out[p] = null
	return out
