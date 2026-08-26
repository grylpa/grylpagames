extends Node

const CATEGORY_ORDER: Array = ["Brain twisters", "Attention & Speed", "Serenity", "Memory & Speed", "Reflexes", "Planning", "Memory & Navigation", "Imagination & Recognition", "Language"]

# [0]=folder, [1]=display_name, [2]=description, [3]=category, [4]=needs_login (false), [5]=supports mobile (true), [6]=supports desktop (true))
var games = [
	["aliens",        "Aliens",         "Work the spaceport gates",                               "Brain twisters"],
	["sortingrobots", "Sorting Robots", "Sort items by hidden rules",                             "Brain twisters"],
	["bucketmadness", "Bucket Madness", "Direct falling items into the right bucket",             "Brain twisters"],
	["monkeyc",       "Apprentice",     "Watch the robot, then name its rule",                    "Brain twisters"],
	["change",        "Change",         "Pay the exact amount",                                   "Brain twisters"],
	# ["rlmadness",     "RL Madness",     "How fast can your brain switch?",                        "Brain twisters"],

	["ptbits",        "Nudge",          "Nudge every ball over the rim into its own basket",      "Attention & Speed"],
	["gorilla",       "Gorilla",        "Pick up coins while counting the gorillas",              "Attention & Speed"],
	["couples",       "Couples",        "Find the two identical cards",                           "Attention & Speed"],
	["wolves",        "Wolves",         "Guard your flock from the wolves",                       "Attention & Speed"],
	["didi",          "Pinpoint",       "Two clues, one shot",                                    "Attention & Speed"],
	["taxi",          "Taxi",           "Be a station manager and owner",                         "Attention & Speed"],
	["ddooo",         "Witness",        "You saw it happen. Now testify",                         "Attention & Speed"],
	["pop",           "Glimpse",        "Catch it out of the corner of your eye",                 "Attention & Speed"],
	["ooo",           "Lineup",         "Pick the culprit out of the lineup",                     "Attention & Speed"],

	["dino",          "Dino",           "Swipe to say if you've seen the card already",           "Memory & Speed"],
	["dinoback",      "Dino N-Back",    "Does this card match the one N cards back?",             "Memory & Speed"],
	["movingcards",   "Moving Cards",   "Remember moving cards",                                  "Memory & Speed"],
	["weris",         "Weris",          "Find people in a crowd",                                 "Memory & Speed"],
	["friends",       "Friends",        "Recognize your friends on an evening stroll",            "Memory & Speed"],

	["storm",         "Storm",          "Save your house from the storm",                         "Planning"],
	["guidem",        "Guidem",         "Help your players reach their targets",                  "Planning"],
	["pneumo",        "Pneumo",         "Manage your pneumatic tubes deliveries",                 "Planning"],
	["parkem",        "Parkem",         "Don't allow the monsters to reach their goals",          "Planning"],
	
	["whack",         "Whack",          "Tap quickly and accurately. Avoid decoys",               "Reflexes"],
	["typit",         "Typit",          "How fast and accurate can you type?",                    "Reflexes", false, true, false],

	["breathe",       "Breathe",        "Track your breathing rhythm and consistency",            "Serenity"],
	["udbr",          "Buoy",           "Float up and down with your breath",                     "Serenity"],
	["crack",         "Crack the Safe", "Crack the safe with your breath",                        "Serenity"],
	["mother",        "Mother Snake",   "Follow the mother snake's breathing path",               "Serenity"],
	#["river",         "River",          "Float down the river with your breath",                  "Serenity"],

	["polkadots",     "Polka Dots",     "Identify the scatter of dots",                           "Imagination & Recognition"],

	["mmm",           "Mind Palace",    "Explore and remember the room colors",                   "Memory & Navigation"],
	["lightsout",     "Lights Out",     "Remember your path, goal, and obstacles",                "Memory & Navigation"],
	["deliverem",     "Deliverem",      "Remember the delivery order",                            "Memory & Navigation"],
	["delemfp",       "Delem FP",       "Deliver packets in order while zoomed in",               "Memory & Navigation"],

	# ["matchws",       "Matchws",        "Learn new words",                                        "Language", true],

]

# Games that have an authored coached tutorial ({folder}/scripts/tutorial.gd). This drives the
# automatic first-run tutorial and the suppression of the instructions wall for those games; the
# two buttons that offer a tutorial (the game's main menu and its instructions screen) instead test
# whether the game's main.gd defines start_tutorial(). Add a folder here as each tutorial is
# written — see docs/tutorials.md for the recipe.
var tutorials: Array = ["aliens", "breathe", "bucketmadness", "change", "couples", "crack", "ddooo", "delemfp", "deliverem", "didi", "dino", "dinoback", "gorilla", "guidem", "lightsout", "mmm", "monkeyc", "mother", "ooo", "parkem", "pneumo", "pop", "ptbits", "sortingrobots", "storm", "taxi", "udbr", "whack", "wolves"]

func has_tutorial(folder: String) -> bool:
	return folder in tutorials

func move_to_top(folder: String):
	for i in games.size():
		if games[i][0] == folder:
			if i > 0:
				games.insert(0, games.pop_at(i))
			return

# Optional fields on a game row, past the four every row carries:
#   [4] needs_login   [5] runs on mobile   [6] runs on desktop
# A row that stops short of a field takes the default: no login needed, and the game is offered on
# both platforms. Only a game that is meaningless on one of them has to say so.
const IDX_NEEDS_LOGIN: int = 4
const IDX_SUPPORTS_MOBILE: int = 5
const IDX_SUPPORTS_DESKTOP: int = 6

func supports_mobile(g) -> bool:
	return true if g.size() <= IDX_SUPPORTS_MOBILE else bool(g[IDX_SUPPORTS_MOBILE])

func supports_desktop(g) -> bool:
	return true if g.size() <= IDX_SUPPORTS_DESKTOP else bool(g[IDX_SUPPORTS_DESKTOP])

# Whether to offer this game on the device we are actually running on. Typit, for one, only makes
# sense with a touch keyboard, so it is hidden on desktop. Score sync deliberately does NOT use
# this: a game hidden here may still have scores from the player's other device.
func runs_on_this_platform(g) -> bool:
	return supports_mobile(g) if MainGlobals.is_mobile() else supports_desktop(g)

# set to value of game folder if a single game
var single_game = ""
# var single_game = "mmm"

var use_BE = false
# Controls whether user_events and user_game_states are written to.
# These are analytics/log tables only — no game logic reads from them.
# Disable to reduce network traffic without affecting score sync.
var use_BE_logging: bool = false

var is_anonymous_user: bool = false

var show_reset_scores: bool = false
