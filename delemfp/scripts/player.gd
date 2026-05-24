extends Area2D

var board_pos

func _ready() -> void:
	rotation = PI/2
	reset()

func reset():
	board_pos = DelemfpG.game.get_player_start_pos()
	set_pos(board_pos)
	
func set_pos(board_v):
	position = DelemfpG.game.board_to_px(board_v)

func set_board_pos(bpos):
	board_pos = bpos
	set_pos(bpos)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
