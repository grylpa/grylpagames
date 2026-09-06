extends CanvasLayer

var game: GenericGameUtil
var current_level_id: int = 1

var rounds_before_hide: int = 6
var num_rounds_per_level: int = 10
var fall_duration: float = 2.5
var preview_time: float = 4.0

# category: 0=matches left rule, 1=matches right rule, 2=neither (dumpster)
# correct_bucket: 0=left, 1=center(dumpster), 2=right
var active_category: int = 0
var correct_bucket: int = 0

var fall_item_node: Control = null
var fall_tween: Tween = null
# The answered item's slide into its bucket. Kept so it can be paused with everything else — a
# Tween runs on its own clock and ignores game.paused() unless something stops it.
var _slide_tween: Tween = null
var item_answered: bool = false

var round_start_ms: float = 0.0
var labels_hidden: bool = false
var rounds_done: int = 0
var waiting_for_input: bool = false

var times_to_answer: Array = []
var _score_at_level_start: int = 0
var _rollback_score_on_next_level: bool = false
var total_rounds: int = 0
var total_corrects: int = 0

var current_pair: Array = []

var _all_modality_keys: Array = ["digit", "square", "even_odd", "vowel", "prime", "filled", "hollow", "stroop", "color_shape", "lines"]

# The pool of rule keys allowed for the CURRENT level (from level_config "rules"). The two shown
# rules are drawn from it at random each time the level loads, so which rules appear — and which
# bucket each one lands on — varies from play to play instead of always being the same two.
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

# The containers are DRAWN (scripts/bucket_view.gd), not sprites. The shipped PNGs looked like they
# came from a different game to everything else on screen — and `bucket_closed` / `bucket_open_*`
# turned out not to be frames of one bucket at all, so swapping between them read as the bucket
# being replaced rather than opening.

var _trap_poly: Polygon2D = null
var _chute: ChuteView = null
var _stage: BucketStage = null
# The three bucket pictures, in board order [left, dumpster, right]. They are built at runtime by
# _setup_bucket_images and have no scene names, so anything wanting to point at a bucket — the
# tutorial — needs them kept here.
var _bucket_images: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _primes: Array = [2, 3, 5, 7, 11, 13, 17, 19, 23]
var _non_primes: Array = [1, 4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25]
var _straight_letters: Array = ["A", "E", "F", "H", "I", "K", "L", "M", "N", "T", "V", "W", "X", "Y", "Z"]
var _curved_letters: Array = ["B", "C", "D", "G", "J", "O", "P", "Q", "R", "S", "U"]
var _color_names: Array = ["RED", "BLUE", "GREEN", "YELLOW", "PURPLE"]
# Shared with the other two sorting games — see scripts/sleek.gd. The raw primaries these used to
# be (Color.RED is literally (1,0,0)) had no shading headroom and looked like debug placeholders.
# Item colors are compared for EQUALITY by the rule tests, so every color must come from here.
var _color_values: Dictionary = Sleek.PALETTE

var item_font_size: int = 52
var pair_font_size: int = 36
var item_w: float = 140.0
var item_h: float = 88.0

var correct_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var wrong_audio = preload("res://art/sounds/swoosh.mp3")

var _swipe_start: Vector2 = Vector2.ZERO
var _swipe_tracking: bool = false

signal sig_level_is_done(didwin: bool)
signal started_playing

# The rule headers, restyled to match the other two sorting games: a chip that belongs to the
# bucket under it rather than bare yellow text floating on grass.
# A factory, drawn, in place of the tiled grass field these games shipped with — a field, in three
# games about machines sorting objects on conveyors. It is the largest single thing on screen, so
# nothing done to the widgets on top of it changes what the screen looks like.
#
# The old TextureRect is hidden rather than deleted: the scene file still owns it, and hiding is
# reversible in a way that editing three .tscn files is not.
func _add_backdrop_depth() -> void:
	var bg = get_node_or_null("Background")
	var fb: FactoryBackdrop = FactoryBackdrop.new()
	fb.horizon = 0.74
	fb.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fb)
	move_child(fb, 0)
	if bg != null:
		bg.visible = false

func _apply_sleek_chrome() -> void:
	_add_backdrop_depth()
	# The ground the buckets stand on. Added straight after the backdrop so it sits UNDER the
	# buckets themselves, which live inside MainLayout further down the tree.
	_stage = BucketStage.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	move_child(_stage, 1)
	for n in ["LeftRuleLabel", "RightRuleLabel", "DumpsterLabel"]:
		var lbl = get_node_or_null("MainLayout/VBox/ContentVBox/BucketsRow/LeftBucketSide/" + n)
		if lbl == null:
			lbl = get_node_or_null("MainLayout/VBox/ContentVBox/BucketsRow/RightBucketSide/" + n)
		if lbl == null:
			lbl = get_node_or_null("MainLayout/VBox/ContentVBox/BucketsRow/CenterBucketSide/" + n)
		if lbl is Label:
			Sleek.header(lbl as Label)

func _ready() -> void:
	_apply_sleek_chrome()
	game = BucketMadnessG.game
	game.sig_time_over.connect(_on_time_over)
	game.add_sound(self, "correct", correct_audio)
	game.add_sound(self, "wrong", wrong_audio)
	var layout: MarginContainer = $MainLayout
	layout.offset_top = 100.0 if MainGlobals.is_mobile() else 150.0
	layout.offset_bottom = -(MainGlobals.footer_height + 15.0)
	if MainGlobals.is_mobile():
		item_font_size = 68
		pair_font_size = 48
		item_w = 180.0
		item_h = 110.0
		%LeftRuleLabel.add_theme_font_size_override("font_size", 26)
		%RightRuleLabel.add_theme_font_size_override("font_size", 26)
		%DumpsterLabel.add_theme_font_size_override("font_size", 26)
		%AvgTimeLabel.add_theme_font_size_override("font_size", 36)
	# Prose labels take the NO-FALLBACK face. The symbol font's line box is 2.09x the font size
	# (the Noto Symbols fallback is very tall and a Font's line height is the MAX over its
	# fallbacks), which on these WRAPPED rule labels nearly doubles the gap between lines --
	# "Shape is / blue or red?" reading as two separate captions. Only the tick/cross needs
	# symbols.
	var f: Font = MainGlobals.get_system_sans_font()
	var ft: Font = MainGlobals.get_text_font()
	%LeftRuleLabel.add_theme_font_override("font", ft)
	%RightRuleLabel.add_theme_font_override("font", ft)
	%DumpsterLabel.add_theme_font_override("font", ft)
	%AvgTimeLabel.add_theme_font_override("font", ft)
	%FeedbackLabel.add_theme_font_override("font", f)
	%FallArea.clip_contents = true
	_chute = ChuteView.new()
	%FallArea.add_child(_chute)
	%FallArea.move_child(_chute, 0)
	_trap_poly = Polygon2D.new()
	# The flat trapezoid is kept as the base fill under the drawn chute, so nothing shows through
	# at the edges where the two disagree by a pixel.
	_trap_poly.color = Sleek.BELT_FILL
	%FallArea.add_child(_trap_poly)
	%FallArea.move_child(_trap_poly, 0)
	%FallArea.resized.connect(_update_trapezoid)
	call_deferred("_update_trapezoid")
	_setup_bucket_images()
	set_process(true)

func _update_trapezoid() -> void:
	if _trap_poly == null or not is_instance_valid(_trap_poly):
		return
	var sz: Vector2 = %FallArea.size
	if sz.x < 10.0 or sz.y < 10.0:
		return
	var w: float = sz.x
	var h: float = sz.y
	var top_inset: float = maxf((w - item_w - 20.0) * 0.5, 10.0)
	_trap_poly.polygon = PackedVector2Array([
		Vector2(top_inset, 0.0),
		Vector2(w - top_inset, 0.0),
		Vector2(w, h),
		Vector2(0.0, h)
	])
	if _chute != null and is_instance_valid(_chute):
		_chute.size = sz
		_chute.position = Vector2.ZERO
		_chute.top_inset = top_inset

func _process(_delta: float) -> void:
	# "item_dropped" fires the moment a round starts, when the item is still one full item-height
	# ABOVE the fall area — clipped, invisible, and nothing a caption can point at. This is the
	# event that means it has arrived somewhere the player can see it.
	if not _tut_notified_ready and _tutorial_should_hold():
		_tut_notified_ready = true
		game.tutorial_notify("item_ready")
	# is_instance_valid() is NOT enough: a Tween that has run to the end is still a live object, but
	# play() on it errors ("Can't play finished Tween"). Tween.is_valid() is the one that goes false
	# when it finishes or was built outside the tree, and _process runs every frame after the item
	# has landed — so this fired continuously once a round's animation completed.
	_position_stage()
	_drive_tween(_slide_tween, game.paused())
	_drive_tween(fall_tween, game.paused() or _tutorial_should_hold())

# Pause or resume a tween that may already have finished. Kept in one place because both of this
# game's tweens are driven every frame from _process to follow the game's own paused state.
func _drive_tween(tw: Tween, want_paused: bool) -> void:
	if tw == null or not is_instance_valid(tw) or not tw.is_valid():
		return
	if want_paused:
		if tw.is_running():
			tw.pause()
	elif not tw.is_running():
		tw.play()

# Godot has no is_dead(): a tween that has run to the end still reports is_valid() == true, and
# is_running() == false is indistinguishable from "paused". The only reliable way not to call
# play() on a finished tween is to stop holding a reference to one — so every tween this game
# drives from _process clears its own variable the moment it finishes.
func _forget_when_done(tw: Tween, which: String) -> void:
	if tw == null:
		return
	tw.finished.connect(func():
		if which == "fall" and fall_tween == tw:
			fall_tween = null
		elif which == "slide" and _slide_tween == tw:
			_slide_tween = null)

# The bucket the item went into reacts to catching it. Nothing on this screen moved on a drop
# except a tick appearing in a label — the buckets themselves sat perfectly still whether the
# player was right or wrong, which is most of why the game felt inert.
#
# A right answer is a quick squash-and-settle, as though something landed in it. A wrong one is a
# short shake. Both are driven from the bucket's own center so it does not slide out of its row.
# Shut once the caught item has visibly gone in, not the instant it is judged.
func _shut_buckets_after() -> void:
	await get_tree().create_timer(0.45).timeout
	if is_inside_tree() and not game.level_is_done:
		_set_buckets_open(false)

# Keeps the stage under the buckets. From their live rects because the row is laid out by a
# container and resizes with the window.
func _position_stage() -> void:
	if _stage == null or not is_instance_valid(_stage):
		return
	var rs: Array = []
	for img in _bucket_images:
		if img != null and is_instance_valid(img):
			rs.append(Rect2(img.global_position - _stage.global_position, img.size))
	_stage.rects = rs

func _bucket_react(bucket: int, is_right: bool) -> void:
	if bucket < 0 or bucket >= _bucket_images.size():
		return
	var img: Control = _bucket_images[bucket]
	if img == null or not is_instance_valid(img):
		return
	img.pivot_offset = img.size * 0.5
	var tw: Tween = create_tween()
	if is_right:
		img.modulate = Color(1.35, 1.35, 1.2)
		tw.tween_property(img, "scale", Vector2(1.14, 0.86), 0.09)
		tw.tween_property(img, "scale", Vector2(0.96, 1.06), 0.10)
		tw.tween_property(img, "scale", Vector2.ONE, 0.12)
		tw.parallel().tween_property(img, "modulate", Color.WHITE, 0.22)
	else:
		var x: float = img.position.x
		tw.tween_property(img, "position:x", x - 7.0, 0.05)
		tw.tween_property(img, "position:x", x + 7.0, 0.08)
		tw.tween_property(img, "position:x", x, 0.07)

# Only the container the item is actually going into opens.
#
# All three used to open the moment an item was released, which says nothing: no choice has been
# made yet, so three containers gaping at once is just movement. The one that opens is the one
# answering for this item.
func _set_buckets_open(open: bool) -> void:
	for img in _bucket_images:
		_tween_open(img, 0.0 if not open else 1.0)

func _open_one(idx: int) -> void:
	for i in range(_bucket_images.size()):
		_tween_open(_bucket_images[i], 1.0 if i == idx else 0.0)

func _tween_open(img, amount: float) -> void:
	if not (img is BucketView) or not is_instance_valid(img):
		return
	if absf(img.open_amount - amount) < 0.01:
		return
	var tw: Tween = create_tween()
	tw.tween_property(img, "open_amount", amount, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _setup_bucket_images() -> void:
	var sides: Array = [
		$MainLayout/VBox/ContentVBox/BucketsRow/LeftBucketSide,
		$MainLayout/VBox/ContentVBox/BucketsRow/CenterBucketSide,
		$MainLayout/VBox/ContentVBox/BucketsRow/RightBucketSide
	]
	var min_heights: Array = [125, 160, 125]
	for i in 3:
		var v: BucketView = BucketView.new()
		v.is_dumpster = (i == 1)
		# Above the flying item (z 4), so an item entering the mouth is occluded by the front wall.
		v.z_index = 8
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.custom_minimum_size = Vector2(0, min_heights[i])
		sides[i].add_child(v)
		sides[i].move_child(v, 0)
		_bucket_images.append(v)

# --- Modality building (same as rlmadness) ---

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
	return text.to_upper() if BucketMadnessG.use_uppercase else text

func _gen_digit_or_letter(is_correct: bool) -> String:
	if is_correct:
		return str(rng.randi_range(1, 9))
	var letters: String = "ABCDEFGHJKLMNPQRSTUVWXYZ"
	return str(letters[rng.randi_range(0, letters.length() - 1)])

func _gen_even_odd(is_correct: bool) -> String:
	var n: int = rng.randi_range(1, 25)
	return str(n * 2 if is_correct else n * 2 - 1)

func _gen_vowel_consonant(is_correct: bool) -> String:
	var pool: String = "AEIU" if is_correct else "BCDFGHJKLMNPQRSTVWXYZ"
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
	return {"text": word, "color": _color_values[others[rng.randi_range(0, others.size() - 1)]]}

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
		return ShapeLabel.make(as_text, Sleek.PALETTE["WHITE"], item_font_size)
	var lbl: Label = Label.new()
	lbl.text = as_text
	lbl.add_theme_font_size_override("font_size", item_font_size)
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Sleek.style_text(lbl)
	return lbl

func _make_stroop(item: Dictionary) -> Label:
	var lbl: Label = Label.new()
	lbl.text = _u(item["text"])
	lbl.add_theme_font_size_override("font_size", 44)
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Sleek.style_text(lbl, item["color"])
	return lbl

# Drawn, not typeset — see scripts/shape_label.gd. Still a Label, so the pair layout that measures
# both objects and shares the row width between them is untouched.
func _make_colored_shape(item: Dictionary) -> Label:
	return ShapeLabel.make(item["shape"], item["color"], item_font_size)

func _make_pair_control(item_a: Variant, mod_a: Dictionary, item_b: Variant, mod_b: Dictionary) -> Control:
	var c: Control = Control.new()
	var lbl_a: Label = mod_a["make"].call(item_a)
	var lbl_b: Label = mod_b["make"].call(item_b)
	var shares: Array = _share_pair_widths(lbl_a, lbl_b, item_w, pair_font_size)
	lbl_a.size = Vector2(shares[0], item_h)
	lbl_a.position = Vector2(0.0, 0.0)
	lbl_b.size = Vector2(shares[1], item_h)
	lbl_b.position = Vector2(shares[0] + _PAIR_GAP, 0.0)
	c.add_child(lbl_a)
	c.add_child(lbl_b)
	return c

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
		BucketMadnessG.reset_queue_from(BucketMadnessG.starting_level_id)
	game.need_to_increase_level = false
	current_level_id = BucketMadnessG.pop_next_level_id()
	_load_level(current_level_id)
	rounds_done = 0
	labels_hidden = false
	waiting_for_input = false
	item_answered = false
	_show_labels()
	_update_avg_label()
	_clear_fall_area()
	game.level_is_ready = true
	started_playing.emit()
	await get_tree().process_frame
	await _run_preview()
	_next_round()

func _run_preview() -> void:
	var secs: int = roundi(preview_time)
	for i in secs:
		%AvgTimeLabel.text = "Starting in %d..." % (secs - i)
		await _wait_ms(1000.0)
		if game.level_is_done:
			break
	%AvgTimeLabel.text = "Average time : —"

# A wait measured in game_time, which excludes paused time. A plain SceneTreeTimer does not stop
# for a help screen, a "return to menu?" dialog or a tutorial caption — and this countdown used to
# ABANDON itself when it noticed the game had paused, which meant `_next_round()` was then reached
# while still paused and returned without dropping anything. No countdown, no first item, and
# nothing that would ever call it again.
func _wait_ms(ms: float) -> void:
	var until: float = game.game_time + ms
	while game.game_time < until:
		await get_tree().process_frame
		if game.level_is_done or not is_inside_tree():
			return

func _load_level(id: int) -> void:
	var def: Dictionary = BucketMadnessLevelConfig.get_level(id)
	rounds_before_hide = def.get("hide_after", 5)
	num_rounds_per_level = def.get("rounds", 10)
	fall_duration = def.get("fall_duration", 2.5)
	preview_time = float(def.get("preview", 4))
	_level_rules_pool = def.get("rules", ["digit", "square"]).duplicate()
	_pick_pair_from_pool()
	game.level_label_changed("Level " + str(def.get("name", id)))

# True if the two rule keys can be confused (an item could satisfy both), so they must never be
# the two shown rules at once.
func _are_confusable(a: String, b: String) -> bool:
	return _CONFUSABLE_WITH.get(a, []).has(b) or _CONFUSABLE_WITH.get(b, []).has(a)

# Pick this level's two shown rules from its pool: two DISTINCT, non-confusable rules in RANDOM
# order, so a given rule shows up on the left bucket sometimes and on the right bucket other times.
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

func _clear_fall_area() -> void:
	for child in %FallArea.get_children():
		# The chute and its base fill are scenery, not items: this clears the round's falling
		# object, and freeing the chute with it left the game running in an empty box from the
		# first round onward.
		if child != _trap_poly and child != _chute:
			child.queue_free()
	fall_item_node = null
	if fall_tween != null:
		fall_tween.kill()
		fall_tween = null
	%FeedbackLabel.modulate.a = 0.0

func _next_round() -> void:
	# Wait the pause out rather than returning: nothing else would call this again, so a round
	# skipped here is a board that never refills.
	while game.paused():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	if game.level_is_done:
		return

	if rounds_done >= rounds_before_hide and not labels_hidden:
		labels_hidden = true
		_hide_labels()

	_clear_fall_area()
	item_answered = false
	# All shut while the item falls: nothing has been chosen yet.
	_set_buckets_open(false)

	var fall_area: Control = %FallArea
	var h: float = max(fall_area.size.y, 280.0)
	var w: float = max(fall_area.size.x, 300.0)

	# Pick category: 0=matches left rule, 1=matches right rule, 2=neither (dumpster)
	active_category = rng.randi_range(0, 2)
	correct_bucket = [0, 2, 1][active_category]

	# Generate two objects with cross-rule constraint: only one can match one rule
	var item_a: Variant
	var item_b: Variant
	var mod_a: Dictionary
	var mod_b: Dictionary
	if active_category == 0:
		item_a = current_pair[0]["gen"].call(true)
		item_b = current_pair[1]["gen"].call(false)
		mod_a = current_pair[0]
		mod_b = current_pair[1]
	elif active_category == 1:
		item_a = current_pair[1]["gen"].call(true)
		item_b = current_pair[0]["gen"].call(false)
		mod_a = current_pair[1]
		mod_b = current_pair[0]
	else:
		item_a = current_pair[0]["gen"].call(false)
		item_b = current_pair[1]["gen"].call(false)
		mod_a = current_pair[0]
		mod_b = current_pair[1]

	# Shuffle display order so matching object isn't always on same side
	if rng.randi_range(0, 1) == 1:
		var tmp_item: Variant = item_a
		var tmp_mod: Dictionary = mod_a
		item_a = item_b
		mod_a = mod_b
		item_b = tmp_item
		mod_b = tmp_mod

	fall_item_node = _make_pair_control(item_a, mod_a, item_b, mod_b)
	fall_item_node.custom_minimum_size = Vector2(item_w, item_h)
	fall_item_node.size = Vector2(item_w, item_h)
	fall_item_node.position = Vector2((w - item_w) * 0.5, -(item_h + 10.0))
	fall_area.add_child(fall_item_node)

	fall_tween = create_tween()
	_forget_when_done(fall_tween, "fall")
	fall_tween.tween_property(fall_item_node, "position:y", h - item_h - 30.0, fall_duration)
	fall_tween.tween_callback(_on_fall_reached_bottom)

	round_start_ms = game.game_time
	waiting_for_input = true
	_tut_notified_ready = false
	game.tutorial_notify("item_dropped")   # no-op outside tutorial mode

func _on_fall_reached_bottom() -> void:
	fall_tween = null  # prevent _process from restarting it
	if not item_answered:
		_evaluate_answer(1)  # timeout → dumpster (center)

func _evaluate_answer(bucket: int) -> void:
	if not waiting_for_input or game.level_is_done or item_answered:
		return
	waiting_for_input = false
	item_answered = true

	if fall_tween != null:
		fall_tween.kill()
		fall_tween = null

	var elapsed: int = int(game.game_time - round_start_ms)
	var is_right: bool = bucket == correct_bucket

	total_rounds += 1
	rounds_done += 1
	# Which destination was right against which was chosen, as a 3x3. A percentage cannot say
	# whether the mistakes are matches sent to the dumpster, non-matches sent to a bucket, or
	# one bucket taken for the other -- and the rules swap sides between sessions, so a lean to
	# one side that survives pooling is positional rather than about a particular rule.
	game.record_choice(correct_bucket, bucket)

	if is_right:
		total_corrects += 1
		times_to_answer.append(float(elapsed))
		while times_to_answer.size() > 20:
			times_to_answer.remove_at(0)
		var speed_bonus: int = max(0, 20 - elapsed / 100)
		game.add_score_and_time(10 + speed_bonus, 0)
		game.add_correct_or_mistake(1, 0)
		game.play_sound("correct")
		%FeedbackLabel.text = "✓"
		%FeedbackLabel.modulate = Color.GREEN
		_update_avg_label()
	else:
		var penalty: int = min(3, game.score)
		game.add_score_and_time(-penalty, 0)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("wrong")
		%FeedbackLabel.text = "✗"
		%FeedbackLabel.modulate = Color.RED

	%FeedbackLabel.modulate.a = 1.0
	_open_one(bucket)
	_bucket_react(bucket, is_right)
	_shut_buckets_after()
	game.tutorial_notify("answered_right" if is_right else "answered_wrong")

	# Drop the item INTO the container it was sent to.
	#
	# It used to tween to `h + 20` inside %FallArea, which is clip_contents — so it was cut off at
	# the bottom of the chute and vanished in mid-air ABOVE the buckets. It never reached one.
	#
	# Reparenting to the stage fixes both halves: the stage is not clipped, and it sits UNDER the
	# containers in the tree, so the item is occluded by the bucket's front wall as it goes in
	# rather than sliding over the top of it.
	if fall_item_node != null and is_instance_valid(fall_item_node) and _stage != null:
		var item: Control = fall_item_node
		var target: Control = _bucket_images[bucket] if bucket < _bucket_images.size() else null
		var landing: Vector2 = Vector2.ZERO
		if target is BucketView:
			landing = (target as BucketView).mouth_global() - _stage.global_position
		elif target != null:
			landing = target.global_position + target.size * 0.5 - _stage.global_position
		var keep: Vector2 = item.global_position
		item.reparent(_stage, true)
		item.position = keep - _stage.global_position
		# ABOVE the containers (z 8), not behind them. At z 4 the container's body covered the item
		# the moment they overlapped, so it read as sliding out of sight BEHIND the bucket rather
		# than dropping into it. Going in is sold by the item shrinking and fading away into the
		# dark mouth instead — which is what something falling into a container actually does.
		item.z_index = 12
		landing -= item.size * 0.5
		_slide_tween = create_tween().set_parallel(true)
		_forget_when_done(_slide_tween, "slide")
		_slide_tween.tween_property(item, "position", landing, 0.34) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Shrinking as it drops in reads as going down into the container rather than onto it.
		item.pivot_offset = item.size * 0.5
		_slide_tween.tween_property(item, "scale", Vector2(0.12, 0.12), 0.34) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Fading only over the LAST third: it stays solid all the way to the rim, then goes as it
		# passes below it.
		_slide_tween.tween_property(item, "modulate:a", 0.0, 0.12).set_delay(0.22)
		_slide_tween.chain().tween_callback(func():
			if _stage != null and is_instance_valid(_stage):
				_stage.thump(bucket)
			if is_instance_valid(item):
				item.queue_free())

	await _wait_ms(700.0)
	%FeedbackLabel.modulate.a = 0.0

	if game.level_is_done:
		return
	# If a "return to menu?" dialog was open and the player said no, wait until unpaused
	while game.paused():
		await get_tree().process_frame
	if game.level_is_done:
		return

	if rounds_done >= num_rounds_per_level:
		_level_done()
		return

	_next_round()

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
	# A frozen board must not answer. The item hangs mid-fall behind a help screen, a "return to
	# menu?" dialog or a tutorial caption, and without this an arrow key pressed over any of them
	# lands in a bucket.
	if game.paused():
		return
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
			if abs(delta.x) >= abs(delta.y) * 1.2:
				_evaluate_answer(0 if delta.x < 0.0 else 2)  # left or right bucket
			else:
				_evaluate_answer(1)  # down swipe = dumpster
	if event.is_action_pressed("left") or event.is_action_pressed("ui_left"):
		_evaluate_answer(0)
	elif event.is_action_pressed("right") or event.is_action_pressed("ui_right"):
		_evaluate_answer(2)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_accept"):
		_evaluate_answer(1)

func _level_done() -> void:
	game.level_is_done = true
	var pct: int = pct_correct()
	var need: int = BucketMadnessG.pass_pct_for(current_level_id)
	# Passing is now a RESULT, not a formality: below the level's own accuracy the same
	# level comes round again instead of the next one.
	var passed: bool = BucketMadnessG.record_level_result(current_level_id, pct)
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
	var nxt: int = BucketMadnessG.peek_next_level_id()
	if nxt <= 0 or nxt == current_level_id:
		return "Level passed."
	return "Level passed — on to level %s." % BucketMadnessG.level_name_for(nxt)

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

# --- Tutorial hooks -------------------------------------------------------------------------
#
# The item falls on a Tween, and a tutorial must not let it land while the coach is mid-sentence:
# reaching the bottom answers "dumpster" on the player's behalf and scores it. So the tutorial
# holds the item in mid-air — but only AFTER it has fallen far enough to be seen. Pausing it where
# it spawns would freeze it above the trapezoid, where `clip_contents` hides it completely, and the
# caption would be pointing at nothing.

var tutorial_hold_fall: bool = false
var _tut_notified_ready: bool = false

const TUT_HOLD_FRAC: float = 0.45   # share of the fall at which a held item stops

func _tutorial_hold_y() -> float:
	var h: float = max(%FallArea.size.y, 280.0)
	return (h - item_h - 30.0) * TUT_HOLD_FRAC

func _tutorial_should_hold() -> bool:
	if not tutorial_hold_fall or fall_item_node == null or not is_instance_valid(fall_item_node):
		return false
	return fall_item_node.position.y >= _tutorial_hold_y()

# True once the item is on screen and hanging — what a caption should wait for before it starts
# describing "these two objects".
func tutorial_item_is_held() -> bool:
	return _tutorial_should_hold()

func tutorial_has_item() -> bool:
	return waiting_for_input and fall_item_node != null and is_instance_valid(fall_item_node)

func tutorial_item_rect() -> Rect2:
	if fall_item_node == null or not is_instance_valid(fall_item_node):
		return Rect2()
	return fall_item_node.get_global_rect()

# Buckets and their labels, for the coach to point at. These are the scene's own nodes, so a frame
# lands on what the player is actually looking at rather than on a guessed rectangle.
func _bucket_image(idx: int) -> Control:
	if idx < 0 or idx >= _bucket_images.size() or not is_instance_valid(_bucket_images[idx]):
		return null
	return _bucket_images[idx]

func tutorial_left_bucket() -> Control:
	return _bucket_image(0)

func tutorial_dumpster() -> Control:
	return _bucket_image(1)

func tutorial_right_bucket() -> Control:
	return _bucket_image(2)

func tutorial_left_rule_label() -> Control:
	return %LeftRuleLabel

func tutorial_right_rule_label() -> Control:
	return %RightRuleLabel

func tutorial_avg_label() -> Control:
	return %AvgTimeLabel

func tutorial_rules_row() -> Rect2:
	var l: Rect2 = %LeftRuleLabel.get_global_rect()
	return l.merge(%RightRuleLabel.get_global_rect())

func tutorial_buckets_row() -> Rect2:
	var l: Control = _bucket_image(0)
	var r: Control = _bucket_image(2)
	if l == null or r == null:
		return Rect2()
	return l.get_global_rect().merge(r.get_global_rect())

# 0 = left bucket, 1 = dumpster, 2 = right bucket — the same indices the input maps to.
func tutorial_correct_bucket() -> int:
	return correct_bucket

func tutorial_bucket_name(bucket: int) -> String:
	if bucket == 0:
		return "left bucket"
	if bucket == 2:
		return "right bucket"
	return "dumpster"

# The rule the current item matches, in the game's own words, or "" when it matches neither and
# belongs in the dumpster. Read live so a caption can never claim the wrong rule.
func tutorial_matching_rule() -> String:
	if current_pair.size() < 2 or active_category == 2:
		return ""
	return _u(current_pair[0 if active_category == 0 else 1].get("label", ""))

func tutorial_rule_text(side: int) -> String:
	if current_pair.size() < 2:
		return ""
	return _u(current_pair[clampi(side, 0, 1)].get("label", ""))
