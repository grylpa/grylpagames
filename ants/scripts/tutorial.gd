extends RefCounted

# Ants has no coached tutorial yet, and this file is the placeholder for one.
#
# It is deliberately NOT wired up: "ants" is absent from MainCfg.tutorials and main.gd defines no
# start_tutorial(), which is what the instructions screen and the main menu test before offering
# the "Interactive tutorial" button. Defining the method with no steps behind it would put the
# button in front of players and open an empty coached session -- worse than not offering one.
#
# To bring it to life, follow main/docs/tutorials.md: fill in steps(), add start_tutorial() to
# ants/scripts/main.gd on the ptbits model, and add "ants" to MainCfg.tutorials. Spotlights must be
# MEASURED, not authored -- this game runs under a camera whose zoom depends on the world size, so
# a spot_radius in screen units means something different on every level (see the gorilla design
# doc's "_tight" note, which is the worked example).

static func tutorial_level_id() -> int:
	return 1

static func steps(_level: Node, _game: GenericGameUtil) -> Array:
	return []
