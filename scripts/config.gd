extends Node

const CATEGORY_ORDER: Array = ["Brain twisters", "Attention & Speed", "Serenity", "Memory & Speed", "Reflexes", "Planning", "Memory & Navigation", "Imagination & Recognition", "Language"]

# [0]=folder, [1]=display_name, [2]=description, [3]=category, [4]=needs_login (optional bool)
var games = [
	["breathe",       "Breathe",        "Track your breathing rhythm and consistency",            "Serenity"],
	["udbr",          "Udbr",           "Follow your breathing pattern",                          "Serenity"],
	#["river",         "River",          "Float down the river with your breath",                  "Serenity"],
	["crack",         "Crack the Safe", "Turn the dial with your breath to crack the safe",       "Serenity"],
	["mother",        "Mother Snake",   "Follow the mother snake's breathing path",               "Serenity"],

	# ["rlmadness",     "RL Madness",     "How fast can your brain switch?",                        "Brain twisters"],
	["sortingrobots", "Sorting Robots", "Sort items by hidden rules",                             "Brain twisters"],
	["bucketmadness", "Bucket Madness", "Direct falling items into the right bucket",             "Brain twisters"],
	["monkeyc",       "Monkey C",       "Watch the robot and figure out the rule",                "Brain twisters"],
	["change",        "Change",         "Drag coins to pay the exact amount",                     "Brain twisters"],
	["aliens",        "Aliens",         "Work the spaceport gates: board only the right aliens",  "Brain twisters"],

	["ptbits",        "Ptbits",         "Push each ball into its matching-color basket",          "Attention & Speed"],
	["gorilla",       "Gorilla",        "Pick up coins while counting the gorillas",              "Attention & Speed"],
	["wolves",        "Wolves",         "Guard your flock from the wolves",                       "Attention & Speed"],
	["couples",       "Couples",        "Find and tap the two identical cards",                   "Attention & Speed"],
	["ddooo",         "DDOOO",          "Find the center shape and pay attention to the corner",  "Attention & Speed"],
	["didi",          "DIDI",           "Find the center shape and remember where you saw it",    "Attention & Speed"],
	["taxi",          "Taxi",           "Be a station manager and owner",                         "Attention & Speed"],
	["pop",           "Pop",            "Remember the shapes and colors",                         "Attention & Speed"],
	["ooo",           "OOO",            "Remember the shapes and colors",                         "Attention & Speed"],

	["movingcards",   "Moving Cards",   "Remember moving cards",                                  "Memory & Speed"],
	["weris",         "Weris",          "Find people in a crowd",                                 "Memory & Speed"],
	["friends",       "Friends",        "Recognize your friends on an evening stroll",            "Memory & Speed"],
	["dino",          "Dino",           "Swipe to say if you've seen the card already",           "Memory & Speed"],

	["storm",         "Storm",          "Save your house from the storm with tools and drains",   "Planning"],
	["guidem",        "Guidem",         "Help your players reach their targets",                  "Planning"],
	["pneumo",        "Pneumo",         "Manage your pneumatic tubes deliveries",                 "Planning"],
	["parkem",        "Parkem",         "Don't allow the monsters to reach their goals",          "Planning"],
	
	["whack",         "Whack",          "Tap quickly and accurately. Avoid decoys",               "Reflexes"],
	["typit",         "Typit",          "Tap precisely — every touch position is measured",       "Reflexes"],

	["polkadots",     "Polka Dots",     "Identify the scatter of dots",                           "Imagination & Recognition"],

	["mmm",           "MMM",            "Remember room colors after exploring all of them",       "Memory & Navigation"],
	["deliverem",     "Deliverem",      "Remember the order for delivering your packets",         "Memory & Navigation"],
	["lightsout",     "Lights Out",     "Remember your path, goal, and obstacles",                "Memory & Navigation"],
	["delemfp",       "Delem FP",       "Deliver packets in order while zoomed in",               "Memory & Navigation"],

	# ["matchws",       "Matchws",        "Learn new words",                                        "Language", true],

]

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
