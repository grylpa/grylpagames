extends RefCounted

# Pickpocket's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time player has to be shown:
#   1. That there are TWO jobs at once: follow the ball, and keep the street in the corner of your
#      eye. A player told only about the cups watches the cups and is then asked about a theft they
#      never knew to look for.
#   2. That the street freezes when the cups stop, and the questions come in order: the cup, then
#      the person.
#   3. Who was robbed, and who did it, pointed at once the answer is in.
#
# The round is the real one, slowed down (level._tutorial_setup): three cups, slow swaps, a bright
# wallet and a victim who starts, always on the street, never a question about the pickpocket.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var table_spot: Callable = func(): return level.tutorial_table_rect()
	var victim_spot: Callable = func(): return level.tutorial_victim_rect()
	var thief_spot: Callable = func(): return level.tutorial_thief_rect()
	# The street and the onlookers: no caption may sit on them while the player has to watch them
	# or pick a person from them (the runner docks the caption where it covers least of these).
	var far_band: Callable = func(): return level.tutorial_far_band()
	var near_band: Callable = func(): return level.tutorial_near_band()
	var crowd_l: Callable = func(): return level.tutorial_crowd_rect(-1)
	var crowd_r: Callable = func(): return level.tutorial_crowd_rect(1)
	var everything: Array = [table_spot, near_band, far_band, crowd_l, crowd_r]
	return [
		{
			"title": "Pickpocket",
			"text": "A street hustler hides a ball under one of his cups and shuffles them.\n\nFollow the ball.",
			"spot": table_spot,
		},
		{
			"title": "Two jobs at once",
			"text": "Meanwhile, someone on the street gets robbed. Watch the cups, and the street from the corner of your eye.",
			"keep_clear": everything,
		},
		{
			"text": "Follow the ball. Keep the street in the corner of your eye.",
			"await": {"event": "street_frozen", "timeout": 30.0},
			"watch_only": true,
			"keep_clear": everything,
		},
		{
			"text": "The street freezes. Where is the ball? Tap its cup.",
			"await": {"event": "cup_picked", "timeout": 60.0},
			"keep_clear": everything,
			"hint_after": 12.0,
			"hint": "Tap a cup.",
		},
		{
			"text": "Now tap the person who was robbed.",
			"await": {"event": "person_picked", "timeout": 60.0},
			"keep_clear": everything,
			"hint_after": 15.0,
			"hint": "Tap someone on the street.",
		},
		{
			"title": "Robbed",
			"text": "This is who was robbed.",
			"spot": victim_spot,
			"keep_clear": [victim_spot, thief_spot],
		},
		{
			"title": "The pickpocket",
			"text": "And this is the pickpocket.\n\nA round counts only when you get both the ball and the person right.",
			"spot": thief_spot,
			"keep_clear": [victim_spot, thief_spot],
		},
		{
			"title": "Ready",
			"text": "Later the cups move faster, the theft is quicker, and you may be asked for the pickpocket instead.\n\nSometimes no one is robbed at all: then tap No one.",
		},
	]
