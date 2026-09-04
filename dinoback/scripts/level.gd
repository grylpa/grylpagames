extends CanvasLayer

# Dino N-Back gameplay.
#
# One card at a time. The player answers whether it matches the card exactly N positions back —
# MATCH (swipe right / the Match button) or NO (swipe left / the No button). A card left
# unanswered past card_time counts as a miss. The level runs for duration_sec.
#
# This is NOT the Dino recognition task ("have I seen this before"). The pool is deliberately
# small and every card recurs constantly, so seeing a familiar card tells the player nothing —
# only its POSITION in the stream does. That is also why the first N cards of a level are PRIMING
# cards: they have no predecessor to compare against, so they are shown to be memorized, with no
# answer and no score.
#
# What a match means is per level (`rule`): the same symbol, the same color, or both. The other
# attribute is then a live distractor, which is the point.

var game: GenericGameUtil

var current_level_id: int = 1

# --- level params (from DinobackLevelConfig) ---
var n_back: int = 1
var rule: String = "symbol"       # "symbol" | "color" | "both"
var pool_size: int = 4
var num_colors: int = 1
var card_size_key: String = "med"
var card_time_ms: float = 4000.0
var gap_ms: float = 600.0
var duration_sec: int = 60
var target_rate: float = 0.30
var lure_rate: float = 0.15
var partial_rate: float = 0.40
var _categories: Array = []

# --- pool and sequence ---
# _pool: the distinct card faces in play this level.
#        [{cat:String, sym:String, tex:Texture2D, border:Color}]
# _seq:  every trial shown so far, in order. [{item:int (index into _pool), col:int}]
var _pool: Array = []
var _seq: Array = []

# --- per-level stats ---
var total_rounds: int = 0         # scored trials (priming excluded)
var total_corrects: int = 0
var targets_total: int = 0
var targets_hit: int = 0
var times_to_answer: Array = []

# --- phase machine ---
enum Phase { IDLE, SHOW, FEEDBACK, GAP }
var phase: int = Phase.IDLE
var _phase_start_ms: float = 0.0
var _show_start_ms: float = 0.0
var _cur_is_target: bool = false
var _cur_priming: bool = false
var _answered: bool = false

# --- tutorial staging (all inert outside tutorial_mode) ---------------------
# The coach chooses whether the next scored card WILL be a match, so "this one matches" and "this
# one does not" can each be taught on demand rather than whenever the generator obliges.
# 1 = force a match, 0 = force a non-match, -1 = leave it to target_rate/lure_rate.
var tutorial_force_target: int = -1
# Hold the stream between cards, so a caption can be read without the next card arriving behind it.
var tutorial_hold_cards: bool = false

# --- ui (built in code) ---
var _bg: TextureRect = null
var _instruction: Label = null
var _hint: Label = null
var _feedback: Label = null
var _btn_no: Button = null
var _btn_match: Button = null
var _bar_track: ColorRect = null
var _bar_fill: ColorRect = null
var _bar_full_w: float = 200.0
var _bar_h: float = 14.0
var _card = null
var _card_frac: float = 0.78
var _card_avail_w: float = 200.0
var _card_avail_h: float = 200.0
var _card_area_top: float = 0.0
var _card_center_x: float = 340.0

const CARD_SCRIPT: GDScript = preload("res://shared/scripts/card.gd")
const ART_SCRIPT: GDScript = preload("res://dinoback/scripts/symbol_art.gd")
const CARD_INSET: float = 8.0     # must match the set_frame() inset below
const DRAWN_ASPECT: float = 1.0   # drawn faces get a square card; a big symbol fills it best

# --- swipe input ---
var _pressing: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_index: int = -2
const _SWIPE_MIN: float = 60.0

const FEEDBACK_MS: float = 600.0

var correct_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var wrong_audio = preload("res://art/sounds/swoosh.mp3")

signal sig_level_is_done(didwin: bool)
signal started_playing

func _ready() -> void:
	game = DinobackG.game
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
	_instruction.text = ""
	add_child(_instruction)

	_hint = _make_label(24, Color(0.92, 0.92, 0.92, 1.0))
	_hint.text = ""
	add_child(_hint)

	_feedback = _make_label(84, Color(0.2, 0.8, 0.3, 1.0))
	_feedback.text = ""
	_feedback.z_index = 20
	_feedback.hide()
	add_child(_feedback)

	_btn_no = _make_button("No", Color(0.85, 0.35, 0.30, 1.0))
	_btn_no.pressed.connect(_on_no_pressed)
	add_child(_btn_no)

	_btn_match = _make_button("Match", Color(0.20, 0.62, 0.30, 1.0))
	_btn_match.pressed.connect(_on_match_pressed)
	add_child(_btn_match)

func _make_label(font_size: int, fg: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", fg)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _make_button(txt: String, bg: Color) -> Button:
	var b: Button = Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 34)
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = bg
	st.set_corner_radius_all(14)
	st.set_border_width_all(3)
	st.border_color = bg.darkened(0.35)
	var st_hover: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	st_hover.bg_color = bg.lightened(0.12)
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

	MainGlobals.set_font_size(_instruction, 30)
	MainGlobals.set_font_size(_hint, 22)
	MainGlobals.set_font_size(_feedback, 84)
	for b in [_btn_no, _btn_match]:
		MainGlobals.set_font_size(b, 32)

	_bar_h = 22.0 if mob else 14.0
	var bar_x: float = 22.0
	var bar_y: float = hh + 8.0
	_bar_full_w = sw - bar_x * 2.0
	_place(_bar_track, bar_x, bar_y, _bar_full_w, _bar_h)
	_bar_fill.position = Vector2(bar_x, bar_y)
	_bar_fill.size = Vector2(_bar_full_w, _bar_h)

	var instr_line: float = 52.0 if mob else 40.0
	var hint_line: float = 42.0 if mob else 30.0
	var text_top: float = hh + (96.0 if mob else 84.0)
	_place(_instruction, 0.0, text_top, sw, instr_line)
	_place(_hint, 0.0, text_top + instr_line, sw, hint_line)

	var card_top: float = text_top + instr_line + hint_line + (16.0 if mob else 12.0)
	var avail_h: float = btn_y - card_top - (20.0 if mob else 16.0)
	var avail_w: float = sw - (44.0 if mob else 40.0)
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

	_place(_feedback, 0.0, card_top + avail_h * 0.5 - 70.0, sw, 140.0)

	var bw: float = sw * 0.42
	var gap: float = 14.0
	_place(_btn_no, sw * 0.5 - bw - gap, btn_y, bw, btn_h)
	_place(_btn_match, sw * 0.5 + gap, btn_y, bw, btn_h)

func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	c.custom_minimum_size = Vector2(w, h)

# --- Level flow -------------------------------------------------------------

func new_game(_from_scratch: bool = true) -> void:
	game.level_is_done = false
	game.level_is_ready = false
	if _from_scratch:
		current_level_id = DinobackG.starting_level_id
	elif game.need_to_increase_level:
		current_level_id = mini(current_level_id + 1, DinobackLevelConfig.max_level())
	game.need_to_increase_level = false
	total_rounds = 0
	total_corrects = 0
	targets_total = 0
	targets_hit = 0
	game.corrects = 0
	game.mistakes = 0
	times_to_answer.clear()
	_clear_card()
	_seq.clear()
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
		# No "Level 1 / N = 1 / MATCH = same shape as..." wall in front of the coach's first
		# caption — the tutorial IS that explanation, delivered one beat at a time.
		_tutorial_setup()
		_layout()
		game.level_is_ready = true
		started_playing.emit()
		return
	# The shared briefing card (ResultCard): prose wraps itself and "Label: value" lines are set as
	# a table, so the text below is written as sentences and facts, not hand-wrapped lines.
	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	game.show_game_popup(self, "Level %d" % current_level_id, _intro_text())

# The rule is spelled out in full every level. It changes from level to level along two axes at
# once (what N is, and which attribute counts), and neither is guessable from the cards.
func _intro_text() -> String:
	var noun: String = _symbol_noun()
	# Sentences, not hand-wrapped lines — the card wraps prose itself. The facts go last so they
	# form ONE table instead of being split by the rule text.
	var lines: Array = []
	match rule:
		"color":
			lines.append("MATCH = same COLOR as the card %d back." % n_back)
			lines.append("The %s does not matter." % noun.to_lower())
		"both":
			lines.append("MATCH = same %s AND same COLOR as the card %d back." % [noun, n_back])
		_:
			lines.append("MATCH = same %s as the card %d back." % [noun, n_back])
			if num_colors > 1:
				lines.append("The color does not matter.")
	lines.append("")
	lines.append("Swipe RIGHT = match")
	lines.append("Swipe LEFT = no match")
	lines.append("")
	if n_back == 1:
		lines.append("The first card is just to watch.")
	else:
		lines.append("The first %d cards are just to watch." % n_back)
	lines.append("")
	lines.append("Cards: %s" % _categories_phrase())
	lines.append("N: %d" % n_back)
	lines.append("Duration: %s" % _fmt_secs(float(duration_sec)))
	return "\n".join(lines)

# The level's categories in plain English, for the intro line "Cards: ...". The player should not
# have to infer what they are about to be shown from the rule wording.
func _categories_phrase() -> String:
	var words: Array = []
	for c in _categories:
		match str(c):
			"shapes":
				words.append("shapes")
			"letters":
				words.append("letters")
			"digits":
				words.append("digits")
			"dinos":
				words.append("dinos")
			"people":
				words.append("faces")
			_:
				words.append(str(c))
	var joined: String = " and ".join(words)
	if num_colors > 1:
		joined += ", in %d colors" % num_colors
	# only the first letter — String.capitalize() would Title Case Every Word
	return joined.substr(0, 1).to_upper() + joined.substr(1)

# What the symbol dimension is CALLED on this level, so the rule text and the on-screen prompt
# both name the thing the player is actually looking at.
func _symbol_noun() -> String:
	var has_drawn: bool = false
	var kinds: Dictionary = {}
	for c in _categories:
		kinds[c] = true
		if DinobackG.is_drawn(c):
			has_drawn = true
	if not has_drawn:
		return "PICTURE"
	if kinds.size() == 1:
		match str(_categories[0]):
			"shapes":
				return "SHAPE"
			"letters":
				return "LETTER"
			"digits":
				return "DIGIT"
	return "SYMBOL"

func _on_game_popup_closed() -> void:
	if not game.level_is_done and not game.level_is_ready:
		# Re-layout now that play is about to start: on the very first level the initial _layout()
		# can run before the viewport size has settled, leaving the labels mispositioned.
		_layout()
		game.level_is_ready = true
		started_playing.emit()

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
	var def: Dictionary = DinobackLevelConfig.get_level(id)
	n_back = maxi(1, int(def.get("n_back", 1)))
	rule = str(def.get("rule", "symbol"))
	pool_size = maxi(2, int(def.get("pool_size", 4)))
	num_colors = maxi(1, int(def.get("num_colors", 1)))
	card_size_key = str(def.get("card_size", "med"))
	card_time_ms = float(def.get("card_time_sec", 4.0)) * 1000.0
	gap_ms = float(def.get("gap_sec", 0.6)) * 1000.0
	duration_sec = int(def.get("duration_sec", 60))
	target_rate = clampf(float(def.get("target_rate", 0.30)), 0.05, 0.6)
	lure_rate = clampf(float(def.get("lure_rate", 0.15)), 0.0, 0.6)
	partial_rate = clampf(float(def.get("partial_rate", 0.40)), 0.0, 0.9)

	# Six card sources crossed with three n-back depths: "2-back with faces" and "2-back with
	# shapes" are different tasks that would otherwise share nothing but a level number.
	game.set_task_signature({
		"source": str(def.get("source", "shapes")),
		"n_back": n_back,
		"rule": rule,
		"card_time_sec": float(def.get("card_time_sec", 4.0)),
	})

	_categories = []
	for part in str(def.get("source", "shapes")).split(","):
		var f: String = part.strip_edges()
		if f != "" and (DinobackG.is_drawn(f) or DinobackG.is_image(f)):
			_categories.append(f)
	if _categories.is_empty():
		_categories = ["shapes"]

	# A photograph has no color of its own, so a level built on images can only ever be matched on
	# identity. Correct the config rather than shipping a rule the cards cannot express.
	var has_image: bool = false
	for c in _categories:
		if DinobackG.is_image(c):
			has_image = true
	if has_image:
		num_colors = 1
		rule = "symbol"
	# ...and a rule needs at least two of whatever it reads, or no non-match could ever be built.
	if num_colors < 2 and rule != "symbol":
		rule = "symbol"
	num_colors = mini(num_colors, DinobackG.COLORS.size())

	var bgpath: String = DinobackG.background_for(_categories)
	if ResourceLoader.exists(bgpath):
		_bg.texture = load(bgpath)
		_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	# per-level time budget: the clock is (re)set each level. Runs after game.reset() in
	# main.new_game, so it takes precedence.
	game.set_reset_time_left(duration_sec)
	game.set_time_left(0, 0, duration_sec)
	# The HUD gets the number and N only. The long name is for the dropdown and the scores screen;
	# in-game, WHICH cards you are looking at is obvious from the screen, but N is not.
	game.level_label_changed("Level %d   N=%d" % [int(def.get("id", id)), n_back])

# The pool is SMALL and fixed for the level: that is what forces the player to track position
# instead of novelty. Drawn categories take the first `want` of their most-distinct-first list;
# image categories take a random subset, since all photos are equally distinct.
func _build_pool() -> void:
	_pool = []
	var n: int = maxi(1, _categories.size())
	var per: Array = []
	for _p in n:
		per.append(pool_size / n)
	for extra in (pool_size % n):
		per[extra] += 1
	for ci in n:
		var cat: String = str(_categories[ci])
		var want: int = int(per[ci])
		if DinobackG.is_drawn(cat):
			var syms: Array = DinobackG.symbols_of(cat)
			for k in mini(want, syms.size()):
				_pool.append({"cat": cat, "sym": str(syms[k]), "tex": null,
					"border": DinobackG.default_border(cat)})
		else:
			var idxs: Array = []
			for k in DinobackG.num_images(cat):
				idxs.append(k)
			idxs.shuffle()
			for k in mini(want, idxs.size()):
				_pool.append({"cat": cat, "sym": "", "tex": DinobackG.image_at(cat, int(idxs[k])),
					"border": DinobackG.default_border(cat)})
	if _pool.size() < 2:
		# never leave a level that cannot pose a non-match
		for s in DinobackG.SHAPES:
			if _pool.size() >= maxi(2, pool_size):
				break
			_pool.append({"cat": "shapes", "sym": str(s), "tex": null,
				"border": DinobackG.CARD_YELLOW})

# --- Sequence generation ----------------------------------------------------

func _rule_match(a: Dictionary, b: Dictionary) -> bool:
	match rule:
		"color":
			return int(a["col"]) == int(b["col"])
		"both":
			return int(a["item"]) == int(b["item"]) and int(a["col"]) == int(b["col"])
	return int(a["item"]) == int(b["item"])

func _random_trial() -> Dictionary:
	return {
		"item": game.rng.randi_range(0, _pool.size() - 1),
		"col": game.rng.randi_range(0, num_colors - 1),
	}

func _other_item(not_this: int) -> int:
	if _pool.size() < 2:
		return not_this
	var v: int = game.rng.randi_range(0, _pool.size() - 2)
	return v if v < not_this else v + 1

func _other_col(not_this: int) -> int:
	if num_colors < 2:
		return not_this
	var v: int = game.rng.randi_range(0, num_colors - 2)
	return v if v < not_this else v + 1

# Copy whatever the rule reads from `ref`; leave the rest random, so the distractor attribute
# keeps varying even on a match.
func _make_match(ref: Dictionary) -> Dictionary:
	var t: Dictionary = _random_trial()
	match rule:
		"color":
			t["col"] = int(ref["col"])
		"both":
			t["item"] = int(ref["item"])
			t["col"] = int(ref["col"])
		_:
			t["item"] = int(ref["item"])
	return t

# rule "both" only: matches EXACTLY ONE of symbol/color — the half-right card that is by far the
# easiest thing to answer wrongly.
func _make_partial(ref: Dictionary) -> Dictionary:
	var t: Dictionary = _random_trial()
	if game.rng.randf() < 0.5:
		t["item"] = int(ref["item"])
		t["col"] = _other_col(int(ref["col"]))
	else:
		t["col"] = int(ref["col"])
		t["item"] = _other_item(int(ref["item"]))
	return t

# rule "both": a clean non-match, differing in BOTH attributes. Needed as an explicit case —
# leaving it to _break_match produced a half-right card almost every time, which made `partial_rate`
# mean nothing (measured 0.67 against a configured 0.40).
func _make_neither(ref: Dictionary) -> Dictionary:
	return {"item": _other_item(int(ref["item"])), "col": _other_col(int(ref["col"]))}

# Force a trial to NOT match `ref`, by changing exactly the attribute the rule reads. Under "both"
# the symbol is changed, which deliberately leaves any color match standing as a partial lure.
func _break_match(t: Dictionary, ref: Dictionary) -> Dictionary:
	var out: Dictionary = t.duplicate()
	match rule:
		"color":
			out["col"] = _other_col(int(ref["col"]))
		"both":
			if _pool.size() >= 2:
				out["item"] = _other_item(int(ref["item"]))
			else:
				out["col"] = _other_col(int(ref["col"]))
		_:
			out["item"] = _other_item(int(ref["item"]))
	return out

# A neighboring position (N-1 or N+1 back). Repeating THAT card is the classic n-back lure: it
# feels exactly like a hit and is the main reason a 3-back is hard rather than merely slow.
func _lure_ref(i: int):
	var cands: Array = []
	for d in [n_back - 1, n_back + 1]:
		if d >= 1 and i - d >= 0:
			cands.append(_seq[i - d])
	if cands.is_empty():
		return null
	return cands[game.rng.randi_range(0, cands.size() - 1)]

func _next_trial() -> Dictionary:
	var i: int = _seq.size()
	if i < n_back:
		return _random_trial()          # priming: nothing to match against yet
	var ref: Dictionary = _seq[i - n_back]
	if tutorial_force_target == 1:
		return _make_match(ref)
	if tutorial_force_target == 0:
		var forced: Dictionary = _random_trial()
		if _rule_match(forced, ref):
			forced = _break_match(forced, ref)
		return forced
	if game.rng.randf() < target_rate:
		return _make_match(ref)
	# a non-match, optionally dressed up as a near miss
	var t: Dictionary
	var lure = _lure_ref(i)
	if lure != null and game.rng.randf() < lure_rate:
		t = _make_match(lure)
	elif rule == "both":
		# split explicitly, so partial_rate is the fraction of half-right cards it claims to be
		t = _make_partial(ref) if game.rng.randf() < partial_rate else _make_neither(ref)
	else:
		t = _random_trial()
	if _rule_match(t, ref):
		t = _break_match(t, ref)
	return t

# --- Card presentation ------------------------------------------------------

func _show_next_card() -> void:
	_clear_card()
	if _pool.is_empty():
		return
	var idx: int = _seq.size()
	var t: Dictionary = _next_trial()
	_seq.append(t)
	_cur_priming = idx < n_back
	_cur_is_target = (not _cur_priming) and _rule_match(t, _seq[idx - n_back])
	_answered = false

	var item: Dictionary = _pool[int(t["item"])]
	_card = CARD_SCRIPT.new()
	add_child(_card)
	var tex = item["tex"]
	var w: float
	if tex != null:
		# photographs keep their own aspect, so the whole image shows uncropped
		var asp: float = CARD_SCRIPT.ASPECT_H_OVER_W
		var ts: Vector2 = tex.get_size()
		if ts.x > 0.0 and ts.y > 0.0:
			asp = ts.y / ts.x
		_card.set_frame(8, CARD_INSET)
		_card.setup(tex, item["border"])
		w = maxf(minf(_card_avail_w, _card_avail_h / asp) * _card_frac, 60.0)
		_card.set_width(w)
	else:
		# a drawn face gets a square card and a symbol filling most of it
		_card.fit = CARD_SCRIPT.Fit.FILL
		_card.fixed_aspect = DRAWN_ASPECT
		_card.set_frame(8, CARD_INSET)
		_card.setup(null, item["border"])
		w = maxf(minf(_card_avail_w, _card_avail_h / DRAWN_ASPECT) * _card_frac, 60.0)
		_card.set_width(w)
		# child of the CARD, so the deal/swipe tweens carry it without knowing it exists
		var art = ART_SCRIPT.new()
		art.position = Vector2(-w * 0.5 + CARD_INSET, CARD_INSET)
		art.setup(str(item["cat"]), str(item["sym"]), DinobackG.color_at(int(t["col"])),
			Vector2(w - CARD_INSET * 2.0, w * DRAWN_ASPECT - CARD_INSET * 2.0))
		_card.add_child(art)

	var ch: float = _card.card_height()
	_card.position = Vector2(_card_center_x, _card_area_top + maxf(0.0, (_card_avail_h - ch) * 0.5))
	_card.rotation = 0.0
	_card.modulate = Color(1, 1, 1, 0)
	var tw: Tween = create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.12)
	_feedback.hide()
	_refresh_prompt()
	# a swipe must BEGIN during the current card — drop stale press state so a leftover release
	# cannot answer a fresh card
	_pressing = false
	_press_index = -2
	phase = Phase.SHOW
	_show_start_ms = game.game_time
	_phase_start_ms = game.game_time
	game.tutorial_notify("card_shown")   # no-op outside tutorial mode
	game.tutorial_notify("priming_card" if _cur_priming else "scored_card")
	if not _cur_priming:
		game.tutorial_notify("target_card" if _cur_is_target else "plain_card")

# Priming cards are shown for a shorter beat than a scored card: there is nothing to decide, only
# something to memorize, and a full card_time of staring at card 1 of 3 is dead air.
func _prime_ms() -> float:
	return clampf(card_time_ms * 0.55, 900.0, 2200.0)

func _refresh_prompt() -> void:
	if _cur_priming:
		# _seq already holds the card on screen, so this is how many priming cards FOLLOW it
		var left: int = maxi(0, n_back - _seq.size())
		_instruction.text = "Remember this card"
		if left > 0:
			_hint.text = "%d more, then you answer" % left
		else:
			_hint.text = "Answering starts on the next card"
	else:
		var noun: String = _symbol_noun()
		match rule:
			"color":
				_instruction.text = "Same COLOR as %d back?" % n_back
			"both":
				_instruction.text = "Same %s + COLOR as %d back?" % [noun, n_back]
			_:
				_instruction.text = "Same %s as %d back?" % [noun, n_back]
		_hint.text = "Swipe RIGHT = match    LEFT = no"
	var a: float = 0.45 if _cur_priming else 1.0
	_btn_no.modulate.a = a
	_btn_match.modulate.a = a

func _register_answer(said_match) -> void:
	# said_match: true (right/"Match"), false (left/"No"), or null (timed out)
	if phase != Phase.SHOW or _answered or _cur_priming:
		return
	var timed_out: bool = said_match == null
	if not timed_out and (game.game_time - _show_start_ms) < 150.0:
		return
	_answered = true
	var correct: bool = (not timed_out) and (bool(said_match) == _cur_is_target)
	if timed_out:
		game.record_no_answer()
	else:
		game.record_answer(bool(said_match), _cur_is_target)
	total_rounds += 1
	if _cur_is_target:
		targets_total += 1
	if correct:
		total_corrects += 1
		if _cur_is_target:
			targets_hit += 1
		var elapsed: float = game.game_time - _show_start_ms
		times_to_answer.append(maxf(elapsed, 0.0))
		while times_to_answer.size() > 20:
			times_to_answer.remove_at(0)
		var bonus: int = maxi(0, 8 - int(elapsed / 500.0))
		# A match is worth more than a pass. Only ~30% of cards are matches, so a player who
		# always answered "No" would otherwise bank most of the level's score for free.
		var base_pts: int = 10 if _cur_is_target else 5
		game.add_score_and_time(base_pts + bonus, 0)
		game.add_correct_or_mistake(1, 0)
		game.play_sound("correct")
		_feedback.text = "Match!" if _cur_is_target else "Correct"
		_feedback.add_theme_color_override("font_color", Color(0.25, 0.85, 0.35, 1.0))
	else:
		var penalty: int = mini(3, maxi(0, game.score))
		game.add_score_and_time(-penalty, 0)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("wrong")
		if timed_out:
			_feedback.text = "Too slow"
		elif _cur_is_target:
			_feedback.text = "Missed"
		else:
			_feedback.text = "Wrong"
		_feedback.add_theme_color_override("font_color", Color(0.9, 0.3, 0.25, 1.0))
	_feedback.show()
	game.tutorial_notify("answered")
	game.tutorial_notify("answered_right" if correct else "answered_wrong")
	MainGlobals.global_update_hud()
	_animate_card_out(said_match, timed_out)
	phase = Phase.FEEDBACK
	_phase_start_ms = game.game_time

func _animate_card_out(said_match, timed_out: bool) -> void:
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
		var dir: float = 1.0 if bool(said_match) else -1.0
		var target_x: float = card_ref.position.x + dir * (float(MainGlobals.screen_size.x) * 0.9)
		tw.tween_property(card_ref, "position:x", target_x, 0.28)
		tw.tween_property(card_ref, "rotation", dir * 0.28, 0.28)
		tw.tween_property(card_ref, "modulate:a", 0.0, 0.28)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(card_ref):
			card_ref.queue_free())

# A priming card is not answered, so it fades straight out with no swipe direction.
func _fade_card_out() -> void:
	if _card == null or not is_instance_valid(_card):
		_card = null
		return
	var card_ref = _card
	_card = null
	var tw: Tween = create_tween()
	tw.tween_property(card_ref, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func() -> void:
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
			if tutorial_hold_cards:
				return
			_show_next_card()
		Phase.SHOW:
			var span: float = _prime_ms() if _cur_priming else card_time_ms
			var frac: float = clampf(1.0 - (now - _show_start_ms) / span, 0.0, 1.0)
			_bar_fill.visible = true
			_bar_fill.size = Vector2(_bar_full_w * frac, _bar_h)
			if _cur_priming:
				# a neutral bar: it is a "look at this" countdown, not a deadline
				_bar_fill.color = Color(0.45, 0.62, 0.95, 1.0)
			else:
				_bar_fill.color = Color(0.9, 0.3, 0.25, 1.0).lerp(Color(0.3, 0.8, 0.4, 1.0), frac)
			if now - _show_start_ms >= span:
				if _cur_priming:
					_fade_card_out()
					phase = Phase.GAP
					_phase_start_ms = now
				else:
					_register_answer(null)
		Phase.FEEDBACK:
			_bar_fill.visible = false
			if now - _phase_start_ms >= FEEDBACK_MS:
				phase = Phase.GAP
				_phase_start_ms = now
				_feedback.hide()
		Phase.GAP:
			_bar_fill.visible = false
			if tutorial_hold_cards:
				return
			if now - _phase_start_ms >= gap_ms:
				_show_next_card()

# --- Input ------------------------------------------------------------------

func _on_no_pressed() -> void:
	_register_answer(false)

func _on_match_pressed() -> void:
	_register_answer(true)

func _input(event: InputEvent) -> void:
	if not _can_play() or phase != Phase.SHOW or _answered or _cur_priming:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# keyboard: Left = no, Right = match (matches swipe/buttons)
		if event.keycode == KEY_LEFT:
			_register_answer(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT:
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
		_register_answer(d.x > 0.0)  # right = match, left = no
		get_viewport().set_input_as_handled()

# --- Level completion -------------------------------------------------------

func _on_time_over() -> void:
	if game.level_is_done:
		return
	_level_done(true)

func _level_done(didwin: bool) -> void:
	if game.tutorial_mode:
		# The level's duration_sec running out mid-lesson would drop a level-completed popup on
		# top of the coach. A tutorial ends when the coach says so.
		return
	if game.level_is_done:
		return
	game.level_is_done = true
	_clear_card()
	_feedback.hide()
	game.sig_level_is_done.emit(didwin)  # main saves the level score
	if not didwin:
		sig_level_is_done.emit(false)
		return
	var pct: int = pct_correct()
	var need: int = int(DinobackLevelConfig.get_level(current_level_id).get("pass_pct", 70))
	# Passing is a RESULT, not a formality: below the level's own accuracy the SAME level comes
	# round again instead of the next one.
	var passed: bool = pct >= need
	MainGlobals.global_level_is_done(passed)
	if current_level_id >= DinobackLevelConfig.max_level():
		sig_level_is_done.emit(true)   # already at the top level — loop it, no popup
		return
	game.need_to_increase_level = passed   # a failed level is played again
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	# Plain accuracy flatters an n-back player, because ~70% of cards are not matches and "No" is
	# right by default. The hit count is the honest number, so it is shown next to it.
	var extra: String = "\n\nAccuracy: %d%%\nMatches found: %d/%d\nMean time: %s\n\n%s" % [
		pct_correct(), targets_hit, targets_total,
		("%d ms" % mean_response_time_ms()) if not times_to_answer.is_empty() else "N/A",
		_progress_line(passed, need)
	]
	game.show_level_done_popup(self, "", "", current_level_id, extra, passed)

# What the player gets next, in words. "Accuracy: 40%" alone does not say whether they are moving
# on, which is the only thing they want to know at that moment.
func _progress_line(passed: bool, need: int) -> String:
	if not passed:
		return "You need at least %d%% accuracy to pass to the next level." % need
	return "Level passed — on to level %d." % (current_level_id + 1)

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

# --- tutorial staging -------------------------------------------------------
#
# No freeze work is needed: _can_play() requires `not game.paused()`, and the card deadline is
# measured in game.game_time, which excludes paused time. A caption stops the stream AND the timer
# bar together.

func _tutorial_setup() -> void:
	tutorial_force_target = -1
	tutorial_hold_cards = false

# Let the stream run again after a caption has held it between cards.
func tutorial_release_cards() -> void:
	tutorial_hold_cards = false

# --- things for the coach to point at (all in SCREEN coordinates) -----------

func tutorial_card_rect() -> Rect2:
	if _card == null or not is_instance_valid(_card):
		return Rect2()
	var w: float = _card.card_width() if _card.has_method("card_width") else 160.0
	var h: float = _card.card_height()
	var c: Vector2 = (_card as Node2D).get_global_transform_with_canvas().origin
	return Rect2(c.x - w * 0.5, c.y, w, h)

func tutorial_has_card() -> bool:
	return _card != null and is_instance_valid(_card)

# The countdown bar: the deadline a first-timer does not know exists.
func tutorial_bar_rect() -> Rect2:
	if _bar_track == null or not is_instance_valid(_bar_track):
		return Rect2()
	return _bar_track.get_global_rect()

func tutorial_buttons_rect() -> Rect2:
	if _btn_no == null or not is_instance_valid(_btn_no):
		return Rect2()
	var r: Rect2 = _btn_no.get_global_rect()
	if _btn_match != null and is_instance_valid(_btn_match):
		r = r.merge(_btn_match.get_global_rect())
	return r

# True while the card on screen is one of the priming cards (no answer accepted).
func tutorial_is_priming() -> bool:
	return _cur_priming

# Whether the card on screen matches the one n_back ago — so a caption can say which it is instead
# of leaving the player to find out by being wrong.
func tutorial_is_target() -> bool:
	return _cur_is_target

func tutorial_n_back() -> int:
	return n_back

