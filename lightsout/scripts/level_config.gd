class_name LightsoutLevelConfig

# Per-level configuration for Lightsout.
# rounds: how many rounds at this level before advancing
# board_size: width and height of the board (square)
# num_bombs: number of bomb agents to add

const LEVELS: Array = [
	{"level": 1, "rounds": 3, "board_size": 9,  "num_bombs": 2, "dispatch_ms": 5000},
	{"level": 2, "rounds": 3, "board_size": 11, "num_bombs": 4, "dispatch_ms": 2500},
	{"level": 3, "rounds": 3, "board_size": 13, "num_bombs": 5, "dispatch_ms": 3500},
	{"level": 4, "rounds": 3, "board_size": 15, "num_bombs": 7, "dispatch_ms": 2500},
	{"level": 5, "rounds": 3, "board_size": 23, "num_bombs": 11, "dispatch_ms": 2000},
]
