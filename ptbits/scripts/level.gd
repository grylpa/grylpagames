extends Node2D

# Ptbits gameplay.
#
# Colored balls (RigidBody2D) fall slowly from the top. The player drags
# color-matching "tools" (AnimatableBody2D paddles) to physically push a ball
# up and over into the matching-color basket on the side. A tool only collides
# with balls of its own color — other colors pass straight through it.
#
# Color = physics layer. Bit 1 = OUTER (side walls / ceiling). Color i uses
# bit (2 + i), shared by that color's balls, tool and basket walls:
#   ball_i : layer bit(2+i); mask = OUTER | bit(2+i)
#   tool_i : layer bit(2+i); mask = 0   (detected/pushed by ball_i, ignores everything else)
#   basket_i walls / outer walls : layer only, mask = 0 (static)
# Result: ball_i collides with outer walls, its own tool and its own basket, and
# with same-color balls; it ignores every other color's tool and basket.

const COLORS: Array = [
	Color(0.93, 0.30, 0.32),  # 0 red
	Color(0.30, 0.55, 0.96),  # 1 blue
	Color(0.34, 0.79, 0.44),  # 2 green
	Color(0.97, 0.80, 0.26),  # 3 yellow
	Color(0.73, 0.44, 0.92),  # 4 purple
	Color(0.98, 0.58, 0.22),  # 5 orange
]

const LAYER_OUTER: int = 1

var game: GenericGameUtil

var current_level_id: int = 1
var num_colors: int = 2
var gravity_scale: float = 0.16
var spawn_interval: float = 3.4
var max_active: int = 1
var rounds: int = 6
var ball_radius: float = 27.0

# play rectangle (global/screen coords; Node2D sits at origin)
var play_left: float = 0.0
var play_right: float = 680.0
var play_top: float = 60.0
var play_bottom: float = 748.0

var _walls: Array = []            # static bodies (outer + basket walls)
var _tools: Array = []            # AnimatableBody2D paddles, index == color id
var _tools_layer: Node2D = null   # holds the tools so the grabbed one can be raised above the others
var _balls: Array = []            # active RigidBody2D balls
var _basket_rects: Array = []     # index == color id -> global interior Rect2 (scoring)
var _basket_polys: Array = []     # index == color id -> PackedVector2Array [TL,TR,BR,BL] (draw)
var _bumpers: Array = []          # PackedVector2Array triangles: solid mid-side deflectors (draw)
var _spawn_min_x: float = 0.0     # ball spawn x band (between the bucket columns, so no ball
var _spawn_max_x: float = 0.0     # falls straight into a bucket)

var _dragging_tool: AnimatableBody2D = null
var _drag_target: Vector2 = Vector2.ZERO
var _drag_index: int = -1          # active touch index (-1 = mouse)
# Round tools; capped low so a contact nudges the ball gently instead of
# flinging it. Combined with high ball linear_damp -> soft, non-jumpy pushes.
const TOOL_MAX_SPEED: float = 1150.0
# Hard cap on ball speed. Enforced authoritatively inside the ball's own
# _integrate_forces (see ball.gd) — clamping in _physics_process runs before the
# solver and misses the pinch impulse. Normal fall is 80-140 px/s.
const MAX_BALL_SPEED: float = 420.0
const BALL_SCRIPT: GDScript = preload("res://ptbits/scripts/ball.gd")
# A ball that comes to rest (speed < REST_SPEED) anywhere OUTSIDE a basket for
# REST_TIMEOUT_MS is counted as a miss — otherwise a ball stuck on a tool/bumper
# would never resolve and (with the current ball gating spawns) softlock the level.
const REST_SPEED: float = 26.0
const REST_TIMEOUT_MS: float = 5000.0
# tool_radius doubles on mobile (set in _ready) so a fingertip doesn't hide it.
var tool_radius: float = 27.0
# The tool has a pusher disc on top and a stem + loop handle below. The player
# grabs the LOOP, so the disc (and the ball it pushes) sits above the finger and
# stays visible. grab_offset = distance from disc center down to the loop center.
var grab_offset: float = 44.0
var loop_radius: float = 14.0

var _spawn_accum: float = 0.0
var spawned_count: int = 0
var resolved_count: int = 0

var total_rounds: int = 0
var total_corrects: int = 0
var times_to_answer: Array = []

var _phys_frozen: bool = false

var correct_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var wrong_audio = preload("res://art/sounds/swoosh.mp3")

signal sig_level_is_done(didwin: bool)
signal started_playing

func _ready() -> void:
	game = PtbitsG.game
	game.sig_time_over.connect(_on_time_over)
	game.add_sound(self, "correct", correct_audio)
	game.add_sound(self, "wrong", wrong_audio)
	if MainGlobals.is_mobile():
		tool_radius = 54.0  # twice as big so a fingertip doesn't hide it
	grab_offset = tool_radius * 2.4
	loop_radius = tool_radius * 0.46
	# tools live in their own layer (added before any balls, so balls still draw on
	# top) so the grabbed tool can be raised above the OTHER tools and stay there.
	_tools_layer = Node2D.new()
	add_child(_tools_layer)
	_recompute_play_rect()
	set_process(true)
	set_physics_process(true)

func _recompute_play_rect() -> void:
	play_left = 0.0
	play_right = float(MainGlobals.full_screen_size.x)
	play_top = float(MainGlobals.header_height) + 6.0
	play_bottom = float(MainGlobals.screen_size.y) - 4.0
	if play_right < 100.0:
		play_right = 680.0
	if play_bottom < 200.0:
		play_bottom = 748.0

# --- Level flow -------------------------------------------------------------

func new_game(_from_scratch: bool = true) -> void:
	game.level_is_done = false
	_recompute_play_rect()
	current_level_id = PtbitsG.pop_next_level_id()
	if _from_scratch:
		total_rounds = 0
		total_corrects = 0
		PtbitsG.reset_queue_from(PtbitsG.starting_level_id)
		current_level_id = PtbitsG.starting_level_id
	game.need_to_increase_level = false
	_load_level(current_level_id)
	_build_world()
	spawned_count = 0
	resolved_count = 0
	_spawn_accum = spawn_interval * 0.4  # first ball drops fairly soon
	times_to_answer.clear()
	_phys_frozen = false
	game.level_is_ready = true
	queue_redraw()
	started_playing.emit()

func _load_level(id: int) -> void:
	var def: Dictionary = PtbitsLevelConfig.get_level(id)
	num_colors = int(def.get("num_colors", 2))
	gravity_scale = float(def.get("gravity_scale", 0.16))
	spawn_interval = float(def.get("spawn_interval", 3.0))
	max_active = int(def.get("max_active", 1))
	rounds = int(def.get("rounds", 6))
	ball_radius = float(def.get("ball_radius", 25))
	if MainGlobals.is_mobile():
		ball_radius += 6.0  # a bit bigger so it's visible under a fingertip
	game.level_label_changed("Level " + str(def.get("name", id)))

func _color_bit(color_id: int) -> int:
	return 2 + color_id

func _set_layers(body: CollisionObject2D, layer_bits: Array, mask_bits: Array) -> void:
	body.collision_layer = 0
	body.collision_mask = 0
	for b in layer_bits:
		body.set_collision_layer_value(b, true)
	for b in mask_bits:
		body.set_collision_mask_value(b, true)

# --- World construction -----------------------------------------------------

func _clear_world() -> void:
	for b in _balls:
		if is_instance_valid(b):
			b.queue_free()
	_balls.clear()
	for t in _tools:
		if is_instance_valid(t):
			t.queue_free()
	_tools.clear()
	for w in _walls:
		if is_instance_valid(w):
			w.queue_free()
	_walls.clear()
	_dragging_tool = null
	_drag_index = -1

func _build_world() -> void:
	_clear_world()
	_build_outer_walls()
	_build_baskets()
	_build_tools()

func _add_static_box(rect: Rect2, layer_bit: int) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = rect.position + rect.size * 0.5
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rs: RectangleShape2D = RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	body.add_child(shape)
	_set_layers(body, [layer_bit], [])
	add_child(body)
	_walls.append(body)

func _build_outer_walls() -> void:
	var t: float = 24.0
	# left, right, ceiling. No floor -> balls that miss fall out the bottom.
	_add_static_box(Rect2(play_left - t, play_top - t, t, (play_bottom - play_top) + t * 2.0), LAYER_OUTER)
	_add_static_box(Rect2(play_right, play_top - t, t, (play_bottom - play_top) + t * 2.0), LAYER_OUTER)
	_add_static_box(Rect2(play_left - t, play_top - t, (play_right - play_left) + t * 2.0, t), LAYER_OUTER)
	# Solid triangular bumpers, high up (25% from the top): long (vertical) side on
	# the screen wall, a 45° face top and bottom meeting at an inward apex. A ball
	# falling from above slides down-and-inward off the top face; a ball pushed up
	# from below slides up-and-inward off the bottom face — either way toward center.
	# Being a solid rigid shape the whole ball radius is handled (no squeeze) and it
	# can't be forced through. These are now the main way to work a ball inward.
	_bumpers.clear()
	var cy: float = play_top + (play_bottom - play_top) * 0.25
	_add_side_bumper(true, cy, 52.0)
	_add_side_bumper(false, cy, 52.0)

func _add_side_bumper(on_left: bool, cy: float, size: float) -> void:
	var wall_x: float = play_left if on_left else play_right
	var apex_x: float = (play_left + size) if on_left else (play_right - size)
	var tri: PackedVector2Array = PackedVector2Array([
		Vector2(wall_x, cy - size),   # top, on the wall
		Vector2(apex_x, cy),          # inward apex
		Vector2(wall_x, cy + size),   # bottom, on the wall
	])
	var body: StaticBody2D = StaticBody2D.new()
	_set_layers(body, [LAYER_OUTER], [])
	var shape: CollisionShape2D = CollisionShape2D.new()
	var poly: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	poly.points = tri
	shape.shape = poly
	body.add_child(shape)
	add_child(body)
	_walls.append(body)
	_bumpers.append(tri)

func _build_baskets() -> void:
	_basket_rects.clear()
	_basket_polys.clear()
	_basket_rects.resize(num_colors)
	_basket_polys.resize(num_colors)

	# free-standing trapezoidal buckets: wide open top, narrower bottom. Sized so the
	# interior still fits a ball AFTER the thick (24px) walls (which stop the tool
	# from force-pushing a ball through the wall into the bucket).
	var top_w: float = 134.0
	var bot_w: float = 104.0
	var height: float = 96.0

	# distribute colors: even ids on left, odd ids on right, stacked downward
	var left_count: int = 0
	var right_count: int = 0
	var play_h: float = play_bottom - play_top
	var base_y: float = play_top + play_h * 0.36
	# gap between stacked buckets: account for the 24px bottom wall (the visible bucket
	# is height + 24 tall) plus a clear gap, so top/bottom buckets never touch.
	var step: float = height + 24.0 + (92.0 if MainGlobals.is_mobile() else 44.0)
	# Buckets are free-standing ISLANDS held well off the walls: the outer clearance
	# is wider than a ball, so there is no wall-adjacent ledge to trap/jitter a ball
	# pushed up along the wall (it rides the ceiling deflector back to open space
	# instead), and the tool can approach the bucket from any side.
	var clearance: float = ball_radius * 2.0 + 26.0
	var cx_left: float = play_left + clearance + top_w * 0.5
	var cx_right: float = play_right - clearance - top_w * 0.5
	# spawn balls only in the central band between the bucket columns, so a ball
	# never falls straight into (its own or any) bucket without being maneuvered.
	_spawn_min_x = cx_left + top_w * 0.5 + ball_radius + 14.0
	_spawn_max_x = cx_right - top_w * 0.5 - ball_radius - 14.0

	for i in num_colors:
		var on_left: bool = (i % 2) == 0
		var k: int = 0
		if on_left:
			k = left_count
			left_count += 1
		else:
			k = right_count
			right_count += 1
		var cx: float = cx_left if on_left else cx_right
		var top_y: float = base_y + float(k) * step
		var bottom_margin: float = 190.0 if MainGlobals.is_mobile() else 90.0
		top_y = minf(top_y, play_bottom - height - bottom_margin)
		_add_bucket(i, cx, top_y, top_w, bot_w, height)

# Symmetric free-standing trapezoid: wide open mouth on top, narrower bottom,
# two slanted sides + a bottom. Sits as an island away from the screen walls.
func _add_bucket(color_id: int, cx: float, top_y: float, top_w: float, bot_w: float, height: float) -> void:
	var color_bit: int = _color_bit(color_id)
	var wall_t: float = 24.0
	var tl: Vector2 = Vector2(cx - top_w * 0.5, top_y)
	var tr: Vector2 = Vector2(cx + top_w * 0.5, top_y)
	var bl: Vector2 = Vector2(cx - bot_w * 0.5, top_y + height)
	var br: Vector2 = Vector2(cx + bot_w * 0.5, top_y + height)

	var body: StaticBody2D = StaticBody2D.new()
	_set_layers(body, [color_bit], [])
	# bottom wall
	_add_wall_shape(body, (bl + br) * 0.5 + Vector2(0.0, wall_t * 0.5), Vector2(bot_w + wall_t, wall_t), 0.0)
	# left slanted wall
	var lseg: Vector2 = bl - tl
	_add_wall_shape(body, (tl + bl) * 0.5, Vector2(lseg.length(), wall_t), lseg.angle())
	# right slanted wall
	var rseg: Vector2 = br - tr
	_add_wall_shape(body, (tr + br) * 0.5, Vector2(rseg.length(), wall_t), rseg.angle())
	add_child(body)
	_walls.append(body)

	# Scoring zone: lower-CENTER of the bucket, inset from every wall. Combined with
	# the drop-in arming + settle checks in _process, only a ball actually dropped in
	# and resting scores.
	var iw: float = bot_w * 0.60
	_basket_rects[color_id] = Rect2(cx - iw * 0.5, top_y + height * 0.50, iw, height * 0.44)
	_basket_polys[color_id] = PackedVector2Array([tl, tr, br, bl])

func _add_wall_shape(body: StaticBody2D, center: Vector2, size: Vector2, rot: float) -> void:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rs: RectangleShape2D = RectangleShape2D.new()
	rs.size = size
	shape.shape = rs
	shape.position = center
	shape.rotation = rot
	body.add_child(shape)

func _build_tools() -> void:
	_tools.resize(num_colors)
	# rest the discs high enough that the loop below them clears the bottom bar
	var tray_y: float = play_bottom - grab_offset - loop_radius - 24.0
	var span_left: float = play_right * 0.24
	var span_right: float = play_right * 0.76
	for i in num_colors:
		var frac: float = 0.5
		if num_colors > 1:
			frac = float(i) / float(num_colors - 1)
		var tx: float = lerpf(span_left, span_right, frac)
		var tool: AnimatableBody2D = _make_tool(i)
		tool.global_position = Vector2(tx, tray_y)
		_tools_layer.add_child(tool)
		_tools[i] = tool

func _make_tool(color_id: int) -> AnimatableBody2D:
	var tool: AnimatableBody2D = AnimatableBody2D.new()
	tool.sync_to_physics = true
	_set_layers(tool, [_color_bit(color_id)], [])
	tool.set_meta("color_id", color_id)

	# Collision is ONLY the disc (origin) — the stem/loop are a visual grab handle
	# and don't push balls. The disc is round so a ball can't rest on it.
	var shape: CollisionShape2D = CollisionShape2D.new()
	var cs: CircleShape2D = CircleShape2D.new()
	cs.radius = tool_radius
	shape.shape = cs
	tool.add_child(shape)

	var col: Color = COLORS[color_id]
	# handle: a thick rounded bar between the disc (big "head") and the loop —
	# roughly an ant: big head, body, then the loop at the tail.
	var handle: Line2D = Line2D.new()
	handle.add_point(Vector2(0.0, tool_radius * 0.45))
	handle.add_point(Vector2(0.0, grab_offset - loop_radius))
	handle.width = maxf(9.0, tool_radius * 0.42)
	handle.default_color = col.darkened(0.22)
	handle.begin_cap_mode = Line2D.LINE_CAP_ROUND
	handle.end_cap_mode = Line2D.LINE_CAP_ROUND
	tool.add_child(handle)
	# loop handle (an open ring the player grabs)
	var loop: Line2D = Line2D.new()
	loop.points = _circle_points(loop_radius, 22)
	loop.closed = true
	loop.width = maxf(5.0, tool_radius * 0.22)
	loop.default_color = col.darkened(0.18)
	loop.position = Vector2(0.0, grab_offset)
	tool.add_child(loop)
	# pusher disc on top
	var body_poly: Polygon2D = Polygon2D.new()
	body_poly.polygon = _circle_points(tool_radius, 28)
	body_poly.color = col
	tool.add_child(body_poly)
	var rim: Line2D = Line2D.new()
	rim.points = _circle_points(tool_radius, 28)
	rim.closed = true
	rim.width = 3.5
	rim.default_color = col.darkened(0.4)
	rim.joint_mode = Line2D.LINE_JOINT_ROUND
	tool.add_child(rim)
	return tool

func _circle_points(r: float, n: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for s in n:
		var a: float = TAU * (float(s) / float(n))
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

# --- Balls ------------------------------------------------------------------

func _spawn_ball() -> void:
	var color_id: int = randi() % num_colors
	var ball: RigidBody2D = BALL_SCRIPT.new()
	ball.set("max_speed", MAX_BALL_SPEED)
	ball.gravity_scale = gravity_scale
	# High linear damping + zero bounce = a push nudges the ball a little and it
	# settles quickly instead of being flung. Mass up a touch so it feels weighty.
	ball.linear_damp = 3.2
	ball.angular_damp = 4.0
	ball.mass = 2.0
	ball.can_sleep = false
	# cast_shape sweeps the whole circle (not just the center ray), so a fast ball
	# can't clip through a wall corner during a pinch.
	ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	ball.set_meta("color_id", color_id)
	ball.set_meta("spawn_ms", game.game_time)

	var pmat: PhysicsMaterial = PhysicsMaterial.new()
	pmat.bounce = 0.4  # rebounds off walls when thrown at them (speed is capped)
	pmat.friction = 0.9
	ball.physics_material_override = pmat

	var shape: CollisionShape2D = CollisionShape2D.new()
	var cs: CircleShape2D = CircleShape2D.new()
	cs.radius = ball_radius
	shape.shape = cs
	ball.add_child(shape)

	var spr: Sprite2D = Sprite2D.new()
	spr.texture = PtbitsG.ball_texture()
	var tex_size: float = float(PtbitsG.ball_texture().get_width())
	var scl: float = (ball_radius * 2.0) / tex_size
	spr.scale = Vector2(scl, scl)
	spr.modulate = COLORS[color_id]
	ball.add_child(spr)

	_set_layers(ball, [_color_bit(color_id)], [LAYER_OUTER, _color_bit(color_id)])

	var min_x: float = _spawn_min_x
	var max_x: float = _spawn_max_x
	if max_x - min_x < 50.0:
		min_x = play_left + 130.0
		max_x = play_right - 130.0
	var sx: float = randf_range(min_x, max_x)
	ball.global_position = Vector2(sx, play_top + ball_radius + 4.0)

	add_child(ball)
	_balls.append(ball)
	spawned_count += 1

func _resolve_ball(ball: RigidBody2D, scored: bool) -> void:
	if not is_instance_valid(ball):
		return
	_balls.erase(ball)
	resolved_count += 1
	total_rounds += 1
	if scored:
		total_corrects += 1
		var elapsed: float = float(game.game_time) - float(ball.get_meta("spawn_ms", game.game_time))
		times_to_answer.append(maxf(elapsed, 0.0))
		while times_to_answer.size() > 20:
			times_to_answer.remove_at(0)
		var speed_bonus: int = maxi(0, 10 - int(elapsed / 1000.0))
		game.add_score_and_time(15 + speed_bonus, 0)
		game.add_correct_or_mistake(1, 0)
		game.play_sound("correct")
	else:
		var penalty: int = mini(5, game.score)
		game.add_score_and_time(-penalty, 0)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("wrong")
		_flash_miss(ball.global_position)
	MainGlobals.global_update_hud()
	ball.queue_free()

func _flash_miss(pos: Vector2) -> void:
	# a fading red ✗ so a vanished ball reads clearly as a miss
	var lbl: Label = Label.new()
	lbl.text = "✗"
	lbl.add_theme_font_size_override("font_size", 56)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.z_index = 60
	var fx: float = clampf(pos.x, play_left + 24.0, play_right - 24.0)
	var fy: float = clampf(pos.y, play_top + 24.0, play_bottom - 44.0)
	lbl.position = Vector2(fx - 18.0, fy - 32.0)
	add_child(lbl)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75)
	tw.tween_property(lbl, "position:y", lbl.position.y - 44.0, 0.75)
	tw.chain().tween_callback(lbl.queue_free)

	if resolved_count >= rounds and not game.level_is_done:
		_level_done()

# --- Frame updates ----------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_pause_freeze()
	if game.playing and not game.paused() and not game.level_is_done:
		_corral_balls()
	if _dragging_tool == null or not is_instance_valid(_dragging_tool):
		return
	if game.paused() or not game.playing:
		return
	# the finger holds the loop; the disc (tool origin) sits grab_offset above it
	var target: Vector2 = _clamp_tool_pos(_drag_target - Vector2(0.0, grab_offset))
	var to_target: Vector2 = target - _dragging_tool.global_position
	var maxstep: float = TOOL_MAX_SPEED * delta
	if to_target.length() <= maxstep:
		_dragging_tool.global_position = target
	else:
		_dragging_tool.global_position += to_target.normalized() * maxstep

func _corral_balls() -> void:
	# Hard guarantee that a ball can never leave the field sideways or through the
	# ceiling — a deep tool-vs-wall pinch can positionally teleport a ball past a
	# wall (a jump velocity clamping can't stop), so we snap it back in and kill the
	# outward velocity. The bottom is left open so a genuine miss still falls through.
	var min_x: float = play_left + ball_radius
	var max_x: float = play_right - ball_radius
	var min_y: float = play_top + ball_radius
	for b in _balls:
		if not is_instance_valid(b):
			continue
		var v: Vector2 = b.linear_velocity
		var sp: float = v.length()
		if sp > MAX_BALL_SPEED:
			v = v * (MAX_BALL_SPEED / sp)
			b.linear_velocity = v
		var p: Vector2 = b.global_position
		var nx: float = clampf(p.x, min_x, max_x)
		var ny: float = maxf(p.y, min_y)
		if nx != p.x or ny != p.y:
			b.global_position = Vector2(nx, ny)
			var vv: Vector2 = b.linear_velocity
			if nx != p.x:
				vv.x = 0.0
			if ny != p.y and vv.y < 0.0:
				vv.y = 0.0
			b.linear_velocity = vv

func _update_pause_freeze() -> void:
	var want_frozen: bool = game.paused() or not game.playing or game.level_is_done
	if want_frozen == _phys_frozen:
		return
	_phys_frozen = want_frozen
	for b in _balls:
		if is_instance_valid(b):
			b.freeze = want_frozen

func _process(delta: float) -> void:
	if not game.playing or game.level_is_done or game.paused():
		return

	# spawn
	if spawned_count < rounds and _balls.size() < max_active:
		_spawn_accum += delta
		if _spawn_accum >= spawn_interval:
			_spawn_accum = 0.0
			_spawn_ball()

	# scoring + miss detection
	var to_score: Array = []
	var to_miss: Array = []
	for ball in _balls:
		if not is_instance_valid(ball):
			continue
		var cid: int = int(ball.get_meta("color_id", 0))
		var pos: Vector2 = ball.global_position
		if pos.y > play_bottom + ball_radius * 2.0:
			to_miss.append(ball)
			continue
		var speed: float = ball.linear_velocity.length()
		var in_basket: bool = cid < _basket_rects.size() and (_basket_rects[cid] is Rect2) \
			and (_basket_rects[cid] as Rect2).has_point(pos)
		# rest-timeout: a ball stuck at rest outside a basket is eventually a miss, so
		# a stuck ball can never softlock the spawner.
		if speed < REST_SPEED and not in_basket:
			var rest: float = float(ball.get_meta("rest_ms", 0.0)) + delta * 1000.0
			ball.set_meta("rest_ms", rest)
			if rest >= REST_TIMEOUT_MS:
				to_miss.append(ball)
				continue
		else:
			ball.set_meta("rest_ms", 0.0)
		if cid >= _basket_polys.size() or not (_basket_polys[cid] is PackedVector2Array):
			continue
		var poly: PackedVector2Array = _basket_polys[cid]
		if poly.size() < 4:
			continue
		# "armed" = the ball has been above the bucket MOUTH, i.e. it came over the
		# rim from above. Only then can it score — being pushed up through the zone
		# from below never arms it.
		if pos.y <= poly[0].y and pos.x >= poly[0].x and pos.x <= poly[1].x:
			ball.set_meta("armed", true)
		if not bool(ball.get_meta("armed", false)):
			continue
		if not in_basket:
			continue
		# it must have come to REST at the bottom (not still falling / bouncing), so
		# the ball visibly settles in the bucket rather than vanishing mid-drop.
		if speed < 40.0:
			to_score.append(ball)
	for ball in to_score:
		_resolve_ball(ball, true)
	for ball in to_miss:
		_resolve_ball(ball, false)

func _clamp_tool_pos(p: Vector2) -> Vector2:
	# p is the disc center: keep the disc top and the loop bottom inside the field
	var m: float = tool_radius + 4.0
	return Vector2(
		clampf(p.x, play_left + m, play_right - m),
		clampf(p.y, play_top + tool_radius + 4.0, play_bottom - grab_offset - loop_radius - 4.0)
	)

# --- Input (drag a tool) ----------------------------------------------------

func _grab_at(pos: Vector2) -> AnimatableBody2D:
	var best: AnimatableBody2D = null
	var best_d: float = 1e9
	for t in _tools:
		if not is_instance_valid(t):
			continue
		# grab by the loop handle below the disc (so the finger stays off the disc/ball)
		var loop_c: Vector2 = t.global_position + Vector2(0.0, grab_offset)
		var dist: float = (pos - loop_c).length()
		if dist <= loop_radius + 34.0 and dist < best_d:
			best_d = dist
			best = t
	return best

func _bring_tool_to_front(t: AnimatableBody2D) -> void:
	# raise the grabbed tool above the other tools; it stays there after it's dropped
	if _tools_layer != null and is_instance_valid(t) and t.get_parent() == _tools_layer:
		_tools_layer.move_child(t, _tools_layer.get_child_count() - 1)

func _input(event: InputEvent) -> void:
	if not game.playing or game.level_is_done or game.paused():
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _dragging_tool == null:
				var t: AnimatableBody2D = _grab_at(event.position)
				if t != null:
					_dragging_tool = t
					_drag_index = event.index
					_drag_target = event.position
					_bring_tool_to_front(t)
		elif event.index == _drag_index:
			_dragging_tool = null
			_drag_index = -1
	elif event is InputEventScreenDrag and event.index == _drag_index and _dragging_tool != null:
		_drag_target = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var tm: AnimatableBody2D = _grab_at(event.position)
			if tm != null:
				_dragging_tool = tm
				_drag_index = -1
				_drag_target = event.position
				_bring_tool_to_front(tm)
		else:
			if _drag_index == -1:
				_dragging_tool = null
	elif event is InputEventMouseMotion and _dragging_tool != null and _drag_index == -1:
		_drag_target = event.position

# --- Draw (background + baskets) -------------------------------------------

func _draw() -> void:
	# play-area backdrop
	var area: Rect2 = Rect2(play_left, play_top, play_right - play_left, play_bottom - play_top)
	draw_rect(area, Color(0.11, 0.14, 0.20, 1.0), true)

	# solid mid-side triangular bumpers
	for tri in _bumpers:
		draw_colored_polygon(tri, Color(0.20, 0.25, 0.33, 1.0))
		draw_line(tri[0], tri[1], Color(0.40, 0.46, 0.56, 1.0), 3.0)
		draw_line(tri[1], tri[2], Color(0.40, 0.46, 0.56, 1.0), 3.0)

	for i in num_colors:
		if i >= _basket_polys.size() or not (_basket_polys[i] is PackedVector2Array):
			continue
		if (_basket_polys[i] as PackedVector2Array).size() < 4:
			continue
		_draw_basket(i)

func _draw_basket(color_id: int) -> void:
	var p: PackedVector2Array = _basket_polys[color_id]
	var tl: Vector2 = p[0]
	var tr: Vector2 = p[1]
	var br: Vector2 = p[2]
	var bl: Vector2 = p[3]
	var col: Color = COLORS[color_id]
	var hw: float = 12.0  # half of wall_t (24) — sides pushed out hw, bottom slab 2·hw tall
	var bd: Color = Color(0.11, 0.14, 0.20, 1.0)  # backdrop color, to carve the cavity

	# One clean bucket = an OUTER solid trapezoid with the INNER cavity carved out (and
	# opened at the top). Both halves are simple convex quads, so it draws cleanly and
	# the slanted sides join the bottom with no gaps. Visible ≈ collision (walls are
	# centerd on tl/tr/bl/br, ±hw), so the ball still rests flush.
	var outer: PackedVector2Array = PackedVector2Array([
		Vector2(tl.x - hw, tl.y), Vector2(tr.x + hw, tr.y),
		Vector2(br.x + hw, br.y + 2.0 * hw), Vector2(bl.x - hw, bl.y + 2.0 * hw)])
	draw_colored_polygon(outer, col)
	# carve the cavity (raised above the mouth so the top is open)
	var inner: PackedVector2Array = PackedVector2Array([
		Vector2(tl.x + hw, tl.y - 30.0), Vector2(tr.x - hw, tr.y - 30.0),
		Vector2(br.x - hw, br.y), Vector2(bl.x + hw, bl.y)])
	draw_colored_polygon(inner, bd)
	# faint color tint inside the cavity (from the mouth down)
	var tint: PackedVector2Array = PackedVector2Array([
		Vector2(tl.x + hw, tl.y), Vector2(tr.x - hw, tr.y),
		Vector2(br.x - hw, br.y), Vector2(bl.x + hw, bl.y)])
	draw_colored_polygon(tint, Color(col.r, col.g, col.b, 0.14))

# --- Level completion -------------------------------------------------------

func _level_done() -> void:
	game.level_is_done = true
	PtbitsG.record_level_result(current_level_id, pct_correct())
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
