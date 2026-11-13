extends Area2D

signal player_pressed(_transaction_id, _board_pos)
signal sig_is_really_moving(is_really_moving)

var board_pos: Vector2i
var next_dir: int = -1            # a keyboard turn waiting for the next cell (level.gd)
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

var angles = []

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
	angles.append(0)
	z_index = 10
	$Head.z_index = z_index
	isready = true
	# the dog is DRAWN (beast_art.gd: a border collie, all the animals in one style) under the head node, whose own
	# sprite -- the generic blob, tinted blue -- is made invisible
	_art = preload("res://wolves/scripts/beast_art.gd").new()
	_art.set("kind", "dog")
	$Head.self_modulate = Color(1, 1, 1, 0)
	$Head.modulate = Color(1, 1, 1, 1)
	$Head.add_child(_art)

var _art: Node2D = null

# THE ACTIVE DOG (2026-11-13), when a level has more than one: a gold CONTOUR hugging its outline -- body
# and wagging tail -- with a soft glow outside it, breathing slowly (drawn by beast_art.gd, which asks
# mark_strength()). The one the keyboard drives (level.gd set_active_dog). It fades in and out over a
# quarter second as the choice moves; with one dog there is none. (A ring on the ground was tried first.)
var active: bool = false
var _mark_a: float = 0.0
var _mark_t: float = 0.0

func mark_strength() -> float:
	if _mark_a <= 0.01:
		return 0.0
	return _mark_a * (0.75 + 0.25 * sin(_mark_t * 3.2))

func _tick_mark(delta: float) -> void:
	var want: float = 1.0 if active else 0.0
	if _mark_a == want and want == 0.0:
		return
	_mark_a = move_toward(_mark_a, want, delta * 4.0)
	_mark_t += delta

func play():
	# $Head.play("PlayerHeadEyes")
	$Head.play("circular")

func reset():
	reached_target_pos = true
	# abs_time_supposed_to_reach_target_ms = 0
	_pending_speed_scale_to_use = -1

func set_color(_color):
	color = _color
	$Head.set_modulate(color if _art == null else Color(1, 1, 1, 1))

func set_pos(p, dir):
	direction = dir
	angles[0] = dir * PI/2
	$Head.rotation = angles[0]          # placed: face that way at once
	if !isready:
		return
	position = p

var time_set_target_pos := MainGlobals.timems()

func set_target_pos(p):
	if reached_target_pos and _pending_speed_scale_to_use > 0:
		game.time_scale = _pending_speed_scale_to_use
		_pending_speed_scale_to_use = -1.0
	# CHAINED STEPS (2026-11-13): a step that follows straight on from the last one starts where and WHEN
	# that one ended -- its cell's center, its end time -- so a run is one even glide. It started at the
	# moment the level got round to it, from wherever the dog then was: a pause or a jump at every cell.
	var now_ms: int = MainGlobals.timems()
	var prev_end: int = time_set_target_pos + int(time_from_start_to_target_ms / speed_scale)
	if set_target_once and now_ms >= prev_end and now_ms - prev_end < 100 and not was_hit:
		position = target_position
		time_set_target_pos = prev_end
	else:
		time_set_target_pos = now_ms
	target_position = p
	starting_position = position
	time_from_start_to_target_ms = game.major_tick_time_ms * game.time_scale * \
	 	p.distance_to(position) / WolvesG.game.tile_size
	if not barking and p.distance_to(position) > 0.5:
		angles[0] = (p - position).angle()      # face the step as it starts
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
	_tick_mark(_delta)
	# turning is smooth (see agent.gd): the head swings round to angles[0] a little each frame
	if not barking:
		$Head.rotation = lerp_angle($Head.rotation, float(angles[0]), clampf(_delta * 45.0, 0.0, 1.0))
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
			if not was_hit:
				position = target_position         # end ON the cell (it stopped a frame short of it)
			reached_target_pos = true
			# and go straight on into the next step in THIS frame, if there is one (chained from this
			# step's end, see set_target_pos): given it a frame later, the dog stopped short at every cell
			# and made the distance up in the next frame -- a hitch per cell
			var lv: Node = get_parent()
			if not was_hit and lv != null and lv.has_method("step_player_now"):
				lv.step_player_now(self)
				if not reached_target_pos:
					var span: float = float(time_from_start_to_target_ms) / speed_scale
					var sf2: float = clampf(float(MainGlobals.timems() - time_set_target_pos) / maxf(span, 1.0), 0.0, 1.0)
					position = starting_position + (target_position - starting_position) * sf2
					set_rots()
					return
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
			# var speed = v.length() / _delta
			# print("speed %f" % speed)
			position = starting_position + v
			set_rots()

func set_rots():
	pass                                # _process eases the head round to angles[0]

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
	return d

func distance_to(a):
	var d = a.distance_to_point(position)
	return d

func set_major_tick_now():
	last_major_tick_ms = MainGlobals.timems()

func need_to_major_tick():
	if reached_target_pos:
		return true
	var t = MainGlobals.timems()
	return t - last_major_tick_ms >= game.major_tick_time_ms * game.time_scale / speed_scale and is_moving

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
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
