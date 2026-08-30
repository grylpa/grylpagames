extends CanvasLayer

var game: GenericGameUtil
var current_level_id: int = 1

# Level-defined
var rounds_before_hide: int = 6
var num_rounds_per_level: int = 10
var window_duration: float = 2.5
var scroll_speed: float = 75.0

# Scoring / progress
var labels_hidden: bool = false
var rounds_done: int = 0
var total_rounds: int = 0
var total_corrects: int = 0
var _shown_yes: int = 0  # windowed items judged so far, by truth — used to balance yes/no spread
var _shown_no: int = 0
var times_to_answer: Array = []
var _score_at_level_start: int = 0
var _rollback_score_on_next_level: bool = false
var round_start_ms: float = 0.0
var _showing_feedback: bool = false
# The belt the last window was on, kept because a TIMEOUT discards the window before scoring and
# the flash still has to know which belt to wash.
var _last_belt: int = -1

var current_pair: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _all_modality_keys: Array = ["digit", "square", "even_odd", "vowel", "prime", "filled", "hollow", "stroop", "color_shape", "lines"]

# The pool of rule keys allowed for the CURRENT level (from level_config "rules"). The two shown
# rules are drawn from it at random each time the level loads, so which rules appear — and which
# side each one lands on — varies from play to play instead of always being the same two.
var _level_rules_pool: Array = []

# The rule pair used last time, so the next pick can avoid repeating it.
var _last_pair_keys: Array = []

# Two rules may only be shown together if NO single object can satisfy both — otherwise an item
# would legitimately belong to both sides and the "correct" answer is arbitrary. The pairs below
# genuinely overlap:
#   digit/even_odd/prime — "4" is a digit AND even; "3" is a digit AND prime AND odd
#   vowel/lines          — A, E, I are vowels AND straight-line letters
#   square/filled/color_shape — a ■ is a square AND filled; colored shapes are all filled glyphs
# (hollow is absent on purpose: hollow glyphs are disjoint from square, filled and color_shape.)
const _CONFUSABLE_WITH: Dictionary = {
	"digit": ["even_odd", "prime"],
	"even_odd": ["digit", "prime"],
	"prime": ["digit", "even_odd"],
	"vowel": ["lines"],
	"lines": ["vowel"],
	"square": ["filled", "color_shape"],
	"filled": ["square", "color_shape"],
	"color_shape": ["square", "filled"],
}

# Endless conveyor
var pair_font_size: int = 32
var item_h: float = 72.0
# The pitch between consecutive belt items is a MULTIPLE OF item_h, never a pixel range.
#
# It used to be a flat randf_range(80, 130) while item_h is 72 on desktop and 100 on mobile — so the
# gap between boxes was 8..58 on desktop and MINUS 20..30 on mobile, and the items overlapped each
# other vertically on every phone. The item grew for the bigger screen and the spacing that keeps
# items apart did not.
#
# The fractions reproduce the old desktop pixels exactly at item_h = 72 (72 x 1.111 = 80,
# 72 x 1.806 = 130), so the rhythm is unchanged there and merely scales with the item.
const PITCH_MIN: float = 1.111       # x item_h
const PITCH_MAX: float = 1.806
const STAGGER_MIN: float = 0.556     # x item_h, the second belt's head start
const STAGGER_MAX: float = 1.042

const ITEM_SPACING: float = 95.0
# Claw pick-up timing: the item is first popped slightly larger (the claw closing and lifting it
# off the belt), and only then yanked off the side.
const _GRAB_SCALE: float = 1.18
const _GRAB_TIME: float = 0.14
const _PULL_TIME: float = 0.55


var belt_items: Array = [[], []]  # each entry: {ctrl, truth_l, truth_r}
var belt_initialized: bool = false

# Window (highlight box that enters and exits from top/bottom with its item)
var window_panel: Panel = null
# The item the current verdict belongs to, captured by _discard_window() before it clears the
# window, since scoring happens after the window is gone.
var window_belt: int = -1
var window_open: bool = false        # accepting input
var window_rolling_out: bool = false # answered/timed-out but still scrolling to exit
var window_target_item: Control = null
var window_target_truth: bool = false
var window_timer: float = 0.0
var next_window_timer: float = 2.0

# The ✓/✗ overlay. Floated out of the vertical flow in _ready so it can sit exactly between the

var _swipe_start: Vector2 = Vector2.ZERO
var _swipe_tracking: bool = false

var _primes: Array = [2, 3, 5, 7, 11, 13, 17, 19, 23]
var _non_primes: Array = [1, 4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25]
var _straight_letters: Array = ["A", "E", "F", "H", "I", "K", "L", "M", "N", "T", "V", "W", "X", "Y", "Z"]
var _curved_letters: Array = ["B", "C", "D", "G", "J", "O", "P", "Q", "R", "S", "U"]
var _color_names: Array = ["RED", "BLUE", "GREEN", "YELLOW", "PURPLE"]
# Shared with the other two sorting games — see scripts/sleek.gd. The raw primaries these used to
# be (Color.RED is literally (1,0,0)) had no shading headroom and looked like debug placeholders.
# Item colors are compared for EQUALITY by the rule tests, so every color must come from here.
var _color_values: Dictionary = Sleek.PALETTE

var correct_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var wrong_audio = preload("res://art/sounds/swoosh.mp3")

signal sig_level_is_done(didwin: bool)
signal started_playing

# The belts and rule headers, restyled. The belts were the largest thing on screen and the
# flattest: a PanelContainer with one flat color, no border, no radius and no shadow.
# A factory FLOOR, drawn, in place of the tiled grass field this game shipped with.
#
# Top-down: the belts are conveyors seen from overhead, so the room has no horizon and no vanishing
# point — every seam is parallel and the only depth comes from light and wear. Drawing a wall
# meeting a floor, as the first attempt did, is a side-on view, and against top-down belts it read
# as a conveyor standing upright against a wall.
#
# The old TextureRect is hidden rather than deleted: the scene file still owns it, and hiding is
# reversible in a way that editing three .tscn files is not.
func _add_backdrop_depth() -> void:
	var bg = get_node_or_null("Background")
	var fb: FactoryFloor = FactoryFloor.new()
	fb.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fb)
	move_child(fb, 0)
	if bg != null:
		bg.visible = false

# The robots the game is named after. An overlay across the level rather than nodes in the layout:
# the belts sit in a tight HBox with no room beside them, and the arms have to hover OVER the belt
# edge anyway, which is where a top-down arm serving a conveyor would be.
var _robots: RobotBay = null

# Keeps each robot beside its belt. Done every frame from the belts' own rects because the layout
# resizes with the window and the belt height is computed at runtime (_size_belts).
func _position_robots() -> void:
	if _robots == null or not is_instance_valid(_robots):
		return
	var boxes: Array = [%LeftItemsContainer.get_parent(), %RightItemsContainer.get_parent()]
	var bays: Array = []
	for i in range(boxes.size()):
		var b = boxes[i]
		if b == null or not is_instance_valid(b):
			continue
		var r: Rect2 = Rect2(b.global_position - _robots.global_position, b.size)
		bays.append({"rect": r, "side": -1 if i == 0 else 1})
	_robots.bays = bays

func _apply_sleek_chrome() -> void:
	_add_backdrop_depth()
	for c in [%LeftItemsContainer, %RightItemsContainer]:
		var box = c.get_parent()
		if box is PanelContainer:
			(box as PanelContainer).add_theme_stylebox_override("panel", Sleek.belt())
			# A running tread UNDER the items. move_child(0) matters: a PanelContainer stretches
			# every child to fill it, so without this the tread would be painted over the objects.
			var tread: BeltTread = BeltTread.new()
			box.add_child(tread)
			box.move_child(tread, 0)
	_robots = RobotBay.new()
	_robots.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_robots)
	for lbl in [%LeftRuleLabel, %RightRuleLabel]:
		if lbl is Label:
			Sleek.header(lbl as Label)

func _ready() -> void:
	game = SortingRobotsG.game
	game.sig_time_over.connect(_on_time_over)
	game.add_sound(self, "correct", correct_audio)
	game.add_sound(self, "wrong", wrong_audio)
	_apply_sleek_chrome()
	var layout: MarginContainer = $MainLayout
	# ONE vertical layout for every platform: sit just under the header, reserve the app's bottom
	# button bar, and hand whatever is left to the belts (see _size_belts). The old fixed 150px
	# desktop top pad plus a hardcoded 420px belt made the content taller than the space actually
	# available, so the belts ran under the bottom bar. Nothing here is platform-specific any more
	# except the font/item sizes, which are about legibility rather than fit.
	var bar_h: float = 70.0 if MainGlobals.is_mobile() else 44.0
	var bottom_reserve: float = maxf(20.0, bar_h - MainGlobals.footer_height + 10.0)
	layout.offset_top = MainGlobals.header_height + 12.0
	layout.offset_bottom = -(MainGlobals.footer_height + bottom_reserve)
	var belt_w: float = 140.0
	if MainGlobals.is_mobile():
		pair_font_size = 48
		item_h = 100.0
		belt_w = 220.0
		%LeftRuleLabel.add_theme_font_size_override("font_size", 32)
		%RightRuleLabel.add_theme_font_size_override("font_size", 32)
		%AvgTimeLabel.add_theme_font_size_override("font_size", 36)
	# The old centre label is removed from the tree outright: the verdict is drawn on the framed
	# item (_mark_item), and an unused Label left in ContentVBox silently reserves its height.
	var old_feedback: Node = %FeedbackLabel
	old_feedback.get_parent().remove_child(old_feedback)
	old_feedback.queue_free()
	# Prose labels take the NO-FALLBACK face. The symbol font's line box is 2.09x the font size
	# (the Noto Symbols fallback is very tall and a Font's line height is the MAX over its
	# fallbacks), which on these WRAPPED rule labels nearly doubles the gap between lines --
	# "Shape is / blue or red?" reading as two separate captions. Only the tick/cross needs
	# symbols.
	var f: Font = MainGlobals.get_system_sans_font()
	var ft: Font = MainGlobals.get_text_font()
	%LeftRuleLabel.add_theme_font_override("font", ft)
	%RightRuleLabel.add_theme_font_override("font", ft)
	%AvgTimeLabel.add_theme_font_override("font", ft)
	# Fix both rule labels to a 2-line height so a 1-line and a 2-line rule
	# occupy the same space (bottom-aligned), keeping the two belts aligned.
	var rule_fs: int = 32 if MainGlobals.is_mobile() else 22
	var two_line_h: float = f.get_height(rule_fs) * 2.0 + 6.0
	%LeftRuleLabel.custom_minimum_size = Vector2(0, two_line_h)
	%RightRuleLabel.custom_minimum_size = Vector2(0, two_line_h)
	_size_belts(f, belt_w, two_line_h, layout)
	# 0, not -8: that was compensating for the symbol font's 2.09x line box, and these labels now
	# use the prose face, where it would squeeze the wrapped lines together instead.
	%LeftRuleLabel.add_theme_constant_override("line_spacing", 0)
	%RightRuleLabel.add_theme_constant_override("line_spacing", 0)
	%LeftItemsContainer.clip_contents = true
	%RightItemsContainer.clip_contents = true
	# Float the ✓/✗ out of the VBox flow so it can be positioned freely over the belts.
	_add_belt_edges()
	set_process(false)

# Give the belts exactly the height left after the status line and the rule labels, instead of a
# hardcoded 420/500. Derived from the space actually available, so the belts can never reach under
# the app's bottom button bar on any window size or platform.
func _size_belts(f: Font, belt_w: float, rule_h: float, layout: MarginContainer) -> void:
	# offset_bottom is negative, so adding it subtracts the reserved bottom space
	var layout_h: float = float(MainGlobals.full_screen_size.y) - layout.offset_top + layout.offset_bottom
	var content: VBoxContainer = $MainLayout/VBox/ContentVBox
	# Measure what ELSE is in the column instead of listing it by hand. A hand-written subtraction
	# misses a child the moment one is added or one stops being reparented away — which is exactly
	# how this went wrong: sortingrobots lifts its FeedbackLabel out of the flow in _ready, monkeyc
	# left it in at alpha 0, and the belt height copied across overshot by that label's height,
	# pushing the whole column up under the app's top bar.
	var used: float = 0.0
	var shown: int = 0
	for child in content.get_children():
		if child is Control and (child as Control).visible:
			shown += 1
			if (child as Control).name != "BoxesRow":
				used += (child as Control).get_combined_minimum_size().y
	var sep: float = float(content.get_theme_constant("separation")) * float(maxi(shown - 1, 0))
	# The rule label sits above the belt inside LeftSide/RightSide, with that VBox's own separation.
	var side_sep: float = float(
		$MainLayout/VBox/ContentVBox/BoxesRow/LeftSide.get_theme_constant("separation"))
	# floor keeps the belt playable on a very short window; below that the content simply clips
	var belt_h: float = maxf(200.0, layout_h - used - rule_h - side_sep - sep - 8.0)
	$MainLayout/VBox/ContentVBox/BoxesRow/LeftSide/LeftBox.custom_minimum_size = Vector2(belt_w, belt_h)
	$MainLayout/VBox/ContentVBox/BoxesRow/RightSide/RightBox.custom_minimum_size = Vector2(belt_w, belt_h)
func _add_belt_edges() -> void:
	var edge_script: Script = load("res://sortingrobots/scripts/belt_edge.gd")
	var boxes: Array = [
		$MainLayout/VBox/ContentVBox/BoxesRow/LeftSide/LeftBox,
		$MainLayout/VBox/ContentVBox/BoxesRow/RightSide/RightBox,
	]
	for box in boxes:
		# Zero the panel's content margins so children fill the full belt rect — the
		# edge strips then span the full belt width and meet the belt with no overlap.
		var sb: StyleBox = box.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var sbf: StyleBoxFlat = sb as StyleBoxFlat
			sbf.content_margin_left = 0.0
			sbf.content_margin_top = 0.0
			sbf.content_margin_right = 0.0
			sbf.content_margin_bottom = 0.0
		var edge: Control = Control.new()
		edge.set_script(edge_script)
		box.add_child(edge)

# --- Modality building ---

func _build_modality(key: String) -> Dictionary:
	match key:
		"digit":
			return {"key": key, "label": "Is it a digit?",
				"gen": func(ok): return _gen_digit_or_letter(ok),
				"make": func(item): return _make_text(item)}
		"square":
			return {"key": key, "label": "Is it a square?",
				"gen": func(ok): return _gen_shape(ok, ["■"], ["●", "▲", "★"]),
				"make": func(item): return _make_text(item)}
		"even_odd":
			var use_even: bool = rng.randi_range(0, 1) == 0
			return {"key": key, "label": "Is it even?" if use_even else "Is it odd?",
				"gen": func(ok): return _gen_even_odd(ok if use_even else !ok),
				"make": func(item): return _make_text(item)}
		"vowel":
			return {"key": key, "label": "Is it a vowel?",
				"gen": func(ok): return _gen_vowel_consonant(ok),
				"make": func(item): return _make_text(item)}
		"prime":
			return {"key": key, "label": "Is it prime?",
				"gen": func(ok): return _gen_prime_or_not(ok),
				"make": func(item): return _make_text(item)}
		"filled":
			return {"key": key, "label": "Is it a filled shape?",
				"gen": func(ok): return _gen_shape(ok, ["■","●","▲","★"], ["□","○","△","☆"]),
				"make": func(item): return _make_text(item)}
		"hollow":
			return {"key": key, "label": "Is it a hollow shape?",
				"gen": func(ok): return _gen_shape(ok, ["□","○","△","☆"], ["■","●","▲","★"]),
				"make": func(item): return _make_text(item)}
		"stroop":
			return {"key": key, "label": "Color = text color?",
				"gen": func(ok): return _gen_stroop(ok),
				"make": func(item): return _make_stroop(item)}
		"color_shape":
			return {"key": key, "label": "Shape is\nblue or red?",
				"gen": func(ok): return _gen_colored_shape(ok),
				"make": func(item): return _make_colored_shape(item)}
		"lines":
			return {"key": key, "label": "Letter is\nstraight lines?",
				"gen": func(ok): return _gen_straight_letter(ok),
				"make": func(item): return _make_text(item)}
	return {}

func _u(text: String) -> String:
	return text.to_upper() if SortingRobotsG.use_uppercase else text

func _gen_digit_or_letter(is_correct: bool) -> String:
	if is_correct:
		return str(rng.randi_range(1, 9))
	var letters: String = "ABCDEFGHJKLMNPQRSTUVWXYZ"
	return str(letters[rng.randi_range(0, letters.length() - 1)])

func _gen_even_odd(is_correct: bool) -> String:
	var n: int = rng.randi_range(1, 25)
	return str(n * 2 if is_correct else n * 2 - 1)

func _gen_vowel_consonant(is_correct: bool) -> String:
	var vowels: String = "AEIU"
	var consonants: String = "BCDFGHJKLMNPQRSTVWXYZ"
	var pool: String = vowels if is_correct else consonants
	return str(pool[rng.randi_range(0, pool.length() - 1)])

func _gen_prime_or_not(is_correct: bool) -> String:
	var pool: Array = _primes if is_correct else _non_primes
	return str(pool[rng.randi_range(0, pool.size() - 1)])

func _gen_shape(is_correct: bool, correct_shapes: Array, wrong_shapes: Array) -> String:
	var pool: Array = correct_shapes if is_correct else wrong_shapes
	return pool[rng.randi_range(0, pool.size() - 1)]

func _gen_straight_letter(is_correct: bool) -> String:
	var pool: Array = _straight_letters if is_correct else _curved_letters
	return pool[rng.randi_range(0, pool.size() - 1)]

func _gen_stroop(is_correct: bool) -> Dictionary:
	var word: String = _color_names[rng.randi_range(0, _color_names.size() - 1)]
	if is_correct:
		return {"text": word, "color": _color_values[word]}
	var others: Array = _color_names.filter(func(c): return c != word)
	var other: String = others[rng.randi_range(0, others.size() - 1)]
	return {"text": word, "color": _color_values[other]}

func _gen_colored_shape(is_correct: bool) -> Dictionary:
	var shapes: Array = ["■", "●", "▲", "★"]
	var shape: String = shapes[rng.randi_range(0, shapes.size() - 1)]
	if is_correct:
		return {"shape": shape, "color": [_color_values["BLUE"], _color_values["RED"]][rng.randi_range(0, 1)]}
	# Anything that is NOT the blue/red the rule accepts. Named, then looked up, so these stay the
	# same objects the equality test compares against.
	var others: Array = ["GREEN", "YELLOW", "PURPLE", "WHITE", "ORANGE"]
	return {"shape": shape, "color": _color_values[others[rng.randi_range(0, others.size() - 1)]]}

func _make_text(item: Variant) -> Label:
	# Shapes go through here too, not only through _make_colored_shape: the "square", "filled" and
	# "hollow" rules all generate bare glyphs. Converting only the colored-shape rule left three of
	# the four shape rules — and so most of what the player actually sees — as flat glyphs.
	var as_text: String = _u(str(item))
	if Sleek.is_shape(as_text):
		return ShapeLabel.make(as_text, Sleek.PALETTE["WHITE"], pair_font_size)
	var lbl: Label = Label.new()
	lbl.text = as_text
	lbl.add_theme_font_size_override("font_size", pair_font_size)
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Sleek.style_text(lbl)
	return lbl

func _make_stroop(item: Dictionary) -> Label:
	var lbl: Label = Label.new()
	lbl.text = _u(item["text"])
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Sleek.style_text(lbl, item["color"])
	return lbl

# Drawn, not typeset — see scripts/shape_label.gd. Still a Label, so the pair layout that measures
# both objects and shares the row width between them is untouched.
func _make_colored_shape(item: Dictionary) -> Label:
	return ShapeLabel.make(item["shape"], item["color"], pair_font_size)

# --- Pair layout ---
# Objects are sized to FIT. A stroop word ("YELLOW") is many times wider than a glyph, so splitting
# the item width 50/50 made the word spill over its half and collide with the other object. Instead
# the two objects share the width in proportion to how wide they actually are, and each font is
# shrunk until its text fits the share it got.

const _PAIR_GAP: float = 8.0
const _MIN_PAIR_FONT: int = 12

func _text_width(lbl: Label, font_size: int) -> float:
	var f: Font = lbl.get_theme_font("font")
	if f == null:
		f = MainGlobals.get_system_sans_font()
	return f.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

# Shrink the label's font until its text fits max_w. Returns the size actually used.
func _fit_label_width(lbl: Label, max_w: float, start_size: int) -> int:
	var fs: int = start_size
	while fs > _MIN_PAIR_FONT and _text_width(lbl, fs) > max_w:
		fs -= 1
	lbl.add_theme_font_size_override("font_size", fs)
	return fs

# Give each label a share of `total_w` proportional to its natural width, then fit its font to that
# share. Returns [width_l, width_r] — laid out with _PAIR_GAP between them.
func _share_pair_widths(lbl_l: Label, lbl_r: Label, total_w: float, base_size: int) -> Array:
	var avail: float = maxf(total_w - _PAIR_GAP, 20.0)
	var wl: float = _text_width(lbl_l, base_size)
	var wr: float = _text_width(lbl_r, base_size)
	var alloc_l: float = avail * 0.5
	var alloc_r: float = avail * 0.5
	if wl + wr > 0.0:
		# proportional share, but never starve one side below a readable sliver
		alloc_l = clampf(avail * (wl / (wl + wr)), avail * 0.18, avail * 0.82)
		alloc_r = avail - alloc_l
	_fit_label_width(lbl_l, alloc_l, base_size)
	_fit_label_width(lbl_r, alloc_r, base_size)
	return [alloc_l, alloc_r]

func _make_pair_control(item_l: Variant, mod_l: Dictionary, item_r: Variant, mod_r: Dictionary, bw: float) -> Control:
	var c: Control = Control.new()
	var lbl_l: Label = mod_l["make"].call(item_l)
	var lbl_r: Label = mod_r["make"].call(item_r)
	var shares: Array = _share_pair_widths(lbl_l, lbl_r, bw, pair_font_size)
	lbl_l.size = Vector2(shares[0], item_h)
	lbl_l.position = Vector2(0.0, 0.0)
	lbl_r.size = Vector2(shares[1], item_h)
	lbl_r.position = Vector2(shares[0] + _PAIR_GAP, 0.0)
	c.add_child(lbl_l)
	c.add_child(lbl_r)
	return c

func _containers() -> Array:
	return [%LeftItemsContainer, %RightItemsContainer]

# --- Endless conveyor ---

func _process(delta: float) -> void:
	_position_robots()
	_track_window_panel()
	if game.paused() or game.level_is_done:
		return
	if not belt_initialized:
		_init_belts()
		return
	_scroll_belts(delta)
	if game.tutorial_mode:
		_tutorial_settle_window()
	if window_open and not _showing_feedback:
		if window_target_item != null and is_instance_valid(window_target_item):
			var h: float = _containers()[window_belt].size.y
			var item_y: float = window_target_item.position.y
			if item_y >= h - item_h:
				# Out of time. Fired when the item reaches the BOTTOM of the belt, not after it has
				# left: it used to wait for item_y >= h, which is ~11 s after the window opened and
				# a moment when there is nothing on screen to attach the verdict to. The player let
				# an item go by and saw nothing for it.
				#
				# Marked exactly like an answer — the same red X on the item, the same red frame —
				# so a miss reads as a miss rather than as a silent score drop. _score_answer frees
				# the window afterwards, as on every other path.
				window_open = false
				_mark_item(false)
				_score_answer(false, true)
			else:
				if window_panel != null and is_instance_valid(window_panel):
					window_panel.position.y = item_y - 4.0
	elif window_rolling_out:
		_update_rolling_window()
	elif not window_open and not _showing_feedback and not window_rolling_out:
		next_window_timer -= delta
		if next_window_timer <= 0.0 and rounds_done < num_rounds_per_level:
			_open_window()

# --- tutorial: hold the belts once the framed item is in view --------------
#
# _open_window() deliberately frames an item that is still ABOVE the belt, so the frame slides in
# from the top with it. During a tutorial that puts the frame over the rule label for its first
# moments, and it reads as though the RULE is being framed. Worse, the belts keep moving while the
# player is reading the caption.
#
# So in tutorial mode the belts run on only until the framed item has cleared the rule label, and
# then everything stops until the judgment is made.
var tutorial_hold_belts: bool = false

# -1 = no preference (normal play). 0 or 1 makes the next framed item one that must be LEFT or
# TAKEN, so the tutorial can guarantee the player meets both answers.
var tutorial_want_truth: int = -1

func _tutorial_settle_window() -> void:
	if tutorial_hold_belts or not window_open:
		return
	if window_panel == null or not is_instance_valid(window_panel):
		return
	var lbl: Control = tutorial_rule_label(window_belt)
	var clear_y: float = 0.0
	if lbl != null and is_instance_valid(lbl):
		clear_y = lbl.global_position.y + lbl.size.y + 6.0
	if window_panel.global_position.y >= clear_y:
		tutorial_hold_belts = true
		game.tutorial_notify("window_settled")

func _scroll_belts(delta: float) -> void:
	if tutorial_hold_belts:
		return
	for si in 2:
		var container: Control = _containers()[si]
		var h: float = container.size.y
		var bw: float = container.size.x
		if h <= 0.0 or bw <= 0.0:
			continue
		var items: Array = belt_items[si]
		for entry in items:
			entry["ctrl"].position.y += scroll_speed * delta
		# Remove items that scrolled off the bottom
		var i: int = items.size() - 1
		while i >= 0:
			if items[i]["ctrl"].position.y >= h:
				items[i]["ctrl"].queue_free()
				items.remove_at(i)
			i -= 1
		# Find topmost item; add new items above with random spacing
		var top_y: float = h
		for entry in items:
			if entry["ctrl"].position.y < top_y:
				top_y = entry["ctrl"].position.y
		while top_y > -item_h:
			top_y -= item_h * rng.randf_range(PITCH_MIN, PITCH_MAX)
			items.append(_spawn_belt_item(si, top_y, bw))

func _init_belts() -> void:
	for si in 2:
		var container: Control = _containers()[si]
		var h: float = container.size.y
		var bw: float = container.size.x
		if h <= 0.0 or bw <= 0.0:
			return
		# Right belt starts with a vertical offset so the two belts are never aligned
		var y: float = -item_h if si == 0 else -item_h - item_h * rng.randf_range(STAGGER_MIN, STAGGER_MAX)
		while y < h + item_h:
			belt_items[si].append(_spawn_belt_item(si, y, bw))
			y += item_h * rng.randf_range(PITCH_MIN, PITCH_MAX)
	belt_initialized = true

func _spawn_belt_item(si: int, y: float, bw: float) -> Dictionary:
	var truth_l: bool = rng.randi_range(0, 1) == 1
	var truth_r: bool = rng.randi_range(0, 1) == 1
	var item_l: Variant = current_pair[0]["gen"].call(truth_l)
	var item_r: Variant = current_pair[1]["gen"].call(truth_r)
	var swapped: bool = rng.randi_range(0, 1) == 1
	var ctrl: Control
	if swapped:
		ctrl = _make_pair_control(item_r, current_pair[1], item_l, current_pair[0], bw)
	else:
		ctrl = _make_pair_control(item_l, current_pair[0], item_r, current_pair[1], bw)
	ctrl.size = Vector2(bw, item_h)
	ctrl.position = Vector2(0.0, y)
	_containers()[si].add_child(ctrl)
	return {"ctrl": ctrl, "truth_l": truth_l, "truth_r": truth_r}

func _open_window() -> void:
	var si: int = rng.randi_range(0, 1)
	var container: Control = _containers()[si]
	var bw: float = container.size.x
	# Only pick items that are still ABOVE the viewport (position.y < 0).
	# This ensures the window always enters from the top with its item.
	# balance the yes/no items the player actually judges: prefer an entering item whose truth
	# (for this belt) is the under-represented one so far, so it isn't "almost all no"
	var need_truth: int = -1
	if _shown_yes < _shown_no:
		need_truth = 1
	elif _shown_no < _shown_yes:
		need_truth = 0
	if tutorial_want_truth >= 0:
		need_truth = tutorial_want_truth
	var target_y: float = -item_h * 0.5
	var best_entry: Variant = null
	var best_dist: float = INF
	var any_entry: Variant = null
	var any_dist: float = INF
	for entry in belt_items[si]:
		var item_y: float = entry["ctrl"].position.y
		if item_y >= 0.0 or item_y < -item_h * 4.0:
			continue  # only items still entering from the top, not too far up
		var dist: float = abs(item_y - target_y)
		if dist < any_dist:
			any_dist = dist
			any_entry = entry
		var t: bool = entry["truth_l"] if si == 0 else entry["truth_r"]
		if (need_truth == -1 or int(t) == need_truth) and dist < best_dist:
			best_dist = dist
			best_entry = entry
	if best_entry == null and tutorial_want_truth < 0:
		best_entry = any_entry
	if best_entry == null:
		# Nothing of the required kind is entering yet; look again shortly.
		next_window_timer = 0.3
		return
	window_belt = si
	window_target_item = best_entry["ctrl"]
	window_target_truth = best_entry["truth_l"] if si == 0 else best_entry["truth_r"]
	if window_target_truth:
		_shown_yes += 1
	else:
		_shown_no += 1
	var pad: float = 4.0
	var panel: Panel = Panel.new()
	panel.z_index = 2
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 0.0, 0.18)
	sb.set_border_width_all(3)
	sb.border_color = Color(1.0, 0.9, 0.0, 1.0)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(bw, item_h + pad * 2.0)
	# Position exactly with the item — clip_contents hides it while above the container
	panel.position = Vector2(0.0, window_target_item.position.y - pad)
	container.add_child(panel)
	window_panel = panel
	window_open = true
	game.tutorial_notify("window_opened")   # no-op outside tutorial mode
	window_timer = window_duration
	round_start_ms = game.game_time

# --- tutorial staging -------------------------------------------------------

func _tutorial_setup() -> void:
	tutorial_hold_belts = false
	tutorial_want_truth = -1
	# No clock on the judgment and no automatic vanishing: both happen when the coach says so.
	# Judging against a 3 s window while reading a caption is not a fair introduction, and the
	# labels disappearing mid-explanation would land as a glitch rather than as the lesson.
	window_duration = 100000.0
	rounds_before_hide = 100000

# The frame, for the coach to point at.
func tutorial_window_panel() -> Control:
	return window_panel if window_panel != null and is_instance_valid(window_panel) else null

# Which belt the framed item is on, and that belt's rule as written on its label.
func tutorial_window_belt() -> int:
	return window_belt

func tutorial_rule_text(belt: int) -> String:
	if current_pair.size() < 2 or belt < 0 or belt > 1:
		return ""
	return _u(current_pair[belt].get("label", ""))

func tutorial_belt_name(belt: int) -> String:
	return "left" if belt == 0 else "right"

# Whether the framed item actually satisfies its belt's rule, so the coach can say which way to
# swipe rather than leaving a first-timer to guess on the very first one.
func tutorial_window_truth() -> bool:
	return window_target_truth

func tutorial_rule_label(belt: int) -> Control:
	return %LeftRuleLabel if belt == 0 else %RightRuleLabel

# The lesson the game is really about, on cue instead of six rounds in.
func tutorial_hide_labels_now() -> void:
	labels_hidden = true
	_hide_labels()
	game.tutorial_notify("labels_hidden")

# Keep the verdict frame ON the item while the verdict is up.
#
# The panel only followed the item while the window was ROLLING OUT; after an answer nothing moved
# it. That never showed before, because the panel used to be discarded the instant the player
# answered — now it lives through the 0.4 s of the verdict, and the belt keeps scrolling underneath,
# so a frame left at a fixed y slides off the item it belongs to.
#
# Not while the item is being carried off: _claw_pull reparents it into a flyer, and chasing a node
# in another coordinate space would throw the frame across the screen.
func _track_window_panel() -> void:
	if not _showing_feedback:
		return
	if window_panel == null or not is_instance_valid(window_panel):
		return
	if window_target_item == null or not is_instance_valid(window_target_item):
		return
	if window_belt < 0 or window_target_item.get_parent() != _containers()[window_belt]:
		return
	window_panel.position.y = window_target_item.position.y - 4.0

func _discard_window() -> void:
	if window_belt >= 0:
		_last_belt = window_belt
	window_open = false
	window_rolling_out = false
	if window_panel != null and is_instance_valid(window_panel):
		window_panel.queue_free()
		window_panel = null
	window_belt = -1
	window_target_item = null

func _update_rolling_window() -> void:
	if window_target_item == null or not is_instance_valid(window_target_item):
		# Item was freed (scrolled off via belt scroll) — score as timeout
		_discard_window()
		_score_answer(false, true)
		return
	if window_panel == null or not is_instance_valid(window_panel):
		window_rolling_out = false
		window_target_item = null
		window_belt = -1
		return
	var h: float = _containers()[window_belt].size.y
	var item_y: float = window_target_item.position.y
	if item_y >= h:
		# Window has fully exited — score the timeout now
		_discard_window()
		_score_answer(false, true)
		return
	window_panel.position.y = item_y - 4.0

func _clear_belts() -> void:
	for si in 2:
		for entry in belt_items[si]:
			if entry["ctrl"] != null and is_instance_valid(entry["ctrl"]):
				entry["ctrl"].queue_free()
		belt_items[si] = []
	if window_panel != null and is_instance_valid(window_panel):
		window_panel.queue_free()
		window_panel = null
	window_belt = -1
	window_open = false
	window_rolling_out = false
	window_target_item = null

# --- Game flow ---

func new_game(from_scratch: bool = true) -> void:
	game.level_is_done = false
	times_to_answer.clear()
	# EVERY level starts clean, not just the first. These count the level being graded — the gate
	# reads pct_correct() and the saved score row stores it — so leaving them to accumulate across
	# levels meant a replay of a failed level inherited the misses that failed it, and even a
	# flawless retry could not reach the threshold. (aliens has always done this; the other games
	# only did it `if from_scratch`.)
	total_rounds = 0
	total_corrects = 0
	game.corrects = 0
	game.mistakes = 0
	# The failed level's points go back HERE, with everything else, so the summary card is read
	# against the score the player had while playing it.
	if _rollback_score_on_next_level:
		_rollback_score_on_next_level = false
		game.score = _score_at_level_start
	# What the score was before this level. A failed level gives its points back (see _level_done):
	# without that, failing forever is a way to earn forever — every attempt banked its points and
	# the retry cost nothing.
	_score_at_level_start = game.score
	# Repaint here, where the clearing happens. Whether the HUD is refreshed AFTER the level is
	# rebuilt is up to each game's main.gd, and polkadots did not — so its counters read 0 while
	# the labels still showed the level the player had just failed.
	MainGlobals.global_update_hud()
	if from_scratch:
		SortingRobotsG.reset_queue_from(SortingRobotsG.starting_level_id)
	game.need_to_increase_level = false
	current_level_id = SortingRobotsG.pop_next_level_id()
	_load_level(current_level_id)
	rounds_done = 0
	labels_hidden = false
	_showing_feedback = false
	window_open = false
	window_rolling_out = false
	window_belt = -1
	next_window_timer = 2.0
	belt_initialized = false
	_clear_belts()
	_show_labels()
	_update_avg_label()
	game.level_is_ready = true
	started_playing.emit()
	set_process(true)

func _load_level(id: int) -> void:
	var def: Dictionary = SortingRobotsLevelConfig.get_level(id)
	rounds_before_hide = def.get("hide_after", 5)
	num_rounds_per_level = def.get("rounds", 12)
	window_duration = float(def.get("window_dur", 2.5))
	scroll_speed = float(def.get("belt_spd", 75))
	_level_rules_pool = def.get("rules", ["digit", "square"]).duplicate()
	_pick_pair_from_pool()
	if game.tutorial_mode:
		# After the level values are read, so it overrides them rather than being overwritten.
		_tutorial_setup()
	game.level_label_changed("Level " + str(def.get("name", id)))

# True if the two rule keys can be confused (an item could satisfy both), so they must never be
# the two shown rules at once.
func _are_confusable(a: String, b: String) -> bool:
	return _CONFUSABLE_WITH.get(a, []).has(b) or _CONFUSABLE_WITH.get(b, []).has(a)

# Pick this level's two shown rules from its pool: two DISTINCT, non-confusable rules in RANDOM
# order, so a given rule shows up on the left belt sometimes and on the right belt other times.
func _pick_pair_from_pool() -> void:
	var pool: Array = _level_rules_pool.duplicate()
	if pool.is_empty():
		pool = _all_modality_keys.duplicate()   # empty "rules" in level_config = use every rule
	if pool.size() < 2:
		pool = ["digit", "square"]
	pool.shuffle()
	# Prefer a pair different from last time so replaying a level (or wrapping around the
	# progression order) doesn't serve up the same two rules again; fall back to repeating only
	# when the pool offers no alternative.
	var chosen: Array = _find_rule_pair(pool, true)
	if chosen.is_empty():
		chosen = _find_rule_pair(pool, false)
	if chosen.is_empty():
		# every rule in the pool overlaps every other — author error; fall back rather than hang
		push_warning("level rule pool has no non-overlapping pair: %s" % str(pool))
		chosen = [pool[0], pool[1]]
	_last_pair_keys = [chosen[0], chosen[1]]
	current_pair = [_build_modality(chosen[0]), _build_modality(chosen[1])]


# Search the shuffled pool for a legal pair (no single object may satisfy both rules). When
# `avoid_last` is set, the pair used last time is skipped regardless of order.
func _find_rule_pair(pool: Array, avoid_last: bool) -> Array:
	for i in pool.size():
		for j in pool.size():
			if i == j or _are_confusable(pool[i], pool[j]):
				continue
			if avoid_last and _last_pair_keys.has(pool[i]) and _last_pair_keys.has(pool[j]):
				continue
			return [pool[i], pool[j]]
	return []

func _evaluate_answer(user_picks_up: bool) -> void:
	if not window_open or _showing_feedback or game.paused() or game.level_is_done:
		return
	# Judgment made: let the belts run again until the next item settles.
	tutorial_hold_belts = false
	window_open = false
	# The verdict lands on the framed item FIRST, while the highlight panel still exists — monkeyc's
	# order (_mark_item, then _take_item). Everything that made this game's version awkward came from
	# doing it the other way round: the panel was already freed, so the mark had to invent its own
	# frame at its own size, and it never matched the yellow one it was replacing.
	_mark_item(user_picks_up == window_target_truth)
	# correct pick-up → a robot claw yanks the item off the nearest side (left belt→left, right→right)
	if user_picks_up and user_picks_up == window_target_truth \
			and window_target_item != null and is_instance_valid(window_target_item):
		# remove from belt tracking, then the claw reparents & pulls the real item off its side
		var tgt: Control = window_target_item
		var bi: int = window_belt
		for i in range(belt_items[bi].size() - 1, -1, -1):
			if belt_items[bi][i]["ctrl"] == tgt:
				belt_items[bi].remove_at(i)
				break
		_claw_pull(window_belt == 1)
	# NOT discarded here any more: the mark lives on the highlight panel, so the panel has to
	# outlast the verdict. _score_answer frees it once the mark has been seen.
	_score_answer(user_picks_up, false)

func _claw_pull(to_right: bool) -> void:
	# Reparent the ACTUAL item (unchanged — looks exactly as on the belt) into a flyer, keep the
	# highlight RECTANGLE around it (border only, transparent fill, no ✓ overlay), and let a claw
	# grip its edge. The claw first POPS the item a little larger so the pick-up reads as physical,
	# and only then yanks it off the nearest side. It never freezes — the grab is a brief beat.
	var item: Control = window_target_item
	if item == null or not is_instance_valid(item):
		return
	var item_gpos: Vector2 = item.global_position
	var item_size: Vector2 = item.size
	if item_size.x < 1.0 or item_size.y < 1.0:
		item_size = Vector2(item_h, item_h)
	# The flyer's ORIGIN sits at the item's center so scaling it grows the item in place; with the
	# origin at (0,0) the scale-up would drag the item toward the canvas corner instead.
	var item_center: Vector2 = item_gpos + item_size * 0.5
	var flyer: Node2D = Node2D.new()
	flyer.z_index = 80
	flyer.position = item_center
	add_child(flyer)
	var panel: Panel = window_panel
	if panel != null and is_instance_valid(panel):
		for ch in panel.get_children():
			if ch is Label:
				ch.queue_free()  # drop the ✓/✗ so nothing covers the item
		var psb: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if psb != null:
			psb.border_color = Color(0.2, 0.9, 0.3)  # correct pick-up → green frame
			psb.bg_color = Color(psb.bg_color.r, psb.bg_color.g, psb.bg_color.b, 0.0)
		panel.reparent(flyer, true)  # keep the (green) border rectangle around the item
		window_panel = null
	item.reparent(flyer, true)  # keep global transform so the item doesn't jump/change
	# The ROBOT grips it — not a throwaway claw sprite parented to the flyer. It tracks this node's
	# real position every frame, so the arm is dragged along with the item as it is yanked off, and
	# retracts by itself once the flyer is freed. An arm that is not doing the picking is scenery.
	if _robots != null and is_instance_valid(_robots):
		_robots.hold(1 if to_right else 0, flyer)
	var sw: float = float(MainGlobals.screen_size.x)
	var dx: float = (sw + item_size.x + 80.0 - item_gpos.x) if to_right else (-(item_gpos.x + item_size.x + 560.0))
	var tw: Tween = flyer.create_tween()
	# 1) grip and lift — a quick pop, slightly overshooting, so it reads as being picked up
	tw.tween_property(flyer, "scale", Vector2(_GRAB_SCALE, _GRAB_SCALE), _GRAB_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2) then yank it off the side, still held at the lifted size
	tw.tween_property(flyer, "position:x", flyer.position.x + dx, _PULL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(flyer.queue_free)

# Put the ✓/✗ exactly between the two belts: horizontally centered in the gap that separates
# them, vertically at their shared center. Recomputed on each show so it follows any resize.
# The verdict, with some weight behind it.
#
# It was a label whose color changed and whose alpha went to 1 — the single least noticeable way to
# tell someone they got it wrong, on a screen where their eyes are on a belt somewhere else. It now
# punches in past its final size and settles, and the belt that was being judged flashes with it, so
# the answer is reported where the player was actually looking.
# The verdict, ON the item that was judged.
#
# It used to be a single label floated over the gap BETWEEN the two belts. Now that each belt hugs
# the inner edge of its half — so the robots have room outside them — that gap is gone, and there is
# nowhere in the centre for it to stand. monkeyc has always drawn its mark on the item itself
# (_mark_item), and it reads fine there, so this is the same treatment rather than a new idea:
# a label filling the window panel, over a tinted wash of the same colour.
# The verdict, stamped on the framed item. This is monkeyc's _mark_item()/_pop_mark(), which is the
# reference implementation of this idea in the project — ported rather than reinvented.
#
# The yellow highlight panel is RECOLOURED, not replaced: it keeps its exact rect, so the verdict
# frame lands precisely where the yellow one was. A separately drawn frame is always a slightly
# different size and reads as a second box.
func _mark_item(is_right: bool) -> void:
	if window_panel == null or not is_instance_valid(window_panel):
		return
	var col: Color = Color.GREEN if is_right else Color(1.0, 0.35, 0.0)
	var sb: StyleBoxFlat = window_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.border_color = col
		sb.bg_color = Color(col.r, col.g, col.b, 0.22)
	var indicator: Label = Label.new()
	indicator.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.size = window_panel.size
	indicator.text = "✓" if is_right else "✗"
	indicator.add_theme_font_size_override("font_size", 36)
	indicator.add_theme_color_override("font_color", col)
	window_panel.add_child(indicator)
	_pop_mark(indicator)

# The punch-in, on EVERY verdict: the glyph overshoots and settles, and the panel flinches with it.
# That small increase-decrease is the decision landing. Growing further is the PICK-UP, and that is
# the claw's job (_claw_pull) — not this.
func _pop_mark(indicator: Label) -> void:
	indicator.pivot_offset = indicator.size * 0.5
	indicator.scale = Vector2(0.3, 0.3)
	var tw: Tween = create_tween()
	tw.tween_property(indicator, "scale", Vector2(1.5, 1.5), 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(indicator, "scale", Vector2.ONE, 0.14)
	if window_panel != null and is_instance_valid(window_panel):
		window_panel.pivot_offset = window_panel.size * 0.5
		var tp: Tween = create_tween()
		tp.tween_property(window_panel, "scale", Vector2(1.18, 1.18), 0.11) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tp.tween_property(window_panel, "scale", Vector2.ONE, 0.17)

# A wash over the WHOLE belt the round was about, not a tint on its outline.
#
# The first version of this recolored the belt's 2px border and nothing else, which is invisible in
# practice — a flash you have to look for is not feedback. This floods the belt's fill with the
# verdict color, thickens its edge, and drains both back over half a second, so the machine the
# round was about visibly reacts.
func _flash_belt(belt: int, is_right: bool) -> void:
	if belt < 0 or belt > 1:
		return
	var cont: Control = _containers()[belt]
	if cont == null or not is_instance_valid(cont):
		return
	var box = cont.get_parent()
	if not (box is PanelContainer):
		return
	var sb: StyleBoxFlat = box.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		return
	var hit: Color = Color(0.25, 0.80, 0.42) if is_right else Color(0.88, 0.28, 0.26)
	sb.bg_color = Color(hit.r, hit.g, hit.b, 0.72)
	sb.border_color = hit.lightened(0.35)
	sb.set_border_width_all(6)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(sb, "bg_color", Sleek.BELT_FILL, 0.55)
	tw.tween_property(sb, "border_color", Sleek.BELT_EDGE, 0.55)
	tw.chain().tween_callback(func():
		sb.border_width_top = 3
		sb.border_width_bottom = 2
		sb.border_width_left = 2
		sb.border_width_right = 2)

func _score_answer(user_picks_up: bool, is_timeout: bool) -> void:
	if _showing_feedback or game.level_is_done:
		return
	_showing_feedback = true
	var elapsed: int = int(game.game_time - round_start_ms)
	var is_right: bool = not is_timeout and (user_picks_up == window_target_truth)
	total_rounds += 1
	rounds_done += 1
	game.tutorial_notify("judged_right" if is_right else "judged_wrong")   # no-ops outside tutorial
	game.tutorial_notify("judged")
	if is_right:
		total_corrects += 1
		times_to_answer.append(float(elapsed))
		while times_to_answer.size() > 20:
			times_to_answer.remove_at(0)
		var speed_bonus: int = max(0, 20 - elapsed / 100)
		game.add_score_and_time(10 + speed_bonus, 0)
		game.add_correct_or_mistake(1, 0)
		game.play_sound("correct")
		_update_avg_label()
	else:
		var penalty: int = min(3, game.score)
		game.add_score_and_time(-penalty, 0)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("wrong")
	# Every outcome washes the belt, including a timeout — which reaches here with the window
	# already discarded and the item scrolled off the bottom, so the wash is the ONLY thing there is
	# to see. Without it, letting an item go by looked like nothing had happened at all: the score
	# ticked down and the screen said nothing.
	_flash_belt(window_belt if window_belt >= 0 else _last_belt, is_right)
	if rounds_done >= rounds_before_hide and not labels_hidden:
		labels_hidden = true
		_hide_labels()
	await get_tree().create_timer(0.4).timeout
	_discard_window()
	_showing_feedback = false
	if game.level_is_done or game.paused():
		return
	if rounds_done >= num_rounds_per_level:
		_level_done()
		return
	next_window_timer = rng.randf_range(1.2, 2.5)

func _update_avg_label() -> void:
	if times_to_answer.is_empty():
		%AvgTimeLabel.text = "Average time : —"
	else:
		%AvgTimeLabel.text = "Average time : %d ms" % mean_response_time_ms()

func _show_labels() -> void:
	if current_pair.size() >= 2:
		%LeftRuleLabel.text = _u(current_pair[0].get("label", ""))
		%RightRuleLabel.text = _u(current_pair[1].get("label", ""))
	%LeftRuleLabel.modulate.a = 1.0
	%RightRuleLabel.modulate.a = 1.0

func _hide_labels() -> void:
	%LeftRuleLabel.modulate.a = 0.0
	%RightRuleLabel.modulate.a = 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start = event.position
			_swipe_tracking = true
		else:
			_swipe_tracking = false
	elif event is InputEventScreenDrag and _swipe_tracking:
		var delta: Vector2 = event.position - _swipe_start
		if delta.length() > 60.0:
			_swipe_tracking = false
			MainGlobals.swipe_was_drag = true
			if abs(delta.x) >= abs(delta.y):
				_evaluate_answer(delta.x > 0.0)
	if event.is_action_pressed("right") or event.is_action_pressed("ui_right"):
		_evaluate_answer(true)
	elif event.is_action_pressed("left") or event.is_action_pressed("ui_left"):
		_evaluate_answer(false)

func _level_done() -> void:
	set_process(false)
	game.level_is_done = true
	var pct: int = pct_correct()
	var need: int = SortingRobotsG.pass_pct_for(current_level_id)
	# Passing is now a RESULT, not a formality: below the level's own accuracy the same
	# level comes round again instead of the next one.
	var passed: bool = SortingRobotsG.record_level_result(current_level_id, pct)
	# A failed level earns nothing — but the player does not see it vanish while the summary is
	# still up. The score row IS written now (sig_level_is_done saves it), and it has to record the
	# score actually kept or failing repeatedly would farm the score list. So the kept value is put
	# in place just for the save, the screen keeps showing the level the player played, and the
	# rollback lands with everything else when they press Continue (see new_game).
	if not passed:
		var earned_this_level: int = game.score
		game.score = _score_at_level_start
		game.sig_level_is_done.emit(passed)
		game.score = earned_this_level
		_rollback_score_on_next_level = true
	else:
		game.sig_level_is_done.emit(passed)
	MainGlobals.global_level_is_done(passed)
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	# Just the number. The threshold is stated in full by the progress line below the table
	# ("You need at least NN% accuracy..."), so "(need NN%)" here said it twice; and on a level the
	# player passed, the bar they cleared is not something they need told.
	var extra: String = "\n\nAccuracy: %d%%\nMean time: %s" % [
		pct,
		("%d ms" % mean_response_time_ms()) if not times_to_answer.is_empty() else "N/A"
	]
	# Say what happens next, either way. "Accuracy: 40%" alone does not tell the player whether
	# they are moving on, which is the only thing they want to know at that moment.
	extra += "\n\n" + _progress_line(passed, need)
	# `passed` and the level id: this game can END a level without PASSING it, so the card must not
	# say "complete!" over a "you need at least NN%" line.
	game.show_level_done_popup(self, "", extra, current_level_id, "", passed)

# What the player gets next, in words.
func _progress_line(passed: bool, need: int) -> String:
	if not passed:
		return "You need at least %d%% accuracy to pass to the next level." % need
	var nxt: int = SortingRobotsG.peek_next_level_id()
	if nxt <= 0 or nxt == current_level_id:
		return "Level passed."
	return "Level passed — on to level %s." % SortingRobotsG.level_name_for(nxt)

func _on_level_done_popup_closed() -> void:
	sig_level_is_done.emit(true)

func _on_time_over() -> void:
	pass

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

func tick() -> void:
	pass
