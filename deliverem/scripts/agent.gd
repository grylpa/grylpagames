extends Area2D

var board_pos: Vector2i
var direction: int
var target_position: Vector2
var starting_position: Vector2
var time_from_start_to_target_ms: float = 0.0
var set_target_once: bool = false
var can_move: bool = true
var time_created: int = MainGlobals.timems()

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
	color = DeliveremG.game.next_color()
	$Head.set_modulate(color)
	$Head.rotation = PI/2
	$Tail.modulate = color
	$Tail.play("TailWheels")
	$Head.play("HeadEyes")
	$Skeleton.modulate = color.darkened(0.1)
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
		# body.texture = preload("res://deliverem/art/agent_body.png")
		body.modulate = color
		body.z_index = z_index-i-1
		add_child(body)
		bodies.append(body)
		body.hide()
		angles.append(0)
	time_created = MainGlobals.timems()
	isready = true

func set_pos(p, dir):
	direction = dir
	if !isready:
		return
	position = p
			
var time_set_target_pos: int = MainGlobals.timems()

func set_target_pos(p):
	target_position = p
	starting_position = position
	time_set_target_pos = MainGlobals.timems()
	time_from_start_to_target_ms = DeliveremG.game.major_tick_time_ms
	set_target_once = true
	
var _last_process_ms: int = MainGlobals.timems()

func _process(_delta: float) -> void:
	if !DeliveremG.game.playing or !can_move:
		return
	# The truck slides between tiles on a hand-rolled interpolation against the WALL clock, not a
	# Tween, so nothing stops it when the game pauses: it would keep gliding through a help screen,
	# a popup or a tutorial caption — straight past the dock the caption is talking about. Pushing
	# the move's start time forward by the paused duration suspends it mid-tile and resumes it
	# without the jump a naive early-return would cause.
	var now_ms: int = MainGlobals.timems()
	if DeliveremG.game.paused():
		time_set_target_pos += now_ms - _last_process_ms
		_last_process_ms = now_ms
		return
	_last_process_ms = now_ms
	if set_target_once:
		var dv = target_position - starting_position
		# if dv.length() < 1e-3:
		# 	return
		var now = MainGlobals.timems()
		var dt = now - time_set_target_pos
		var should_halt = dt > time_from_start_to_target_ms * DeliveremG.game.time_scale
		if !should_halt:
			var sf = dt / float(time_from_start_to_target_ms * DeliveremG.game.time_scale)
			var v = dv * sf
			var last = position
			position = starting_position + v
			angles[0] = last.angle_to_point(position)
			if Vector2i(target_position) != Vector2i(starting_position):
				time_back_positions.push_back(position)   # raw: rounding the trail to whole pixels
				# makes the segment lengths alternate and the followers wobble half a pixel a frame
				# Only count a segment when one was actually appended. Adding this every frame
				# inflated the running total on frames with no new sample, which over-trimmed
				# the trail from the front and made the followers lurch.
				if time_back_positions.size() > 1:
					back_total_len += (time_back_positions[-1] - time_back_positions[-2]).length()
			while time_back_positions.size() > 2 and back_total_len > tail_dist_back * 1.5:
				back_total_len -= (time_back_positions[1] - time_back_positions[0]).length()
				time_back_positions.pop_front()
			var trail_pos
			#for i in range(nbody_parts-1,-1,-1):
			for i in bodies.size():
				trail_pos = pos_back_along_trail(i * body_dist + head_dist)
				if trail_pos != null:
					last = bodies[i].position
					bodies[i].position = trail_pos - position
					bodies[i].show()
					while $Skeleton.get_point_count() < i+2:
						$Skeleton.add_point(Vector2.ZERO)
					$Skeleton.set_point_position(i+1, bodies[i].position)
					angles[i+1] = $Skeleton.get_point_position(i+1).angle_to_point($Skeleton.get_point_position(i))
			
			if bodies.size() == nbody_parts:
				trail_pos = pos_back_along_trail(tail_dist_back)
				if trail_pos != null:
					while $Skeleton.get_point_count() < bodies.size()+2:
						$Skeleton.add_point(Vector2.ZERO)
					last = $Tail.position
					$Tail.position = trail_pos - position
					while $Skeleton.get_point_count() < nbody_parts+2:
						$Skeleton.add_point(Vector2.ZERO)
					$Skeleton.set_point_position(nbody_parts+1, $Tail.position)
					$Tail.show()

			if $Skeleton.get_point_count() > nbody_parts+1:
				angles[-1] = $Skeleton.get_point_position(nbody_parts+1).angle_to_point($Skeleton.get_point_position(nbody_parts))
				
			set_rots()
		# The leg ended between two frames, so the head is parked a fraction of a tile short
		# until the board hands it the next one. Finish the tile instead of standing still:
		# it can only ever move forward, and by less than one frame of travel.
		else:
			position = target_position

# Returns the point exactly `dist` back along the recorded trail, interpolating inside the segment
# it lands in, or null when the trail is not yet that long.
#
# This used to return the index of the first recorded sample at least `dist` back, and the caller
# parked the follower on that sample. Between index steps the sample is fixed while the head drives
# on, so the follower slid backwards, then jumped a whole sample forward when the index finally
# stepped -- a sawtooth as large as the distance covered per frame.
func pos_back_along_trail(dist):
	if time_back_positions.is_empty():
		return null
	# Measure from where the head is RIGHT NOW, not from the newest recorded sample. A sample is
	# only appended when the tile target changes, so on the frames in between the newest sample is
	# stale and every follower comes out at the wrong offset, snapping back the next frame. That
	# showed up as the lead tube's gap breathing between 33.5 and 34.0 px while the head advanced
	# smoothly -- a sub-pixel jerk backwards every few frames.
	var sum: float = 0.0
	var b: Vector2 = position
	for i in range(time_back_positions.size()-1, -1, -1):
		var a: Vector2 = time_back_positions[i]
		var seg: float = (a - b).length()
		if sum + seg >= dist:
			var t: float = 0.0 if seg <= 0.0001 else (dist - sum) / seg
			return b.lerp(a, t)
		sum += seg
		b = a
	return null
			
func set_rots():
	$Head.rotation = angles[0]
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
		if body_ids.size() == 1:
			can_move = false
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
