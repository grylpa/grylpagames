class_name WolvesLevelConfig

# w,h						: width,height of center compund, if h is omitted, set h == w
# color						: color of center compound
# color_idx					: color index of center compound. use color if this doesn't exist
# compund_fence_interval	: mean time between removing pieces of the inner fence
# sheep_speed				: speed factor 0 to 1
# pct_sheep					: percentage of room area to fill with sheep
# wolves_interval			: mean time between appearance of new wolves, 0 or don't include to not have wolves at all
# dist_to_scare				: board distance for a sheep to get scared from the dog. reasonable values are 2,3
# max_wolves				: leave at 0 to not have a limit
# level_time				: initial time to end level, in seconds, default is 300

const LEVELS: Array = [
	{"level": 1, "w": 7, "color": Color("#77AADD"), "compund_fence_interval": 5000, "farm_fence_interval": 8000, "sheep_speed": 0.2, "pct_sheep": 0.3, 
	"wolves_interval": 5000, "dist_to_scare": 3, "max_wolves": 3, "level_time": 120},
	{"level": 2, "w": 9, "h": 9, "color": Color("#EE8866"), "compund_fence_interval": 4000, "farm_fence_interval": 8000, "sheep_speed": 0.3, "pct_sheep": 0.3, 
	"wolves_interval": 10000, "dist_to_scare": 3, "max_wolves": 5, "level_time": 300},
	{"level": 3, "w": 9, "h": 9, "color": Color("#EEDD88"), "compund_fence_interval": 3000, "farm_fence_interval": 7000, "sheep_speed": 0.4, "pct_sheep": 0.4, 
	"wolves_interval": 4000, "dist_to_scare": 3, "max_wolves": 5},
	{"level": 4, "w": 9, "h": 9, "color": Color("#332288"), "compund_fence_interval": 2000, "farm_fence_interval": 5000, "sheep_speed": 0.5, "pct_sheep": 0.5, 
	"wolves_interval": 3000, "dist_to_scare": 2, "max_wolves": 7},
	{"level": 5, "w": 9, "h": 9, "color": Color("#f032e6"), "compund_fence_interval": 1000, "farm_fence_interval": 1000, "sheep_speed": 0.5, "pct_sheep": 0.8, 
	"wolves_interval": 1000, "dist_to_scare": 2, "max_wolves": 9},
]

