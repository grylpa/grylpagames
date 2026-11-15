extends CanvasLayer

var game: GenericGameUtil
var current_level_id: int = 1

# Level-defined
var rounds_before_hide: int = 6
var num_rounds_per_level: int = 10
var scroll_speed: float = 75.0

# Scoring / progress
var labels_hidden: bool = false
var rounds_done: int = 0
var total_rounds: int = 0
var total_corrects: int = 0
var times_to_answer: Array = []
var _score_at_level_start: int = 0
var _rollback_score_on_next_level: bool = false
# The belt the last window was on, kept because a TIMEOUT discards the window before scoring and
# the flash still has to know which belt to wash.

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
const PITCH_MIN: float = 1.04        # x item_h (parcels, 2026-11-02: they are taller than the tiles were,
									 # so the old 1.111-1.806 left too few items on the belt)
const PITCH_MAX: float = 1.30
const STAGGER_MIN: float = 0.556     # x item_h, the second belt's head start
const STAGGER_MAX: float = 1.042

const ITEM_SPACING: float = 95.0

# QUALITY CONTROL (2026-11-15). Both belts run continuously through a SCANNER line; each parcel is in
# question while it is inside its belt's SCANNER GATE (scanner_gate.gd, fixed at the belt's middle and
# steadily lit), and the player
# TAPS the belt to grab it when it passes that belt's rule, or lets it ride. Parcels come at irregular
# spacing on both belts, so calls come every second or two and often nearly together on both sides:
# the rule to apply switches with the belt the parcel is on -- the task-switching experiment this game
# rests on (the stimulus's PLACE cues the task, Rogers & Monsell 1995), now at a pace. It replaced one
# framed parcel at a time and a swipe, with long watching in between ("still a boring game").
const SCAN_FRAC: float = 0.50             # the scanner gate's middle, as a share of the belt's height
const GATE_H: float = 1.25                # x item_h: the gate's opening, along the belt
const SCAN_HALF: float = 0.475            # x item_h: a parcel is IN the gate while its middle is this near
										  # the gate's middle (mostly inside it)
const GATE_SCRIPT: GDScript = preload("res://sortingrobots/scripts/scanner_gate.gd")
const QC_PITCH_MIN: float = 1.15          # x item_h: parcel spacing on a belt, irregular
const QC_PITCH_MAX: float = 2.70
const SPEED_UP: float = 1.12              # the staircase on the belts' speed
const SPEED_DOWN: float = 0.88
const SPEED_STREAK: int = 3
const SPEED_MIN: float = 0.65             # x the level's belt_spd
const SPEED_MAX: float = 2.10
const SWAP_SHOW_MS: float = 2200.0        # the signs come back up this long after a swap
const SPEED_REF_ITEM_H: float = 140.0     # belt_spd is set for a parcel this tall (desktop)
const REJECT_POINTS: int = 2              # letting a non-matching parcel ride: right, but a quiet one
var _speed_mul: float = 1.0
var _speed_streak: int = 0
var _belt_rule: Array = [0, 1]            # which of the pair's rules each belt asks (swaps)
var _swap_ms: float = 0.0                 # 0 = no swaps on this level
var _next_swap_at: float = 0.0
var _show_until_ms: float = 0.0           # signs up again after a swap, until then
var _prev_judged_belt: int = -1
var _rt_switch: Array = []                # grab times after a judgment on the OTHER belt
var _rt_repeat: Array = []                # and after one on the same belt
var _gates: Array = []                    # the scanner gate on each belt (scanner_gate.gd)
var _go_total: int = 0                    # parcels that matched their belt's rule (to grab) ...
var _go_hit: int = 0                      # ... and how many were grabbed
var _nogo_total: int = 0                  # parcels that did not (to let ride) ...
var _nogo_cr: int = 0                     # ... and how many were let ride
# Claw pick-up timing: the item is first popped slightly larger (the claw closing and lifting it
# off the belt), and only then yanked off the side.
const _GRAB_SCALE: float = 1.18
const _GRAB_TIME: float = 0.14
const _PULL_TIME: float = 0.55


var belt_items: Array = [[], []]  # each entry: {ctrl, truth_l, truth_r}
var belt_initialized: bool = false

# Left from the framed-item version (before Quality Control): window_target_item / window_panel are
# what _claw_pull grips, set for the moment of a grab; the rest stays only for _clear_belts.
var window_panel: Panel = null
var window_target_item: Control = null

# The ✓/✗ overlay. Floated out of the vertical flow in _ready so it can sit exactly between the


var _primes: Array = [2, 3, 5, 7, 11, 13, 17, 19, 23]
var _non_primes: Array = [1, 4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25]
var _straight_letters: Array = ["A", "E", "F", "H", "I", "K", "L", "M", "N", "T", "V", "W", "X", "Y", "Z"]
var _curved_letters: Array = ["B", "C", "D", "G", "J", "O", "P", "Q", "R", "S", "U"]
var _color_names: Array = ["RED", "BLUE", "GREEN", "YELLOW", "PURPLE"]
# Shared with the other two sorting games — see scripts/sleek.gd. The raw primaries these used to
# be (Color.RED is literally (1,0,0)) had no shading headroom and looked like debug placeholders.
# Item colors are compared for EQUALITY by the rule tests, so every color must come from here.
var _color_values: Dictionary = Sleek.PALETTE

# Right / wrong made for this game (devtools/make_answer_sounds.py); they replaced an arcade coin and a swoosh.
var correct_audio = preload("res://art/sounds/sortingrobots_right.ogg")
var wrong_audio = preload("res://art/sounds/sortingrobots_wrong.ogg")

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
# The depot floor; told where the belts are (_position_robots) for its lane lines and pallets.
var _floor: FactoryFloor = null

func _add_backdrop_depth() -> void:
	var bg = get_node_or_null("Background")
	var fb: FactoryFloor = FactoryFloor.new()
	_floor = fb
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
	if _floor != null and is_instance_valid(_floor):
		var rects: Array = []
		for i2 in range(boxes.size()):
			var b2 = boxes[i2]
			if b2 != null and is_instance_valid(b2) and (b2 as Control).is_visible_in_tree():
				rects.append(Rect2((b2 as Control).global_position - _floor.global_position, (b2 as Control).size))
		_floor.belts = rects

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
			# ...and the housings over both ends, ABOVE the items: parcels come out from under the top
			# one and go back under the bottom one (scripts/belt_hood.gd). Same belt in both games.
			box.add_child(BeltHood.new())
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
	# the robot arm is heard taking an item (devtools/make_action_sounds.py, "robot")
	game.add_sound(self, "grab", preload("res://art/sounds/robot_grab.ogg"))
	game.set_sound_volume("grab", -3.0)
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
	var belt_w: float = 225.0     # a turned parcel, its side showing, with cards that read (was 140, for tiles)
	if MainGlobals.is_mobile():
		pair_font_size = 48
		belt_w = 310.0
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
	# An item is a parcel framed at ParcelArt.ASPECT (height / width); the belt's own width sets it.
	item_h = ceilf(belt_w * ParcelArt.ASPECT)
	# 0, not -8: that was compensating for the symbol font's 2.09x line box, and these labels now
	# use the prose face, where it would squeeze the wrapped lines together instead.
	%LeftRuleLabel.add_theme_constant_override("line_spacing", 0)
	%RightRuleLabel.add_theme_constant_override("line_spacing", 0)
	%LeftItemsContainer.clip_contents = true
	%RightItemsContainer.clip_contents = true
	# Float the ✓/✗ out of the VBox flow so it can be positioned freely over the belts.
	set_process(false)

# Give the belts exactly the height left after the status line and the rule labels, instead of a
# hardcoded 420/500. Derived from the space actually available, so the belts can never reach under
# the app's bottom button bar on any window size or platform.
func _size_belts(_f: Font, belt_w: float, rule_h: float, layout: MarginContainer) -> void:
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
	var shp: String = shapes[rng.randi_range(0, shapes.size() - 1)]
	if is_correct:
		return {"shape": shp, "color": [_color_values["BLUE"], _color_values["RED"]][rng.randi_range(0, 1)]}
	# Anything that is NOT the blue/red the rule accepts. Named, then looked up, so these stay the
	# same objects the equality test compares against.
	var others: Array = ["GREEN", "YELLOW", "PURPLE", "WHITE", "ORANGE"]
	return {"shape": shp, "color": _color_values[others[rng.randi_range(0, others.size() - 1)]]}

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

# THE PAIR IS A PARCEL (scripts/parcel_art.gd): one cardboard box, the two items on two equal cards on
# its lid. The modality builders still make the Labels they always made; only what each one SAYS --
# its text or shape, and its color -- is handed to the parcel, so the rules and generators are
# untouched.
func _make_pair_control(item_l: Variant, mod_l: Dictionary, item_r: Variant, mod_r: Dictionary, bw: float) -> Control:
	var lbl_l: Label = mod_l["make"].call(item_l)
	var lbl_r: Label = mod_r["make"].call(item_r)
	var c: ParcelArt = ParcelArt.make(self, Vector2(bw, item_h), _item_desc(lbl_l), _item_desc(lbl_r), rng.randi())
	lbl_l.free()
	lbl_r.free()
	return c

func _item_desc(lbl: Label) -> Dictionary:
	if lbl is ShapeLabel:
		return {"shape": lbl.text, "color": (lbl as ShapeLabel).base_color}
	return {"text": lbl.text, "color": lbl.get_theme_color("font_color"), "font": lbl.get_theme_font("font")}

func _containers() -> Array:
	return [%LeftItemsContainer, %RightItemsContainer]

# --- Endless conveyor ---

func _process(delta: float) -> void:
	_position_robots()
	if game.paused() or game.level_is_done:
		return
	if not belt_initialized:
		_init_belts()
		return
	_scroll_belts(delta)
	_update_scanner()
	_update_rule_swap()

# --- tutorial: hold the belts when a parcel reaches the scanner ---------------
#
# With `tutorial_hold_at_scanner` set, the belts stop the moment a parcel reaches the scanner gate's middle, so
# the coach can talk about it while it sits there (`qc_held`); judging it lets them run again.
var tutorial_hold_belts: bool = false
var tutorial_hold_at_scanner: bool = false
var _tutorial_held: Array = []            # [belt, entry] of the parcel the belts stopped for

# -1 = no preference (normal play). 0 or 1 makes the parcels that come (for the rule of the belt
# they are on) ones to LET RIDE or to GRAB, so the tutorial can guarantee both answers.
var tutorial_want_truth: int = -1

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
			entry["ctrl"].position.y += scroll_speed * _speed_mul * (item_h / SPEED_REF_ITEM_H) * delta
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
			top_y -= item_h * rng.randf_range(QC_PITCH_MIN, QC_PITCH_MAX)
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
		# ONLY ABOVE THE BELT: the parcels enter from the top. Filling the whole belt at the start made
		# them pop in one by one at random places as their pictures finished rendering (ParcelArt).
		while y < 0.0:
			belt_items[si].append(_spawn_belt_item(si, y, bw))
			y += item_h * rng.randf_range(QC_PITCH_MIN, QC_PITCH_MAX)
	belt_initialized = true

func _spawn_belt_item(si: int, y: float, bw: float) -> Dictionary:
	var truth_l: bool = rng.randi_range(0, 1) == 1
	var truth_r: bool = rng.randi_range(0, 1) == 1
	if game.tutorial_mode and tutorial_want_truth >= 0:
		truth_l = tutorial_want_truth == 1
		truth_r = truth_l
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
	return {"ctrl": ctrl, "truth_l": truth_l, "truth_r": truth_r, "live": false, "done": false, "enter_ms": 0.0}

func _tutorial_setup() -> void:
	tutorial_hold_belts = false
	tutorial_hold_at_scanner = false
	tutorial_want_truth = -1
	_tutorial_held = []
	# No vanishing labels on their own: that happens when the coach says so.
	rounds_before_hide = 100000

# The parcel the belts are holding at the scanner, for the coach to point at, its belt, and whether
# it passes that belt's rule (so the coach can say "grab it" or "let it ride").
func tutorial_held_parcel() -> Control:
	if _tutorial_held.is_empty():
		return null
	var ctrl = _tutorial_held[1]["ctrl"]
	return ctrl if ctrl != null and is_instance_valid(ctrl) else null

func tutorial_held_belt() -> int:
	return int(_tutorial_held[0]) if not _tutorial_held.is_empty() else 0

func tutorial_held_truth() -> bool:
	return _truth_on(tutorial_held_belt(), _tutorial_held[1]) if not _tutorial_held.is_empty() else false

# Let the held parcel ride on: the belts run again and it is judged as it leaves the gate.
func tutorial_release() -> void:
	tutorial_hold_belts = false

func tutorial_rule_text(belt: int) -> String:
	if current_pair.size() < 2 or belt < 0 or belt > 1:
		return ""
	return _u(current_pair[int(_belt_rule[belt])].get("label", ""))

func tutorial_belt_name(belt: int) -> String:
	return "left" if belt == 0 else "right"

func tutorial_rule_label(belt: int) -> Control:
	return %LeftRuleLabel if belt == 0 else %RightRuleLabel

# The lesson the game is really about, on cue instead of six rounds in.
func tutorial_hide_labels_now() -> void:
	labels_hidden = true
	_hide_labels()
	game.tutorial_notify("labels_hidden")

func _clear_belts() -> void:
	for si in 2:
		for entry in belt_items[si]:
			if entry["ctrl"] != null and is_instance_valid(entry["ctrl"]):
				entry["ctrl"].queue_free()
		belt_items[si] = []
	if window_panel != null and is_instance_valid(window_panel):
		window_panel.queue_free()
		window_panel = null
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
	_speed_mul = 1.0
	_speed_streak = 0
	_belt_rule = [0, 1]
	_prev_judged_belt = -1
	_rt_switch.clear()
	_rt_repeat.clear()
	for g2 in _gates:
		if is_instance_valid(g2):
			(g2 as Node2D).visible = true
	_go_total = 0
	_go_hit = 0
	_nogo_total = 0
	_nogo_cr = 0
	_show_until_ms = 0.0
	_next_swap_at = game.game_time + _swap_ms if _swap_ms > 0.0 else INF
	rounds_done = 0
	labels_hidden = false
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
	scroll_speed = float(def.get("belt_spd", 75))
	_swap_ms = float(def.get("swap_sec", 0.0)) * 1000.0
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

# A short NOUN for the stats screen. The option/rule labels are questions ("Is it a digit?"),
# which read badly as a row heading, and even_odd's wording flips between "even" and "odd" while
# the rule behind it is one thing. The name travels with the trial so the shared stats code needs
# to know nothing about this game's vocabulary.
const RULE_NAMES: Dictionary = {
	"digit": "Digit", "square": "Square", "even_odd": "Even or odd", "vowel": "Vowel",
	"prime": "Prime", "filled": "Filled shape", "hollow": "Hollow shape",
	"stroop": "Color matches word", "color_shape": "Blue or red", "lines": "Straight lines",
}

func _rule_display(key: String) -> String:
	return str(RULE_NAMES.get(key, key.capitalize()))

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
	game.play_sound("grab")
	var sw: float = float(MainGlobals.screen_size.x)
	var dx: float = (sw + item_size.x + 80.0 - item_gpos.x) if to_right else (-(item_gpos.x + item_size.x + 560.0))
	var tw: Tween = flyer.create_tween()
	# 0) the arm reaches out to it first (RobotBay.REACH_TIME); the item waits for the gripper
	tw.tween_interval(RobotBay.REACH_TIME)
	# 1) grip and lift — a quick pop, slightly overshooting, so it reads as being picked up
	tw.tween_property(flyer, "scale", Vector2(_GRAB_SCALE, _GRAB_SCALE), _GRAB_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2) then yank it off the side, still held at the lifted size
	tw.tween_property(flyer, "position:x", flyer.position.x + dx, _PULL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(flyer.queue_free)

func _update_avg_label() -> void:
	if times_to_answer.is_empty():
		%AvgTimeLabel.text = "Average time : —"
	else:
		%AvgTimeLabel.text = "Average time : %d ms" % mean_response_time_ms()

func _show_labels() -> void:
	if current_pair.size() >= 2:
		%LeftRuleLabel.text = _u(current_pair[int(_belt_rule[0])].get("label", ""))
		%RightRuleLabel.text = _u(current_pair[int(_belt_rule[1])].get("label", ""))
	%LeftRuleLabel.modulate.a = 1.0
	%RightRuleLabel.modulate.a = 1.0

func _hide_labels() -> void:
	%LeftRuleLabel.modulate.a = 0.0
	%RightRuleLabel.modulate.a = 0.0

# TAP A BELT to grab the parcel at its scanner (left half / right half of the screen, or the arrow
# keys). Not tapping lets it ride. (It used to be a swipe right/left on one framed item.)
func _input(event: InputEvent) -> void:
	if game.paused() or game.level_is_done:
		return
	if event is InputEventScreenTouch and event.pressed:
		var b: int = _belt_at(event.position)
		if b >= 0:
			_tap_belt(b)
	elif event.is_action_pressed("left") or event.is_action_pressed("ui_left"):
		_tap_belt(0)
	elif event.is_action_pressed("right") or event.is_action_pressed("ui_right"):
		_tap_belt(1)

# Which belt a screen point falls on: the half of the screen it is in, below the rule signs.
func _belt_at(screen_pos: Vector2) -> int:
	var c0: Control = _containers()[0]
	if c0 == null or screen_pos.y < c0.get_global_rect().position.y - item_h:
		return -1
	return 0 if screen_pos.x < float(MainGlobals.screen_size.x) * 0.5 else 1

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
	var cost: int = switch_cost_ms()
	if cost != NO_SWITCH_COST:
		extra += "\nSwitch cost: %d ms" % cost
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
	return "Level passed. On to level %s." % SortingRobotsG.level_name_for(nxt)

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

# BALANCED accuracy (2026-11-15): the mean of the share of MATCHES grabbed and the share of
# NON-MATCHES let ride. Letting a non-match ride is a right answer, and about half the parcels are
# non-matches, so plain accuracy gave a player who never tapped ~50% and random tapping ~59% --
# within reach of a pass. Balanced, both of those are 50% (chance), whatever the mix.
func pct_correct() -> int:
	if _go_total == 0 and _nogo_total == 0:
		return 0
	var hit: float = float(_go_hit) / float(maxi(1, _go_total)) if _go_total > 0 else 1.0
	var cr: float = float(_nogo_cr) / float(maxi(1, _nogo_total)) if _nogo_total > 0 else 1.0
	if _go_total == 0:
		hit = cr
	if _nogo_total == 0:
		cr = hit
	return roundi(100.0 * (hit + cr) * 0.5)

func tick() -> void:
	pass

# --- Quality control: the scanner -------------------------------------------------------------

# Each frame: a parcel whose middle comes within SCAN_HALF of the gate's middle becomes the one in
# question on its belt (lit); one that has passed it unjudged is resolved as LET RIDE.
func _update_scanner() -> void:
	for b in 2:
		var h: float = _containers()[b].size.y
		if h <= 0.0:
			continue
		_place_gate(b, h)
		var scan_y: float = h * SCAN_FRAC
		for entry in belt_items[b]:
			if bool(entry["done"]):
				continue
			var ctrl: Control = entry["ctrl"]
			if ctrl == null or not is_instance_valid(ctrl):
				continue
			var mid: float = ctrl.position.y + item_h * 0.5
			if not bool(entry["live"]):
				if absf(mid - scan_y) <= item_h * SCAN_HALF and mid <= scan_y:
					entry["live"] = true
					entry["enter_ms"] = game.game_time
					game.tutorial_notify("qc_live")
			elif game.tutorial_mode and tutorial_hold_at_scanner and mid >= scan_y:
				tutorial_hold_at_scanner = false
				tutorial_hold_belts = true
				_tutorial_held = [b, entry]
				game.tutorial_notify("qc_held")
			elif mid - scan_y > item_h * SCAN_HALF:
				_resolve(b, entry, false)

# The scanner GATE on each belt, at its middle, over the parcels: lit amber while a parcel is in it.
func _place_gate(b: int, h: float) -> void:
	while _gates.size() <= b:
		var g: Node2D = GATE_SCRIPT.new()
		g.z_index = 6
		add_child(g)
		_gates.append(g)
	var c: Control = _containers()[b]
	var r: Rect2 = c.get_global_rect()
	var top: float = r.position.y + h * SCAN_FRAC - item_h * GATE_H * 0.5
	# each housing as wide as the space beside the belt allows: the INNER side (where the two belts
	# meet) gets just under half the gap, so the two gates do not overlap in the middle
	var other: Rect2 = _containers()[1 - b].get_global_rect()
	var gap: float = (other.position.x - r.end.x) if b == 0 else (r.position.x - other.end.x)
	var inner_room: float = maxf(2.0, gap * 0.5 - 2.0)
	var room: Vector2 = Vector2(16.0, inner_room) if b == 0 else Vector2(inner_room, 16.0)
	(_gates[b] as Node2D).call("place", r, top, item_h * GATE_H, room)

# The parcel in question on belt b (the one nearest the gate's middle, if two are close), or null.
func _live_entry(b: int):
	var best = null
	var best_d: float = INF
	var scan_y: float = _containers()[b].size.y * SCAN_FRAC
	for entry in belt_items[b]:
		if bool(entry["live"]) and not bool(entry["done"]):
			var d: float = absf(entry["ctrl"].position.y + item_h * 0.5 - scan_y)
			if d < best_d:
				best_d = d
				best = entry
	return best

func _tap_belt(b: int) -> void:
	var entry = _live_entry(b)
	if entry == null:
		return                         # nothing at the scanner: a tap there costs nothing
	_resolve(b, entry, true)

func _truth_on(b: int, entry: Dictionary) -> bool:
	return bool(entry["truth_l"]) if int(_belt_rule[b]) == 0 else bool(entry["truth_r"])

# A parcel judged: TAPPED (grab) or let ride. The four outcomes -- a grab of a match (the claw takes
# it), a let-ride of a non-match (a quiet right), a grab of a non-match and a let-ride of a match
# (both misses, stamped red on the parcel).
func _resolve(b: int, entry: Dictionary, tapped: bool) -> void:
	if bool(entry["done"]) or game.level_is_done:
		return
	entry["done"] = true
	entry["live"] = false
	tutorial_hold_belts = false
	var ctrl: Control = entry["ctrl"]
	var truth: bool = _truth_on(b, entry)
	var right: bool = tapped == truth
	var ms: int = int(game.game_time - float(entry["enter_ms"]))
	var switched: bool = _prev_judged_belt >= 0 and _prev_judged_belt != b
	game.record_answer(tapped, truth)
	var rk: String = str(current_pair[int(_belt_rule[b])].get("key", ""))
	game.record_trial({"rule": rk, "rule_name": _rule_display(rk), "right": right, "hidden": labels_hidden,
		"ms": ms if tapped else 0, "belt": b, "switch": switched, "go": truth})
	if tapped and right:
		(_rt_switch if switched else _rt_repeat).append(float(ms))
	_prev_judged_belt = b
	if truth:
		_go_total += 1
		if tapped:
			_go_hit += 1
	else:
		_nogo_total += 1
		if not tapped:
			_nogo_cr += 1
	total_rounds += 1
	rounds_done += 1
	game.tutorial_notify("judged_right" if right else "judged_wrong")
	game.tutorial_notify("judged")
	if not tapped:
		game.tutorial_notify("qc_rode")       # let ride: an answer the player gives by NOT tapping
	if right:
		total_corrects += 1
		game.add_correct_or_mistake(1, 0)
		if tapped:
			times_to_answer.append(float(ms))
			while times_to_answer.size() > 20:
				times_to_answer.remove_at(0)
			game.add_score_and_time(10 + maxi(0, 20 - ms / 100), 0)
			game.play_sound("correct")
			if ctrl != null and is_instance_valid(ctrl):
				belt_items[b].erase(entry)
				window_target_item = ctrl
				window_panel = null
				_claw_pull(b == 1)
				window_target_item = null
			_update_avg_label()
		else:
			game.add_score_and_time(REJECT_POINTS, 0)
			_tick_let_ride(ctrl)
	else:
		game.add_score_and_time(-mini(3, game.score), 0)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("wrong")
		if ctrl is ParcelArt and is_instance_valid(ctrl):
			(ctrl as ParcelArt).stamp(false)
	_adapt_speed(right)
	if rounds_done >= rounds_before_hide and not labels_hidden:
		labels_hidden = true
		_hide_labels()
	if rounds_done >= num_rounds_per_level:
		_level_done()

# The STAIRCASE on the belts: three right in a row, faster; any miss, slower.
func _adapt_speed(right: bool) -> void:
	if game.tutorial_mode:
		return
	if right:
		_speed_streak += 1
		if _speed_streak >= SPEED_STREAK:
			_speed_streak = 0
			_speed_mul = minf(SPEED_MAX, _speed_mul * SPEED_UP)
	else:
		_speed_streak = 0
		_speed_mul = maxf(SPEED_MIN, _speed_mul * SPEED_DOWN)

# RULE SWAPS (levels with swap_sec): the two belts trade rules, a banner says so and the signs come
# back up for SWAP_SHOW_MS -- then, if they were hidden, hide again: the player has to remember the
# new arrangement (Aliens' gate change, in the depot).
func _update_rule_swap() -> void:
	var now: float = game.game_time
	if _show_until_ms > 0.0 and now >= _show_until_ms:
		_show_until_ms = 0.0
		if labels_hidden:
			_hide_labels()
	if _swap_ms <= 0.0 or game.tutorial_mode or now < _next_swap_at:
		return
	_next_swap_at = now + _swap_ms * rng.randf_range(0.8, 1.2)
	_belt_rule = [_belt_rule[1], _belt_rule[0]]
	_show_labels()
	_show_until_ms = now + SWAP_SHOW_MS
	game.play_sound("grab")
	var banner: Label = Label.new()
	banner.text = "RULES SWAPPED"
	banner.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(banner, 30)
	banner.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30))
	banner.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	banner.add_theme_constant_override("outline_size", 10)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(float(MainGlobals.screen_size.x), 60.0)
	banner.position = Vector2(0.0, float(MainGlobals.screen_size.y) * 0.40)
	banner.z_index = 90
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	var tw: Tween = banner.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)
	tw.tween_callback(banner.queue_free)

const NO_SWITCH_COST: int = -99999

# How much slower a right GRAB is just after a judgment on the other belt than after one on the same
# belt: the task-switching research's own measure. NO_SWITCH_COST until both have a few.
func switch_cost_ms() -> int:
	if _rt_switch.size() < 3 or _rt_repeat.size() < 3:
		return NO_SWITCH_COST
	var a: float = 0.0
	for t in _rt_switch:
		a += t
	var c: float = 0.0
	for t2 in _rt_repeat:
		c += t2
	return roundi(a / _rt_switch.size() - c / _rt_repeat.size())

# A RIGHT LET-RIDE is shown too (2026-11-15): a small green tick and the points float up from the parcel
# as it leaves the scanner and fade within half a second. Before, the +2 landed with nothing on screen,
# so a correct "no" felt like nothing had happened. Quieter than a miss's stamp, and silent: about half
# the parcels earn one.
func _tick_let_ride(ctrl: Control) -> void:
	if ctrl == null or not is_instance_valid(ctrl):
		return
	var lbl: Label = Label.new()
	lbl.text = "✓ +%d" % REJECT_POINTS
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	MainGlobals.set_font_size(lbl, 20)
	lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.05))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 70
	var r: Rect2 = ctrl.get_global_rect()
	lbl.position = r.get_center() - Vector2(28.0, 14.0)
	add_child(lbl)
	var tw: Tween = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 26.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.55).set_delay(0.15)
	tw.chain().tween_callback(lbl.queue_free)
