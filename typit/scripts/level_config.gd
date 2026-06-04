class_name TypitLevelConfig

# Per-level configuration for Typit. The size of this array determines the number
# of levels shown in the main-menu Level slider and the stats Keys-tab selector.
#
# key_w, key_h : on-screen key width/height in px (smaller = harder)
# case         : how the text to type is displayed —
#                "lower" (all lowercase), "upper" (ALL CAPS),
#                "title" (Capitalise The First Letter Of Each Word),
#                "sentence" (Capitalise first letter of the passage only)
#                Matching is always case-insensitive (the keyboard types lowercase).

const LEVELS: Array = [
	{"level": 1, "key_w": 62.0, "key_h": 58.0, "case": "sentence"},
	{"level": 2, "key_w": 52.0, "key_h": 48.0, "case": "sentence"},
	{"level": 3, "key_w": 44.0, "key_h": 40.0, "case": "title"},
	{"level": 4, "key_w": 36.0, "key_h": 32.0, "case": "title"},
	{"level": 5, "key_w": 28.0, "key_h": 24.0, "case": "upper"},
]
