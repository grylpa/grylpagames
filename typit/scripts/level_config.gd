class_name TypitLevelConfig

# Per-level configuration for Typit. The size of this array determines the number
# of levels shown in the main-menu Level slider and the stats Keys-tab selector.
#
# key_w, key_h   : on-screen key width/height in px (smaller = harder)
# case           : how the text to type is displayed —
#                  "lower" (all lowercase), "upper" (ALL CAPS),
#                  "title" (Capitalise The First Letter Of Each Word),
#                  "sentence" (Capitalise first letter of the passage only)
# case_sensitive : if true, the input must match the shown casing — the Shift key is
#                  shown and works (tap it, next letter is capital). If false, the
#                  Shift key is hidden and matching ignores case.
# max_len        : max characters of the passage to type. The text is cut at a word
#                  boundary (whitespace) or sentence end, never mid-word, never over
#                  this length, and never ending on a space. 0 = no limit (full passage).

const LEVELS: Array = [
	{"level": 1, "key_w": 62.0, "key_h": 58.0, "case": "upper",    "case_sensitive": false, "max_len": 18},
	{"level": 2, "key_w": 52.0, "key_h": 48.0, "case": "title",    "case_sensitive": true,  "max_len": 24},
	{"level": 3, "key_w": 44.0, "key_h": 40.0, "case": "sentence", "case_sensitive": true,  "max_len": 30},
	{"level": 4, "key_w": 36.0, "key_h": 32.0, "case": "lower",    "case_sensitive": false, "max_len": 40},
	{"level": 5, "key_w": 28.0, "key_h": 24.0, "case": "lower",    "case_sensitive": false, "max_len": 0},
]

# Sentences to type. Lowercase here; displayed in the level's chosen case.
const PASSAGES: Array = [
	"the quick brown fox jumps over the lazy dog",
	"sphinx of black quartz judge my vow",
	"pack my box with 5 dozen liquor jugs",
	"how vexingly quick daft zebras jump",
	"the 5 boxing wizards jump quickly",
	"jackdaws love my big sphinx of quartz",
	"we promptly judged antique ivory buckles for the next prize",
	"a quart jar of oil mixed with zinc oxide makes a bright paint",
	"brown jars prevented the mixture from freezing too quickly",
	"six big juicy steaks sizzled in a pan as five workmen left the quarry",
	"amazingly few discotheques provide jukeboxes",
	"crazy frederica bought many very exquisite opal jewels",
	"60 zippers were quickly picked from the woven jute bag",
	"fix problem quickly with galvanized jets",
	"my girl wove six dozen plaid jackets before she quit",
	"the job requires extra pluck and zeal from every young wage earner",
	"a mad boxer shot a quick gloved jab to the jaw of his dizzy opponent",
	"big july earthquakes confound zany experimental vows",
	"when zombies arrive quickly fax judge pat",
	"how quickly daft jumping zebras vex",
]
