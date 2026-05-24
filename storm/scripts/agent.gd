extends Area2D

# signal hit(id)
signal remove_agent(id)
signal agent_pressed(_transaction_id, _board_pos)
signal sig_agent_is_really_moving(is_really_moving)

var board_pos: Vector2i
var direction: int
var target_position: Vector2
var starting_position: Vector2
var time_from_start_to_target_ms := 0
var set_target_once := false
var arrived := false
var was_hit := false
var agent_type := 0
var agent_id := 0
var last_major_tick_ms := -10000
var speed_scale := 1.0
var is_moving := false
var transaction_id := -1
var time_created_ms := 0

var is_really_moving := false
var is_automoving_agent := false
var nbody_parts = 0
var bodies = []
var time_back_positions = []
var back_total_len = 0
var body_dist = 34
var head_dist = 34
var tail_dist_back = body_dist
var angles = []
var body_ids = [1,2,3]
var body_scene: PackedScene = load("res://storm/scenes/tube_animation.tscn")

var color = Color.WHITE
var isready = false
var game:GenericGameUtil

func _ready() -> void:
	# color = game.next_color()
	game = StormG.game
	set_type(agent_type)
	$Head.set_modulate(color)
	$Head.rotation = PI/2
	# $Head.play("HeadEyes")
	if agent_type == 0:
		$Head.play("Bomb")
	else:
		$Head.play("Enemy")
	$Head.speed_scale = 0.5
	$Skeleton.modulate = color.darkened(0.1)
	$Skeleton.add_point(Vector2.ZERO)
	angles.append(0)
	angles.append(0)
	nbody_parts = body_ids.size()
	tail_dist_back = body_dist * nbody_parts + head_dist
	z_index = 10
	$Head.z_index = z_index
	$Skeleton.z_index = z_index-10
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

# func set_color(_color):
# 	color = _color
# 	$Head.set_modulate(color)
# 	$Skeleton.modulate = color.darkened(0.1)
# 	for body in bodies:
# 		body.modulate = color

func set_type(_agent_type):
	agent_type = _agent_type

func set_color(_color_idx = -1):
	var coloridx = 0
	if _color_idx >= 0:
		coloridx = _color_idx % game.colors.size()
	else:
		if speed_scale < 1.8:
			coloridx = 0
		elif speed_scale < 2.6:
			coloridx = 1
		else:
			coloridx = 2
	color = game.color_by_index(coloridx)
	$Head.set_modulate(color)
	$Skeleton.modulate = color.darkened(0.1)
	for body in bodies:
		body.modulate = color
	
func set_pos(p, dir):
	direction = dir
	angles[0] = dir * PI/2
	set_rots()
	if !isready:
		return
	position = p
			
var time_set_target_pos := MainGlobals.timems()

func set_target_pos(p):
	target_position = p
	starting_position = position
	time_set_target_pos = MainGlobals.timems()
	time_from_start_to_target_ms = game.major_tick_time_ms
	set_target_once = true
	time_created_ms = MainGlobals.timems()
	
func _process(_delta: float) -> void:
	if MainGlobals.timems() - time_created_ms > game.time_to_auto_start_moving_ms and is_automoving_agent:
		is_moving = true
	if set_target_once and is_moving:
		var dv = target_position - starting_position
		var now = MainGlobals.timems()
		var dt = now - time_set_target_pos
		var should_halt = dt > time_from_start_to_target_ms * game.time_scale / speed_scale or was_hit
		if should_halt and is_really_moving:
			is_really_moving = false
			sig_agent_is_really_moving.emit(false)
		if !should_halt:
			if !is_really_moving:
				is_really_moving = true
				sig_agent_is_really_moving.emit(true)
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
	$Head.rotation = angles[0]
	for i in nbody_parts:
		bodies[i].rotation = angles[i+1]
	
func add_body(_id):
	pass
	
func remove_body_if_first(id):
	var idx = body_ids.find(id)
	return remove_body(id) if idx == 0 else false
		
var _pending_remove_ids := {}		
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
