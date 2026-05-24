extends Area2D

signal pipe_pressed(_board_pos)

var board_pos := Vector2i.ZERO
var game: GenericGameUtil
var has_brick := -1
var has_coin := -1
var show_middle_road_path := false
var warp_to_pos: Vector2i

var bricks: Array[Sprite2D] = []
var active_brick = null
var _coin_natural_scale: Vector2 = Vector2.ONE
var _coin_more_scale: float = 1.0

var fences := [false, false, false, false]		# right,bottom,left,top
var fence_objects := [null, null, null, null]	# right,bottom,left,top

var wall_texture = preload("res://art/fence_inner_wall.png")
var power_coin_texture = preload("res://art/coin-orange-w-power.png")
var regular_coin_texture = preload("res://art/coin.png")
var worm_hole_texture = preload("res://art/black_hole.png")
var worm_anim: PackedScene = load("res://scenes/worm.tscn")
var no_entry_texture = preload("res://art/red_x.png")
# var no_entry_texture = preload("res://art/blocked_black_hole.png")

var worm_anim_object = null

@onready var floor_sprite = $PipeFloor3
@onready var coin = $PipeCoin1

func _ready() -> void:
	game = GorillaG.game
	bricks = [$PipeBrick1, $PipeBrick2, $PipeBrick3]
	_coin_natural_scale = $PipeCoin1.scale
	# for dir in 4:
	# 	show_fence(dir, true)
		
func show_fence(dir, _show:bool):
	if _show:
		if fence_objects[dir] == null:
			fence_objects[dir] = Sprite2D.new()
			fence_objects[dir].texture = wall_texture
			fence_objects[dir].rotation = dir * PI / 2		
			add_child(fence_objects[dir])
		fence_objects[dir].show()
		fences[dir] = true
	else:
		if fence_objects[dir] != null:
			fence_objects[dir].hide()
		fences[dir] = false

func can_fill():
	return has_brick < 0 and has_coin < 0

var _pulse_tween = null
var _deactivated_sprite = null

func set_coin():	
	if has_coin < 0:
		coin.hide()
	else:
		var coin_text = str(has_coin)
		if has_coin == 1000:
			coin.texture = power_coin_texture
			coin_text = ""
			_coin_more_scale = 1.5
			if _pulse_tween == null:
				var t := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				t.tween_property(coin, "scale", _coin_natural_scale * _coin_more_scale * Vector2(1.2, 1.2), 0.5)
				t.parallel().tween_property(coin, "modulate", Color(1.4, 1.4, 1.4), 0.5)
				t.tween_property(coin, "scale", _coin_natural_scale * _coin_more_scale * Vector2(1.0, 1.0), 0.5)
				t.parallel().tween_property(coin, "modulate", Color(1, 1, 1), 0.5)
				_pulse_tween = t
		elif has_coin >= 2000 and has_coin < 2010:
			coin.texture = worm_hole_texture
			coin_text = ""
			_coin_more_scale = 2.3
			if worm_anim_object == null:
				var anim = worm_anim.instantiate()
				worm_anim_object = anim
				anim.z_index = 20
				var s:float = 16.0 / 248.0
				anim.scale = Vector2(s,s)
				anim.position = Vector2(0, -2)
				anim.modulate = Color("#ffbf66")
				anim.frame = has_coin % 2000
				anim.speed_scale = 1.2
				anim.play("r2l")
				add_child(anim)
			worm_anim_object.show()
			# if _pulse_tween == null:
			# 	var t := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			# 	t.tween_property(coin, "scale", _coin_natural_scale * _coin_more_scale * Vector2(1.2, 1.2), 0.5)
			# 	t.parallel().tween_property(coin, "modulate", Color(1.4, 1.4, 1.4), 0.5)
			# 	t.tween_property(coin, "scale", _coin_natural_scale * _coin_more_scale * Vector2(1.0, 1.0), 0.5)
			# 	t.parallel().tween_property(coin, "modulate", Color(1, 1, 1), 0.5)
			# 	_pulse_tween = t
		else:
			coin.texture = regular_coin_texture
			_coin_more_scale = 1.0
		coin.show()
		coin.scale = _coin_natural_scale * _coin_more_scale
		coin.modulate = Color(1,1,1,1)
		%CoinLabelShadow.text = coin_text
		%CoinLabelText.text = coin_text

var _wormhole_active := true
func deactivate_wormhole():
	_wormhole_active = false
	worm_anim_object.stop()
	
	if _deactivated_sprite == null:
		_deactivated_sprite = Sprite2D.new()
		_deactivated_sprite.texture = no_entry_texture
		# _deactivated_sprite.modulate = Color("#ffbf66")
		var s = 20.0 / 256.0
		_deactivated_sprite.scale = Vector2(s,s)
		add_child(_deactivated_sprite)
		_deactivated_sprite.z_index = 9
	_deactivated_sprite.show()
	coin.modulate = Color(1, 1, 1, 0.8)
	var t = MainGlobals.make_tween()
	coin.modulate = Color(1,1,1,0.2)
	t.tween_property(coin, "modulate", Color(1, 1, 1, 1), 5)
	t.tween_callback(func(): 
		_wormhole_active = true
		_deactivated_sprite.hide()
		worm_anim_object.play()
	)

var warping := false
var warping_tween = null
func set_warping(activate:bool, start_small:bool = false):
	if activate and warping_tween == null and !warping:
		warping = true
		var scales:Array = [1.2, 0.8]
		var i:int = 1 if start_small else 0
		var t := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(coin, "scale", _coin_natural_scale * _coin_more_scale * scales[i]  , 0.5)
		t.tween_property(coin, "scale", _coin_natural_scale * _coin_more_scale * scales[1-i], 0.5)
		warping_tween = t
	elif !activate:
		if warping_tween != null:
			warping_tween.kill()
			warping_tween = null
		coin.scale = _coin_natural_scale * _coin_more_scale
		warping = false
	
func is_wormhole_active() -> bool:
	return _wormhole_active

func is_wormhole():
	return has_coin >= 2000 and has_coin < 2010

func is_power_coin():
	return has_coin == 1000

func remove_coin():
	has_coin = -1
	coin.hide()
	coin.scale = _coin_natural_scale * _coin_more_scale
	coin.modulate = Color(1,1,1,1)
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null

func set_coin_age(ratio: float):
	if has_coin < 0:
		return
	var remaining: float = clamp(1.0 - ratio, 0.0, 1.0)
	coin.modulate.a = lerpf(0.15, 1.0, remaining)
	var s: float = lerpf(0.4, 1.0, remaining)
	$PipeCoin1.scale = _coin_natural_scale * s * _coin_more_scale

func show_dir_floor(board):
	var p = board_pos
	var r = p.x+1 < game.board_size.x and board[p.y][p.x+1].ispipe
	var d = p.y+1 < game.board_size.y and board[p.y+1][p.x].ispipe
	var l = p.x > 0 and board[p.y][p.x-1].ispipe
	var u = p.y > 0 and board[p.y-1][p.x].ispipe
	$PipeImageLR.hide()
	$PipeImage4.hide()
	$PipeImageURD.hide()
	$PipeImageRD.hide()
	if !show_middle_road_path:
		return

	$PipeImageLR.z_index = 1
	$PipeImage4.z_index = 1
	$PipeImageURD.z_index = 1
	$PipeImageRD.z_index = 1

	if d and u and r and l:
		$PipeImage4.show()
	elif d and r and l:
		$PipeImageURD.show()
		$PipeImageURD.rotation = PI/2.0
	elif d and r and u:
		$PipeImageURD.show()
		$PipeImageURD.rotation = 0
	elif u and r and l:
		$PipeImageURD.show()
		$PipeImageURD.rotation = -PI/2.0
	elif d and l and u:
		$PipeImageURD.show()
		$PipeImageURD.rotation = PI		
	elif d and u:
		$PipeImageLR.show()
		$PipeImageLR.rotation = PI/2.0
	elif r and l:
		$PipeImageLR.show()
		$PipeImageLR.rotation = 0
	elif d and r:
		$PipeImageRD.show()
		$PipeImageRD.rotation = 0
	elif d and l:
		$PipeImageRD.show()
		$PipeImageRD.rotation = PI/2.0
	elif u and l:
		$PipeImageRD.show()
		$PipeImageRD.rotation = PI
	elif u and r:
		$PipeImageRD.show()
		$PipeImageRD.rotation = -PI/2.0
	elif d or u:
		$PipeImageLR.show()
		$PipeImageLR.rotation = PI/2.0
	elif r or l:
		$PipeImageLR.show()
		$PipeImageLR.rotation = 0
	# floor_sprite.hide()

func set_rot(board):
	var p = board_pos
	set_coin()
	if board[p.y][p.x].room_id >= 0:
		if game != null and game.zoomed_in:
			floor_sprite.modulate = game.color_by_index(board[p.y][p.x].room_id).darkened(0.3)
			if has_brick >= 0 and not bricks.is_empty():
				if active_brick == null:
					seed(MainGlobals.timeus())
					active_brick = bricks[has_brick % bricks.size()]
				active_brick.show()
				active_brick.z_index = 2
		else:
			if board[p.y][p.x].color_idx >= 0:
				floor_sprite.modulate = game.color_by_index(board[p.y][p.x].color_idx)
			else:
				floor_sprite.modulate = Color.from_rgba8(65, 65, 65, 255)
			if active_brick != null:
				active_brick.hide()
		show_dir_floor(board)
		return
	else:
		$PipeFloor1.hide()
		$PipeFloor2.hide()
		$PipeFloor3.hide()
		$PipeImageNoDir.show()
		show_dir_floor(board)

	if has_brick >= 0 and !bricks.is_empty():
		if active_brick == null:
			seed(MainGlobals.timeus())
			active_brick = bricks[has_brick % bricks.size()]
			active_brick.show()
			active_brick.z_index = 2

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		pipe_pressed.emit(board_pos)
