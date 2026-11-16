extends RefCounted

# THE ROOMS OF THE PALACE (2026-11-16). A room's floor COLOR used to be what the player remembered (the
# map asked for it); now the map asks where each vault's object was, and the floors are what a house's
# floors are: each room a KIND, with its own floor -- drawn by castle_floor.gdshader (`style`, `col_a`,
# `col_b`). The kind's name shows as the player walks in, and the FOUND card says where the object is
# ("In the kitchen"), the way a mind palace is used. The map at the end stays plain gray: knowing "the
# kitchen" must still be joined to where the kitchen is.
#
# [name, shader style, col_a, col_b]. Styles: 0 rough stone, 1 marble checker, 2 parquet, 3 checker
# tiles, 4 mosaic, 5 planks, 6 carpet, 7 flagstones in grass, 8 terracotta.
const KINDS: Array = [
	["living room", 2, Color(0.70, 0.50, 0.28), Color(0.0, 0.0, 0.0)],
	["kitchen", 3, Color(0.88, 0.85, 0.78), Color(0.36, 0.40, 0.46)],
	["bathroom", 4, Color(0.62, 0.82, 0.86), Color(0.95, 0.97, 0.98)],
	["library", 5, Color(0.36, 0.22, 0.13), Color(0.0, 0.0, 0.0)],
	["bedroom", 6, Color(0.20, 0.27, 0.50), Color(0.85, 0.70, 0.35)],
	["garden", 7, Color(0.66, 0.63, 0.57), Color(0.30, 0.52, 0.22)],
	["ballroom", 1, Color(0.93, 0.89, 0.82), Color(0.80, 0.70, 0.66)],
	["cellar", 0, Color(0.42, 0.39, 0.35), Color(0.0, 0.0, 0.0)],
	["sunroom", 8, Color(0.76, 0.42, 0.26), Color(0.92, 0.86, 0.74)],
	["study", 5, Color(0.58, 0.28, 0.20), Color(0.0, 0.0, 0.0)],
	["dining room", 1, Color(0.30, 0.48, 0.40), Color(0.90, 0.88, 0.80)],
	["nursery", 6, Color(0.80, 0.55, 0.62), Color(0.97, 0.93, 0.86)],
]

static func kind_name(k: int) -> String:
	return str(KINDS[k][0]) if k >= 0 and k < KINDS.size() else ""
