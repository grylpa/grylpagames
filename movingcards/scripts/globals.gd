extends Node

var starting_level: int = 1
var card_move_speed: float = 200.0  # base px/s; scaled per level by speed_scale from config

var game: GenericGameUtil = GenericGameUtil.new("Moving Cards", "movingcards", 0, 5, 0)

var back_textures: Array = [
	"res://art/cards/CardBack1.png",
	"res://art/cards/CardBack2.png",
	"res://art/cards/CardBack3.png",
	"res://art/cards/CardBack4.png",
	"res://art/cards/CardBack5.png",
	"res://art/cards/CardBack6.png",
	"res://art/cards/CardBack7.png",
	"res://art/cards/CardBack8.png",
	"res://art/cards/CardBack9.png",
]

func reset() -> void:
	back_textures.shuffle()
	game.reset(false)

func init_globals() -> void:
	game.tile_size = 88
	reset()
	game.init_sizes()

func px_to_board(p: Vector2) -> Vector2i:
	return Vector2i((p - game.get_viewport_center()) / game.tile_size)

func board_to_px(p: Vector2) -> Vector2:
	return Vector2(p) * game.tile_size + game.get_viewport_center()

func save_settings() -> void:
	game.save_settings([starting_level])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level = settings[0]
