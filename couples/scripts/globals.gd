extends Node

# CouplesG autoload — shared state for the Couples game. Self-contained: loads the shared
# dino images (res://art/dinos, contiguous dino1..N) itself. Probing known paths with
# ResourceLoader.exists is export-safe (DirAccess can't enumerate res:// images in exports).

var starting_level_id: int = 1

var game: GenericGameUtil = GenericGameUtil.new("Couples", "couples", 0, 2, 0)

var _dinos: Array = []

func _ensure_dinos() -> void:
	if not _dinos.is_empty():
		return
	for i in range(1, 400):
		var p: String = "res://art/dinos/dino%d.jpg" % i
		if ResourceLoader.exists(p):
			_dinos.append(load(p))

func num_dinos() -> int:
	_ensure_dinos()
	return _dinos.size()

func dino_texture(idx: int) -> Texture2D:
	_ensure_dinos()
	if _dinos.is_empty():
		return null
	return _dinos[idx % _dinos.size()]

func save_settings() -> void:
	game.save_settings([starting_level_id])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level_id = int(settings[0])
