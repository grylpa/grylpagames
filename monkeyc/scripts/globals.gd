extends Node

var starting_level_id: int = 1
var use_uppercase: bool = true
var game: GenericGameUtil = GenericGameUtil.new("Monkey C", "monkeyc", 0, 10, 0, 0)

var level_queue: Array = []

func init_globals() -> void:
	game.init_sizes()
	game.reset(true)

func reset_queue_from(start_id: int) -> void:
	var base: Array = MonkeyCLevelConfig.LEVEL_PROGRESSION_ORDER.duplicate()
	var idx: int = base.find(start_id)
	if idx > 0:
		level_queue = base.slice(idx) + base.slice(0, idx)
	else:
		level_queue = base

func pop_next_level_id() -> int:
	if level_queue.is_empty():
		level_queue = MonkeyCLevelConfig.LEVEL_PROGRESSION_ORDER.duplicate()
	return level_queue.pop_front()

func record_level_result(level_id: int, pct: int) -> void:
	if pct < 70:
		if level_queue.size() >= 1:
			level_queue.insert(1, level_id)
		else:
			level_queue.append(level_id)

func save_settings() -> void:
	game.save_settings([starting_level_id])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level_id = settings[0]
