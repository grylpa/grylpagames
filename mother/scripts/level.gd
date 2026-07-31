extends CanvasLayer

signal sig_session_done
signal sig_show_main_menu

# Both heads at same x; mother on top half, child on bottom half
const HEAD_X_FRAC: float = 0.82
const M_TOP_FRAC: float = 0.30   # mother y range top (center of range ~0.43, just above screen center)
const M_BOT_FRAC: float = 0.56   # mother y range bottom; child starts at 0.5 (just below mid-range)
# Visuals
var MOTHER_W: float = 30.0
var CHILD_W: float = 25.0
var HEAD_SCALE: float = 0.74

# --- Palette: NIGHT DESERT ---------------------------------------------------------------------
# This is a breathing game in the "Serenity" category, and every sibling there is dark and
# low-chroma (crack 0.04,0.05,0.09; river 0.06,0.18,0.34; udbr 0.04,0.07,0.14). It used to be the
# one bright, high-chroma screen in the category — saturated sand under a pure-green mother and a
# saturated indigo child, three unrelated hue families all shouting at once. It also contradicted
# itself: the results panel and the stats graph were already dark, so the palette flipped the
# moment a session ended.
#
# Now the ground is dark and warm and the SNAKES are the light source. Mother and child sit in one
# hue family and differ in lightness, so they read as the same animal at two ages — the child used
# to be blue for no stated reason, which made them look like unrelated species.
const GROUND_TOP: Color = Color(0.086, 0.067, 0.078)      # horizon, slightly cooler
const GROUND_BOTTOM: Color = Color(0.145, 0.110, 0.106)   # nearer sand, warmer
const GROUND_BANDS: int = 24
# Parallax dune ridges, far to near. Each is a filled band whose top edge is a slow double sine,
# scrolling at its OWN fraction of the world speed — the differing speeds are what read as depth;
# a single layer would just look like a wavy line.
#
# Deliberately NOT a horizon with a moon: the ripples, pebbles, bushes and beetles all establish
# an oblique view of a ground PLANE, and a skyline would contradict every one of them. Ridges sit
# on that same plane.
const DUNE_LAYERS: Array = [
	{"y": 0.14, "amp": 0.055, "period": 1.55, "speed": 0.22, "col": Color(0.115, 0.088, 0.092)},
	{"y": 0.24, "amp": 0.045, "period": 1.05, "speed": 0.40, "col": Color(0.137, 0.104, 0.101)},
	{"y": 0.34, "amp": 0.036, "period": 0.78, "speed": 0.62, "col": Color(0.158, 0.119, 0.110)},
]
const DUNE_STEP: float = 14.0
# Drifting dust. Size, speed and opacity are all derived from the SAME depth value as the mote's
# y position, so a nearer mote is bigger, faster and brighter together — that correlation is what
# reads as depth. Rolling the three independently just looks like noise.
const DUST_COUNT: int = 26
const DUST_R_FAR: float = 0.6
const DUST_R_NEAR: float = 2.2
const DUST_SPEED_FAR: float = 1.3      # multiples of the world scroll speed
const DUST_SPEED_NEAR: float = 3.6
const DUST_A_FAR: float = 0.10
const DUST_A_NEAR: float = 0.30
const DUST_COL: Color = Color(0.86, 0.78, 0.70)
# Vignette: darkens the screen edges so the eye settles on the middle, where the snakes are.
# Drawn on the props canvas, i.e. OVER the snakes — a vignette behind them would be pointless,
# since the thing it needs to de-emphasise is the busy edge of the play area, snakes included.
const VIGNETTE_STEPS: int = 12
# Share of the SHORT side that is darkened. Capped so the darkening stops short of HEAD_X_FRAC
# (0.82): at 0.22 it reached 150 px in from a 680 px canvas, which clipped the heads — the one
# thing on screen the eye is supposed to go to.
const VIGNETTE_DEPTH: float = 0.16
const VIGNETTE_MAX_A: float = 0.26

# --- Head shape ---------------------------------------------------------------------------------
# The head is DRAWN, not a sprite. It used to be head1/2/3-4x.png — a white ellipse with a black
# border and two eyes, tinted to the body colour. An ellipse cannot be made snake-like by any
# transform: scale/rotation/skew are affine, so they map a rectangle to a parallelogram and can
# never produce a taper. Squashing the quad narrower at the nose would squash the BORDER with it,
# giving an outline thick at the base and thin at the snout.
#
# Drawn, the outline can be the real thing: narrow at the snout, widest at the JAW a little behind
# it, then narrowing into the neck. A straight wedge reads as a spearhead; the jaw bulge is what
# makes it read as a snake.
const HEAD_LEN_W: float = 1.30       # head length, in body widths
const HEAD_WIDE_W: float = 1.15      # width at the jaw, in body widths
const HEAD_JAW_AT: float = 0.28      # where the jaw sits, as a share of length back from the nose
const HEAD_NOSE_W: float = 0.30      # snout width as a share of the jaw width
const HEAD_NECK_W: float = 0.86      # width where it meets the body, as a share of the jaw width
const HEAD_STEPS: int = 22           # outline resolution along one side
# No dark border: the BODY has none — it is a banded fill, a lighter spine and a faint halo, and
# nothing else. A dark outline on the head alone was a large part of why it read as a separate
# object stuck on the front. The head now gets the same three ingredients and no outline.
const HEAD_EYE_RING: float = 0.055   # faint lid ring so the eye reads on a banded fill
const HEAD_EYE_AT: float = 0.34      # eye position along the head, share of length from the nose
const HEAD_EYE_OUT: float = 0.56     # eye offset from the spine, share of half-width there
const HEAD_EYE_R: float = 0.17       # eye radius, in body widths
const HEAD_CAP_STEPS: int = 10       # resolution of the rounded snout and neck caps
# The halo fades to nothing toward the neck. Carried all the way round, anything drawn outside the
# outline puts a ring ON the body wherever the head overlaps it — which is what made the head read
# as a separate disc rotating over an unrelated body.
const HEAD_HALO_FADE: float = 0.55   # share of the length over which the halo fades out
const HEAD_STRIPE_FROM: float = 0.42 # dorsal stripe starts this far back from the nose

const RIPPLE_LIGHT: Color = Color(0.62, 0.50, 0.44)       # moonlight catching a dune crest
const RIPPLE_DARK: Color = Color(0.04, 0.03, 0.04)        # the trough behind it
const PEBBLE_COL: Color = Color(0.24, 0.19, 0.19, 0.75)
const BUSH_COL: Color = Color(0.30, 0.23, 0.17, 0.80)
const BEETLE_COL: Color = Color(0.03, 0.025, 0.03, 0.95)
const MOTHER_COL: Color = Color(0.88, 0.63, 0.30, 1.0)    # warm amber
const CHILD_COL: Color = Color(0.96, 0.85, 0.62, 1.0)     # pale gold — same family, lighter
const TEXT_COL: Color = Color(0.93, 0.86, 0.74, 0.90)     # warm cream

# Body shape. A constant-width polyline reads as a cable or a logic-analyzer trace, which is
# exactly how the old thumbnail looked. A real snake tapers, catches light on one side, and casts
# a shadow on the ground it is lying on.
const TAIL_FRAC: float = 0.34        # tail width as a share of head width
const EDGE_MUL: float = 1.20         # dark rim drawn under the body
const HL_MUL: float = 0.34           # highlight width as a share of body width
const HL_OFFSET: float = 0.22        # highlight offset along the normal, in body widths
# The second line under each body is the SOFT EDGE, not a drop shadow. It was a dark offset
# shadow, which on a near-black ground did almost nothing visible.
#
# It has to be a Line2D and not a hand-drawn polyline: draw_polyline has a CONSTANT width, so it
# cannot follow the body's width_curve — at the tail the body is TAIL_FRAC of full width while the
# halo stayed at 100%, ballooning around the thin tail — and its joints are what looked wrong on
# corners. A Line2D gets the same taper and the same round joints as the body for free, because it
# is built by the same function from the same points.
#
# Reusing the existing node rather than adding one is deliberate: the previous soft-edge attempt
# added two more Line2Ds and every body stopped rendering.
const SHADOW_DY: float = 2.0         # slight downward offset, so it still grounds the snake a bit
const GLOW_MUL: float = 1.10         # halo width, as a share of body width
const GLOW_ALPHA: float = 0.18

# The body BREATHES: it swells and brightens on the inhale and settles on the exhale. This is the
# only animation on the body, and deliberately so — it changes nothing geometric (only `width` and
# `default_color`), so it cannot reintroduce the artifacts that offsetting points along their
# normals produced at the turns. It also ties the visuals to the actual mechanic instead of just
# decorating: in a breathing game the snake should visibly breathe.
const PULSE_W_LOW: float = 0.88      # width multiplier when fully exhaled
const PULSE_W_HIGH: float = 1.14     # ...and when fully inhaled
const PULSE_LIGHT: float = 0.20      # brightening at full inhale
const CHILD_START_DROP: float = 60.0 # child starts this far below the mother's band

# The child's body starts at a visible length and lengthens SLOWLY. It used to start at zero and
# reach full length in ~12 s, driven straight off how much history existed — so for the first
# seconds of every session the tail was visibly stretching, and the pattern had to renormalise
# continuously while it did.
# The heads swing round over time rather than snapping to the current direction. The body's turn
# is eased (smootherstep), so a head that tracked the instantaneous tangent looked mechanical
# against it. The mother's used to be set directly from her phase velocity with no smoothing at
# all; the child's was smoothed, but at rate 20, which is fast enough to read as instant.
const HEAD_TURN_RATE: float = 6.0

const CHILD_START_LEN_PX: float = 120.0    # visible tail the moment a session starts
const CHILD_GROW_PX_PER_MS: float = 0.011  # ~40 s from there to filling the screen

# Skin pattern. Both parts are drawn on the IDENTICAL path as the body, so their joints behave
# exactly as the body's do — no normals, no offsets, no UVs. That is the whole point: every
# previous attempt at skin failed at the turns because it needed one of those three.
const BAND_PX: float = 12.0          # spacing of the dark bands along the body
const BAND_DARK: float = 0.82        # how dark a band gets, as a multiplier
const BAND_MAX: int = 56             # cap on bands, so the gradient stays a sane size
const TAIL_SOLID: float = 0.82       # gradient offset at which the tail dissolve begins
# Slither: a lateral undulation travelling down the body toward the tail.
#
# VERTICAL displacement ONLY, and that is the whole design. An earlier attempt displaced each
# point along its LOCAL NORMAL; at a turn that normal rotates through nearly 180 deg between
# samples a couple of px apart, so the displaced points crossed over and the body tangled itself
# at exactly the turns. The path is strictly monotonic in x, so moving points in y alone leaves it
# monotonic in x — and a polyline monotonic in x CANNOT self-intersect, because any vertical line
# still crosses it exactly once. That is a proof, not a tuning.
#
# The phase is keyed to HORIZONTAL DISTANCE FROM THE HEAD, which is monotonic and independent of
# the point count, so it cannot jump when the sampler adds or drops a vertex.
#
# AMP is a share of body width, so it scales with the snake — but note it scales BOTH ways: at a
# body width of 80 an amp of 0.32 is a 26 px wobble, which was too much. Keep it modest.
const SLITHER_AMP_W: float = 0.22    # amplitude, in body widths
const SLITHER_WAVE_W: float = 7.0    # wavelength, in body widths
const SLITHER_SPEED: float = 2.0     # rad/s the wave travels toward the tail
const SLITHER_RAMP_W: float = 3.5    # body widths behind the head before it eases in

const STRIPE_W: float = 0.28         # dorsal stripe width, as a share of body width
const STRIPE_LIGHT: float = 0.40     # how much lighter the stripe is than the body

# Child body history ring buffer — interpolated to eliminate jitter
const HISTORY_INTERVAL_MS: float = 16.0
const HISTORY_SLOTS: int = 3000

var game: GenericGameUtil
var _duration_ms: float = 60000.0
var _elapsed_ms: float = 0.0
var _session_complete: bool = false

var _screen_w: float = 680.0
var _screen_h: float = 788.0
var _head_x: float = 0.0
var _m_top_y: float = 0.0
var _m_bot_y: float = 0.0
var _scroll_px_per_ms: float = 0.04

var _child_y: float = 0.0

var _child_history: PackedFloat32Array
var _history_head: int = 0
var _history_count: int = 0
var _history_last_ms: float = -1000.0

var _child_angle: float = 0.0
var _mother_angle: float = 0.0
var _child_vel_y: float = 0.0   # smooth keyboard velocity (px/s, positive = down)
var _session_ps: int = 0

var _sprite_child: Node2D
var _sprite_mother: Node2D
var _anim_time: float = 0.0
var _head_frame: int = 0
var _bg_seeds: Array = []

# Stats / graph
var _graph: Control = null
var _phase_grid: GridContainer
var _reaction_label: Label
var _trace_segments: Array = []
var _current_trace: Array = []
var _trace_last_ms: float = 0.0
const TRACE_INTERVAL_MS: float = 200.0
const KEY_POLL_INTERVAL_MS: float = 50.0

var _key_poll: Array = []
var _rt_ms: int = 0

var active_mode: bool = false
var _computed_phases: Array = [0.0, 0.0, 0.0, 0.0]

@onready var _canvas: Control = $MotherCanvas
@onready var _timer_label: Label = $SessionOverlay/TimerLabel
@onready var _goal_label: Label = $SessionOverlay/GoalLabel
@onready var _phase_label: Label = $SessionOverlay/PhaseLabel
@onready var _results_panel: Control = $ResultsPanel
@onready var _result_label: Label = $ResultsPanel/Margin/VBox/ResultLabel

# A head as a Node2D that draws itself, so the outline can be a real snake head rather than an
# ellipse. Positioned and rotated by _process exactly as the sprite was.
func _make_head(body_w: float, col: Color, z: int) -> Node2D:
	var nd: Node2D = Node2D.new()
	nd.z_index = z
	nd.visible = false
	nd.set_meta("body_w", body_w)
	nd.set_meta("col", col)
	nd.draw.connect(_draw_head.bind(nd))
	add_child(nd)
	return nd

# Outline in head-local space: +x toward the nose, y across. Widest at the JAW, not at the base.
# BOTH ends are rounded caps — flat cuts left hard corners at the snout and the neck, and the neck
# corners in particular caught the eye every time the head turned.
#
# `extra` pushes the outline outward to make the border, and is faded toward the neck by
# HEAD_HALO_FADE so no dark edge is drawn over the body the head is sitting on.
func _head_half_width(t: float, half: float) -> float:
	if t < HEAD_JAW_AT:
		return half * lerpf(HEAD_NOSE_W, 1.0, smoothstep(0.0, 1.0, t / HEAD_JAW_AT))
	return half * lerpf(1.0, HEAD_NECK_W, smoothstep(0.0, 1.0, (t - HEAD_JAW_AT) / (1.0 - HEAD_JAW_AT)))

func _head_shape(body_w: float, extra: float) -> PackedVector2Array:
	var ln: float = body_w * HEAD_LEN_W
	var half: float = body_w * HEAD_WIDE_W * 0.5
	var nose_x: float = ln * 0.5
	var neck_x: float = -ln * 0.5
	var hw0: float = _head_half_width(0.0, half)
	var hw1: float = _head_half_width(1.0, half)
	var pts: PackedVector2Array = PackedVector2Array()

	# upper edge, nose -> neck
	for i in range(HEAD_STEPS + 1):
		var t: float = float(i) / float(HEAD_STEPS)
		var e: float = extra * (1.0 - smoothstep(1.0 - HEAD_HALO_FADE, 1.0, t))
		pts.append(Vector2(lerpf(nose_x, neck_x, t), -(_head_half_width(t, half) + e)))
	# rounded neck cap, bulging backward; no border here, it is inside the body
	for i in range(1, HEAD_CAP_STEPS):
		var a: float = lerpf(-PI * 0.5, -PI * 1.5, float(i) / float(HEAD_CAP_STEPS))
		pts.append(Vector2(neck_x + cos(a) * hw1, sin(a) * hw1))
	# lower edge, neck -> nose
	for i in range(HEAD_STEPS + 1):
		var t2: float = 1.0 - float(i) / float(HEAD_STEPS)
		var e2: float = extra * (1.0 - smoothstep(1.0 - HEAD_HALO_FADE, 1.0, t2))
		pts.append(Vector2(lerpf(nose_x, neck_x, t2), _head_half_width(t2, half) + e2))
	# rounded snout cap
	for i in range(1, HEAD_CAP_STEPS):
		var a2: float = lerpf(PI * 0.5, -PI * 0.5, float(i) / float(HEAD_CAP_STEPS))
		pts.append(Vector2(nose_x + cos(a2) * (hw0 + extra), sin(a2) * (hw0 + extra)))
	return pts

# One band period of the body's skin, as a multiplier. Mirrors _build_gradient exactly: its stops
# alternate base / BAND_DARK every half period and interpolate linearly, which is a triangle wave.
func _band_shade(dist_px: float) -> float:
	var phase: float = fposmod(dist_px / maxf(1.0, BAND_PX), 1.0)
	return lerpf(BAND_DARK, 1.0, absf(phase * 2.0 - 1.0))

# The head is drawn with the SAME three ingredients as the body and in the same order: faint halo,
# banded fill, lighter spine. No dark outline, because the body has none.
#
# The banding continues the body's: the body pins its bands to pixel distance BACK from the head
# point, and head-local +x runs FORWARD from that same point, so distance = -x carries the phase
# straight across the join with no seam.
func _draw_head(nd: Node2D) -> void:
	var body_w: float = float(nd.get_meta("body_w"))
	var col: Color = nd.get_meta("col")
	var ln: float = body_w * HEAD_LEN_W
	var half: float = body_w * HEAD_WIDE_W * 0.5

	# 1. halo, matching the body's
	nd.draw_colored_polygon(_head_shape(body_w, body_w * (GLOW_MUL - 1.0) * 0.5),
		Color(col, GLOW_ALPHA))

	# 2. banded fill, as transverse strips so each band follows the tapering outline
	var strips: int = HEAD_STEPS * 2
	for i in strips:
		var t0: float = float(i) / float(strips)
		var t1: float = float(i + 1) / float(strips)
		var x0: float = lerpf(ln * 0.5, -ln * 0.5, t0)
		var x1: float = lerpf(ln * 0.5, -ln * 0.5, t1)
		var h0: float = _head_half_width(t0, half)
		var h1: float = _head_half_width(t1, half)
		var sh: float = _band_shade(-(x0 + x1) * 0.5)
		var quad: PackedVector2Array = PackedVector2Array([
			Vector2(x0, -h0), Vector2(x1, -h1), Vector2(x1, h1), Vector2(x0, h0)])
		nd.draw_colored_polygon(quad, Color(col.r * sh, col.g * sh, col.b * sh, 1.0))

	# 3. the dorsal stripe, continuing the body's
	nd.draw_line(Vector2(ln * 0.5 - ln * HEAD_STRIPE_FROM, 0.0), Vector2(-ln * 0.5, 0.0),
		col.lightened(STRIPE_LIGHT), body_w * STRIPE_W, true)

	# eyes on the flanks, looking forward; frame 2 of 4 is a blink
	var ex: float = ln * 0.5 - ln * HEAD_EYE_AT
	var ey: float = _head_half_width(HEAD_EYE_AT, half) * HEAD_EYE_OUT
	var er: float = body_w * HEAD_EYE_R
	for sgn in [-1.0, 1.0]:
		if _head_frame == 2:
			nd.draw_line(Vector2(ex - er, ey * sgn), Vector2(ex + er, ey * sgn),
				col.darkened(0.72), maxf(1.0, er * 0.45), true)
		else:
			nd.draw_circle(Vector2(ex, ey * sgn), er, Color(0.06, 0.05, 0.06), true, -1.0, true)
			nd.draw_arc(Vector2(ex, ey * sgn), er, 0.0, TAU, 14,
				col.lightened(0.30), maxf(1.0, body_w * HEAD_EYE_RING), true)

func _ready() -> void:
	game = MotherG.game
	_screen_w = float(MainGlobals.screen_size.x)
	_screen_h = float(MainGlobals.screen_size.y)
	_head_x = _screen_w * HEAD_X_FRAC
	_m_top_y = _screen_h * M_TOP_FRAC
	_m_bot_y = _screen_h * M_BOT_FRAC
	if MainGlobals.is_mobile():
		MOTHER_W *= 2.0
		CHILD_W *= 2.0
		HEAD_SCALE *= 2.0

	# Bodies are Line2D nodes living above the ground canvas (z 0) and below the props canvas and
	# the heads. Shadows go under their own body.
	_props_canvas = Control.new()
	_props_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_props_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_props_canvas.z_index = 3
	add_child(_props_canvas)
	_props_canvas.draw.connect(_draw_props.bind(_props_canvas))

	_l_mother_sh = _make_body_line(MOTHER_W, MOTHER_COL, 1, true)
	_l_child_sh = _make_body_line(CHILD_W, CHILD_COL, 1, true)
	_l_mother = _make_body_line(MOTHER_W, MOTHER_COL, 2, false)
	_l_child = _make_body_line(CHILD_W, CHILD_COL, 2, false)
	# A dorsal stripe: a narrower line on the SAME path, so its round joints sit inside the body's
	# at every turn. Real snakes have one, and it gives the body a spine without any offsetting.
	_l_mother_st = _make_body_line(MOTHER_W * STRIPE_W, MOTHER_COL.lightened(STRIPE_LIGHT), 3, false)
	_l_child_st = _make_body_line(CHILD_W * STRIPE_W, CHILD_COL.lightened(STRIPE_LIGHT), 3, false)

	_sprite_mother = _make_head(MOTHER_W, MOTHER_COL, 5)
	_sprite_child = _make_head(CHILD_W, CHILD_COL, 6)

	var sys_font: Font = MainGlobals.get_system_sans_font()
	var theme: Theme = Theme.new()
	theme.set_font("font", "Label", sys_font)
	theme.set_font("font", "Button", sys_font)
	$SessionOverlay.theme = theme
	_results_panel.theme = theme

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.42, 0.28, 0.13, 1.0)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	var btn_pressed: StyleBoxFlat = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.28, 0.18, 0.09, 1.0)
	$ResultsPanel/Margin/VBox/DoneButton.add_theme_stylebox_override("normal", btn_style)
	$ResultsPanel/Margin/VBox/DoneButton.add_theme_stylebox_override("hover", btn_style)
	$ResultsPanel/Margin/VBox/DoneButton.add_theme_stylebox_override("pressed", btn_pressed)

	for lb in [_timer_label, _goal_label, _phase_label]:
		lb.add_theme_color_override("font_color", TEXT_COL)
		lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
		lb.add_theme_constant_override("outline_size", 5)
	$ResultsPanel/Margin/VBox/TitleLabel.add_theme_color_override("font_color", TEXT_COL)
	_result_label.add_theme_color_override("font_color", Color(TEXT_COL, 0.82))
	$ResultsPanel/Margin/VBox/DoneButton.add_theme_color_override("font_color", TEXT_COL)

	_timer_label.offset_right = -16.0
	if MainGlobals.is_mobile():
		_timer_label.add_theme_font_size_override("font_size", 46)
		_timer_label.offset_bottom = 62.0
		_goal_label.add_theme_font_size_override("font_size", 42)
		_goal_label.offset_top = 66.0
		_goal_label.offset_bottom = 114.0
		_phase_label.add_theme_font_size_override("font_size", 42)
		_phase_label.offset_top = 118.0
		_phase_label.offset_bottom = 166.0
		$ResultsPanel/Margin/VBox/TitleLabel.add_theme_font_size_override("font_size", 34)
		_result_label.add_theme_font_size_override("font_size", 28)
		$ResultsPanel/Margin/VBox/DoneButton.add_theme_font_size_override("font_size", 36)

	_child_history = PackedFloat32Array()
	_child_history.resize(HISTORY_SLOTS)

	_graph = Control.new()
	_graph.set_script(load("res://mother/scripts/key_graph.gd"))
	_graph.set("bg_color", Color(0.075, 0.058, 0.066, 1.0))
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.custom_minimum_size = Vector2(0, 100)
	_graph.visible = false
	var vbox_m: Node = $ResultsPanel/Margin/VBox
	vbox_m.add_child(_graph)
	vbox_m.move_child(_graph, vbox_m.get_child_count() - 2)
	var graph_spacer_m: Control = Control.new()
	graph_spacer_m.custom_minimum_size = Vector2(0, 24)
	vbox_m.add_child(graph_spacer_m)
	vbox_m.move_child(graph_spacer_m, vbox_m.get_child_count() - 2)

	var mobile_m: bool = MainGlobals.is_mobile()
	var again_btn_m: Button = Button.new()
	again_btn_m.text = "Again"
	again_btn_m.custom_minimum_size = Vector2(160, 52)
	again_btn_m.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	again_btn_m.add_theme_stylebox_override("normal", btn_style)
	again_btn_m.add_theme_stylebox_override("hover", btn_style)
	again_btn_m.add_theme_stylebox_override("pressed", btn_pressed)
	again_btn_m.add_theme_font_size_override("font_size", 36 if mobile_m else 26)
	again_btn_m.add_theme_color_override("font_color", Color(0.82, 0.96, 0.85, 1.0))
	again_btn_m.pressed.connect(_on_again_pressed)
	var btn_hbox_m: HBoxContainer = HBoxContainer.new()
	btn_hbox_m.add_theme_constant_override("separation", 16)
	btn_hbox_m.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_m.add_child(btn_hbox_m)
	$ResultsPanel/Margin/VBox/DoneButton.reparent(btn_hbox_m)
	btn_hbox_m.add_child(again_btn_m)
	btn_hbox_m.move_child(again_btn_m, 0)

	_phase_grid = GridContainer.new()
	_phase_grid.columns = 3
	_phase_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_phase_grid.add_theme_constant_override("h_separation", 24)
	_phase_grid.add_theme_constant_override("v_separation", 1)
	var _grid_hbox_m: HBoxContainer = HBoxContainer.new()
	_grid_hbox_m.alignment = BoxContainer.ALIGNMENT_CENTER
	_grid_hbox_m.add_child(_phase_grid)
	vbox_m.add_child(_grid_hbox_m)
	vbox_m.move_child(_grid_hbox_m, 2)

	_reaction_label = Label.new()
	_reaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reaction_label.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	_reaction_label.add_theme_font_size_override("font_size", 20 if not MainGlobals.is_mobile() else 28)
	_reaction_label.add_theme_color_override("font_color", Color(0.75, 0.88, 0.75, 0.85))
	_reaction_label.visible = false
	vbox_m.add_child(_reaction_label)
	vbox_m.move_child(_reaction_label, 3)

	_results_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_panel.offset_top = 0.0
	_results_panel.offset_bottom = 0.0
	_results_panel.offset_left = 0.0
	_results_panel.offset_right = 0.0
	var margin_ctrl: Control = $ResultsPanel/Margin as Control
	var mobile_r: bool = MainGlobals.is_mobile()
	margin_ctrl.add_theme_constant_override("margin_bottom", MainGlobals.footer_height + (48 if mobile_r else 16))
	margin_ctrl.add_theme_constant_override("margin_top", 8)
	($ResultsPanel/Margin/VBox as VBoxContainer).add_theme_constant_override("separation", 3 if mobile_r else 6)
	_results_panel.hide()

	var bg_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	bg_rng.seed = 4219
	# Sand ripple lines (alternating dark/light)
	for i in range(22):
		_bg_seeds.append({
			"type": 0,
			"y_frac": (float(i) + bg_rng.randf_range(0.1, 0.9)) / 22.0,
			"amp": bg_rng.randf_range(1.5, 5.0),
			"period": bg_rng.randf_range(110.0, 280.0),
			"phase": bg_rng.randf_range(0.0, TAU),
			"alpha": bg_rng.randf_range(0.18, 0.38),
			"light": bg_rng.randf() > 0.5,
		})
	# Small pebbles
	for i in range(22):
		_bg_seeds.append({
			"type": 1,
			"wx": bg_rng.randf_range(0.0, 2000.0),
			"y_frac": bg_rng.randf_range(0.0, 1.0),
			"r": bg_rng.randf_range(1.5, 4.0),
			"speed_f": bg_rng.randf_range(0.55, 1.0),
		})
	# Dry bushes (tumbling with wind)
	for i in range(11):
		var spikes: Array = []
		for _k in range(12):
			spikes.append({"a": bg_rng.randf_range(0.0, TAU), "r": bg_rng.randf_range(0.45, 1.0)})
		# First 8 go in the top half, last 3 spread bottom half
		var y_min: float = 0.05 if i < 8 else 0.52
		var y_max: float = 0.50 if i < 8 else 0.92
		_bg_seeds.append({
			"type": 2,
			"wx": bg_rng.randf_range(0.0, 2000.0),
			"y_frac": bg_rng.randf_range(y_min, y_max),
			"r": bg_rng.randf_range(10.0, 20.0),
			"spikes": spikes,
			"speed_f": bg_rng.randf_range(1.1, 1.5),
			"phase": bg_rng.randf_range(0.0, TAU),
		})
	# Drifting dust
	for i in DUST_COUNT:
		var depth: float = bg_rng.randf_range(0.06, 0.98)   # 0 far, 1 near
		_bg_seeds.append({
			"type": 4,
			"wx": bg_rng.randf_range(0.0, 2000.0),
			"y_frac": depth,
			"r": lerpf(DUST_R_FAR, DUST_R_NEAR, depth),
			"speed_f": lerpf(DUST_SPEED_FAR, DUST_SPEED_NEAR, depth),
			"alpha": lerpf(DUST_A_FAR, DUST_A_NEAR, depth),
			"phase": bg_rng.randf_range(0.0, TAU),
		})
	# Beetles
	for i in range(4):
		_bg_seeds.append({
			"type": 3,
			"wx": bg_rng.randf_range(0.0, 2000.0),
			"y_frac": bg_rng.randf_range(0.1, 0.9),
			"speed_f": bg_rng.randf_range(0.7, 1.1),
			"phase": bg_rng.randf_range(0.0, TAU),
		})

func new_game() -> void:
	_duration_ms = MotherG.duration_min * 60000.0
	_elapsed_ms = 0.0
	_session_complete = false
	_anim_time = 0.0
	_head_frame = 0
	_scroll_px_per_ms = _compute_scroll_speed()
	_child_y = _m_bot_y + CHILD_START_DROP
	_child_angle = 0.0
	_child_vel_y = 0.0
	_session_ps = 0
	_rt_ms = 0
	_history_head = 0
	_history_count = 0
	_prefill_history(_child_y)
	_history_last_ms = -1000.0
	_child_history.fill(_child_y)
	_trace_segments = []
	_current_trace = []
	_trace_last_ms = 0.0
	_key_poll = []
	_computed_phases = [0.0, 0.0, 0.0, 0.0]
	# In ACTIVE mode the only snake on screen is the PLAYER's own trail, so it wears the child's
	# head and colours. It used to wear the mother's, which made Active mode look like Guided mode
	# with the mother missing — the single most confusing thing about this game.
	_sprite_child.visible = true
	_sprite_mother.visible = not active_mode
	if active_mode:
		_goal_label.text = ""
	else:
		var d_g: Array = MotherG.get_guided_durations()
		_goal_label.text = "Goal: %s – %s – %s – %s" % [_fv_ms(d_g[0]), _fv_ms(d_g[1]), _fv_ms(d_g[2]), _fv_ms(d_g[3])]
	game.level_is_ready = true
	game.playing = true
	$SessionOverlay.show()
	_results_panel.hide()
	_canvas.queue_redraw()
	if _props_canvas != null:
		_props_canvas.queue_redraw()

func _compute_scroll_speed() -> float:
	var d: Array = MotherG.get_guided_durations()
	var cycle_ms: float = d[0] + d[1] + d[2] + d[3]
	return _screen_w / (1.5 * cycle_ms)

func _process(delta: float) -> void:
	if not game.level_is_ready or game.paused() or _session_complete:
		return

	_elapsed_ms += delta * 1000.0
	_anim_time += delta

	# Keyboard: speed calibrated so full inhale/exhale traverses the mother's range
	var d: Array = MotherG.get_guided_durations()
	var m_range: float = _m_bot_y - _m_top_y
	var speed_up: float = m_range / d[0] * 1000.0
	var speed_down: float = m_range / d[2] * 1000.0
	var target_vel: float = 0.0
	if Input.is_action_pressed("up") or MainGlobals.is_in_digitized_swipe_up:
		target_vel = -speed_up
	elif Input.is_action_pressed("down") or MainGlobals.is_in_digitized_swipe_dn:
		target_vel = speed_down
	_child_vel_y = lerpf(_child_vel_y, target_vel, delta * 8.0)
	var _new_child_y: float = clampf(_child_y + _child_vel_y * delta, 0.0, _screen_h)
	if _new_child_y == 0.0 or _new_child_y == _screen_h:
		_child_vel_y = 0.0
	_child_y = _new_child_y

	# History ring buffer
	if _elapsed_ms - _history_last_ms >= HISTORY_INTERVAL_MS:
		_child_history[_history_head] = _child_y
		_history_head = (_history_head + 1) % HISTORY_SLOTS
		_history_count = mini(_history_count + 1, HISTORY_SLOTS)
		_history_last_ms = _elapsed_ms

	# Keyboard polling — fill every 50ms slot up to current time; no drift
	var expected_slots: int = int(_elapsed_ms / KEY_POLL_INTERVAL_MS)
	while _key_poll.size() < expected_slots:
		if Input.is_action_pressed("up") or MainGlobals.is_in_digitized_swipe_up:
			_key_poll.append(1)
		elif Input.is_action_pressed("down") or MainGlobals.is_in_digitized_swipe_dn:
			_key_poll.append(2)
		else:
			_key_poll.append(0)

	# Trace sampling
	if _elapsed_ms - _trace_last_ms >= TRACE_INTERVAL_MS:
		var y_norm: float = _child_y / _screen_h
		_current_trace.append(Vector2(_elapsed_ms, clampf(y_norm, 0.0, 1.0)))
		_trace_last_ms = _elapsed_ms

	# Head animation
	# Same cadence the three-frame sprite cycle used; frame 2 of 4 is the blink.
	var f_now: int = int(_anim_time * 3.5) % 4
	if f_now != _head_frame:
		_head_frame = f_now
		_sprite_child.queue_redraw()
		_sprite_mother.queue_redraw()

	var scroll_px_s: float = _scroll_px_per_ms * 1000.0
	var y_old: float = _child_y_at_time(_elapsed_ms - 50.0)
	var child_vel_px_s: float = (_child_y - y_old) / 0.05

	if active_mode:
		_child_angle = lerp_angle(_child_angle, atan2(child_vel_px_s, scroll_px_s), minf(1.0, delta * HEAD_TURN_RATE))
		_sprite_child.rotation = _child_angle
		_sprite_child.position = Vector2(_head_x, _child_y)
	else:
		var mother_y: float = _phase_y_at(_elapsed_ms, _m_top_y, _m_bot_y)
		var mother_vel_px_s: float = _phase_vel_norm_at(_elapsed_ms) * (_m_bot_y - _m_top_y) * 1000.0
		_mother_angle = lerp_angle(_mother_angle, atan2(mother_vel_px_s, scroll_px_s), minf(1.0, delta * HEAD_TURN_RATE))
		_sprite_mother.rotation = _mother_angle
		_sprite_mother.position = Vector2(_head_x, mother_y)
		_child_angle = lerp_angle(_child_angle, atan2(child_vel_px_s, scroll_px_s), minf(1.0, delta * HEAD_TURN_RATE))
		_sprite_child.rotation = _child_angle
		_sprite_child.position = Vector2(_head_x, _child_y)

	var rem_s: int = int(maxf(0.0, _duration_ms - _elapsed_ms) / 1000.0)
	_timer_label.text = "%d:%02d" % [rem_s / 60, rem_s % 60]
	_phase_label.text = _current_phase_label()

	_canvas.queue_redraw()
	if _props_canvas != null:
		_props_canvas.queue_redraw()

	if _elapsed_ms >= _duration_ms:
		_on_session_complete()

# Breathing phase y position; top_y = inhale extreme, bot_y = exhale extreme
func _phase_y_at(t_ms: float, top_y: float, bot_y: float) -> float:
	var d: Array = MotherG.get_guided_durations()
	var inhale_ms: float = d[0]
	var hold_top_ms: float = d[1]
	var exhale_ms: float = d[2]
	var cycle_ms: float = inhale_ms + hold_top_ms + exhale_ms + d[3]
	var t: float = fmod(t_ms, cycle_ms)
	if t < 0.0:
		t += cycle_ms
	if t < inhale_ms:
		return lerpf(bot_y, top_y, t / inhale_ms)
	t -= inhale_ms
	if t < hold_top_ms:
		return top_y
	t -= hold_top_ms
	if t < exhale_ms:
		return lerpf(top_y, bot_y, t / exhale_ms)
	return bot_y

# Normalized velocity in range-fractions per ms (negative=going to top)
func _phase_vel_norm_at(t_ms: float) -> float:
	var d: Array = MotherG.get_guided_durations()
	var inhale_ms: float = d[0]
	var hold_top_ms: float = d[1]
	var exhale_ms: float = d[2]
	var cycle_ms: float = inhale_ms + hold_top_ms + exhale_ms + d[3]
	var t: float = fmod(t_ms, cycle_ms)
	if t < 0.0:
		t += cycle_ms
	if t < inhale_ms:
		return -1.0 / inhale_ms
	t -= inhale_ms
	if t < hold_top_ms:
		return 0.0
	t -= hold_top_ms
	if t < exhale_ms:
		return 1.0 / exhale_ms
	return 0.0

# Interpolated history lookup — smooth from current position through stored history
func _child_y_at_time(t_ms: float) -> float:
	if _history_count == 0:
		return _child_y
	var time_back_ms: float = _elapsed_ms - t_ms
	if time_back_ms <= 0.0:
		return _child_y
	var last_idx: int = (_history_head - 1 + HISTORY_SLOTS) % HISTORY_SLOTS
	var time_since_last: float = _elapsed_ms - _history_last_ms
	# Sub-interval: interpolate between current position and last stored sample
	if time_back_ms <= time_since_last:
		var t: float = time_back_ms / maxf(time_since_last, 0.5)
		return lerpf(_child_y, _child_history[last_idx], t)
	# Into stored history, offset by the partial interval already consumed
	var adjusted_back: float = time_back_ms - time_since_last
	var slots_back_f: float = adjusted_back / HISTORY_INTERVAL_MS
	var slots_back: int = int(slots_back_f)
	var frac: float = slots_back_f - float(slots_back)
	if slots_back >= _history_count - 1:
		var oldest_idx: int = (_history_head - _history_count + HISTORY_SLOTS) % HISTORY_SLOTS
		return _child_history[oldest_idx]
	var idx0: int = (_history_head - 1 - slots_back + HISTORY_SLOTS) % HISTORY_SLOTS
	var idx1: int = (_history_head - 2 - slots_back + HISTORY_SLOTS) % HISTORY_SLOTS
	return lerpf(_child_history[idx0], _child_history[idx1], frac)

func _current_phase_label() -> String:
	if active_mode:
		return ""
	var d: Array = MotherG.get_guided_durations()
	var cycle_ms: float = d[0] + d[1] + d[2] + d[3]
	var t: float = fmod(_elapsed_ms, cycle_ms)
	if t < 0.0:
		t += cycle_ms
	if t < d[0]:
		return "Inhale  ▲"
	t -= d[0]
	if t < d[1]:
		return "Hold  ■"
	t -= d[1]
	if t < d[2]:
		return "Exhale  ▼"
	return "Hold  ■"

# --- Snake body rendering -----------------------------------------------------------------------
#
# --- Snake bodies: Line2D, not hand-built polygons ------------------------------------------------
#
# Two earlier attempts failed here, and the reason the second one failed is worth keeping:
#
#   1. `draw_polyline` at constant width with a pale stripe down the CENTRE. A centred stripe reads
#      as a racing stripe rather than a rounded form, and a constant-width line with round caps
#      reads as a cable — the two snakes looked like a logic-analyzer timing diagram.
#   2. A hand-built tapered polygon ribbon. `draw_colored_polygon` triangulates through
#      Geometry2D, which FAILS AND DRAWS NOTHING on a self-intersecting polygon — and an offset
#      ribbon self-intersects wherever the path turns sharper than its own half-width. So the
#      mother (steep guided path, wide body) vanished completely and the child flickered as folds
#      appeared and disappeared while scrolling. A fold does not render a knot; it renders
#      nothing.
#
# Line2D solves all of it in the engine: it tessellates its own strip robustly, `joint_mode` ROUND
# gives genuinely rounded turns, `width_curve` gives the taper, and a tiled `texture` gives both
# the cross-section shading (roundness) and the SCALES. Nothing here can fail to triangulate.

var _l_mother: Line2D = null
var _l_child: Line2D = null
var _l_mother_sh: Line2D = null
var _l_child_sh: Line2D = null
var _l_mother_st: Line2D = null      # dorsal stripe, same path, drawn over the body
var _l_child_st: Line2D = null
var _bands: Dictionary = {}          # line -> band count its gradient was built for
var _props_canvas: Control = null

func _make_body_line(w: float, col: Color, z: int, shadow: bool) -> Line2D:
	var ln: Line2D = Line2D.new()
	ln.width = w
	ln.default_color = Color(col, GLOW_ALPHA) if shadow else col
	ln.joint_mode = Line2D.LINE_JOINT_ROUND
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	ln.round_precision = 16
	ln.antialiased = true
	ln.z_index = z
	var cur: Curve = Curve.new()
	cur.add_point(Vector2(0.0, 1.0))
	cur.add_point(Vector2(0.62, 0.90))
	cur.add_point(Vector2(1.0, TAIL_FRAC))
	ln.width_curve = cur
	add_child(ln)
	return ln

# Banding and the tail dissolve, baked into one Gradient.
#
# NOTE Line2D.gradient REPLACES default_color rather than multiplying it, so everything about the
# body's colour has to live in here — an earlier version set the pulse brightness on
# default_color, where it was silently ignored. The per-frame brightness now rides on `modulate`,
# which does multiply.
# The dorsal stripe gets a CONSTANT colour, not the body's banding. Sharing the banded gradient
# made the stripe's dark stops (value 0.72) come out darker than the body's lit regions (0.88), so
# along the length the spine alternated between lighter and darker than the body it sits on and
# cancelled itself out. Only the tail dissolve is kept, so it fades with the body it rides on.
func _build_plain_gradient(col: Color) -> Gradient:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, TAIL_SOLID, 1.0])
	g.colors = PackedColorArray([
		Color(col.r, col.g, col.b, 1.0), Color(col.r, col.g, col.b, 1.0), Color(col.r, col.g, col.b, 0.0)])
	return g

func _build_gradient(base_col: Color, span_px: float) -> Gradient:
	var offs: PackedFloat32Array = PackedFloat32Array()
	var cols: PackedColorArray = PackedColorArray()
	var dark: Color = Color(base_col.r * BAND_DARK, base_col.g * BAND_DARK, base_col.b * BAND_DARK, 1.0)
	var half: float = BAND_PX * 0.5
	var span: float = maxf(half * 2.0, span_px)
	var n_steps: int = clampi(int(span / half), 2, BAND_MAX * 2)
	for i in range(n_steps + 1):
		# ANCHORED IN PIXELS from the head: offset = distance / length. As the child's body grows,
		# a band 100 px back stays 100 px back — only new bands appear at the tail. Dividing 0..1
		# into equal fractions instead made every band shift a little each time the length changed,
		# which is what the tail jitter during growth actually was.
		var t: float = clampf(float(i) * half / span, 0.0, 1.0)
		var c: Color = base_col if i % 2 == 0 else dark
		var a: float = 1.0
		if t > TAIL_SOLID:
			a = 1.0 - (t - TAIL_SOLID) / (1.0 - TAIL_SOLID)
		offs.append(t)
		cols.append(Color(c.r, c.g, c.b, a))
	var g: Gradient = Gradient.new()
	g.offsets = offs
	g.colors = cols
	return g

# Seed the history ring with a flat run at the starting position, so the child HAS a tail on
# frame one instead of growing one from nothing. These are ordinary history samples — the body is
# drawn from them exactly as it is from real ones.
func _child_grow_cap() -> float:
	return CHILD_START_LEN_PX + _elapsed_ms * CHILD_GROW_PX_PER_MS

func _prefill_history(y: float) -> void:
	var px_per_slot: float = maxf(0.01, HISTORY_INTERVAL_MS * _scroll_px_per_ms)
	var slots: int = clampi(int(CHILD_START_LEN_PX / px_per_slot) + 6, 8, HISTORY_SLOTS)
	for i in slots:
		_child_history[i] = y
	_history_head = slots % HISTORY_SLOTS
	_history_count = slots
	_history_last_ms = 0.0

# How open the breath is right now: 0 fully exhaled (bottom of the range), 1 fully inhaled (top).
func _openness(y: float, drop: float) -> float:
	var span: float = _m_bot_y - _m_top_y
	if span <= 0.0:
		return 0.0
	return clampf((_m_bot_y + drop - y) / span, 0.0, 1.0)

# `pts` must arrive HEAD FIRST — Line2D samples width_curve and gradient from points[0].
func _slither_y(pts: PackedVector2Array, w: float, now_s: float) -> PackedVector2Array:
	var n: int = pts.size()
	if n < 3 or w <= 0.0:
		return pts
	var amp: float = w * SLITHER_AMP_W
	var wave: float = maxf(1.0, w * SLITHER_WAVE_W)
	var ramp: float = maxf(1.0, w * SLITHER_RAMP_W)
	var x0: float = pts[0].x
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	for i in n:
		var dx: float = absf(x0 - pts[i].x)
		# eased in behind the head, so the head itself stays exactly on the true path
		var ease: float = smoothstep(0.0, 1.0, minf(1.0, dx / ramp))
		out[i] = Vector2(pts[i].x, pts[i].y + amp * ease * sin(dx / wave * TAU - now_s * SLITHER_SPEED))
	return out

func _set_body(ln: Line2D, sh: Line2D, st: Line2D, pts: PackedVector2Array, w: float,
		base_col: Color, openness: float, stable_len: float) -> void:
	if pts.size() < 2:
		ln.points = PackedVector2Array()
		sh.points = PackedVector2Array()
		st.points = PackedVector2Array()
		return
	pts = _slither_y(pts, w, _elapsed_ms * 0.001)
	var o: float = clampf(openness, 0.0, 1.0)
	var pw: float = w * lerpf(PULSE_W_LOW, PULSE_W_HIGH, o)
	ln.width = pw
	sh.width = pw * GLOW_MUL
	st.width = pw * STRIPE_W

	# The inhale brightening rides on `modulate`, which MULTIPLIES the gradient. Putting it on
	# default_color did nothing, because a Line2D with a gradient ignores default_color entirely.
	var m: float = 1.0 + PULSE_LIGHT * o
	ln.modulate = Color(m, m, m, 1.0)
	st.modulate = ln.modulate

	# Bands are spaced in PIXELS, but gradient offsets are normalised over the line — so the band
	# count has to track the body's length, or the spacing would stretch as the child grows.
	#
	# Measured against ARC length it changed ~19 times per 700 frames, because the arc lengthens
	# and shortens as the breath steepens the path. Every change renormalises the offsets and
	# shifts EVERY band a little, which would read as the pattern crawling. The HORIZONTAL span is
	# the stable proxy: constant for the mother, monotonically growing for the child, so the count
	# settles and stops churning.
	# Rebuild only when the number of stops would actually change; the stops themselves are
	# pinned to pixel distances from the head, so growth appends bands rather than moving them.
	#
	# The length used here is the SMOOTH one passed in, not the measured span. The snapped-time
	# sampler quantises the tail to the 2 px sample step, so the measured span oscillates by up to
	# one step every frame (132 shrinks per 900 frames, measured) — feeding that into the gradient
	# would put that wobble into the pattern. The tail tip itself still moves those 2 px, where the
	# alpha ramp has already faded it to nothing.
	var span: float = maxf(1.0, stable_len)
	var n_steps: int = clampi(int(maxf(BAND_PX, span) / (BAND_PX * 0.5)), 2, BAND_MAX * 2)
	if int(_bands.get(ln, -1)) != n_steps:
		_bands[ln] = n_steps
		ln.gradient = _build_gradient(base_col, span)
		st.gradient = _build_plain_gradient(base_col.lightened(STRIPE_LIGHT))

	ln.points = pts
	st.points = pts
	var shifted: PackedVector2Array = PackedVector2Array()
	shifted.resize(pts.size())
	for i in pts.size():
		shifted[i] = pts[i] + Vector2(0.0, SHADOW_DY)
	sh.points = shifted

func _do_draw(canvas: CanvasItem) -> void:
	var w: float = (canvas as Control).size.x
	var h: float = (canvas as Control).size.y

	# banded vertical gradient: cooler at the horizon, warmer nearer the viewer
	var band_h: float = h / float(GROUND_BANDS)
	for gi in GROUND_BANDS:
		var gt: float = float(gi) / float(GROUND_BANDS - 1)
		canvas.draw_rect(Rect2(0.0, float(gi) * band_h, w, band_h + 1.0),
			GROUND_TOP.lerp(GROUND_BOTTOM, gt), true)

	var scroll_off: float = _elapsed_ms * _scroll_px_per_ms
	var bg_span: float = 2000.0

	# Dune ridges. The top edge is single-valued in x and always well above the bottom, so the
	# outline is a simple polygon and draw_colored_polygon can always triangulate it — the failure
	# mode that made an earlier body renderer draw nothing at all.
	for dune in DUNE_LAYERS:
		var dy: float = float(dune["y"]) * h
		var damp: float = float(dune["amp"]) * h
		var dper: float = maxf(1.0, float(dune["period"]) * w)
		var doff: float = scroll_off * float(dune["speed"])
		var dn: int = int(w / DUNE_STEP) + 2
		var poly: PackedVector2Array = PackedVector2Array()
		for j in range(dn):
			var dx: float = float(j) * DUNE_STEP
			poly.append(Vector2(dx, dy
				+ damp * sin((dx + doff) * TAU / dper)
				+ damp * 0.38 * sin((dx + doff * 1.7) * TAU / (dper * 0.41))))
		poly.append(Vector2(w, h))
		poly.append(Vector2(0.0, h))
		canvas.draw_colored_polygon(poly, dune["col"])

	# Ground texture (behind snake paths): sand ripple lines and pebbles
	for bg_item in _bg_seeds:
		if bg_item.type == 0:  # sand ripple line
			var y_base: float = bg_item.y_frac * h
			var rpts: PackedVector2Array = PackedVector2Array()
			var rx_step: float = 8.0
			var rn: int = int(w / rx_step) + 2
			rpts.resize(rn)
			for j in range(rn):
				var rx: float = float(j) * rx_step
				rpts[j] = Vector2(rx, y_base + bg_item.amp * sin((rx + scroll_off) * TAU / bg_item.period + bg_item.phase))
			var rc: Color = Color(RIPPLE_LIGHT, bg_item.alpha * 0.55) if bg_item.light else Color(RIPPLE_DARK, bg_item.alpha)
			canvas.draw_polyline(rpts, rc, 1.0, true)
		elif bg_item.type == 4:  # drifting dust
			var dsx: float = fmod(bg_item.wx - scroll_off * bg_item.speed_f, bg_span)
			if dsx < 0.0:
				dsx += bg_span
			if dsx >= -4.0 and dsx <= w + 4.0:
				var dsy: float = bg_item.y_frac * h + sin(_elapsed_ms * 0.0009 + bg_item.phase) * 5.0
				canvas.draw_circle(Vector2(dsx, dsy), bg_item.r,
					Color(DUST_COL, bg_item.alpha), true, -1.0, true)
		elif bg_item.type == 1:  # pebble
			var sx_raw: float = fmod(bg_item.wx - scroll_off * bg_item.speed_f, bg_span)
			if sx_raw < 0.0:
				sx_raw += bg_span
			var sy: float = bg_item.y_frac * h
			for _si in range(2):
				var sx: float = sx_raw if _si == 0 else sx_raw - bg_span
				if sx < -6.0 or sx > w + 6.0:
					continue
				canvas.draw_circle(Vector2(sx, sy), bg_item.r, PEBBLE_COL, true, -1.0, true)

	var step: float = 2.0
	# Guard: the transition-marker loop below steps by _cycle_ms from a start derived by dividing
	# by _scroll_px_per_ms. Either being zero makes that start -INF and the loop never terminates —
	# a hard freeze, not a glitch. Both are derived from the screen width, so a layout that has not
	# been sized yet is enough to trigger it.
	if _scroll_px_per_ms <= 0.0:
		return
	if active_mode:
		_l_mother.points = PackedVector2Array()
		_l_mother_sh.points = PackedVector2Array()
		_l_mother_st.points = PackedVector2Array()

	# --- Mother body ---
	if active_mode:
		# Active mode: no guide exists, so the one body drawn is the PLAYER's own trail — child
		# colours and child width, matching the head above.
		if _history_count > 4:
			var reliable_px_a: float = minf(minf(
				float(_history_count - 4) * HISTORY_INTERVAL_MS * _scroll_px_per_ms,
				_head_x + CHILD_W), _child_grow_cap())
			var n_ma: int = int(reliable_px_a / step) + 2
			if n_ma >= 2:
				var trail_pts: PackedVector2Array = PackedVector2Array()
				trail_pts.append(Vector2(_head_x, _child_y))
				# Snap sample times to a fixed grid so sharp trail vertices don't alias/jitter while scrolling
				var dt_step_a: float = step / _scroll_px_per_ms
				var t_base_a: float = floor(_elapsed_ms / dt_step_a) * dt_step_a
				for i in range(n_ma + 1):
					var t_at_x: float = t_base_a - float(i) * dt_step_a
					var x: float = _head_x - (_elapsed_ms - t_at_x) * _scroll_px_per_ms
					if x < -CHILD_W:
						break
					trail_pts.append(Vector2(x, _child_y_at_time(t_at_x)))
				if trail_pts.size() >= 2:
					_set_body(_l_child, _l_child_sh, _l_child_st, trail_pts, CHILD_W, CHILD_COL,
						_openness(_child_y, CHILD_START_DROP), reliable_px_a)
	else:
		# Guided mode: the mother's own path, sampled on a SNAPPED TIME GRID and walked head-first.
		#
		# It used to be sampled at fixed screen-x with exact phase-transition vertices spliced in.
		# That inserts and drops points as the transitions scroll past, so the point count changed
		# every frame — which jittered the texture, the joints and (before it was arc-length based)
		# the slither, all worst at the turns. The child already used a snapped time grid for
		# exactly this reason: snapping the sample TIMES keeps each vertex's neighbours constant
		# frame to frame, so the whole body scrolls smoothly instead of resampling under itself.
		# The transition vertices are not missed: `_phase_y_at` uses smootherstep, which is C2, so
		# there is no corner at a phase boundary that needs a vertex placed on it.
		var mother_pts: PackedVector2Array = PackedVector2Array()
		var dt_step_m: float = step / _scroll_px_per_ms
		var t_base_m: float = floor(_elapsed_ms / dt_step_m) * dt_step_m
		mother_pts.append(Vector2(_head_x, _phase_y_at(_elapsed_ms, _m_top_y, _m_bot_y)))
		var n_m: int = int((_head_x + MOTHER_W) / step) + 2
		for i in range(n_m + 1):
			var t_at_x_m: float = t_base_m - float(i) * dt_step_m
			var x_m: float = _head_x - (_elapsed_ms - t_at_x_m) * _scroll_px_per_ms
			if x_m < -MOTHER_W:
				break
			mother_pts.append(Vector2(x_m, _phase_y_at(t_at_x_m, _m_top_y, _m_bot_y)))
		_set_body(_l_mother, _l_mother_sh, _l_mother_st, mother_pts, MOTHER_W, MOTHER_COL,
			_openness(mother_pts[0].y, 0.0), _head_x + MOTHER_W)

		# --- Child body — break at left edge to avoid tail jitter ---
		if _history_count > 4:
			var reliable_px: float = minf(minf(
				float(_history_count - 4) * HISTORY_INTERVAL_MS * _scroll_px_per_ms,
				_head_x), _child_grow_cap())
			var n_child: int = int(reliable_px / step) + 2
			if n_child >= 2:
				var child_pts: PackedVector2Array = PackedVector2Array()
				child_pts.append(Vector2(_head_x, _child_y))
				# Snap sample times to a fixed grid so sharp trail vertices don't alias/jitter while scrolling
				var dt_step: float = step / _scroll_px_per_ms
				var t_base: float = floor(_elapsed_ms / dt_step) * dt_step
				for i in range(n_child + 1):
					var t_at_x: float = t_base - float(i) * dt_step
					var x: float = _head_x - (_elapsed_ms - t_at_x) * _scroll_px_per_ms
					if x < -CHILD_W:
						break
					child_pts.append(Vector2(x, _child_y_at_time(t_at_x)))
				if child_pts.size() >= 2:
					_set_body(_l_child, _l_child_sh, _l_child_st, child_pts, CHILD_W, CHILD_COL,
						_openness(_child_y, CHILD_START_DROP), reliable_px)


# Bushes and beetles sit at the same ground level as the snakes and are drawn OVER them, so a
# snake passing behind a bush reads as being on the ground rather than floating above it. Now that
# the bodies are Line2D nodes rather than canvas draws, these need their own canvas above them.
# Concentric bands of black, densest at the very edge. Cheap, and it needs no shader or texture —
# the same approach aliens/scripts/field.gd uses.
func _draw_vignette(canvas: CanvasItem, w: float, h: float) -> void:
	var depth: float = minf(w, h) * VIGNETTE_DEPTH
	var stepv: float = depth / float(VIGNETTE_STEPS)
	for i in VIGNETTE_STEPS:
		var f: float = 1.0 - float(i) / float(VIGNETTE_STEPS)
		var a: float = VIGNETTE_MAX_A * f * f
		var o: float = float(i) * stepv
		canvas.draw_rect(Rect2(0.0, o, w, stepv), Color(0, 0, 0, a), true)
		canvas.draw_rect(Rect2(0.0, h - o - stepv, w, stepv), Color(0, 0, 0, a), true)
		canvas.draw_rect(Rect2(o, 0.0, stepv, h), Color(0, 0, 0, a), true)
		canvas.draw_rect(Rect2(w - o - stepv, 0.0, stepv, h), Color(0, 0, 0, a), true)

func _draw_props(canvas: CanvasItem) -> void:
	var w: float = (canvas as Control).size.x
	var h: float = (canvas as Control).size.y
	var scroll_off: float = _elapsed_ms * _scroll_px_per_ms
	var bg_span: float = 2000.0
	_draw_vignette(canvas, w, h)
	for bg_item in _bg_seeds:
		if bg_item.type == 2:  # dry bush with wind rotation and gentle bob
			var sx_raw: float = fmod(bg_item.wx - scroll_off * bg_item.speed_f, bg_span)
			if sx_raw < 0.0:
				sx_raw += bg_span
			for _si in range(2):
				var sx: float = sx_raw if _si == 0 else sx_raw - bg_span
				if sx + bg_item.r * 2.0 < -5.0 or sx - bg_item.r * 2.0 > w + 5.0:
					continue
				var rot_angle: float = sin(_elapsed_ms * 0.0015 + bg_item.phase) * 0.4
				var bob_y: float = sin(_elapsed_ms * 0.0022 + bg_item.phase * 0.7) * 4.0
				var sy: float = bg_item.y_frac * h + bob_y
				var bc: Color = BUSH_COL
				for sp in bg_item.spikes:
					var total_a: float = sp.a + rot_angle
					var ex: float = sx + cos(total_a) * bg_item.r * sp.r
					var ey: float = sy + sin(total_a) * bg_item.r * sp.r
					canvas.draw_line(Vector2(sx, sy), Vector2(ex, ey), bc, 1.4, true)
				canvas.draw_circle(Vector2(sx, sy), bg_item.r * 0.18, bc, true, -1.0, true)
		elif bg_item.type == 3:  # beetle with body jitter and walking legs
			var sx_raw: float = fmod(bg_item.wx - scroll_off * bg_item.speed_f, bg_span)
			if sx_raw < 0.0:
				sx_raw += bg_span
			var base_sy: float = bg_item.y_frac * h
			for _si in range(2):
				var sx_base: float = sx_raw if _si == 0 else sx_raw - bg_span
				if sx_base < -20.0 or sx_base > w + 20.0:
					continue
				var sx: float = sx_base + sin(_elapsed_ms * 0.0031 + bg_item.phase) * 0.5
				var sy: float = base_sy + sin(_elapsed_ms * 0.0047 + bg_item.phase * 1.4) * 0.35
				var col: Color = BEETLE_COL
				var bw_b: float = 7.0
				var bh_b: float = 4.5
				var bpts: PackedVector2Array = PackedVector2Array()
				for k in range(10):
					var a: float = float(k) / 10.0 * TAU
					bpts.append(Vector2(sx + cos(a) * bw_b, sy + sin(a) * bh_b))
				canvas.draw_colored_polygon(bpts, col)
				# 3 pairs of walking legs, radiating outward from ellipse surface
				var walk_t: float = _elapsed_ms * 0.006 + bg_item.phase
				var leg_len_b: float = 3.2
				var leg_dxs: Array = [-3.8, 0.0, 3.8]
				var walk_phases: Array = [0.0, PI, 0.0]
				for li in range(3):
					var dx: float = leg_dxs[li]
					var fy: float = sqrt(maxf(0.0, 1.0 - (dx / bw_b) * (dx / bw_b)))
					var y_top: float = sy - bh_b * fy
					var y_bot: float = sy + bh_b * fy
					var lx: float = sx + dx
					var walk_ang: float = 0.28 * sin(walk_t + walk_phases[li])
					# Front legs (li=0) tilt forward; rear (li=2) tilt backward
					var fwd: float = (float(li) - 1.0) * 0.4
					var ang_top: float = -PI / 2.0 + fwd + walk_ang
					var ang_bot: float = PI / 2.0 - fwd + walk_ang
					canvas.draw_line(
						Vector2(lx, y_top),
						Vector2(lx + cos(ang_top) * leg_len_b, y_top + sin(ang_top) * leg_len_b),
						col, 1.0, true)
					canvas.draw_line(
						Vector2(lx, y_bot),
						Vector2(lx + cos(ang_bot) * leg_len_b, y_bot + sin(ang_bot) * leg_len_b),
						col, 1.0, true)


func get_session_score(didwin: bool, wasaborted: bool) -> Array:
	return [didwin, wasaborted, int(_duration_ms / 60000.0), _session_ps, _rt_ms]

func get_computed_phases() -> Array:
	return _computed_phases

func _fv_ms(ms: float) -> String:
	var r: float = round(ms / 500.0) / 2.0
	if r == float(int(r)):
		return str(int(r))
	var whole: int = int(r)
	return ("" if whole == 0 else str(whole)) + "½"

func _on_session_complete() -> void:
	_session_complete = true
	game.playing = false
	game.level_is_ready = false
	_sprite_child.visible = false
	_sprite_mother.visible = false
	$SessionOverlay.hide()

	if _current_trace.size() > 1:
		_trace_segments.append(_current_trace)
	_current_trace = []

	var dur_min: int = int(_duration_ms / 60000.0)
	var dur_sec: int = int(_duration_ms / 1000.0) % 60

	var phases: Array = _compute_phase_durations(_key_poll)
	_computed_phases = phases
	var minhale: float = phases[0]
	var mhold_top: float = phases[1]
	var mexhale: float = phases[2]
	var mhold_bot: float = phases[3]
	var has_data: bool = minhale + mexhale > 100.0

	var d: Array = MotherG.get_guided_durations() if not active_mode else []
	if active_mode:
		if has_data:
			_result_label.text = "Session: %d:%02d min\nPattern saved for next guided session" % [dur_min, dur_sec]
			_populate_phase_grid([minhale, mhold_top, mexhale, mhold_bot], [])
		else:
			_result_label.text = "Session: %d:%02d min\nNo breathing data detected" % [dur_min, dur_sec]
			_populate_phase_grid([], [])
	else:
		_session_ps = 0
		if has_data:
			var err: float = 0.0
			err += absf(minhale - d[0]) / maxf(d[0], 1.0)
			err += absf(mhold_top - d[1]) / maxf(d[1], 1.0)
			err += absf(mexhale - d[2]) / maxf(d[2], 1.0)
			err += absf(mhold_bot - d[3]) / maxf(d[3], 1.0)
			err /= 4.0
			_session_ps = clampi(roundi((1.0 - minf(err, 1.0)) * 100.0), 0, 100)
			game.add_score_and_time(_session_ps, 0, true)
		_result_label.text = "Session: %d:%02d min    Score: %d/100" % [dur_min, dur_sec, _session_ps]
		if has_data:
			_populate_phase_grid([minhale, mhold_top, mexhale, mhold_bot], d)
		else:
			_result_label.text += "\nNo breathing data detected"
			_populate_phase_grid([], [])

	if not active_mode and has_data:
		var mother_cmds: Array = _get_mother_commands()
		_rt_ms = calc_reaction_time(mother_cmds, _key_poll)
		_reaction_label.text = "Avg reaction time: %d ms" % _rt_ms
		_reaction_label.visible = true
	else:
		_rt_ms = 0
		_reaction_label.visible = false

	if _graph != null:
		_graph.visible = true
		var graph_mother: Array = _get_mother_commands() if not active_mode else []
		var graph_duration_ms: float = _key_poll.size() * KEY_POLL_INTERVAL_MS
		_graph.call("set_data", _key_poll, graph_mother, graph_duration_ms)
		_graph.queue_redraw()

	_results_panel.show()
	sig_session_done.emit()

func _populate_phase_grid(phases: Array, durations: Array) -> void:
	for child in _phase_grid.get_children():
		child.queue_free()
	if phases.size() < 4:
		return
	var font: Font = MainGlobals.get_system_sans_font()
	var fs: int = 28 if MainGlobals.is_mobile() else 20
	var has_target: bool = durations.size() >= 4
	_phase_grid.columns = 3 if has_target else 2
	var rows: Array = [["Inhale", phases[0], durations[0] if has_target else 0.0]]
	if (has_target and durations[1] > 200.0) or (not has_target and phases[1] > 200.0):
		rows.append(["Hold air", phases[1], durations[1] if has_target else 0.0])
	rows.append(["Exhale", phases[2], durations[2] if has_target else 0.0])
	if (has_target and durations[3] > 200.0) or (not has_target and phases[3] > 200.0):
		rows.append(["Hold empty", phases[3], durations[3] if has_target else 0.0])
	for row in rows:
		var lbl_n: Label = Label.new()
		lbl_n.text = str(row[0]) + ":"
		lbl_n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl_n.add_theme_font_override("font", font)
		lbl_n.add_theme_font_size_override("font_size", fs)
		lbl_n.add_theme_color_override("font_color", Color(0.72, 0.82, 0.95, 0.80))
		_phase_grid.add_child(lbl_n)
		var lbl_v: Label = Label.new()
		lbl_v.text = "%.1f s" % [float(row[1]) / 1000.0]
		lbl_v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl_v.add_theme_font_override("font", font)
		lbl_v.add_theme_font_size_override("font_size", fs)
		lbl_v.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 1.0))
		_phase_grid.add_child(lbl_v)
		if has_target:
			var lbl_t: Label = Label.new()
			lbl_t.text = "(target %.1f s)" % [float(row[2]) / 1000.0]
			lbl_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			lbl_t.add_theme_font_override("font", font)
			lbl_t.add_theme_font_size_override("font_size", fs)
			lbl_t.add_theme_color_override("font_color", Color(0.70, 0.88, 0.72, 0.72))
			_phase_grid.add_child(lbl_t)

# keys: Array of int polled every 50ms — 1=up pressed, 2=down pressed, 0=neither
# Returns [inhale_ms, hold_top_ms, exhale_ms, hold_bot_ms] as average durations in ms
func _compute_phase_durations(keys: Array) -> Array:
	var res:Array[float] = [0.0, 0.0, 0.0, 0.0]

	# print("got %d keys" % [keys.size()])

	# var num_vals = [0,0,0]
	# for i in keys.size():
	# 	num_vals[keys[i]] += 1

	# print("num keys: ", num_vals)

	#first, fill outlier gaps
	var maxgap:int = 2
	# var ngaps_filled = 0
	for i in range(maxgap + 1,keys.size()):
		if keys[i] != 0 and keys[i-1] == 0 and keys[i-maxgap-1] == keys[i]:
			for j in range(i-maxgap,i):
				keys[j] = keys[i]
			# ngaps_filled += 1
	# print("filled %d gaps" % ngaps_filled)	

	#second, find consecutive phases
	var i_started = 0
	var phase = -1
	var sums:Array[int] = [0,0,0,0]
	var nums:Array[int] = [0,0,0,0]
	for i in keys.size():
		if keys[i] == 1:
			if phase != 0:
				if phase == 3:
					nums[3] += 1
					sums[3] += i - i_started + 1
				i_started = i
				phase = 0
				# print("set phase 0")
		elif keys[i] == 2:
			if phase != 2:
				if phase == 1:
					nums[1] += 1
					sums[1] += i - i_started + 1
				i_started = i
				phase = 2
				# print("set phase 2")
		else:			
			if phase == 0:
				nums[0] += 1
				sums[0] += i - i_started + 1
				i_started = i
				phase = 1
				# print("set phase 1")
			elif phase == 2:
				nums[2] += 1
				sums[2] += i - i_started + 1
				i_started = i
				phase = 3
				# print("set phase 3")

	for i in 4:
		res[i] = float(sums[i]) / (float(nums[i]) + 1e-6) * 50.0
		# print("for phase i got sum %d num %d res %.1f" % [sums[i],nums[i],res[i]])

	return res


func _get_mother_commands() -> Array:
	var d: Array = MotherG.get_guided_durations()
	var inhale_ms: float = d[0]
	var hold_top_ms: float = d[1]
	var exhale_ms: float = d[2]
	var hold_bot_ms: float = d[3]
	var cycle_ms: float = inhale_ms + hold_top_ms + exhale_ms + hold_bot_ms
	if cycle_ms < 1.0:
		return []
	var result: Array = []
	for i: int in _key_poll.size():
		var t: float = fmod(float(i) * KEY_POLL_INTERVAL_MS, cycle_ms)
		if t < inhale_ms:
			result.append(1)
		elif t < inhale_ms + hold_top_ms:
			result.append(0)
		elif t < inhale_ms + hold_top_ms + exhale_ms:
			result.append(2)
		else:
			result.append(0)
	return result

func calc_reaction_time(mother_commands: Array, child_actions: Array) -> int:
	# Returns mean reaction time in ms (center 80th percentile, slots * 50ms).
	# Each sample: slots until child makes the same phase transition as mother (0 = reacted early).
	# old: return int(dt * float(sum) / (num + 1e-6) + 0.5)  # plain mean of all samples
	var dt: float = 50.0
	var look_back: int = int(200.0 / dt + 0.5)    # 4 slots — child reacted early window
	var look_ahead: int = int(2000.0 / dt + 0.5)  # 40 slots — max latency to measure
	var actual_commands: Array = []

	for i in range(1, mother_commands.size()):
		if mother_commands[i] != mother_commands[i - 1]:
			var found_back: int = -1
			var found_ahead: int = -1
			for j in range(i - 1, max(1, i - look_back) - 1, -1):
				if child_actions[j] == mother_commands[i] and child_actions[j - 1] == mother_commands[i - 1]:
					found_back = j
					break
			for j in range(i, min(child_actions.size(), i + look_ahead + 1)):
				if child_actions[j] == mother_commands[i] and child_actions[j - 1] == mother_commands[i - 1]:
					found_ahead = j
					break
			if found_back >= 0 and (found_ahead < 0 or i - found_back < found_ahead - i):
				actual_commands.append(0)  # child reacted early
			elif found_ahead >= 0:
				actual_commands.append(found_ahead - i)
			# else: neither found — skip (missing reaction, not counted)

	if actual_commands.is_empty():
		return 0

	actual_commands.sort()
	var cut: int = maxi(0, int(actual_commands.size() * 0.10))
	var trimmed: Array = actual_commands.slice(cut, actual_commands.size() - cut)
	if trimmed.is_empty():
		trimmed = actual_commands
		# return int(dt * float(actual_commands[actual_commands.size() / 2]) + 0.5)
	var s: float = 0.0
	for v in trimmed:
		s += float(v)
	return int(dt * s / float(trimmed.size()) + 0.5)

func _on_again_pressed() -> void:
	_results_panel.hide()
	game.reset(true)
	new_game()

func _on_done_pressed() -> void:
	sig_show_main_menu.emit()
