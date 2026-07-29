extends Node

# AliensG autoload — shared state for the Aliens game (drag roaming aliens into or out of the
# target areas' rings). Self-contained; the aliens are drawn (see alien.gd), not images.

var starting_level_id: int = 1
var game: GenericGameUtil = GenericGameUtil.new("Aliens", "aliens", 0, 2, 0)

# Ordered list of level IDs to play next. Popped one at a time; refilled from
# LEVEL_PROGRESSION_ORDER when empty.
var level_queue: Array = []

# A trailing -1 in LEVEL_PROGRESSION_ORDER means "once the list is exhausted, keep replaying its
# LAST level" instead of cycling back to the beginning. The sentinel is never a level id itself.
const REPEAT_LAST: int = -1

# Last level actually handed out — what a trailing REPEAT_LAST keeps returning.
var _last_level_id: int = 0

func init_globals() -> void:
	game.init_sizes()
	game.reset(true)

# The progression order with the trailing REPEAT_LAST sentinel (if present) stripped off.
func _progression() -> Array:
	var order: Array = AliensLevelConfig.LEVEL_PROGRESSION_ORDER.duplicate()
	if not order.is_empty() and int(order[order.size() - 1]) == REPEAT_LAST:
		order.remove_at(order.size() - 1)
	return order

func _repeats_last() -> bool:
	var order: Array = AliensLevelConfig.LEVEL_PROGRESSION_ORDER
	return not order.is_empty() and int(order[order.size() - 1]) == REPEAT_LAST

func reset_queue_from(start_id: int) -> void:
	_last_level_id = 0
	var base: Array = _progression()
	var idx: int = base.find(start_id)
	if _repeats_last():
		# No wrap-around tail: the run plays through to the final level and then stays there,
		# so starting mid-list never makes an earlier level the one that repeats.
		level_queue = base.slice(idx) if idx > 0 else base
	elif idx > 0:
		level_queue = base.slice(idx) + base.slice(0, idx)
	else:
		level_queue = base

func pop_next_level_id() -> int:
	if level_queue.is_empty():
		if _repeats_last() and _last_level_id > 0:
			return _last_level_id      # stay on the last level instead of wrapping to the start
		level_queue = _progression()
	if level_queue.is_empty():
		return _last_level_id if _last_level_id > 0 else 1
	_last_level_id = level_queue.pop_front()
	return _last_level_id

# After completing a level, optionally schedule a repeat if accuracy was poor.
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
		starting_level_id = int(settings[0])
