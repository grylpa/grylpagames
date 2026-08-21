extends Area2D

# signal hit(id)
signal remove_agent(id)
signal agent_pressed(_transaction_id, _board_pos)
signal sig_agent_started_moving(_transaction_id)

var board_pos: Vector2i
var direction: int
var target_position: Vector2
var starting_position: Vector2
var time_from_start_to_target_ms: int = 0
var set_target_once: bool = false
var arrived: bool = false
var was_hit: bool = false
var agent_type: int = 1
var agent_id: int = 0
var last_major_tick_ms: int = -10000
var speed_scale: float = 1.0
var is_moving: bool = false
var transaction_id: int = -1
var time_created_ms: int = 0

var nbody_parts = 0
var bodies = []
var time_back_positions = []
var back_total_len = 0
var body_dist = 34
var head_dist = 34
var tail_dist_back = body_dist
var angles = []
var body_ids = [1,2,3]
var body_scene: PackedScene = load("res://pneumo/scenes/tube_animation.tscn")

var color
var isready = false

var game:GenericGameUtil

func _ready() -> void:
	game = PneumoG.game
	# color = game.next_color()
	set_type(agent_type)
	$Head.set_modulate(color)
	$Head.rotation = PI/2
	$Head.play("HeadEyes")
	$Head.speed_scale = 0.5
	$Skeleton.modulate = color.darkened(0.1)
	$Skeleton.add_point(Vector2.ZERO)
	angles.append(0)
	angles.append(0)
	nbody_parts = body_ids.size()
	tail_dist_back = body_dist * nbody_parts + head_dist
	z_index = 10
	$Skeleton.z_index = z_index-10
	# var dsc = (1.0 - 0.4) / nbody_parts
	for i in nbody_parts:
		var body = body_scene.instantiate()
		var anim = body.get_node("animation")
		body.mouse_click.connect(_on_body_input_event)
		anim.play("main")
		anim.frame = (i+2)%3
		# anim.speed_scale = 1.0 - dsc * (i + 1)
		anim.speed_scale = 0.5
		body.modulate = color
		body.z_index = z_index-i-1
		add_child(body)
		bodies.append(body)
		body.hide()
		angles.append(0)
	isready = true
	time_created_ms = MainGlobals.timems()

func set_id(_id):
	agent_id = _id

func set_color(_color):
	color = _color
	$Head.set_modulate(color)
	$Skeleton.modulate = color.darkened(0.1)
	for body in bodies:
		body.modulate = color

func set_type(_agent_type):
	agent_type = _agent_type
	var coloridx = agent_type-1
	if speed_scale < 1.8:
		coloridx = 0
	elif speed_scale < 2.6:
		coloridx = 1
	else:
		coloridx = 2
	color = game.color_by_index(coloridx)
	set_color(color)
	
func set_pos(p, dir):
	direction = dir
	angles[0] = dir * PI/2
	if not _head_angle_set:
		# The heading a capsule is BORN with is not a turn — face that way at once, or it swings
		# into place in full view the moment it appears.
		_head_angle = angles[0]
		_head_angle_set = true
	set_rots()
	if !isready:
		return
	position = p
			
var time_set_target_pos = MainGlobals.timems()

# --- One arc through the door ------------------------------------------------------------------
#
# The capsule runs dead straight — horizontal or vertical, never anything else — right up to
# `TURN_RADIUS` short of the door's center, takes ONE quarter-arc through the door tile, and leaves
# straight along the new axis. The leg deliberately ENDS past the door center, at the far end of
# the arc, so the next leg is a plain axis-aligned run to the next tile center.
#
# Two earlier attempts are worth remembering, because both looked wrong in ways the numbers did
# not show at first:
#   1. Curving the WHOLE leg (control point a tile away) took the capsule off the straight run
#      entirely and set it oscillating.
#   2. Rounding each joint of the level's own three-leg turn — it used to aim at a point offset a
#      quarter tile DIAGONALLY inside the door — gave three small arcs curving alternate ways: a
#      harsh turn, a correction back, then another. The offsets are gone from level.gd now, which
#      is what makes a single arc possible.
#
# The level says a turn is coming (`turn_dir`) when it sets the target, one tick BEFORE the capsule
# reaches the door, because an arc has to begin before the corner.
# Of a tile, the arc's reach either side of the door's center. At 1.0 the turn is a single quarter
# circle from one tile center to the next, which is as wide as the geometry allows: it passes
# 0.414 tiles from the door's center (a circular arc of radius R clears the corner it rounds by
# 0.414 R), so a capsule swings around the flap rather than over it, and two capsules turning at
# the same door from opposite sides keep about 0.83 tiles between their paths.
const TURN_RADIUS_FRAC: float = 1.0

# The arc is deliberately split across the TWO legs of the turn — into the door and out of it —
# rather than crammed into one. Each leg then carries half of it and is the same length as the
# other, so the capsule holds one speed all the way round. Packed into a single leg (the first
# attempt at this) the leg into the door was 1.49 tiles and the one out of it 0.15, both given a
# tick apiece: the capsule sprinted through the turn and then crawled.
#
# A CIRCLE, not a Bezier: constant curvature is what makes the whole thing read as one movement.
# A quadratic Bezier bends hardest in its middle — the "harsh, then correcting" look — and passes
# closer to the corner (0.354 R) for the same reach.
var _arc_center: Vector2 = Vector2.ZERO
var _arc_from: Vector2 = Vector2.ZERO    # the arc's start, relative to its center
var _arc_sweep: float = 0.0              # +/- PI/2 for the whole turn; each leg takes half
var _arc_a: Vector2 = Vector2.ZERO       # where the straight run ends and the arc begins
var _arc_frac: float = 0.0               # share of THIS leg spent on the straight part
var _arc_half: int = 0                   # 0 = no arc, 1 = first half of one, 2 = second half
var _legs_done: int = 0                  # how many targets this capsule has been given

# A door sitting right at a thrower's mouth is the one place the full-tile radius is wrong: the arc
# would start at the capsule's spawn point, so it would leave the thrower already curving —
# crossing the door before it turns. On its FIRST leg a capsule therefore gets a half-tile radius,
# which buys it half a tile of straight exit and still clears the door's center by 0.2 tiles.
const FIRST_LEG_RADIUS_FRAC: float = 0.5

func set_target_pos(p, turn_dir: int = -1):
	if _arc_half == 1:
		# Second half of a turn already under way: finish the arc, then run straight at whatever
		# the level has just asked for. The capsule is standing at the arc's midpoint.
		_legs_done += 1
		_arc_half = 2
		_arc_from = position - _arc_center
		var radius: float = _arc_from.length()
		var half_len: float = absf(_arc_sweep) * 0.5 * radius
		# The straight run afterwards is measured from where the ARC ENDS, not from where the
		# capsule is standing now. Measuring it from here counted the arc's own chord as straight
		# line as well, so the capsule finished the turn half way through the leg and then stood
		# still for the rest of it.
		var arc_end: Vector2 = _arc_center + _arc_from.rotated(_arc_sweep * 0.5)
		var out_len: float = arc_end.distance_to(p)
		_arc_frac = half_len / maxf(half_len + out_len, 0.001)
		target_position = p
		starting_position = position
		time_set_target_pos = MainGlobals.timems()
		time_from_start_to_target_ms = game.major_tick_time_ms
		set_target_once = true
		time_created_ms = MainGlobals.timems()
		return
	_arc_half = 0
	_arc_frac = 0.0
	var u_in: Vector2 = (p - position).normalized()
	if turn_dir >= 0 and u_in != Vector2.ZERO:
		var u_out: Vector2 = Vector2(game.DirArray[turn_dir]).normalized()
		# A right angle and nothing else: this is the only shape a door makes.
		if u_out != Vector2.ZERO and absf(u_in.dot(u_out)) < 0.01:
			var frac: float = FIRST_LEG_RADIUS_FRAC if _legs_done == 0 else TURN_RADIUS_FRAC
			# The radius is CAPPED by the run-up actually available, not demanded of it. A capsule
			# halts a fraction short of each target — legs measure about 39.3 px against a 40 px
			# tile — so a guard that insisted on a full tile of run-up refused to plan any arc at
			# all, and those capsules went straight over the door and turned on the spot. That is
			# what a capsule bounced back off a wrong receiver did on its way back through the
			# door it came in by.
			var leg_len: float = position.distance_to(p)
			var r: float = minf(game.tile_size * frac, leg_len)
			if r >= game.tile_size * 0.2:
				_arc_a = p - u_in * r
				_arc_center = _arc_a + u_out * r
				_arc_from = _arc_a - _arc_center
				_arc_sweep = (PI * 0.5) * signf(u_in.cross(u_out))
				_arc_half = 1
				# This leg is: straight run, then the FIRST half of the arc. Time is split by
				# length so the speed does not change at the joint.
				var straight_len: float = position.distance_to(_arc_a)
				var half_len: float = r * PI * 0.25
				_arc_frac = straight_len / maxf(straight_len + half_len, 0.001)
				# It ends at the arc's midpoint; the next leg picks the arc up from there.
				p = _arc_center + _arc_from.rotated(_arc_sweep * 0.5)
	_legs_done += 1
	target_position = p
	starting_position = position
	time_set_target_pos = MainGlobals.timems()
	time_from_start_to_target_ms = game.major_tick_time_ms
	set_target_once = true
	time_created_ms = MainGlobals.timems()

# Held still by the coach for a step that is about something ELSE — the doors. Behaves exactly
# like a pause for this capsule: every clock is suspended, so nothing ages while it waits.
var tutorial_hold: bool = false
var _last_process_ms: int = MainGlobals.timems()

func _process(delta: float) -> void:
	# Both clocks in here are the WALL clock: the auto-start delay and the tile-to-tile
	# interpolation. Neither stops when the game pauses, so a capsule kept gliding through a help
	# screen, a popup or a tutorial caption. Pushing both baselines forward by the paused (or held)
	# duration suspends it exactly where it is and resumes it without a jump.
	var now_ms: int = MainGlobals.timems()
	if tutorial_hold or (game != null and game.paused()):
		var paused_for: int = now_ms - _last_process_ms
		time_created_ms += paused_for
		time_set_target_pos += paused_for
		_last_process_ms = now_ms
		return
	_last_process_ms = now_ms
	_ease_head_angle(delta)
	$Head.rotation = _head_angle
	if MainGlobals.timems() - time_created_ms > game.time_to_auto_start_moving_ms:
		is_moving = true
		sig_agent_started_moving.emit(transaction_id)
	if set_target_once and is_moving:
		var dv = target_position - starting_position
		var now = MainGlobals.timems()
		var dt = now - time_set_target_pos
		var should_halt = dt > time_from_start_to_target_ms * game.time_scale / speed_scale or was_hit
		if !should_halt:
			var sf = dt / float(time_from_start_to_target_ms * game.time_scale / speed_scale)
			var v = dv * sf
			var last = position
			if _arc_half == 1:
				if sf < _arc_frac:
					# Straight in, along the axis, up to where the arc begins.
					position = starting_position.lerp(_arc_a, sf / _arc_frac)
				else:
					# First half of the sweep, ending at the arc's midpoint.
					var t1: float = (sf - _arc_frac) / maxf(1.0 - _arc_frac, 0.001)
					position = _arc_center + _arc_from.rotated(_arc_sweep * 0.5 * t1)
			elif _arc_half == 2:
				if sf < _arc_frac:
					# Second half of the sweep, out of the turn.
					var t2: float = sf / maxf(_arc_frac, 0.001)
					position = _arc_center + _arc_from.rotated(_arc_sweep * 0.5 * t2)
				else:
					# Straight out along the new axis.
					var arc_end: Vector2 = _arc_center + _arc_from.rotated(_arc_sweep * 0.5)
					position = arc_end.lerp(target_position,
						(sf - _arc_frac) / maxf(1.0 - _arc_frac, 0.001))
			else:
				position = starting_position + v
			angles[0] = last.angle_to_point(position)
			if Vector2i(target_position) != Vector2i(starting_position):
				time_back_positions.push_back(position.round())
			if time_back_positions.size() > 1:
				back_total_len += (time_back_positions[-1] - time_back_positions[-2]).length()
			while time_back_positions.size() > 2 and back_total_len > tail_dist_back * 1.5:
				back_total_len -= (time_back_positions[1] - time_back_positions[0]).length()
				time_back_positions.pop_front()
			var idx
			#for i in range(nbody_parts-1,-1,-1):
			for i in bodies.size():
				idx = find_closest_dist(i * body_dist + head_dist)
				if idx >= 0:
					last = bodies[i].position
					bodies[i].position = time_back_positions[idx] - position
					bodies[i].show()
					while $Skeleton.get_point_count() < i+2:
						$Skeleton.add_point(Vector2.ZERO)
					$Skeleton.set_point_position(i+1, bodies[i].position)
					angles[i+1] = $Skeleton.get_point_position(i+1).angle_to_point($Skeleton.get_point_position(i))
			
			# if $Skeleton.get_point_count() > nbody_parts+1:
			# 	angles[-1] = $Skeleton.get_point_position(nbody_parts+1).angle_to_point($Skeleton.get_point_position(nbody_parts))
				
			set_rots()

func find_closest_dist(dist):
	if time_back_positions.size() == 0:
		return -1
	var idx = -1
	var sum = 0
	for i in range(time_back_positions.size()-2,-1,-1):
		sum += (time_back_positions[i] - time_back_positions[i+1]).length()
		if sum >= dist:
			idx = i
			break
	return idx
			
func set_rots():
	$Head.rotation = _head_angle if _head_angle_set else angles[0]
	for i in nbody_parts:
		bodies[i].rotation = angles[i+1]
	
func add_body(_id):
	pass
	
func remove_body_if_first(id):
	var idx = body_ids.find(id)
	return remove_body(id) if idx == 0 else false
		
var _pending_remove_ids: Dictionary = {}
func remove_body(id):
	if id in _pending_remove_ids:
		return
	_pending_remove_ids[id] = true
	var idx = body_ids.find(id)
	if idx >= 0:
		var body = bodies[idx]
		var tween_color = MainGlobals.make_tween()
		tween_color.tween_property(body, "modulate", color.darkened(0.4), 0.45)
		var tween_scale = MainGlobals.make_tween()
		var oldscale = body.scale
		tween_scale.tween_property(body, "scale", oldscale * 2, 0.2)
		tween_scale.tween_property(body, "scale", Vector2(0.0,0.0), 0.3)
		tween_scale.tween_callback(func(): final_remove_body(id))
		return true
	return false
		
func final_remove_body(id):
	var idx = body_ids.find(id)
	if idx >= 0:
		nbody_parts -= 1
		body_ids.remove_at(idx)
		var body = bodies[idx]
		for iidx in range(bodies.size()-1, idx, -1):
			bodies[iidx].position = bodies[iidx-1].position
			bodies[iidx].rotation = bodies[iidx-1].rotation
		bodies.remove_at(idx)
		if $Skeleton.get_point_count() > 0:
			$Skeleton.remove_point($Skeleton.get_point_count()-1)
		tail_dist_back = body_dist * nbody_parts + head_dist
		angles.pop_back()
		body.queue_free()		
		set_rots()
		_pending_remove_ids.erase(id)
		return true
	return false

func mark_arrived():
	arrived = true
	var tween_color = MainGlobals.make_tween()
	tween_color.tween_property(self, "modulate", Color(1.0,1.0,1.0,0.2), 0.7)
	var tween_scale = MainGlobals.make_tween()
	var oldscale = scale
	tween_scale.tween_property(self, "scale", oldscale * 0.5, 0.4)
	tween_scale.tween_property(self, "scale", oldscale * 0.1, 0.5)
	tween_scale.tween_callback(func(): remove_agent.emit(agent_id))

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
	tween_scale.tween_property(self, "scale", oldscale * 0.1, 0.6)
	tween_scale.tween_callback(func(): remove_agent.emit(agent_id))

func distance_to_point(p):
	var d = (position - p).length()
	for body in bodies:
		d = min(d, (position + body.position).distance_to(p))
	return d

func distance_to(a):
	var d = a.distance_to_point(position)
	for body in bodies:
		d = min(d, a.distance_to_point(position + body.position))
	return d

func set_major_tick_now():
	last_major_tick_ms = MainGlobals.timems()

func need_to_major_tick():
	var t = MainGlobals.timems()
	return t - last_major_tick_ms >= game.major_tick_time_ms * game.time_scale / speed_scale and is_moving

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		agent_pressed.emit(transaction_id, board_pos)

func _on_body_input_event() -> void:
	agent_pressed.emit(transaction_id, board_pos)

# --- Turning ---------------------------------------------------------------------------------
#
# `angles[0]` is the LOGICAL heading, recomputed every frame from the direction of travel — and at
# a corner the direction of travel changes between one frame and the next, so drawing the head
# straight off it made the capsule snap round. `_head_angle` is what the head is DRAWN at: it
# chases the logical heading instead of matching it, so a corner reads as a turn.
#
# Taxi does the same thing with a 0.12 s tween in `set_rot`, which works there because the heading
# only changes when the taxi is told to turn. Here it is re-derived every frame, and restarting a
# tween every frame means it never arrives — so this eases per frame instead. The body segments are
# unaffected: they trail off `angles`, not off this.
# A CONSTANT angular speed, not a proportional ease: taxi tweens its head over a fixed 0.12 s, and
# matching that here means the swing looks the same in both games and can never exceed this rate,
# however long a frame runs.
const TURN_SPEED: float = PI * 0.5 / 0.12   # a right angle in 0.12 s

var _head_angle: float = 0.0
var _head_angle_set: bool = false

func _ease_head_angle(delta: float) -> void:
	if not _head_angle_set:
		# First heading of this capsule's life: face that way, do not spin into it.
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
