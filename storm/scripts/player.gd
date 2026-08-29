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

var angles = []

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
	angles.append(0)
	z_index = 10
	$Head.z_index = z_index
	isready = true

func play():
	# $Head.play("PlayerHeadEyes")
	$Head.play("circular")

func reset():
	# abs_time_supposed_to_reach_target_ms = 0
	_pending_speed_scale_to_use = -1

func set_color(_color):
	color = _color
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

func set_rots():
	$Head.rotation = _head_angle if _head_angle_set else angles[0]

func distance_to_point(p):
	var d = (position - p).length()
	return d

func distance_to(a):
	var d = a.distance_to_point(position)
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
