extends Area2D

# signal remove_player(arrived:bool)
signal player_pressed(_transaction_id, _board_pos)
signal sig_is_really_moving(is_really_moving)

var board_pos: Vector2i
var direction: int
# var target_position: Vector2
var starting_position: Vector2
var time_from_start_to_target_ms:float = 0
# var abs_time_supposed_to_reach_target_ms := 0
var set_target_once := false
var arrived := false
var was_hit := false
var last_major_tick_ms := -10000
var speed_scale := 1.0
# var is_moving := false
var transaction_id := -1
var is_really_moving := false
# var need_to_stop := false
# var need_to_move := false

var nbody_parts = 0
var bodies = []
var time_back_positions = []
var back_total_len = 0
var body_dist = 34
var head_dist = 34
var tail_dist_back = body_dist
var angles = []
var body_ids = []
var body_scene: PackedScene = load("res://storm/scenes/tube_animation.tscn")

var color := Color(1,1,1,1)
var isready = false
var _pending_speed_scale_to_use := -1.0;

var path:Array[Vector2i] = []

var game:GenericGameUtil

func _ready() -> void:
	game = StormG.game
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
	if not _head_angle_set:
		# The heading it is BORN with is not a turn either.
		_head_angle = angles[0]
		_head_angle_set = true
	set_rots()
	if !isready:
		return
	position = p
			
var time_set_target_pos := MainGlobals.timems()

func set_new_speed_scale(new_scale):
	_pending_speed_scale_to_use = new_scale

var last_time_moved := MainGlobals.timems()

var time_to_turn_feet_off := 0
func _process(delta: float) -> void:
	_ease_head_angle(delta)
	$Head.rotation = _head_angle
	var v:Vector2 = Vector2.ZERO
	var target_position = game.board_to_px(board_pos)
	var dv = target_position - position
	var dt = MainGlobals.timems() - last_time_moved
	var speed = 30.0 * speed_scale / game.major_tick_time_ms / game.time_scale
	if dv.length() > 1e-3:
		v = dv / dv.length() * speed
		if !is_really_moving:
			is_really_moving = true
			sig_is_really_moving.emit(true)
	else:
		if is_really_moving:
			is_really_moving = false
			sig_is_really_moving.emit(false)
		return
	var last = position
	var newpos = position + v * dt
	if (last - newpos).length_squared() > (last - target_position).length_squared():
		newpos = target_position
	if (newpos - position).length_squared() < 1e-6:
		return
	position = newpos
	var actual_dx = position - last
	if actual_dx.length() > 0.01:
		angles[0] = last.angle_to_point(position)
	last_time_moved = MainGlobals.timems()
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
	var supposed_to_be_px = game.board_to_px(board_pos)
	if (supposed_to_be_px - position).length() < game.tile_size / 10:
		return true
	else:
		return MainGlobals.timems() - last_time_moved > 1000

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		player_pressed.emit(transaction_id, board_pos)

func _on_body_input_event() -> void:
	player_pressed.emit(transaction_id, board_pos)

func set_board_pos(q:Vector2i, board):
	var p = board_pos
	board[p.y][p.x].has_agent = false
	board[q.y][q.x].has_agent = true
	board_pos = q
	last_time_moved = MainGlobals.timems()

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
