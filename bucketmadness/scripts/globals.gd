extends Node

var starting_level_id: int = 1
var use_uppercase: bool = true
var game: GenericGameUtil = GenericGameUtil.new("Bucket Madness", "bucketmadness", 0, 10, 0, 0)

var level_queue: Array = []

func init_globals() -> void:
	game.init_sizes()
	game.reset(true)

# A trailing -1 in LEVEL_PROGRESSION_ORDER means "once the list is exhausted, keep replaying its
# LAST level" instead of cycling back to the beginning. The sentinel is never a level id itself.
const REPEAT_LAST: int = -1

# Last level actually handed out — what a trailing REPEAT_LAST keeps returning.
var _last_level_id: int = 0

# The progression order with the trailing REPEAT_LAST sentinel (if present) stripped off.
func _progression() -> Array:
	var order: Array = BucketMadnessLevelConfig.LEVEL_PROGRESSION_ORDER.duplicate()
	if not order.is_empty() and int(order[order.size() - 1]) == REPEAT_LAST:
		order.remove_at(order.size() - 1)
	return order

func _repeats_last() -> bool:
	var order: Array = BucketMadnessLevelConfig.LEVEL_PROGRESSION_ORDER
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

# The accuracy a level demands before the player moves on, from that level's own config. 70 was
# hardcoded here for every level, which is why a harder level asked no more of the player than the
# first one.
const DEFAULT_PASS_PCT: int = 70

func pass_pct_for(level_id: int) -> int:
	for lv in BucketMadnessLevelConfig.LEVELS:
		if int(lv.get("id", -1)) == level_id:
			return int(lv.get("pass_pct", DEFAULT_PASS_PCT))
	return DEFAULT_PASS_PCT

func level_name_for(level_id: int) -> String:
	for lv in BucketMadnessLevelConfig.LEVELS:
		if int(lv.get("id", -1)) == level_id:
			return str(lv.get("name", str(level_id)))
	return str(level_id)

# True when the player earned the next level. Failing now REPLAYS the same level next, instead of
# advancing and quietly re-queueing the failed one behind it — you could get every answer wrong and
# still move on, which is what made the accuracy number decorative.
func record_level_result(level_id: int, pct: int) -> bool:
	if pct >= pass_pct_for(level_id):
		return true
	level_queue.insert(0, level_id)
	return false

# What the player will get next, for the level-done popup to name. -1 when it cannot be known
# without consuming the queue.
func peek_next_level_id() -> int:
	return int(level_queue[0]) if not level_queue.is_empty() else -1

func save_settings() -> void:
	game.save_settings([starting_level_id])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level_id = settings[0]
