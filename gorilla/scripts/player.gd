extends Area2D

# The ring that shows how much of the power coin is left.
#
# A separate node rather than more work on the head, because the head's OWN look is already the
# "you are powered" state and a state cue cannot double as a quantity: the breath got faster and
# that was all anyone could read from it. An arc that empties is a quantity you can glance at.
#
# Copied rather than shared: didi has the same widget as an inner class, and games in this project
# do not reach into each other's scripts.
class PowerRing extends Node2D:
	var progress: float = 1.0
	var radius: float = 22.0
	var width: float = 3.0
	# Green while there is time, amber as it goes, red at the end. The colour is a SECOND reading of
	# the same number, so the ring says "nearly out" even at a glance too short to judge its length.
	const FULL: Color = Color(0.35, 0.95, 0.40)
	const HALF: Color = Color(1.00, 0.78, 0.15)
	const LOW: Color = Color(1.00, 0.32, 0.20)

	func _draw() -> void:
		if progress <= 0.0:
			return
		# 64 segments: at this radius, magnified by the board camera, the flat on each edge is
		# hundredths of a screen unit. (Witness's direction dots were a 12-gon for exactly the
		# reason that number has to be checked against the ZOOMED size, not the authored one.)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.0, 0.0, 0.0, 0.30), width + 1.5)
		var col: Color = HALF.lerp(LOW, 1.0 - progress / 0.5) if progress < 0.5 \
			else FULL.lerp(HALF, 1.0 - (progress - 0.5) / 0.5)
		draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + progress * TAU, 64, col, width)


signal remove_player(arrived:bool)
signal player_pressed(_transaction_id, _board_pos)
signal sig_is_really_moving(is_really_moving)

var board_pos: Vector2i
var direction: int
var target_position: Vector2
var starting_position: Vector2
var time_from_start_to_target_ms:float = 0
# var abs_time_supposed_to_reach_target_ms := 0
var set_target_once := false
var arrived := false
var was_hit := false
var last_major_tick_ms := -10000
var speed_scale := 1.0
var is_moving := false
var transaction_id := -1
var reached_target_pos := true
var is_really_moving := false
var need_to_stop := false
var need_to_move := false
var show_hand:bool = false

var angles = []

var color := Color(1,1,1,1)
var isready = false
var _pending_speed_scale_to_use := -1.0;

var has_power:bool = false
var time_started_power:int = 0
var DURATION_TO_STOP_POWER:int = 5000
# The power clock STANDS STILL inside a wormhole. Entering one has to be a free move: a player who
# dives in with two seconds left has to come out with two seconds left, or they take the trip
# expecting to reach a monster on the far side and find the power gone when they get there.
# `_power_paused_at_ms` is when the clock stopped, 0 when it is running.
var _power_paused_at_ms:int = 0

var game:GenericGameUtil

var orig_head_scale:Vector2 = Vector2(1,1)
var orig_head_color:Color = Color(1,1,1,1)

func _ready() -> void:
	game = GorillaG.game
	$Head.set_modulate(color)
	$Head.rotation = PI/2
	$Head.play("HeadEyes")
	$Head.speed_scale = 0.5
	orig_head_scale = $Head.scale
	orig_head_color = $Head.modulate
	angles.append(0)
	z_index = 10
	$Head.z_index = z_index
	$Hand.z_index = z_index + 1
	if !show_hand:
		hide_hand()
	isready = true

# The powered gorilla, and HOW LONG IS LEFT of it.
#
# The head alone cannot carry this. It used to be a looping tween — a one-second breath, scale
# 1.0<->1.2 with a green tint — identical in the fifth second and the first, which said "powered"
# and never "powered for how much longer". Ramping that breath from slow to fast was the first
# attempt and it is not enough on its own: rhythm is the only thing that changes, and a rhythm is
# not a quantity. The second attempt ended the power with a 6 Hz square-wave flash of the whole
# head, which reads as a strobe and is genuinely unpleasant to look at — never do that.
#
# So the two jobs are split between two things:
#
#   the head BREATHES   a smooth sine, PULSE_HZ_START -> PULSE_HZ_END across the five seconds. This
#                       is the STATE cue: you are powered, and it is running down. Nothing about it
#                       flashes and its rate tops out well under anything strobe-like.
#   the ring EMPTIES    an arc around the gorilla draining full circle -> nothing, green -> amber ->
#                       red. This is the QUANTITY: a glance says how much is left, without counting
#                       breaths.
#
# Driven from _process off the power CLOCK rather than from a tween, for two reasons. A looping
# tween cannot change its own duration, so the ramp is not expressible in one. And tween progress
# does not stop inside a wormhole while the clock does — the old pulse froze during a warp while
# the power really was draining, so it lied at exactly the moment the player was deciding whether
# to dive in.
const PULSE_HZ_START: float = 1.0
const PULSE_HZ_END: float = 2.2
const POWER_TINT: Color = Color(1.3, 1.9, 1.0)
const POWER_SCALE: float = 1.2
# ON the head's contour, not around it: the head is a 128px frame at scale 0.25, so 32 units across
# and a radius of 16. A wider ring reads as a separate hoop the gorilla happens to be standing in;
# this one is the gorilla's own outline lighting up. Measured from the Head node rather than
# guessed — the 0.25 lives inside scenes/head_anim.tscn, not in this game's player scene.
const RING_RADIUS: float = 16.0

var _power_phase: float = 0.0
var _power_ring: PowerRing = null

func ate_power():
	has_power = true
	time_started_power = MainGlobals.timems()
	_power_paused_at_ms = 0
	_power_phase = 0.0
	if _power_ring == null:
		_power_ring = PowerRing.new()
		_power_ring.radius = RING_RADIUS
		_power_ring.width = 2.5
		# Behind the head, which is at the player's own z_index, so the ring reads as a halo around
		# it rather than a hoop drawn over its face.
		_power_ring.z_index = z_index - 1
		add_child(_power_ring)
	_power_ring.progress = 1.0
	_power_ring.scale = Vector2.ONE
	_power_ring.show()
	_power_ring.queue_redraw()

func stop_power():
	has_power = false
	_power_paused_at_ms = 0
	_power_phase = 0.0
	$Head.scale = orig_head_scale
	$Head.modulate = orig_head_color
	if _power_ring != null and is_instance_valid(_power_ring):
		_power_ring.hide()

# Milliseconds of power actually spent — wormhole time does not count.
func power_elapsed_ms() -> int:
	if not has_power:
		return 0
	var now: int = _power_paused_at_ms if _power_paused_at_ms > 0 else MainGlobals.timems()
	return now - time_started_power

func power_left_ms() -> int:
	return maxi(DURATION_TO_STOP_POWER - power_elapsed_ms(), 0) if has_power else 0

func power_left_fraction() -> float:
	if not has_power:
		return 0.0
	return clampf(float(power_left_ms()) / float(DURATION_TO_STOP_POWER), 0.0, 1.0)

func pause_power_clock() -> void:
	if has_power and _power_paused_at_ms == 0:
		_power_paused_at_ms = MainGlobals.timems()

func resume_power_clock() -> void:
	if _power_paused_at_ms > 0:
		# Push the start forward by however long the clock stood still, so everything downstream
		# keeps reading elapsed time as `now - time_started_power`.
		time_started_power += MainGlobals.timems() - _power_paused_at_ms
		_power_paused_at_ms = 0

func _update_power_look(delta: float) -> void:
	var left: float = power_left_fraction()
	if _power_ring != null and is_instance_valid(_power_ring):
		# The ring keeps ticking down through a wormhole trip — it is drawn at the player's origin
		# and the warp only scales the HEAD, so there is nothing to fight. It just stands still,
		# which is exactly what the frozen clock means.
		_power_ring.progress = left
		_power_ring.queue_redraw()
	# The head, though, belongs to the warp animation while it is shrinking to a point.
	if _power_paused_at_ms > 0:
		return
	var hz: float = lerpf(PULSE_HZ_START, PULSE_HZ_END, 1.0 - left)
	_power_phase = fmod(_power_phase + delta * hz, 1.0)
	var amount: float = 0.5 - 0.5 * cos(_power_phase * TAU)
	var swell: float = lerpf(1.0, POWER_SCALE, amount)
	$Head.scale = orig_head_scale * swell
	$Head.modulate = orig_head_color.lerp(POWER_TINT, amount)
	# The ring breathes WITH the head, by the same factor, so it stays on the contour instead of
	# the head swelling out through a ring that stands still.
	if _power_ring != null and is_instance_valid(_power_ring):
		_power_ring.scale = Vector2.ONE * swell

func play():
	# $Head.play("PlayerHeadEyes")
	$Head.play("circular")

func reset():
	reached_target_pos = true
	# abs_time_supposed_to_reach_target_ms = 0
	_pending_speed_scale_to_use = -1

func set_color(_color):
	color = _color
	$Head.set_modulate(color)
	orig_head_color = $Head.modulate

func hide_hand():
	$Hand.hide()

func look_towards_next_dir(next_dir):
	var new_rotation = next_dir * PI/2
	$Hand.rotation = new_rotation
	if show_hand:
		$Hand.show()

func set_pos(p, dir):
	hide_hand()
	direction = dir
	angles[0] = dir * PI/2
	if not _head_angle_set:
		# The heading it is BORN with is not a turn either.
		_head_angle = angles[0]
		_head_angle_set = true
	set_rots()
	if !isready:
		return
	position = p

var time_set_target_pos := MainGlobals.timems()

func set_target_pos(p):
	if reached_target_pos and _pending_speed_scale_to_use > 0:
		game.time_scale = _pending_speed_scale_to_use
		_pending_speed_scale_to_use = -1.0
	target_position = p
	starting_position = position
	time_set_target_pos = MainGlobals.timems()
	time_from_start_to_target_ms = game.major_tick_time_ms * game.time_scale * \
	 	p.distance_to(position) / GorillaG.game.tile_size
	# abs_time_supposed_to_reach_target_ms = time_set_target_pos + time_from_start_to_target_ms
	set_target_once = true
	reached_target_pos = false
	return time_from_start_to_target_ms

# func get_time_to_reach_target_sec():
# 	if is_moving and not reached_target_pos and set_target_once:
# 		var now = MainGlobals.timems()
# 		var dt = abs_time_supposed_to_reach_target_ms - now
# 		Log.dbg("dt " + str(dt))
# 		return max(0, dt) / 1000.0
# 	else:
# 		return 0

func set_new_speed_scale(new_scale):
	_pending_speed_scale_to_use = new_scale

var time_to_turn_feet_off := 0
var last_pos := Vector2.ZERO
var velocity := Vector2.ZERO
func _process(_delta: float) -> void:
	_ease_head_angle(_delta)
	$Head.rotation = _head_angle
	# Not while dying: mark_hit() is tweening the head's scale, and a pulse writing the same
	# property every frame would fight it. (A monster cannot hit a powered player — that branch of
	# _check_agent_collisions only runs unpowered — but the power outlives a kill now, so the two
	# can overlap in ways they could not before.)
	if has_power and not was_hit:
		_update_power_look(_delta)
		if power_elapsed_ms() > DURATION_TO_STOP_POWER:
			stop_power()

	velocity = (position - last_pos) / _delta
	last_pos = position
	if time_to_turn_feet_off > 0 and MainGlobals.timems() > time_to_turn_feet_off and is_really_moving:
		is_really_moving = false
		# print("is_really_moving " + str(is_really_moving))
		sig_is_really_moving.emit(false)

	if set_target_once and is_moving:
		var dv = target_position - starting_position
		var now = MainGlobals.timems()
		var dt = now - time_set_target_pos
		var should_halt = dt > time_from_start_to_target_ms / speed_scale or was_hit
		if should_halt:
			hide_hand()
			reached_target_pos = true
			if is_really_moving:
				if time_to_turn_feet_off == 0:
					time_to_turn_feet_off = MainGlobals.timems() + 100				
		else:
			time_to_turn_feet_off = 0
			if !is_really_moving:
				is_really_moving = true
				# print("is_really_moving " + str(is_really_moving))
				sig_is_really_moving.emit(true)
			var sf = dt / float(time_from_start_to_target_ms / speed_scale)
			var v = dv * sf
			var last = position
			# var speed = v.length() / _delta
			# print("speed %f" % speed)
			position = starting_position + v
			var dpos = position - target_position
			if dpos.length() < 1:
				reached_target_pos = true
			angles[0] = last.angle_to_point(position)
			set_rots()

func set_rots():
	$Head.rotation = _head_angle if _head_angle_set else angles[0]

func mark_arrived():
	arrived = true
	var tween_color = MainGlobals.make_tween()
	tween_color.tween_property(self, "rotation", 6.28*4, 1.2)
	# tween_color.tween_property(self, "modulate", Color(1.0,1.0,1.0,0.2), 0.7)
	var tween_scale = MainGlobals.make_tween()
	var oldscale = scale
	# tween_scale.tween_property(self, "scale", oldscale * 0.5, 0.6)
	tween_scale.tween_property(self, "scale", oldscale * 0.0, 1.2)
	# tween_scale.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.01), 0.8)
	tween_scale.tween_callback(func(): remove_player.emit(true))

func mark_hit():
	# set_color(Color(0,0,0))
	was_hit = true
	var node_to_shake = $Head
	var tween_color = MainGlobals.make_tween()
	# tween_color.tween_property(self, "modulate", Color(1,1,1,0.4), 0.65)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.2), 0.3)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.8), 0.3)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.2), 0.3)
	var tween_scale = MainGlobals.make_tween()
	var oldscale = node_to_shake.scale
	tween_scale.tween_property(node_to_shake, "scale", oldscale * 3.0, 0.3)
	oldscale = scale
	tween_scale.tween_property(self, "scale", oldscale * 0.0, 0.6)
	tween_scale.tween_callback(func(): remove_player.emit(false))

func distance_to_point(p):
	var d = (position - p).length()
	return d

func distance_to(a):
	var d = a.distance_to_point(position)
	return d

func set_major_tick_now():
	last_major_tick_ms = MainGlobals.timems()

func need_to_major_tick():
	var target_pos = game.board_to_px(board_pos)
	if (target_pos - position).length() < game.tile_size / 10:
		return true
	var t = MainGlobals.timems()
	return t - last_major_tick_ms >= game.major_tick_time_ms * game.time_scale / speed_scale and is_moving

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		player_pressed.emit(transaction_id, board_pos)

var warping := false
func warp_to(q:Vector2i, board):
	if warping:
		return
	warping = true
	pause_power_clock()
	var nd = $Head
	var pcell = board[board_pos.y][board_pos.x]
	var qcell = board[q.y][q.x]
	var ppipe = pcell.pipe
	var qpipe = qcell.pipe
	game.play_sound("swoosh")
	ppipe.set_warping(true, true)
	qpipe.set_warping(true, false)
	var tween_scale = MainGlobals.make_tween()
	tween_scale.tween_property(nd, "scale", orig_head_scale * 0.2, 0.8)
	tween_scale.tween_callback(func(): 
		game.play_sound("swoosh")
		set_board_pos(q, board)
		position = game.board_to_px(q)
		var tween_scale2 = MainGlobals.make_tween()
		tween_scale2.tween_property(nd, "scale", orig_head_scale, 0.8)
		tween_scale2.tween_callback(func(): 
			ppipe.set_warping(false)
			qpipe.set_warping(false)
			ppipe.deactivate_wormhole()
			qpipe.deactivate_wormhole()
			warping = false
			resume_power_clock()
		)
	)

func set_board_pos(q:Vector2i, board):
	var p = board_pos
	board[p.y][p.x].has_agent = false
	board[q.y][q.x].has_agent = true
	board_pos = q

# --- Turning ---------------------------------------------------------------------------------
#
# `angles[0]` is the LOGICAL heading, recomputed every frame from the direction of travel — and at
# a corner that direction changes between one frame and the next, so drawing the head straight off
# it made it snap round in a single frame. `_head_angle` is what the head is DRAWN at: it chases
# the logical heading at a constant rate, so a corner reads as a turn. The body segments are
# unaffected; they trail off `angles`, not off this.
#
# The rate is taxi's: a right angle in 0.12 s. Constant rather than proportional, because a
# proportional ease takes a share of the remaining angle per frame and so swallows the whole turn
# at once when a frame runs long.
const TURN_SPEED: float = PI * 0.5 / 0.12

var _head_angle: float = 0.0
var _head_angle_set: bool = false

func _ease_head_angle(delta: float) -> void:
	if not _head_angle_set:
		# The first heading of its life is not a turn — face that way, do not spin into it.
		_head_angle = angles[0]
		_head_angle_set = true
		return
	# Shortest way round, so a right turn from "up" does not unwind three quarters of a circle.
	var diff: float = wrapf(angles[0] - _head_angle, -PI, PI)
	var step: float = TURN_SPEED * delta
	if absf(diff) <= step:
		_head_angle = angles[0]
	else:
		_head_angle += signf(diff) * step
