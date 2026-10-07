extends CanvasLayer

# Lighthouse: a boat crosses a dark sea at night, from the bottom center to a pier at the top
# center. Nothing in the sea can be seen except where light falls on it: the lighthouse in the
# middle sweeps a beam round, widening as it goes out and lighting EVERYTHING in its way, and the
# boat carries a small light of its own that is bright at the bow and fades ahead. Rocks, wrecks and
# cliffs show only in slices as the light passes, so getting across is remembering where they were.
#
# HOW THE DARK IS MADE. The sea, the obstacles and the pier live in their own CanvasLayer under a
# near-black CanvasModulate, and two PointLight2Ds light them: the beam (a long wedge texture,
# rotated about the lamp) and the boat's light (a cone at the bow). Anything in that layer is visible
# exactly where, and as much as, a light falls on it -- "partially seen" is not computed, it is what
# lighting does. The beam's sides are soft in the texture and it turns smoothly, so a lit thing fades
# as the beam moves off it; there is no afterglow.
#
# What must ALWAYS be visible -- the boat, the lighthouse's head seen from above, the drawn route --
# is drawn in this layer, above the dark one, and is not touched by the CanvasModulate.
#
# MOVEMENT IS CONTINUOUS. The boat has a position and a heading, turns at a limited rate toward the
# next point of its route, and sails at the level's speed. A drawn route is kept as the points drawn
# (thinned), never snapped to cells. Arrow keys steer too: left/right turn, up sails ahead, down
# stops. A tap on the boat stops it; a tap elsewhere sends it straight there.
#
# Input is the mouse button and mouse motion only: touch is emulated as mouse.

var game: GenericGameUtil
var current_level_id: int = 1

# --- level params (LighthouseLevelConfig), in 680-wide units until scaled by _k ---
var n_obstacles: int = 6
var obstacle_size: float = 34.0
var beam_turn_deg: float = 50.0
var beam_width: float = 230.0
var boat_light: float = 150.0
var boat_speed: float = 105.0
var max_rounds: int = 3
var round_ms: float = 60000.0             # each round's time limit
var same_sea: bool = true
var max_crashes: int = 3                  # the first round's; see max_crashes_for()
var n_boats: int = 0                      # other boats crossing the sea

const REF_W: float = 680.0
var _k: float = 1.0                       # sea width / REF_W

# --- the sea ---
var _sea: Rect2 = Rect2()
var _world_layer: CanvasLayer = null
var _world: Node2D = null
var _dark: CanvasModulate = null
var _beam: PointLight2D = null
var _lamp_glow: PointLight2D = null
# A very small, very faint glow round each light source, on the water just around it: the lantern
# and the boat's lamp. Only a hint that a lamp is there -- the beams are what show things.
var _boat_glow: PointLight2D = null
const GLOW_ENERGY: float = 0.45
const BOAT_GLOW_ENERGY: float = 0.6
var _boat_lamp: PointLight2D = null
var _overlay: Node2D = null
var _route_line: Line2D = null
# The waves: small crests that drift across the sea and swell and fade, each on its own phase. They
# are in the dark layer, so they show only where light falls -- the beam and the boat's light find a
# moving sea. One per ~1800 px^2: [Vector2 home, float half_len, float phase, float drift speed].
var _waves: Array = []
var _sea_bg: Node2D = null
var _waves_node: Node2D = null

# One per obstacle: {kind: "rock"|"wreck"|"cliff", poly: PackedVector2Array (sea coords), center:
# Vector2, r: float, seen: bool, deck: Array (wreck planks)}. `seen` is set the first time any light
# falls on it, and kept for as long as the sea is (the whole level when same_sea).
var obstacles: Array = []
# OTHER BOATS, crossing the sea from one edge to the other, slowly: {path: PackedVector2Array, next:
# int, pos: Vector2, heading: float, speed: float, seen: bool}. Each has its OWN ROUTE, found once
# when the sea is built: a grid search (AStarGrid2D) from one edge to the other at its starting
# height, with a boat's width of clearance from every obstacle, the lighthouse and the jetty -- so it
# runs straight where the sea is clear and curves round whatever is in the way, and a boat can never
# meet an obstacle. It follows the route turning smoothly, and starts again at its beginning off the
# far edge. In the dark layer like the rocks: seen only where light falls. Bumping into one is a crash
# (hit_at returns TRAFFIC + its index); one that would run into the player's boat waits, and so does
# the later of two boats about to touch. (Horizontal lanes reserved before the rocks were placed were
# tried and rejected: they bent the rock layout round them and capped the number of boats.)
var traffic: Array = []
const TRAFFIC: int = 1000
const TRAFFIC_LEN: float = 46.0           # 680-wide units
const TRAFFIC_WID: float = 16.0
var _traffic_node: Node2D = null
var _lh_pos: Vector2 = Vector2.ZERO      # the lighthouse: center of the sea
var _lh_r: float = 30.0                  # its rock island's radius (an obstacle too)
var _pier: Rect2 = Rect2()               # the whole jetty's bounds (kept clear of obstacles)
var _jetty_walk: Rect2 = Rect2()
var _jetty_head: Rect2 = Rect2()
var _harbor_light: PointLight2D = null
var _dock: Vector2 = Vector2.ZERO        # just below the landing: the approach kept clear and searched to
var _start: Vector2 = Vector2.ZERO

# --- the boat ---
var boat_pos: Vector2 = Vector2.ZERO
var boat_heading: float = -PI * 0.5      # radians; -PI/2 is straight up the screen
var boat_moving: bool = false
var route: Array = []                    # Array of Vector2, the points still to sail through
const BOAT_LEN: float = 30.0             # 680-wide units
const BOAT_R: float = 9.0                # collision radius, 680-wide units
const TURN_RATE: float = 3.2             # radians a second
const LOOKAHEAD: float = 34.0            # 680-wide units: how far along its route the boat aims
var beam_angle: float = 0.0
var _invuln_until: float = 0.0
# What the boat last crashed into (an obstacle's index, -1 the lighthouse rock, NO_CRASH nothing).
# Touching it again does not count until the boat has been CRASH_CLEAR away from it -- a boat nosing
# along a rock it has just hit is one crash, not one every 0.7 s.
const NO_CRASH: int = -99
const CRASH_CLEAR: float = 22.0           # 680-wide units beyond the boat's own radius
var _last_crash: int = NO_CRASH
var _crash_t: float = -10000.0
var _crash_at: Vector2 = Vector2.ZERO

# --- phases ---
enum Phase { IDLE, PLAY, ROUND_OVER, ROUND_CARD, DONE }
var phase: int = Phase.IDLE
var _phase_start: float = 0.0
var _awaiting_round_card: bool = false
var _awaiting_summary: bool = false
var round_index: int = 0                 # 1-based once a round starts
var _round_t: float = 0.0                # ms sailed this round
var _round_won: bool = false
var _timed_out: bool = false             # this round's time ran out

# --- what is recorded, per level ---
var round_times_ms: Array = []           # every round's crossing time, won or not
var round_solved: Array = []             # whether each round reached the jetty
var round_timed_out: Array = []          # whether each lost round lost to the clock
var round_collisions: Array = []         # collisions in each round
var collisions_total: int = 0
var collisions_seen: int = 0             # collisions with something the light had shown before
var rounds_won: int = 0
var lives: int = 3                       # lifebuoys left this round; the round is lost at 0

# --- input ---
const TAP_SLOP: float = 12.0
const RESUME_MS: int = 300
const RESUME_PX: float = 70.0
var _released_ms: int = -100000
var _pressed: bool = false
var _press_at: Vector2 = Vector2.ZERO
var _drawing: bool = false
var _drawn: Array = []

# --- ui (built in code) ---
var _caption: Label = null
var _feedback: Label = null
var _bar_track: ColorRect = null
var _bar_fill: ColorRect = null
var _bar_full_w: float = 200.0
var _bar_h: float = 14.0

const BG: Color = Color(0.02, 0.03, 0.06)
# What the dark leaves of the sea. Nearly black ON PURPOSE: at a few percent, pale rock stayed a
# shade above the sea around it and every obstacle showed as a faint silhouette in the dark.
const NIGHT: Color = Color(0.010, 0.013, 0.025)
const SEA: Color = Color(0.13, 0.27, 0.42)
const FEEDBACK_SEC: float = 1.2
const CRASH_SEC: float = 0.5

var crash_audio = preload("res://art/sounds/bump-sound-7.mp3")
var dock_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var waves_audio = preload("res://art/sounds/ocean-waves-2.mp3")

signal sig_level_is_done(didwin: bool)
signal started_playing
signal lives_changed

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	game = LighthouseG.game
	game.add_sound(self, "crash", crash_audio)
	game.add_sound(self, "dock", dock_audio)
	game.add_sound(self, "waves", waves_audio, true)
	_rng.randomize()
	_build_ui()
	# The dark layer is a CanvasLayer of its own, so hiding this one does not reach it.
	visibility_changed.connect(func() -> void: _world_layer.visible = visible)

# --- UI ------------------------------------------------------------------------------------------

func _build_ui() -> void:
	_world_layer = CanvasLayer.new()
	_world_layer.layer = 0
	add_child(_world_layer)
	_dark = CanvasModulate.new()
	_dark.color = NIGHT
	_world_layer.add_child(_dark)
	_sea_bg = Node2D.new()
	_sea_bg.draw.connect(func() -> void:
		if _sea.size.x > 0.0:
			_sea_bg.draw_rect(_sea, SEA))
	_world_layer.add_child(_sea_bg)
	_waves_node = Node2D.new()
	_waves_node.draw.connect(_draw_waves)
	_world_layer.add_child(_waves_node)
	_world = Node2D.new()
	_world.draw.connect(_draw_world)
	_world_layer.add_child(_world)
	_traffic_node = Node2D.new()
	_traffic_node.draw.connect(_draw_traffic)
	_world_layer.add_child(_traffic_node)
	_beam = PointLight2D.new()
	_beam.texture = _beam_texture()
	_beam.energy = 1.25
	_world_layer.add_child(_beam)
	_lamp_glow = PointLight2D.new()
	_lamp_glow.texture = _glow_texture()
	_lamp_glow.energy = GLOW_ENERGY
	_world_layer.add_child(_lamp_glow)
	_boat_glow = PointLight2D.new()
	_boat_glow.texture = _glow_texture()
	_boat_glow.energy = BOAT_GLOW_ENERGY
	_world_layer.add_child(_boat_glow)
	# A small green harbor light at the jetty's end, so the goal is known in the dark; the jetty
	# itself still shows only where light falls on it.
	_harbor_light = PointLight2D.new()
	_harbor_light.texture = _glow_texture()
	_harbor_light.color = Color(0.45, 1.0, 0.55)
	_harbor_light.energy = 0.9
	_world_layer.add_child(_harbor_light)
	_boat_lamp = PointLight2D.new()
	_boat_lamp.texture = _cone_texture()
	_boat_lamp.energy = 2.2
	_world_layer.add_child(_boat_lamp)

	_route_line = Line2D.new()
	_route_line.width = 4.0
	_route_line.default_color = Color(1.0, 0.86, 0.45, 0.55)
	_route_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_route_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_route_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_route_line)
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_bar_track = ColorRect.new()
	_bar_track.color = Color(1, 1, 1, 0.10)
	_bar_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_track)
	_bar_fill = ColorRect.new()
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.visible = false
	add_child(_bar_fill)
	_caption = _make_label(Color(1, 1, 1, 0.92))
	add_child(_caption)
	_feedback = _make_label(Color(0.3, 0.9, 0.45))
	_feedback.z_index = 40
	_feedback.hide()
	add_child(_feedback)

func _make_label(col: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)

# The sea is everything between the caption and the app's bottom bar, full width. Its geometry is
# fixed when a level loads; a resize only moves the labels.
func _layout_ui() -> Rect2:
	var sw: float = float(MainGlobals.screen_size.x)
	var sh: float = float(MainGlobals.screen_size.y)
	var mob: bool = MainGlobals.is_mobile()
	var hh: float = float(MainGlobals.header_height)
	MainGlobals.set_font_size(_caption, 20)
	MainGlobals.set_font_size(_feedback, 48)
	_bar_h = 22.0 if mob else 14.0
	var bar_x: float = 22.0
	var bar_y: float = hh + 8.0
	_bar_full_w = sw - bar_x * 2.0
	_place(_bar_track, bar_x, bar_y, _bar_full_w, _bar_h)
	_bar_fill.position = Vector2(bar_x, bar_y)
	var cap_h: float = 48.0 if mob else 36.0
	var cap_top: float = 136.0          # below the level number, which main.gd moves to y 92-132
	_place(_caption, 0.0, cap_top, sw, cap_h)
	var top: float = cap_top + cap_h + 6.0
	var bottom_bar: float = 70.0 if mob else 44.0
	var bottom: float = sh - maxf(20.0, bottom_bar - float(MainGlobals.footer_height) + 12.0)
	var sea: Rect2 = Rect2(8.0, top, sw - 16.0, maxf(120.0, bottom - top))
	_place(_feedback, 0.0, sea.position.y + sea.size.y * 0.30 - 60.0, sw, 120.0)
	return sea

# --- light textures --------------------------------------------------------------------------------

# The beam, along +x from the texture's center: narrow at the lamp, `beam_width` wide at the far
# edge of the sea, with sides that fade over a third of its half-width so a lit thing fades in and
# out as the beam passes. Small (256 px) and scaled up with texture_scale.
const BEAM_TEX: int = 256
func _beam_texture() -> Texture2D:
	var img: Image = Image.create(BEAM_TEX, BEAM_TEX, false, Image.FORMAT_RGBA8)
	var c: float = float(BEAM_TEX) * 0.5
	# the width is set per level by rescaling the texture's y (see _apply_level_lights); here the
	# beam's half-width grows from 3% of the radius at the lamp to 50% at the edge
	for y in BEAM_TEX:
		for x in BEAM_TEX:
			var px: float = float(x) + 0.5 - c
			var py: float = float(y) + 0.5 - c
			var a: float = 0.0
			if px > 0.0:
				var t: float = px / c
				var half: float = c * (0.03 + 0.47 * t)
				var lat: float = absf(py) / half
				var side: float = 1.0 - smoothstep(0.62, 1.0, lat)
				var along: float = (1.0 - 0.45 * t) * (1.0 - smoothstep(0.92, 1.0, t))
				a = side * along
			img.set_pixel(x, y, Color(1.0, 0.95, 0.80, a))
	return ImageTexture.create_from_image(img)

# The boat's light: a cone along +x from the texture's center, bright at the bow and fading into the
# dark at its end.
const CONE_TEX: int = 128
func _cone_texture() -> Texture2D:
	var img: Image = Image.create(CONE_TEX, CONE_TEX, false, Image.FORMAT_RGBA8)
	var c: float = float(CONE_TEX) * 0.5
	for y in CONE_TEX:
		for x in CONE_TEX:
			var px: float = float(x) + 0.5 - c
			var py: float = float(y) + 0.5 - c
			var a: float = 0.0
			var d: float = Vector2(px, py).length()
			if px > -2.0 and d < c:
				var ang: float = absf(atan2(py, maxf(px, 0.001)))
				var cone: float = 1.0 - smoothstep(0.34, 0.55, ang)
				var fall: float = pow(1.0 - d / c, 1.1)
				a = cone * fall
			img.set_pixel(x, y, Color(1.0, 0.92, 0.70, a))
	return ImageTexture.create_from_image(img)

# A soft round glow: the lamp lighting its own rock.
func _glow_texture() -> Texture2D:
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c: float = float(n) * 0.5
	for y in n:
		for x in n:
			var d: float = Vector2(float(x) + 0.5 - c, float(y) + 0.5 - c).length() / c
			img.set_pixel(x, y, Color(1.0, 0.9, 0.7, clampf(1.0 - d, 0.0, 1.0) ** 1.6))
	return ImageTexture.create_from_image(img)

func _apply_level_lights() -> void:
	# The beam reaches the farthest corner of the sea.
	var reach: float = 0.0
	for corner: Vector2 in [_sea.position, _sea.position + Vector2(_sea.size.x, 0.0),
			_sea.position + Vector2(0.0, _sea.size.y), _sea.end]:
		reach = maxf(reach, corner.distance_to(_lh_pos))
	_beam.position = _lh_pos
	_beam.texture_scale = reach / (float(BEAM_TEX) * 0.5)
	# The texture's edge half-width is 50% of the reach; scale y so it is beam_width / 2 instead.
	var want_half: float = beam_width * _k * 0.5
	_beam.scale = Vector2(1.0, clampf(want_half / (reach * 0.5), 0.15, 3.0))
	_lamp_glow.position = _lh_pos
	_lamp_glow.texture_scale = _lh_r * 2.8 / 32.0
	_boat_glow.texture_scale = BOAT_LEN * _k * 1.1 / 32.0
	_boat_lamp.texture_scale = boat_light * _k / (float(CONE_TEX) * 0.5)

# --- level flow ----------------------------------------------------------------------------------

func new_game(from_scratch: bool = true) -> void:
	game.level_is_done = false
	game.level_is_ready = false
	if from_scratch:
		current_level_id = LighthouseG.starting_level_id
	elif game.need_to_increase_level:
		current_level_id = LighthouseLevelConfig.next_id(current_level_id)
	game.need_to_increase_level = false
	round_times_ms.clear()
	round_solved.clear()
	round_timed_out.clear()
	round_collisions.clear()
	collisions_total = 0
	collisions_seen = 0
	rounds_won = 0
	round_index = 0
	_timed_out = false
	_awaiting_round_card = false
	_awaiting_summary = false
	phase = Phase.IDLE
	_feedback.hide()
	_caption.text = ""
	_bar_fill.visible = false
	route.clear()
	_reset_gesture()
	_route_line.points = PackedVector2Array()
	_load_level(current_level_id)
	_sea = _layout_ui()
	_k = _sea.size.x / REF_W
	_lh_pos = _sea.get_center()
	_lh_r = 26.0 * _k
	_build_fixtures()
	_build_sea()
	_build_traffic()
	_apply_level_lights()
	_reset_boat()
	_world.queue_redraw()
	_sea_bg.queue_redraw()
	_waves_node.queue_redraw()
	_overlay.queue_redraw()
	if game.tutorial_mode:
		game.level_is_ready = true
		started_playing.emit()
		return
	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	game.show_game_popup(self, round_title(1), briefing_text(1))

# TWO cards between rounds. First the SUMMARY of the round just played (summary_title/summary_text:
# "Round 1 complete" or "Round 1 failed" -- the title gives the card its gold or warm look and a
# Continue button), then the INTRO of the next (round_title/briefing_text: that round's facts, its own
# crash limit among them), the same card round 1 opens with. Facts only: how the game is played is
# the instructions screen's and the tutorial's.
func round_title(k: int) -> String:
	if k <= 1:
		return "Level %d \u00b7 Round 1 of %d" % [current_level_id, max_rounds]
	return "Round %d of %d" % [k, max_rounds]

func summary_title() -> String:
	var ok: bool = not round_solved.is_empty() and bool(round_solved.back())
	return "Round %d %s" % [round_solved.size(), "complete" if ok else "failed"]

func summary_text() -> String:
	var p: int = round_solved.size() - 1
	var ok: bool = bool(round_solved[p])
	var lines: Array = []
	lines.append("Result: " + ("Docked" if ok else ("Out of time" if bool(round_timed_out[p]) else "Too many crashes")))
	if ok:
		lines.append("Time: " + _fmt_secs(float(round_times_ms[p]) / 1000.0))
	lines.append("Crashes: %d" % int(round_collisions[p]))
	return "\n".join(lines)

func briefing_text(k: int = 1) -> String:
	var lines: Array = []
	# Short values: the table is as wide as its widest row, and a long one pushed the card off a
	# phone's screen.
	lines.append("Obstacles: %d" % n_obstacles)
	lines.append("Other boats: " + (str(n_boats) if n_boats > 0 else "None"))
	lines.append("Same sea: " + ("Yes" if same_sea else "No"))
	lines.append("Max crashes: %d" % max_crashes_for(k))
	lines.append("Max time: " + _fmt_secs(round_ms / 1000.0))
	return "\n".join(lines)

func _on_game_popup_closed() -> void:
	if _awaiting_summary:
		# the summary closed: now the next round's own card
		_awaiting_summary = false
		_awaiting_round_card = true
		game.show_game_popup(self, round_title(round_index + 1), briefing_text(round_index + 1))
		return
	if _awaiting_round_card:
		_awaiting_round_card = false
		_next_round()
		return
	if not game.level_is_done and not game.level_is_ready:
		game.level_is_ready = true
		started_playing.emit()

func stop_level() -> void:
	_awaiting_round_card = false
	_awaiting_summary = false
	_reset_gesture()
	phase = Phase.IDLE
	_feedback.hide()
	_bar_fill.visible = false
	route.clear()
	_route_line.points = PackedVector2Array()
	game.stop_sound("waves")

func _load_level(id: int) -> void:
	var def: Dictionary = LighthouseLevelConfig.get_level(id)
	n_obstacles = maxi(0, int(def.get("obstacles", 6)))
	obstacle_size = maxf(8.0, float(def.get("obstacle_size", 30)))
	beam_turn_deg = float(def.get("beam_turn_deg", 45))
	beam_width = maxf(20.0, float(def.get("beam_width", 200)))
	boat_light = maxf(20.0, float(def.get("boat_light", 130)))
	boat_speed = maxf(20.0, float(def.get("boat_speed", 110)))
	max_rounds = maxi(1, int(def.get("rounds", 3)))
	round_ms = maxf(10.0, float(def.get("round_sec", 60))) * 1000.0
	same_sea = bool(def.get("same_sea", true))
	n_boats = maxi(0, int(def.get("boats", 0)))
	max_crashes = maxi(0, int(def.get("max_crashes", 3)))
	game.level_label_changed("Level " + str(def.get("name", id)))
	game.set_task_signature({"obstacles": n_obstacles, "obstacle_size": int(obstacle_size),
		"beam_turn_deg": int(beam_turn_deg), "beam_width": int(beam_width), "boat_light": int(boat_light),
		"boat_speed": int(boat_speed), "rounds": max_rounds, "round_sec": int(round_ms / 1000.0),
		"same_sea": same_sea, "max_crashes": max_crashes, "boats": n_boats})

func _can_play() -> bool:
	return game.playing and not game.paused() and not game.level_is_done and game.level_is_ready

func _enter(ph: int) -> void:
	phase = ph
	_phase_start = game.game_time

# --- the sea: pier, start, lighthouse, obstacles -------------------------------------------------

func _build_fixtures() -> void:
	# A jetty from the top edge: a narrow walkway, then a wider landing. Close to the top -- the
	# crossing is the whole sea, not most of it.
	var walk_w: float = 18.0 * _k
	var walk_l: float = 20.0 * _k
	var head_w: float = 76.0 * _k
	var head_d: float = 16.0 * _k
	_jetty_walk = Rect2(_lh_pos.x - walk_w * 0.5, _sea.position.y, walk_w, walk_l)
	_jetty_head = Rect2(_lh_pos.x - head_w * 0.5, _sea.position.y + walk_l, head_w, head_d)
	_pier = _jetty_walk.merge(_jetty_head)
	_dock = Vector2(_lh_pos.x, _jetty_head.end.y + 10.0 * _k)
	_harbor_light.position = Vector2(_jetty_head.end.x - 6.0 * _k, _jetty_head.get_center().y)
	_harbor_light.texture_scale = 70.0 * _k / 32.0
	_start = Vector2(_lh_pos.x, _sea.end.y - 34.0 * _k)
	_waves.clear()
	var n: int = int(_sea.size.x * _sea.size.y / 1800.0)
	for _i in n:
		_waves.append([Vector2(_rng.randf_range(_sea.position.x, _sea.end.x), _rng.randf_range(_sea.position.y, _sea.end.y)),
			_rng.randf_range(6.0, 14.0) * _k, _rng.randf_range(0.0, TAU), _rng.randf_range(14.0, 26.0) * _k])

# A fresh layout. Kept clear of the start, the pier and the lighthouse, apart from each other by
# more than a boat's width, and checked to leave a way through; a layout that blocks the way is
# drawn again (up to 40 times, then with one obstacle fewer).
func _build_sea() -> void:
	var want: int = n_obstacles
	for attempt in 120:
		obstacles = _try_layout(want)
		if obstacles.size() == want and has_way_through():
			return
		if attempt % 40 == 39:
			want = maxi(0, want - 1)
	obstacles = []

func _try_layout(want: int) -> Array:
	var out: Array = []
	var margin: float = 6.0 * _k
	var gap: float = BOAT_R * _k * 4.0
	for _i in want * 30:
		if out.size() >= want:
			break
		var kinds: Array = ["rock", "rock", "wreck", "cliff"]
		var kind: String = str(kinds[_rng.randi_range(0, kinds.size() - 1)])
		var r: float = obstacle_size * _k * _rng.randf_range(0.8, 1.2) * (1.35 if kind == "cliff" else 1.0)
		var c: Vector2 = Vector2(_rng.randf_range(_sea.position.x + r + margin, _sea.end.x - r - margin),
			_rng.randf_range(_sea.position.y + r + margin, _sea.end.y - r - margin))
		if c.distance_to(_start) < r + 70.0 * _k or c.distance_to(_dock) < r + 70.0 * _k:
			continue
		if c.distance_to(_lh_pos) < r + _lh_r + gap:
			continue
		if _pier.grow(gap).has_point(c):
			continue
		var clash: bool = false
		for o: Dictionary in out:
			if c.distance_to(o["center"]) < r + float(o["r"]) + gap:
				clash = true
				break
		if clash:
			continue
		out.append(_make_obstacle(kind, c, r))
	return out

func _make_obstacle(kind: String, c: Vector2, r: float) -> Dictionary:
	var poly: PackedVector2Array = PackedVector2Array()
	var deck: Array = []
	match kind:
		"wreck":
			# a broken hull lying on its side: pointed bow, square-ish stern, one corner torn away
			var ang: float = _rng.randf_range(0.0, TAU)
			var L: float = r * 1.15
			var Wd: float = r * 0.48
			var pts: Array = [Vector2(L, 0.0), Vector2(L * 0.45, Wd), Vector2(-L * 0.7, Wd * 0.95),
				Vector2(-L, Wd * 0.3), Vector2(-L * 0.78, -Wd * 0.2), Vector2(-L * 0.9, -Wd * 0.85),
				Vector2(L * 0.45, -Wd)]
			for p: Vector2 in pts:
				poly.append(c + p.rotated(ang))
			for k in 4:
				var x: float = -L * 0.55 + float(k) * L * 0.32
				deck.append([c + Vector2(x, -Wd * 0.75).rotated(ang), c + Vector2(x, Wd * 0.75).rotated(ang)])
			deck.append([c + Vector2(-L * 0.2, 0.0).rotated(ang), c + Vector2(L * 0.9, -Wd * 1.6).rotated(ang)])   # fallen mast
		"cliff":
			# a long ragged ridge
			var ang2: float = _rng.randf_range(0.0, TAU)
			var n: int = 12
			for i in n:
				var a: float = TAU * float(i) / float(n)
				var rr: float = r * _rng.randf_range(0.75, 1.1)
				poly.append(c + Vector2(cos(a) * rr * 1.25, sin(a) * rr * 0.55).rotated(ang2))
		_:
			var n2: int = _rng.randi_range(7, 10)
			var a0: float = _rng.randf_range(0.0, TAU)
			for i in n2:
				var a2: float = a0 + TAU * float(i) / float(n2)
				poly.append(c + Vector2(cos(a2), sin(a2)) * r * _rng.randf_range(0.72, 1.1))
	return {"kind": kind, "poly": poly, "center": c, "r": r, "seen": false, "deck": deck}

# Is there a way from the start to the pier for a boat? A grid search over the sea at a boat's
# width, a cell blocked where a boat there would touch something.
func has_way_through() -> bool:
	var step: float = maxf(6.0, BOAT_R * _k * 1.2)
	var cols: int = int(_sea.size.x / step)
	var rows: int = int(_sea.size.y / step)
	var cell_of: Callable = func(p: Vector2) -> Vector2i:
		return Vector2i(clampi(int((p.x - _sea.position.x) / step), 0, cols - 1),
			clampi(int((p.y - _sea.position.y) / step), 0, rows - 1))
	var from: Vector2i = cell_of.call(_start)
	var to: Vector2i = cell_of.call(_dock)
	var seen_cells: Dictionary = {from: true}
	var q: Array = [from]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if cur.distance_to(to) <= 1.5:
			return true
		for dv: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = cur + dv
			if nx.x < 0 or nx.y < 0 or nx.x >= cols or nx.y >= rows or seen_cells.has(nx):
				continue
			seen_cells[nx] = true
			var p: Vector2 = _sea.position + (Vector2(nx) + Vector2(0.5, 0.5)) * step
			if hit_at(p, BOAT_R * _k * 1.1, false) != -2:
				continue
			q.append(nx)
	return false

# What a boat of radius `rad` at `p` touches: an obstacle's index, -1 for the lighthouse rock,
# TRAFFIC + i for another boat, or -2 for nothing. `with_traffic` false leaves the moving boats out
# (the way-through search and the boats' own route search: they move, and route round the rest).
func hit_at(p: Vector2, rad: float, with_traffic: bool = true) -> int:
	if p.distance_to(_lh_pos) < _lh_r + rad:
		return -1
	if with_traffic:
		for t in traffic.size():
			if _touches_traffic(t, p, rad):
				return TRAFFIC + t
	for i in obstacles.size():
		var o: Dictionary = obstacles[i]
		if p.distance_to(o["center"]) > float(o["r"]) * 1.4 + rad:
			continue
		var poly: PackedVector2Array = o["poly"]
		if Geometry2D.is_point_in_polygon(p, poly):
			return i
		for j in poly.size():
			var a: Vector2 = poly[j]
			var b: Vector2 = poly[(j + 1) % poly.size()]
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < rad:
				return i
	return -2

# --- other boats ---------------------------------------------------------------------------------------

# One route per boat: a grid over the sea, a cell solid where a boat there would touch an obstacle,
# the lighthouse or the jetty; each boat starts at a random height on one edge (left or right at
# random) and the grid search finds its way to the other edge. A height with no way across is tried
# again elsewhere; a boat that finds none is left out.
func _build_traffic() -> void:
	traffic.clear()
	if n_boats <= 0:
		return
	var step: float = 8.0 * _k
	var cols: int = int(_sea.size.x / step)
	var rows: int = int(_sea.size.y / step)
	var grid: AStarGrid2D = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, cols, rows)
	grid.cell_size = Vector2(step, step)
	grid.offset = _sea.position + Vector2(step, step) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var clear: float = (TRAFFIC_WID * 0.5 + 6.0) * _k
	var jetty: Rect2 = _pier.grow(clear + 6.0 * _k)
	for cx in cols:
		for cy in rows:
			var at: Vector2 = grid.offset + Vector2(cx, cy) * step
			if jetty.has_point(at) or hit_at(at, clear, false) != -2:
				grid.set_point_solid(Vector2i(cx, cy), true)
	var top: int = int((_pier.end.y + 30.0 * _k - _sea.position.y) / step)
	var bottom: int = rows - 1 - int(50.0 * _k / step)
	for _b in n_boats:
		for _try in 12:
			var row: int = _rng.randi_range(top, maxi(top, bottom))
			var from: Vector2i = Vector2i(0, row)
			var to: Vector2i = Vector2i(cols - 1, row)
			to = _free_near(grid, to, rows)
			from = _free_near(grid, from, rows)
			if from.x < 0 or to.x < 0:
				continue
			var pts: PackedVector2Array = grid.get_point_path(from, to)
			if pts.size() < 2:
				continue
			# off both edges, so a boat sails in and out of sight rather than appearing
			var path: PackedVector2Array = PackedVector2Array([pts[0] - Vector2(TRAFFIC_LEN * _k, 0.0)])
			for q in range(0, pts.size(), 3):
				path.append(pts[q])
			path.append(pts[pts.size() - 1])
			path.append(pts[pts.size() - 1] + Vector2(TRAFFIC_LEN * _k, 0.0))
			if _rng.randf() < 0.5:
				path.reverse()
			var start: int = _rng.randi_range(0, path.size() - 2)
			traffic.append({"path": path, "next": start + 1, "pos": path[start],
				"heading": (path[start + 1] - path[start]).angle(), "speed": _rng.randf_range(22.0, 34.0) * _k, "seen": false})
			break

# The nearest free cell in the same column, searching up and down; x = -1 if the column has none.
func _free_near(grid: AStarGrid2D, cell: Vector2i, rows: int) -> Vector2i:
	for d in rows:
		for sgn in [1, -1]:
			var c: Vector2i = Vector2i(cell.x, cell.y + d * sgn)
			if c.y >= 0 and c.y < rows and not grid.is_point_solid(c):
				return c
	return Vector2i(-1, -1)

# Along its route, turning smoothly toward the next point, and from the beginning again once off the
# far edge -- unless the player's boat, or another boat with a lower number, is just ahead of it:
# then it waits. The other boats never ram.
func _move_traffic(dt: float) -> void:
	for i in traffic.size():
		var t: Dictionary = traffic[i]
		var path: PackedVector2Array = t["path"]
		var pos: Vector2 = t["pos"]
		var nxt_i: int = int(t["next"])
		if nxt_i >= path.size():
			t["pos"] = path[0]
			t["next"] = 1
			t["heading"] = (path[1] - path[0]).angle()
			continue
		var target: Vector2 = path[nxt_i]
		var want: float = (target - pos).angle()
		var h: float = float(t["heading"])
		h += clampf(wrapf(want - h, -PI, PI), -1.6 * dt, 1.6 * dt)
		var fwd: Vector2 = Vector2.from_angle(h)
		var nose: Vector2 = pos + fwd * (TRAFFIC_LEN * 0.5 + 6.0) * _k
		if nose.distance_to(boat_pos) < (BOAT_R + 10.0) * _k or _touches_traffic(i, boat_pos, (BOAT_R + 4.0) * _k):
			continue
		var blocked: bool = false
		for j in i:
			if (traffic[j]["pos"] as Vector2).distance_to(nose) < TRAFFIC_LEN * 0.55 * _k:
				blocked = true
				break
		if blocked:
			continue
		t["heading"] = h
		t["pos"] = pos + fwd * float(t["speed"]) * dt
		if (t["pos"] as Vector2).distance_to(target) < 6.0 * _k:
			t["next"] = nxt_i + 1

func _touches_traffic(i: int, p: Vector2, rad: float) -> bool:
	if i < 0 or i >= traffic.size():
		return false
	var d: Vector2 = (p - (traffic[i]["pos"] as Vector2)).rotated(-float(traffic[i]["heading"]))
	return absf(d.x) < TRAFFIC_LEN * 0.5 * _k + rad and absf(d.y) < TRAFFIC_WID * 0.5 * _k + rad

# A small working boat seen from above: a pointed hull, a deck, a wheelhouse, and the white of its
# wake behind it. Lit only where the light falls, like everything in this layer.
func _draw_traffic() -> void:
	for t: Dictionary in traffic:
		var p: Vector2 = t["pos"]
		var f: Vector2 = Vector2.from_angle(float(t["heading"]))
		var side: Vector2 = f.orthogonal()
		var L: float = TRAFFIC_LEN * _k
		var Wd: float = TRAFFIC_WID * _k
		for k in 4:
			var w: Vector2 = p - f * (L * 0.55 + float(k) * 7.0 * _k)
			_traffic_node.draw_circle(w, (3.0 + float(k) * 1.2) * _k, Color(0.85, 0.92, 1.0, 0.35 - 0.07 * float(k)))
		var hull: PackedVector2Array = PackedVector2Array([
			p + f * L * 0.5, p + f * L * 0.22 + side * Wd * 0.5, p - f * L * 0.5 + side * Wd * 0.45,
			p - f * L * 0.5 - side * Wd * 0.45, p + f * L * 0.22 - side * Wd * 0.5])
		_traffic_node.draw_colored_polygon(hull, Color(0.62, 0.18, 0.16))
		var deck: PackedVector2Array = PackedVector2Array()
		for q: Vector2 in hull:
			deck.append(p + (q - p) * 0.78)
		_traffic_node.draw_colored_polygon(deck, Color(0.78, 0.70, 0.55))
		var cab_c: Vector2 = p - f * L * 0.12
		_traffic_node.draw_colored_polygon(PackedVector2Array([cab_c + f * L * 0.13 + side * Wd * 0.28,
			cab_c - f * L * 0.13 + side * Wd * 0.28, cab_c - f * L * 0.13 - side * Wd * 0.28,
			cab_c + f * L * 0.13 - side * Wd * 0.28]), Color(0.92, 0.92, 0.90))
		_traffic_node.draw_polyline(hull + PackedVector2Array([hull[0]]), Color(0.25, 0.08, 0.07), 1.5 * _k, true)

# --- drawing ---------------------------------------------------------------------------------------

func _draw_world() -> void:
	if _sea.size.x <= 0.0:
		return
	# the jetty: a walkway of planks running out from the top edge, a wider landing across its end,
	# piles under the edges and two mooring posts on the landing
	var wood: Color = Color(0.56, 0.40, 0.25)
	var seam: Color = Color(0.30, 0.20, 0.12)
	for rect: Rect2 in [_jetty_walk, _jetty_head]:
		_world.draw_rect(Rect2(rect.position + Vector2(3.0, 4.0) * _k, rect.size), Color(0, 0, 0, 0.45))
	_world.draw_rect(_jetty_walk, wood)
	var yy: float = _jetty_walk.position.y + 5.0 * _k
	while yy < _jetty_walk.end.y:
		_world.draw_line(Vector2(_jetty_walk.position.x, yy), Vector2(_jetty_walk.end.x, yy), seam, 1.5 * _k)
		yy += 5.0 * _k
	_world.draw_rect(_jetty_head, wood.lightened(0.06))
	var xx: float = _jetty_head.position.x + 6.0 * _k
	while xx < _jetty_head.end.x:
		_world.draw_line(Vector2(xx, _jetty_head.position.y), Vector2(xx, _jetty_head.end.y), seam, 1.5 * _k)
		xx += 6.0 * _k
	_world.draw_rect(_jetty_head, seam, false, 2.0 * _k)
	for px: float in [_jetty_head.position.x, _jetty_head.end.x]:
		for py: float in [_jetty_head.position.y, _jetty_head.end.y]:
			_world.draw_circle(Vector2(px, py), 3.5 * _k, Color(0.25, 0.17, 0.10))
	for bx: float in [_jetty_head.position.x + 14.0 * _k, _jetty_head.end.x - 22.0 * _k]:
		_world.draw_circle(Vector2(bx, _jetty_head.get_center().y), 4.0 * _k, Color(0.15, 0.15, 0.17))
		_world.draw_circle(Vector2(bx - 1.0 * _k, _jetty_head.get_center().y - 1.0 * _k), 2.0 * _k, Color(0.45, 0.45, 0.50))
	# The lighthouse's rock, with a SOFT edge that fades into the water. A hard disc with a foam ring
	# round it, lit evenly by the lantern's glow, read as a sharp constant ring rather than a glow.
	var rock: Color = Color(0.42, 0.40, 0.38)
	for k in 10:
		var t: float = float(k) / 9.0
		_world.draw_circle(_lh_pos, _lh_r * lerpf(1.3, 0.7, t), Color(rock, lerpf(0.10, 1.0, t * t)))
	for o: Dictionary in obstacles:
		_draw_obstacle(o)

# Each crest drifts with the wind (to the right, wrapping round the sea), swells and fades on its own
# phase, and is drawn as a shallow arc -- the lit face of a small wave -- with a faint trough under it.
func _draw_waves() -> void:
	if _sea.size.x <= 0.0:
		return
	var t: float = game.game_time / 1000.0
	var w_sea: float = _sea.size.x
	for w: Array in _waves:
		var home: Vector2 = w[0]
		var hl: float = w[1]
		var ph: float = w[2]
		var x: float = _sea.position.x + fposmod(home.x - _sea.position.x + t * float(w[3]), w_sea)
		var y: float = home.y + sin(t * 1.4 + ph) * 2.0 * _k
		var swell: float = 0.5 + 0.5 * sin(t * 2.2 + ph)
		var half: float = hl * (0.55 + 0.45 * swell)
		var alpha: float = 0.15 + 0.45 * swell
		var r: float = half * 1.8
		var ang: float = asin(clampf(half / r, 0.0, 1.0))
		var ctr: Vector2 = Vector2(x, y + r)
		_waves_node.draw_arc(ctr, r, -PI * 0.5 - ang, -PI * 0.5 + ang, 8, Color(0.70, 0.84, 0.96, alpha), 1.6 * _k, true)
		_waves_node.draw_arc(ctr + Vector2(0, 2.5 * _k), r, -PI * 0.5 - ang * 0.8, -PI * 0.5 + ang * 0.8, 6,
			Color(0.03, 0.10, 0.20, alpha * 0.6), 1.4 * _k, true)

func _draw_obstacle(o: Dictionary) -> void:
	var poly: PackedVector2Array = o["poly"]
	var c: Vector2 = o["center"]
	match str(o["kind"]):
		"wreck":
			# foam where the water breaks on it
			var foam: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in poly:
				foam.append(c + (p - c) * 1.12)
			_world.draw_colored_polygon(foam, Color(0.85, 0.92, 1.0, 0.30))
			_world.draw_colored_polygon(poly, Color(0.40, 0.27, 0.16))
			for seg: Array in o["deck"]:
				_world.draw_line(seg[0], seg[1], Color(0.22, 0.14, 0.08), 2.5 * _k, true)
			_world.draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0.20, 0.12, 0.07), 2.0 * _k, true)
		_:
			var foam2: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in poly:
				foam2.append(c + (p - c) * 1.14)
			_world.draw_colored_polygon(foam2, Color(0.85, 0.92, 1.0, 0.32))
			var base: Color = Color(0.45, 0.43, 0.41) if str(o["kind"]) == "rock" else Color(0.38, 0.35, 0.32)
			_world.draw_colored_polygon(poly, base)
			# a lit top face, smaller and offset up-left
			var top: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in poly:
				top.append(c + (p - c) * 0.62 + Vector2(-0.12, -0.16) * float(o["r"]))
			_world.draw_colored_polygon(top, base.lightened(0.22))
			_world.draw_polyline(poly + PackedVector2Array([poly[0]]), base.darkened(0.45), 2.0 * _k, true)

# Always visible: the lighthouse's head seen from above, the boat, a crash flash.
func _draw_overlay() -> void:
	if _sea.size.x <= 0.0:
		return
	var r: float = _lh_r
	# gallery (the walkway round the lantern) with its railing
	_overlay.draw_circle(_lh_pos, r * 0.78, Color(0.20, 0.21, 0.24))
	_overlay.draw_arc(_lh_pos, r * 0.78, 0.0, TAU, 40, Color(0.55, 0.57, 0.62), 2.0 * _k, true)
	# the lantern: lit glass all round
	_overlay.draw_circle(_lh_pos, r * 0.55, Color(1.0, 0.86, 0.45))
	_overlay.draw_circle(_lh_pos, r * 0.45, Color(1.0, 0.96, 0.78))
	# the red cap and its vent
	_overlay.draw_circle(_lh_pos, r * 0.32, Color(0.75, 0.16, 0.14))
	_overlay.draw_circle(_lh_pos + Vector2(-0.07, -0.08) * r, r * 0.16, Color(0.90, 0.30, 0.26))
	_overlay.draw_circle(_lh_pos, r * 0.08, Color(0.25, 0.06, 0.05))
	# the harbor light at the jetty's end: always visible, the one thing that says where to go. It
	# flashes like a real one (see harbor_flash), and never goes fully dark.
	var hl: Vector2 = _harbor_light.position
	var fl: float = harbor_flash()
	_overlay.draw_circle(hl, (4.5 + 2.0 * fl) * _k, Color(0.4, 1.0, 0.5, 0.18 * fl))
	_overlay.draw_circle(hl, 3.0 * _k, Color(0.50, 0.95, 0.58).darkened(0.78 * (1.0 - fl)))
	_draw_boat()
	var since: float = game.game_time - _crash_t
	if since < CRASH_SEC * 1000.0:
		var t: float = since / (CRASH_SEC * 1000.0)
		_overlay.draw_arc(_crash_at, (8.0 + 30.0 * t) * _k, 0.0, TAU, 32, Color(1.0, 0.35, 0.25, 1.0 - t), 4.0 * _k, true)

# The harbor light's rhythm: OCCULTING, the "Oc G 4s" of a real harbor light -- lit most of the
# time, with a short dark break every HARBOR_PERIOD seconds (HARBOR_DARK of it). The break dips to a
# faint glow (HARBOR_DIM) rather than to black, so the goal is never lost. 1 = lit, HARBOR_DIM = the
# bottom of the break. (A short flash with long dark gaps, tried first, left it dark most of the time.)
const HARBOR_PERIOD: float = 4.0
const HARBOR_DARK: float = 1.5
const HARBOR_DIM: float = 0.06

func harbor_flash() -> float:
	var t: float = fposmod(game.game_time / 1000.0, HARBOR_PERIOD)
	var lit: float = HARBOR_PERIOD - HARBOR_DARK
	if t < lit:
		return 1.0
	var dip: float = sin(PI * (t - lit) / HARBOR_DARK)
	return 1.0 - (1.0 - HARBOR_DIM) * dip

func _draw_boat() -> void:
	var L: float = BOAT_LEN * _k
	var Wd: float = L * 0.36
	var fwd: Vector2 = Vector2.from_angle(boat_heading)
	var side: Vector2 = fwd.orthogonal()
	var p: Vector2 = boat_pos
	var hull: PackedVector2Array = PackedVector2Array([
		p + fwd * L * 0.55,
		p + fwd * L * 0.20 + side * Wd * 0.5,
		p - fwd * L * 0.45 + side * Wd * 0.42,
		p - fwd * L * 0.45 - side * Wd * 0.42,
		p + fwd * L * 0.20 - side * Wd * 0.5])
	var shadow: PackedVector2Array = PackedVector2Array()
	for q: Vector2 in hull:
		shadow.append(q + Vector2(2.0, 3.0) * _k)
	_overlay.draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	_overlay.draw_colored_polygon(hull, Color(0.93, 0.90, 0.82))
	_overlay.draw_polyline(hull + PackedVector2Array([hull[0]]), Color(0.30, 0.22, 0.15), 1.5 * _k, true)
	# the cabin, and the lamp at the bow
	var cab: PackedVector2Array = PackedVector2Array([
		p + fwd * L * 0.05 + side * Wd * 0.26, p - fwd * L * 0.22 + side * Wd * 0.26,
		p - fwd * L * 0.22 - side * Wd * 0.26, p + fwd * L * 0.05 - side * Wd * 0.26])
	_overlay.draw_colored_polygon(cab, Color(0.55, 0.36, 0.22))
	_overlay.draw_circle(p + fwd * L * 0.42, 2.5 * _k, Color(1.0, 0.95, 0.70))

# --- the boat ----------------------------------------------------------------------------------------

func _reset_boat() -> void:
	boat_pos = _start
	boat_heading = -PI * 0.5
	boat_moving = false
	route.clear()
	_route_line.points = PackedVector2Array()
	_place_boat_lamp()

func _place_boat_lamp() -> void:
	var fwd: Vector2 = Vector2.from_angle(boat_heading)
	_boat_lamp.position = boat_pos + fwd * BOAT_LEN * _k * 0.42
	_boat_lamp.rotation = boat_heading
	_boat_glow.position = _boat_lamp.position

func stop_boat() -> void:
	boat_moving = false
	route.clear()
	_route_line.points = PackedVector2Array()

# Sail toward the next point of the route, turning at most TURN_RATE; or, under the keys, as they say.
func _sail(dt: float) -> void:
	var keys_turn: float = 0.0
	var pace: float = 1.0
	if bool(_keys.get("left", false)):
		keys_turn -= 1.0
	if bool(_keys.get("right", false)):
		keys_turn += 1.0
	if bool(_keys.get("up", false)):
		if not route.is_empty():
			stop_boat()
		boat_moving = true
	if keys_turn != 0.0:
		if not route.is_empty():
			route.clear()
			_route_line.points = PackedVector2Array()
		boat_heading += keys_turn * TURN_RATE * dt
	elif not route.is_empty():
		# Look ahead: aim at the furthest route point within LOOKAHEAD, dropping the ones before it,
		# so the boat follows the line's course instead of chasing every wobble of a finger.
		var look: float = LOOKAHEAD * _k
		while route.size() > 1 and boat_pos.distance_to(route[1]) < look:
			route.pop_front()
		var target: Vector2 = route[0]
		var want: float = (target - boat_pos).angle()
		var diff: float = wrapf(want - boat_heading, -PI, PI)
		boat_heading += clampf(diff, -TURN_RATE * dt, TURN_RATE * dt)
		# Slow while turning, and turn IN PLACE when the point is more than 60 degrees off the bow. A boat that kept going while it turned sailed off the drawn line and came back round
		# to it in a loop; at full speed its tightest circle is speed / TURN_RATE across, and a point
		# inside it would be circled for ever.
		pace = clampf((cos(diff) - 0.5) * 2.0, 0.0, 1.0)     # full ahead within ~0 deg, still beyond 60
		boat_moving = true
		if boat_pos.distance_to(target) < 10.0 * _k:
			route.pop_front()
			if route.is_empty():
				boat_moving = false
	if not boat_moving:
		_place_boat_lamp()
		return
	var prev: Vector2 = boat_pos
	var next: Vector2 = boat_pos + Vector2.from_angle(boat_heading) * boat_speed * _k * pace * dt
	# the sea's edges are walls you slide along, not obstacles
	var lim: Rect2 = _sea.grow(-BOAT_R * _k)
	next = Vector2(clampf(next.x, lim.position.x, lim.end.x), clampf(next.y, lim.position.y, lim.end.y))
	boat_pos = next
	var hit: int = hit_at(boat_pos, BOAT_R * _k)
	if hit != -2:
		boat_pos = prev
		if hit == _last_crash:
			# Still beside the thing it last crashed into: it cannot sail through, but touching it
			# again is not another crash.
			stop_boat()
		else:
			_collide(hit)
	elif _last_crash != NO_CRASH and not _touches(_last_crash, boat_pos, (BOAT_R + CRASH_CLEAR) * _k):
		_last_crash = NO_CRASH        # clear of it: the next contact with it is a crash again
	_place_boat_lamp()
	_update_route_line()

# Does a boat of radius `rad` at `p` touch obstacle `which` (-1: the lighthouse rock)?
func _touches(which: int, p: Vector2, rad: float) -> bool:
	if which == -1:
		return p.distance_to(_lh_pos) < _lh_r + rad
	if which >= TRAFFIC:
		return _touches_traffic(which - TRAFFIC, p, rad)
	if which < 0 or which >= obstacles.size():
		return false
	var o: Dictionary = obstacles[which]
	var poly: PackedVector2Array = o["poly"]
	if Geometry2D.is_point_in_polygon(p, poly):
		return true
	for j in poly.size():
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[j], poly[(j + 1) % poly.size()])) < rad:
			return true
	return false

func _collide(which: int) -> void:
	var now: float = game.game_time
	stop_boat()
	if now < _invuln_until:
		return
	_last_crash = which
	_invuln_until = now + 700.0
	_crash_t = now
	_crash_at = boat_pos
	game.play_sound("crash")
	collisions_total += 1
	round_collisions[round_collisions.size() - 1] = int(round_collisions.back()) + 1
	if which >= TRAFFIC and which - TRAFFIC < traffic.size():
		if bool(traffic[which - TRAFFIC]["seen"]):
			collisions_seen += 1
	elif which >= 0 and bool(obstacles[which]["seen"]):
		collisions_seen += 1
	game.tutorial_notify("collided")
	# Each crash costs a lifebuoy; the round is lost with the LAST one -- the crash that reaches this
	# round's maximum (max_crashes_for). The HUD reaching 0 means the round is over.
	lives = maxi(0, lives - 1)
	game.lives_left = lives
	lives_changed.emit()
	if lives <= 0:
		_round_ended(false)

func _update_route_line() -> void:
	if route.is_empty():
		_route_line.points = PackedVector2Array()
		return
	var pts: PackedVector2Array = PackedVector2Array([boat_pos])
	for p: Vector2 in route:
		pts.append(p)
	_route_line.points = pts

# Which obstacles the light is on now: the beam (the angle to it within the beam's half-width at
# that distance) or the boat's light (close enough, and within its cone).
func _mark_seen() -> void:
	_mark_traffic_seen()
	_mark_obstacles_seen()

# A boat is seen the moment the beam or the boat's light is on it, the same test as a rock's.
func _mark_traffic_seen() -> void:
	for t: Dictionary in traffic:
		if bool(t["seen"]):
			continue
		if _lit_at(t["pos"], TRAFFIC_LEN * 0.5 * _k):
			t["seen"] = true

func _lit_at(c: Vector2, r: float) -> bool:
	var v: Vector2 = c - _lh_pos
	var d: float = v.length()
	var reach: float = _beam.texture_scale * float(BEAM_TEX) * 0.5
	var half: float = (0.03 + 0.47 * d / maxf(reach, 1.0)) * reach * _beam.scale.y
	var off: float = wrapf(v.angle() - beam_angle, -PI, PI)
	if absf(off) < PI * 0.5 and absf(sin(off)) * d < half * 0.8 + r:
		return true
	var vb: Vector2 = c - boat_pos
	return vb.length() < boat_light * _k * 0.85 + r \
		and absf(wrapf(vb.angle() - boat_heading, -PI, PI)) < 0.45 + atan2(r, maxf(vb.length(), 1.0))

func _mark_obstacles_seen() -> void:
	var beam_dir: float = beam_angle
	var reach_half_at: Callable = func(d: float) -> float:
		var reach: float = _beam.texture_scale * float(BEAM_TEX) * 0.5
		return (0.03 + 0.47 * d / maxf(reach, 1.0)) * reach * _beam.scale.y
	for o: Dictionary in obstacles:
		if bool(o["seen"]):
			continue
		var v: Vector2 = (o["center"] as Vector2) - _lh_pos
		var d: float = v.length()
		var lat: float = absf(sin(wrapf(v.angle() - beam_dir, -PI, PI))) * d
		var ahead: bool = absf(wrapf(v.angle() - beam_dir, -PI, PI)) < PI * 0.5
		if ahead and lat < reach_half_at.call(d) * 0.8 + float(o["r"]):
			o["seen"] = true
			continue
		var vb: Vector2 = (o["center"] as Vector2) - boat_pos
		if vb.length() < boat_light * _k * 0.85 + float(o["r"]) \
				and absf(wrapf(vb.angle() - boat_heading, -PI, PI)) < 0.45 + atan2(float(o["r"]), maxf(vb.length(), 1.0)):
			o["seen"] = true

# --- rounds --------------------------------------------------------------------------------------------

func _start_round() -> void:
	_reset_gesture()
	round_index += 1
	if round_index > 1 and not same_sea:
		_build_sea()
		_build_traffic()
		_world.queue_redraw()
	_reset_boat()
	lives = max_crashes_for(round_index)
	game.lives_left = lives
	lives_changed.emit()
	_round_t = 0.0
	_round_won = false
	_timed_out = false
	_last_crash = NO_CRASH
	round_collisions.append(0)
	_caption.text = "Round %d of %d" % [round_index, max_rounds]
	_enter(Phase.PLAY)
	game.play_sound("waves", false)

# Docked: the boat actually TOUCHES the jetty -- its bow inside it, or its hull's circle over an
# edge. A distance to a point below the landing said "docked" a boat-length short of the planks.
func touches_jetty() -> bool:
	var bow: Vector2 = boat_pos + Vector2.from_angle(boat_heading) * BOAT_LEN * _k * 0.55
	var reach: float = 1.5 * _k
	for rect: Rect2 in [_jetty_walk, _jetty_head]:
		if rect.grow(reach).has_point(bow):
			return true
		var nearest: Vector2 = Vector2(clampf(boat_pos.x, rect.position.x, rect.end.x), clampf(boat_pos.y, rect.position.y, rect.end.y))
		if nearest.distance_to(boat_pos) < BOAT_R * _k + reach:
			return true
	return false

func _round_ended(won: bool) -> void:
	if phase != Phase.PLAY:
		return
	stop_boat()
	_round_won = won
	_reset_gesture()
	round_times_ms.append(int(_round_t))
	round_solved.append(won)
	round_timed_out.append(_timed_out)
	if won:
		rounds_won += 1
		game.play_sound("dock")
		var bonus: int = maxi(0, 20 - 5 * int(round_collisions.back()))
		game.add_score_and_time(30 + bonus, 0)
		_feedback.add_theme_color_override("font_color", Color(0.3, 0.9, 0.45))
		_feedback.text = "Docked!"
	else:
		game.add_score_and_time(0, 0)
		_feedback.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
		_feedback.text = "Time's up" if _timed_out else "Too many crashes"
	_feedback.show()
	game.tutorial_notify("round_won" if won else "round_lost")
	_enter(Phase.ROUND_OVER)

func _next_round() -> void:
	_start_round()


# Passed: every round reached the jetty. How much faster the crossings got is measured and charted,
# not required.
func passed() -> bool:
	if round_solved.size() < max_rounds:
		return false
	for ok in round_solved:
		if not bool(ok):
			return false
	return true

# The crashes round `k` (1-based) can take. On a same-sea level each round after the first allows
# one fewer, never below 1: the sea has been seen. It drops after a FAILED round too -- a round lost
# to crashes showed exactly where the rocks are, and a limit tied to success would make a failure
# the way to an easier round. On a new-sea level every round is unseen water,
# so every round allows the same.
func max_crashes_for(k: int) -> int:
	if not same_sea:
		return max_crashes
	return maxi(mini(1, max_crashes), max_crashes - (maxi(1, k) - 1))

func _show_bar(frac: float, col: Color) -> void:
	_bar_fill.visible = true
	_bar_fill.size = Vector2(_bar_full_w * clampf(frac, 0.0, 1.0), _bar_h)
	_bar_fill.color = col

func _process(dt: float) -> void:
	if not _can_play():
		return
	beam_angle = wrapf(beam_angle + deg_to_rad(beam_turn_deg) * dt, -PI, PI)
	_beam.rotation = beam_angle
	match phase:
		Phase.IDLE:
			_start_round()
		Phase.PLAY:
			_round_t += dt * 1000.0
			# the round's time limit; in a tutorial it does not run
			var frac: float = 1.0 if game.tutorial_mode else 1.0 - _round_t / round_ms
			_show_bar(frac, Color(0.9, 0.3, 0.25).lerp(Color(0.3, 0.8, 0.4), clampf(frac, 0.0, 1.0)))
			_move_traffic(dt)
			_sail(dt)
			_mark_seen()
			if phase == Phase.PLAY and touches_jetty():
				_round_ended(true)
			elif phase == Phase.PLAY and not game.tutorial_mode and _round_t >= round_ms:
				_timed_out = true
				_round_ended(false)
		Phase.ROUND_OVER:
			if game.game_time - _phase_start >= FEEDBACK_SEC * 1000.0:
				_feedback.hide()
				if round_index >= max_rounds:
					_level_done(passed())
				elif game.tutorial_mode:
					_next_round()
				else:
					_awaiting_summary = true
					_enter(Phase.ROUND_CARD)
					game.show_game_popup(self, summary_title(), summary_text())
	_harbor_light.energy = 0.8 * harbor_flash()
	_overlay.queue_redraw()
	_waves_node.queue_redraw()
	_traffic_node.queue_redraw()

# --- input: draw a route, tap to go, tap the boat to stop ------------------------------------------

# THE ARROW KEYS ARE READ FROM REAL KEY PRESSES ONLY. The app turns every drag into swipe steering
# -- simulated left/right/up/stop ACTIONS (scripts/main.gd, MainGlobals.sim_action) -- unless a game
# switches on its shared path mode, as wolves and storm do. Lighthouse draws its own free route with
# that mode off, so reading the actions (Input.is_action_pressed) obeyed the steering fired by the
# very drag that was drawing the route: "up" dropped the route and sailed ahead, "left"/"right"
# wiped the line off the screen and turned the boat. Simulated actions are InputEventAction; a key
# is an InputEventKey, and only those are taken.
var _keys: Dictionary = {}

func _take_key(event: InputEventKey) -> void:
	for act in ["left", "right", "up"]:
		if event.is_action(act):
			_keys[act] = event.pressed
	if event.pressed and not event.echo and (event.is_action("down") or event.is_action("stop")):
		stop_boat()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if phase == Phase.PLAY and _can_play():
			_take_key(event)
		else:
			_keys.clear()
		return
	# A release is ALWAYS taken, whatever the phase: one that lands during a card would otherwise be
	# lost, and the next round would think the finger was still down -- drawing a route from plain
	# mouse motion, with the old line still showing.
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and (phase != Phase.PLAY or not _can_play()):
		_reset_gesture()
		return
	if phase != Phase.PLAY or not _can_play():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if _pressed:
				return            # a second press inside a gesture (another finger): the first one owns it
			if not _sea.has_point(mb.position):
				return
			# A phone sometimes reports a finger as lifted and pressed again in the middle of a drag (a
			# shaky finger, a brush of the palm). A press that comes RESUME_MS after a drawn line ended,
			# near where it ended, carries the line on instead of starting a new one.
			if not _drawn.is_empty() and Time.get_ticks_msec() - _released_ms < RESUME_MS \
					and mb.position.distance_to(_drawn.back()) < RESUME_PX * _k:
				_pressed = true
				_drawing = true
				return
			_pressed = true
			_drawing = false
			_press_at = mb.position
			_drawn = [mb.position]
		elif _pressed:
			_pressed = false
			_released_ms = Time.get_ticks_msec() if _drawing else -100000
			if _drawing:
				_take_route(_drawn)
			elif _press_at.distance_to(boat_pos) < BOAT_LEN * _k * 0.9:
				stop_boat()
				game.tutorial_notify("stopped")
			else:
				_take_route([_press_at])
			_drawing = false
	elif event is InputEventMouseMotion and _pressed:
		var mm: InputEventMouseMotion = event
		if not _drawing and mm.position.distance_to(_press_at) > TAP_SLOP:
			_drawing = true
		if _drawing and mm.position.distance_to(_drawn.back()) >= 8.0:
			_drawn.append(mm.position)
			var pts: PackedVector2Array = PackedVector2Array([boat_pos])
			for p: Vector2 in _drawn:
				pts.append(p)
			_route_line.points = pts

# The tutorial's demonstration of drawing a route: from the boat, curving up and round to the
# left of the lighthouse, in screen points.
func tutorial_demo_route() -> Array:
	var b: Vector2 = boat_pos
	var pts: Array = []
	for i in 9:
		var t: float = float(i) / 8.0
		var p: Vector2 = b + Vector2(-110.0 * _k * sin(t * PI * 0.8), -210.0 * _k * t)
		pts.append(Vector2(clampf(p.x, _sea.position.x + 10.0, _sea.end.x - 10.0), clampf(p.y, _sea.position.y + 10.0, _sea.end.y - 10.0)))
	return pts

# What a tutorial caption must not cover while it teaches the route: the demo route, the boat, and
# the stretch of sea its light falls on ahead of it.
func tutorial_demo_rect() -> Rect2:
	var r: Rect2 = tutorial_boat_rect()
	for p: Vector2 in tutorial_demo_route():
		r = r.expand(p)
	return r.grow(24.0 * _k)

func tutorial_boat_rect() -> Rect2:
	var ahead: Vector2 = boat_pos + Vector2.from_angle(boat_heading) * boat_light * _k
	return Rect2(boat_pos, Vector2.ZERO).expand(ahead).grow(BOAT_LEN * _k * 1.2)

# Forget any gesture in progress and the line it drew.
func _reset_gesture() -> void:
	_keys.clear()
	_pressed = false
	_drawing = false
	_drawn = []
	_released_ms = -100000
	if route.is_empty():
		_route_line.points = PackedVector2Array()

# A drawn route is sailed as drawn. Points inside the boat's own length are dropped, so a route
# started on the boat does not make it turn round to its own start.
func _take_route(pts: Array) -> void:
	var r: Array = []
	# A drawn line starts wherever the finger went down, often a little beside or behind the boat.
	# Sail from the point of it NEAREST the boat, never back to its first point.
	var from: int = 0
	if pts.size() > 1:
		var best: float = INF
		for i in pts.size():
			var dd: float = (pts[i] as Vector2).distance_to(boat_pos)
			if dd < best:
				best = dd
				from = i
	for i in range(from, pts.size()):
		var p: Vector2 = pts[i]
		var q: Vector2 = Vector2(clampf(p.x, _sea.position.x, _sea.end.x), clampf(p.y, _sea.position.y, _sea.end.y))
		if r.is_empty() and q.distance_to(boat_pos) < BOAT_LEN * _k * 0.6 and i < pts.size() - 1:
			continue
		r.append(q)
	if r.is_empty():
		return
	route = r
	boat_moving = true
	_update_route_line()
	game.tutorial_notify("route")

# --- the end of a level -------------------------------------------------------------------------------

func _level_done(didwin: bool) -> void:
	if game.level_is_done:
		return
	_enter(Phase.DONE)
	game.stop_sound("waves")
	if game.tutorial_mode:
		return
	game.level_is_done = true
	_bar_fill.visible = false
	_feedback.hide()
	game.sig_level_is_done.emit(didwin)
	MainGlobals.global_level_is_done(didwin)
	game.need_to_increase_level = didwin and current_level_id < LighthouseLevelConfig.max_level()
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	game.show_level_done_popup(self, "", "", current_level_id, result_text(didwin), didwin)

const ROUNDS_AS_ROWS: int = 6
const ROUNDS_PER_ROW: int = 5

func result_text(didwin: bool) -> String:
	var lines: Array = ["", ""]
	# One row per round while they fit on the card (it does not scroll); past ROUNDS_AS_ROWS, five to
	# a row, a dash for a round that did not reach the pier.
	if round_times_ms.size() <= ROUNDS_AS_ROWS:
		for k in round_times_ms.size():
			var how: String = _fmt_secs(float(round_times_ms[k]) / 1000.0) if bool(round_solved[k]) \
				else ("time ran out" if bool(round_timed_out[k]) else "too many crashes")
			if int(round_collisions[k]) > 0:
				how += ", %d crash%s" % [int(round_collisions[k]), "" if int(round_collisions[k]) == 1 else "es"]
			lines.append("Round %d: %s" % [k + 1, how])
	else:
		var n: int = round_times_ms.size()
		for start in range(0, n, ROUNDS_PER_ROW):
			var parts: Array = []
			for k in range(start, mini(start + ROUNDS_PER_ROW, n)):
				parts.append(str(int(round(float(round_times_ms[k]) / 1000.0))) if bool(round_solved[k]) else "-")
			var span: String = str(start + 1) if parts.size() == 1 else "%d-%d" % [start + 1, start + parts.size()]
			lines.append("Rounds %s (sec): %s" % [span, ", ".join(parts)])
	lines.append("Reached the jetty: %d of %d" % [rounds_won, max_rounds])
	lines.append("Total crashes: %d" % collisions_total)
	lines.append("")
	if didwin:
		if current_level_id >= LighthouseLevelConfig.max_level():
			lines.append("Level passed. This is the last level, so it comes round again.")
		else:
			lines.append("Level passed. On to level %d." % LighthouseLevelConfig.next_id(current_level_id))
	else:
		lines.append("To pass, reach the jetty in every round. Play this level again.")
	return "\n".join(lines)

func _on_level_done_popup_closed() -> void:
	sig_level_is_done.emit(true)

# The last round's crossing time, only when it reached the pier (0 otherwise).
func last_round_ms() -> int:
	if round_solved.is_empty() or not bool(round_solved.back()):
		return 0
	return int(round_times_ms.back())

func first_round_ms() -> int:
	for k in round_times_ms.size():
		if bool(round_solved[k]):
			return int(round_times_ms[k])
	return 0

func _fmt_secs(s: float) -> String:
	var t: int = int(round(s))
	if t >= 60:
		return "%d:%02d min" % [floori(t / 60.0), t % 60]
	return "%d s" % t
