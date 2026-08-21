extends Area2D

var board_pos: Vector2i
var direction: int
var target_position: Vector2
var starting_position: Vector2
var time_from_start_to_target_ms: float = 0.0
var set_target_once: bool = false

var nbody_parts = 0
var bodies = []
var time_back_positions = []
var back_total_len = 0
var body_dist = 32
var head_dist = 28
var tail_dist_back = body_dist
var angles = []
var body_ids = [1,2,3]
var agent_textures = [
	preload("res://art/agent_body.png"),
	preload("res://art/agent_body2.png"),
	preload("res://art/agent_body3.png"),
	preload("res://art/agent_body4.png"),
	preload("res://art/agent_body5.png")
]

var color
var isready = false

func _ready() -> void:
	color = DelemfpG.game.next_color()
	$Head.set_modulate(color)
	$Head.rotation = PI/2
	$Tail.modulate = color
	$Tail.play("TailWheelsFP")
	$Head.play("HeadEyes")
	$Skeleton.modulate = color.darkened(0.7)
	$Skeleton.add_point(Vector2.ZERO)
	angles.append(0)
	angles.append(0)
	nbody_parts = body_ids.size()
	tail_dist_back = body_dist * nbody_parts + head_dist
	$Tail.hide()
	var txtidx = 0
	z_index = 10
	$Head.z_index = z_index
	$Skeleton.z_index = -10
	$Tail.z_index = z_index-nbody_parts-1
	for i in nbody_parts:
		var body = Sprite2D.new()
		if txtidx == 0:
			agent_textures.shuffle()
		txtidx = (txtidx + 1) % agent_textures.size()
		body.texture = agent_textures[txtidx]
		body.scale = Vector2(0.25,0.25)
		# body.texture = preload("res://delemfp/art/agent_body.png")
		body.modulate = color
		body.z_index = z_index-i-1
		add_child(body)
		bodies.append(body)
		body.hide()
		angles.append(0)
	isready = true

func set_pos(p, dir):
	direction = dir
	# `angles` is filled in _ready, and the level does add_child() before this — but a caller that
	# ever reversed that order would index an empty array here.
	if not _head_angle_set and angles.size() > 0:
		# The heading a truck is DISPATCHED with is not a turn. Without this the drawn angle was
		# first seeded from `angles[0]`, which is 0 (east) until the truck has actually moved — so
		# a truck that is dispatched facing DOWN (direction 1, the only direction the level uses)
		# spent its first moment pointing right, and then swung.
		angles[0] = dir * PI / 2.0
		_head_angle = angles[0]
		_head_angle_set = true
		$Head.rotation = _head_angle
	if !isready:
		return
	position = p
			
var time_set_target_pos: int = MainGlobals.timems()

func set_target_pos(p):
	target_position = p
	starting_position = position
	time_set_target_pos = MainGlobals.timems()
	# maxf: a zero-length move would divide by zero in _process (sf = dt/0), and 0 * INF is NaN —
	# which lands straight in `position` and takes the whole level's screen geometry with it.
	time_from_start_to_target_ms = maxf(1.0, DelemfpG.game.time_scale * \
		DelemfpG.game.major_tick_time_ms * p.distance_to(position) / DelemfpG.game.tile_size)
	set_target_once = true
	return time_from_start_to_target_ms
	
var last_pos: Vector2 = Vector2.ZERO
var _last_process_ms: int = MainGlobals.timems()

func _process(delta: float) -> void:
	# The truck slides between tiles on a hand-rolled interpolation, not a Tween, so nothing stops
	# it when the game pauses: it would keep gliding through a help screen, a popup or a tutorial
	# caption. Pushing the move's start time forward by the paused duration suspends it mid-tile
	# and resumes it without the jump a naive early-return would cause.
	var now_ms: int = MainGlobals.timems()
	if DelemfpG.game.paused():
		time_set_target_pos += now_ms - _last_process_ms
		_last_process_ms = now_ms
		return
	_last_process_ms = now_ms
	_ease_head_angle(delta)
	$Head.rotation = _head_angle
	if position == last_pos:
		if $Tail.is_playing():
			$Tail.stop()
	else:
		if !$Tail.is_playing():
			$Tail.play("TailWheelsFP")
	last_pos = position
	if set_target_once:
		var dv = target_position - starting_position
		# if dv.length() < 1e-3:
		# 	return
		var now = MainGlobals.timems()
		var dt = now - time_set_target_pos
		var should_halt = dt > time_from_start_to_target_ms
		if !should_halt:
			var sf = dt / float(time_from_start_to_target_ms)
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
			# var idx = find_closest_dist(tail_dist_back)
			# while $Skeleton.get_point_count() < nbody_parts+2:
			# 	$Skeleton.add_point(Vector2.ZERO)
			# if idx >= 0:
			# 	last = $Tail.position
			# 	$Tail.position = time_back_positions[idx] - position
			# 	$Skeleton.set_point_position(nbody_parts+1, $Tail.position)
			# 	$Tail.show()
			# #for i in range(nbody_parts-1,-1,-1):
			# for i in nbody_parts:
			# 	idx = find_closest_dist(i * body_dist + head_dist)
			# 	if idx >= 0:
			# 		last = bodies[i].position
			# 		bodies[i].position = time_back_positions[idx] - position
			# 		bodies[i].show()
			# 		$Skeleton.set_point_position(i+1, bodies[i].position)
			# 		angles[i+1] = $Skeleton.get_point_position(i+1).angle_to_point($Skeleton.get_point_position(i))
			# angles[-1] = $Skeleton.get_point_position(nbody_parts+1).angle_to_point($Skeleton.get_point_position(nbody_parts))
			var idx
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
			
			if bodies.size() == nbody_parts:
				idx = find_closest_dist(tail_dist_back)
				if idx >= 0:
					while $Skeleton.get_point_count() < bodies.size()+2:
						$Skeleton.add_point(Vector2.ZERO)
					last = $Tail.position
					$Tail.position = time_back_positions[idx] - position
					while $Skeleton.get_point_count() < nbody_parts+2:
						$Skeleton.add_point(Vector2.ZERO)
					$Skeleton.set_point_position(nbody_parts+1, $Tail.position)
					$Tail.show()

			if $Skeleton.get_point_count() > nbody_parts+1:
				angles[-1] = $Skeleton.get_point_position(nbody_parts+1).angle_to_point($Skeleton.get_point_position(nbody_parts))
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
	$Tail.rotation = angles[-1]
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
		$Tail.position = bodies[-1].position
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

# --- Turning ---------------------------------------------------------------------------------
#
# `angles[0]` is the LOGICAL heading, recomputed every frame from the direction of travel — and at
# a corner the direction of travel changes between one frame and the next, so drawing the head
# straight off it made the truck snap round. `_head_angle` is what the head is DRAWN at: it
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
		# First heading of this truck's life: face that way, do not spin into it.
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
