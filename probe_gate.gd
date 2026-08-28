extends Node

# TEMPORARY PROBE — delete after use.
#
# Checks the accuracy GATE in the games that just got one, against the pattern the four reference
# games document (aliens, bucketmadness, polkadots, movingcards):
#
#   1. Passing a level      — below the level's accuracy, the SAME level comes round again.
#   2. "complete!" only when it was — the card says "not passed" and drops the check badge.
#   3. A replay starts clean — the per-level counters and stats are cleared on EVERY level start.
#   4. A failed level earns nothing — the score is rolled back to what it was when the level began,
#      and the value SAVED at the moment the level ends is already the rolled-back one.
#
# Each game is instantiated standalone and driven straight through its level-done entry point, so
# no gameplay has to be simulated. Nothing is allowed to touch the player's save files: the app's
# own save handler is disconnected and every save path is snapshotted before and after.

const GAMES: Array = [
	{"folder": "didi", "entry": "_level_done", "base": 60, "cap": 80},
	# whack states its bar per level in its config rather than deriving it, so the probe reads it
	# from there instead of repeating a formula that no longer exists.
	{"folder": "whack", "entry": "_level_done", "base": 55, "cap": 75, "config": "whack"},
	{"folder": "ooo", "entry": "level_is_done", "base": 60, "cap": 80},
	{"folder": "pop", "entry": "level_is_done", "base": 60, "cap": 80},
	{"folder": "friends", "entry": "level_is_done", "base": 60, "cap": 80},
	{"folder": "weris", "entry": "level_is_done", "base": 60, "cap": 80},
]

const TEST_LEVEL: int = 2
const SCORE_AT_START: int = 500
const EARNED_IN_LEVEL: int = 40

var _fails: Array = []
var _cur: String = ""
var _game: GenericGameUtil = null
var _main: Node = null
var _level: Node = null
var _score_when_saved: int = -1
var _saves_seen: int = 0

func _fail(m: String) -> void:
	_fails.append("[%s] %s" % [_cur, m])

func _ready() -> void:
	MainGlobals.init_globals(Vector2(680, 788))
	for spec: Dictionary in GAMES:
		await _run_game(spec)
	await _run_gorilla()
	await _run_wolves()
	await _run_monkeyc()
	for spec: Dictionary in ROUND_GAMES:
		await _run_rounds_game(spec)
	print("")
	if _fails.is_empty():
		print("PROBE OK (%d games)" % (GAMES.size() + 3 + ROUND_GAMES.size()))
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
	if _game == null:
		_fail("could not reach the game util")
		return
	_level = _main.get_node_or_null("Level")
	if _level == null:
		_fail("no Level node")
		return
	var before: Dictionary = _snap()
	# The app's own handler saves a score row to disk the moment a level ends. The probe wants the
	# value it WOULD have saved, not the file, so the handler is replaced with a recorder.
	for c: Dictionary in _game.sig_level_is_done.get_connections():
		var cb: Callable = c["callable"]
		if cb.get_object() == _main:
			_game.sig_level_is_done.disconnect(cb)
	_game.sig_level_is_done.connect(_on_save_moment)

	var need: int = mini(int(spec["base"]) + 5 * (TEST_LEVEL - 1), int(spec["cap"]))
	if spec.has("config"):
		var cfg_script: Script = load("res://%s/scripts/level_config.gd" % spec["config"])
		need = cfg_script.pass_pct_for(TEST_LEVEL)
	# 13/20 is exactly `need` for the 65 games and above it for whack's 60 — a boundary the gate
	# has to let through, since it is stated to the player as "at least NN%".
	await _one_case(spec, need, 13, 7, true)
	await _one_case(spec, need, 1, 9, false)

	var after: Dictionary = _snap()
	for p: String in before:
		if before[p] != after[p]:
			_fail("wrote to %s" % p.get_file())
	_main.queue_free()
	_main = null
	for _i in 4:
		await get_tree().process_frame

# One full pass through a level end: start the level, earn some points, answer to the given
# accuracy, end it, read the card, then press Continue and see which level comes back.
func _one_case(spec: Dictionary, need: int, corrects: int, mistakes: int, want_pass: bool) -> void:
	var what: String = "pass" if want_pass else "fail"
	_level.set("level", TEST_LEVEL)
	_game.need_to_increase_level = false
	_game.score = SCORE_AT_START
	_game.tutorial_mode = false
	if _level.get("_tutorial_board") != null:
		_level.set("_tutorial_board", false)
	_level.new_game(false)
	for _i in 4:
		await get_tree().process_frame
	if _level.get("level") != TEST_LEVEL:
		_fail("%s: new_game moved off level %d before the level even started" % [what, TEST_LEVEL])
		return
	if int(_game.corrects) != 0 or int(_game.mistakes) != 0:
		_fail("%s: new_game did not clear corrects/mistakes (%d/%d) — a replay inherits the misses that failed the level" % [what, _game.corrects, _game.mistakes])
	for entry: Array in _times_lists():
		if not (entry[1] as Array).is_empty():
			_fail("%s: %s still holds %d entries at a fresh level start — the summary averages in the attempt that failed" % [what, entry[0], (entry[1] as Array).size()])

	_game.score = SCORE_AT_START + EARNED_IN_LEVEL
	_game.corrects = corrects
	_game.mistakes = mistakes
	_feed_times()
	var pct: int = _game.session_pct_correct()
	if (pct >= need) != want_pass:
		_fail("%s: the probe's own %d/%d is %d%% against a bar of %d%% — test is wrong, not the game" % [what, corrects, mistakes, pct, need])
		return

	_score_when_saved = -1
	_saves_seen = 0
	_game.level_is_done = false
	_level.call(String(spec["entry"]), true)
	for _i in 6:
		await get_tree().process_frame

	if bool(_game.need_to_increase_level) != want_pass:
		_fail("%s: %d%% against a bar of %d%% set need_to_increase_level=%s" % [what, pct, need, str(_game.need_to_increase_level)])

	var kept: int = SCORE_AT_START if not want_pass else SCORE_AT_START + EARNED_IN_LEVEL
	if _saves_seen == 0:
		_fail("%s: the level end never reached the save handler" % what)
	elif _score_when_saved != kept:
		_fail("%s: the score row was written with %d, expected %d — a failed level must bank nothing" % [what, _score_when_saved, kept])
	if int(_game.score) != SCORE_AT_START + EARNED_IN_LEVEL:
		_fail("%s: the score on screen changed to %d while the summary is still up (expected %d — the rollback belongs in new_game)" % [what, _game.score, SCORE_AT_START + EARNED_IN_LEVEL])

	_check_card(what, want_pass, need)

	# Continue: the level that comes back, and the score it comes back with.
	_level.new_game(false)
	for _i in 4:
		await get_tree().process_frame
	var want_level: int = TEST_LEVEL + 1 if want_pass else TEST_LEVEL
	if int(_level.get("level")) != want_level:
		_fail("%s: Continue landed on level %d, expected %d" % [what, _level.get("level"), want_level])
	if int(_game.score) != kept:
		_fail("%s: after Continue the score is %d, expected %d" % [what, _game.score, kept])

func _on_save_moment(_didwin: bool) -> void:
	_saves_seen += 1
	_score_when_saved = int(_game.score)

# The card is built by scripts/level_done_popup.gd and parented to the level.
func _check_card(what: String, want_pass: bool, need: int) -> void:
	var card: Node = null
	for c in _all_nodes(_level):
		if c.has_method("set_passed") and c.has_method("set_title"):
			card = c
	if card == null:
		_fail("%s: no level-done card appeared" % what)
		return
	if bool(card.get("_passed")) != want_pass:
		_fail("%s: the card was built as passed=%s" % [what, str(card.get("_passed"))])
	var title: String = ""
	var parts = card.get("_parts")
	if parts is Dictionary and parts.has("title"):
		title = String(parts["title"].text)
	var body: String = ""
	for n in _all_nodes(card):
		if n is Label or n is RichTextLabel:
			body += String(n.get("text")) + "\n"
	if want_pass:
		if not title.contains("complete"):
			_fail("%s: the card is titled '%s'" % [what, title])
		if not body.contains("Level passed"):
			_fail("%s: the card never says the player is moving on" % what)
	else:
		if not title.contains("not passed"):
			_fail("%s: the card is titled '%s' — it congratulates the player for failing" % [what, title])
		if not body.contains("at least %d%%" % need):
			_fail("%s: the card never states the bar of %d%%" % [what, need])
	if not body.contains("Accuracy"):
		_fail("%s: the card shows no accuracy row" % what)
	MainGlobals.set_visible("level_done", false)
	card.queue_free()

# Every one of these games shows a per-level timing stat on the card, read off a list the level
# appends to as the player answers. The mean functions return a SENTINEL for an empty list
# (9999 ms, a timeout), so the list itself is what says whether the level started clean.
const TIME_LIST_PROPS: Array = ["times_to_answer", "_times_to_answer", "_reaction_times", "_accuracies"]

func _times_lists() -> Array:
	var out: Array = []
	for prop: String in TIME_LIST_PROPS:
		var lst = _level.get(prop)
		if lst is Array:
			out.append([prop, lst])
	return out

func _feed_times() -> void:
	for entry: Array in _times_lists():
		for _i in 5:
			(entry[1] as Array).append(1000)

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

# gorilla does not have a level-done ENTRY POINT to call: a level is `rounds_per_level` buildings,
# and the gate is judged when the last of them is answered. So the rounds are played out through
# the answer buttons' own handler, exactly as the app reaches it.
const GORILLA_LEVEL: int = 2

func _run_gorilla() -> void:
	_cur = "gorilla"
	_main = load("res://gorilla/scenes/main.tscn").instantiate()
	add_child(_main)
	for _i in 8:
		await get_tree().process_frame
	_game = _main.get("game")
	_level = _main.get_node_or_null("Level")
	if _game == null or _level == null:
		_fail("could not reach the game")
		return
	var before: Dictionary = _snap()
	var rounds: int = int(GorillaLevelConfig.LEVELS[GORILLA_LEVEL - 1]["rounds"])
	var need: int = GorillaLevelConfig.pass_pct_for(GORILLA_LEVEL)
	# 2 of 3 is 66% against a bar of 60; 1 of 3 is 33%.
	await _gorilla_case(rounds, need, [true, true, false], true)
	await _gorilla_case(rounds, need, [false, false, true], false)
	print("  gorilla: %d rounds per level, bar %d%%" % [rounds, need])
	var after: Dictionary = _snap()
	for p: String in before:
		if before[p] != after[p]:
			_fail("wrote to %s" % p.get_file())
	_main.queue_free()
	_main = null
	for _i in 4:
		await get_tree().process_frame

func _gorilla_case(rounds: int, need: int, verdicts: Array, want_pass: bool) -> void:
	var what: String = "pass" if want_pass else "fail"
	_game.tutorial_mode = false
	_level.set("level", GORILLA_LEVEL)
	_game.need_to_increase_level = false
	_level.set("_level_is_over", true)   # make the next new_game() a LEVEL start
	await _level.new_game(false)
	for _i in 4:
		await get_tree().process_frame
	if int(_level.get("round_in_level")) != 0:
		_fail("%s: the level did not start on round 0" % what)
	if int(_game.corrects) != 0 or int(_game.mistakes) != 0:
		_fail("%s: the level did not start with the round tally cleared (%d/%d)" % [what, _game.corrects, _game.mistakes])
	_game.score = SCORE_AT_START
	_level.set("_score_at_level_start", SCORE_AT_START)

	for i in verdicts.size():
		if i > 0:
			await _level.new_game(false)
			for _i in 4:
				await get_tree().process_frame
		if int(_level.get("level")) != GORILLA_LEVEL:
			_fail("%s: left level %d mid-level, on round %d" % [what, GORILLA_LEVEL, i])
			return
		_game.score = SCORE_AT_START + EARNED_IN_LEVEL * (i + 1)
		# A right answer is chosen == true_count; a wrong one is off by two.
		_level.call("_on_answer_selected", 7 if bool(verdicts[i]) else 5, 7)
		for _i in 3:
			await get_tree().process_frame
		var last: bool = i == verdicts.size() - 1
		if int(_level.get("round_in_level")) != (0 if last and rounds == verdicts.size() else i + 1) and not last:
			_fail("%s: round %d did not count toward the level" % [what, i + 1])

	if int(_level.get("round_in_level")) != rounds:
		_fail("%s: %d rounds were played but the level counted %d" % [what, verdicts.size(), _level.get("round_in_level")])
	if bool(_game.need_to_increase_level) != want_pass:
		_fail("%s: the gate set need_to_increase_level=%s" % [what, str(_game.need_to_increase_level)])
	_check_card(what, want_pass, need)

	var kept: int = SCORE_AT_START if not want_pass else int(_game.score)
	_level.set("_level_is_over", true)
	await _level.new_game(false)
	for _i in 4:
		await get_tree().process_frame
	var want_level: int = GORILLA_LEVEL + 1 if want_pass else GORILLA_LEVEL
	if int(_level.get("level")) != want_level:
		_fail("%s: Continue landed on level %d, expected %d" % [what, _level.get("level"), want_level])
	if int(_game.score) != kept:
		_fail("%s: after Continue the score is %d, expected %d" % [what, _game.score, kept])

# wolves is gated on the FLOCK, not on answers: the level lasts a fixed time and what decides it is
# how many sheep are still inside when the clock runs out. The probe builds a real board, marks
# some of the flock as lost, and ends the level.
const WOLVES_LEVEL: int = 2

func _run_wolves() -> void:
	_cur = "wolves"
	_main = load("res://wolves/scenes/main.tscn").instantiate()
	add_child(_main)
	for _i in 8:
		await get_tree().process_frame
	_game = _main.get("game")
	_level = _main.get_node_or_null("Level")
	if _game == null or _level == null:
		_fail("could not reach the game")
		return
	var before: Dictionary = _snap()
	var need: int = WolvesLevelConfig.pass_pct_for(WOLVES_LEVEL)
	await _wolves_case(need, 0.9, true)
	await _wolves_case(need, 0.2, false)
	var after: Dictionary = _snap()
	for p: String in before:
		if before[p] != after[p]:
			_fail("wrote to %s" % p.get_file())
	_main.queue_free()
	_main = null
	for _i in 4:
		await get_tree().process_frame

func _wolves_case(need: int, keep_share: float, want_pass: bool) -> void:
	var what: String = "pass" if want_pass else "fail"
	_game.tutorial_mode = false
	_level.set("level", WOLVES_LEVEL)
	_game.need_to_increase_level = false
	await _level.new_game(false)
	for _i in 4:
		await get_tree().process_frame
	if int(_level.get("level")) != WOLVES_LEVEL:
		_fail("%s: the level moved to %d before it started" % [what, _level.get("level")])
		return
	var total: int = int(_level.get("_sheep_at_level_start"))
	if total < 4:
		_fail("%s: the board came up with %d sheep, too few to measure a share against" % [what, total])
		return
	_game.score = SCORE_AT_START
	_level.set("_score_at_level_start", SCORE_AT_START)
	_game.score = SCORE_AT_START + EARNED_IN_LEVEL

	# Lose enough of the flock to land either side of the bar.
	var keep: int = int(floor(float(total) * keep_share))
	var lost: int = 0
	for a in _level.get("agents"):
		if lost >= total - keep:
			break
		if is_instance_valid(a) and a.agent_type == 0 and not a.was_removed:
			a.was_removed = true
			lost += 1
	var saved: int = int(_level.call("get_num_sheep_left"))
	var pct: int = int(round(100.0 * float(saved) / float(total)))
	if (pct >= need) != want_pass:
		_fail("%s: kept %d of %d (%d%%) against a bar of %d%% — test is wrong, not the game" % [what, saved, total, pct, need])
		return

	_game.level_is_done = false
	_level.call("level_is_done", true)
	for _i in 6:
		await get_tree().process_frame
	if bool(_game.need_to_increase_level) != want_pass:
		_fail("%s: %d%% of the flock against a bar of %d%% set need_to_increase_level=%s" % [what, pct, need, str(_game.need_to_increase_level)])
	var card_body: String = _wolves_card(what, want_pass)
	if not card_body.contains("Sheep saved"):
		_fail("%s: the card never says how much of the flock came through" % what)
	if not want_pass and not card_body.contains("at least %d%%" % need):
		_fail("%s: the card never states the bar of %d%%" % [what, need])

	# Continue: the level that comes back, and the score it comes back with.
	_game.need_to_increase_level = bool(_game.need_to_increase_level)
	await _level.new_game(false)
	for _i in 4:
		await get_tree().process_frame
	var want_level: int = WOLVES_LEVEL + 1 if want_pass else WOLVES_LEVEL
	if int(_level.get("level")) != want_level:
		_fail("%s: Continue landed on level %d, expected %d" % [what, _level.get("level"), want_level])
	var kept_score: int = SCORE_AT_START if not want_pass else SCORE_AT_START + EARNED_IN_LEVEL + 50
	if int(_game.score) != kept_score:
		_fail("%s: after Continue the score is %d, expected %d" % [what, _game.score, kept_score])

func _wolves_card(what: String, want_pass: bool) -> String:
	var card: Node = null
	for c in _all_nodes(_level):
		if c.has_method("set_passed") and c.has_method("set_title"):
			card = c
	if card == null:
		if want_pass:
			_fail("%s: no level card appeared" % what)
		return ""
	if bool(card.get("_passed")) != want_pass:
		_fail("%s: the card was built as passed=%s" % [what, str(card.get("_passed"))])
	var body: String = ""
	for n in _all_nodes(card):
		if n is Label or n is RichTextLabel:
			body += String(n.get("text")) + "\n"
	MainGlobals.set_visible("level_done", false)
	card.free()
	return body

# monkeyc has no `level` counter: the levels come off a QUEUE, and failing means the same id is
# handed out again next. So what the probe checks after a failed level is which id the queue gives
# back, not a number on the level node.
const MONKEYC_LEVEL: int = 2

func _run_monkeyc() -> void:
	_cur = "monkeyc"
	_main = load("res://monkeyc/scenes/main.tscn").instantiate()
	add_child(_main)
	for _i in 8:
		await get_tree().process_frame
	_game = _main.get("game")
	_level = _main.get_node_or_null("Level")
	if _game == null or _level == null:
		_fail("could not reach the game")
		return
	var before: Dictionary = _snap()
	for c: Dictionary in _game.sig_level_is_done.get_connections():
		var cb: Callable = c["callable"]
		if cb.get_object() == _main:
			_game.sig_level_is_done.disconnect(cb)
	_game.sig_level_is_done.connect(_on_save_moment)
	var need: int = MonkeyCG.pass_pct_for(MONKEYC_LEVEL)
	var rounds: int = int(MonkeyCLevelConfig.get_level(MONKEYC_LEVEL)["rounds"])
	await _monkeyc_case(need, rounds, rounds, true)
	await _monkeyc_case(need, rounds, 1, false)
	var after: Dictionary = _snap()
	for p: String in before:
		if before[p] != after[p]:
			_fail("wrote to %s" % p.get_file())
	_main.queue_free()
	_main = null
	for _i in 4:
		await get_tree().process_frame

func _monkeyc_case(need: int, rounds: int, corrects: int, want_pass: bool) -> void:
	var what: String = "pass" if want_pass else "fail"
	_game.tutorial_mode = false
	MonkeyCG.reset_queue_from(MONKEYC_LEVEL)
	_game.score = SCORE_AT_START
	await _level.new_game(false)
	for _i in 4:
		await get_tree().process_frame
	if int(_level.get("current_level_id")) != MONKEYC_LEVEL:
		_fail("%s: the queue handed out level %d, expected %d" % [what, _level.get("current_level_id"), MONKEYC_LEVEL])
		return
	if int(_level.get("total_rounds")) != 0 or int(_game.corrects) != 0:
		_fail("%s: the level did not start with its counters cleared (%d rounds, %d correct)" % [what, _level.get("total_rounds"), _game.corrects])

	_game.score = SCORE_AT_START + EARNED_IN_LEVEL
	_level.set("total_rounds", rounds)
	_level.set("total_corrects", corrects)
	var pct: int = int(_level.call("pct_correct"))
	if (pct >= need) != want_pass:
		_fail("%s: %d of %d is %d%% against a bar of %d%% — test is wrong, not the game" % [what, corrects, rounds, pct, need])
		return

	_score_when_saved = -1
	_saves_seen = 0
	_level.call("_level_done")
	for _i in 6:
		await get_tree().process_frame

	var kept: int = SCORE_AT_START if not want_pass else SCORE_AT_START + EARNED_IN_LEVEL
	if _saves_seen == 0:
		_fail("%s: the level end never reached the save handler" % what)
	elif _score_when_saved != kept:
		_fail("%s: the score row was written with %d, expected %d" % [what, _score_when_saved, kept])
	if int(_game.score) != SCORE_AT_START + EARNED_IN_LEVEL:
		_fail("%s: the score on screen changed while the summary is still up" % what)
	_check_card(what, want_pass, need)

	# Continue: which level the queue gives back, and what the score comes back as.
	await _level.new_game(false)
	for _i in 4:
		await get_tree().process_frame
	var got: int = int(_level.get("current_level_id"))
	if want_pass and got == MONKEYC_LEVEL:
		_fail("pass: the queue handed out level %d again after it was passed" % got)
	if not want_pass and got != MONKEYC_LEVEL:
		_fail("fail: the queue moved on to level %d instead of replaying %d" % [got, MONKEYC_LEVEL])
	if int(_game.score) != kept:
		_fail("%s: after Continue the score is %d, expected %d" % [what, _game.score, kept])

# The two games whose level is a run of ROUNDS and whose gate is the share of them won. There is no
# level-done entry point to call: the rounds are played out one verdict at a time, exactly as the
# app reaches level_is_done(), and the level ends itself on the last one.
const ROUND_GAMES: Array = [
	{"folder": "lightsout", "config": "LightsoutLevelConfig", "level": 2},
	{"folder": "mmm", "config": "MmmLevelConfig", "level": 2},
]

func _run_rounds_game(spec: Dictionary) -> void:
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
	var script: Script = load("res://%s/scripts/level_config.gd" % _cur)
	var lvl: int = int(spec["level"])
	var need: int = script.pass_pct_for(lvl)
	var rounds: int = 0
	for row: Dictionary in script.LEVELS:
		if int(row["level"]) == lvl:
			rounds = int(row["rounds"])
	if rounds < 3:
		_fail("level %d is only %d rounds, too few for a share to mean anything" % [lvl, rounds])
		return
	# 2 of 3 is 66% against a bar of 60; 1 of 3 is 33%.
	await _rounds_case(lvl, rounds, need, [true, true, false], true)
	await _rounds_case(lvl, rounds, need, [false, false, true], false)
	print("  %s: %d rounds per level, bar %d%%" % [_cur, rounds, need])
	var after: Dictionary = _snap()
	for p: String in before:
		if before[p] != after[p]:
			_fail("wrote to %s" % p.get_file())
	_main.queue_free()
	_main = null
	for _i in 4:
		await get_tree().process_frame

func _rounds_case(lvl: int, rounds: int, need: int, verdicts: Array, want_pass: bool) -> void:
	var what: String = "pass" if want_pass else "fail"
	_game.tutorial_mode = false
	if _level.get("_tutorial_board") != null:
		_level.set("_tutorial_board", false)
	_level.set("level", lvl)
	_game.need_to_increase_level = false
	_level.set("_level_is_over", true)   # make the next new_game() a LEVEL start
	_level.new_game(false)
	for _i in 6:
		await get_tree().process_frame
	if int(_level.get("round_in_level")) != 0:
		_fail("%s: the level did not start on round 0" % what)
	# mmm keeps its round tally in its own counters, because game.corrects / game.mistakes there
	# already count ROOM answers and the HUD shows them.
	if _level.get("_rounds_played") != null:
		if int(_level.get("_rounds_played")) != 0 or int(_level.get("_rounds_fully_correct")) != 0:
			_fail("%s: the level did not start with the round tally cleared (%d/%d)" % [what, _level.get("_rounds_fully_correct"), _level.get("_rounds_played")])
	elif int(_game.corrects) != 0 or int(_game.mistakes) != 0:
		_fail("%s: the level did not start with the round tally cleared (%d/%d)" % [what, _game.corrects, _game.mistakes])
	_game.score = SCORE_AT_START
	_level.set("_score_at_level_start", SCORE_AT_START)

	for i in verdicts.size():
		if i > 0:
			_level.new_game(false)
			for _i in 6:
				await get_tree().process_frame
		if int(_level.get("level")) != lvl:
			_fail("%s: left level %d mid-level, on round %d" % [what, lvl, i])
			return
		_game.score = SCORE_AT_START + EARNED_IN_LEVEL * (i + 1)
		_game.level_is_done = false
		_level.call("level_is_done", bool(verdicts[i]))
		for _i in 4:
			await get_tree().process_frame

	if int(_level.get("round_in_level")) != rounds:
		_fail("%s: %d rounds were played but the level counted %d" % [what, verdicts.size(), _level.get("round_in_level")])
	if bool(_game.need_to_increase_level) != want_pass:
		_fail("%s: the gate set need_to_increase_level=%s" % [what, str(_game.need_to_increase_level)])
	_check_card(what, want_pass, need)

	var kept: int = SCORE_AT_START if not want_pass else int(_game.score)
	_level.new_game(false)
	for _i in 6:
		await get_tree().process_frame
	var want_level: int = lvl + 1 if want_pass else lvl
	if int(_level.get("level")) != want_level:
		_fail("%s: Continue landed on level %d, expected %d" % [what, _level.get("level"), want_level])
	if int(_game.score) != kept:
		_fail("%s: after Continue the score is %d, expected %d" % [what, _game.score, kept])
