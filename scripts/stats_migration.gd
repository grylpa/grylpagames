extends RefCounted
class_name StatsMigration

# The one-time changeover to the v6 session record.
#
# v6 stores a named DICTIONARY per session instead of a positional array, so the old history cannot
# be carried across — the fields it would need were never recorded. That is an acceptable trade
# (see docs), but it must be explained once to a player who had history, and never mentioned to
# someone installing for the first time.
#
# Telling those two apart needs no version history and nothing recorded in advance, because the OLD
# SAVE FILES ARE THEMSELVES THE EVIDENCE of a previous install:
#
#   marker present                      -> already migrated, do nothing
#   marker absent + old v5 score files  -> UPGRADE      : notice, wipe, write marker
#   marker absent + no old score files  -> FRESH INSTALL: write marker silently
#
# Writing the marker on a fresh install too is what makes the branch run exactly once, ever. The
# marker holds a NUMBER rather than a flag so the same mechanism carries any later migration.

const MARKER_PATH: String = "user://stats_schema.txt"
const SCHEMA_VERSION: int = 6

# Only score history is discarded. Per-game SETTINGS (starting level, options) live in
# `settings_v5_*` and are deliberately left alone — the player asked for a history reset, not to
# have every game's preferences forgotten.
const OLD_SCORE_PREFIXES: Array = ["scores_v5_", "ongoing_score_v5_", "uploaded_v5_", "new_best_v1_"]

enum Outcome { ALREADY_DONE, FRESH_INSTALL, UPGRADED }

static func read_marker() -> int:
	if not FileAccess.file_exists(MARKER_PATH):
		return -1
	var f: FileAccess = FileAccess.open(MARKER_PATH, FileAccess.READ)
	if f == null:
		return -1
	var txt: String = f.get_as_text().strip_edges()
	f.close()
	return int(txt) if txt.is_valid_int() else -1

static func write_marker(v: int = SCHEMA_VERSION) -> void:
	var f: FileAccess = FileAccess.open(MARKER_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(str(v))
		f.close()

# Every old score file in user://, across all games and all user keys.
static func find_old_score_files() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return found
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			for prefix: String in OLD_SCORE_PREFIXES:
				if fname.begins_with(prefix):
					found.append(fname)
					break
		fname = dir.get_next()
	dir.list_dir_end()
	return found

# Run once at startup, BEFORE any game writes a session. Returns what happened so the caller can
# decide whether to show the notice; this function never shows UI itself.
static func run() -> Outcome:
	if read_marker() >= SCHEMA_VERSION:
		return Outcome.ALREADY_DONE
	var old_files: PackedStringArray = find_old_score_files()
	if old_files.is_empty():
		write_marker()
		return Outcome.FRESH_INSTALL
	for fname: String in old_files:
		DirAccess.remove_absolute("user://" + fname)
	write_marker()
	Log.dbg("stats migration: removed %d old score files" % old_files.size())
	return Outcome.UPGRADED

# Shown once, only to a player who had history. Short, and honest about what was lost — a person
# who kept a year of scores deserves to be told plainly rather than to discover an empty list.
static func notice_title() -> String:
	return "Progress tracking has changed"

static func notice_text() -> String:
	return ("This version measures your progress in a new way, recording much more about how you " +
		"play than before.\n\n" +
		"Your previous scores could not be carried over, so tracking starts fresh from today.\n\n" +
		"Your game settings have been kept.")
