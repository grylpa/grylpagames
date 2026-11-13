extends Area2D

# signal hit(id)
signal remove_agent(id, good_remove)
signal agent_pressed(_transaction_id, _board_pos)

@export var jitter_strength := randf_range(1.5,2.5)
@export var jitter_speed := randf_range(300.0, 600)

var noise := FastNoiseLite.new()
var t_jitter := 0.0

var board_pos: Vector2i
var direction: int
var was_removed := false
var agent_type := 0
var agent_id := 0
var last_major_tick_ms := -10000
var speed_scale := 1.0
var transaction_id := -1
var time_created_ms := 0
var angles = []

var scared:bool = false
# When this sheep first stepped outside a room, in ms. The gap from here to the player barking it
# back is the one measurement this game is really about: long quiet stretches, then how fast you
# notice. Zero means it is where it belongs.
var strayed_ms: int = 0
var trying_to_enter:bool = false
var to_sheep:bool = false

var color = Color.WHITE
var isready = false
var game:GenericGameUtil

var path:Array[Vector2i] = []

func _ready() -> void:
	# color = game.next_color()
	game = WolvesG.game
	noise.seed = randi()
	# noise.frequency = 0.01
	set_type(agent_type)
	$Head.set_modulate(color)
	$Head.rotation = PI/2
	# $Head.play("HeadEyes")
	if agent_type == 0:
		$Head.play("Sheep")
	else:
		$Head.play("Enemy")
	$Head.speed_scale = 0.5
	angles.append(0)
	z_index = 10
	$Head.z_index = z_index
	isready = true
	time_created_ms = MainGlobals.timems()

	if agent_type == 0:
		var s = $Head.scale
		$Head.scale = Vector2(s.x,s.y * 0.8)
		_dress_as("sheep")
	else:
		_dress_as_wolf()

# Sheep and wolves are DRAWN (beast_art.gd, all the animals in one style) under the head node, whose
# own sprite -- the sheep sprite, or the generic blob tinted yellow -- is made invisible.
var _art: Node2D = null

func _dress_as_wolf() -> void:
	_dress_as("wolf")

func _dress_as(what: String) -> void:
	if _art != null:
		return
	_art = preload("res://wolves/scripts/beast_art.gd").new()
	_art.set("kind", what)
	$Head.self_modulate = Color(1, 1, 1, 0)
	$Head.modulate = Color(1, 1, 1, 1)
	$Head.add_child(_art)

func set_id(_id):
	agent_id = _id

func set_type(_agent_type):
	agent_type = _agent_type

func set_color(_color):
	color = _color
	# a drawn wolf wears its own coat; the tint was only for the blob
	$Head.set_modulate(color if _art == null else Color(1, 1, 1, 1))
		
func set_color_idx(_color_idx = -1):
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
	set_color(color)	
	
func set_pos(p, dir):
	direction = dir
	angles[0] = dir * PI/2
	$Head.rotation = angles[0]          # placed: face that way at once
	if !isready:
		return
	position = p

var _speed_mul := 1.0
var last_time_moved := MainGlobals.timems()
var _carry: float = 0.0                       # px of a step left over when a cell was reached

func _process(_delta: float) -> void:
	_ease_turn(_delta)
	if agent_type == 0:
		t_jitter += _delta * jitter_speed	
		var jitter := Vector2(noise.get_noise_1d(t_jitter),noise.get_noise_1d(t_jitter + 1000.0)) * jitter_strength
		$Head.position = jitter

	if eaten:
		return

	_move(_delta)

# THE MOTION (2026-11-13): CELL TO CELL at a constant speed, one cell per step period. The level gives the
# next cell (board_pos) the frame the animal arrives (main.gd runs its tick every frame, before the
# animals), and what is left of this frame's step past the cell is carried on into the next, so a run of
# cells is one even glide. The animal faces the step's direction as it starts it (and turns fast, see
# TURN_RATE) -- never by the frame-to-frame drift. It was a chase toward the cell at 50 units per tick
# with the clock stopped while standing, and the next cell only every 50 ms: stop-go, a lurch every cell.
var _seg_to: Vector2 = Vector2.INF
var idle_cell: Vector2i = Vector2i(-9999, -9999)    # the level's retry pause for a blocked animal
var idle_until_ms: int = 0

func _move(delta: float) -> void:
	var target_position: Vector2 = game.board_to_px(board_pos)
	if target_position != _seg_to:
		_seg_to = target_position
		var step_v: Vector2 = target_position - position
		if step_v.length() > 0.5 and !eating and !eaten:
			angles[0] = step_v.angle()
	var dv: Vector2 = target_position - position
	if dv.length() < 1e-3:
		_carry = 0.0                    # standing: nothing carries over a wait
		return
	var speed: float = float(game.tile_size) * speed_scale * _speed_mul / float(game.major_tick_time_ms) / game.time_scale
	# the frame's own time (capped only against a stall): capped at 50 ms, a slow phone slowed the animals
	# and not the dog, which goes by the clock
	var step_len: float = speed * minf(delta, 0.25) * 1000.0 + _carry
	_carry = 0.0
	if step_len >= dv.length():
		_carry = minf(step_len - dv.length(), float(game.tile_size) * 0.5)
		position = target_position
		# on the cell: ask for the next one now and go on into it with what is left of this frame's step
		var lv: Node = get_parent()
		if _carry > 0.01 and not eaten and lv != null and lv.has_method("step_agent_now"):
			lv.step_agent_now(self)
			var nxt: Vector2 = game.board_to_px(board_pos)
			if nxt != target_position:
				_seg_to = nxt
				var dv2: Vector2 = nxt - position
				if !eating:
					angles[0] = dv2.angle()
				var go: float = minf(_carry, dv2.length())
				position += dv2.normalized() * go
				_carry = 0.0
	else:
		position += dv / dv.length() * step_len
	last_time_moved = MainGlobals.timems()     # (the level unsticks one that has not moved for 1 s)
	set_rots()

# TURNING IS QUICK: set_rots only sets where the animal faces (angles[0]); the head swings round to it
# here, a quarter turn in well under 0.1 s -- eased (it once snapped in one frame), but done as the step
# starts, not carried on through it (at 12 it was, and the animals turned while walking).
const TURN_RATE: float = 45.0

func set_rots():
	pass

func _ease_turn(delta: float) -> void:
	if eaten:
		return
	if eating:
		# the head script rests while eating: turn at its steady pace, a quarter turn in 0.1 s
		var diff: float = wrapf(float(angles[0]) - $Head.rotation, -PI, PI)
		var step: float = PI * 0.5 / 0.10 * delta
		$Head.rotation = float(angles[0]) if absf(diff) <= step else $Head.rotation + signf(diff) * step
		return
	$Head.rotation = lerp_angle($Head.rotation, float(angles[0]), clampf(delta * TURN_RATE, 0.0, 1.0))
	
var eaten := false

func mark_eaten(pos_to):
	if eaten:
		return
	eaten = true
	var node_to_shake = $Head
	angles[0] = pos_to.angle_to_point(position)
	node_to_shake.rotation = angles[0]
	var tween_color = MainGlobals.make_tween()
	tween_color.tween_property(self, "modulate", Color(1.0,0.4,0.4,1), 0.3)
	# tween_color.tween_property(self, "modulate", Color(1.0,1.0,1.0,1), 0.3)
	var tween_scale = MainGlobals.make_tween()
	var oldscale = node_to_shake.scale
	tween_scale.tween_property(node_to_shake, "scale", oldscale * 1.3, 0.2)
	tween_scale.tween_property(node_to_shake, "scale", oldscale * 0.5, 0.2)
	tween_scale.tween_property(node_to_shake, "scale", oldscale * 0.1, 0.2)

	var tween_pos = MainGlobals.make_tween()
	tween_pos.tween_property(self, "position", pos_to, 0.6)

	tween_scale.tween_callback(func(): remove_agent.emit(agent_id, false))

var eating := false
var eating_tween_scale = null
func mark_eating(pos_to):
	if eating:
		return
	eating = true
	var node_to_shake = $Head
	# TURN TO THE SHEEP FIRST (2026-11-13), and bite only once facing it. It snapped round in one frame and
	# was already biting. The shared head script (scripts/head_anim.gd), which gives every head its smooth
	# turns and rounded corners, faces a head along its recent path and would hold it facing the way it
	# came -- so it rests for the bite, and the head turns here at ITS steady pace (a quarter turn in 0.1 s,
	# never in one step); it takes over again, smoothly, when the bite is done.
	if (pos_to - position).length() > 0.5:
		angles[0] = position.angle_to_point(pos_to)
	$Head.set_process(false)
	eating_tween_scale = MainGlobals.make_tween()
	var oldscale = node_to_shake.scale
	eating_tween_scale.tween_interval(0.15)
	eating_tween_scale.tween_property(node_to_shake, "scale", oldscale * 1.2, 0.15)
	eating_tween_scale.tween_property(node_to_shake, "scale", oldscale * 0.7, 0.15)
	eating_tween_scale.tween_property(node_to_shake, "scale", oldscale * 1.2, 0.15)
	eating_tween_scale.tween_property(node_to_shake, "scale", oldscale * 1.0, 0.15)
	eating_tween_scale.tween_callback(
		func(): 
			eating = false
			$Head.set_process(true)
	)

func mark_removed():
	# set_color(Color(0,0,0))
	was_removed = true
	var node_to_shake = $Head
	var tween_color = MainGlobals.make_tween()
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.2), 0.3)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.8), 0.3)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.2), 0.3)
	var tween_scale = MainGlobals.make_tween()
	var oldscale = node_to_shake.scale
	tween_scale.tween_property(node_to_shake, "scale", oldscale * 2.0, 0.3)
	oldscale = scale
	tween_scale.tween_property(self, "scale", oldscale * 0.1, 0.6)
	tween_scale.tween_callback(func(): remove_agent.emit(agent_id, false))

var scared_tween_color = null
var _in_scared_tween = false
func mark_scared(_scared:bool = true):
	if _scared:
		if scared or _in_scared_tween:
			return
		scared = true
		if eating:
			eating = false
			if eating_tween_scale != null:
				eating_tween_scale.kill()
				eating_tween_scale = null
		_in_scared_tween = true
		var node_to_shake = $Head
		scared_tween_color = MainGlobals.make_tween()
		scared_tween_color.tween_property(self, "modulate", Color(1.0,0.7,0.7,1), 0.3)
		# scared_tween_color.tween_property(self, "modulate", Color(1.0,1.0,1.0,1), 0.3)
		var tween_scale = MainGlobals.make_tween()
		var oldscale = node_to_shake.scale
		tween_scale.tween_property(node_to_shake, "scale", oldscale * 1.3, 0.3)
		tween_scale.tween_property(node_to_shake, "scale", oldscale * 1, 0.3)
		# oldscale = scale
		# tween_scale.tween_property(self, "scale", oldscale * 0.1, 0.6)
		
		tween_scale.tween_callback(
			func():
				_in_scared_tween = false;
		)
	else:
		if scared_tween_color != null:
			scared_tween_color.kill()
			scared_tween_color = null
		scared = false
		modulate = Color(1,1,1,1)
	set_speed_mul()

func set_speed_mul():
	_speed_mul = 5.0 if scared else 1.0

func can_set_target_pos():
	if eaten:
		return false
	var supposed_to_be_px = game.board_to_px(board_pos)
	if (supposed_to_be_px - position).length() < 0.5:          # ON the cell: steps run center to center
		set_speed_mul()
		return true
	else:
		return MainGlobals.timems() - last_time_moved > 1000
		# return false

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		agent_pressed.emit(transaction_id, board_pos)
