extends CanvasLayer

# TIP THE SCALES: a weigh-house logic puzzle (from Mor's desktop "Scales", mor/einstein/), made for a
# phone. See tipscales/docs/design.md.
#
# The screen, top to bottom:
#   THE BOARD      the crates: a row per color, a column per letter. Each crate's paper tag shows the
#                  weights it may still have, or its weight once settled.
#   THE WORKBENCH  the crate being worked on, and its weights as big iron weights: tap one to cross it
#                  out (or back), long-press one to settle the crate on it. Idle, it shows the puzzle's
#                  progress and the Hint button. (Mor's version did all this with right- and left-clicks
#                  on 18-px numbers inside the crate: no use on a phone.)
#   THE MESSAGE    what just happened: a refused move, a hint's reasoning.
#   THE TICKETS    the scale clues, two to a row, scrolling. Tapping one shows its crates on the board
#                  (Mor's hover frames); its check sets it aside, to the end of the list. While a crate is
#                  selected only the tickets naming it are listed -- most of the scrolling is gone. A
#                  ticket whose crates are all settled is SETTLED and moves down by itself.
#
# CROSSING OUT IS FREE: nothing is checked as it is done (see _toggle_cross). A crate down to one weight
# gets its plate unchecked; a mistake is counted only when one shows (a crate with nothing left, scales
# that do not balance once every crate is plated, or Hint putting a weight back).
#
# A level is a few short puzzles (TipscalesLevelConfig); each is generated on a worker thread, the next
# one while the current one is played.

const PUZZLE: Script = preload("res://tipscales/scripts/puzzle.gd")
const ART: Script = preload("res://tipscales/scripts/scales_art.gd")
const BG_SHADER: Shader = preload("res://tipscales/scripts/weighhouse.gdshader")

signal sig_level_is_done(didwin: bool)
signal started_playing

const LONG_PRESS_MS: float = 450.0
const RING_AFTER_MS: float = 200.0
const BENCH_RULE: float = 17.5        # the workbench's inner gold rule, in from its edge (leather.gdshader)
const TAP_SLOP: float = 12.0
const POINTS_CRATE: int = 1
const POINTS_PUZZLE: int = 10
const POINTS_CLEAN: int = 5
const COST_MISTAKE: int = 2
const COST_HINT: int = 3
const NEXT_PUZZLE_S: float = 2.6

var game: GenericGameUtil
var current_level_id: int = 1
var _cfg: Dictionary = {}

# --- the puzzle ---
var puzzle = null
var _next = null
var _gen_task: int = -1
var _gen_puzzle = null
var crossed: PackedInt32Array = PackedInt32Array()    # per crate: weights crossed out (by the player or a hint)
var placed: PackedInt32Array = PackedInt32Array()     # per crate: its settled weight, 0 if not yet
var selected: int = -1
var focus: int = -1
var aside: Array = []                                 # clue indices set aside, in the order set aside
var _solved: bool = false

# --- stats ---
var puzzle_mistakes: int = 0
var puzzle_hints: int = 0
var _puzzle_t0: float = 0.0
var puzzles_done: int = 0
var clean_done: int = 0
var puzzle_times_ms: Array = []

# --- view ---
var _bg: ColorRect = null
var _view: Control = null
var _tickets: Control = null
var _font: Font = null
var _serif: Font = null
var _text_font: Font = null
var _w: float = 680.0
var _h: float = 788.0
var _board_rect: Rect2 = Rect2()
var _cell: Vector2 = Vector2.ZERO
var _gap: float = 8.0
var _bench_rect: Rect2 = Rect2()
var _msg_rect: Rect2 = Rect2()
var _head_rect: Rect2 = Rect2()
var _tick_rect: Rect2 = Rect2()
var _card: Vector2 = Vector2(316.0, 130.0)
var _scroll: float = 0.0
var _scroll_v: float = 0.0
var _msg: String = ""
var _msg_col: Color = Color(0.95, 0.90, 0.80)
var _msg_until: float = 0.0       # ms; the message fades out over its last MSG_FADE_MS
# A MESSAGE IS FOR NOW: it fades after a few seconds, and the player's next good move clears it at
# once. One that stayed ("Not so fast...") read as still true after the crate was settled (the user).
const MSG_FADE_MS: float = 600.0
const MSG_INFO_MS: float = 3500.0
const MSG_MISTAKE_MS: float = 5000.0
const MSG_HINT_MS: float = 9000.0
var _pops: Dictionary = {}        # crate -> time (ms) it was settled (a pop)
var _hint_rings: Dictionary = {}  # crate -> until (ms)
var _swing_t0: float = -1.0       # the win: every ticket's beam swings and settles
var _waiting: bool = false        # the next puzzle is still being generated
var _wait_t0: float = 0.0

# --- input ---
var _press_pos: Vector2 = Vector2.ZERO
var _press_on: String = ""        # "weight", "tickets", "" (none)
var _press_v: int = 0
var _press_t: float = 0.0
var _press_fired: bool = false
var _dragging: bool = false
var _drag_last: float = 0.0

func _ready() -> void:
	game = TipscalesG.game
	# devtools/make_tipscales_sounds.py
	game.add_sound(self, "pick", preload("res://art/sounds/tipscales_pick.ogg"))
	game.add_sound(self, "thud", preload("res://art/sounds/tipscales_settle.ogg"))
	game.add_sound(self, "wrong", preload("res://art/sounds/tipscales_wrong.ogg"))
	game.add_sound(self, "solved", preload("res://art/sounds/tipscales_solved.ogg"))
	game.add_sound(self, "tick", preload("res://art/sounds/tipscales_chalk.ogg"))
	game.add_sound(self, "hint", preload("res://art/sounds/tipscales_hint.ogg"))
	game.set_sound_volume("tick", -4.0)
	_build()
	set_process(true)

func _build() -> void:
	_font = ThemeDB.fallback_font
	_serif = load("res://art/fonts/NotoSerif-Bold.ttf")
	_text_font = MainGlobals.get_text_font()
	_bg = ColorRect.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = BG_SHADER
	_bg.material = m
	add_child(_bg)
	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_view_input)
	add_child(_view)
	_tickets = Control.new()
	_tickets.clip_contents = true
	_tickets.mouse_filter = Control.MOUSE_FILTER_STOP
	_tickets.draw.connect(_draw_tickets)
	# the baked materials are drawn smaller than they were rendered: sample them through their mipmaps
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_tickets.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_tickets.gui_input.connect(_on_tickets_input)
	add_child(_tickets)

func _exit_tree() -> void:
	if _gen_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_gen_task)
		_gen_task = -1

# --- the level ----------------------------------------------------------------------------------------

const TUTORIAL_SEED: int = 4213
var _tutorial_gen: int = 0

# --- where the tutorial points (screen space; empty while there is no puzzle) ---
func tutorial_board_rect() -> Rect2:
	return _board_rect.grow(6.0) if puzzle != null else Rect2()

func tutorial_ticket_rect(k: int) -> Rect2:
	if puzzle == null or ticket_order().size() <= k:
		return Rect2()
	return Rect2(_tick_rect.position + _card_rect(k).position, _card)

func tutorial_focus_crates_rect() -> Rect2:
	if puzzle == null or focus < 0:
		return Rect2()
	var r: Rect2 = Rect2()
	var first: bool = true
	for c in puzzle.clues[focus]["c"]:
		r = crate_rect(c) if first else r.merge(crate_rect(c))
		first = false
	return r

func tutorial_bench_rect() -> Rect2:
	return _bench_rect if puzzle != null else Rect2()

func tutorial_hint_rect() -> Rect2:
	return _hint_rect() if puzzle != null and selected < 0 else _bench_close_rect()

func new_game(from_scratch: bool = true) -> void:
	game.level_is_done = false
	game.level_is_ready = false
	if from_scratch:
		current_level_id = TipscalesG.starting_level_id
	elif game.need_to_increase_level:
		current_level_id = mini(current_level_id + 1, TipscalesLevelConfig.max_level())
	game.need_to_increase_level = false
	game.corrects = 0
	game.mistakes = 0
	_cfg = TipscalesLevelConfig.TUTORIAL if game.tutorial_mode else TipscalesLevelConfig.get_level(current_level_id)
	# short in the HUD strip ("7 · Weighmaster": its box is 200 wide and "Level 7: Weighmaster" ran off
	# its left edge); the briefing card has the full title
	game.level_label_changed("Tutorial" if game.tutorial_mode else "%d · %s" % [current_level_id, str(_cfg.get("name", ""))])
	puzzles_done = 0
	clean_done = 0
	_tutorial_gen = 0
	puzzle_times_ms.clear()
	puzzle = null
	_next = null
	_solved = false
	_layout()
	_start_generating()
	if game.tutorial_mode:
		_on_game_popup_closed()
		return
	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	var facts: String = "Colors: %d\nCrates per color: %d (1 to %d kg)\nPuzzles: %d" % [
		int(_cfg["colors"]), int(_cfg["crates"]), int(_cfg["crates"]), int(_cfg["puzzles"])]
	game.show_game_popup(self, TipscalesLevelConfig.level_title(current_level_id), facts)

func _on_game_popup_closed() -> void:
	if not game.level_is_done and not game.level_is_ready:
		game.level_is_ready = true
		started_playing.emit()
		_begin_puzzle()

func stop_level() -> void:
	selected = -1
	focus = -1
	_view.queue_redraw()

func _start_generating() -> void:
	if _gen_task >= 0 or _next != null:
		return
	# the tutorial's puzzles are fixed (seeded), so the coach always meets the same board
	var seed_i: int = (TUTORIAL_SEED + _tutorial_gen) if game.tutorial_mode else -1
	if game.tutorial_mode:
		_tutorial_gen += 1
	var p = PUZZLE.new(int(_cfg["colors"]), int(_cfg["crates"]), seed_i)
	_gen_puzzle = p
	var cfg: Dictionary = _cfg.duplicate()
	_gen_task = WorkerThreadPool.add_task(func() -> void:
		p.generate(cfg["mix"], int(cfg["spare"]), int(cfg["k_max"]), int(cfg["tries"])))

func _poll_generation() -> void:
	if _gen_task < 0 or not WorkerThreadPool.is_task_completed(_gen_task):
		return
	WorkerThreadPool.wait_for_task_completion(_gen_task)
	_gen_task = -1
	_next = _gen_puzzle
	_gen_puzzle = null
	if _waiting:
		_waiting = false
		_begin_puzzle()

func _begin_puzzle() -> void:
	if _next == null:
		# THE CRATES ARE STILL BEING STACKED: a big puzzle takes a noticeable while to generate (seconds on a
		# phone at level 7), so a card says so over the board (_draw_waiting) rather than a line of text
		_waiting = true
		_wait_t0 = Time.get_ticks_msec()
		_msg = ""
		_view.queue_redraw()
		return
	puzzle = _next
	_next = null
	var n: int = puzzle.n_crates()
	crossed = PackedInt32Array()
	crossed.resize(n)
	crossed.fill(0)
	placed = PackedInt32Array()
	placed.resize(n)
	placed.fill(0)
	selected = -1
	focus = -1
	aside.clear()
	_pops.clear()
	_hint_rings.clear()
	_flagged_empty.clear()
	_wrong_flagged = false
	_card_at.clear()
	_press_card.clear()
	_aside_pending.clear()
	_scroll = 0.0
	_scroll_v = 0.0
	_swing_t0 = -1.0
	_solved = false
	puzzle_mistakes = 0
	puzzle_hints = 0
	_puzzle_t0 = game.game_time
	_layout()
	_say("Puzzle %d of %d. Tap a crate to work on it." % [puzzles_done + 1, int(_cfg["puzzles"])])
	game.play_sound("thud")
	if puzzles_done + 1 < int(_cfg["puzzles"]) or game.tutorial_mode:
		_start_generating()
	_redraw()

func _puzzle_solved() -> void:
	_solved = true
	game.tutorial_notify("solved")
	selected = -1
	focus = -1
	var took: float = game.game_time - _puzzle_t0
	puzzle_times_ms.append(int(took))
	puzzles_done += 1
	var clean: bool = puzzle_mistakes <= TipscalesLevelConfig.CLEAN_MISTAKES and puzzle_hints == 0
	if clean:
		clean_done += 1
	# the crates count when the puzzle balances (a plate alone is unchecked, so it scores nothing)
	game.add_score_and_time(POINTS_PUZZLE + POINTS_CRATE * puzzle.n_crates() + (POINTS_CLEAN if clean else 0), 0)
	game.add_correct_or_mistake(puzzle.n_crates(), 0)
	game.record_count("puzzles_solved")
	game.play_sound("solved")
	_swing_t0 = Time.get_ticks_msec()
	var secs: int = int(took / 1000.0)
	_say("Balanced! Solved in %d:%02d, %d mistake%s%s." % [secs / 60, secs % 60, puzzle_mistakes,
		"" if puzzle_mistakes == 1 else "s", (", %d hint%s" % [puzzle_hints, "" if puzzle_hints == 1 else "s"]) if puzzle_hints > 0 else ""],
		Color(0.70, 1.0, 0.70), NEXT_PUZZLE_S * 1000.0 + 400.0)
	_redraw()
	var lvl_id: int = current_level_id
	await get_tree().create_timer(NEXT_PUZZLE_S).timeout
	if not is_inside_tree() or lvl_id != current_level_id or game.level_is_done or not game.playing:
		return
	if puzzles_done >= int(_cfg["puzzles"]) and not game.tutorial_mode:
		_level_done()
	else:
		_begin_puzzle()

func _level_done() -> void:
	if game.level_is_done:
		return
	game.level_is_done = true
	game.sig_level_is_done.emit(true)
	var pct: int = pct_clean()
	var need: int = int(_cfg.get("pass_pct", 66))
	var passed: bool = pct >= need
	MainGlobals.global_level_is_done(passed)
	if current_level_id >= TipscalesLevelConfig.max_level():
		game.need_to_increase_level = false
	else:
		game.need_to_increase_level = passed
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	var extra: String = "\n\nSolved cleanly: %d of %d\n(at most %d mistake%s and no hint)\n\n%s" % [
		clean_done, puzzles_done, TipscalesLevelConfig.CLEAN_MISTAKES,
		"" if TipscalesLevelConfig.CLEAN_MISTAKES == 1 else "s",
		("Level passed. On to level %d." % (current_level_id + 1)) if passed and current_level_id < TipscalesLevelConfig.max_level()
			else ("The last level: well weighed." if passed else "Solve at least %d%% of the puzzles cleanly to move on." % need)]
	game.show_level_done_popup(self, "", "", current_level_id, extra, passed)

func _on_level_done_popup_closed() -> void:
	sig_level_is_done.emit(true)

func mean_puzzle_time_s() -> int:
	if puzzle_times_ms.is_empty():
		return 0
	var s: float = 0.0
	for t in puzzle_times_ms:
		s += float(t)
	return roundi(s / float(puzzle_times_ms.size()) / 1000.0)

func pct_clean() -> int:
	if puzzles_done == 0:
		return 0
	return roundi(100.0 * float(clean_done) / float(puzzles_done))

# --- the rules ------------------------------------------------------------------------------------------

func _cols() -> int:
	return puzzle.cols if puzzle != null else int(_cfg.get("crates", 4))

func _rows() -> int:
	return puzzle.rows if puzzle != null else int(_cfg.get("colors", 2))

func _full() -> int:
	return (1 << _cols()) - 1

# weights another crate of i's color has settled on
func _taken(i: int) -> int:
	var m: int = 0
	var r: int = i / _cols()
	for c in _cols():
		var j: int = r * _cols() + c
		if j != i and placed[j] > 0:
			m |= PUZZLE.bit(placed[j])
	return m

func open_mask(i: int) -> int:
	if placed[i] > 0:
		return PUZZLE.bit(placed[i])
	return _full() & ~crossed[i] & ~_taken(i)

func _name(i: int) -> String:
	return ART.crate_name(i / _cols(), i % _cols())

func _can_play() -> bool:
	return puzzle != null and not _solved and game.playing and not game.paused() and game.level_is_ready \
		and not game.level_is_done

# CROSSING OUT IS FREE (the user, 2026-11-16). It used to be the Einstein game's rule -- the true weight
# could not be crossed out, the refusal counted as a mistake -- and every refusal TOLD the player that
# weight was the crate's: "a huge hint". Now nothing is checked as it is done. A crate down to one weight
# gets its plate unchecked (_recompute), and a weight rubbed off can be tapped back, which takes the plate
# off again. A mistake is counted only when one SHOWS: a crate left with no weight at all, every crate
# plated but the scales not balancing, or Hint having to put a rubbed-off weight back -- Hint fixes such
# an error before it gives any step.
func _toggle_cross(i: int, v: int) -> void:
	var b: int = PUZZLE.bit(v)
	if crossed[i] & b:
		crossed[i] &= ~b
	elif placed[i] == v:
		_say("To change %s, tap a rubbed-off weight back." % _name(i))
		return
	elif _taken(i) & b:
		_say("Another %s crate has %d kg." % [ART.SET_NAMES[i / _cols()].to_lower(), v])
		return
	else:
		crossed[i] |= b
		game.tutorial_notify("crossed")
	game.play_sound("tick")
	_clear_message()
	_recompute()
	_redraw()

# a long press: this crate weighs v -- every other weight rubbed off (unchecked, like any other move)
func _try_settle(i: int, v: int) -> void:
	if placed[i] == v:
		return
	if _taken(i) & PUZZLE.bit(v):
		_say("Another %s crate has %d kg." % [ART.SET_NAMES[i / _cols()].to_lower(), v])
		return
	crossed[i] = _full() & ~PUZZLE.bit(v)
	game.tutorial_notify("crossed")
	_clear_message()
	_recompute()
	_redraw()

var _flagged_empty: Dictionary = {}     # crates already counted as left with no weight
var _wrong_flagged: bool = false        # "the scales don't balance" already counted

# THE PLATES, from the slates: a crate whose weights are down to one is plated, and its weight leaves the
# rest of its color -- which can leave another with one, so round again. Derived afresh after every move,
# so tapping a weight back takes plates off as surely as rubbing one off puts them on.
func _recompute() -> void:
	var before: PackedInt32Array = placed.duplicate()
	placed.fill(0)
	var again: bool = true
	while again:
		again = false
		for i in puzzle.n_crates():
			if placed[i] == 0:
				var v: int = PUZZLE.single_value(_full() & ~crossed[i] & ~_taken(i))
				if v > 0:
					placed[i] = v
					again = true
	var plated_now: bool = false
	for i in puzzle.n_crates():
		if placed[i] > 0 and before[i] != placed[i]:
			_pops[i] = Time.get_ticks_msec()
			plated_now = true
	if plated_now:
		game.play_sound("thud")
	# a crate with nothing left: one of its rubbed-off weights was right
	for i in puzzle.n_crates():
		var empty: bool = placed[i] == 0 and open_mask(i) == 0
		if empty and not _flagged_empty.has(i):
			_flagged_empty[i] = true
			_mistake("%s has no weight left: one of the weights rubbed off it was right." % _name(i))
		elif not empty:
			_flagged_empty.erase(i)
	var all: bool = true
	var right: bool = true
	for i in puzzle.n_crates():
		if placed[i] == 0:
			all = false
		elif placed[i] != puzzle.answer[i]:
			right = false
	if not all:
		_wrong_flagged = false
	elif right:
		if not _solved:
			_puzzle_solved()
	elif not _wrong_flagged:
		_wrong_flagged = true
		_mistake("Every crate has a weight, but the scales don't balance: a weight rubbed off somewhere was right. Tap weights back, or use Hint.")

func _mistake(text: String) -> void:
	puzzle_mistakes += 1
	game.add_score_and_time(-COST_MISTAKE, 0)
	game.add_correct_or_mistake(0, 1)
	game.record_count("mistakes")
	game.play_sound("wrong")
	_say(text, Color(1.0, 0.55, 0.45), MSG_MISTAKE_MS)
	_redraw()

func _is_settled_clue(ci: int) -> bool:
	for c in puzzle.clues[ci]["c"]:
		if placed[c] == 0:
			return false
	return true

func live_clues() -> Array:
	var out: Array = []
	for ci in puzzle.clues.size():
		if not aside.has(ci) and not _is_settled_clue(ci):
			out.append(ci)
	return out

# The tickets in the order shown: live ones in their own order, then the settled, then those set aside
# (in the order they were); only those naming the selected crate while one is selected.
func ticket_order() -> Array:
	if puzzle == null:
		return []
	var live: Array = []
	var done: Array = []
	for ci in puzzle.clues.size():
		if selected >= 0 and not (puzzle.clues[ci]["c"] as Array).has(selected):
			continue
		if aside.has(ci):
			continue
		if _is_settled_clue(ci):
			done.append(ci)
		else:
			live.append(ci)
	var out: Array = live + done
	for ci in aside:
		if selected < 0 or (puzzle.clues[ci]["c"] as Array).has(selected):
			out.append(ci)
	return out

func hint() -> void:
	if not _can_play():
		return
	var now: float = Time.get_ticks_msec()
	# AN ERROR FIRST: a weight rubbed off that the crate really has is put back, and that is a mistake
	for i in puzzle.n_crates():
		var tb: int = PUZZLE.bit(puzzle.answer[i])
		if crossed[i] & tb:
			_count_hint()
			crossed[i] &= ~tb
			_hint_rings[i] = now + 2600.0
			_recompute()
			_mistake("Hint: %s can still weigh %d kg -- nothing rules that out. It was rubbed off by mistake." % [_name(i), puzzle.answer[i]])
			return
	var masks: PackedInt32Array = PackedInt32Array()
	masks.resize(puzzle.n_crates())
	for i in puzzle.n_crates():
		masks[i] = open_mask(i)
	var st: Dictionary = puzzle.next_step(masks, live_clues())
	if st.is_empty():
		return
	_count_hint()
	var text: String = ""
	if st["kind"] == "row":
		for i in st["place"].keys():
			var v: int = int(st["place"][i])
			text = "%s must be %d kg: no other %s crate can still weigh %d." % [_name(i), v,
				ART.SET_NAMES[i / _cols()].to_lower(), v]
			_hint_rings[i] = now + 2200.0
			crossed[i] = _full() & ~PUZZLE.bit(v)
	else:
		var ci: int = int(st["clue"])
		focus = ci
		var parts: Array = []
		for i in st["remove"].keys():
			crossed[i] |= int(st["remove"][i])
			_hint_rings[i] = now + 2200.0
			parts.append("%s can't be %s" % [_name(i), _list_weights(int(st["remove"][i]))])
		text = "From %s: %s." % [ART.caption(puzzle.clues[ci], _cols()), "; ".join(parts)]
		_scroll_to_clue(ci)
	_recompute()
	if not _solved:
		_say(text, Color(1.0, 0.86, 0.50), MSG_HINT_MS)
	_redraw()

func _count_hint() -> void:
	puzzle_hints += 1
	game.tutorial_notify("hinted")
	game.play_sound("hint")
	game.add_score_and_time(-COST_HINT, 0)
	game.record_count("hints")

func _list_weights(m: int) -> String:
	var vs: Array = []
	for v in range(1, _cols() + 1):
		if m & PUZZLE.bit(v):
			vs.append(str(v))
	if vs.size() == 1:
		return vs[0] + " kg"
	return ", ".join(vs.slice(0, vs.size() - 1)) + " or " + vs[-1] + " kg"

func _say(text: String, col: Color = Color(0.95, 0.90, 0.80), ms: float = MSG_INFO_MS) -> void:
	_msg = text
	_msg_col = col
	_msg_until = Time.get_ticks_msec() + ms
	if _view != null:
		_view.queue_redraw()

func _clear_message() -> void:
	if _msg != "" and not _waiting and not _solved:
		_msg_until = minf(_msg_until, Time.get_ticks_msec() + MSG_FADE_MS * 0.5)

func _redraw() -> void:
	if _view != null:
		_view.queue_redraw()
	if _tickets != null:
		_tickets.queue_redraw()

# --- the materials, rendered once ----------------------------------------------------------------------
# Wood, paint, slate, paper and leather are shaders (crate.gdshader, paper.gdshader, leather.gdshader)
# rendered ONCE into textures whenever the layout's sizes change, at twice the size for a sharp result on
# a larger window; then every frame only draws textures (memory note: per-frame noise shaders cost a
# phone its frame rate). Until they are ready the drawings fall back to plain colors.
const CRATE_SHADER: Shader = preload("res://tipscales/scripts/crate.gdshader")
const PAPER_SHADER: Shader = preload("res://tipscales/scripts/paper.gdshader")
const LEATHER_SHADER: Shader = preload("res://tipscales/scripts/leather.gdshader")
const BAKE_SCALE: float = 2.0
var _tex_crates: Array = []      # [row * 2 + variant]
var _tex_paper: Array = []
var _tex_leather: Texture2D = null
var _baked_key: String = ""
var _baking: bool = false

func _crate_tex(i: int) -> Texture2D:
	var k: int = (i / _cols()) * 2 + ((i % _cols()) % 2)
	return _tex_crates[k] if k < _tex_crates.size() else null

func _bake_materials() -> void:
	var key: String = "%d %d %d %d %d %d" % [int(_cell.x), int(_cell.y), _rows(), int(_card.x), int(_card.y), int(_bench_rect.size.y)]
	if key == _baked_key or _baking or not is_inside_tree():
		return
	_baking = true
	_baked_key = key
	var crates: Array = []
	for r in _rows():
		for variant in 2:
			crates.append(await _bake(CRATE_SHADER, _cell, {"paint": ART.set_color(r), "seed": float(r * 7 + variant * 3 + 1)}))
	var papers: Array = []
	for k in 3:
		papers.append(await _bake(PAPER_SHADER, _card, {"seed": float(k * 5 + 2)}))
	var leather: Texture2D = await _bake(LEATHER_SHADER, _bench_rect.size, {})
	_tex_crates = crates
	_tex_paper = papers
	_tex_leather = leather
	_baking = false
	_redraw()
	if key != _baked_key:
		_bake_materials()

func _bake(shader: Shader, sz: Vector2, params: Dictionary) -> Texture2D:
	var px: Vector2i = Vector2i(maxi(4, int(sz.x * BAKE_SCALE)), maxi(4, int(sz.y * BAKE_SCALE)))
	var vp: SubViewport = SubViewport.new()
	vp.size = px
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cr: ColorRect = ColorRect.new()
	cr.size = Vector2(px)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("size", sz)
	for k in params.keys():
		m.set_shader_parameter(k, params[k])
	cr.material = m
	vp.add_child(cr)
	add_child(vp)
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	if img == null:
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# --- layout ---------------------------------------------------------------------------------------------

func _layout() -> void:
	_w = float(MainGlobals.screen_size.x)
	_h = float(MainGlobals.screen_size.y)
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	_bg.position = Vector2.ZERO
	_bg.size = full
	(_bg.material as ShaderMaterial).set_shader_parameter("size", full)
	_view.position = Vector2.ZERO
	_view.size = full
	var mobile: bool = MainGlobals.is_mobile()
	var top: float = 64.0
	var side: float = 14.0
	var rows: int = _rows()
	var cols: int = _cols()
	_gap = 8.0 if cols >= 6 else 10.0
	var head: float = 22.0
	var cw: float = (_w - side * 2.0 - _gap * float(cols - 1)) / float(cols)
	cw = minf(cw, 128.0)
	var ch: float = cw * 0.80
	var bench_h: float = 112.0 if mobile else 82.0
	var msg_h: float = 70.0 if mobile else 34.0
	# at least this much of the tickets shows; on the short desktop canvas the board comes first
	var tick_min: float = (2.2 if mobile else 1.0) * (_card_h() + 10.0) + 20.0
	var foot: float = float(MainGlobals.full_screen_size.y) - (92.0 if mobile else 50.0)
	var board_max: float = foot - top - 22.0 - 12.0 - bench_h - 4.0 - msg_h - 28.0 - tick_min
	var need: float = head + float(rows) * ch + float(rows - 1) * _gap
	if need > board_max:
		ch = maxf(36.0, (board_max - head - float(rows - 1) * _gap) / float(rows))
	_cell = Vector2(cw, ch)
	var bw: float = float(cols) * cw + float(cols - 1) * _gap
	_board_rect = Rect2((_w - bw) * 0.5, top + head, bw, float(rows) * ch + float(rows - 1) * _gap)
	var y: float = _board_rect.end.y + 12.0
	_bench_rect = Rect2(side, y, _w - side * 2.0, bench_h)
	y = _bench_rect.end.y + 4.0
	_msg_rect = Rect2(side, y, _w - side * 2.0, msg_h)
	y = _msg_rect.end.y
	_head_rect = Rect2(side, y, _w - side * 2.0, 40.0 if mobile else 30.0)
	y = _head_rect.end.y + 2.0
	# the tickets stop above the app's button bar (it sits over the screen's foot)
	_tick_rect = Rect2(0.0, y, _w, foot - y)
	_tickets.position = _tick_rect.position
	_tickets.size = _tick_rect.size
	_card = Vector2((_w - side * 2.0 - 10.0 * float(_ticket_cols() - 1)) / float(_ticket_cols()), _card_h())
	var bgm: ShaderMaterial = _bg.material as ShaderMaterial
	bgm.set_shader_parameter("board", Vector4(_board_rect.position.x, _board_rect.position.y, _board_rect.size.x, _board_rect.size.y))
	bgm.set_shader_parameter("rows", float(rows))
	bgm.set_shader_parameter("pitch", _cell.y + _gap)
	bgm.set_shader_parameter("cell_h", _cell.y)
	bgm.set_shader_parameter("counter_y", _bench_rect.position.y - 14.0)
	bgm.set_shader_parameter("lamp", Vector2(_w * 0.5, _board_rect.position.y - 10.0))
	_bake_materials()

# TWO PAPERS TO A ROW, on a phone too, but TALLER there: larger crate stamps, and the rule in large type
# wrapped under the engraving. (One to a row, the engraving beside the rule, was tried for readability;
# the user preferred the grid with bigger letters.)
func _card_h() -> float:
	if TipscalesG.show_rules:
		return 196.0 if MainGlobals.is_mobile() else 128.0
	return 168.0 if MainGlobals.is_mobile() else 112.0

func _ticket_cols() -> int:
	return 2

func crate_rect(i: int) -> Rect2:
	var r: int = i / _cols()
	var c: int = i % _cols()
	return Rect2(_board_rect.position + Vector2(float(c) * (_cell.x + _gap), float(r) * (_cell.y + _gap)), _cell)

func _crate_at(p: Vector2) -> int:
	if puzzle == null:
		return -1
	for i in puzzle.n_crates():
		if crate_rect(i).grow(_gap * 0.5).has_point(p):
			return i
	return -1

# the workbench: [crate rect, weight rects..., close rect]
func _bench_weight_rect(v: int) -> Rect2:
	var cols: int = _cols()
	var left: float = _bench_rect.position.x + _bench_rect.size.y * 1.05
	var right: float = _bench_rect.end.x - 40.0
	var slot: float = (right - left) / float(cols)
	var s: float = minf(slot, _bench_rect.size.y)
	return Rect2(left + slot * float(v - 1) + (slot - s) * 0.5, _bench_rect.position.y + (_bench_rect.size.y - s) * 0.5, s, s)

func _bench_close_rect() -> Rect2:
	return Rect2(_bench_rect.end.x - 38.0, _bench_rect.position.y + 4.0, 34.0, 34.0)

func _hint_rect() -> Rect2:
	# inside the workbench's gold rule, like the text beside it
	var hw: float = 140.0 if MainGlobals.is_mobile() else 120.0
	var hh: float = minf(58.0 if MainGlobals.is_mobile() else 50.0, _bench_rect.size.y - (BENCH_RULE + 5.0) * 2.0)
	return Rect2(_bench_rect.end.x - BENCH_RULE - 8.0 - hw, _bench_rect.position.y + (_bench_rect.size.y - hh) * 0.5, hw, hh)

func _card_rect(k: int) -> Rect2:
	return Rect2(_card_list_pos(k) - Vector2(0.0, _scroll), _card)

# a paper's place in the list (before scrolling)
func _card_list_pos(k: int) -> Vector2:
	var side: float = 14.0
	var col: int = k % _ticket_cols()
	var row: int = k / _ticket_cols()
	return Vector2(side + float(col) * (_card.x + 10.0), 4.0 + float(row) * (_card.y + 10.0))

# THE PAPERS MOVE, they do not jump (the user: setting one aside was "too immediate ... you can't really
# tell something happened"). Each paper's drawn place eases toward its place in the list; setting one aside
# first stamps the check and dims it where it lies (ASIDE_HOLD_MS, a small press), and only then does it
# go to the end of the list, the others sliding up after it. A change of WHICH papers are listed (a crate
# selected, a new puzzle) snaps them instead.
const ASIDE_HOLD_MS: float = 420.0
var _card_at: Dictionary = {}       # clue -> its drawn place in the list (Vector2)
var _cards_key: String = ""
var _press_card: Dictionary = {}    # clue -> when its check was pressed (ms)
var _aside_pending: Dictionary = {} # clue -> when it goes to the end of the list (ms)

func _animate_cards(delta: float) -> void:
	if puzzle == null:
		return
	var now: float = Time.get_ticks_msec()
	for ci in _aside_pending.keys():
		if now >= float(_aside_pending[ci]):
			_aside_pending.erase(ci)
			if not aside.has(ci):
				aside.append(ci)
	var key: String = "%d/%d" % [selected, puzzle.clues.size()]
	if key != _cards_key:
		_cards_key = key
		_card_at.clear()
	var order: Array = ticket_order()
	var moving: bool = false
	var k_ease: float = 1.0 - exp(-delta * 9.0)
	for k in order.size():
		var ci: int = order[k]
		var tgt: Vector2 = _card_list_pos(k)
		if not _card_at.has(ci):
			_card_at[ci] = tgt
			continue
		var cur: Vector2 = _card_at[ci]
		if cur.distance_to(tgt) > 0.5:
			_card_at[ci] = cur.lerp(tgt, k_ease)
			moving = true
		else:
			_card_at[ci] = tgt
	for ci in _press_card.keys():
		if now - float(_press_card[ci]) > 400.0:
			_press_card.erase(ci)
		moving = true
	if moving or not _aside_pending.is_empty():
		_tickets.queue_redraw()

func _aside_rect(cr: Rect2) -> Rect2:
	var sz: float = 58.0 if MainGlobals.is_mobile() else 44.0
	return Rect2(cr.end.x - sz - 2.0, cr.position.y + 2.0, sz, sz)

func _max_scroll() -> float:
	var n: int = ticket_order().size()
	var rows_n: int = int(ceil(float(n) / float(_ticket_cols())))
	return maxf(0.0, 8.0 + float(rows_n) * (_card.y + 10.0) - _tick_rect.size.y)

func _scroll_to_clue(ci: int) -> void:
	var k: int = ticket_order().find(ci)
	if k < 0:
		return
	var y: float = 4.0 + float(k / _ticket_cols()) * (_card.y + 10.0)
	if y < _scroll or y + _card.y > _scroll + _tick_rect.size.y:
		_scroll = clampf(y - 6.0, 0.0, _max_scroll())
	_scroll_v = 0.0

# --- per frame ------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_poll_generation()
	_animate_cards(delta)
	var now: float = Time.get_ticks_msec()
	# the long press on a weight settles the crate on it
	if _press_on == "weight" and not _press_fired and now - _press_t >= LONG_PRESS_MS and selected >= 0 and _can_play():
		_press_fired = true
		_try_settle(selected, _press_v)
	# the tickets' fling
	if not _dragging and absf(_scroll_v) > 1.0:
		_scroll = clampf(_scroll + _scroll_v * delta, 0.0, _max_scroll())
		_scroll_v *= pow(0.04, delta)
		_tickets.queue_redraw()
	var anim: bool = false
	for i in _pops.keys():
		if now - float(_pops[i]) < 350.0:
			anim = true
	for i in _hint_rings.keys():
		if now > float(_hint_rings[i]):
			_hint_rings.erase(i)
			anim = true
		else:
			anim = true
	if _press_on == "weight" and not _press_fired:
		anim = true
	if _swing_t0 >= 0.0 and now - _swing_t0 < 2200.0:
		_tickets.queue_redraw()
	if _msg != "" and now < _msg_until + 50.0:
		anim = true
	if anim or _waiting:
		_view.queue_redraw()

# --- drawing --------------------------------------------------------------------------------------------

func _draw_view() -> void:
	if puzzle == null:
		_draw_message()
		_draw_waiting()
		return
	var now: float = Time.get_ticks_msec()
	var cols: int = _cols()
	var focus_crates: Array = puzzle.clues[focus]["c"] if focus >= 0 and focus < puzzle.clues.size() else []
	for i in puzzle.n_crates():
		var ring: int = 0
		if _hint_rings.has(i):
			ring = 3
		elif i == selected:
			ring = 1
		elif focus_crates.has(i):
			ring = 2
		var pop: float = 1.0
		if _pops.has(i):
			var u: float = (now - float(_pops[i])) / 350.0
			if u < 1.0:
				pop = 1.0 + 0.12 * sin(u * PI)
		ART.draw_crate(_view, crate_rect(i), _crate_tex(i), i / cols, i % cols, cols, open_mask(i), crossed[i],
			placed[i], ring, pop, _serif)
	_draw_bench()
	_draw_message()
	_draw_tickets_head()
	_draw_waiting()

# the waiting card: the board dimmed, a paper in the middle, a small brass balance rocking on it
func _draw_waiting() -> void:
	if not _waiting:
		return
	var t: float = (Time.get_ticks_msec() - _wait_t0) / 1000.0
	var fade: float = clampf(t / 0.25, 0.0, 1.0)
	_view.draw_rect(Rect2(Vector2.ZERO, _view.size), Color(0.05, 0.03, 0.02, 0.55 * fade))
	var mob: bool = MainGlobals.is_mobile()
	var cw: float = 400.0 if mob else 340.0
	var ch: float = 220.0 if mob else 180.0
	var ctr: Vector2 = Vector2(_w * 0.5, _board_rect.get_center().y)
	var r: Rect2 = Rect2(ctr - Vector2(cw, ch) * 0.5, Vector2(cw, ch))
	for k in 4:
		_view.draw_rect(Rect2(r.position + Vector2(3, 6), r.size).grow(6.0 - float(k) * 1.5), Color(0, 0, 0, 0.12 * fade))
	if not _tex_paper.is_empty() and _tex_paper[0] != null:
		_view.draw_texture_rect(_tex_paper[0], r, false, Color(1, 1, 1, fade))
	else:
		_view.draw_rect(r, Color(ART.PAPER, fade))
	# the balance, rocking as if a crate were being set on it
	var pivot: Vector2 = Vector2(ctr.x, r.position.y + ch * 0.22)
	var ang: float = deg_to_rad(11.0) * sin(t * 2.6)
	var dir: Vector2 = Vector2(cos(ang), sin(ang))
	var half: float = cw * 0.20
	var ink: Color = Color(ART.INK, 0.9 * fade)
	_view.draw_line(pivot, Vector2(pivot.x, pivot.y + ch * 0.36), ink, 3.0)
	_view.draw_line(Vector2(pivot.x - 22.0, pivot.y + ch * 0.36), Vector2(pivot.x + 22.0, pivot.y + ch * 0.36), ink, 4.0)
	_view.draw_line(pivot - dir * half, pivot + dir * half, ink, 4.0)
	_view.draw_circle(pivot, 5.0, Color(ART.BRASS, fade))
	for side in [-1.0, 1.0]:
		var end: Vector2 = pivot + dir * half * side
		var py: float = end.y + ch * 0.18
		_view.draw_line(end, Vector2(end.x - 18.0, py), Color(ART.INK, 0.5 * fade), 1.2)
		_view.draw_line(end, Vector2(end.x + 18.0, py), Color(ART.INK, 0.5 * fade), 1.2)
		_view.draw_arc(Vector2(end.x, py - 4.0), 22.0, 0.15, PI - 0.15, 12, ink, 3.0)
	var fs: int = 30 if mob else 24
	var title: String = "Stacking the crates" + ".".repeat(1 + int(t * 2.0) % 3)
	var tw: float = _serif.get_string_size("Stacking the crates...", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_view.draw_string(_serif, Vector2(ctr.x - tw * 0.5, r.position.y + ch * 0.76), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	var sub: String = "Puzzle %d of %d" % [puzzles_done + 1, int(_cfg.get("puzzles", 3))]
	var sfs: int = 20 if mob else 16
	var sw: float = _text_font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
	_view.draw_string(_text_font, Vector2(ctr.x - sw * 0.5, r.position.y + ch * 0.76 + sfs * 1.6), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(ART.INK, 0.7 * fade))

func _draw_bench() -> void:
	var r: Rect2 = _bench_rect
	# the workbench: green leather in a walnut frame (leather.gdshader, baked), set into the counter
	for k in 4:
		_view.draw_rect(Rect2(r.position + Vector2(0, 4), r.size).grow(5.0 - float(k)), Color(0, 0, 0, 0.12))
	if _tex_leather != null:
		_view.draw_texture_rect(_tex_leather, r, false)
	else:
		_view.draw_rect(r, Color(0.10, 0.22, 0.15))
	if selected < 0 or _solved:
		var placed_n: int = 0
		for v in placed:
			if v > 0:
				placed_n += 1
		var t1: String = ("Puzzle %d of %d" % [puzzles_done + 1, int(_cfg.get("puzzles", 3))]) if not _solved \
			else ("Puzzle %d of %d: balanced!" % [puzzles_done, int(_cfg.get("puzzles", 3))])
		var t2: String = "%d of %d crates settled" % [placed_n, puzzle.n_crates()]
		# inside the leather's gold rule (leather.gdshader: the frame 9, the inner rule 8.5 in from it): the
		# two lines sized to that height and centered in it -- at a fixed place they ran over the rule on
		# the shorter desktop bench
		var inner: Rect2 = r.grow(-(BENCH_RULE + 5.0))
		var fs1: int = int(clampf(inner.size.y * 0.42, 14.0, 27.0))
		var fs2: int = int(round(fs1 * (0.85 if MainGlobals.is_mobile() else 0.72)))
		var gap: float = fs1 * 0.30
		var block: float = fs1 * 0.80 + gap + fs2 * 0.95
		var y0: float = inner.position.y + (inner.size.y - block) * 0.5
		var x0: float = inner.position.x + 6.0
		_view.draw_string(_serif, Vector2(x0, y0 + fs1 * 0.80), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1, Color(1.0, 0.94, 0.78))
		_view.draw_string(_text_font, Vector2(x0, y0 + fs1 * 0.80 + gap + fs2 * 0.95), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0.98, 0.94, 0.84, 0.92))
		if not _solved:
			var hr: Rect2 = _hint_rect()
			_view.draw_rect(Rect2(hr.position + Vector2(0, 3), hr.size), Color(0, 0, 0, 0.4))
			_view.draw_rect(hr, ART.BRASS)
			_view.draw_rect(hr.grow(-3.0), Color(0.95, 0.80, 0.45))
			var ht: String = "Hint"
			var hfs: int = 29 if MainGlobals.is_mobile() else 22
			var hw: float = _serif.get_string_size(ht, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x
			_view.draw_string(_serif, Vector2(hr.get_center().x - hw * 0.5, hr.get_center().y + hfs * 0.36), ht, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, ART.INK)
		return
	# the crate being worked on, and its weights
	var cs: float = r.size.y - 22.0
	var cr: Rect2 = Rect2(r.position.x + 10.0, r.position.y + 6.0, cs * 1.05, cs * 0.84)
	var cols: int = _cols()
	ART.draw_crate(_view, cr, _crate_tex(selected), selected / cols, selected % cols, cols, open_mask(selected),
		crossed[selected], placed[selected], 0, 1.0, _serif)
	var nm: String = _name(selected)
	var nfs: int = 17 if MainGlobals.is_mobile() else 13
	var nw: float = _text_font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	_view.draw_string(_text_font, Vector2(cr.get_center().x - nw * 0.5, r.end.y - 4.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(0.95, 0.88, 0.75))
	var taken: int = _taken(selected)
	for v in range(1, cols + 1):
		var st: int = 0
		var b: int = PUZZLE.bit(v)
		if placed[selected] > 0:
			st = 3 if placed[selected] == v else (1 if crossed[selected] & b else 2)
		elif taken & b:
			st = 2
		elif crossed[selected] & b:
			st = 1
		var press: float = 0.0
		if _press_on == "weight" and _press_v == v and not _press_fired:
			press = clampf((Time.get_ticks_msec() - _press_t) / LONG_PRESS_MS, 0.0, 1.0)
		var wr: Rect2 = _bench_weight_rect(v)
		ART.draw_weight(_view, wr, v, st, press, _serif)
		# THE LONG PRESS'S RING only once the finger is clearly HOLDING (RING_AFTER_MS), then filling over
		# the rest: from the first moment, every plain tap flashed a quarter of it ("what is that?")
		var held: float = press * LONG_PRESS_MS
		if held > RING_AFTER_MS:
			var ring: float = clampf((held - RING_AFTER_MS) / (LONG_PRESS_MS - RING_AFTER_MS), 0.0, 1.0)
			_view.draw_arc(wr.get_center(), wr.size.x * 0.52, -PI * 0.5, -PI * 0.5 + TAU * ring, 32, ART.GLOW, 3.0)
	var xr: Rect2 = _bench_close_rect()
	var xc: Vector2 = xr.get_center()
	_view.draw_line(xc + Vector2(-7, -7), xc + Vector2(7, 7), Color(0.95, 0.88, 0.75, 0.7), 2.5)
	_view.draw_line(xc + Vector2(-7, 7), xc + Vector2(7, -7), Color(0.95, 0.88, 0.75, 0.7), 2.5)

func _draw_message() -> void:
	var left: float = _msg_until - Time.get_ticks_msec()
	if _msg == "" or (left <= 0.0 and not _waiting):
		return
	var fade: float = 1.0 if _waiting else clampf(left / MSG_FADE_MS, 0.0, 1.0)
	var fs: int = 22 if MainGlobals.is_mobile() else 15
	_view.draw_multiline_string(_text_font, Vector2(_msg_rect.position.x + 4.0, _msg_rect.position.y + fs + 4.0), _msg,
		HORIZONTAL_ALIGNMENT_LEFT, _msg_rect.size.x - 8.0, fs, 2, Color(_msg_col, _msg_col.a * fade))

func _draw_tickets_head() -> void:
	var t: String = "SCALES"
	if selected >= 0:
		t = "SCALES WITH %s" % _name(selected).to_upper()
	var n: int = ticket_order().size()
	var sub: String = "%d" % n
	if selected < 0 and not aside.is_empty():
		sub += " · %d set aside" % aside.size()
	var mob: bool = MainGlobals.is_mobile()
	var fs: int = 27 if mob else 18
	var base_y: float = _head_rect.size.y - 8.0
	_view.draw_string(_serif, _head_rect.position + Vector2(4.0, base_y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.88, 0.60))
	var tw: float = _serif.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_view.draw_string(_serif, _head_rect.position + Vector2(tw + 14.0, base_y), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.97, 0.90, 0.78, 0.8))
	_view.draw_line(_head_rect.position + Vector2(4.0, base_y + 6.0), Vector2(_head_rect.end.x, _head_rect.position.y + base_y + 6.0), Color(0.85, 0.62, 0.32, 0.45), 1.0)

func _draw_tickets() -> void:
	if puzzle == null:
		return
	var order: Array = ticket_order()
	var now: float = Time.get_ticks_msec()
	var swing: float = 0.0
	if _swing_t0 >= 0.0:
		var u: float = (now - _swing_t0) / 1000.0
		if u < 2.2:
			swing = deg_to_rad(10.0) * sin(u * 9.0) * exp(-u * 2.2)
	for k in order.size():
		var ci: int = order[k]
		var cr: Rect2 = Rect2(_card_at.get(ci, _card_list_pos(k)) - Vector2(0.0, _scroll), _card)
		if cr.end.y < 0.0 or cr.position.y > _tick_rect.size.y:
			continue
		if _press_card.has(ci):
			var u: float = (now - float(_press_card[ci])) / 400.0
			cr = cr.grow(-cr.size.x * 0.035 * sin(clampf(u, 0.0, 1.0) * PI))
		var st: int = 0
		if _solved:
			st = 0          # the win: every scale bright, swinging
		elif aside.has(ci) or _aside_pending.has(ci):
			st = 2
		elif _is_settled_clue(ci):
			st = 3
		elif ci == focus:
			st = 1
		# askew on the counter; a full-width paper less (the same angle moves its ends twice as far)
		var tilt_deg: float = float((ci * 37 + 11) % 7 - 3) * 0.45 * minf(1.0, 320.0 / _card.x)
		ART.draw_ticket(_tickets, cr, puzzle.clues[ci], _cols(), st, _serif,
			_tex_paper[ci % _tex_paper.size()] if not _tex_paper.is_empty() else null, _aside_rect(cr), swing, tilt_deg,
			TipscalesG.show_rules)
	# the scroll bar, while there is more
	var ms: float = _max_scroll()
	if ms > 0.0:
		var h: float = _tick_rect.size.y
		var bh: float = maxf(30.0, h * h / (h + ms))
		var by: float = (h - bh) * (_scroll / ms)
		_tickets.draw_rect(Rect2(_w - 6.0, by, 3.0, bh), Color(0.95, 0.85, 0.65, 0.35))
	if order.is_empty() and selected >= 0:
		_tickets.draw_string(_text_font, Vector2(20.0, 30.0), "No scale names this crate: the color rule settles it.",
			HORIZONTAL_ALIGNMENT_LEFT, _w - 40.0, 15, Color(0.95, 0.88, 0.75, 0.7))

# --- input ----------------------------------------------------------------------------------------------

func _on_view_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) or (ev as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb: InputEventMouseButton = ev
	var p: Vector2 = mb.position
	if mb.pressed:
		_press_pos = p
		_press_on = ""
		if not _can_play():
			return
		if selected >= 0 and _bench_rect.has_point(p):
			for v in range(1, _cols() + 1):
				if _bench_weight_rect(v).grow(4.0).has_point(p):
					_press_on = "weight"
					_press_v = v
					_press_t = Time.get_ticks_msec()
					_press_fired = false
					return
		return
	# released
	var was: String = _press_on
	_press_on = ""
	if not _can_play():
		return
	if was == "weight":
		if not _press_fired and selected >= 0 and _bench_weight_rect(_press_v).grow(8.0).has_point(p):
			_toggle_cross(selected, _press_v)
		_view.queue_redraw()
		return
	if p.distance_to(_press_pos) > TAP_SLOP * 2.0:
		return
	var i: int = _crate_at(p)
	if i >= 0:
		selected = -1 if selected == i else i
		if selected >= 0:
			game.tutorial_notify("selected")
		_scroll = 0.0
		_scroll_v = 0.0
		game.play_sound("pick")
		_redraw()
		return
	if selected >= 0 and _bench_close_rect().grow(6.0).has_point(p):
		selected = -1
		_scroll = 0.0
		_redraw()
		return
	if selected < 0 and _hint_rect().has_point(p):
		hint()
		return

func _on_tickets_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = ev
		if mb.pressed:
			_press_pos = mb.position
			_press_on = "tickets"
			_dragging = false
			_scroll_v = 0.0
			_drag_last = Time.get_ticks_msec()
			return
		var was_drag: bool = _dragging
		_dragging = false
		_press_on = ""
		if was_drag or not _can_play():
			return
		_tap_ticket(mb.position)
	elif ev is InputEventMouseMotion and _press_on == "tickets":
		var mm: InputEventMouseMotion = ev
		if not _dragging and mm.position.distance_to(_press_pos) > TAP_SLOP:
			_dragging = true
		if _dragging:
			var now: float = Time.get_ticks_msec()
			var dt: float = maxf(1.0, now - _drag_last) / 1000.0
			_drag_last = now
			_scroll = clampf(_scroll - mm.relative.y, 0.0, _max_scroll())
			_scroll_v = lerpf(_scroll_v, -mm.relative.y / dt, 0.5)
			_tickets.queue_redraw()
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var wb: InputEventMouseButton = ev
		if wb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll = clampf(_scroll + 60.0, 0.0, _max_scroll())
			_tickets.queue_redraw()
		elif wb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll = clampf(_scroll - 60.0, 0.0, _max_scroll())
			_tickets.queue_redraw()

func _tap_ticket(p: Vector2) -> void:
	var order: Array = ticket_order()
	for k in order.size():
		var cr: Rect2 = _card_rect(k)
		if not cr.has_point(p):
			continue
		var ci: int = order[k]
		if not _is_settled_clue(ci) and _aside_rect(cr).grow(6.0).has_point(p):
			_press_card[ci] = Time.get_ticks_msec()
			if aside.has(ci):
				aside.erase(ci)
			elif _aside_pending.has(ci):
				_aside_pending.erase(ci)
			else:
				_aside_pending[ci] = Time.get_ticks_msec() + ASIDE_HOLD_MS
				if focus == ci:
					focus = -1
			game.play_sound("tick")
		else:
			focus = -1 if focus == ci else ci
			if focus >= 0:
				game.tutorial_notify("focused")
			game.play_sound("pick")
		_scroll = clampf(_scroll, 0.0, _max_scroll())
		_redraw()
		return
