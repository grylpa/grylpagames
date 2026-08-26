extends CanvasLayer

# Dino gameplay: a continuous recognition-memory task.
#
# One card at a time is shown. The player answers whether they have ALREADY seen
# that card earlier THIS round — swipe RIGHT (or the "Seen" button) — or whether it
# is new — swipe LEFT (or "New"). A card left unanswered past card_time counts as a
# miss. The level runs for duration_sec and completes when the time elapses.
#
# The working set of distinct images ADAPTS to the player's pace instead of being a
# fixed pool: it starts at `start_cards` and grows by one image for every card that has
# been shown `new_after` times ("seen twice -> add a new card"). New images are drawn
# from the source folder(s) (equal probability per folder, then within it), so "new"
# answers keep flowing and the mix stays ~50/50 regardless of how fast the player goes;
# the only cap is how many images the folders hold. Each presentation is a fresh image
# (was_seen=false) or a repeat (was_seen=true); correctness = (said "seen") == was_seen.

var game: GenericGameUtil

var current_level_id: int = 1

# --- level params (from DinoLevelConfig) ---
var card_size_key: String = "med"
var card_time_ms: float = 5000.0
var gap_ms: float = 700.0
var start_cards: int = 3        # working set size at round start (difficulty lever)
var new_after: int = 2          # a new image is unlocked each time a card hits this many shows
var duration_sec: int = 60
var _folders: Array = []        # folder names in play this level
var _folder_colors: Array = []  # parallel border Color per folder

# --- adaptive card set ---
# The working set grows as the player plays: an extra distinct image is unlocked for
# every card that has been shown `new_after` times. New images come from the folder(s)
# (equal folder probability), so "new" answers keep flowing and the mix stays ~50/50
# regardless of the player's pace; the only cap is how many images the folders hold.
var _introduced: Array = []     # [{id:int, tex:Texture2D, color:Color, count:int}]
var _folder_avail: Array = []   # per folder index: shuffled list of not-yet-used image indices
var _last_id: int = -1          # id of the last shown card (to avoid immediate duplicates)
var _next_id: int = 0

# --- per-level stats ---
var total_rounds: int = 0
var total_corrects: int = 0
var times_to_answer: Array = []

# --- phase machine ---
enum Phase { IDLE, SHOW, FEEDBACK, GAP }
var phase: int = Phase.IDLE
var _phase_start_ms: float = 0.0
var _show_start_ms: float = 0.0
var _cur_was_seen: bool = false
var _answered: bool = false

# --- ui (built in code) ---
var _bg: TextureRect = null
var _instruction: Label = null
var _hint: Label = null
var _feedback: Label = null
var _btn_new: Button = null
var _btn_seen: Button = null
var _bar_track: ColorRect = null   # per-card timeout bar (track)
var _bar_fill: ColorRect = null    # per-card timeout bar (fill, depletes over card_time)
var _bar_full_w: float = 200.0
var _bar_h: float = 14.0
var _card = null
var _card_frac: float = 0.78         # size fraction of the max fittable card (small/med/big)
var _card_avail_w: float = 200.0
var _card_avail_h: float = 200.0
var _card_area_top: float = 0.0
var _card_center_x: float = 340.0
const CARD_SCRIPT: GDScript = preload("res://shared/scripts/card.gd")

# --- swipe input ---
var _pressing: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_index: int = -2
const _SWIPE_MIN: float = 60.0

# How long the Correct!/Too slow banner stays up. A var, not a const, only so a tutorial can
# shorten it; _load_level puts it back, so a tutorial can never leave real play running fast.
const FEEDBACK_DEFAULT_MS: float = 700.0
var feedback_ms: float = FEEDBACK_DEFAULT_MS

var correct_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var wrong_audio = preload("res://art/sounds/swoosh.mp3")

signal sig_level_is_done(didwin: bool)
signal started_playing

func _ready() -> void:
	game = DinoG.game
	game.sig_time_over.connect(_on_time_over)
	game.add_sound(self, "correct", correct_audio)
	game.add_sound(self, "wrong", wrong_audio)
	_build_ui()
	set_process(true)

# --- UI construction --------------------------------------------------------

func _build_ui() -> void:
	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# per-image timeout bar (below the header, above the level number)
	_bar_track = ColorRect.new()
	_bar_track.color = Color(0, 0, 0, 0.38)
	_bar_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_track)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.3, 0.8, 0.4, 1.0)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.visible = false
	add_child(_bar_fill)

	_instruction = _make_label(34, Color(1, 1, 1, 1))
	_instruction.text = "Seen this card already?"
	add_child(_instruction)

	_hint = _make_label(24, Color(0.92, 0.92, 0.92, 1.0))
	_hint.text = "Swipe RIGHT = seen    LEFT = new"
	add_child(_hint)

	_feedback = _make_label(84, Color(0.2, 0.8, 0.3, 1.0))
	_feedback.text = ""
	_feedback.z_index = 20
	_feedback.hide()
	add_child(_feedback)

	_btn_new = _make_button("New", Color(0.85, 0.35, 0.30, 1.0))
	_btn_new.pressed.connect(_on_new_pressed)
	add_child(_btn_new)

	_btn_seen = _make_button("Seen", Color(0.20, 0.62, 0.30, 1.0))
	_btn_seen.pressed.connect(_on_seen_pressed)
	add_child(_btn_seen)

func _make_label(font_size: int, col: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # never exceed the screen width
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _make_button(txt: String, col: Color) -> Button:
	var b: Button = Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 34)
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = col
	st.set_corner_radius_all(14)
	st.set_border_width_all(3)
	st.border_color = col.darkened(0.35)
	var st_hover: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	st_hover.bg_color = col.lightened(0.12)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st_hover)
	b.add_theme_stylebox_override("pressed", st_hover)
	b.add_theme_stylebox_override("focus", st)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

func _layout() -> void:
	var sw: float = float(MainGlobals.screen_size.x)
	var sh: float = float(MainGlobals.screen_size.y)
	var mob: bool = MainGlobals.is_mobile()
	var hh: float = float(MainGlobals.header_height)

	var btn_h: float = 88.0 if mob else 56.0
	var btn_margin_bottom: float = 46.0 if mob else 26.0
	var btn_y: float = sh - btn_h - btn_margin_bottom

	# fonts scale up on mobile
	_instruction.add_theme_font_size_override("font_size", 40 if mob else 30)
	_hint.add_theme_font_size_override("font_size", 30 if mob else 22)
	_feedback.add_theme_font_size_override("font_size", 120 if mob else 84)
	for b in [_btn_new, _btn_seen]:
		b.add_theme_font_size_override("font_size", 44 if mob else 32)

	# timeout bar just under the header (level label is moved down below it in main.gd)
	_bar_h = 22.0 if mob else 14.0
	var bar_x: float = 22.0
	var bar_y: float = hh + 8.0
	_bar_full_w = sw - bar_x * 2.0
	_place(_bar_track, bar_x, bar_y, _bar_full_w, _bar_h)
	_bar_fill.position = Vector2(bar_x, bar_y)
	_bar_fill.size = Vector2(_bar_full_w, _bar_h)

	# instruction + hint sit BELOW the (moved) level number
	var instr_line: float = 52.0 if mob else 40.0
	var hint_line: float = 42.0 if mob else 30.0
	var text_top: float = hh + (96.0 if mob else 84.0)
	_place(_instruction, 0.0, text_top, sw, instr_line)
	_place(_hint, 0.0, text_top + instr_line, sw, hint_line)

	# card area between the header text and the buttons
	var card_top: float = text_top + instr_line + hint_line + (16.0 if mob else 12.0)
	var avail_h: float = btn_y - card_top - (20.0 if mob else 16.0)
	var avail_w: float = sw - (44.0 if mob else 40.0)
	# The actual card is sized per-image (in _show_next_card) to the image's own aspect
	# so the whole image shows uncropped; here we just store the area + the size fraction.
	# small/med/big are fractions of the largest card that fits, so they differ clearly.
	var frac: float = 0.78
	match card_size_key:
		"small":
			frac = 0.56
		"med":
			frac = 0.78
		"big":
			frac = 0.98
	_card_frac = frac
	_card_avail_w = avail_w
	_card_avail_h = avail_h
	_card_area_top = card_top
	_card_center_x = sw * 0.5

	# feedback overlays the (fixed) center of the card area
	_place(_feedback, 0.0, card_top + avail_h * 0.5 - 70.0, sw, 140.0)

	# yes/no buttons, mapped left = new, right = seen (matches swipe direction)
	var bw: float = sw * 0.42
	var gap: float = 14.0
	_place(_btn_new, sw * 0.5 - bw - gap, btn_y, bw, btn_h)
	_place(_btn_seen, sw * 0.5 + gap, btn_y, bw, btn_h)

func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	c.custom_minimum_size = Vector2(w, h)

# --- Level flow -------------------------------------------------------------

func new_game(_from_scratch: bool = true) -> void:
	game.level_is_done = false
	game.level_is_ready = false  # play starts only when the pre-level popup closes
	# monotonic level counter (ptbits/didi pattern)
	if _from_scratch:
		current_level_id = DinoG.starting_level_id
	elif game.need_to_increase_level:
		current_level_id = mini(current_level_id + 1, DinoLevelConfig.max_level())
	game.need_to_increase_level = false
	# per-level stats reset every level (each level is scored separately)
	total_rounds = 0
	total_corrects = 0
	game.corrects = 0
	game.mistakes = 0
	times_to_answer.clear()
	_clear_card()
	_answered = false
	_pressing = false
	_press_index = -2
	phase = Phase.IDLE
	if _bar_fill != null:
		_bar_fill.visible = false
	_load_level(current_level_id)
	_build_pool()
	_layout()
	# also re-apply a frame later: on the first level the menu->level transition may not be
	# settled yet when the immediate _layout runs, which mispositions the labels.
	call_deferred("_layout")
	_feedback.hide()

	if game.tutorial_mode:
		# The tutorial IS the intro, and it teaches the same things the popup states. Showing both
		# would make the player dismiss a wall of text before being taught it.
		_tutorial_setup()
		_on_game_popup_closed()
		return

	# The shared briefing card (ResultCard): prose wraps itself and "Label: value" lines are set as
	# a table, so the text below is written as sentences and facts, not hand-wrapped lines.
	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	game.show_game_popup(self, "Level %d" % current_level_id, _intro_text())

# A tutorial plays the real level, but with the pressure taken off: a long per-card deadline (the
# bar is being EXPLAINED, so it must not expire while the coach talks about it) and a scripted
# opening of new, new, repeat — which is the exact sequence the lesson needs.
func _tutorial_setup() -> void:
	card_time_ms = 20000.0
	_forced_picks = ["new", "new", "repeat"]
	# "Here is the first." followed by most of a second of blank screen reads as the tutorial
	# having hung. The gap exists to pace real play; a coach pointing at a card needs it short.
	# The feedback banner is the bigger half of that wait: the coach says "another one, tap New
	# again" the moment the previous answer lands, while the board is still showing "Correct!",
	# so the card it is talking about turned up a full second later. 700 + 700 -> 250 + 150.
	gap_ms = 150.0
	feedback_ms = 250.0

# Opens with what you are about to be shown, then the rule in full. Built as a line array rather
# than one format string: the old version needed parentheses around the whole concatenation,
# because `%` binds tighter than `+` and would otherwise format only the last line.
#
# CARD TIME is deliberately not listed. It is a timeout, not something to plan around, and the
# per-card bar under the header shows it far better than a number in a panel you have already
# dismissed.
func _intro_text() -> String:
	# The facts sit together at the end so they form ONE table; prose above them is left to wrap.
	var lines: Array = [
		"SEEN = this card has already appeared THIS round.",
		"",
		"Swipe RIGHT = seen before",
		"Swipe LEFT = new",
		"",
		"Cards: %s" % _folders_phrase(),
		"Duration: %s" % _fmt_secs(float(duration_sec)),
	]
	return "\n".join(lines)

# The level's image folders in plain English — "people" is the folder name, "faces" is what the
# player actually sees.
func _folders_phrase() -> String:
	var words: Array = []
	for f in _folders:
		words.append("faces" if str(f) == "people" else str(f))
	var joined: String = " and ".join(words)
	# only the first letter — String.capitalize() would Title Case Every Word
	return joined.substr(0, 1).to_upper() + joined.substr(1)

func _on_game_popup_closed() -> void:
	if not game.level_is_done and not game.level_is_ready:
		# Re-layout now that play is about to start: on the very first level the initial
		# _layout() (during new_game, mid menu->level transition) can run before the
		# viewport/screen size has settled, leaving the labels mispositioned until a later
		# level or a manual "N". Recomputing here (settled) fixes level 1.
		_layout()
		game.level_is_ready = true
		started_playing.emit()

# Called when the player leaves to the main menu mid-round: tear down the current
# card/answer state so nothing lingers into the next round.
func stop_level() -> void:
	_clear_card()
	phase = Phase.IDLE
	_answered = true
	_pressing = false
	_press_index = -2
	if _feedback != null:
		_feedback.hide()
	if _bar_fill != null:
		_bar_fill.visible = false

func _load_level(id: int) -> void:
	var def: Dictionary = DinoLevelConfig.get_level(id)
	card_size_key = str(def.get("card_size", "med"))
	card_time_ms = float(def.get("card_time_sec", 5.0)) * 1000.0
	feedback_ms = FEEDBACK_DEFAULT_MS
	gap_ms = float(def.get("gap_sec", 0.7)) * 1000.0
	start_cards = maxi(1, int(def.get("start_cards", 3)))
	new_after = maxi(1, int(def.get("new_after", 2)))
	duration_sec = int(def.get("duration_sec", 60))

	_folders = []
	for part in str(def.get("source", "dinos")).split(","):
		var f: String = part.strip_edges()
		if f != "":
			_folders.append(f)
	if _folders.is_empty():
		_folders = ["dinos"]

	_folder_colors = []
	var bc = def.get("border_colors", null)
	if bc is Array and bc.size() == _folders.size():
		_folder_colors = bc.duplicate()
	else:
		for f in _folders:
			_folder_colors.append(DinoG.default_color(f))

	var bgpath: String = DinoG.background_for(_folders)
	if ResourceLoader.exists(bgpath):
		_bg.texture = load(bgpath)
		# grass is a small tile (weris TILES it, stretch_mode 1); bk1 is a full image (cover).
		if bgpath.ends_with("grass.png"):
			_bg.stretch_mode = TextureRect.STRETCH_TILE
		else:
			_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	# per-level time budget: the clock is (re)set to duration each level. Runs after
	# game.reset() in main.new_game, so it takes precedence.
	game.set_reset_time_left(duration_sec)
	game.set_time_left(0, 0, duration_sec)
	# Just the number. The old "Level 5 DP" leaked a scores-table shorthand onto the play screen,
	# where it read as a code — and the thing it encoded (which folders the cards come from) is
	# already on screen in the cards themselves.
	game.level_label_changed("Level %d" % int(def.get("id", id)))

func _build_pool() -> void:
	# Reset the adaptive set. Per folder, keep a shuffled list of image indices not yet
	# used this round; new cards are drawn from these (equal folder probability).
	_introduced = []
	_last_id = -1
	_next_id = 0
	_folder_avail = []
	for f in _folders:
		var n: int = DinoG.num_images(f)
		var idxs: Array = []
		for i in n:
			idxs.append(i)
		idxs.shuffle()
		_folder_avail.append(idxs)

# --- Card presentation ------------------------------------------------------

func _total_folder_avail() -> int:
	var s: int = 0
	for a in _folder_avail:
		s += a.size()
	return s

func _allowance() -> int:
	# how many distinct images are allowed in play: base + one per card already shown
	# `new_after` times. (The "seen twice -> add a card" rule.)
	var unlocked: int = 0
	for c in _introduced:
		if c["count"] >= new_after:
			unlocked += 1
	return start_cards + unlocked

func _introduce_new():
	# draw a not-yet-used image, picking a folder with equal probability first
	var fis: Array = []
	for i in _folders.size():
		if _folder_avail[i].size() > 0:
			fis.append(i)
	if fis.is_empty():
		return null
	var fi: int = fis[game.rng.randi_range(0, fis.size() - 1)]
	var img_i: int = _folder_avail[fi].pop_back()
	var entry: Dictionary = {
		"id": _next_id,
		"tex": DinoG.image_at(_folders[fi], img_i),
		"color": _folder_colors[fi],
		"count": 0,
	}
	_next_id += 1
	_introduced.append(entry)
	return entry

# Tutorial support: a scripted run of picks, consumed one per card ("new" or "repeat"). The
# tutorial has to be able to say "and NOW you see one you've already seen", which the adaptive
# picker below would only get to by luck. Empty in normal play, so the picker is untouched.
var _forced_picks: Array = []

func _forced_pick(kind: String) -> Dictionary:
	if kind == "new" or _introduced.is_empty():
		var e = _introduce_new()
		if e == null:
			return {}
		e["count"] += 1
		_last_id = e["id"]
		return {"entry": e, "was_seen": false}
	# repeat: anything already introduced except the card just shown
	var choices: Array = []
	for c in _introduced:
		if c["id"] != _last_id:
			choices.append(c)
	if choices.is_empty():
		return {}
	var pick_c: Dictionary = choices[game.rng.randi_range(0, choices.size() - 1)]
	pick_c["count"] += 1
	_last_id = pick_c["id"]
	return {"entry": pick_c, "was_seen": true}

func _pick_next() -> Dictionary:
	if not _forced_picks.is_empty():
		var forced: Dictionary = _forced_pick(String(_forced_picks.pop_front()))
		if not forced.is_empty():
			return forced
		# could not honor it (folder exhausted) — fall through to the normal picker
	var folder_has: bool = _total_folder_avail() > 0
	# first card of the round is always new
	if _introduced.is_empty():
		var e0 = _introduce_new()
		if e0 == null:
			return {}
		e0["count"] += 1
		_last_id = e0["id"]
		return {"entry": e0, "was_seen": false}

	# cards still below the unlock threshold (excluding the last shown) — repeating these
	# drives the "seen new_after times" unlocks that keep new images flowing.
	var pending: Array = []
	for c in _introduced:
		if c["count"] < new_after and c["id"] != _last_id:
			pending.append(c)
	var can_new: bool = _introduced.size() < _allowance() and folder_has

	var do_new: bool
	if pending.is_empty():
		do_new = folder_has  # nothing useful to repeat -> keep novelty (else fall to repeat)
	elif not can_new:
		do_new = false
	else:
		do_new = game.rng.randf() < 0.5  # interleave ~50/50

	if do_new:
		var en = _introduce_new()
		if en != null:
			en["count"] += 1
			_last_id = en["id"]
			return {"entry": en, "was_seen": false}
		# introduce failed (folder exhausted) -> fall through to a repeat

	# repeat an already-seen card: prefer a below-threshold one (to unlock), else any,
	# never the one just shown.
	var choices: Array = pending
	if choices.is_empty():
		choices = []
		for c in _introduced:
			if c["id"] != _last_id:
				choices.append(c)
	if choices.is_empty():
		choices = _introduced
	var pick_c: Dictionary = choices[game.rng.randi_range(0, choices.size() - 1)]
	pick_c["count"] += 1
	_last_id = pick_c["id"]
	return {"entry": pick_c, "was_seen": true}

func _show_next_card() -> void:
	_clear_card()
	var pick: Dictionary = _pick_next()
	if pick.is_empty():
		return
	_cur_was_seen = pick["was_seen"]
	_answered = false
	var entry: Dictionary = pick["entry"]
	var tex = entry["tex"]
	# fit the card to the image's own aspect ratio (full image, no crop), scaled by the
	# level's size fraction, inside the available area.
	var asp: float = CARD_SCRIPT.ASPECT_H_OVER_W
	if tex != null:
		var ts: Vector2 = tex.get_size()
		if ts.x > 0.0 and ts.y > 0.0:
			asp = ts.y / ts.x
	var maxw: float = minf(_card_avail_w, _card_avail_h / asp)
	var w: float = maxf(maxw * _card_frac, 60.0)
	_card = CARD_SCRIPT.new()
	add_child(_card)
	_card.set_frame(8, 8)  # dino uses a thicker frame than the shared default
	_card.setup(tex, entry["color"])
	_card.set_width(w)
	# centered in the card area (its center is a fixed point, so the layout is stable and
	# the text above always stays in the same place regardless of card size).
	var ch: float = _card.card_height()
	_card.position = Vector2(_card_center_x, _card_area_top + maxf(0.0, (_card_avail_h - ch) * 0.5))
	_card.rotation = 0.0
	_card.modulate = Color(1, 1, 1, 0)
	var tw: Tween = create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.12)
	_feedback.hide()
	# a swipe must BEGIN during the current card — drop any stale press state so a
	# leftover release (from the menu/popup/previous round) can't answer a fresh card
	_pressing = false
	_press_index = -2
	_answered_without_buttons = false
	phase = Phase.SHOW
	_show_start_ms = game.game_time
	_phase_start_ms = game.game_time
	# No-op outside tutorial mode.
	game.tutorial_notify("card_shown_seen" if _cur_was_seen else "card_shown_new")
	game.tutorial_notify("card_shown")

func _register_answer(said_seen) -> void:
	# said_seen: true (right/"Seen"), false (left/"New"), or null (timed out)
	if phase != Phase.SHOW or _answered:
		return
	var timed_out: bool = said_seen == null
	# ignore a too-early input answer (e.g. a leftover release right as a card appears)
	if not timed_out and (game.game_time - _show_start_ms) < 150.0:
		return
	_answered = true
	var correct: bool = (not timed_out) and (bool(said_seen) == _cur_was_seen)
	total_rounds += 1
	if correct:
		total_corrects += 1
		var elapsed: float = game.game_time - _show_start_ms
		times_to_answer.append(maxf(elapsed, 0.0))
		while times_to_answer.size() > 20:
			times_to_answer.remove_at(0)
		var bonus: int = maxi(0, 8 - int(elapsed / 500.0))
		game.add_score_and_time(10 + bonus, 0)
		game.add_correct_or_mistake(1, 0)
		game.play_sound("correct")
		_feedback.text = "Correct"
		_feedback.add_theme_color_override("font_color", Color(0.25, 0.85, 0.35, 1.0))
	else:
		var penalty: int = mini(3, maxi(0, game.score))
		game.add_score_and_time(-penalty, 0)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("wrong")
		_feedback.text = "Too slow" if timed_out else "Wrong"
		_feedback.add_theme_color_override("font_color", Color(0.9, 0.3, 0.25, 1.0))
	_feedback.show()
	MainGlobals.global_update_hud()
	_animate_card_out(said_seen, timed_out)
	phase = Phase.FEEDBACK
	_phase_start_ms = game.game_time
	# No-ops outside tutorial mode. "answered" fires however the answer went — a tutorial should
	# move on when the player acts, not only when they get it right.
	game.tutorial_notify("answered_correct" if correct else "answered_wrong")
	if not timed_out:
		game.tutorial_notify("answered_without_buttons" if _answered_without_buttons
			else "answered_by_button")
	game.tutorial_notify("answered")

func _animate_card_out(said_seen, timed_out: bool) -> void:
	if _card == null or not is_instance_valid(_card):
		_card = null
		return
	var card_ref = _card
	_card = null
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	if timed_out:
		tw.tween_property(card_ref, "modulate:a", 0.0, 0.3)
	else:
		var dir: float = 1.0 if bool(said_seen) else -1.0
		var target_x: float = card_ref.position.x + dir * (float(MainGlobals.screen_size.x) * 0.9)
		tw.tween_property(card_ref, "position:x", target_x, 0.28)
		tw.tween_property(card_ref, "rotation", dir * 0.28, 0.28)
		tw.tween_property(card_ref, "modulate:a", 0.0, 0.28)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(card_ref):
			card_ref.queue_free())

func _clear_card() -> void:
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	_card = null

# --- Frame update -----------------------------------------------------------

func _can_play() -> bool:
	return game.playing and not game.paused() and not game.level_is_done and game.level_is_ready

func _process(_dt: float) -> void:
	if not _can_play():
		return
	var now: float = game.game_time
	match phase:
		Phase.IDLE:
			_bar_fill.visible = false
			_show_next_card()
		Phase.SHOW:
			var frac: float = clampf(1.0 - (now - _show_start_ms) / card_time_ms, 0.0, 1.0)
			_bar_fill.visible = true
			_bar_fill.size = Vector2(_bar_full_w * frac, _bar_h)
			_bar_fill.color = Color(0.9, 0.3, 0.25, 1.0).lerp(Color(0.3, 0.8, 0.4, 1.0), frac)
			if now - _show_start_ms >= card_time_ms:
				_register_answer(null)
		Phase.FEEDBACK:
			_bar_fill.visible = false
			if now - _phase_start_ms >= feedback_ms:
				phase = Phase.GAP
				_phase_start_ms = now
				_feedback.hide()
		Phase.GAP:
			_bar_fill.visible = false
			if now - _phase_start_ms >= gap_ms:
				_show_next_card()

# --- Input (swipe) ----------------------------------------------------------

# How the current answer was given. Only the tutorial reads it: it teaches the buttons and the
# faster gesture as separate lessons, so it has to know which one the player actually used.
# Arrow keys count as "without buttons" too — on desktop they are the same shortcut as a swipe.
var _answered_without_buttons: bool = false

func _on_new_pressed() -> void:
	_answered_without_buttons = false
	_register_answer(false)

func _on_seen_pressed() -> void:
	_answered_without_buttons = false
	_register_answer(true)

func _input(event: InputEvent) -> void:
	if not _can_play() or phase != Phase.SHOW or _answered:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# keyboard: Left = new, Right = seen (matches swipe/buttons)
		if event.keycode == KEY_LEFT:
			_answered_without_buttons = true
			_register_answer(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT:
			_answered_without_buttons = true
			_register_answer(true)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
			_press_index = event.index
		elif _pressing and event.index == _press_index:
			_pressing = false
			_try_swipe(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
			_press_index = -1
		elif _pressing and _press_index == -1:
			_pressing = false
			_try_swipe(event.position)

func _try_swipe(release_pos: Vector2) -> void:
	var d: Vector2 = release_pos - _press_pos
	if absf(d.x) >= _SWIPE_MIN and absf(d.x) > absf(d.y):
		_answered_without_buttons = true
		_register_answer(d.x > 0.0)  # right = seen, left = new
		get_viewport().set_input_as_handled()

# --- Level completion -------------------------------------------------------

func _on_time_over() -> void:
	if game.level_is_done:
		return
	_level_done(true)

func _level_done(didwin: bool) -> void:
	if game.level_is_done:
		return
	game.level_is_done = true
	_clear_card()
	_feedback.hide()
	game.sig_level_is_done.emit(didwin)  # main saves the level score
	if not didwin:
		sig_level_is_done.emit(false)
		return
	MainGlobals.global_level_is_done(true)
	if current_level_id >= DinoLevelConfig.max_level():
		# already at the top level — loop it (no increase, no popup)
		sig_level_is_done.emit(true)
		return
	game.need_to_increase_level = true
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	var extra: String = "\n\nAccuracy: %d%%\nMean time: %s" % [
		pct_correct(),
		("%d ms" % mean_response_time_ms()) if not times_to_answer.is_empty() else "N/A"
	]
	game.show_level_done_popup(self, "", "", current_level_id, extra)

func _on_level_done_popup_closed() -> void:
	sig_level_is_done.emit(true)

func mean_response_time_ms() -> int:
	if times_to_answer.is_empty():
		return 9999
	var s: float = 0.0
	for t in times_to_answer:
		s += t
	return roundi(s / times_to_answer.size())

func pct_correct() -> int:
	if total_rounds == 0:
		return 0
	return roundi(100.0 * float(total_corrects) / float(total_rounds))

func _fmt_secs(s: float) -> String:
	var t: int = int(round(s))
	if t >= 60:
		return "%d:%02d min" % [t / 60, t % 60]
	return "%d sec" % t

func tick() -> void:
	pass
