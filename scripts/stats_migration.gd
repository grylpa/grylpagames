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

# Where the save files live. A seam, and it exists for one reason: the probe for this class has
# to delete real files to mean anything, and pointed at the real user:// it deleted a developer's
# whole save directory on its first run. Production never sets it.
static var base_dir: String = "user://"

const MARKER_NAME: String = "stats_schema.txt"
const SCHEMA_VERSION: int = 7

# What each step removes, and ONLY that step.
#
# A step runs when the marker is below it, so a later step never re-runs an earlier one's sweep.
# That is not tidiness — `keydata_v5_` is also the file typit writes TODAY. It has to be removed
# once, at the moment the sessions it described were discarded, and never again; a single shared
# list would have deleted live key data at the next schema bump.
#
# Step 6 is the changeover to the v6 session record.
#
# Step 7 is that changeover's own leftovers. Typit keeps its per-key tap history in
# `keydata_v5_{key}_typit.gpa` — session history like any other, but under a name step 6 did not
# list, so it survived. The result was a Keys tab showing a full table of taps for sessions the
# score list no longer had, on a device that had just been told its history could not be carried
# over. Only step 6 says anything to the player; step 7 is cleanup after a message already sent.
#
# Only score history is discarded. Per-game SETTINGS (starting level, options) live in
# `settings_v5_*` and are deliberately left alone — the player asked for a history reset, not to
# have every game's preferences forgotten.
const SWEEPS: Dictionary = {
	6: ["scores_v5_", "ongoing_score_v5_", "uploaded_v5_", "new_best_v1_"],
	7: ["keydata_v5_"],
}

# SWEPT: leftovers removed from a device that had already been told. No notice — there is no new
# loss to report, and repeating the message would claim one.
enum Outcome { ALREADY_DONE, FRESH_INSTALL, UPGRADED, SWEPT }

static func marker_path() -> String:
	return base_dir + MARKER_NAME

static func read_marker() -> int:
	if not FileAccess.file_exists(marker_path()):
		return -1
	var f: FileAccess = FileAccess.open(marker_path(), FileAccess.READ)
	if f == null:
		return -1
	var txt: String = f.get_as_text().strip_edges()
	f.close()
	return int(txt) if txt.is_valid_int() else -1

static func write_marker(v: int = SCHEMA_VERSION) -> void:
	var f: FileAccess = FileAccess.open(marker_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(str(v))
		f.close()

# Every file in user:// matching any of `prefixes`, across all games and all user keys.
static func find_old_score_files(prefixes: Array = []) -> PackedStringArray:
	if prefixes.is_empty():
		for step: int in SWEEPS:
			prefixes.append_array(SWEEPS[step])
	var found: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(base_dir)
	if dir == null:
		return found
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			for prefix: String in prefixes:
				if fname.begins_with(prefix):
					found.append(fname)
					break
		fname = dir.get_next()
	dir.list_dir_end()
	return found

# Run once at startup, BEFORE any game writes a session. Returns what happened so the caller can
# decide whether to show the notice; this function never shows UI itself.
static func run() -> Outcome:
	var marker: int = read_marker()
	if marker >= SCHEMA_VERSION:
		return Outcome.ALREADY_DONE

	var steps: Array = SWEEPS.keys()
	steps.sort()
	var removed: int = 0
	var had_history: bool = false          # step 6 found something: this player had a history
	for step: int in steps:
		if marker >= step:
			continue
		var files: PackedStringArray = find_old_score_files(SWEEPS[step].duplicate())
		if step == 6 and not files.is_empty():
			had_history = true
		for fname: String in files:
			DirAccess.remove_absolute(base_dir + fname)
		removed += files.size()

	write_marker()
	if removed > 0:
		Log.dbg("stats migration: removed %d old files (marker was %d)" % [removed, marker])
	if had_history:
		return Outcome.UPGRADED
	if removed > 0:
		return Outcome.SWEPT
	return Outcome.FRESH_INSTALL

# Shown once, only to a player who had history. Short, and honest about what was lost — a person
# who kept a year of scores deserves to be told plainly rather than to discover an empty list.
static func notice_title() -> String:
	return "Progress measurement has changed"

static func notice_text() -> String:
	return ("This version measures your progress in a new and better way.\n\n" +
		"Your previous scores could not be carried over, so measurements start fresh from today.\n\n" +
		"Your game settings have been kept.")
