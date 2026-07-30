extends CanvasLayer

# Aliens — little aliens roam a field and walk into the OUTER ring of a target area on their own.
# The player drags each arrival either into that area's INNER ring (if it matches the area's rule)
# or back out to the hall (if it doesn't). While a gate's queue is FULL, aliens that walk up to it
# are turned away and each one costs a miss.
#
# The whole UI is built in code (see _build_ui); level.tscn is just a CanvasLayer + this script.

var game: GenericGameUtil
var current_level_id: int = 1

# --- level config (see aliens/scripts/level_config.gd) ---
var level_time_sec: int = 70
var rules_pool: Array = []
var num_areas: int = 1
var alien_speed_frac: float = 0.055
var alien_size_key: String = "med"
var num_free_aliens: int = 8
var hide_after_ms: float = 0.0
var enter_chance: float = 0.30      # per-alien probability, rolled on each retarget
var park_patience_ms: float = 0.0
var trait_colors: Array = [0, 1, 2]
var trait_eyes: Array = [1, 2, 3]
var trait_antennae: Array = [0, 1, 2]
var trait_spots_chance: float = 0.5
var gate_change_ms: float = 0.0        # 0 = gates never swap passes
var deny_chance: float = 0.0           # per-gate probability of being a DENY gate
var priority_every_ms: float = 0.0     # 0 = no boarding calls
var priority_window_ms: float = 6000.0
var compound_chance: float = 0.0       # per gate, probability the pass is two rules joined
var compound_ops: Array = []           # subset of ALL_OPS; empty = no compounds
var _chip_lines: int = 1               # rule-chip height in lines (2 once compounds can appear)

# --- rules -----------------------------------------------------------------------------------
const ALL_RULES: Array = [
	"eyes1", "eyes2", "eyes3", "fat", "thin",
	"ant0", "ant1", "ant2", "spots", "nospots",
	"blue", "red", "green", "yellow", "purple",
]

const RULE_LABELS: Dictionary = {
	"eyes1": "1 EYE", "eyes2": "2 EYES", "eyes3": "3 EYES",
	"fat": "FAT", "thin": "THIN",
	"ant0": "NO ANTENNAE", "ant1": "1 ANTENNA", "ant2": "2 ANTENNAE",
	"spots": "SPOTTED", "nospots": "NO SPOTS",
	"blue": "BLUE", "red": "RED", "green": "GREEN", "yellow": "YELLOW", "purple": "PURPLE",
}

# Which trait each rule reads. Two rules may only be shown together if they read DIFFERENT
# dimensions — that is the point of the game: a forced CONTEXT SWITCH. "1 EYE" beside "2 EYES"
# keeps the player staring at the same feature and merely changes the value, which is a comparison,
# not a switch. (This subsumes the old complement rule: fat/thin and spots/nospots are the same
# dimension, so they can never be paired either.)
# The config lists MODALITIES, not individual rules: one modality per gate, then a random rule
# from within it. Orthogonality is then guaranteed by construction rather than filtered for.
const ALL_MODALITIES: Array = ["eyes", "shape", "antennae", "spots", "color"]

const RULE_DIMENSION: Dictionary = {
	"eyes1": "eyes", "eyes2": "eyes", "eyes3": "eyes",
	"fat": "shape", "thin": "shape",
	"ant0": "antennae", "ant1": "antennae", "ant2": "antennae",
	"spots": "spots", "nospots": "spots",
	"blue": "color", "red": "color", "green": "color", "yellow": "color", "purple": "color",
}

# True when both rules read the same trait, so pairing them would ask for a value comparison
# rather than a context switch.
# Rules whose LABEL is already a negation. A DENY gate must never take one: the chip would read
# "NO NO SPOTS", and for a two-valued trait deny+nospots is logically identical to accept+spots
# anyway — so the double negative buys no extra load, only confusion. A deny gate swaps to the
# positive rule of the same modality instead (which also keeps one modality per gate intact).
const NEGATIVE_RULES: Array = ["nospots", "ant0"]

# Two different negations, kept as two different words so they never blur together:
#   "NO ..."  a trait that is ABSENT      — NO ANTENNAE, NO SPOTS, NO ANT (a rule's own name)
#   "NOT ..." the requirement is NEGATED  — NOT FAT, NOT BLUE (a deny gate, or a compound operand)
# "NOT" also matches the compound operators ("AND NOT", "OR NOT"), so the player learns one word
# for negation rather than two for the same idea.
const DENY_PREFIX: String = "NOT "

func _same_dimension(a: String, b: String) -> bool:
	return str(RULE_DIMENSION.get(a, a)) == str(RULE_DIMENSION.get(b, b))

const COLOR_RULE_ID: Dictionary = {"blue": 0, "red": 1, "green": 2, "yellow": 3, "purple": 4}

const SMART_ENTRY: float = 0.5     # chance an alien heads for an area it actually fits
const EAGER_ENTER: float = 0.85    # commit chance when hovering beside a ring with free space
const LOITER_BIAS: float = 0.45     # chance a wander target sits just outside a ring
const LOITER_BAND: float = 4.2      # depth of the loitering band, in alien radii
const MIN_ENTRY_GAP_MS: float = 550.0   # so two aliens never commit on the same frame
const RE_ENTRY_COOLDOWN_MS: float = 5000.0  # after being pushed out, an alien stays out a while
const ARRIVAL_WINDOW: int = 8
const ARRIVAL_SKEW: int = 6

# --- geometry --------------------------------------------------------------------------------
const SLOT_GAP: float = 1.10       # required center spacing between slots = 2 * a * SLOT_GAP
const INNER_MUL: float = 2.40      # inner disc radius, in alien radii
const BAND_MUL: float = 2.60       # annulus width in units of a (2.0 would be an exact fit);
                                   # the extra room keeps the parking lane clear of the inner disc
const AREA_PAD: float = 6.0
const KEEP_OUT_PAD: float = 3.0
const PARK_GAP: float = 6.0        # clearance between two aliens parked in an outer ring;
                                   # also absorbs the small glide offset on arrival
const INNER_PAD: float = 1.0       # how far parked/walking aliens stay off the inner disc
const SEP_ITERS: int = 3       # relaxation passes per resolve cycle
const RESOLVE_CYCLES: int = 4  # separate + keep-out, interleaved (see _resolve_positions)
const SEP_PAD: float = 2.0
const STEER_RESPONSE: float = 9.0
const ARRIVE_RADIUS_MUL: float = 1.8   # start slowing this many radii out
const BOB_RATE: float = 0.085
const SNAP_MS: float = 190.0
const INNER_HOLD_MS: float = 1100.0
const FADE_MS: float = 480.0
const HINT_FLASH_MS: float = 650.0
# Reported when the player never made a single correct call. Response time is "lower is better",
# so an empty average must read as BAD, not as a perfect 0.
const NO_ANSWER_MS: int = 99999
const MARK_RISE: float = 54.0      # how far the ✓/✗ floats up
const MARK_MS: float = 900.0
const SEEK_TIMEOUT_MS: float = 3500.0    # give up on a blocked approach quickly and visibly
const LEAVE_TIMEOUT_MS: float = 3000.0   # a departure blocked by the crowd cannot linger forever
const MIN_SUPPLY: int = 2                # roamers that must match / not match EACH area's rule
const TOPUP_PERIOD_MS: float = 1200.0    # how often the supply is checked (slow: each swap is
                                         # a visible fade out/in, and churn looks bad)
const TOPUP_MAX_PER_TICK: int = 2        # a burst of promotions can open several gaps at once
const SUPPLY_HEADROOM: int = 3           # extra aliens allowed above num_free_aliens to cover gaps

# --- interference layer (gate change / deny list / boarding call) ------------------------------
# These exist to defeat the three shortcuts that made the base game gentler than rlmadness:
#   1. the rule settles into a LOCATION ("left = blue")  -> gate change re-permutes the passes
#   2. polarity is always ACCEPT                         -> a deny gate boards everything EXCEPT
#   3. the player picks what to handle and when, so gates can be batched one at a time, and
#      batching removes the task-switch cost entirely    -> a boarding call interrupts the batch
const GATE_CHANGE_REVEAL_MS: float = 2200.0  # passes come back up briefly after a swap
const GATE_CHANGE_JITTER: float = 0.22       # +/- share of the period, so it is never countable
const BANNER_MS: float = 1600.0
const CALL_RETRY_MS: float = 900.0           # nobody parked to call yet — look again shortly

enum AState { ROAM, SEEKING_SLOT, PARKED_OUTER, PARKED_INNER, LEAVING, DRAGGED, SNAPPING, FADING }
enum Region { FIELD, OUTER, INNER }

# --- world -----------------------------------------------------------------------------------
var _aliens: Array = []
var _areas: Array = []
var _field: Rect2 = Rect2(0, 0, 100, 100)
var _alien_radius: float = 33.0
var _roam_speed: float = 40.0
var _seek_speed: float = 68.0
var _meadow_top: float = 0.0
var _entry_cooldown_ms: float = 0.0
var _next_topup_ms: float = 0.0
var _last_now: float = 0.0
var topup_swaps: int = 0     # supply-driven replacements (diagnostic)
var _recent_arrivals: Array = []
var _play_start_ms: float = 0.0
var _rules_hidden: bool = false
var _chips_visible: bool = true      # what the chips are actually showing right now
var _z_counter: int = 10

# --- interference state ---
var _next_gate_change_ms: float = 0.0
var _reveal_until_ms: float = 0.0    # passes forced back up (after a swap) even when hidden
var _called_al = null                # the priority passenger, or null
var _called_until_ms: float = 0.0
var _next_priority_ms: float = 0.0
var _last_called_area: int = -1      # so consecutive calls prefer a DIFFERENT gate
var gate_changes: int = 0            # diagnostics
var calls_made: int = 0
var calls_missed: int = 0
var _banner: Label = null

# --- drag state ---
var _drag_alien = null
var _drag_offset: Vector2 = Vector2.ZERO

# --- scoring ---
var total_rounds: int = 0
var total_corrects: int = 0
var times_to_answer: Array = []

# --- nodes ---
var _catcher: Control = null
var _field_node: Node2D = null
var _alien_root: Node2D = null
var _rule_labels: Array = []

const ALIEN_SCRIPT: GDScript = preload("res://aliens/scripts/alien.gd")
const FIELD_SCRIPT: GDScript = preload("res://aliens/scripts/field.gd")

var correct_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var wrong_audio = preload("res://art/sounds/swoosh.mp3")
var gatechange_audio = preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var call_audio = preload("res://art/sounds/FreeSFX/GameSFX/Blops/Retro Blop 22.ogg")

signal sig_level_is_done(didwin: bool)
signal started_playing

func _ready() -> void:
	game = AliensG.game
	game.sig_time_over.connect(_on_time_over)
	game.add_sound(self, "correct", correct_audio)
	game.add_sound(self, "wrong", wrong_audio)
	game.add_sound(self, "gatechange", gatechange_audio)
	game.add_sound(self, "call", call_audio)
	_build_ui()
	set_process(true)

# --- UI construction --------------------------------------------------------------------------

func _build_ui() -> void:
	_field_node = Node2D.new()
	_field_node.set_script(FIELD_SCRIPT)
	_field_node.z_index = -10
	add_child(_field_node)

	_alien_root = Node2D.new()
	add_child(_alien_root)

	# drag catcher (invisible, full-screen). Aliens are Node2D and don't take GUI input, so a
	# single STOP control under them handles every drag.
	_catcher = Control.new()
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_catcher_gui_input)
	add_child(_catcher)

func _make_rule_label() -> Label:
	var lbl: Label = Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.clip_text = true          # without this the Label's minimum size overrides _place()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 20
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.add_theme_color_override("font_color", Color(1, 0.97, 0.72, 1.0))
	# deliberately quiet: no border, barely-there backdrop. It is a caption, not a UI panel.
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.10, 0.07, 0.42)
	st.set_corner_radius_all(10)
	lbl.add_theme_stylebox_override("normal", st)
	return lbl

# Shrink a caption's font until its longest possible text fits the chip, so clip_text never
# actually clips anything.
func _fit_caption(lb: Label, max_w: float, base_fs: int) -> void:
	var f: Font = lb.get_theme_font("font")
	if f == null:
		f = MainGlobals.get_system_sans_font()
	var fs: int = base_fs
	# a compound caption is two lines: measure the WIDEST one. Measuring the whole string would
	# include the newline as ordinary text and shrink the font far more than necessary.
	while fs > 10 and _widest_line_w(f, lb.text, fs) > max_w:
		fs -= 1
	lb.add_theme_font_size_override("font_size", fs)

func _widest_line_w(f: Font, txt: String, fs: int) -> float:
	var w: float = 0.0
	for line in txt.split("\n"):
		w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return w

func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)

# --- Layout -----------------------------------------------------------------------------------

func _layout() -> void:
	var sw: float = float(MainGlobals.screen_size.x)
	var sh: float = float(MainGlobals.screen_size.y)
	var mob: bool = MainGlobals.is_mobile()
	var hh: float = float(MainGlobals.header_height)

	_place(_catcher, 0.0, 0.0, sw, sh)

	# reserve the app bottom button bar (taller than the footer) — same math as change/couples
	var bar_h_bottom: float = 70.0 if mob else 44.0
	var bottom_reserve: float = maxf(20.0, bar_h_bottom - float(MainGlobals.footer_height) + 10.0)
	var bottom_limit: float = sh - bottom_reserve

	var side: float = 8.0
	var field_top: float = hh + 50.0        # clears the HUD level label
	_field = Rect2(side, field_top, sw - side * 2.0, bottom_limit - field_top)

	var cap_fs: int = 28 if mob else 21
	var cap_font: Font = MainGlobals.get_system_sans_font()
	var label_res: float = cap_font.get_height(cap_fs) * float(_chip_lines) + 18.0
	var n: int = maxi(1, num_areas)

	# base alien radius as a fraction of screen WIDTH (platform-independent), then shrunk until
	# the rings fit their corners, stay clear of each other, and leave room for every roamer.
	var base_frac: float = 0.098
	match alien_size_key:
		"big":
			base_frac = 0.112
		"med":
			base_frac = 0.098
		"small":
			base_frac = 0.086
	var a_want: float = sw * base_frac * 0.5
	if not mob:
		a_want *= 0.70          # same convention as change: wider/shorter screens get smaller

	var a: float = a_want
	var rr: Vector2 = Vector2.ZERO
	var centers: Array = []
	for _try in 12:
		rr = _ring_radii(a)
		centers = _area_centers(n, rr.y, label_res)
		var fit_r: float = minf(_field.size.x * 0.5 - AREA_PAD,
			(_field.size.y - label_res * 2.0) * 0.5 - AREA_PAD)
		var ok_fit: bool = rr.y <= fit_r
		var ok_sep: bool = true
		for i in centers.size():
			for j in range(i + 1, centers.size()):
				if Vector2(centers[i]).distance_to(Vector2(centers[j])) < rr.y * 2.0 + 2.2 * a:
					ok_sep = false
		var disk_area: float = float(n) * PI * pow(rr.y + a, 2.0)
		var free_area: float = _field.size.x * _field.size.y - disk_area
		var ok_room: bool = free_area >= float(num_free_aliens) * pow(2.6 * a, 2.0)
		if ok_fit and ok_sep and ok_room:
			break
		a *= 0.94
	_alien_radius = a
	rr = _ring_radii(a)
	centers = _area_centers(n, rr.y, label_res)

	_roam_speed = alien_speed_frac * sw
	_seek_speed = _roam_speed * 1.7

	var s_out: float = (rr.x + rr.y) * 0.5
	var inner: Vector2 = _inner_lane(rr.x, a)
	var s_in: float = inner.x
	var k_in: int = int(inner.y)

	var old_pass: Array = []
	var old_deny: Array = []
	for ar in _areas:
		old_pass.append(ar.get("pass", {}))
		old_deny.append(bool(ar.get("deny", false)))
	_areas.clear()
	for i in n:
		var inner_owner: Array = []
		for _s in k_in:
			inner_owner.append(null)
		var pass_def: Dictionary = {}
		if i < old_pass.size():
			pass_def = old_pass[i]
		_areas.append({
			"center": Vector2(centers[i]), "r_in": rr.x, "r_out": rr.y,
			"s_in": s_in, "s_out": s_out,
			"inner_slots": k_in, "inner_owner": inner_owner,
			"parked": 0, "capacity": 0, "pass": pass_def,
			"deny": bool(old_deny[i]) if i < old_deny.size() else false,
		})
	for i in n:
		_refresh_ring_state(i)

	# rule chips, centered on the top of each circle
	while _rule_labels.size() < n:
		var lbl: Label = _make_rule_label()
		add_child(lbl)
		_rule_labels.append(lbl)
	for i in _rule_labels.size():
		var lb: Label = _rule_labels[i]
		lb.visible = i < n and _chips_visible
		if i >= n:
			continue
		lb.add_theme_font_size_override("font_size", cap_fs)
		var chip_h: float = label_res - 6.0
		var chip_w: float = minf(rr.y * 2.0, _field.size.x * 0.46)
		var c: Vector2 = Vector2(_areas[i]["center"])
		var chip_x: float = clampf(c.x - chip_w * 0.5, _field.position.x,
			_field.position.x + _field.size.x - chip_w)
		var chip_y: float = _field.position.y + 3.0
		if _area_is_bottom(i, n):
			chip_y = _field.position.y + _field.size.y - label_res + 3.0
		_place(lb, chip_x, chip_y, chip_w, chip_h)
		_fit_caption(lb, chip_w - 14.0, cap_fs)

	_meadow_top = _field.position.y

	_field_node.areas = _areas
	_field_node.field_rect = _field
	_field_node.set_sky_size(Vector2(sw, sh))
	_field_node.alien_radius = _alien_radius
	_field_node.queue_redraw()

	for al in _aliens:
		if not is_instance_valid(al):
			continue
		al.radius = _alien_radius
		al.queue_redraw()
		# the rings may have moved/resized — put anyone already parked back on their (new) spot
		if al.state == AState.PARKED_OUTER and al.park_angle > al.HAS_ANGLE_MIN \
			and al.area_idx >= 0 and al.area_idx < _areas.size():
			al.sim_pos = _outer_park_pos(_areas[al.area_idx], al.park_angle)
			al.position = al.sim_pos

# Areas sit in the screen CORNERS: one area centres in the field, two take OPPOSING corners, and
# three or four fill the remaining ones. Corners keep the middle of the field open as one
# contiguous roaming space, and keep the two rings as far apart as the screen allows.
const CORNER_SIGNS: Array = [
	Vector2(-1.0, -1.0),   # top-left
	Vector2(1.0, 1.0),     # bottom-right (opposite, so 2 areas are diagonal)
	Vector2(1.0, -1.0),    # top-right
	Vector2(-1.0, 1.0),    # bottom-left
]

# `label_res` is reserved at BOTH the top and the bottom of the field: a top-corner area captions
# in the top band, a bottom-corner one in the bottom band. That keeps every caption completely
# outside the play area, so it never sits over a ring or over the roaming aliens.
func _area_centers(n: int, r_out: float, label_res: float) -> Array:
	var out: Array = []
	if n <= 1:
		out.append(Vector2(_field.position.x + _field.size.x * 0.5,
			_field.position.y + label_res + (_field.size.y - label_res * 2.0) * 0.5))
		return out
	for i in mini(n, CORNER_SIGNS.size()):
		var sgn: Vector2 = CORNER_SIGNS[i]
		var x: float = _field.position.x + AREA_PAD + r_out
		if sgn.x > 0.0:
			x = _field.position.x + _field.size.x - AREA_PAD - r_out
		var y: float = _field.position.y + label_res + AREA_PAD + r_out
		if sgn.y > 0.0:
			y = _field.position.y + _field.size.y - label_res - AREA_PAD - r_out
		out.append(Vector2(x, y))
	return out

# True when this area captions in the BOTTOM band rather than the top one.
func _area_is_bottom(i: int, n: int) -> bool:
	if n <= 1:
		return false
	return i < CORNER_SIGNS.size() and Vector2(CORNER_SIGNS[i]).y > 0.0

# r_in / r_out derived purely from the alien radius, so the geometry is right by construction.
# The inner disc holds as many aliens as physically fit, exactly like the outer ring — neither
# has a configured slot count.
func _ring_radii(a: float) -> Vector2:
	var r_in: float = a * INNER_MUL
	return Vector2(r_in, r_in + a * BAND_MUL)

# How many aliens fit inside the inner disc, and the lane radius they stand on.
func _inner_lane(r_in: float, a: float) -> Vector2:
	var lane: float = r_in - a - INNER_PAD
	if lane < a * 0.55:
		return Vector2(0.0, 1.0)                 # only room for one, at the centre
	var q: float = clampf(a * SLOT_GAP / lane, 0.0, 1.0)
	if q >= 1.0:
		return Vector2(0.0, 1.0)
	return Vector2(lane, float(maxi(1, int(floor(PI / asin(q))))))

# The OUTER ring has no fixed slots: aliens pack anywhere around the parking lane that has room.
# Capacity is therefore whatever geometry allows, not a configured number.

# Smallest angular separation two parked aliens may have without touching.
func _ring_min_da(ar: Dictionary) -> float:
	var s_out: float = float(ar["s_out"])
	var need: float = 2.0 * _alien_radius + PARK_GAP
	return 2.0 * asin(clampf(need / (2.0 * s_out), 0.0, 1.0))

func _ring_capacity(ar: Dictionary) -> int:
	var da: float = _ring_min_da(ar)
	if da <= 0.0001:
		return 99
	return maxi(1, int(floor(TAU / da)))

func _outer_park_pos(ar: Dictionary, ang: float) -> Vector2:
	return Vector2(ar["center"]) + Vector2(cos(ang), sin(ang)) * float(ar["s_out"])

# Angles already reserved in this ring (a walking seeker holds its spot, like the old slots did).
func _taken_angles(ai: int, ignore_al) -> Array:
	var out: Array = []
	for al in _aliens:
		if al == ignore_al or al.area_idx != ai:
			continue
		if al.state != AState.SEEKING_SLOT and al.state != AState.PARKED_OUTER \
			and al.state != AState.SNAPPING:
			continue
		if al.park_angle < al.HAS_ANGLE_MIN:
			continue
		out.append(al.park_angle)
	return out

# Reserve a spot on the lane as close as possible to `prefer_ang`. false = the ring is full.
func _reserve_park(ai: int, al, prefer_ang: float) -> bool:
	var ar: Dictionary = _areas[ai]
	var min_da: float = _ring_min_da(ar)
	var taken: Array = _taken_angles(ai, al)
	var steps: int = int(ceil(TAU / maxf(min_da * 0.5, 0.01))) + 1
	for k in steps:
		for sgn in [1.0, -1.0]:
			var cand: float = prefer_ang + sgn * float(k) * min_da * 0.5
			var ok: bool = true
			for t in taken:
				if absf(wrapf(cand - float(t), -PI, PI)) < min_da - 0.001:
					ok = false
					break
			if ok:
				al.park_angle = wrapf(cand, -PI, PI)
				_refresh_ring_state(ai)
				return true
			if k == 0:
				break                    # +0 and -0 are the same candidate
	return false

func _release_park(al) -> void:
	var ai: int = al.area_idx
	al.park_angle = al.NO_ANGLE
	if ai >= 0 and ai < _areas.size():
		_refresh_ring_state(ai)

func _refresh_ring_state(ai: int) -> void:
	var ar: Dictionary = _areas[ai]
	ar["parked"] = _taken_angles(ai, null).size()
	ar["capacity"] = _ring_capacity(ar)
	_field_node.queue_redraw()

func _ring_is_full(ai: int) -> bool:
	return _taken_angles(ai, null).size() >= _ring_capacity(_areas[ai])

func _inner_slot_pos(ar: Dictionary, idx: int) -> Vector2:
	var k: int = int(ar["inner_slots"])
	if k <= 1:
		return Vector2(ar["center"])
	var ang: float = -PI * 0.5 + PI / float(k) + TAU * float(idx) / float(k)
	return Vector2(ar["center"]) + Vector2(cos(ang), sin(ang)) * float(ar["s_in"])

# --- Rules ------------------------------------------------------------------------------------

func _alien_matches(al, rule_key: String) -> bool:
	match rule_key:
		"eyes1":
			return al.eyes == 1
		"eyes2":
			return al.eyes == 2
		"eyes3":
			return al.eyes == 3
		"fat":
			return al.is_fat
		"thin":
			return not al.is_fat
		"ant0":
			return al.antennae == 0
		"ant1":
			return al.antennae == 1
		"ant2":
			return al.antennae == 2
		"spots":
			return al.has_spots
		"nospots":
			return not al.has_spots
		"blue":
			return al.color_id == 0
		"red":
			return al.color_id == 1
		"green":
			return al.color_id == 2
		"yellow":
			return al.color_id == 3
		"purple":
			return al.color_id == 4
	return false

# THE judgment, in exactly one place: should this gate board this alien?
#
# An ACCEPT gate boards the aliens matching its pass. A DENY gate boards everything EXCEPT them —
# the polarity flips, and after the pass hides the player has to remember both which rule it was
# and which way round it ran. Every decision, every supply calculation and every arrival choice
# goes through here, so the two never disagree.
func _gate_wants(al, area_idx: int) -> bool:
	if area_idx < 0 or area_idx >= _areas.size():
		return false
	var m: bool = _pass_matches(al, _areas[area_idx].get("pass", {}))
	return m != bool(_areas[area_idx].get("deny", false))

# Inverse of the above, for the supply system: given "this gate should (not) board it", what does
# the alien have to do with the gate's RULE? _force_rule speaks rules, not gate decisions.
func _match_want(area_idx: int, gate_want: bool) -> bool:
	if area_idx < 0 or area_idx >= _areas.size():
		return gate_want
	return gate_want != bool(_areas[area_idx].get("deny", false))

# A rule is only offered if this level's trait pools can produce BOTH matches and non-matches —
# otherwise it is either always true or always false and carries no information.
func _is_rule_usable(rule_key: String) -> bool:
	if COLOR_RULE_ID.has(rule_key):
		return trait_colors.size() >= 2 and trait_colors.has(int(COLOR_RULE_ID[rule_key]))
	if rule_key.begins_with("eyes"):
		return trait_eyes.size() >= 2 and trait_eyes.has(int(rule_key.substr(4)))
	if rule_key.begins_with("ant"):
		return trait_antennae.size() >= 2 and trait_antennae.has(int(rule_key.substr(3)))
	if rule_key == "spots" or rule_key == "nospots":
		return trait_spots_chance > 0.01 and trait_spots_chance < 0.99
	return rule_key == "fat" or rule_key == "thin"

# Every rule belonging to a modality.
func _rules_in_modality(m: String) -> Array:
	var out: Array = []
	for k in ALL_RULES:
		if str(RULE_DIMENSION.get(k, "")) == m:
			out.append(str(k))
	return out

# Rules of this modality that this level's trait pools can actually pose (see _is_rule_usable).
func _usable_rules_in(m: String) -> Array:
	var out: Array = []
	for k in _rules_in_modality(m):
		if _is_rule_usable(k):
			out.append(k)
	return out

# Modalities from the level's pool that can pose at least one rule. An EMPTY pool means "all".
func _usable_modalities(pool: Array) -> Array:
	var src: Array = pool.duplicate()
	if src.is_empty():
		src = ALL_MODALITIES.duplicate()
	var out: Array = []
	for m in src:
		var mk: String = str(m)          # not `name` — that shadows Node.name
		if not ALL_MODALITIES.has(mk) or out.has(mk):
			continue
		if not _usable_rules_in(mk).is_empty():
			out.append(mk)
	return out

# A gate's PASS is either a single rule or two rules from DIFFERENT modalities joined by an
# operator. Both atoms coming from different modalities is what makes everything downstream
# tractable: forcing one atom can never disturb the other, so the supply system decomposes
# exactly instead of needing a constraint solver.
#
#   {"op": "atom",   "a": "blue"}                 BLUE
#   {"op": "and",    "a": "eyes1", "b": "blue"}   1 EYE AND BLUE
#   {"op": "or",     ...}                         1 EYE OR BLUE
#   {"op": "andnot", ...}                         1 EYE AND NOT BLUE
#   {"op": "ornot",  ...}                         1 EYE OR NOT BLUE
const OP_JOIN: Dictionary = {
	"and": "AND ", "or": "OR ", "andnot": "AND NOT ", "ornot": "OR NOT ",
}
const ALL_OPS: Array = ["and", "or", "andnot", "ornot"]

# Compound labels are twice as long as simple ones in a chip that does not get any wider, and the
# font shrinks to fit: measured, "NO ANTENNAE AND NOT SPOTTED" landed at 11 px on a 3-gate level,
# which is unreadable on a phone. Two fixes, both needed. First, compound OPERANDS use these
# abbreviations — only inside a compound, since a simple gate has room for the full wording.
const RULE_LABELS_SHORT: Dictionary = {
	"ant0": "NO ANT", "ant1": "1 ANT", "ant2": "2 ANT",
	"spots": "SPOTS", "nospots": "NO SPOTS",
	"eyes1": "1 EYE", "eyes2": "2 EYES", "eyes3": "3 EYES",
}

func _atom_label(key: String, short: bool) -> String:
	if short and RULE_LABELS_SHORT.has(key):
		return str(RULE_LABELS_SHORT[key])
	return str(RULE_LABELS.get(key, key))

func _pass_matches(al, ps: Dictionary) -> bool:
	var a: bool = _alien_matches(al, str(ps.get("a", "")))
	var op: String = str(ps.get("op", "atom"))
	if op == "atom":
		return a
	var b: bool = _alien_matches(al, str(ps.get("b", "")))
	match op:
		"and":
			return a and b
		"or":
			return a or b
		"andnot":
			return a and not b
		"ornot":
			return a or not b
	return a

# Second fix: a compound breaks at the OPERATOR onto a second line, so neither line is longer than
# a simple pass. `_chip_lines` reserves the height for it at layout time (the passes are not drawn
# yet then, so the reservation is per-LEVEL, not per-pass — stable geometry beats a tight fit).
func _pass_label(ps: Dictionary, multiline: bool = true) -> String:
	var op: String = str(ps.get("op", "atom"))
	var short: bool = op != "atom"
	var la: String = _atom_label(str(ps.get("a", "")), short)
	if op == "atom":
		return la
	var lb: String = _atom_label(str(ps.get("b", "")), short)
	var joiner: String = str(OP_JOIN.get(op, "AND "))
	if multiline and _chip_lines > 1:
		return la + "\n" + joiner + lb
	return la + " " + joiner + lb

# Identity of a pass, for "no two gates get the same one". AND and OR are symmetric, so their
# operands are sorted — otherwise "1 EYE AND BLUE" and "BLUE AND 1 EYE" would count as different
# passes while reading as the same requirement.
func _pass_signature(ps: Dictionary) -> String:
	var op: String = str(ps.get("op", "atom"))
	if op == "atom":
		return "atom:" + str(ps.get("a", ""))
	if op == "and" or op == "or":
		var pair: Array = [str(ps.get("a", "")), str(ps.get("b", ""))]
		pair.sort()
		return op + ":" + str(pair[0]) + "," + str(pair[1])
	return op + ":" + str(ps.get("a", "")) + "," + str(ps.get("b", ""))

func _rule_in(m: String) -> String:
	var opts: Array = _usable_rules_in(m)
	if opts.is_empty():
		return ""
	return str(opts[game.rng.randi_range(0, opts.size() - 1)])

func _draw_pass(mods: Array, allow_compound: bool = true) -> Dictionary:
	var want_compound: bool = allow_compound and compound_chance > 0.0 \
		and not compound_ops.is_empty() \
		and mods.size() >= 2 and game.rng.randf() < compound_chance
	if not want_compound:
		return {"op": "atom", "a": _rule_in(str(mods[game.rng.randi_range(0, mods.size() - 1)]))}
	var two: Array = mods.duplicate()
	two.shuffle()
	var op: String = str(compound_ops[game.rng.randi_range(0, compound_ops.size() - 1)])
	var ka: String = _rule_in(str(two[0]))
	var kb: String = ""
	if op == "andnot" or op == "ornot":
		# the right operand is already negated by the operator, so it must not be a
		# negatively-labelled rule as well: "1 EYE AND NOT NO ANTENNAE" is unreadable
		kb = _positive_rule_in(str(two[1]))
		if kb == "":
			op = "and" if op == "andnot" else "or"
			kb = _rule_in(str(two[1]))
	else:
		kb = _rule_in(str(two[1]))
	if ka == "" or kb == "":
		return {"op": "atom", "a": ka if ka != "" else kb}
	return {"op": op, "a": ka, "b": kb}

# One pass per gate. Plain (atom) gates still take DIFFERENT modalities wherever possible — that
# is what makes moving between gates a switch of attention rather than a change of value. With
# compounds the old "every gate a distinct modality" invariant becomes arithmetically impossible
# (4 gates x 2 atoms needs 8 slots from 5 modalities), so it weakens to "no two gates get the
# same pass", with distinct modalities still preferred for the simple ones.
func _pick_rules() -> void:
	var mods: Array = _usable_modalities(rules_pool)
	if mods.size() < 2:
		mods = _usable_modalities([])
	if mods.is_empty():
		mods = ["eyes"]

	# MODALITY BUDGET. Gates must read DIFFERENT traits — that is what makes moving between them a
	# switch of attention rather than a change of value, and it is the reason the game exists. A
	# compound spends TWO modalities, an atom one, and each gate draws only from those still
	# unspent, so the traits are disjoint across the whole board by construction.
	#
	# A gate may only go compound if the gates AFTER it would still have one modality each. That
	# is what caps the number of compounds — by the budget rather than by luck. With five
	# modalities: 2 gates can both be compound, 3 gates get at most two, 4 gates at most one.
	#
	# (An earlier version only enforced this between the SIMPLE gates and let compounds overlap
	# anything. Measured, that put two gates on a shared trait in 84% of rounds on levels 9-10 —
	# no ambiguity ever, but a badly weakened switch: "3 EYES OR 2 ANT" beside "3 EYES AND BLUE"
	# is answered half-way by one look at the eyes.)
	var avail: Array = mods.duplicate()
	avail.shuffle()
	var used_sig: Dictionary = {}
	for i in _areas.size():
		var others_left: int = _areas.size() - i - 1
		var can_compound: bool = avail.size() - 2 >= others_left
		var pool: Array = avail if avail.size() >= (2 if can_compound else 1) else mods
		var best: Dictionary = {}
		for _try in 16:
			var ps: Dictionary = _draw_pass(pool, can_compound)
			if str(ps.get("a", "")) == "":
				continue
			best = ps
			if not used_sig.has(_pass_signature(ps)):
				break
		if best.is_empty():
			best = {"op": "atom", "a": _rule_in(str(pool[0]))}
		used_sig[_pass_signature(best)] = true
		for m in _pass_modalities(best):
			avail.erase(m)
		_areas[i]["pass"] = best
	_assign_polarity()
	_refresh_rule_labels()

# Which traits a pass reads: one for an atom, two for a compound.
func _pass_modalities(ps: Dictionary) -> Array:
	var out: Array = [str(RULE_DIMENSION.get(str(ps.get("a", "")), ""))]
	if str(ps.get("op", "atom")) != "atom":
		out.append(str(RULE_DIMENSION.get(str(ps.get("b", "")), "")))
	return out

# A DENY gate boards everything EXCEPT its pass — an INDEPENDENT roll per gate, with no correction
# afterwards, so `deny_chance` means what it says at every gate count. (An earlier version forced
# the polarities to be mixed on the grounds that a uniform polarity is "one rule inverted once".
# That was simply wrong: the gates carry DIFFERENT rules, so all-deny is not equivalent to
# all-accept. The forcing also made the knob a no-op at 2 gates, where any 0 < p < 1 produced
# exactly one deny gate.)
#
# A COMPOUND pass is never denied: "NO (1 EYE AND BLUE)" is a De Morgan puzzle, and `andnot` /
# `ornot` already provide negation in a form that can be read straight off the chip.
func _assign_polarity() -> void:
	for ar in _areas:
		ar["deny"] = false
	if deny_chance <= 0.0:
		return
	for ar in _areas:
		if str(ar["pass"].get("op", "atom")) != "atom":
			continue
		ar["deny"] = game.rng.randf() < deny_chance
	_avoid_double_negatives()

# Swapping the rule (rather than dropping the deny) keeps the requested deny rate intact; a usable
# modality always has at least one positively-labelled rule, so the fallback is unreachable in
# practice.
func _avoid_double_negatives() -> void:
	for i in _areas.size():
		if not bool(_areas[i]["deny"]):
			continue
		var key: String = str(_areas[i]["pass"].get("a", ""))
		if not NEGATIVE_RULES.has(key):
			continue
		var alt: String = _positive_rule_in(str(RULE_DIMENSION.get(key, "")))
		if alt != "":
			_areas[i]["pass"] = {"op": "atom", "a": alt}
		else:
			_areas[i]["deny"] = false

func _positive_rule_in(m: String) -> String:
	if m == "":
		return ""
	var opts: Array = []
	for r in _usable_rules_in(m):
		if not NEGATIVE_RULES.has(str(r)):
			opts.append(str(r))
	if opts.is_empty():
		return ""
	return str(opts[game.rng.randi_range(0, opts.size() - 1)])

# Once the rules hide the caption is REMOVED, not replaced by a placeholder — an empty box left
# on screen is just clutter over the play area.
#
# A DENY gate reads "NOT SPOTTED" in a warning colour. The word AND the colour both carry it,
# because after the pass hides the player is recalling the polarity too, and a single cue that
# only exists while the chip is up would make that recall a coin flip.
func _refresh_rule_labels() -> void:
	for i in _areas.size():
		if i >= _rule_labels.size():
			continue
		var deny: bool = bool(_areas[i].get("deny", false))
		var txt: String = _pass_label(_areas[i].get("pass", {}))
		_rule_labels[i].text = (DENY_PREFIX + txt) if deny else txt
		_rule_labels[i].add_theme_color_override("font_color",
			Color(1.0, 0.62, 0.52, 1.0) if deny else Color(1, 0.97, 0.72, 1.0))
		var st: StyleBoxFlat = StyleBoxFlat.new()
		st.bg_color = Color(0.16, 0.05, 0.05, 0.52) if deny else Color(0.04, 0.10, 0.07, 0.42)
		st.set_corner_radius_all(10)
		_rule_labels[i].add_theme_stylebox_override("normal", st)
		_rule_labels[i].visible = _chips_visible
		_fit_caption(_rule_labels[i], _rule_labels[i].size.x - 14.0,
			28 if MainGlobals.is_mobile() else 21)
		_rule_labels[i].size.x = _rule_labels[i].size.x

# The chips are up while the pass is public, and again for a moment after a GATE CHANGE — a swap
# the player cannot read is not a memory test, it is a guess. The glimpse is short: you get to
# re-encode the new arrangement, not to keep reading it.
func _update_rules_visibility(now: float) -> void:
	if not _rules_hidden and hide_after_ms > 0.0 and now - _play_start_ms >= hide_after_ms:
		_rules_hidden = true
	var want: bool = (not _rules_hidden) or now < _reveal_until_ms
	if want != _chips_visible:
		_chips_visible = want
		_refresh_rule_labels()

# --- Gate change ------------------------------------------------------------------------------
#
# The passes ROTATE between the gates. This is the answer to the cheapest shortcut in the game:
# after a few seconds the player stops holding "the rule" and starts holding "left = blue", and a
# rule welded to a place costs nothing to recall. A rotation invalidates every such binding at
# once, and the old one keeps interfering, which is exactly the cost rlmadness charges every round.
#
# A rotation (not a shuffle) because it is guaranteed to be a derangement: NO gate keeps its pass,
# so there is never a swap where nothing observable happened.

func _schedule_gate_change(now: float) -> void:
	if gate_change_ms <= 0.0:
		_next_gate_change_ms = 1e18
		return
	var j: float = 1.0 + game.rng.randf_range(-GATE_CHANGE_JITTER, GATE_CHANGE_JITTER)
	_next_gate_change_ms = now + gate_change_ms * j

func _maybe_gate_change(now: float) -> void:
	if gate_change_ms <= 0.0 or _areas.size() < 2 or now < _next_gate_change_ms:
		return
	# Never re-judge an alien that is already in the player's hand: they committed to a decision
	# under the old pass, and having it graded against a new one is the game cheating.
	if _drag_alien != null:
		return
	_schedule_gate_change(now)
	var n: int = _areas.size()
	var k: int = game.rng.randi_range(1, n - 1)
	var passes: Array = []
	var denies: Array = []
	for ar in _areas:
		passes.append(ar.get("pass", {}))
		denies.append(bool(ar.get("deny", false)))
	for i in n:
		var src: int = (i + k) % n
		_areas[i]["pass"] = passes[src]
		_areas[i]["deny"] = denies[src]      # the whole pass travels, polarity included
	gate_changes += 1
	_reveal_until_ms = now + GATE_CHANGE_REVEAL_MS
	_chips_visible = true
	_refresh_rule_labels()
	_field_node.queue_redraw()
	_show_banner("GATE CHANGE")
	game.play_sound("gatechange")

# --- Boarding call ------------------------------------------------------------------------------
#
# One parked alien is called to board within `priority_window_ms`. This is the answer to the
# deepest shortcut: the player chooses what to handle and when, so gates can be worked one at a
# time — and batching a gate removes the task-switch cost that IS the difficulty. A call comes
# from a gate you are probably not looking at and has a deadline, so it interrupts the batch and
# forces the switch, without taking the free play away the rest of the time.

func _eligible_for_call() -> Array:
	var out: Array = []
	for al in _aliens:
		if is_instance_valid(al) and al.state == AState.PARKED_OUTER and al != _drag_alien:
			out.append(al)
	return out

func _update_priority(now: float) -> void:
	if priority_every_ms <= 0.0:
		return
	if _called_al != null:
		# The call survives being PICKED UP. Ending it on "no longer parked" would let the player
		# grab the called alien and drop it straight back — a legal no-op — to cancel the clock for
		# free. It ends only when the alien is genuinely resolved (the scoring paths call
		# _end_call_for) or when it is no longer at the gate at all.
		var st: int = -1
		if is_instance_valid(_called_al):
			st = _called_al.state
		var pending: bool = st == AState.PARKED_OUTER or st == AState.DRAGGED or st == AState.SNAPPING
		if not pending:
			_clear_call()
		elif now >= _called_until_ms:
			calls_missed += 1
			_score_mistake(_called_al, now)   # a called passenger left standing is a missed boarding
			_clear_call()
			_next_priority_ms = now + priority_every_ms
		else:
			var left: float = (_called_until_ms - now) / maxf(1.0, priority_window_ms)
			_called_al.set_called(true, left)
		return
	if now < _next_priority_ms:
		return
	var cand: Array = _eligible_for_call()
	if cand.is_empty():
		_next_priority_ms = now + CALL_RETRY_MS
		return
	# prefer a gate other than the one called last, so consecutive calls actually force a switch
	var pref: Array = cand.filter(func(a): return a.area_idx != _last_called_area)
	if pref.is_empty():
		pref = cand
	_called_al = pref[game.rng.randi_range(0, pref.size() - 1)]
	_called_until_ms = now + priority_window_ms
	_last_called_area = _called_al.area_idx
	_called_al.set_called(true, 1.0)
	calls_made += 1
	_show_banner("NOW BOARDING")
	game.play_sound("call")

# Called from every path that RESOLVES an alien, so an answered call ends there and then rather
# than waiting for a state check that cannot tell "boarded" from "still being dropped".
func _end_call_for(al) -> void:
	if _called_al != null and _called_al == al:
		_clear_call()

func _clear_call() -> void:
	if _called_al != null and is_instance_valid(_called_al):
		_called_al.set_called(false)
	_called_al = null
	if priority_every_ms > 0.0:
		_next_priority_ms = _last_now + priority_every_ms

# A short caption across the top of the field. Announcements have to be readable at a glance while
# the player's attention is on an alien, so: one short phrase, high contrast, gone by itself.
func _show_banner(txt: String) -> void:
	if _banner != null and is_instance_valid(_banner):
		_banner.queue_free()
	var lbl: Label = Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 210
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.add_theme_font_size_override("font_size", int(_alien_radius * (1.05 if MainGlobals.is_mobile() else 0.95)))
	lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 8)
	_place(lbl, _field.position.x, _field.position.y + _field.size.y * 0.5 - _alien_radius,
		_field.size.x, _alien_radius * 2.0)
	add_child(lbl)
	_banner = lbl
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 0.0, BANNER_MS / 1000.0).set_delay(BANNER_MS / 2600.0)
	tw.tween_callback(lbl.queue_free)

# --- Alien creation ---------------------------------------------------------------------------

func _roll_traits(al) -> void:
	al.setup(_alien_radius,
		int(trait_eyes[game.rng.randi_range(0, trait_eyes.size() - 1)]),
		int(trait_colors[game.rng.randi_range(0, trait_colors.size() - 1)]),
		game.rng.randf() < 0.5,
		int(trait_antennae[game.rng.randi_range(0, trait_antennae.size() - 1)]),
		game.rng.randf() < trait_spots_chance)

func _spawn_alien() -> void:
	var al: Node2D = Node2D.new()
	al.set_script(ALIEN_SCRIPT)
	_alien_root.add_child(al)
	_roll_traits(al)
	al.state = AState.ROAM
	al.sim_pos = _random_free_point(_alien_radius, true, al)
	al.position = al.sim_pos
	al.wander_target = _random_free_point(_alien_radius)
	al.retarget_ms = 0.0
	al.z_index = _next_z()
	_aliens.append(al)

# Force the opening population to hold both answers for every area, instead of trusting the dice.
func _stock_initial_supply() -> void:
	for _t in _aliens.size() * 2:
		var need: Array = _find_supply_gap()
		if need.is_empty():
			return
		var ai: int = int(need[0])
		var want: bool = bool(need[1])
		var victim = null
		for al in _aliens:
			if al.state == AState.ROAM and _gate_wants(al, ai) != want:
				victim = al
				break
		if victim == null:
			return
		_force_pass(victim, _areas[ai].get("pass", {}), _match_want(ai, want))

# A brand new alien, forced onto whichever side of gate `area_idx` the pool is short of.
func _spawn_alien_for(area_idx: int, gate_want: bool) -> void:
	_spawn_alien()
	var al = _aliens[_aliens.size() - 1]
	_force_pass(al, _areas[area_idx].get("pass", {}), _match_want(area_idx, gate_want))

func _next_z() -> int:
	_z_counter += 1
	return _z_counter

func _clear_world() -> void:
	for al in _aliens:
		if is_instance_valid(al):
			al.queue_free()
	_aliens.clear()
	_drag_alien = null
	_called_al = null          # it pointed at an alien that no longer exists
	for ai in _areas.size():
		var ar: Dictionary = _areas[ai]
		for i in ar["inner_owner"].size():
			ar["inner_owner"][i] = null
		_refresh_ring_state(ai)

func _random_free_point(r: float, avoid_aliens: bool = false, ignore_al = null) -> Vector2:
	var lo: Vector2 = _field.position + Vector2(r, r)
	var hi: Vector2 = _field.position + _field.size - Vector2(r, r)
	for _t in 60:
		var p: Vector2 = Vector2(game.rng.randf_range(lo.x, hi.x), game.rng.randf_range(lo.y, hi.y))
		if not _is_free_point(p, r):
			continue
		if avoid_aliens and not _is_clear_of_aliens(p, r, ignore_al):
			continue
		return p
	# the meadow strip below the circles is free by construction
	return Vector2(game.rng.randf_range(lo.x, hi.x),
		game.rng.randf_range(minf(_meadow_top + r, hi.y), hi.y))

# Respawning on top of a neighbor is an instant overlap the solver then has to unpick; with the
# supply top-up recycling aliens often, that became visible. Place them clear in the first place.
func _is_clear_of_aliens(p: Vector2, r: float, ignore_al) -> bool:
	for al in _aliens:
		if al == ignore_al or not is_instance_valid(al):
			continue
		if al.state == AState.FADING:
			continue
		if p.distance_to(al.sim_pos) < r + al.radius + SEP_PAD:
			return false
	return true

func _is_free_point(p: Vector2, r: float) -> bool:
	for ar in _areas:
		if p.distance_to(Vector2(ar["center"])) < float(ar["r_out"]) + r + KEEP_OUT_PAD:
			return false
	return true

# --- Simulation -------------------------------------------------------------------------------

func _can_play() -> bool:
	return game != null and game.playing and game.level_is_ready \
		and not game.level_is_done and not game.paused()

func _process(dt: float) -> void:
	if not _can_play():
		return
	_simulate(minf(dt, 0.05), game.game_time)   # clamp long frames (tab switch, GC pause)

# One frame of the world. Everything the game does per frame must live here.
func _simulate(d: float, now: float) -> void:
	_last_now = now
	_maybe_gate_change(now)
	_update_rules_visibility(now)
	_update_priority(now)
	for al in _aliens:
		_update_alien(al, d, now)
	_resolve_positions()
	for al in _aliens:
		al.position = al.sim_pos
	_update_snaps(now)
	_update_fades(now)
	_update_hints(now)
	_top_up_supply(now)

# Separation and ring keep-out are INTERLEAVED, not run once each. Keep-out can shove an alien
# into a neighbor, so a single separation pass beforehand is not enough — with a crowded field
# that left aliens visibly touching. Alternating the two constraints lets each fix what the
# other broke, and ending on keep-out guarantees no roamer is left inside a ring.
func _resolve_positions() -> void:
	for _cycle in RESOLVE_CYCLES:
		_separate_aliens()
		for al in _aliens:
			_constrain_alien(al)

func _update_alien(al, d: float, now: float) -> void:
	match al.state:
		AState.ROAM:
			_update_roam(al, d, now)
		AState.SEEKING_SLOT:
			_update_seek(al, d, now)
		AState.LEAVING:
			_update_leaving(al, d)
		AState.PARKED_OUTER:
			if park_patience_ms > 0.0 and now - al.park_ms >= park_patience_ms:
				_give_up(al)

func _steer(al, tgt: Vector2, spd: float, d: float) -> void:
	var to: Vector2 = tgt - al.sim_pos
	var dist: float = to.length()
	var desired: Vector2 = Vector2.ZERO
	if dist > 0.001:
		# ease down on approach so the turn radius stays smaller than the arrival tolerance,
		# then cap by dist/d so a long frame can never overshoot either
		var slow_r: float = al.radius * ARRIVE_RADIUS_MUL
		var spd_eff: float = spd
		if dist < slow_r:
			spd_eff = spd * maxf(0.2, dist / slow_r)
		desired = to / dist * minf(spd_eff, dist / maxf(d, 0.0001))
	al.vel = al.vel.lerp(desired, clampf(d * STEER_RESPONSE, 0.0, 1.0))
	al.sim_pos += al.vel * d
	al.bob_phase += al.vel.length() * d * BOB_RATE
	al.set_bob(sin(al.bob_phase) * al.radius * 0.055)
	if al.vel.length_squared() > 4.0:
		al.set_look(al.vel / al.vel.length())

func _update_roam(al, d: float, now: float) -> void:
	if now >= al.retarget_ms or al.sim_pos.distance_to(al.wander_target) < al.radius * 0.8:
		# Every alien WANTS in. On each retarget it rolls `enter_chance` to actually commit to an
		# area; otherwise it keeps milling about, mostly loitering near the rings so the whole
		# crowd reads as "queueing up" rather than drifting at random.
		al.retarget_ms = now + game.rng.randf_range(900.0, 2200.0)
		if _try_enter(al, now):
			return
		al.wander_target = _wander_target_for(al)
	_steer(al, al.wander_target, _roam_speed, d)

# Semi-random wander: most targets sit in a loitering band just outside a random area's outer
# ring, so aliens congregate around the areas instead of scattering over the whole field.
func _wander_target_for(al) -> Vector2:
	# while barred from entering, keep away from the rings — hovering at a door it cannot use is
	# exactly the "wants in but doesn't" look
	if _last_now < al.entry_block_ms:
		return _random_free_point(al.radius, true, al)
	if not _areas.is_empty() and game.rng.randf() < LOITER_BIAS:
		var ar: Dictionary = _areas[game.rng.randi_range(0, _areas.size() - 1)]
		var c: Vector2 = Vector2(ar["center"])
		var lo_r: float = float(ar["r_out"]) + al.radius * 1.9 + KEEP_OUT_PAD
		for _t in 12:
			var ang: float = game.rng.randf_range(0.0, TAU)
			var rad: float = lo_r + game.rng.randf_range(0.0, al.radius * LOITER_BAND)
			var p: Vector2 = c + Vector2(cos(ang), sin(ang)) * rad
			var lo: Vector2 = _field.position + Vector2(al.radius, al.radius)
			var hi: Vector2 = _field.position + _field.size - Vector2(al.radius, al.radius)
			if p.x >= lo.x and p.x <= hi.x and p.y >= lo.y and p.y <= hi.y and _is_free_point(p, al.radius):
				return p
	return _random_free_point(al.radius)

# An alien decides for itself to go in. Returns true if it committed.
func _try_enter(al, now: float) -> bool:
	if _areas.is_empty() or now < _entry_cooldown_ms:
		return false
	# An alien that was just evicted (or gave up) marching straight back in looks like the drag
	# failed, and the player cannot tell a correct release from a mistake.
	if now < al.entry_block_ms:
		return false
	var ai: int = _choose_area_for(al)
	var ar: Dictionary = _areas[ai]
	# Eagerness follows ROOM. `enter_chance` alone meant an alien beside an EMPTY ring still only
	# committed on ~1 retarget in 6, so it circled the door for a median 6.5 s (worst 25 s) while
	# visibly "wanting in" — which reads as broken. An alien next to a ring with space now goes in
	# almost at once; a full ring attracts no rush, since there is nothing to rush for.
	var cap: int = _ring_capacity(ar)
	var taken: int = _taken_angles(ai, null).size()
	var free_frac: float = clampf(float(cap - taken) / float(maxi(1, cap)), 0.0, 1.0)
	var near_ring: bool = al.sim_pos.distance_to(Vector2(ar["center"])) \
		<= float(ar["r_out"]) + al.radius * 5.0
	var eager: float = free_frac * (0.85 if near_ring else 0.35)
	if game.rng.randf() >= lerpf(enter_chance, EAGER_ENTER, eager):
		return false
	var would_match: bool = _gate_wants(al, ai)
	# An EMPTY ring is a wasted opportunity, so the arrival-mix veto only applies once somebody is
	# already parked — otherwise the balancer can silently hold everyone out of an empty ring.
	if taken > 0 and not _arrival_allowed(would_match):
		return false                     # too many of this kind lately — mill about and retry
	_record_arrival(would_match)
	_entry_cooldown_ms = now + MIN_ENTRY_GAP_MS
	al.state = AState.SEEKING_SLOT
	al.area_idx = ai
	al.park_angle = al.NO_ANGLE  # claimed on arrival at the ring edge, not from across the field
	al.seek_start_ms = now
	return true

# With several areas an alien heads for one it actually belongs to about half the time — that
# alone keeps the arrival mix near 50/50 without any global scheduler.
func _choose_area_for(al) -> int:
	var pool: Array = []
	if _areas.size() > 1 and game.rng.randf() < SMART_ENTRY:
		for i in _areas.size():
			if _gate_wants(al, i):
				pool.append(i)
	if pool.is_empty():
		for i in _areas.size():
			pool.append(i)
	# nearest of the acceptable areas: a cross-field hike gets deflected around the other ring and
	# takes many seconds, which reads as the alien being stuck
	var best: int = int(pool[0])
	var best_d: float = 1e9
	for i in pool:
		var d2: float = al.sim_pos.distance_squared_to(Vector2(_areas[int(i)]["center"]))
		if d2 < best_d:
			best_d = d2
			best = int(i)
	return best

# Keeps roughly half of arrivals matching. Without it, on a level whose rule matches only a third
# of aliens, most walk-ins would be mismatches and "always push it out" would be a winning
# strategy. Never a hard block — just a strong nudge.
func _arrival_allowed(would_match: bool) -> bool:
	if _recent_arrivals.size() < ARRIVAL_WINDOW:
		return true
	var same: int = 0
	for m in _recent_arrivals:
		if bool(m) == would_match:
			same += 1
	if same >= ARRIVAL_SKEW:
		return game.rng.randf() < 0.25
	return true

func _record_arrival(matched: bool) -> void:
	_recent_arrivals.append(matched)
	while _recent_arrivals.size() > ARRIVAL_WINDOW:
		_recent_arrivals.remove_at(0)

func _update_leaving(al, d: float) -> void:
	# release the "may stand inside my own ring" exemption only once genuinely clear of it, so the
	# walk out is continuous instead of a jump
	if al.area_idx >= 0 and al.area_idx < _areas.size():
		var ar_home: Dictionary = _areas[al.area_idx]
		if al.sim_pos.distance_to(Vector2(ar_home["center"])) > float(ar_home["r_out"]) + al.radius:
			al.area_idx = -1
		elif _last_now - al.seek_start_ms > LEAVE_TIMEOUT_MS:
			# boxed in by the crowd on the way out. Seekers have a watchdog; departures need one
			# too, or a blocked alien sits in the ring indefinitely. Dropping the exemption lets
			# the keep-out ease it out over the next frames.
			al.area_idx = -1
	if al.waypoints.is_empty():
		al.state = AState.ROAM
		al.retarget_ms = 0.0
		return
	_steer(al, al.waypoints[0], _roam_speed * 1.35, d)
	if al.sim_pos.distance_to(al.waypoints[0]) <= al.radius * 0.5:
		al.waypoints.remove_at(0)
		if al.waypoints.is_empty():
			al.state = AState.ROAM
			al.retarget_ms = 0.0

func _update_seek(al, d: float, now: float) -> void:
	if al.area_idx < 0 or al.area_idx >= _areas.size():
		_abandon_seek(al)
		return
	# Watchdog: a seeker can never stall forever, whatever the geometry or the crowd do.
	if now - al.seek_start_ms > SEEK_TIMEOUT_MS:
		_abandon_seek(al)
		return
	var ar: Dictionary = _areas[al.area_idx]
	var c: Vector2 = Vector2(ar["center"])
	var to_al: Vector2 = al.sim_pos - c
	if to_al.length_squared() < 0.25:
		to_al = Vector2(0.0, 1.0)

	# Phase 1 — no spot yet: walk straight at the ring along the bearing it already has, and claim
	# a place only on ARRIVAL at the edge, taking the free angle nearest to where it actually got
	# there. Claiming at commit time (possibly from across the field) is what made aliens trek to a
	# specific angle and look like they were filling assigned slots.
	if al.park_angle < al.HAS_ANGLE_MIN:
		if to_al.length() > float(ar["r_out"]) + al.radius * 1.6:
			_steer(al, c + to_al.normalized() * float(ar["s_out"]), _seek_speed, d)
			return
		if not _reserve_park(al.area_idx, al, to_al.angle()):
			_turned_away(al)                   # reached the edge and the ring is full
			return

	# Phase 2 — line up OUTSIDE the ring, then come straight in. Any sideways travel happens on
	# the outside; once inside, the only movement is the radial step onto the lane, where it
	# stops. Sliding around the lane inside the ring is what read as aliens shuffling about.
	var spot: Vector2 = _outer_park_pos(ar, al.park_angle)
	var dir_spot: Vector2 = Vector2(cos(al.park_angle), sin(al.park_angle))
	var off_angle: float = absf(wrapf(to_al.angle() - al.park_angle, -PI, PI))
	if off_angle > _ring_min_da(ar) * 0.5:
		# not lined up yet: hold station just outside the ring and slide round to the right bearing
		_steer(al, c + dir_spot * (float(ar["r_out"]) + al.radius + 4.0), _seek_speed, d)
		return
	_steer(al, spot, _seek_speed, d)
	if al.sim_pos.distance_to(spot) > al.radius * 0.2:
		return
	al.set_hint(0)
	al.vel = Vector2.ZERO
	_start_snap(al, spot, AState.PARKED_OUTER, now)
	al.park_ms = now                           # the response-time clock starts here
	al.set_look((c - al.sim_pos).normalized())
	_field_node.queue_redraw()

# Give up on entering, free any reservation, and go back to roaming. No penalty — this is a
# safety valve, not a judgment.
func _abandon_seek(al) -> void:
	var was_area: int = al.area_idx
	_release_park(al)
	al.state = AState.ROAM
	al.area_idx = -1
	al.waypoints = []
	# head somewhere clear of the ring it just failed to enter, so it visibly walks away instead
	# of hovering at the door and immediately jamming again
	_send_away_from(al, was_area, _last_now)

func _free_inner_slot(al) -> void:
	if al.area_idx < 0 or al.area_idx >= _areas.size() or al.slot_idx < 0:
		return
	var owners: Array = _areas[al.area_idx]["inner_owner"]
	if al.slot_idx < owners.size() and owners[al.slot_idx] == al:
		owners[al.slot_idx] = null
	al.slot_idx = -1
	_field_node.queue_redraw()

# Availability is re-checked every frame during the walk and the miss is only booked when the
# alien actually reaches the gate — that turns a flat punishment into a skill window
# ("quick, free a slot before it gets there").
func _turned_away(al) -> void:
	var home2: int = al.area_idx
	_release_park(al)
	al.state = AState.LEAVING
	al.area_idx = home2            # kept until it is clear of the ring — see _update_leaving
	al.seek_start_ms = _last_now
	_send_away_from(al, home2, _last_now)
	al.waypoints = _exit_waypoints(al, home2)
	game.play_sound("wrong")
	var penalty: int = mini(2, maxi(0, game.score))
	game.add_score_and_time(-penalty, 0)
	game.add_correct_or_mistake(0, 1)
	total_rounds += 1
	_flash_mark(al.sim_pos, "NO ROOM", Color(1.0, 0.55, 0.25))
	MainGlobals.sig_global_update_hud.emit()

# Walk this alien away from `area_idx` and stop it trying to enter again for a while.
# The first leg out of a ring is RADIAL: step straight out, then wander off. Heading directly for
# a distant field point made a departing alien cut diagonally across the annulus, which reads as
# it milling around inside the ring.
func _exit_waypoints(al, area_idx: int) -> Array:
	if area_idx < 0 or area_idx >= _areas.size():
		return [al.wander_target]
	var ar: Dictionary = _areas[area_idx]
	var c: Vector2 = Vector2(ar["center"])
	var dir_out: Vector2 = al.sim_pos - c
	if dir_out.length_squared() < 0.25:
		dir_out = Vector2(0.0, 1.0)
	var edge: Vector2 = c + dir_out.normalized() * (float(ar["r_out"]) + al.radius + 6.0)
	return [edge, al.wander_target]

func _send_away_from(al, area_idx: int, now: float) -> void:
	al.entry_block_ms = now + RE_ENTRY_COOLDOWN_MS
	al.wander_target = _random_free_point(al.radius, true, al)
	if area_idx >= 0 and area_idx < _areas.size():
		var c: Vector2 = Vector2(_areas[area_idx]["center"])
		var keep: float = float(_areas[area_idx]["r_out"]) + al.radius * 4.0
		for _t in 10:
			if al.wander_target.distance_to(c) > keep:
				break
			al.wander_target = _random_free_point(al.radius, true, al)
	al.retarget_ms = now + 2200.0

# Deadlock valve: a parked alien the player never resolves gives up and frees its place.
# A MATCHING alien walking away is a MISS — the player let a valid passenger go. A non-matching
# one costs nothing: leaving is exactly what should have happened to it anyway.
# park_patience_sec = 0 disables the valve entirely (the hardest levels).
func _give_up(al) -> void:
	_end_call_for(al)
	var home3: int = al.area_idx
	if home3 >= 0 and home3 < _areas.size() and _gate_wants(al, home3):
		_score_mistake(al, _last_now)
	_release_park(al)
	al.state = AState.LEAVING
	# area_idx is KEPT until it is actually clear of the ring (see _update_leaving): clearing it
	# here makes the keep-out treat the alien as a trespasser and teleport it outside instantly.
	al.area_idx = home3
	al.seek_start_ms = _last_now
	_send_away_from(al, home3, _last_now)
	al.waypoints = _exit_waypoints(al, home3)

# --- Separation, keep-out, commit ---------------------------------------------------------------

# How far an alien yields in a collision. A SEEKING_SLOT alien is HEAVY (0.15): the loitering
# crowd gathers right where the gate is, and with equal weight a seeker got wedged outside the
# ring and never arrived. Heavy-but-not-immovable means roamers step aside for it while two
# seekers still resolve against each other normally.
func _push_weight(al) -> float:
	if al.state == AState.ROAM or al.state == AState.LEAVING:
		return 1.0
	if al.state == AState.SEEKING_SLOT:
		return 0.6
	return 0.0

# Purely positional (no dt) so it is frame-rate independent. O(n^2) with n <= ~14 is trivial.
func _separate_aliens() -> void:
	var n: int = _aliens.size()
	if n < 2:
		return
	for p in SEP_ITERS:
		for i in n:
			var ai = _aliens[i]
			for j in range(i + 1, n):
				var aj = _aliens[j]
				var wi: float = _push_weight(ai)
				var wj: float = _push_weight(aj)
				var total: float = wi + wj
				if total <= 0.0:
					continue                     # both immovable: leave them be
				var dv: Vector2 = aj.sim_pos - ai.sim_pos
				var dist: float = dv.length()
				var need: float = ai.radius + aj.radius + SEP_PAD
				if dist >= need:
					continue
				var nrm: Vector2
				if dist > 0.0001:
					nrm = dv / dist
				else:
					# exactly coincident: a golden-angle escape keeps it deterministic
					nrm = Vector2(cos(float(i) * 2.399963), sin(float(i) * 2.399963))
					dist = 0.0001
				var overlap: float = need - dist
				ai.sim_pos -= nrm * (overlap * wi / total)
				aj.sim_pos += nrm * (overlap * wj / total)
				if p == 0:
					# kill only the CONVERGING part of the relative velocity, so they stop
					# pressing into each other instead of vibrating against each other
					var rel: float = (aj.vel - ai.vel).dot(nrm)
					if rel < 0.0:
						ai.vel += nrm * rel * (wi / total)
						ai.retarget_ms = 0.0
						aj.vel -= nrm * rel * (wj / total)
						aj.retarget_ms = 0.0

# `own_idx` is the area an alien is allowed INSIDE (its own, while seeking/parked/leaving). Even
# there it is only allowed in the ANNULUS: aliens never walk over an inner ring — the only way in
# is the player dragging one there.
func _push_out_of_areas(p: Vector2, r: float, own_idx: int) -> Vector2:
	var q: Vector2 = p
	for _pass in 2:                              # twice, so squeezing out of one disk resolves
		for i in _areas.size():
			var ar: Dictionary = _areas[i]
			var c: Vector2 = Vector2(ar["center"])
			var need: float = float(ar["r_out"]) + r + KEEP_OUT_PAD
			if i == own_idx:
				need = float(ar["r_in"]) + r + INNER_PAD
			var dv: Vector2 = q - c
			var dist: float = dv.length()
			if dist >= need:
				continue
			if dist < 0.0001:
				dv = Vector2(0.0, 1.0)
				dist = 0.0001
			q = c + dv / dist * need
	return q

# Applies the ring keep-out and the field bounds to sim_pos. Does NOT commit to `position` —
# it runs several times per frame inside _resolve_positions.
# Tangential escape from a ring/edge pinch. Returns a position slid around the offending ring.
func _slide_out_of_wedge(p: Vector2, r: float, own_idx: int) -> Vector2:
	var q: Vector2 = p
	for i in _areas.size():
		var ar: Dictionary = _areas[i]
		var c: Vector2 = Vector2(ar["center"])
		var need: float = float(ar["r_out"]) + r + KEEP_OUT_PAD
		if i == own_idx:
			need = float(ar["r_in"]) + r + INNER_PAD
		var dv: Vector2 = q - c
		var dist: float = dv.length()
		if dist >= need - 0.01 or dist < 0.0001:
			continue
		# still inside after the clamp: step around the ring toward the field centre
		var nrm: Vector2 = dv / dist
		var tang: Vector2 = Vector2(-nrm.y, nrm.x)
		var to_middle: Vector2 = (_field.position + _field.size * 0.5) - q
		if tang.dot(to_middle) < 0.0:
			tang = -tang
		q += tang * (need - dist)
	return q

func _constrain_alien(al) -> void:
	if al.state == AState.PARKED_OUTER or al.state == AState.PARKED_INNER \
		or al.state == AState.DRAGGED or al.state == AState.SNAPPING \
		or al.state == AState.FADING:
		return
	# SEEKING_SLOT and LEAVING may be inside their OWN disk; everyone else is pushed out of all
	var skip: int = -1
	if al.state == AState.SEEKING_SLOT or al.state == AState.LEAVING:
		skip = al.area_idx
	al.sim_pos = _push_out_of_areas(al.sim_pos, al.radius, skip)
	var lo: Vector2 = _field.position + Vector2(al.radius, al.radius)
	var hi: Vector2 = _field.position + _field.size - Vector2(al.radius, al.radius)
	al.sim_pos = al.sim_pos.clamp(lo, hi)
	# If the clamp put it back inside a disc, the alien is wedged between the ring and a screen
	# edge (the band above a ring can be narrower than an alien). Radial pushing cannot help —
	# slide it along the ring instead, toward the open middle of the field.
	var before_slide: Vector2 = al.sim_pos
	al.sim_pos = _slide_out_of_wedge(al.sim_pos, al.radius, skip)
	if al.sim_pos.distance_squared_to(before_slide) > 0.01:
		# genuinely pinched: aim at the open middle so it walks itself free
		var middle: Vector2 = _field.position + _field.size * 0.5
		if al.state == AState.ROAM:
			al.wander_target = middle
			al.retarget_ms = _last_now + 1600.0
		elif al.state == AState.LEAVING:
			al.waypoints = [middle]
	al.sim_pos = al.sim_pos.clamp(lo, hi)
	# Bounce only when actually pressing OUTWARD. This runs once per resolve cycle, so it has to
	# be idempotent: a plain "flip if out of bounds" would flip an odd/even number of times and
	# could send the alien straight back into the wall.
	if (al.sim_pos.x <= lo.x + 0.01 and al.vel.x < 0.0) \
		or (al.sim_pos.x >= hi.x - 0.01 and al.vel.x > 0.0):
		al.vel.x = -al.vel.x
		al.retarget_ms = 0.0
	if (al.sim_pos.y <= lo.y + 0.01 and al.vel.y < 0.0) \
		or (al.sim_pos.y >= hi.y - 0.01 and al.vel.y > 0.0):
		al.vel.y = -al.vel.y
		al.retarget_ms = 0.0

# --- Drag -------------------------------------------------------------------------------------

func _on_catcher_gui_input(event: InputEvent) -> void:
	# Handle ONLY mouse events. Both mouse->touch and touch->mouse emulation are on, so each
	# tap/drag fires both a mouse and a touch event; mouse alone covers finger and pointer.
	if not _can_play():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var al = _topmost_alien_at(event.position)
			if al != null:
				_begin_drag(al, event.position)
				get_viewport().set_input_as_handled()
		else:
			_drop_dragged(game.game_time)
	elif event is InputEventMouseMotion and _drag_alien != null:
		if is_instance_valid(_drag_alien):
			var lo: Vector2 = _field.position + Vector2(_drag_alien.radius, _drag_alien.radius)
			var hi: Vector2 = _field.position + _field.size - Vector2(_drag_alien.radius, _drag_alien.radius)
			_drag_alien.sim_pos = (event.position + _drag_offset).clamp(lo, hi)
			_drag_alien.position = _drag_alien.sim_pos
			_update_drag_hint()

func _topmost_alien_at(p: Vector2):
	var best = null
	var best_z: int = -2147483648
	for al in _aliens:
		if not is_instance_valid(al):
			continue
		if al.state == AState.PARKED_INNER or al.state == AState.SNAPPING \
			or al.state == AState.FADING:
			continue                                    # not grabbable
		if p.distance_to(al.sim_pos) <= al.radius * 1.20 and al.z_index >= best_z:
			best_z = al.z_index
			best = al
	return best

func _begin_drag(al, p: Vector2) -> void:
	if al.state == AState.PARKED_OUTER:
		al.drag_from_state = AState.PARKED_OUTER
	else:
		# a grabbed seeker/leaver collapses to ROAM and RELEASES its reservation
		if al.state == AState.SEEKING_SLOT:
			_release_park(al)
		al.drag_from_state = AState.ROAM
		al.area_idx = -1
	# Response time is measured from the alien PARKING in the outer ring to the player GRABBING
	# it — the decision time. It deliberately excludes how long the drag itself takes, which is
	# hand speed, not thinking. Banked here and only counted if the drop turns out correct.
	if al.drag_from_state == AState.PARKED_OUTER:
		al.grab_delay_ms = maxf(0.0, game.game_time - al.park_ms)
	else:
		al.grab_delay_ms = -1.0
	al.drag_origin = al.sim_pos
	al.state = AState.DRAGGED
	al.vel = Vector2.ZERO
	al.z_index = 1000
	al.set_hint(3)
	_drag_offset = al.sim_pos - p
	_drag_alien = al          # without this, motion events are ignored and the alien just freezes

func _region_at(p: Vector2) -> Array:
	for i in _areas.size():
		var ar: Dictionary = _areas[i]
		var dist: float = p.distance_to(Vector2(ar["center"]))
		if dist <= float(ar["r_in"]):
			return [Region.INNER, i]
		if dist <= float(ar["r_out"]):
			return [Region.OUTER, i]
	return [Region.FIELD, -1]

# The hint says whether the drop would be ACCEPTED, never whether the alien matches the rule.
func _update_drag_hint() -> void:
	var al = _drag_alien
	if al == null or not is_instance_valid(al):
		return
	var res: Array = _region_at(al.sim_pos)
	var kind: int = int(res[0])
	var idx: int = int(res[1])
	var legal: bool = false
	if al.drag_from_state == AState.PARKED_OUTER:
		legal = kind == Region.FIELD or (kind == Region.INNER and idx == al.area_idx) \
			or (kind == Region.OUTER and idx == al.area_idx)
	else:
		legal = kind == Region.FIELD
	al.set_hint(3 if legal else 2)
	_field_node.highlight_inner = idx if (kind == Region.INNER and legal) else -1
	_field_node.highlight_outer = al.area_idx if al.drag_from_state == AState.PARKED_OUTER else -1
	_field_node.queue_redraw()

func _drop_dragged(now: float) -> void:
	var al = _drag_alien
	_drag_alien = null
	_field_node.highlight_inner = -1
	_field_node.highlight_outer = -1
	_field_node.queue_redraw()
	if al == null or not is_instance_valid(al):
		return
	al.set_hint(0)
	var res: Array = _region_at(al.sim_pos)
	var kind: int = int(res[0])
	var idx: int = int(res[1])
	if al.drag_from_state == AState.PARKED_OUTER:
		var home: int = al.area_idx
		if home < 0 or home >= _areas.size():
			_reject(al, now)
			return
		var matched: bool = _gate_wants(al, home)
		# Both judgments COMMIT. A wrong call is scored against the player, not undone.
		if kind == Region.INNER and idx == home:
			_accept_into_inner(al, now, not matched)
		elif kind == Region.FIELD:
			_send_to_field(al, now, matched)
		else:
			_reject(al, now)                 # OUTER(home) is a silent no-op; other areas illegal
	else:
		if kind == Region.FIELD:
			al.state = AState.ROAM
			al.retarget_ms = 0.0
			al.z_index = _next_z()
		else:
			_reject(al, now)

# A big ✓/✗ that floats up and fades, plus a colour flash on the alien itself. The small hint
# ring alone was too subtle to tell a correct call from a mistake at a glance.
func _flash_mark(at: Vector2, txt: String, col: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 200
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.add_theme_font_size_override("font_size", int(_alien_radius * 2.1))
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 8)
	var w: float = _alien_radius * 5.0
	var h: float = _alien_radius * 2.6
	lbl.size = Vector2(w, h)
	lbl.position = at - Vector2(w * 0.5, h * 0.5)
	add_child(lbl)
	var tw: Tween = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - MARK_RISE, MARK_MS / 1000.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, MARK_MS / 1000.0).set_delay(MARK_MS / 2200.0)
	tw.chain().tween_callback(lbl.queue_free)

func _score_correct(al, now: float) -> void:
	total_rounds += 1
	total_corrects += 1
	# use the banked park->grab time; fall back to park->now for any non-drag scoring path
	var elapsed: float = al.grab_delay_ms if al.grab_delay_ms >= 0.0 else maxf(0.0, now - al.park_ms)
	al.grab_delay_ms = -1.0
	times_to_answer.append(elapsed)
	while times_to_answer.size() > 20:
		times_to_answer.remove_at(0)
	var speed_bonus: int = maxi(0, 10 - int(elapsed / 400.0))
	game.add_score_and_time(12 + speed_bonus, 0)
	game.add_correct_or_mistake(1, 0)
	game.play_sound("correct")
	_flash_mark(al.sim_pos, "✓ +%d" % (12 + speed_bonus), Color(0.35, 1.0, 0.45))
	_flash_hint(al, 1, now)

# MISTAKE = a legal move with the wrong judgment. It is SCORED but still CARRIED OUT — the alien
# goes where the player put it. Fighting the player's input by springing the alien back reads as
# the game refusing the gesture, when it should just say "that was wrong" and let it stand.
# (Contrast _reject, which refuses moves the rules genuinely do not permit.)
func _score_mistake(al, now: float) -> void:
	var penalty: int = mini(4, maxi(0, game.score))
	game.add_score_and_time(-penalty, 0)
	game.add_correct_or_mistake(0, 1)
	game.play_sound("wrong")
	total_rounds += 1
	_flash_mark(al.sim_pos, "✗ -%d" % penalty, Color(1.0, 0.38, 0.30))
	_flash_hint(al, 2, now)      # red pulse so the mistake is visible even though the move stands

# Drop into this area's inner ring. Correct when the alien matches the rule; a scored mistake
# when it doesn't — but either way it goes in.
func _accept_into_inner(al, now: float, is_mistake: bool) -> void:
	_end_call_for(al)
	_release_park(al)
	if is_mistake:
		_score_mistake(al, now)
	else:
		_score_correct(al, now)

	# A CORRECT boarding starts dissolving the moment the player lets go — it boards, it does not
	# linger. Waiting SNAP_MS to glide onto a slot and then INNER_HOLD_MS before the fade left a
	# correctly-handled alien sitting there for over 1.5 s, which reads as "still to deal with"
	# on exactly the gate the player has just finished with. No inner slot is claimed at all:
	# it fades where it was dropped, which is already inside the ramp.
	if not is_mistake:
		al.state = AState.FADING
		al.fade_t0 = now
		_field_node.queue_redraw()
		return

	# A MISTAKE still takes a slot and holds: the move stands, and the alien has to remain visible
	# long enough for the red flash to be connected to it.
	var ar: Dictionary = _areas[al.area_idx]
	var owners: Array = ar["inner_owner"]
	var slot: int = -1
	for i in owners.size():
		if owners[i] == null:
			owners[i] = al
			slot = i
			break
	if slot < 0:
		# inner ring momentarily full — pause in place, then leave
		al.state = AState.FADING
		al.fade_t0 = now
		return
	al.slot_idx = slot
	al.state = AState.PARKED_INNER
	al.park_ms = now
	_start_snap(al, _inner_slot_pos(ar, slot), AState.PARKED_INNER, now)
	_field_node.queue_redraw()

# Drop out onto the open field. Correct when the alien does NOT match the rule; a scored mistake
# when it does — but either way it is released and roams off from where it was dropped.
func _send_to_field(al, now: float, is_mistake: bool) -> void:
	_end_call_for(al)
	var home: int = al.area_idx
	_release_park(al)
	_send_away_from(al, home, now)
	if is_mistake:
		_score_mistake(al, now)
	else:
		_score_correct(al, now)
	al.state = AState.ROAM
	al.area_idx = -1
	al.vel = Vector2.ZERO
	al.z_index = _next_z()

# ILLEGAL = a move the rules don't permit (field -> any ring; another area's ring -> this inner
# ring). It costs nothing and is simply refused: an affordance error, not a judgment error.
func _reject(al, now: float) -> void:
	al.set_hint(2)
	_start_snap(al, al.drag_origin, al.drag_from_state, now)

# A hint ring that clears itself, so a mistake that COMMITS still flashes red on its way out.
func _flash_hint(al, h: int, now: float) -> void:
	al.set_hint(h)
	al.hint_until_ms = now + HINT_FLASH_MS

func _update_hints(now: float) -> void:
	for al in _aliens:
		if al.hint_until_ms > 0.0 and now >= al.hint_until_ms:
			al.hint_until_ms = 0.0
			al.set_hint(0)

# Snap-back is manual, not a Tween, so separation (which treats SNAPPING as immovable) can
# never fight the animation.
func _start_snap(al, to: Vector2, end_state: int, now: float) -> void:
	al.snap_from = al.sim_pos
	al.snap_to = to
	al.snap_t0 = now
	al.snap_end_state = end_state
	al.state = AState.SNAPPING

func _update_snaps(now: float) -> void:
	for al in _aliens:
		if al.state != AState.SNAPPING:
			continue
		var t: float = clampf((now - al.snap_t0) / SNAP_MS, 0.0, 1.0)
		var e: float = 1.0 - pow(1.0 - t, 3.0)          # ease-out cubic
		al.sim_pos = al.snap_from.lerp(al.snap_to, e)
		al.position = al.sim_pos
		if t >= 1.0:
			al.state = al.snap_end_state
			al.vel = Vector2.ZERO
			al.retarget_ms = 0.0
			if al.hint_until_ms <= 0.0:
				al.set_hint(0)
			al.park_ms = now
			if al.snap_end_state == AState.ROAM:
				al.area_idx = -1
				al.z_index = _next_z()

# A promoted alien celebrates briefly, then fades and is recycled with fresh traits elsewhere.
# That keeps the inner ring turning over, the population constant, and the trait mix fresh.
func _update_fades(now: float) -> void:
	for al in _aliens:
		if al.state == AState.PARKED_INNER:
			if now - al.park_ms >= INNER_HOLD_MS:
				_free_inner_slot(al)
				al.state = AState.FADING
				al.fade_t0 = now
		elif al.state == AState.FADING:
			var t: float = clampf((now - al.fade_t0) / FADE_MS, 0.0, 1.0)
			al.self_modulate.a = 1.0 - t
			if t >= 1.0:
				_recycle(al)
		elif al.fade_in_t0 > 0.0:
			var ti: float = clampf((now - al.fade_in_t0) / FADE_MS, 0.0, 1.0)
			al.self_modulate.a = ti
			if ti >= 1.0:
				al.fade_in_t0 = 0.0

# --- Population supply -------------------------------------------------------------------------
# The roaming pool must always hold enough aliens that MATCH each area's rule and enough that
# don't, or the game runs dry: with rule BLUE, once the blue ones have been promoted and recycled
# to random colors there may be no correct answer left to give, and every arrival becomes an
# eviction. These keep both sides stocked.

# [area_idx, want_match] for the first shortage found, or [] when every side is stocked.
func _find_supply_gap(ignore_al = null) -> Array:
	for i in _areas.size():
		var m: int = 0
		var nm: int = 0
		for al in _aliens:
			if al == ignore_al:
				continue
			if al.state != AState.ROAM and al.state != AState.SEEKING_SLOT \
				and al.state != AState.PARKED_OUTER:
				continue
			if _gate_wants(al, i):
				m += 1
			else:
				nm += 1
		if m < MIN_SUPPLY:
			return [i, true]
		if nm < MIN_SUPPLY:
			return [i, false]
	return []

# Nudge the minimum number of traits so `_alien_matches(al, rule_key) == want`. Everything else
# stays randomly rolled, so the alien is still a fresh independent draw on every other dimension.
func _force_rule(al, rule_key: String, want: bool) -> void:
	if COLOR_RULE_ID.has(rule_key):
		var want_id: int = int(COLOR_RULE_ID[rule_key])
		if want:
			al.color_id = want_id
		else:
			al.color_id = _other_from(trait_colors, want_id, al.color_id)
	elif rule_key.begins_with("eyes"):
		var n: int = int(rule_key.substr(4))
		al.eyes = n if want else _other_from(trait_eyes, n, al.eyes)
	elif rule_key.begins_with("ant"):
		var a: int = int(rule_key.substr(3))
		al.antennae = a if want else _other_from(trait_antennae, a, al.antennae)
	elif rule_key == "spots":
		al.has_spots = want
	elif rule_key == "nospots":
		al.has_spots = not want
	elif rule_key == "fat":
		al.is_fat = want
	elif rule_key == "thin":
		al.is_fat = not want
	al.queue_redraw()

# Make `_pass_matches(al, ps) == want` by nudging as few traits as possible.
#
# Correct because the two atoms always come from DIFFERENT modalities, so forcing one cannot
# change the other's truth. Note the asymmetry: to SATISFY an AND both sides must be set, but to
# BREAK one only a single side is needed (and vice versa for OR) — forcing both when one would do
# would correlate the two traits and quietly weaken the confusion the whole game rests on.
func _force_pass(al, ps: Dictionary, want: bool) -> void:
	var op: String = str(ps.get("op", "atom"))
	var ka: String = str(ps.get("a", ""))
	if ka == "":
		return
	if op == "atom":
		_force_rule(al, ka, want)
		return
	var kb: String = str(ps.get("b", ""))
	if kb == "":
		_force_rule(al, ka, want)
		return
	var neg_b: bool = op == "andnot" or op == "ornot"
	var is_and: bool = op == "and" or op == "andnot"
	# work in terms of B' = the operand AFTER the operator's own negation
	var set_a: bool = false
	var va: bool = false
	var set_b: bool = false
	var vb: bool = false
	if is_and:
		if want:
			set_a = true
			va = true
			set_b = true
			vb = true
		elif game.rng.randf() < 0.5:
			set_a = true            # A false is enough to break the AND
		else:
			set_b = true            # ...or B' false
	else:
		if not want:
			set_a = true
			set_b = true            # both sides false to break the OR
		elif game.rng.randf() < 0.5:
			set_a = true
			va = true               # either side true satisfies the OR
		else:
			set_b = true
			vb = true
	if set_a:
		_force_rule(al, ka, va)
	if set_b:
		_force_rule(al, kb, vb != neg_b)     # B' -> B

# Any value from `pool` other than `avoid`; falls back to the current value if the pool has none.
func _other_from(pool: Array, avoid: int, fallback: int) -> int:
	var alts: Array = pool.filter(func(v): return int(v) != avoid)
	if alts.is_empty():
		return fallback
	return int(alts[game.rng.randi_range(0, alts.size() - 1)])

# Periodically swap out a surplus roamer to cover a shortage, so both answers stay available even
# when the player never promotes anyone.
func _top_up_supply(now: float) -> void:
	if now < _next_topup_ms:
		return
	_next_topup_ms = now + TOPUP_PERIOD_MS
	# A burst of promotions can empty more than one side at once, so keep swapping until every
	# side is stocked (bounded, so one tick can never churn the whole field).
	for _swap in TOPUP_MAX_PER_TICK:
		var need: Array = _find_supply_gap()
		if need.is_empty():
			return
		var ai: int = int(need[0])
		var want: bool = bool(need[1])
		# take the surplus roamer FARTHEST from any ring, so the swap is out of the player's focus
		# 1st choice: a surplus roamer we can spare; 2nd: any other-class roamer; then spawn.
		var victim = null
		var best_d: float = -1.0
		var fallback = null
		var fallback_d: float = -1.0
		for al in _aliens:
			if al.state != AState.ROAM or _gate_wants(al, ai) == want:
				continue
			var d: float = _dist_to_nearest_area(al.sim_pos)
			if _can_spare(al):
				if d > best_d:
					best_d = d
					victim = al
			elif d > fallback_d:
				fallback_d = d
				fallback = al
		if victim == null:
			victim = fallback
		if victim == null:
			# Nothing can be spared without opening another gap — ADD an alien instead. The
			# population drains back to num_free_aliens as promoted aliens are retired.
			if _aliens.size() < num_free_aliens + SUPPLY_HEADROOM:
				_spawn_alien_for(ai, want)
				topup_swaps += 1
				continue
			return
		victim.respawn_need = [ai, want]
		victim.state = AState.FADING
		victim.fade_t0 = now
		topup_swaps += 1

# How many roamers fall on `want` side of area `area_idx`'s rule.
func _class_count(area_idx: int, want: bool, ignore_al) -> int:
	var n: int = 0
	for al in _aliens:
		if al == ignore_al or al.state != AState.ROAM:
			continue
		if _gate_wants(al, area_idx) == want:
			n += 1
	return n

# True when converting this alien would not push any area's class below the minimum.
func _can_spare(al) -> bool:
	for i in _areas.size():
		var want: bool = _gate_wants(al, i)
		if _class_count(i, want, al) < MIN_SUPPLY:
			return false
	return true

func _dist_to_nearest_area(p: Vector2) -> float:
	var best: float = 1e9
	for ar in _areas:
		best = minf(best, p.distance_to(Vector2(ar["center"])))
	return best

func _recycle(al) -> void:
	# fill whatever the pool is short of — either an explicit request or the current gap
	var need: Array = al.respawn_need
	al.respawn_need = []
	if need.size() < 2:
		need = _find_supply_gap(al)
	if need.is_empty() and _aliens.size() > num_free_aliens:
		# fully stocked and above base size — retire this one so the population settles back
		_aliens.erase(al)
		al.queue_free()
		return
	_roll_traits(al)
	al.set_called(false)
	if need.size() >= 2 and need[0] is int:
		var ai2: int = int(need[0])
		# resolved against the gate's rule AS IT IS NOW: a gate change may have swapped the pass
		# (or its polarity) while this alien was fading out
		_force_pass(al, _areas[ai2].get("pass", {}), _match_want(ai2, bool(need[1])))
	al.self_modulate.a = 0.0          # fade in rather than pop into existence
	al.fade_in_t0 = _last_now
	al.state = AState.ROAM
	al.area_idx = -1
	al.slot_idx = -1
	al.park_angle = al.NO_ANGLE
	al.waypoints = []
	al.vel = Vector2.ZERO
	al.sim_pos = _random_free_point(al.radius, true, al)
	al.position = al.sim_pos
	al.retarget_ms = 0.0
	al.z_index = _next_z()

# --- Level flow -------------------------------------------------------------------------------

func new_game(from_scratch: bool = true) -> void:
	game.level_is_done = false
	game.level_is_ready = false
	if from_scratch:
		AliensG.reset_queue_from(AliensG.starting_level_id)
	current_level_id = AliensG.pop_next_level_id()
	game.need_to_increase_level = false
	total_rounds = 0
	total_corrects = 0
	game.corrects = 0
	game.mistakes = 0
	times_to_answer.clear()
	_rules_hidden = false
	_chips_visible = true
	_reveal_until_ms = 0.0
	_recent_arrivals.clear()
	_entry_cooldown_ms = 0.0
	_next_topup_ms = 0.0
	_drag_alien = null
	_called_al = null
	_last_called_area = -1
	gate_changes = 0
	calls_made = 0
	calls_missed = 0
	_clear_world()
	_load_level(current_level_id)
	_layout()
	call_deferred("_layout")     # re-apply once the menu->level transition settles
	_pick_rules()
	# the clocks start when play does (_on_game_popup_closed), not while the intro is up
	_next_gate_change_ms = 1e18
	_next_priority_ms = 1e18
	_field_node.rebuild_sky()      # a new sky for each level
	for _i in num_free_aliens:
		_spawn_alien()
	_stock_initial_supply()
	_field_node.queue_redraw()

	var hide_txt: String = "never" if hide_after_ms <= 0.0 else "%d s" % int(hide_after_ms / 1000.0)
	var body: String = ("Aliens queue up in a gate's outer ring.\n" +
		"Drag one the pass ACCEPTS onto the\n" +
		"boarding ramp, and one it does not\n" +
		"back out to the hall.\n")
	# Only name the twists THIS ROUND actually drew. _pick_rules has already run, so the briefing
	# can report what is really on the board rather than what the level permits — with an
	# independent deny roll, a level that allows deny gates will sometimes have none.
	var n_deny: int = 0
	var n_compound: int = 0
	for ar in _areas:
		if bool(ar.get("deny", false)):
			n_deny += 1
		if str(ar.get("pass", {}).get("op", "atom")) != "atom":
			n_compound += 1
	if n_compound > 0:
		body += "\nSome passes ask for TWO things at once.\n"
	if n_deny > 0:
		body += "\nA red \"NOT ...\" pass boards everyone EXCEPT that.\n"
	if gate_change_ms > 0.0 and num_areas > 1:
		body += "\nGATE CHANGE: the passes move between gates.\n"
	if priority_every_ms > 0.0:
		body += "\nNOW BOARDING: the ringed alien must be\ndealt with before its ring runs out.\n"
	body += "\nGates: %d\nPass comes down after: %s\nTime: %d s" % [num_areas, hide_txt, level_time_sec]
	var intro: PopupText = game.show_text_popup(self, "Level %d" % current_level_id, body)
	intro.closed.connect(_on_game_popup_closed)

func _on_game_popup_closed() -> void:
	if not game.level_is_done and not game.level_is_ready:
		_layout()
		_play_start_ms = game.game_time
		game.level_is_ready = true
		# start the interference clocks now: the intro popup can sit open for any length of time,
		# and a gate change firing on the first frame of play would be unreadable
		_schedule_gate_change(_play_start_ms)
		_next_priority_ms = (_play_start_ms + priority_every_ms) if priority_every_ms > 0.0 else 1e18
		started_playing.emit()

func stop_level() -> void:
	_clear_world()

func _load_level(id: int) -> void:
	var def: Dictionary = AliensLevelConfig.get_level(id)
	level_time_sec = int(def.get("level_time_sec", 70))
	rules_pool = def.get("rules", []).duplicate()
	num_areas = maxi(1, int(def.get("num_areas", 1)))
	alien_speed_frac = float(def.get("alien_speed", 0.055))
	alien_size_key = str(def.get("alien_size", "med"))
	num_free_aliens = maxi(3, int(def.get("num_free_aliens", 8)))
	hide_after_ms = float(def.get("hide_after_sec", 0.0)) * 1000.0
	enter_chance = clampf(float(def.get("enter_chance", 0.30)), 0.0, 1.0)
	park_patience_ms = maxf(0.0, float(def.get("park_patience_sec", 0.0)) * 1000.0)
	trait_colors = def.get("colors", [0, 1, 2]).duplicate()
	trait_eyes = def.get("eye_counts", [1, 2, 3]).duplicate()
	trait_antennae = def.get("antennae_counts", [0, 1, 2]).duplicate()
	trait_spots_chance = float(def.get("spots_chance", 0.5))
	gate_change_ms = maxf(0.0, float(def.get("gate_change_sec", 0.0)) * 1000.0)
	deny_chance = clampf(float(def.get("deny_chance", 0.0)), 0.0, 1.0)
	priority_every_ms = maxf(0.0, float(def.get("priority_every_sec", 0.0)) * 1000.0)
	priority_window_ms = maxf(1500.0, float(def.get("priority_window_sec", 6.0)) * 1000.0)
	compound_chance = clampf(float(def.get("compound_chance", 0.0)), 0.0, 1.0)
	_chip_lines = 2 if compound_chance > 0.0 else 1
	compound_ops = def.get("compound_ops", ALL_OPS).duplicate()
	if compound_chance <= 0.0:
		compound_ops = []
	else:
		compound_ops = compound_ops.filter(func(o): return ALL_OPS.has(str(o)))
		if compound_ops.is_empty():
			compound_ops = ALL_OPS.duplicate()
	if trait_colors.is_empty():
		trait_colors = [0, 1, 2]
	if trait_eyes.is_empty():
		trait_eyes = [1, 2, 3]
	if trait_antennae.is_empty():
		trait_antennae = [0, 1, 2]

	game.set_reset_time_left(level_time_sec)
	game.set_time_left(0, 0, level_time_sec)
	game.level_label_changed("Level " + str(def.get("name", id)))

func _on_time_over() -> void:
	if game.level_is_done:
		return
	_level_done()

func _level_done() -> void:
	game.level_is_done = true
	_drag_alien = null
	AliensG.record_level_result(current_level_id, pct_correct())
	game.sig_level_is_done.emit(true)
	MainGlobals.global_level_is_done(true)
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	var extra: String = "\n\nAccuracy: %d%%\nMean time: %s" % [
		pct_correct(),
		("%d ms" % mean_response_time_ms()) if not times_to_answer.is_empty() else "N/A"
	]
	game.show_level_done_popup(self, "", extra, 0, "")

func _on_level_done_popup_closed() -> void:
	sig_level_is_done.emit(true)

func mean_response_time_ms() -> int:
	if times_to_answer.is_empty():
		return NO_ANSWER_MS      # no correct call at all — report it as bad, not as instant
	var s: float = 0.0
	for t in times_to_answer:
		s += t
	return roundi(s / times_to_answer.size())

func pct_correct() -> int:
	if total_rounds <= 0:
		return 0
	return int(round(100.0 * float(total_corrects) / float(total_rounds)))
