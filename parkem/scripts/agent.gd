extends Area2D

# signal hit(id)
signal remove_agent(id, arrived)
signal agent_pressed(_transaction_id, _board_pos)
signal sig_agent_started_moving(_transaction_id)
signal sig_agent_timeout(agent)

var life_time_ms = 10000
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
var signalled_timeout: bool = false

var path:Array[Vector2i] = []
var nbody_parts = 0
var bodies = []
var time_back_positions = []
var back_total_len = 0
var body_dist = 34
var head_dist = 34
var tail_dist_back = body_dist
var angles = []
var body_ids = [1,2,3]
var body_scene: PackedScene = load("res://parkem/scenes/tube_animation.tscn")

var color = Color(1,1,1,1)
var isready = false

var game:GenericGameUtil

func _ready() -> void:
	game = ParkemG.game
	# color = game.next_color()
	set_type(agent_type)
	$Head.set_modulate(color)
	$Head.rotation = PI/2
	$Head.play("Enemy")#("HeadEyes")
	$Head.speed_scale = 0.5
	$Skeleton.modulate = color.darkened(0.1)
	$Skeleton.add_point(Vector2.ZERO)
	angles.append(0)
	angles.append(0)
	nbody_parts = body_ids.size()
	tail_dist_back = body_dist * nbody_parts + head_dist
	z_index = 10
	$Head.z_index = z_index
	$Skeleton.z_index = -10
	# var dsc = (1.0 - 0.4) / nbody_parts
	for i in nbody_parts:
		var body = body_scene.instantiate()
		var anim = body.get_node("animation")
		body.mouse_click.connect(_on_body_input_event)
		anim.play("EnemyBody")
		anim.frame = (i+2)%3
		body.scale = Vector2(0.25,0.25)
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
	# var coloridx = agent_type-1
	# if speed_scale < 1.8:
	# 	coloridx = 0
	# elif speed_scale < 2.6:
	# 	coloridx = 1
	# else:
	# 	coloridx = 2
	# color = game.color_by_index(coloridx)
	# set_color(color)
	
func set_pos(p, dir):
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
			
var time_set_target_pos = MainGlobals.timems()

func set_target_pos(p):
	target_position = p
	starting_position = position
	time_set_target_pos = MainGlobals.timems()
	time_from_start_to_target_ms = game.major_tick_time_ms
	set_target_once = true
	# time_created_ms = MainGlobals.timems()
	
# Held still by the coach for a step that is about something ELSE — the hatches. Behaves exactly
# like a pause for this creature: every clock is suspended, so nothing ages while it waits.
var tutorial_hold: bool = false
var _last_process_ms: int = MainGlobals.timems()

func _process(delta: float) -> void:
	# EVERY clock in here is the wall clock: the give-up timer, the auto-start delay and the
	# tile-to-tile interpolation. None of them stop when the game pauses, so a creature kept
	# ticking through a help screen, a popup or a tutorial caption — and gave up and vanished
	# while the player was still reading about it, taking its parking spot and its hatch (both
	# looked up FROM the creature) off the screen with it.
	#
	# Pushing all three baselines forward by the paused duration suspends the creature exactly
	# where it is and resumes it without a jump.
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
	var now = MainGlobals.timems()
	if !signalled_timeout and now >= time_created_ms + life_time_ms:
		mark_timeout()
		signalled_timeout = true
	if !is_moving and now - time_created_ms > game.time_to_auto_start_moving_ms:
		is_moving = true
		sig_agent_started_moving.emit(transaction_id)
	if set_target_once and is_moving:
		var dv = target_position - starting_position
		var dt = now - time_set_target_pos
		var should_halt = dt > time_from_start_to_target_ms * game.time_scale / speed_scale or was_hit
		if !should_halt:
			var sf = dt / float(time_from_start_to_target_ms * game.time_scale / speed_scale)
			var v = dv * sf
			var last = position
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
	tween_scale.tween_callback(func(): remove_agent.emit(agent_id, true))

func mark_hit():
	# set_color(Color(0,0,0))
	was_hit = true
	var node_to_shake = $Head
	var tween_color = MainGlobals.make_tween()
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.2), 0.3)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.8), 0.3)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.2), 0.3)
	var tween_scale = MainGlobals.make_tween()
	var oldscale = node_to_shake.scale
	tween_scale.tween_property(node_to_shake, "scale", oldscale * 3.0, 0.3)
	oldscale = scale
	tween_scale.tween_property(self, "scale", oldscale * 0.1, 0.6)
	tween_scale.tween_callback(func(): remove_agent.emit(agent_id, false))

func mark_timeout():
	var tween_color = MainGlobals.make_tween()
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.7), 2.0)
	var tween_scale = MainGlobals.make_tween()
	var oldscale = scale
	tween_scale.tween_property(self, "scale", oldscale * 0.4, 1.5)
	tween_scale.tween_callback(end_agent_timeout)

func end_agent_timeout():
	sig_agent_timeout.emit(self)
	remove_agent.emit(agent_id, false)

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
# straight off it made it snap round in a single frame. `_head_angle` is what the head is DRAWN at:
# it chases the logical heading at a constant rate, so a corner reads as a turn. The body segments
# are unaffected; they trail off `angles`, not off this.
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
