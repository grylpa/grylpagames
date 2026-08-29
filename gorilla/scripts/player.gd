extends Area2D

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

var _power_pulse_tween = null

func ate_power():
	has_power = true
	time_started_power = MainGlobals.timems()
	if _power_pulse_tween == null:
		var nd = $Head
		var t := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(nd, "scale", orig_head_scale * Vector2(1.2, 1.2), 0.5)
		t.parallel().tween_property(nd, "modulate", Color(1.3, 1.9, 1.0), 0.5)
		t.tween_property(nd, "scale", orig_head_scale * Vector2(1.0, 1.0), 0.5)
		t.parallel().tween_property(nd, "modulate", orig_head_color, 0.5)
		_power_pulse_tween = t

func stop_power():
	has_power = false
	var nd = $Head
	if _power_pulse_tween != null:
		_power_pulse_tween.kill()
		_power_pulse_tween = null
	nd.scale = orig_head_scale
	nd.modulate = orig_head_color

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
	if has_power and MainGlobals.timems() - time_started_power > DURATION_TO_STOP_POWER:
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
	if _power_pulse_tween != null:
		_power_pulse_tween.pause()
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
			if _power_pulse_tween != null:
				_power_pulse_tween.play()
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
