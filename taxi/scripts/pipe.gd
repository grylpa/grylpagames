extends Area2D

signal pipe_pressed(_board_pos)

var board_pos := Vector2i.ZERO

# The road is asphalt (asphalt.gdshader, one material shared by every road sprite) with a concrete
# CURB wherever it meets something that is not road (_draw_curb, from the neighbors set_rot finds).
# It was flat gray squares, each with a yellow dot, straight onto the lawn.
static var _asphalt: ShaderMaterial = null
var _open: Array = [true, true, true, true]       # r, d, l, u: is there road that way
var _curb: Node2D = null

func _ready() -> void:
	if _asphalt == null:
		_asphalt = ShaderMaterial.new()
		_asphalt.shader = preload("res://taxi/scripts/asphalt.gdshader")
	for sp: Sprite2D in [$PipeImageLR, $PipeImage4, $PipeImageURD, $PipeImageRD]:
		sp.material = _asphalt
	_curb = Node2D.new()
	_curb.draw.connect(_draw_curb)
	add_child(_curb)
	move_child(_curb, $PipeImageRD.get_index() + 1)

# A curb on each side with no road beyond it: a strip of pale concrete with a lit edge, and the curb's
# shadow falling a little way onto the road.
func _draw_curb() -> void:
	var t: float = 20.0
	var cw: float = 4.0
	for i in 4:
		if _open[i]:
			continue
		var n: Vector2 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][i]
		var side: Vector2 = Vector2(-n.y, n.x)
		var a: Vector2 = n * t + side * t
		var b: Vector2 = n * t - side * t
		_curb.draw_polygon(PackedVector2Array([a - n * cw, b - n * cw, b - n * (cw + 5.0), a - n * (cw + 5.0)]),
			PackedColorArray([Color(0, 0, 0, 0.30), Color(0, 0, 0, 0.30), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)]))
		_curb.draw_colored_polygon(PackedVector2Array([a, b, b - n * cw, a - n * cw]), Color(0.66, 0.65, 0.62))
		_curb.draw_line(a - n * cw, b - n * cw, Color(0.85, 0.84, 0.80), 1.0)

func show_path(timeout_sec = 3):
	$PipePathImage.show()
	if timeout_sec > 0:
		await MainGlobals.sleep(timeout_sec)
		$PipePathImage.hide()

func show_lobby(_show: bool):
	$LobbyImage.visible = _show

func set_rot(board):
	var p = board_pos
	var r = p.x+1 < TaxiG.game.board_size.x and board[p.y][p.x+1].ispipe
	var d = p.y+1 < TaxiG.game.board_size.y and board[p.y+1][p.x].ispipe
	var l = p.x > 0 and board[p.y][p.x-1].ispipe
	var u = p.y > 0 and board[p.y-1][p.x].ispipe
	_open = [r, d, l, u]
	if _curb != null:
		_curb.queue_redraw()
	if d and u and r and l:
		$PipeImageLR.hide()
		$PipeImage4.show()
	elif d and r and l:
		$PipeImageLR.hide()
		$PipeImageURD.show()
		$PipeImageURD.rotation = PI/2.0
	elif d and r and u:
		$PipeImageLR.hide()
		$PipeImageURD.show()
		$PipeImageURD.rotation = 0
	elif u and r and l:
		$PipeImageLR.hide()
		$PipeImageURD.show()
		$PipeImageURD.rotation = -PI/2.0
	elif d and l and u:
		$PipeImageLR.hide()
		$PipeImageURD.show()
		$PipeImageURD.rotation = PI		
	elif d and u:
		$PipeImageLR.rotation = PI/2.0
	elif r and l:
		$PipeImageLR.rotation = 0
	elif d and r:
		$PipeImageLR.hide()
		$PipeImageRD.show()
		$PipeImageRD.rotation = 0
	elif d and l:
		$PipeImageLR.hide()
		$PipeImageRD.show()
		$PipeImageRD.rotation = PI/2.0
	elif u and l:
		$PipeImageLR.hide()
		$PipeImageRD.show()
		$PipeImageRD.rotation = PI
	elif u and r:
		$PipeImageLR.hide()
		$PipeImageRD.show()
		$PipeImageRD.rotation = -PI/2.0
	elif d or u:
		$PipeImageLR.rotation = PI/2.0
	elif r or l:
		$PipeImageLR.rotation = 0

func _on_input_event(_viewport:Node, event:InputEvent, _shape_idx:int) -> void:
	if event.is_action_pressed("lclick"):
		pipe_pressed.emit(board_pos)
