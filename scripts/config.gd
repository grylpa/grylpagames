extends Node

const CATEGORY_ORDER: Array = ["Brain twisters", "Attention & Speed", "Serenity", "Memory & Speed", "Reflexes", "Planning", "Memory & Navigation", "Imagination & Recognition", "Language"]

# [0]=folder, [1]=display_name, [2]=description, [3]=category, [4]=needs_login (optional bool)
var games = [
	["aliens",        "Aliens",         "Work the spaceport gates",                               "Brain twisters"],
	["sortingrobots", "Sorting Robots", "Sort items by hidden rules",                             "Brain twisters"],
	["bucketmadness", "Bucket Madness", "Direct falling items into the right bucket",             "Brain twisters"],
	["monkeyc",       "Monkey C",       "Figure out the rule",                                    "Brain twisters"],
	["change",        "Change",         "Pay the exact amount",                                   "Brain twisters"],
	# ["rlmadness",     "RL Madness",     "How fast can your brain switch?",                        "Brain twisters"],

	["ptbits",        "Nudge",          "Nudge every ball over the rim into its own basket",      "Attention & Speed"],
	["gorilla",       "Gorilla",        "Pick up coins while counting the gorillas",              "Attention & Speed"],
	["couples",       "Couples",        "Find and the two identical cards",                       "Attention & Speed"],
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
	["typit",         "Typit",          "How fast and accurate can you type?",                    "Reflexes"],

	["breathe",       "Breathe",        "Track your breathing rhythm and consistency",            "Serenity"],
	["udbr",          "Udbr",           "Follow your breathing pattern",                          "Serenity"],
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

# Games that have an authored coached tutorial ({folder}/scripts/tutorial.gd). The chooser lists
# these in its "How to play" picker and badges their rows, so a player can tell which games have
# one without entering each game to find out. Add a folder here as each tutorial is written —
# see docs/tutorials.md for the recipe.
var tutorials: Array = ["aliens", "change", "couples", "ddooo", "delemfp", "deliverem", "didi", "dino", "dinoback", "gorilla", "guidem", "lightsout", "mmm", "monkeyc", "ooo", "parkem", "pneumo", "pop", "ptbits", "sortingrobots", "storm", "taxi", "udbr", "wolves"]

func has_tutorial(folder: String) -> bool:
	return folder in tutorials

func move_to_top(folder: String):
	for i in games.size():
		if games[i][0] == folder:
			if i > 0:
				games.insert(0, games.pop_at(i))
			return

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
