extends RefCounted

# THE HOUSE'S FLOORS (2026-11-16). The rooms were the app's palette colors (color_by_index, deep purple,
# crimson, white...) on the floor shader: they read as a diagram, not a home ("way less pretty than Mind
# Palace"). Now each room is a room of a house, in a material and a color a house has: room_floor.gdshader's
# `kind` (0 marble, 1 glazed ceramic, 2 terracotta), its checker, and the tint.
#
# THE WATER MUST READ ON EVERY FLOOR: it is blue (water.gdshader), and seeing it spread is the game. So no
# blue or cyan floor (a blue bathroom would hide a leak), nothing very dark, mostly warm and mid tones. The
# rooms still differ from one another (material and hue), which is what the colors were for: telling which
# room is which. No room names on screen: in Storm the eye is on the water.
#
# [name, kind, checker, tint]. The order is shuffled per board (level.gd `_room_looks`).
const LOOKS: Array = [
	["kitchen", 1, 0.0, Color(0.86, 0.81, 0.68)],
	["living room", 2, 0.0, Color(0.64, 0.43, 0.34)],
	["hall", 0, 1.0, Color(0.76, 0.72, 0.64)],
	["bathroom", 1, 0.0, Color(0.70, 0.78, 0.66)],
	["study", 0, 0.0, Color(0.55, 0.45, 0.37)],
	["dining room", 0, 0.0, Color(0.64, 0.40, 0.36)],
	["sunroom", 2, 0.0, Color(0.80, 0.68, 0.54)],
	["bedroom", 1, 0.0, Color(0.64, 0.52, 0.56)],
]
