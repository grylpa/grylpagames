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
var angles = []

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
	angles.append(0)
	z_index = 10
	$Head.z_index = z_index
	isready = true
	time_created_ms = MainGlobals.timems()

func set_id(_id):
	agent_id = _id

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

func set_target_pos(p):
	target_position = p
	starting_position = position
	time_set_target_pos = MainGlobals.timems()
	time_from_start_to_target_ms = game.major_tick_time_ms
	set_target_once = true
	time_created_ms = MainGlobals.timems()

func _process(delta: float) -> void:
	_ease_head_angle(delta)
	$Head.rotation = _head_angle
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
			set_rots()

func set_rots():
	$Head.rotation = _head_angle if _head_angle_set else angles[0]

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
	return d

func distance_to(a):
	var d = a.distance_to_point(position)
	return d

func set_major_tick_now():
	last_major_tick_ms = MainGlobals.timems()

func need_to_major_tick():
	var t = MainGlobals.timems()
	return t - last_major_tick_ms >= game.major_tick_time_ms * game.time_scale / speed_scale and is_moving

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		agent_pressed.emit(transaction_id, board_pos)

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
