extends Node

# TEMPORARY PROBE — delete after use. All 8 tutorials.

const GAMES: Array = ["deliverem"]

var _fails: Array = []
var _game: GenericGameUtil = null
var _main: Node = null
var _level: Node = null
var _cur: String = ""
var _checked_freeze: bool = false
var _held: int = 0
var _claims_seen: int = 0
var _acted: bool = false
var _steps_seen: Array = []
var _watch = null

func _process(_dt: float) -> void:
	if _watch == null or not is_instance_valid(_watch) or _watch._finished:
		return
	var n: int = _watch._idx + 1
	if _steps_seen.is_empty() or int(_steps_seen[-1]) != n:
		_steps_seen.append(n)

# Events that represent something the PLAYER does. A step waiting on one of these must not be
# satisfiable by the game alone — gorilla's "collect a coin" step was, because the player walks by
# itself (GorillaG.always_moving), so the coach congratulated you for doing nothing.
const PLAYER_EVENTS: Array = ["answered", "answered_without_buttons", "coin_in_tray", "coin_out_of_tray", "coin_moved", "paid", "paid_correct",
	"taxi_selected", "customer_assigned", "sent_to_gas",
	"coin_taken", "room_entered", "room_answered", "player_moved", "answered_right", "judged",
	"promoted", "evicted", "player_steered", "path_drawn", "scared_one", "tool_placed",
	"door_turned", "reached_top", "reached_bottom", "coin_taken"]

func _fail(m: String) -> void:
	_fails.append("[%s] %s" % [_cur, m])

func _ready() -> void:
	MainGlobals.init_globals(Vector2(680, 788))
	# The probe instantiates each game standalone, without the app root — so the bottom action bar
	# does not exist and MainGlobals.add_action_button() silently returns null. A tutorial that
	# points at an action button (taxi's "this buys another taxi") then has nothing to spotlight,
	# which is an artifact of the harness, not the tutorial. Register a real one, as Main does.
	var bar: Node = load("res://scenes/action_buttons.tscn").instantiate()
	add_child(bar)
	# Same story for the app's bottom bar: delemfp's tutorial asks the player to press Clue and
	# Zoom, which live there. Without it those steps have nothing to point at — a harness gap, not
	# a tutorial one.
	var bottom: Node = load("res://scenes/bottom_option_buttons.tscn").instantiate()
	add_child(bottom)
	MainGlobals.sig_update_bottom_bar.connect(
		func(b, c, r): bottom.set_buttons(b, c, r))
	await get_tree().process_frame
	for g: String in GAMES:
		await _run_game(g)
	for _i in 120:
		await get_tree().process_frame
	if _fails.is_empty():
		print("PROBE OK (%d games)" % GAMES.size())
	else:
		for f: String in _fails:
			print("PROBE FAIL ", f)
	get_tree().quit()

func _run_game(folder: String) -> void:
	_cur = folder
	_lo_last_cell = Vector2i(-999, -999)
	_dlv_checked_still = false
	_checked_freeze = false
	_held = 0
	_claims_seen = 0
	MainGlobals.pending_tutorial = folder
	_main = load("res://%s/scenes/main.tscn" % folder).instantiate()
	add_child(_main)
	_game = _main.get("game")
	if _game == null:
		_fail("could not reach the game util")
		return
	var before: Dictionary = _snap()
	var runs0: int = _game.times_run
	for _i in 8:
		await get_tree().process_frame
	var r = null
	for c in _main.get_children():
		if c is TutorialRunner:
			r = c
	if r == null:
		_fail("tutorial never started")
		_main.queue_free()
		return
	_level = _main.get_node("Level")
	if not _game.tutorial_mode:
		_fail("not in tutorial_mode while running")
	if folder == "aliens":
		_check_alien_helpers()
	_check_talking_steps(r)
	if folder == "change":
		_check_change_boards()
		_check_pay_is_exact()
	var total: int = r._steps.size()
	_steps_seen = []
	_watch = r
	await _drive(r)
	if folder == "couples" and _claims_seen < 1:
		_fail("the 'tap its twin' step was never reached, so its spotlight went unchecked")
	if folder == "delemfp" and _claims_seen < 1:
		_fail("no steering instruction was ever checked; the tutorial should give one")
	if folder == "monkeyc" and _claims_seen < 2:
		_fail("only %d verdict claims checked; expected the ✓ and the ✗ captions" % _claims_seen)
	if folder == "aliens" and _claims_seen < 2:
		_fail("only %d match-claims checked; expected the two drag steps" % _claims_seen)
	if _steps_seen.size() != total or (not _steps_seen.is_empty() and int(_steps_seen[-1]) != total):
		_fail("not every step reached the screen: showed %s of %d" % [str(_steps_seen), total])
	if not _checked_freeze:
		_fail("never got to check the freeze")
	if _game.tutorial_mode:
		_fail("still in tutorial_mode at the end")
	if _game.times_run != runs0:
		_fail("times_run moved")
	if MainGlobals.is_screen_visible("tutorial"):
		_fail("LEFT FROZEN")
	# Nothing of the game's own may land once the coach has gone: a round-complete panel, a level
	# popup, a results screen. Several of these are scheduled on a delay, so they arrive AFTER the
	# tutorial has ended and after tutorial_mode has gone false — which is precisely how mmm's
	# "Round 1 of Level 1 completed" kept reaching the player.
	for _i in 150:
		await get_tree().process_frame
	for n in _all_nodes(_main):
		if n.has_method("set_title") and n.has_method("set_text") and n.get("visible") == true:
			var _sc = n.get_script()
			_fail("a panel appeared after the tutorial ended: %s (%s) script=%s" % [n.name,
				n.get_class(), str(_sc.resource_path) if _sc != null else "-"])
			break
	var after: Dictionary = _snap()
	for p: String in before:
		if before[p] != after[p]:
			_fail("wrote to %s" % p.get_file())
	print("  %s: %d steps, %d spotlights held" % [folder, total, _held])
	_main.queue_free()
	for _i in 4:
		await get_tree().process_frame

# Direct test of the guard: given a deliberately WRONG "preferred" alien (a roamer, which is what a
# stale _tutorial_last_parked amounts to), the helper must never hand it back.
func _check_alien_helpers() -> void:
	var roamer = null
	for al in _level._aliens:
		if is_instance_valid(al) and al.state == _level.AState.ROAM:
			roamer = al
			break
	if roamer == null:
		return
	for want in [true, false]:
		var got = _level.tutorial_parked_alien(want, roamer)
		if got == roamer:
			_fail("tutorial_parked_alien handed back a ROAMING alien — the drag would be refused")
		if got != null and got.state != _level.AState.PARKED_OUTER:
			_fail("tutorial_parked_alien returned an alien that is not parked")
		if got != null and _level._gate_wants(got, got.area_idx) != want:
			_fail("tutorial_parked_alien returned an alien on the wrong side of the pass")

# The tutorial names exact amounts ("pay 60 cents") and tells the player coins are hidden. Both
# are claims about the board it hands them, so both are checked against the board itself.
# A talking step freezes the board and eats the next press. If its text tells the player to do
# something, they cannot do it, and the press that begins their attempt dismisses the step instead
# — so obeying the instruction is what skips it. Steps with a demo_path are exempt: those are
# showing a gesture, not asking for one.
const ASK_VERBS: Array = ["drag", "tap", "press", "swipe", "draw", "trace", "walk", "put", "pay"]

func _check_talking_steps(r) -> void:
	for i in r._steps.size():
		if i == 0:
			continue
		var step: Dictionary = r._steps[i]
		if step.has("await") or step.has("demo_path"):
			continue
		var txt = step.get("text", "")
		if txt is Callable:
			txt = (txt as Callable).call()
		# Split on clause boundaries, not just sentence ends: the instruction that started all this
		# ("...more coins here than you can see — drag the top ones aside") hangs off an em-dash,
		# and a first-word-of-sentence test sailed straight past it.
		var flat: String = String(txt).replace(".", "\n").replace("!", "\n") \
			.replace("\u2014", "\n").replace(";", "\n").replace(", and ", "\n")
		for raw in flat.split("\n"):
			var line: String = String(raw).strip_edges().to_lower()
			if line.is_empty():
				continue
			var first: String = line.split(" ")[0]
			if ASK_VERBS.has(first):
				_fail("step %d is a talking step but its text starts an instruction with '%s' — the board is frozen, so the player cannot obey it and their attempt dismisses the step" % [i + 1, first])

func _check_change_boards() -> void:
	var tut: Script = load("res://change/scripts/tutorial.gd")
	for spec in tut.tutorial_boards():
		var values: Array = spec["values"]
		var target: float = float(spec["target"])
		if not _subset_sums_to(values, target):
			_fail("board %s cannot make its stated target of %.2f" % [str(values), target])

func _subset_sums_to(values: Array, target: float) -> bool:
	var cents: Array = []
	for v in values:
		cents.append(int(round(float(v) * 100.0)))
	var want: int = int(round(target * 100.0))
	var reachable: Dictionary = {0: true}
	for c in cents:
		for have in reachable.keys().duplicate():
			reachable[int(have) + int(c)] = true
	return reachable.has(want)

# "There are more coins here than you can see" — only true if the pile actually buries some.
func _check_pile_is_buried() -> void:
	var buried: int = 0
	for i in _level._coins.size():
		var a = _level._coins[i]
		for j in _level._coins.size():
			if i == j:
				continue
			var b = _level._coins[j]
			if not is_instance_valid(a["node"]) or not is_instance_valid(b["node"]):
				continue
			# b sits on top of a and covers most of it
			if b["node"].z_index <= a["node"].z_index:
				continue
			var d: float = a["node"].position.distance_to(b["node"].position)
			if d < float(a["radius"]) * 0.6:
				buried += 1
				break
	if buried < 1:
		_fail("the 'look underneath' pile buries no coins — the caption's claim is false")

func _drive(r) -> void:
	var guard: int = 0
	var prev_idx: int = -1
	var elapsed: float = 0.0
	while is_instance_valid(r) and guard < 9000:
		guard += 1
		await get_tree().process_frame
		if not is_instance_valid(r):
			break
		if r._idx != prev_idx:
			if prev_idx >= 0 and prev_idx < r._steps.size():
				_check_timeout(r._steps[prev_idx], prev_idx, elapsed)
				_check_player_did_it(r._steps[prev_idx], prev_idx)
			prev_idx = r._idx
			_acted = false
			_check_caption(r)
			_check_keep_clear(r)
			_check_claims(r)
			if _cur == "change" and r._text_label.text.contains("more coins here than you can see"):
				_check_pile_is_buried()
			if _cur == "udbr":
				_check_lane_clear(r)
			if _cur == "monkeyc":
				_check_monkeyc_claim(r)
			if _cur == "delemfp":
				_check_delemfp_steerable(r)
			if _cur == "couples":
				_check_couples_twin(r)
			# Give the step a frame on screen before acting on it.
			elapsed = r._step_elapsed
			continue
		elapsed = r._step_elapsed
		if r._finished:
			break
		if _cur == "deliverem" and r._await_event == "door_turned" and not _dlv_checked_still:
			_dlv_checked_still = true
			await _check_deliverem_door_step(r)
			if not is_instance_valid(r):
				break
		if r._blocking:
			if not _checked_freeze and _can_check_freeze():
				_checked_freeze = true
				await _assert_frozen()
			await _hold_spotlight(r)
			if not is_instance_valid(r):
				break
			_tap(Vector2(MainGlobals.screen_size) * 0.5)
			await get_tree().process_frame
			await get_tree().process_frame
			continue
		_act(r._await_event)
	if guard >= 9000:
		_fail("did not terminate (stuck on step %d, awaiting '%s')" % [r._idx + 1, r._await_event])
# Both halves of one finger tap: the touch, and the mouse button the Input layer synthesizes from
# it (emulate_mouse_from_touch / emulate_touch_from_mouse). Dismissing captions by calling
# _advance() directly is what hid the double-advance that cost gorilla and wolves their last step.
func _tap(at: Vector2) -> void:
	var td: InputEventScreenTouch = InputEventScreenTouch.new()
	td.index = 0
	td.pressed = true
	td.position = at
	get_viewport().push_input(td, true)
	var md: InputEventMouseButton = InputEventMouseButton.new()
	md.button_index = MOUSE_BUTTON_LEFT
	md.pressed = true
	md.position = at
	md.global_position = at
	get_viewport().push_input(md, true)
	var tu: InputEventScreenTouch = InputEventScreenTouch.new()
	tu.index = 0
	tu.pressed = false
	tu.position = at
	get_viewport().push_input(tu, true)
	var mu: InputEventMouseButton = InputEventMouseButton.new()
	mu.button_index = MOUSE_BUTTON_LEFT
	mu.pressed = false
	mu.position = at
	mu.global_position = at
	get_viewport().push_input(mu, true)

func _hold_spotlight(r) -> void:
	if not r._has_spot or not r._steps[r._idx].has("spot"):
		return
	_held += 1
	var idx: int = r._idx
	var before: Rect2 = r._spot_rect
	for _i in 30:
		await get_tree().process_frame
		if not is_instance_valid(r) or r._idx != idx:
			return
	if not r._has_spot:
		_fail("step %d: the spotlight target VANISHED while the caption was up" % (idx + 1))
		return
	var moved: float = r._spot_rect.get_center().distance_to(before.get_center())
	if moved > 8.0:
		_fail("step %d: the spotlight moved %.0f px while the caption was up" % [idx + 1, moved])
	# Bound by the OVERLAY, not by MainGlobals.screen_size. screen_size is the play area and stops
	# above the app's bottom bar, but the bar is on screen and its buttons are tappable — taxi
	# points at the buy-a-taxi button down there, and udbr/delemfp point at bar buttons too.
	var lit: Vector2 = r._dim.size
	var c: Vector2 = r._spot_rect.get_center()
	if c.x < 0.0 or c.y < 0.0 or c.x > lit.x or c.y > lit.y:
		_fail("step %d: the spotlight is OFF SCREEN at %s (overlay is %s)" % [idx + 1, str(c), str(lit)])

# A caption that covers the control the step tells you to use makes the step impossible. Only
# player-action steps matter: on a talking step the board is frozen and nothing is reachable.
func _check_keep_clear(r) -> void:
	if r.keep_clear.is_empty():
		return
	var panel: Rect2 = Rect2(r._panel.position, r._panel.size)
	for entry in r.keep_clear:
		var target = entry
		if target is Callable:
			if not (target as Callable).is_valid():
				continue
			target = (target as Callable).call()
		if target == null:
			continue
		var zone: Rect2 = r._rect_for(target, r.DEFAULT_SPOT_RADIUS)
		if zone.size.x <= 0.0 or zone.size.y <= 0.0:
			continue
		var ov: Rect2 = panel.intersection(zone)
		if ov.size.x > 0.0 and ov.size.y > 0.0:
			# A keep-clear zone is a PREFERENCE, weighed against the spotlight (which wins). Fail
			# only when the caption has effectively buried one — a clipped corner is often the best
			# placement geometry allows.
			var frac: float = ov.get_area() / maxf(zone.get_area(), 1.0)
			if frac > 0.5:
				_fail("step %d: the caption buries %.0f%% of a keep-clear zone"
					% [r._idx + 1, frac * 100.0])

func _check_claims(r) -> void:
	if _cur != "aliens":
		return
	var txt: String = r._text_label.text
	var claims_no_match: bool = txt.contains("does not match")
	var claims_match: bool = txt.contains("matches") and not claims_no_match
	if not claims_match and not claims_no_match:
		return
	_claims_seen += 1
	if not _level.tutorial_hold_arrivals:
		_fail("step %d names one alien but arrivals are not held" % (r._idx + 1))
	if not _level._areas.is_empty() and bool(_level._areas[0].get("deny", false)):
		_fail("a NOT pass is in play — plain 'matches' wording is not safe")
	# The alien actually being POINTED AT, found from the spotlight rather than from
	# _tutorial_last_parked — the bug was precisely that those two came apart.
	if not r._has_spot:
		_fail("step %d claims something about an alien but marks nothing" % (r._idx + 1))
		return
	var c: Vector2 = r._spot_rect.get_center()
	var marked = null
	var best: float = 1e18
	for al in _level._aliens:
		if not is_instance_valid(al):
			continue
		var d: float = al.sim_pos.distance_to(c)
		if d < best:
			best = d
			marked = al
	if marked == null or best > 40.0:
		_fail("step %d marks a spot with no alien at it" % (r._idx + 1))
		return
	if marked.state != _level.AState.PARKED_OUTER:
		_fail("step %d marks an alien NOT parked in the ring (state %d) — the drag cannot work"
			% [r._idx + 1, marked.state])
	var wanted: bool = _level._gate_wants(marked, marked.area_idx)
	if claims_match and not wanted:
		_fail("step %d says the MARKED alien matches, but the gate does not want it" % (r._idx + 1))
	if claims_no_match and wanted:
		_fail("step %d says the MARKED alien does not match, but the gate wants it" % (r._idx + 1))

func _act(e: String) -> void:
	match _cur:
		"dino": _act_dino(e)
		"change": _act_change(e)
		"aliens": _act_aliens(e)
		"gorilla": _act_gorilla(e)
		"wolves": _act_wolves(e)
		"storm": _act_storm(e)
		"guidem": _act_guidem(e)
		"udbr": _act_udbr(e)
		"taxi": _act_taxi(e)
		"mmm": _act_mmm(e)
		"didi": _act_didi(e)
		"sortingrobots": _act_sortingrobots(e)
		"ptbits": _act_ptbits(e)
		"delemfp": _act_delemfp(e)
		"monkeyc": _act_monkeyc(e)
		"dinoback": _act_dinoback(e)
		"couples": _act_couples(e)
		"deliverem": _act_deliverem(e)
		"lightsout": _act_lightsout(e)

# picked_up is deliberately NOT a player event: the taxi drives itself once sent.
# Walk the player to whatever the step is waiting for. The game moves one tile per major tick, so
# the probe just sets a direction and lets tick() carry it, the same as a swipe would.
# The only thing a didi player does is tap one shape: the one that matches the centre AND sits in
# the direction the dot flashed. That is the agent the level marked is_correct.
# Lights Out is a navigation game: the probe walks, one direction per major tick, routing over the
# same board the game uses. move_dir() is what a swipe or an arrow key produces.
var _lo_last_cell: Vector2i = Vector2i(-999, -999)

func _act_lightsout(e: String) -> void:
	if e != "delivered":
		return
	var lvl = _level
	if lvl.player == null or not is_instance_valid(lvl.player):
		return
	var goal = lvl.tutorial_goal_target()
	if goal == null:
		return
	# Stand NEXT to the target: targets are not enterable (can_go_to rejects istarget). Take the
	# first neighbour there is actually a ROUTE to, not merely the first walkable one — a walkable
	# tile can still be cut off, and then the probe just spins.
	var want: Vector2i = Vector2i(-1, -1)
	for d in 4:
		var n: Vector2i = goal.board_pos + Vector2i(lvl.DirArray[d])
		if not lvl.can_go_to(n):
			continue
		if n == lvl.player.board_pos or _lo_route(lvl, lvl.player.board_pos, n) >= 0:
			want = n
			break
	if want.x < 0:
		return
	# Act once per TILE, not once per frame: move_dir() sets next_player_dir, and rewriting it
	# every frame races the tick that consumes it — the same mistake that made mmm look stuck.
	if lvl.player.board_pos == _lo_last_cell and not lvl.player.reached_target_pos:
		return
	_lo_last_cell = lvl.player.board_pos
	var dir: int = _lo_route(lvl, lvl.player.board_pos, want)
	if dir < 0:
		return
	_acted = true
	lvl.move_dir(dir)

func _lo_route(lvl, from: Vector2i, to: Vector2i) -> int:
	if from == to:
		return -1
	var prev: Dictionary = {from: from}
	var q: Array = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == to:
			break
		for d in 4:
			var n: Vector2i = c + Vector2i(lvl.DirArray[d])
			if prev.has(n) or not lvl.can_go_to(n):
				continue
			prev[n] = c
			q.append(n)
	if not prev.has(to):
		return -1
	var cur: Vector2i = to
	while prev[cur] != from:
		cur = prev[cur]
		if cur == from:
			return -1
	for d in 4:
		if Vector2i(lvl.DirArray[d]) == cur - from:
			return d
	return -1

# Deliverem's player never steers — they turn DOORS, and the truck drives itself through them.
# The probe therefore does what a player does: work out which way the truck must leave the tile it
# is heading into, and set the door there to the rotation that deflects it that way. It taps the
# real door Area2D, so a tutorial pointing at the wrong door fails here.
func _dlv_door_at(bp: Vector2i):
	for d in _level.doors:
		if is_instance_valid(d) and d.board_pos == bp:
			return d
	return null

# Route the truck to `to`, and set the next door it meets so it turns the right way.
var _dlv_checked_still: bool = false

# "Tap this door" is an ACTION step, so the game is unpaused — but nothing about it should be
# moving. The truck must be held, and the framed door must stay where it was put: the target is
# otherwise derived from the truck's heading, so every tile it drives re-picks a door and the frame
# hops around the yard while the player is trying to hit it.
func _check_deliverem_door_step(r) -> void:
	var spot0: Rect2 = r._spot_rect
	var a = _level.tutorial_agent()
	var cell0 = a.board_pos if a != null else null
	var pos0: Vector2 = a.position if a != null else Vector2.ZERO
	var idx: int = r._idx
	for _i in 90:
		await get_tree().process_frame
		if not is_instance_valid(r) or r._idx != idx:
			return
	if not r._has_spot:
		_fail("the door step lost its spotlight while the player was looking for the door")
		return
	var moved: float = r._spot_rect.get_center().distance_to(spot0.get_center())
	if moved > 4.0:
		_fail("the door step's frame moved %.0f px while the player was aiming at it" % moved)
	var a2 = _level.tutorial_agent()
	if a2 != null and cell0 != null:
		if a2.board_pos != cell0:
			_fail("the truck drove on (%s -> %s) during the door step" % [str(cell0), str(a2.board_pos)])
		elif a2.position.distance_to(pos0) > 2.0:
			_fail("the truck slid %.0f px during the door step" % a2.position.distance_to(pos0))

func _act_deliverem(e: String) -> void:
	var a = _level.tutorial_agent()
	if a == null:
		return
	match e:
		"door_turned":
			var dn = _dlv_door_at(_dlv_next_door_cell(a))
			if dn == null:
				return
			_acted = true
			_level.on_clicked_door(dn.board_pos)
		"packet_delivered":
			var lobby: Vector2i = _dlv_next_lobby()
			if lobby.x < 0:
				return
			var cell: Vector2i = _dlv_next_door_cell(a)
			var dn2 = _dlv_door_at(cell)
			if dn2 == null:
				return
			# Route from the DOOR's cell, not the truck's: the door is several tiles ahead, and the
			# direction that is right at the truck is often wrong by the time it gets there.
			var want: int = _dlv_route_dir(cell, lobby)
			if want < 0:
				return
			# turn this door until the truck's heading after it matches the route
			var guard: int = 0
			while _dlv_dir_after(int(a.direction), int(dn2.rot_idx)) != want and guard < 3:
				_level.on_clicked_door(dn2.board_pos)
				guard += 1
			_acted = true

# Which way a truck heading `dir` leaves a door in rotation `rot` (mirrors level.tick()).
func _dlv_dir_after(dir: int, rot: int) -> int:
	if rot == 1:
		return dir + 1 if (dir == 0 or dir == 2) else (dir + 3) % 4
	if rot == 2:
		return (dir + 3) % 4 if (dir == 0 or dir == 2) else (dir + 1) % 4
	return dir

func _dlv_next_door_cell(a) -> Vector2i:
	var p: Vector2i = a.board_pos
	var step: Vector2i = Vector2i(_level.DirArray[int(a.direction)])
	for _i in 40:
		p += step
		if not _level.game.in_board(p):
			break
		if _dlv_door_at(p) != null:
			return p
	return Vector2i(-1, -1)

func _dlv_next_lobby() -> Vector2i:
	var want: int = _level.tutorial_next_dock_id()
	for i in _level.targets.size():
		if is_instance_valid(_level.targets[i]) and int(_level.targets[i].id) == want:
			return _level.target_lobbies[i]
	return Vector2i(-1, -1)

func _dlv_route_dir(from: Vector2i, to: Vector2i) -> int:
	var prev: Dictionary = {from: from}
	var q: Array = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == to:
			break
		for d in 4:
			var n: Vector2i = c + Vector2i(_level.DirArray[d])
			if prev.has(n) or not _level.can_go_to(n):
				continue
			prev[n] = c
			q.append(n)
	if not prev.has(to):
		return -1
	var cur: Vector2i = to
	while prev[cur] != from:
		cur = prev[cur]
		if cur == from:
			return -1
	for d in 4:
		if Vector2i(_level.DirArray[d]) == cur - from:
			return d
	return -1

# Couples' player taps two cards. The probe taps the REAL card hit-areas (each card carries a
# transparent Control with gui_input), so a tutorial pointing at the wrong place fails here. It
# finds the pair the way a player would — two cards showing the same image — rather than reading
# _target_cells, so a board whose highlighted answer disagreed with what is drawn would be caught.
# When the coach says "tap its twin" it must be pointing at a card showing the SAME picture as the
# one the player is holding. A spotlight on any other card sends them to a guaranteed wrong answer
# while telling them it is the right one.
func _check_couples_twin(r) -> void:
	if not r._text_label.text.to_lower().contains("twin"):
		return
	if not _level.tutorial_has_selection():
		_fail("step %d says 'twin' but no card is held" % (r._idx + 1))
		return
	_claims_seen += 1
	if not r._has_spot:
		_fail("step %d says 'twin' but frames nothing" % (r._idx + 1))
		return
	var want: int = int(_level._cards[_level._selected]["img_idx"])
	var framed: Array = []
	for entry in _level._cards:
		var rect: Rect2 = entry["rect"]
		var ov: Rect2 = r._spot_rect.intersection(rect)
		if ov.size.x > 0.0 and ov.size.y > 0.0 and ov.get_area() / maxf(rect.get_area(), 1.0) > 0.5:
			framed.append(int(entry["img_idx"]))
	if framed.is_empty():
		_fail("step %d frames no card at all" % (r._idx + 1))
	elif not (want in framed):
		_fail("step %d says 'tap its twin' but frames a card showing a DIFFERENT picture" % (r._idx + 1))

func _act_couples(e: String) -> void:
	if not _level.tutorial_has_board():
		return
	var pair: Array = []
	for i in _level._cards.size():
		for j in range(i + 1, _level._cards.size()):
			if int(_level._cards[i]["img_idx"]) == int(_level._cards[j]["img_idx"]):
				pair = [i, j]
				break
		if not pair.is_empty():
			break
	if pair.is_empty():
		_fail("no two cards on the board share an image — there is no pair to find")
		return
	match e:
		"card_selected":
			if _level._selected >= 0:
				return
			_acted = true
			_tap_card(pair[0])
		"answered":
			if _level._selected < 0:
				_acted = true
				_tap_card(pair[0])
				return
			var other: int = pair[1] if _level._selected == pair[0] else pair[0]
			_acted = true
			_tap_card(other)

func _tap_card(idx: int) -> void:
	var hit = _level._cards[idx].get("hit", null)
	if hit == null or not is_instance_valid(hit):
		return
	_tap((hit as Control).get_global_rect().get_center())

# Dino N-Back's player does one thing: say match or no-match. The probe answers CORRECTLY, using
# the level's own _cur_is_target rather than re-deriving the rule — the coached steps each state
# which the card is, and a probe that disagreed with the level would be testing itself.
func _act_dinoback(e: String) -> void:
	if e != "answered":
		return
	if _level.phase != _level.Phase.SHOW or _level._answered or _level._cur_priming:
		return
	_acted = true
	_level._register_answer(_level.tutorial_is_target())

# Monkey C's player only ever does one thing: name the rule. Everything before that is watching,
# so the probe just waits for the belt to produce what the step is waiting for. It answers
# CORRECTLY, which is what the coached step asks for — and the correct key is the one the level
# recorded when it built the question, not a guess.
# The ✓/✗ captions assert what the robot is about to do. If the coach says "a ✓ means it obeys the
# rule and the robot takes it" while the framed item is one the robot will LEAVE, the tutorial is
# teaching the opposite of what the player is watching.
func _check_monkeyc_claim(r) -> void:
	# Whatever the coach frames on a window step must be ON the belt and hold the item it is
	# talking about. The window opens on an item still entering from ABOVE the belt, and the belt
	# clips its contents — so a step told about it too early framed empty space.
	if r._has_spot and _level.window_open:
		var belt: Control = _level._containers()[maxi(0, _level.window_belt)]
		var beltr: Rect2 = belt.get_global_rect()
		var inside: Rect2 = r._spot_rect.intersection(beltr)
		if inside.size.x <= 0.0 or inside.size.y <= 0.0:
			_fail("step %d frames %s, which is entirely OFF the belt %s"
				% [r._idx + 1, str(r._spot_rect), str(beltr)])
		elif inside.get_area() / maxf(r._spot_rect.get_area(), 1.0) < 0.6:
			_fail("step %d frames %s, only %.0f%% of which is on the belt"
				% [r._idx + 1, str(r._spot_rect),
				inside.get_area() / maxf(r._spot_rect.get_area(), 1.0) * 100.0])
		var it = _level.window_target_item
		if it != null and is_instance_valid(it):
			var itr: Rect2 = (it as Control).get_global_rect()
			var hit: Rect2 = r._spot_rect.intersection(itr)
			if hit.size.x <= 0.0 or hit.size.y <= 0.0:
				_fail("step %d frames a region that does not contain the judged item" % (r._idx + 1))
	var cap: String = r._text_label.text
	var says_yes: bool = cap.contains("A ✓ means")
	var says_no: bool = cap.contains("A ✗ means")
	if not says_yes and not says_no:
		return
	if not _level.tutorial_window_is_open():
		_fail("step %d talks about the framed item, but no window is open" % (r._idx + 1))
		return
	_claims_seen += 1
	var truth: bool = _level.tutorial_window_truth()
	if says_yes and not truth:
		_fail("step %d says ✓ / 'the robot takes it', but this item will be LEFT" % (r._idx + 1))
	if says_no and truth:
		_fail("step %d says ✗ / 'the robot leaves it', but this item will be TAKEN" % (r._idx + 1))

func _act_monkeyc(e: String) -> void:
	if e == "window_ready":
		return   # the belt brings the item in by itself
	if e != "question_answered":
		return
	if not _level.tutorial_question_open() or not _level.waiting_for_input:
		return
	var want: String = String(_level.question_correct_keys[0])
	for n in _all_nodes(_level):
		if n is Button and (n as Button).get_meta("opt_key", "") == want:
			_acted = true
			(n as Button).emit_signal("pressed")
			return

# Delem FP's player steers a truck that drives itself. The probe therefore does what a player does
# — press a direction — and works out which direction by routing over the same board the game uses.
# It re-routes every frame from agent.board_pos, which is safe here (unlike mmm) because board_pos
# is set the instant a tile move BEGINS, so the route is always "where do I leave the tile I am
# entering".
func _dfp_route_step(to: Vector2i) -> int:
	var a = _level.tutorial_agent()
	if a == null:
		return -1
	var from: Vector2i = a.board_pos
	if from == to:
		return -1
	var prev: Dictionary = {from: from}
	var queue: Array = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			break
		for d in 4:
			var n: Vector2i = c + Vector2i(_level.game.DirArray[d])
			if prev.has(n) or not _level.can_go_to(n):
				continue
			prev[n] = c
			queue.append(n)
	if not prev.has(to):
		return -1
	var cur: Vector2i = to
	while prev[cur] != from:
		cur = prev[cur]
		if cur == from:
			return -1
	var step: Vector2i = cur - from
	for d in 4:
		if Vector2i(_level.game.DirArray[d]) == step:
			return d
	return -1

# The road tile beside the dock the truck must visit next — standing there is what delivers.
func _dfp_next_lobby() -> Vector2i:
	var want: int = _level.tutorial_next_dock_id()
	for i in _level.targets.size():
		if is_instance_valid(_level.targets[i]) and int(_level.targets[i].id) == want:
			return _level.target_lobbies[i]
	return Vector2i(-1, -1)

# A caption that says "swipe / arrow keys" must appear on a step where steering ACTUALLY works.
# Delem FP put it on the talking step that PARKS the truck (tutorial_hold_truck), so the player
# read it, swiped, got nothing, and concluded the controls were broken — for two whole steps, until
# something else happened to release the truck.
#
# "Works" means: the player has the controls (not a talking step), the truck is not halted, and the
# camera is in (DelemfpG.freeze false — zoomed out, the game refuses movement by design).
func _check_delemfp_steerable(r) -> void:
	var cap: String = r._text_label.text.to_lower()
	if not (cap.contains("swipe") or cap.contains("arrow key")):
		return
	_claims_seen += 1
	var why: Array = []
	if r._blocking:
		why.append("it is a talking step (board frozen)")
	if _level.halt:
		why.append("the truck is halted")
	if DelemfpG.freeze:
		why.append("the view is zoomed out, which forbids movement")
	if not why.is_empty():
		_fail("step %d tells the player to steer, but %s" % [r._idx + 1, " and ".join(why)])

func _act_delemfp(e: String) -> void:
	match e:
		"zoomed_in":
			# Nothing for the player to do — the HUD countdown runs itself once the coach unpauses
			# the game, and the camera drops on the truck when it reaches zero.
			pass
		"packet_delivered":
			var lobby: Vector2i = _dfp_next_lobby()
			if lobby.x < 0:
				return
			var d: int = _dfp_route_step(lobby)
			if d < 0:
				return
			_acted = true
			_level.move_dir(d)
		"reminder_shown":
			_acted = true
			_level.display_reminder()
		"unzoomed":
			_acted = true
			_level.zoom_unzoom()

# Two things a Ptbits player does: take hold of a tool by its ring, and get a ball into its basket.
# The grab is a real tap at the real grab point (level._grab_at decides whether it lands, so a
# tutorial pointing at the wrong spot fails here). Bucketing a ball by simulating a physics drag
# would test Godot's solver rather than the tutorial, so the probe resolves the ball the way the
# game does once it settles in the basket.
func _act_ptbits(e: String) -> void:
	match e:
		"tool_grabbed":
			var loop: Vector2 = _level.tutorial_tool_loop(0)
			if loop == Vector2.ZERO:
				return
			_acted = true
			_tap(loop)
		"ball_scored":
			for b in _level._balls:
				if is_instance_valid(b):
					_acted = true
					_level._resolve_ball(b, true)
					return

# One judgment: swipe right to pick the framed item up, left to leave it. The probe answers
# CORRECTLY, which is what the coached step asks for.
func _act_sortingrobots(e: String) -> void:
	if e != "judged":
		return
	if not _level.window_open:
		return
	_acted = true
	_level._evaluate_answer(_level.window_target_truth)

func _act_didi(e: String) -> void:
	if e != "answered_right":
		return
	for a in _level._answer_agents:
		if is_instance_valid(a) and a.is_correct:
			_acted = true
			_level._on_answer_agent_pressed(a)
			return

# Mind Palace is a navigation game, so the probe has to actually walk. Two things make that work,
# both learned the hard way:
#   - player.path is Array[Vector2i]. Assigning a plain Array fails silently, the player never
#     moves, and the run looks like the tutorial is stuck — which is exactly how a probe bug came
#     to be reported as a game bug.
#   - hand the route over and leave it alone. Calling move_player_on_tick(true) every frame races
#     board_pos ahead of the tweened sprite, so "the tile under the player" is somewhere else and
#     every screen-space marker reads as off screen.
func _act_mmm(e: String) -> void:
	if _level.player == null or not is_instance_valid(_level.player):
		return
	match e:
		"player_moved":
			for dir in 4:
				if _level.can_go_to(_level.player.board_pos + _level.DirArray[dir]):
					_acted = true
					_level.move_dir(dir)
					return
		"coin_taken":
			_acted = true
			for p in _level.coins.keys():
				_route_to(p)
				return
		"room_entered":
			_acted = true
			for rid in _level.rooms.size():
				if not _level.visited_rooms.has(rid):
					var r = _level.rooms[rid]
					_route_to(r.position + Vector2i(r.size.x / 2, r.size.y / 2))
					return
		"room_answered":
			_acted = true
			_answer_a_room()

# BFS over the level's own walkability rule, handed to the player as a TYPED path.
func _route_to(goal) -> void:
	if goal == null or _level.player.path.size() > 0:
		return
	var from: Vector2i = _level.player.board_pos
	var target: Vector2i = Vector2i(goal)
	if from == target:
		return
	var prev: Dictionary = {from: from}
	var q: Array = [from]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if cur == target:
			var route: Array[Vector2i] = []
			while cur != from:
				route.push_front(cur)
				cur = prev[cur]
			_level.player.path = route
			return
		for d in _level.DirArray:
			var nxt: Vector2i = cur + d
			if prev.has(nxt) or not _level.can_go_to(nxt):
				continue
			prev[nxt] = cur
			q.append(nxt)


func _answer_a_room() -> void:
	for r in _all_controls(_level):
		if r.has_meta("is_correct") and int(r.get_meta("is_correct")) == 1:
			var ev: InputEventMouseButton = InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			_level._on_color_rect_input(ev, r)
			return
	for r2 in _all_controls(_level):
		if r2.has_meta("room_id"):
			var ev2: InputEventMouseButton = InputEventMouseButton.new()
			ev2.button_index = MOUSE_BUTTON_LEFT
			ev2.pressed = true
			_level._on_small_color_rect_input(ev2, r2)
			return

func _all_controls(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Control:
			out.append(c)
		out.append_array(_all_controls(c))
	return out

func _act_taxi(e: String) -> void:
	match e:
		"taxi_selected":
			for t in _level.taxis:
				if is_instance_valid(t) and not t.out_of_gas:
					_acted = true
					_level.on_taxi_pressed(t)
					return
		"customer_assigned":
			var taxi = _level.find_selected_taxi()
			if taxi == null:
				for t in _level.taxis:
					if is_instance_valid(t) and not t.out_of_gas:
						_level.on_taxi_pressed(t)
						break
				return
			for a in _level.agents:
				if is_instance_valid(a) and not a.is_taxi and a.assigned_to_taxi == null:
					_acted = true
					_level.on_agent_pressed(a)
					return
		"sent_to_gas":
			var taxi2 = _level.find_selected_taxi()
			if taxi2 == null:
				for t in _level.taxis:
					if is_instance_valid(t) and not t.out_of_gas and t.transaction_id < 0:
						_level.on_taxi_pressed(t)
						break
				return
			var station = _level.tutorial_gas_station()
			if station != null:
				_acted = true
				_level.on_clicked_target(station)

func _act_dino(e: String) -> void:
	if _level.phase != _level.Phase.SHOW or _level._answered:
		return
	if _game.game_time - _level._show_start_ms < 200.0:
		return
	if e == "answered_without_buttons":
		_level._answered_without_buttons = true
		_acted = true
		_level._register_answer(_level._cur_was_seen)
	elif e == "answered":
		_acted = true
		if _level._cur_was_seen:
			_level._on_seen_pressed()
		else:
			_level._on_new_pressed()

func _act_change(e: String) -> void:
	if _level.phase != _level.Phase.SHOW or _level._answered:
		return
	if e == "coin_moved":
		_acted = true
		_shift_top_coin()
	elif e == "coin_out_of_tray":
		for entry in _level._coins:
			if _level._in_basket(entry) and is_instance_valid(entry["node"]):
				entry["node"].position = _level._pile_rect.position + _level._pile_rect.size * 0.5
				_level._drag_coin = entry
				_level._drop_coin()
				_acted = true
				return
	elif e == "coin_in_tray":
		_acted = true
		_drag_coin(0)
	elif e == "paid" or e == "paid_correct":
		var need: float = _level._target_amount
		for i in _level._coins.size():
			if _level._in_basket(_level._coins[i]):
				continue
			var v: float = float(_level._coins[i]["value"])
			if v <= need + _level.PAY_EPSILON:
				_drag_coin(i)
				need -= v
		_acted = true
		_level._on_pay_pressed()

# Every step that names an amount must wait for a CORRECT payment. `paid` fires on a wrong one
# too, so the coach used to move on to the next pile having never had the amount it named paid.
func _check_pay_is_exact() -> void:
	var tut: Script = load("res://change/scripts/tutorial.gd")
	for step in tut.steps(_level, _game):
		var aw = step.get("await", null)
		var ev: String = ""
		if aw is String:
			ev = aw
		elif aw is Dictionary:
			ev = String(aw.get("event", ""))
		if ev == "paid":
			_fail("a payment step waits on 'paid', which a WRONG payment also fires")

# Pull a coin off the top of the heap, the way the "look underneath" step asks.
func _shift_top_coin() -> void:
	var top := -1
	var top_z: int = -99999
	for i in _level._coins.size():
		var node = _level._coins[i]["node"]
		if is_instance_valid(node) and node.z_index > top_z:
			top_z = node.z_index
			top = i
	if top < 0:
		return
	var entry = _level._coins[top]
	entry["node"].position = _level._pile_rect.position + Vector2(
		float(entry["radius"]) * 1.5, float(entry["radius"]) * 1.5)
	_level._drag_coin = entry
	_level._drop_coin()

func _drag_coin(i: int) -> void:
	if i >= _level._coins.size():
		return
	var entry = _level._coins[i]
	if not is_instance_valid(entry["node"]):
		return
	entry["node"].position = _level._basket_rect.position + _level._basket_rect.size * 0.5
	_level._drag_coin = entry
	_level._drop_coin()

func _act_aliens(e: String) -> void:
	if _level._areas.is_empty():
		return
	var want: bool = e == "promoted"
	var al = _level.tutorial_parked_alien(want, _level._tutorial_last_parked)
	if al == null:
		return
	var c: Vector2 = Vector2(_level._areas[0]["center"])
	if e == "promoted":
		_drag_alien(al, c)
	elif e == "evicted":
		_drag_alien(al, c + Vector2(0.0, float(_level._areas[0]["r_out"]) + float(al.radius) * 3.0))

func _drag_alien(al, target: Vector2) -> void:
	_acted = true
	_level._begin_drag(al, al.sim_pos)
	al.sim_pos = target
	al.position = target
	_level._drop_dragged(_game.game_time)

func _act_gorilla(e: String) -> void:
	if e != "player_steered" or _level.player == null:
		return
	_acted = true
	_level._move_dir(0)

func _act_wolves(e: String) -> void:
	if _level.player == null or not is_instance_valid(_level.player):
		return
	if e == "path_drawn":
		var h: Vector2i = _level.player.board_pos
		_acted = true
		MainGlobals.sig_path_drawn.emit([h, h + Vector2i(1, 0), h + Vector2i(2, 0)] as Array[Vector2i])
	elif e == "scared_one":
		for a in _level.agents:
			if a.agent_type != 0 or a.was_removed:
				continue
			var c = _level.bcell(a.board_pos)
			if c == null or c.room_id >= 0:
				continue
			_level.player.board_pos = a.board_pos
			_level.player.position = a.position
			_acted = true
			_level.move_player_on_tick(true)
			return

func _act_storm(e: String) -> void:
	if _level.player == null or not is_instance_valid(_level.player):
		return
	if e == "path_drawn":
		var h: Vector2i = _level.player.board_pos
		_acted = true
		MainGlobals.sig_path_drawn.emit([h, h + Vector2i(1, 0), h + Vector2i(2, 0)] as Array[Vector2i])
	elif e == "tool_placed":
		for y in _level.board.size():
			for x in _level.board[y].size():
				var c = _level.board[y][x]
				if c != null and c.ispipe and c.pipe != null and c.pipe.water_active:
					_level.player.board_pos = Vector2i(x, y)
					_level.player.position = _level.game.board_to_px(Vector2i(x, y))
					if _level.available_actions.is_empty():
						return
					var act = _level.available_actions[0]
					_level.get_action_by_id(act.id, true)
					c.action = act
					c.pipe.set_action(act.name, _level.action_textures.get(act.name, []),
						act.level, act.overflow_level)
					_acted = true
					_level.game.tutorial_notify("tool_placed")
					return

func _act_guidem(e: String) -> void:
	if e == "door_turned" and not _level.doors.is_empty():
		_acted = true
		_level.on_clicked_door(_level.doors[0].board_pos)

func _act_udbr(e: String) -> void:
	# Hold the flag the way a finger held on the screen does, until the ball reaches the end of
	# the lane. The steps wait on a COMPLETED breath, not on the direction latch.
	if e == "reached_top" or e == "reached_bottom":
		_acted = true
	MainGlobals.is_in_digitized_swipe_up = (e == "reached_top")
	MainGlobals.is_in_digitized_swipe_dn = (e == "reached_bottom")

func _can_check_freeze() -> bool:
	match _cur:
		"dino": return true
		"change": return _level.phase == _level.Phase.SHOW and not _level._coins.is_empty()
		"aliens": return not _level._aliens.is_empty()
		"gorilla", "wolves", "storm": return _level.player != null and is_instance_valid(_level.player)
		"guidem": return not _level.agents.is_empty()
		"udbr": return true
		"mmm": return _level.player != null and is_instance_valid(_level.player)
		"didi": return true
		"sortingrobots": return _level.window_open
		"ptbits": return _level.tutorial_has_ball()
		"delemfp": return _level.tutorial_agent() != null and not DelemfpG.freeze
		"monkeyc": return _level.tutorial_window_is_open()
		"dinoback": return _level.tutorial_has_card()
		"couples": return _level.tutorial_has_board()
		"deliverem": return _level.tutorial_agent() != null
		"lightsout": return _level.tutorial_has_player()
		"taxi": return not _level.taxis.is_empty()
	return false

func _assert_frozen() -> void:
	if not _game.paused():
		_fail("freeze: game not paused while talking")
	match _cur:
		"taxi":
			# Taxis drive on their own once dispatched, and fuel burns while they do — both must
			# stop dead while a caption is up, or a slow reader loses taxis to a lesson.
			var pos0: Array = []
			var fuel0: Array = []
			for t in _level.taxis:
				if is_instance_valid(t):
					pos0.append(t.position)
					fuel0.append(t.fuel_level)
			for _i in 40:
				await get_tree().process_frame
			var moved: float = 0.0
			var burned: float = 0.0
			var k: int = 0
			for t in _level.taxis:
				if is_instance_valid(t) and k < pos0.size():
					moved = maxf(moved, Vector2(pos0[k]).distance_to(t.position))
					burned = maxf(burned, absf(float(fuel0[k]) - t.fuel_level))
					k += 1
			if moved > 1.0:
				_fail("freeze: a taxi moved %.1f px while talking" % moved)
			if burned > 0.001:
				_fail("freeze: a taxi burned %.4f of its tank while talking" % burned)
		"dino":
			var dp0: int = _level.phase
			var dr0: int = _level.total_rounds
			for _i in 40:
				await get_tree().process_frame
			if _level.phase != dp0:
				_fail("freeze: phase advanced while talking")
			if _level.total_rounds != dr0:
				_fail("freeze: a card resolved while talking")
		"change":
			var p0: int = _level.phase
			var e0: float = _game.game_time - _level._show_start_ms
			for _i in 40:
				await get_tree().process_frame
			if _level.phase != p0:
				_fail("freeze: phase advanced while talking")
			if absf((_game.game_time - _level._show_start_ms) - e0) > 50.0:
				_fail("freeze: the board deadline advanced while talking")
		"aliens":
			var poses: Array = []
			for al in _level._aliens:
				poses.append(al.sim_pos)
			for _i in 40:
				await get_tree().process_frame
			for i in mini(poses.size(), _level._aliens.size()):
				if _level._aliens[i].sim_pos.distance_to(poses[i]) > 0.5:
					_fail("freeze: aliens kept moving while talking")
					break
		"gorilla":
			var n0: int = _level.coins.size()
			var g0 = _level.player.board_pos
			for _i in 40:
				await get_tree().process_frame
			if _level.coins.size() != n0 or _level.player.board_pos != g0:
				_fail("freeze: the board moved while talking")
		"wolves", "storm", "guidem":
			var w0 = _level.player.board_pos if _cur != "guidem" else Vector2i.ZERO
			for _i in 40:
				await get_tree().process_frame
			if _cur != "guidem" and _level.player.board_pos != w0:
				_fail("freeze: the player moved while talking")
		"lightsout":
			# The player walks tile to tile on a major tick; a caption must stop it dead.
			var lo_p0 = _level.player.board_pos
			var lo_lights: bool = _level.tutorial_lights_are_off()
			for _i in 40:
				await get_tree().process_frame
			if _level.player.board_pos != lo_p0:
				_fail("freeze: the player walked (%s -> %s) while talking"
					% [str(lo_p0), str(_level.player.board_pos)])
			if _level.tutorial_lights_are_off() != lo_lights:
				_fail("freeze: the lights changed while talking")
		"deliverem":
			# The truck slides between tiles on a hand-rolled interpolation against the WALL clock,
			# so a pause that does not reach it lets the truck drive on under the caption.
			var dlv = _level.tutorial_agent()
			var dp0: Vector2 = dlv.position
			var dkeep: Array = [dlv.target_position, dlv.starting_position,
				dlv.time_from_start_to_target_ms, dlv.time_set_target_pos]
			dlv.set_target_pos(dp0 + Vector2(0.0, 64.0))
			for _i in 40:
				await get_tree().process_frame
			if dlv.position.distance_to(dp0) > 1.0:
				_fail("freeze: the truck drove %.1f px into a caption" % dlv.position.distance_to(dp0))
			dlv.position = dp0
			dlv.target_position = dkeep[0]
			dlv.starting_position = dkeep[1]
			dlv.time_from_start_to_target_ms = dkeep[2]
			dlv.time_set_target_pos = dkeep[3]
		"couples":
			# The board carries a countdown measured in game.game_time, which excludes paused time.
			var cp0: int = _level.phase
			var ct0: float = _game.game_time - _level._show_start_ms
			for _i in 40:
				await get_tree().process_frame
			if _level.phase != cp0:
				_fail("freeze: the board phase advanced while talking")
			if absf((_game.game_time - _level._show_start_ms) - ct0) > 50.0:
				_fail("freeze: the board deadline ran on while talking")
		"dinoback":
			# The card carries a countdown measured in game.game_time, which excludes paused time —
			# so a caption must stop the deadline dead. A player who reads slowly would otherwise
			# lose the card the coach is talking about.
			var db_phase0: int = _level.phase
			var db_seq0: int = _level._seq.size()
			var db_t0: float = _game.game_time - _level._show_start_ms
			for _i in 40:
				await get_tree().process_frame
			if _level.phase != db_phase0:
				_fail("freeze: the card phase advanced while talking")
			if _level._seq.size() != db_seq0:
				_fail("freeze: another card was dealt while talking")
			if absf((_game.game_time - _level._show_start_ms) - db_t0) > 50.0:
				_fail("freeze: the card deadline ran on while talking")
		"monkeyc":
			# The belts scroll from _process, which returns early on game.paused() — so a caption
			# must stop the belt, the window and the ✓/✗ timing all at once.
			var mk0: Array = []
			for it in _level.belt_items[0]:
				if is_instance_valid(it["ctrl"]):
					mk0.append(it["ctrl"].position.y)
			for _i in 40:
				await get_tree().process_frame
			var mi: int = 0
			for it in _level.belt_items[0]:
				if is_instance_valid(it["ctrl"]) and mi < mk0.size():
					if absf(it["ctrl"].position.y - mk0[mi]) > 0.5:
						_fail("freeze: the belt kept scrolling while talking")
						break
					mi += 1
		"delemfp":
			# The truck slides between tiles on a hand-rolled interpolation rather than a Tween, so
			# a pause that does not reach it lets the truck drive on under the caption — straight
			# past the dock the caption is telling the player about.
			#
			# Sampling whatever move happens to be in flight is a coin toss: a tile move is over in
			# a few frames, so a stationary truck passes this whether the pause reaches it or not.
			# Put a fresh move in flight first — the exact situation a caption interrupts — and
			# then nothing at all may happen to it.
			var tagent = _level.tutorial_agent()
			var tp0: Vector2 = tagent.position
			var t_keep: Array = [tagent.target_position, tagent.starting_position,
				tagent.time_from_start_to_target_ms, tagent.time_set_target_pos]
			tagent.set_target_pos(tp0 + Vector2(0.0, 64.0))
			for _i in 40:
				await get_tree().process_frame
			var tmoved: float = tagent.position.distance_to(tp0)
			if tmoved > 1.0:
				_fail("freeze: the truck drove %.1f px into a caption" % tmoved)
			# Put the truck's real move back exactly as it was, so the probe's own test does not
			# leave a 64px lurch queued up for the moment play resumes.
			tagent.position = tp0
			tagent.target_position = t_keep[0]
			tagent.starting_position = t_keep[1]
			tagent.time_from_start_to_target_ms = t_keep[2]
			tagent.time_set_target_pos = t_keep[3]
		"ptbits":
			# The balls are RigidBody2Ds under gravity: if the freeze does not reach the physics
			# server, the ball the coach is pointing at drops out of the field while it talks.
			var bp0: Array = []
			for b in _level._balls:
				if is_instance_valid(b):
					bp0.append(b.global_position)
			for _i in 40:
				await get_tree().process_frame
			var bk: int = 0
			for b in _level._balls:
				if is_instance_valid(b) and bk < bp0.size():
					if b.global_position.distance_to(bp0[bk]) > 0.5:
						_fail("freeze: a ball kept falling while talking")
						break
					bk += 1
			if _level._balls.size() != bp0.size():
				_fail("freeze: the number of balls changed while talking")
		"udbr":
			var t0: float = _level._elapsed_ms
			for _i in 40:
				await get_tree().process_frame
			if absf(_level._elapsed_ms - t0) > 1.0:
				_fail("freeze: the session clock ran on while talking")

func _all_nodes(n: Node) -> Array:
	var out: Array = []
	if n == null or not is_instance_valid(n):
		return out
	for c in n.get_children():
		out.append(c)
		out.append_array(_all_nodes(c))
	return out

func _check_caption(r) -> void:
	if r._idx < 0 or r._idx >= r._steps.size():
		return
	# A step with no title and no text draws no caption on purpose — it exists only to wait for the
	# game to reach some state. Nothing to measure, and "empty caption" is the point.
	if not r._panel.visible:
		return
	var pr: Rect2 = r._panel.get_global_rect()
	var screen: Vector2 = Vector2(MainGlobals.screen_size)
	var bar: float = 70.0 if MainGlobals.is_mobile() else 44.0
	if pr.position.x < 0.0 or pr.end.x > screen.x + 0.5:
		_fail("step %d: caption off screen horizontally" % (r._idx + 1))
	if pr.position.y < 0.0:
		_fail("step %d: caption above the top of the screen" % (r._idx + 1))
	if pr.end.y > screen.y - bar + 0.5:
		_fail("step %d: caption overlaps the app bottom bar" % (r._idx + 1))
	if pr.size.y < 30.0:
		_fail("step %d: caption only %.0f px tall" % [r._idx + 1, pr.size.y])
	# "Covers" means the caption is SITTING ON what the step points at — the balloon hiding its own
	# subject. A binary intersects() also fails a 1px kiss of the ring, which is invisible and is
	# often the best placement available once the keep-clear zones are counted too. So: fail if the
	# caption covers the spotlight's centre, or eats more than a twentieth of it.
	if r._has_spot:
		var ovs: Rect2 = pr.intersection(r._spot_rect)
		var eaten: float = 0.0
		if ovs.size.x > 0.0 and ovs.size.y > 0.0:
			eaten = ovs.get_area() / maxf(r._spot_rect.get_area(), 1.0)
		if pr.has_point(r._spot_rect.get_center()) or eaten > 0.05:
			_fail("step %d: caption covers %.0f%% of its own spotlight (panel %s, spot %s)"
				% [r._idx + 1, eaten * 100.0, str(pr), str(r._spot_rect)])
	if r._steps[r._idx].has("spot") and not r._has_spot:
		_fail("step %d: declares a spotlight but nothing resolved" % (r._idx + 1))
	# Resolving is not enough — it has to be somewhere the player can SEE. Guidem pointed at "one
	# of your walkers" while the car was still out at a board edge, off camera, so the caption
	# described something that was not on screen.
	if r._has_spot:
		var sc: Vector2 = r._spot_rect.get_center()
		var lit: Vector2 = r._dim.size
		if sc.x < 0.0 or sc.y < 0.0 or sc.x > lit.x or sc.y > lit.y:
			_fail("step %d: spotlight is OFF SCREEN at %s (overlay is %s)" % [r._idx + 1, str(sc), str(lit)])
	if r._text_label.text.strip_edges().is_empty():
		_fail("step %d: empty caption" % (r._idx + 1))
	# Labels are TOP-aligned, so the TEXT occupies the first _label_height px of each label rect
	# and the remainder is empty space the panel clips. Check where the text actually ends —
	# "tap to continue" hanging below the balloon was a height-measurement error, invisible if you
	# only look at the panel.
	var inner: float = pr.size.x - 36.0
	for lbl: Label in [r._title_label, r._text_label, r._foot_label]:
		if not lbl.visible or lbl.text.is_empty():
			continue
		var text_bottom: float = lbl.get_global_rect().position.y + r._label_height(lbl, inner)
		if text_bottom > pr.end.y - 13.0:
			_fail("step %d: caption text runs %.0f px past the balloon" % [r._idx + 1,
				text_bottom - (pr.end.y - 14.0)])

func _check_player_did_it(step: Dictionary, idx: int) -> void:
	var spec = step.get("await", null)
	var ev: String = ""
	if spec is String:
		ev = spec
	elif spec is Dictionary:
		ev = String(spec.get("event", ""))
	if ev.is_empty() or not PLAYER_EVENTS.has(ev):
		return
	if not _acted:
		_fail("step %d ('%s') completed without the player doing anything" % [idx + 1, ev])

# udbr's whole point: the ball runs up and down a centered vertical lane, so the caption must stay
# off it. This is the failure the right-hand caption exists to fix, and nothing else would see it.
func _check_lane_clear(r) -> void:
	var area: Control = _level.get_node_or_null("SwipeArea")
	if area == null:
		return
	var w: float = area.size.x
	var h: float = area.size.y
	var top_w: float = 180.0 if MainGlobals.is_mobile() else 130.0
	var o: Vector2 = area.get_global_rect().position
	var lane: Rect2 = Rect2(o + Vector2(w * 0.5 - top_w * 0.5, h * UdbrG.LANE_TOP_FRAC),
		Vector2(top_w, h * (UdbrG.LANE_BOT_FRAC - UdbrG.LANE_TOP_FRAC)))
	var pr: Rect2 = r._panel.get_global_rect()
	if pr.intersects(lane):
		_fail("step %d: caption %s covers the lane %s" % [r._idx + 1, str(pr), str(lane)])

func _check_timeout(step: Dictionary, idx: int, took: float) -> void:
	var spec = step.get("await", null)
	if not (spec is Dictionary):
		return
	var t: float = float(spec.get("timeout", 0.0))
	if t > 0.0 and took >= t * 0.9:
		_fail("step %d ('%s') ended on its TIMEOUT after %.1fs" % [idx + 1, String(spec.get("event", "?")), took])

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
