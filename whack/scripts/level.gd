extends CanvasLayer

signal started_playing
signal sig_level_is_done(didwin: bool)

var game: GenericGameUtil

var level: int = 1
var max_difficulty: int = WhackLevelConfig.LEVELS.size()
var num_corrects_in_level_so_far: int = 0
# Three things stacked, and they are three different things:
#
#   a PRESENTATION is one target shown — hit, missed, or correctly left alone
#   a ROUND is `targets_in_round` presentations, with a short panel at its end
#   a LEVEL is `rounds_per_level` rounds, and the accuracy gate over all of them decides passing
#
# The level used to end on a count of HITS ("hits_to_complete"), which meant a level always ended
# ON a hit and so could not be failed however many were missed on the way — the same defect
# polkadots had to be fixed for. It also made levels wildly uneven: 5 hits at level 1, 30 at
# level 4, 15 at level 5.
var targets_in_round: int = 5
var rounds_per_level: int = 4
var _targets_in_round_so_far: int = 0
var _rounds_in_level: int = 0
# A round has ended and its panel is up; the next presentation waits for it to be dismissed.
var _waiting_after_round: bool = false
var target_radius: float = 48.0
var show_target_ms: float = 4000.0
var interval_min_ms: float = 1000.0
var interval_max_ms: float = 2500.0
var _num_decoys: int = 0
var _no_real_chance: float = 0.0
var _same_color_decoy: bool = false
var _use_many_colors_for_decoys: bool = false

# The tap ring is an acknowledgement, not information: by the time it is drawn the tap has already
# been scored. At the original 2.5/s it lingered 400 ms — long enough to still be on screen during
# the NEXT tutorial step, because the coach advances on the same frame as the hit. 12/s clears it
# in about 80 ms, and `_spawn_round()` clears it outright so it can never overlap a new round.
const FLASH_FADE_PER_SEC: float = 12.0

const _DECOY_COLOR_DEFAULT: Color = Color(0.25, 0.5, 1.0, 1.0)
const _DECOY_COLORS_MULTI: Array = [
	Color(0.3,  0.85, 0.3,  1.0),  # green
	Color(0.75, 0.3,  0.9,  1.0),  # purple
	Color(0.9,  0.85, 0.2,  1.0),  # yellow
	Color(0.2,  0.85, 0.85, 1.0),  # cyan
	Color(0.9,  0.3,  0.7,  1.0),  # pink
]

var _target_active: bool = false
var _target_pos: Vector2 = Vector2.ZERO
var _target_color: Color = Color(1.0, 0.35, 0.2, 1.0)

# Each decoy: { "pos": Vector2, "color": Color, "draw_dot": bool }
var _decoys: Array = []

# Tutorial only; both are inert in normal play.
#
# `tutorial_rounds` is a queue of rounds the coach needs to show, consumed one per spawn:
#   {"real": bool, "decoys": int, "mode": "blue" | "multi" | "same"}
# The game would only reach "a real target beside two same-colored decoys" by luck, and that is
# precisely the round a first-timer has to be walked through.
#
# `tutorial_no_timeout` holds a round on screen indefinitely so the player can be told what they
# are looking at before it vanishes. It is switched OFF again for the lesson about empty rounds,
# which can only be taught by letting one time out.
var tutorial_rounds: Array = []
var tutorial_no_timeout: bool = false
# While the coach is running, rounds appear ONLY from tutorial_stage_now(). The level otherwise
# keeps scheduling its own on the normal 700-1500 ms gap -- new_game() queues one immediately, and
# so does every hit -- and one of those could land in the gap between two steps: an unstaged round,
# with no band, that then blocked the staged one because a round was already active.
var tutorial_only_staged: bool = false
# Taps are swallowed while the coach is asking the player to WATCH rather than act. Hitting the
# target during the "watch the ring" step ends the round, so the ring never reaches its halfway
# mark and the step it is waiting on can never be satisfied -- a dead end reachable by doing the
# one thing the tutorial has spent four steps training the player to do.
var tutorial_ignore_taps: bool = false
# A round the coach wants back if it expires. The lesson about the countdown has to let the ring
# actually run out, which means the player can miss it -- and the step is waiting for a hit, so a
# missed target would leave nothing to hit and nothing to wait for. Re-staging the same round on
# timeout turns the miss into part of the lesson instead of a dead end.
var tutorial_retry_spec: Dictionary = {}

# Floating score changes: {"pos": Vector2, "text": String, "color": Color, "age": float}.
# Every scoring event in this game is a tap or a target expiring, and until now the only feedback
# was a colored flash that said "something happened" without saying what it cost. The number is
# the part the player is trying to learn.
var _pops: Array = []
const POP_LIFE_SEC: float = 0.9
const POP_RISE_PX: float = 42.0

# What sitting out a round with no real target is worth. Waiting is a decision, and the only one
# the game never acknowledged: letting a real target expire costs 5, tapping a decoy costs 5, and
# correctly tapping nothing paid nothing at all. Mirrors the penalty it avoids.
const NO_TARGET_REWARD: int = 5
var _tutorial_half_sent: bool = false
var _round_show_ms: float = 0.0

var _round_active: bool = false
var _round_has_real: bool = true
# Set by ANY tap during the round. Waiting out an empty round only pays if the player actually
# waited. Tapping a decoy costs 5, so paying 5 back at the end would net zero and quietly refund a
# wrong tap; and tapping empty space in an empty round is free by design, but it is still not
# waiting, so it should not earn the reward either.
var _round_was_tapped: bool = false
var _round_shown_time_ms: float = 0.0

var _reaction_times: Array = []
var _accuracies: Array = []

var _next_target_time_ms: float = 0.0
var _waiting_for_next: bool = false

var _flash_color: Color = Color.TRANSPARENT
var _flash_alpha: float = 0.0
var _flash_pos: Vector2 = Vector2.ZERO

var _hit_sound: AudioStream = preload("res://art/sounds/tap-1.mp3")
var _miss_sound: AudioStream = preload("res://art/sounds/bump-sound-7.mp3")
var _appear_sound: AudioStream = preload("res://art/sounds/click-2.mp3")

@onready var _draw_area: Control = $DrawArea

# What the score was when this level began. A level that misses the gate gives its points
# back (see the level-done function): without that, failing forever is a way to earn forever
# — every attempt banked its points and the retry cost nothing.
var _bg: Control = null
var _bg_t: float = 0.0

var _score_at_level_start: int = 0
var _rollback_score_on_next_level: bool = false

func _ready() -> void:
	game = WhackG.game
	game.sig_time_over.connect(_on_time_over)
	level = WhackG.starting_level
	_apply_difficulty()
	game.add_sound(self, "hit", _hit_sound)
	game.add_sound(self, "miss", _miss_sound)
	game.add_sound(self, "appear", _appear_sound)
	game.add_sound(self, "wrong", preload("res://art/sounds/swoosh.mp3"))
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_draw_area.position = Vector2.ZERO
	_draw_area.size = vp_size
	_draw_area.gui_input.connect(_on_draw_area_input)
	_apply_look()

# The board is a fairground whack-a-mole box seen from above, drawn — see
# whack/scripts/board_backdrop.gd for why it is that, and why it is top-down. It replaces the tiled
# `res://art/grass.png` every screen in the app used to wear.
func _apply_look() -> void:
	var ground: TextureRect = $Background
	ground.texture = null
	_bg = WhackBoardBackdrop.attach(ground)
	if _bg.draw.get_connections().is_empty():
		_bg.draw.connect(func() -> void: WhackBoardBackdrop.draw(_bg, _bg_t))
	set_process(true)


func new_game(from_scratch: bool = true) -> void:
	# The failed level's points go back HERE, on Continue, together with everything else that is
	# cleared — so the summary card was still read against the score the player had while playing.
	if _rollback_score_on_next_level:
		_rollback_score_on_next_level = false
		game.score = _score_at_level_start
	_score_at_level_start = game.score
	# A replay has to be a FRESH attempt. The gate reads these, so a retry that inherited the
	# misses which failed the level could not pass it even played perfectly; and the summary's
	# timing average would fold in the attempt the player is being made to redo.
	game.corrects = 0
	game.mistakes = 0
	_reaction_times.clear()
	_accuracies.clear()
	game.level_is_ready = false
	if from_scratch:
		level = WhackG.starting_level
	else:
		if game.need_to_increase_level:
			level = min(level + 1, max_difficulty)
			game.need_to_increase_level = false
	_apply_difficulty()
	game.level_label_changed("Level %d" % level)
	num_corrects_in_level_so_far = 0
	_rounds_in_level = 0
	_targets_in_round_so_far = 0
	_waiting_after_round = false
	_target_active = false
	_round_active = false
	_decoys.clear()
	_waiting_for_next = false
	_flash_alpha = 0.0
	_draw_area.queue_redraw()
	# The coach's session is one continuous lesson: a briefing card in front of it would land on a
	# caption, and its rounds are staged by the tutorial rather than scheduled here.
	if game.tutorial_mode:
		_begin_play()
		return
	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	game.show_game_popup(self, "Level %d" % level, _level_briefing())

# What this level is about to be. Every one of these numbers changes between levels and none of
# them was ever said: the player met a smaller, faster, more crowded board with no warning and had
# to work out what had changed from the way it felt.
func _level_briefing() -> String:
	var text: String = "Target: %s\nOn screen: %.1f s" % [
		_target_size_word(), show_target_ms / 1000.0]
	if _num_decoys > 0:
		text += "\nDecoys: %d" % _num_decoys
	# The last level's quota is the sentinel 999, which is not a number to show anyone.
	text += "\nRounds: %d x %d\nPass mark: %d%%" % [
		rounds_per_level, targets_in_round, WhackLevelConfig.pass_pct_for(level)]
	if level >= max_difficulty:
		text += "\n\nThe last level. It comes round again however well you do."
	return text

# The radius in pixels is a number the player cannot act on and cannot picture — it told them
# nothing that looking at the first target would not. Three words they can hold in their head
# before the level starts are worth more.
#
# The thresholds are set against the actual table, which runs 38, 30, 25, 20, 17, 15, 10: they cut
# it two / two / three rather than stranding one level alone at the top.
func _target_size_word() -> String:
	if target_radius >= 28.0:
		return "Big"
	if target_radius >= 18.0:
		return "Medium"
	return "Small"

# Two different cards close through here, because sig_game_popup_closed is global: the level
# briefing before play starts, and the between-rounds panel during it.
func _on_game_popup_closed() -> void:
	if not game.level_is_ready:
		_begin_play()
	elif _waiting_after_round:
		_waiting_after_round = false
		_schedule_next_target()

# Play starts when the briefing is out of the way, not while it is being read — started_playing is
# what sets game.playing and restarts the session clock.
func _begin_play() -> void:
	if game.level_is_ready:
		return
	_schedule_next_target()
	game.level_is_ready = true
	started_playing.emit()

# Stage a round AND show it immediately, instead of queueing it behind the normal 700-1500 ms gap.
#
# The coach's caption is laid out the moment its step opens. With the round arriving a second
# later, the caption described circles that were not there yet, and then the caption jumped once
# they appeared and `keep_clear` finally had something to avoid. Spawning inside the step's setup,
# which runs before the step opens, makes the circles part of the layout from the first frame.
func tutorial_stage_now(spec: Dictionary) -> void:
	tutorial_rounds.append(spec)
	# Replace whatever is on screen rather than queueing behind it. Queueing was what made a step
	# talk over the wrong round: an unstaged round already up meant the staged one waited, and then
	# arrived mid-step -- decoys vanishing and the target jumping to a new place while the caption
	# was still describing the old one.
	_round_active = false
	_target_active = false
	_decoys.clear()
	_spawn_round()

func _apply_difficulty() -> void:
	var idx: int = clamp(level - 1, 0, WhackLevelConfig.LEVELS.size() - 1)
	var cfg: Dictionary = WhackLevelConfig.LEVELS[idx]
	target_radius = cfg["radius"]
	show_target_ms = cfg["show_ms"]
	interval_min_ms = cfg["interval_min_ms"]
	interval_max_ms = cfg["interval_max_ms"]
	targets_in_round = int(cfg.get("num_targets_in_round", 5))
	rounds_per_level = int(cfg.get("num_rounds", 4))
	_num_decoys = cfg.get("num_decoys", 0)
	_no_real_chance = cfg.get("no_real_chance", 0.0)
	_same_color_decoy = cfg.get("same_color_decoy", false)
	_use_many_colors_for_decoys = cfg.get("use_many_colors_for_decoys", false)

func _schedule_next_target() -> void:
	var interval: float = randf_range(interval_min_ms, interval_max_ms)
	_next_target_time_ms = game.game_time + interval
	_waiting_for_next = true

# `band` optionally restricts the vertical range to a fraction of the playable area, as
# [min, max] in 0..1. The tutorial uses it to keep every circle in the lower part of the field so
# the caption has somewhere to sit: with circles free to land anywhere they can span the whole
# field, and then the balloon has no choice but to bury one.
func _try_random_pos(area_size: Vector2, existing: Array, band = null) -> Variant:
	var top_margin: float = 120.0
	var bottom_margin: float = 80.0
	var visual_radius: float = target_radius + 11.0  # circle edge + arc (radius+9 center, 4px wide)
	var pad: float = visual_radius + 4.0
	var min_sep: float = visual_radius * 2.0 + 12.0
	var x_min: float = pad
	var x_max: float = area_size.x - pad
	var y_min: float = top_margin + pad
	var y_max: float = area_size.y - bottom_margin - pad
	if band != null:
		var span: float = y_max - y_min
		var lo: float = y_min + span * float(band[0])
		var hi: float = y_min + span * float(band[1])
		if hi - lo >= pad:
			y_min = lo
			y_max = hi
	if x_max <= x_min or y_max <= y_min:
		return null
	for _attempt in range(200):
		var pos: Vector2 = Vector2(randf_range(x_min, x_max), randf_range(y_min, y_max))
		var ok: bool = true
		for ep in existing:
			if pos.distance_to(ep) < min_sep:
				ok = false
				break
		if ok:
			return pos
	return null

func _spawn_round() -> void:
	_waiting_for_next = false
	_round_was_tapped = false
	_flash_alpha = 0.0        # never let the last tap's ring bleed into a new round
	var forced = null
	if not tutorial_rounds.is_empty():
		forced = tutorial_rounds.pop_front()
	_round_has_real = randf() >= _no_real_chance
	if forced != null:
		_round_has_real = bool(forced.get("real", true))
	# A round with no real target AND no decoys puts nothing whatsoever on the screen: dead time
	# that reads as a long gap, with no decision in it for the player to get right. Level 1 shipped
	# able to produce one (no_real_chance 0.1 against num_decoys 0) and it went unnoticed for
	# exactly that reason -- it had no consequence, until the wait-it-out reward gave it one.
	#
	# This has to be decided HERE, before the block below places the target: deciding it later,
	# next to the decoy count, is too late to bring a target back and the guard silently does
	# nothing. Organic rounds only -- a round the coach staged is left exactly as asked, so the
	# tutorial keeps full control of what it puts on screen.
	if not _round_has_real and forced == null and _num_decoys <= 0:
		_round_has_real = true
	_decoys.clear()
	_target_active = false

	var area_size: Vector2 = _draw_area.size
	if area_size.x < 100.0 or area_size.y < 100.0:
		area_size = Vector2(680.0, 788.0)

	var used_positions: Array = []

	var band = null
	if forced != null:
		band = forced.get("band", null)
	if _round_has_real:
		var rpos: Variant = _try_random_pos(area_size, used_positions, band)
		if rpos != null:
			_target_pos = rpos
			used_positions.append(_target_pos)
			_target_active = true

	var round_same_color: bool = _same_color_decoy
	var round_multi_color: bool = _use_many_colors_for_decoys
	if _same_color_decoy and _use_many_colors_for_decoys:
		round_same_color = randf() < 0.5
		round_multi_color = not round_same_color
	var want_decoys: int = _num_decoys
	if forced != null:
		var mode: String = str(forced.get("mode", "blue"))
		round_same_color = mode == "same"
		round_multi_color = mode == "multi"
		want_decoys = int(forced.get("decoys", 0))

	var decoy_count: int = 0
	for _i in range(want_decoys):
		var dpos: Variant = _try_random_pos(area_size, used_positions, band)
		if dpos == null:
			break  # can't fit more decoys without overlapping — stop here
		used_positions.append(dpos)
		var dcolor: Color
		if round_same_color:
			dcolor = _target_color
		elif round_multi_color:
			dcolor = _DECOY_COLORS_MULTI[decoy_count % _DECOY_COLORS_MULTI.size()]
		else:
			dcolor = _DECOY_COLOR_DEFAULT
		_decoys.append({"pos": dpos, "color": dcolor, "draw_dot": not round_same_color})
		decoy_count += 1

	_round_shown_time_ms = game.game_time
	_round_active = true
	_tutorial_half_sent = false
	# A round may be given its own window, so the coach can let the countdown ring deplete at a
	# readable pace instead of the level's own two seconds.
	_round_show_ms = show_target_ms
	if forced != null and forced.has("show_ms"):
		_round_show_ms = float(forced["show_ms"])
	game.tutorial_notify("round_shown")   # no-op outside tutorial mode
	_target_color = Color(1.0, 0.35, 0.2, 1.0)
	game.play_sound("appear")
	_draw_area.queue_redraw()

func _process(_delta: float) -> void:
	# The board lives whether or not the game is running: it is the room, not the round.
	if _bg != null and is_instance_valid(_bg) and _bg.is_visible_in_tree():
		_bg_t += _delta
		_bg.queue_redraw()
	# The tap flash fades ABOVE the pause guard. Below it, a caption freezing the game froze the
	# flash too, so the colored ring left by a tap sat there at full strength and was still on
	# screen during the next step. It is feedback for a tap that has already been judged; it has
	# no reason to wait for the game.
	if _flash_alpha > 0.0:
		_flash_alpha -= _delta * FLASH_FADE_PER_SEC
		if _flash_alpha < 0.0:
			_flash_alpha = 0.0
		_draw_area.queue_redraw()
	if not _pops.is_empty():
		for i in range(_pops.size() - 1, -1, -1):
			_pops[i]["age"] = float(_pops[i]["age"]) + _delta
			if float(_pops[i]["age"]) >= POP_LIFE_SEC:
				_pops.remove_at(i)
		_draw_area.queue_redraw()
	if not game.level_is_ready or game.level_is_done or game.paused():
		return
	if _waiting_for_next and not tutorial_only_staged \
			and game.game_time >= _next_target_time_ms:
		_spawn_round()
	if _round_active and not _tutorial_half_sent \
			and (game.game_time - _round_shown_time_ms) >= _round_window() * 0.5:
		_tutorial_half_sent = true
		game.tutorial_notify("half_gone")   # the countdown ring is half closed
	if _round_active and not tutorial_no_timeout \
			and (game.game_time - _round_shown_time_ms) >= _round_window():
		_on_round_timeout()
	if _round_active:
		_draw_area.queue_redraw()

func _on_round_timeout() -> void:
	# Where the target WAS: it is cleared below, and a penalty with nothing to point at reads as
	# arbitrary. A round with no real target costs nothing and gets no pop.
	var expired_at: Vector2 = _target_pos
	var had_real: bool = _target_active
	# Where the decoys were, for the reward below: it belongs on the things the player correctly
	# left alone, not in some neutral corner. Falls back to the center of the playfield when the
	# round was completely empty.
	var decoy_center: Vector2 = Vector2.ZERO
	if _decoys.is_empty():
		decoy_center = _draw_area.size * 0.5
	else:
		for d in _decoys:
			decoy_center += d["pos"]
		decoy_center /= float(_decoys.size())
	_round_active = false
	_target_active = false
	_decoys.clear()
	if _round_has_real:
		if had_real:
			_pop_at(expired_at, -5)
		game.add_score_and_time(-5, -5)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("wrong")
	elif not _round_was_tapped:
		# Nothing to hit, and the player did not tap anything either.
		_pop_at(decoy_center, NO_TARGET_REWARD)
		game.add_score_and_time(NO_TARGET_REWARD, NO_TARGET_REWARD)
		game.add_correct_or_mistake(1, 0)
		game.play_sound("hit")
	_draw_area.queue_redraw()
	game.tutorial_notify("round_gone")
	if not tutorial_retry_spec.is_empty():
		tutorial_stage_now(tutorial_retry_spec.duplicate())
		return
	_end_of_target()

# One door for both ways a presentation can end — hit, or run out — so the level's length is
# counted in one place.
#
# The tutorial is not a level and must never complete one: the coach stages its own presentations
# and ends its own session. A level-done popup landing mid-lesson pauses the game, and the round the
# coach is waiting on can then never expire — the step hangs until its timeout.
func _end_of_target() -> void:
	if game.tutorial_mode:
		_schedule_next_target()
		return
	_targets_in_round_so_far += 1
	if _targets_in_round_so_far < targets_in_round:
		_schedule_next_target()
		return
	# End of a round.
	_targets_in_round_so_far = 0
	_rounds_in_level += 1
	if _rounds_in_level >= rounds_per_level:
		_level_done(true)
		return
	# A breather between rounds, and the one place `num_rounds` is visible to the player. Without
	# it the value would divide the level into parts nobody can see.
	_waiting_after_round = true
	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	game.show_game_popup(self, "Well done!", "Round %d\nof\nLevel %d\n\ncompleted" % [
		_rounds_in_level, level])

func _on_draw_area_input(event: InputEvent) -> void:
	if not game.level_is_ready or game.level_is_done or game.paused():
		return
	if tutorial_ignore_taps:
		return
	var tap_pos: Vector2 = Vector2.ZERO
	var is_tap: bool = false
	if event is InputEventMouseButton:
		var mbe: InputEventMouseButton = event as InputEventMouseButton
		if mbe.button_index == MOUSE_BUTTON_LEFT and mbe.pressed:
			tap_pos = mbe.position
			is_tap = true
	elif event is InputEventScreenTouch:
		var ste: InputEventScreenTouch = event as InputEventScreenTouch
		if ste.pressed:
			tap_pos = ste.position
			is_tap = true
	if not is_tap:
		return
	if not _round_active:
		return
	_round_was_tapped = true

	# Check decoys first
	for i in range(_decoys.size()):
		var d: Dictionary = _decoys[i]
		if tap_pos.distance_to(d["pos"]) <= target_radius:
			_on_decoy_hit(tap_pos, i)
			return

	# Check real target
	if _target_active:
		var dist: float = tap_pos.distance_to(_target_pos)
		if dist <= target_radius:
			_on_hit(tap_pos, dist)
		else:
			_on_miss_tap(tap_pos)
	# Tapping empty space in a no-real round: no penalty

func _on_hit(tap_pos: Vector2, dist: float) -> void:
	var reaction_ms: int = int(game.game_time - _round_shown_time_ms)
	_reaction_times.append(reaction_ms)
	_accuracies.append(int(dist))
	while _reaction_times.size() > 20:
		_reaction_times.remove_at(0)
		_accuracies.remove_at(0)
	var score_bonus: int = max(1, 20 - reaction_ms / 200)
	game.add_score_and_time(score_bonus, 10)
	_pop_at(tap_pos, score_bonus)
	game.add_correct_or_mistake(1, 0)
	num_corrects_in_level_so_far += 1
	_flash_at(tap_pos, Color(0.2, 0.9, 0.3, 0.6))
	_target_active = false
	_round_active = false
	_decoys.clear()
	game.play_sound("hit")
	game.tutorial_notify("hit_target")
	_draw_area.queue_redraw()
	_end_of_target()

func _on_decoy_hit(tap_pos: Vector2, decoy_idx: int) -> void:
	_decoys.remove_at(decoy_idx)
	game.add_score_and_time(-5, -5)
	_pop_at(tap_pos, -5)
	game.add_correct_or_mistake(0, 1)
	_flash_at(tap_pos, Color(0.9, 0.2, 0.2, 0.5))
	game.tutorial_notify("hit_decoy")
	_draw_area.queue_redraw()

func _on_miss_tap(tap_pos: Vector2) -> void:
	game.add_score_and_time(-3, -3)
	_pop_at(tap_pos, -3)
	game.add_correct_or_mistake(0, 1)
	_flash_at(tap_pos, Color(0.9, 0.2, 0.2, 0.5))
	_draw_area.queue_redraw()

# `delta` is +ve for a gain and -ve for a loss; the sign picks the wording and the color.
func _pop_at(pos: Vector2, delta: int) -> void:
	if delta == 0:
		return
	_pops.append({
		"pos": pos,
		"text": ("+%d" % delta) if delta > 0 else str(delta),
		"color": Color(0.25, 0.9, 0.35, 1.0) if delta > 0 else Color(1.0, 0.35, 0.3, 1.0),
		"age": 0.0,
	})

func _flash_at(pos: Vector2, color: Color) -> void:
	_flash_color = color
	_flash_alpha = 1.0
	_flash_pos = pos

func _level_done(didwin: bool) -> void:
	game.level_is_done = true
	# The gate is decided BEFORE the level's score row is written: main.gd saves that row on
	# game.sig_level_is_done, and it has to carry the score the player actually KEEPS, or
	# failing the same level over and over is a way to farm the score list.
	#
	# Passing is a RESULT, not a formality: below this level's accuracy the SAME level comes
	# round again. The bar is the level's own, chosen to land exactly on a rung of `rounds` (see
	# level_config.gd) rather than on a formula that mostly does not.
	var need: int = WhackLevelConfig.pass_pct_for(level)
	var pct: int = game.session_pct_correct()
	var passed: bool = true
	if didwin and level < max_difficulty:
		passed = pct >= need
		_rollback_score_on_next_level = not passed
	if passed:
		game.sig_level_is_done.emit(didwin)
	else:
		# The kept value is put in place just for the save. The SCREEN keeps showing the score
		# the player had while playing, because watching it drop out from under a summary you
		# are still reading is alarming; the visible rollback lands on Continue, in new_game().
		var earned_this_level: int = game.score
		game.score = _score_at_level_start
		game.sig_level_is_done.emit(didwin)
		game.score = earned_this_level
	if didwin:
		# No fanfare for a level that was not passed.
		MainGlobals.global_level_is_done(passed)
		if level >= max_difficulty:
			sig_level_is_done.emit(true)
		else:
			game.need_to_increase_level = passed
			if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
				MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
			var avg_ms: int = mean_reaction_ms()
			var avg_dist: int = mean_distance_px()
			var textadd = "\n\nAvg reaction: %d ms\nAvg distance: %d px\nAccuracy: %d%%\n\n%s" % [avg_ms, avg_dist, pct, _progress_line(passed, need)]
			game.show_level_done_popup(self, "", "", level, textadd, passed)
	else:
		sig_level_is_done.emit(false)

func _on_level_done_popup_closed() -> void:
	sig_level_is_done.emit(true)

func _on_time_over() -> void:
	_target_active = false
	_round_active = false
	_decoys.clear()
	_draw_area.queue_redraw()

func tick() -> void:
	pass

# --- what the coach needs to point at -------------------------------------------------------
#
# Targets are drawn by draw_area.gd in ITS local space, so every rect is converted to screen space
# before being handed to the tutorial overlay.

func _tutorial_rect_at(pos: Vector2) -> Rect2:
	var r: float = target_radius + 11.0     # circle edge plus the countdown arc
	var top_left: Vector2 = _draw_area.get_global_transform() * (pos - Vector2(r, r))
	return Rect2(top_left, Vector2(r * 2.0, r * 2.0))

func tutorial_has_real() -> bool:
	return _target_active

# The real target, or null when this round has none — a Callable spot returning null simply draws
# no spotlight, which is what the "there is nothing to hit" step wants.
func tutorial_target_rect():
	if not _target_active:
		return null
	return _tutorial_rect_at(_target_pos)

func tutorial_decoy_count() -> int:
	return _decoys.size()

func tutorial_decoy_rect(idx: int):
	if idx < 0 or idx >= _decoys.size():
		return null
	return _tutorial_rect_at(_decoys[idx]["pos"])

# The window this round actually runs for: the level's, unless the coach overrode it.
func _round_window() -> float:
	return _round_show_ms if _round_show_ms > 0.0 else show_target_ms

func get_draw_state() -> Dictionary:
	var age: float = 0.0
	if _round_active and _round_window() > 0.0:
		age = clamp((game.game_time - _round_shown_time_ms) / _round_window(), 0.0, 1.0)

	var targets: Array = []
	if _target_active:
		targets.append({
			"pos": _target_pos,
			"radius": target_radius,
			"color": _target_color,
			"age": age,
			"draw_dot": true,
		})
	for d in _decoys:
		targets.append({
			"pos": d["pos"],
			"radius": target_radius,
			"color": d["color"],
			"age": age,
			"draw_dot": d["draw_dot"],
		})

	return {
		"pops": _pops,
		"targets": targets,
		"target_radius": target_radius,
		"flash_color": _flash_color,
		"flash_alpha": _flash_alpha,
		"flash_pos": _flash_pos,
	}

# The speed the player is measured on. Only a HIT appends to `_reaction_times`, which is what keeps
# this honest: a round with no real target in it is one the player is supposed to leave alone, and
# folding it in would enter the full show time as a reaction — by definition the worst possible one
# — for doing exactly the right thing. A missed real target is left out for the same reason.
#
# The accuracy gate counts those rounds (correctly ignoring one IS a correct answer); the speed
# average does not.
func mean_reaction_ms(exclude_last: bool = false) -> int:
	if _reaction_times.size() == 0:
		return 9999
	var data: Array = _reaction_times
	if exclude_last and data.size() > 1:
		data = data.slice(0, data.size() - 1)
	var s: int = 0
	for t in data:
		s += t
	return int(float(s) / float(data.size()))

func mean_distance_px(exclude_last: bool = false) -> int:
	if _accuracies.size() == 0:
		return 0
	var data: Array = _accuracies
	if exclude_last and data.size() > 1:
		data = data.slice(0, data.size() - 1)
	var s: int = 0
	for a in data:
		s += a
	return int(float(s) / float(data.size()))

# What the player gets next, in words. An accuracy figure alone does not say whether they are
# moving on, which is the only thing they want to know at that moment.
func _progress_line(passed: bool, need: int) -> String:
	if not passed:
		return "You need at least %d%% accuracy to pass to the next level." % need
	return "Level passed — on to level %d." % (level + 1)
