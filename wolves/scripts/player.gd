extends Area2D

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

var nbody_parts = 0
var bodies = []
var time_back_positions = []
var back_total_len = 0
var body_dist = 34
var head_dist = 34
var tail_dist_back = body_dist
var angles = []
var body_ids = []
var body_scene: PackedScene = load("res://wolves/scenes/tube_animation.tscn")

var color := Color(1,1,1,1)
var isready = false
var _pending_speed_scale_to_use := -1.0;

var path:Array[Vector2i] = []

var game:GenericGameUtil

func _ready() -> void:
	game = WolvesG.game
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
	$Head.z_index = z_index
	$Skeleton.z_index = z_index-10
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

func play():
	# $Head.play("PlayerHeadEyes")
	$Head.play("circular")
	
func reset():
	reached_target_pos = true
	for body in bodies:
		body.queue_free()
	bodies.clear()
	# abs_time_supposed_to_reach_target_ms = 0
	_pending_speed_scale_to_use = -1

func set_color(_color):
	color = _color
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
	if reached_target_pos and _pending_speed_scale_to_use > 0:
		game.time_scale = _pending_speed_scale_to_use
		_pending_speed_scale_to_use = -1.0
	target_position = p
	starting_position = position
	time_set_target_pos = MainGlobals.timems()
	time_from_start_to_target_ms = game.major_tick_time_ms * game.time_scale * \
	 	p.distance_to(position) / WolvesG.game.tile_size
	# abs_time_supposed_to_reach_target_ms = time_set_target_pos + time_from_start_to_target_ms
	set_target_once = true
	reached_target_pos = false
	return time_from_start_to_target_ms
	
func set_new_speed_scale(new_scale):
	_pending_speed_scale_to_use = new_scale

var time_to_turn_feet_off := 0
var last_pos := Vector2.ZERO
var velocity := Vector2.ZERO
func _process(_delta: float) -> void:
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
			if !barking:
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
		
# func mark_arrived():
# 	arrived = true
# 	var tween_color = MainGlobals.make_tween()
# 	tween_color.tween_property(self, "rotation", 6.28*4, 1.2)
# 	# tween_color.tween_property(self, "modulate", Color(1.0,1.0,1.0,0.2), 0.7)
# 	var tween_scale = MainGlobals.make_tween()
# 	var oldscale = scale
# 	# tween_scale.tween_property(self, "scale", oldscale * 0.5, 0.6)
# 	tween_scale.tween_property(self, "scale", oldscale * 0.0, 1.2)
# 	# tween_scale.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.01), 0.8)
# 	tween_scale.tween_callback(func(): remove_player.emit(true))

# func mark_hit():
# 	# set_color(Color(0,0,0))
# 	was_hit = true
# 	var node_to_shake = $Head
# 	var tween_color = MainGlobals.make_tween()
# 	# tween_color.tween_property(self, "modulate", Color(1,1,1,0.4), 0.65)
# 	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.2), 0.3)
# 	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.8), 0.3)
# 	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.2), 0.3)
# 	var tween_scale = MainGlobals.make_tween()
# 	var oldscale = node_to_shake.scale
# 	tween_scale.tween_property(node_to_shake, "scale", oldscale * 3.0, 0.3)
# 	oldscale = scale
# 	tween_scale.tween_property(self, "scale", oldscale * 0.0, 0.6)
# 	tween_scale.tween_callback(func(): remove_player.emit(false))

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
	var target_pos = game.board_to_px(board_pos)
	if (target_pos - position).length() < game.tile_size / 10:
		return true
	var t = MainGlobals.timems()
	return t - last_major_tick_ms >= game.major_tick_time_ms * game.time_scale / speed_scale and is_moving

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		player_pressed.emit(transaction_id, board_pos)

func _on_body_input_event() -> void:
	player_pressed.emit(transaction_id, board_pos)

var barking := false
var barking_tween_scale = null
func bark_towards(pos_to):
	if barking:
		return
	barking = true
	var node_to_shake = $Head
	angles[0] = position.angle_to_point(pos_to)
	node_to_shake.rotation = angles[0]
	barking_tween_scale = MainGlobals.make_tween()
	var oldscale = node_to_shake.scale
	barking_tween_scale.tween_property(node_to_shake, "scale", oldscale * 1.2, 0.15)
	barking_tween_scale.tween_property(node_to_shake, "scale", oldscale * 0.7, 0.15)
	barking_tween_scale.tween_property(node_to_shake, "scale", oldscale * 1.2, 0.15)
	barking_tween_scale.tween_property(node_to_shake, "scale", oldscale * 1.0, 0.15)
	barking_tween_scale.tween_callback(
		func(): 
			barking = false
	)
