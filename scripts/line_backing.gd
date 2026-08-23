extends Line2D

# A Line2D that mirrors another Line2D's points, so a game can draw a thicker, darker line behind
# a skeleton without the code that builds the skeleton having to add, move and remove every point
# twice.
#
# Use it from the scene only: add a Line2D as an EARLIER sibling of the line it backs (earlier
# siblings draw first, so it lands behind at the same z_index), give it this script, set `follows`
# to the line to copy, and set width/default_color to taste. No game code changes at all.
#
# The copy runs at a raised process_priority so it happens after the owner has moved its skeleton
# for this frame; otherwise the backing line would always render one frame stale.

@export var follows: NodePath

var _src: Line2D = null

func _ready() -> void:
	process_priority = 100
	if not follows.is_empty():
		_src = get_node_or_null(follows) as Line2D

func _process(_delta: float) -> void:
	if _src != null:
		points = _src.points
		# Match the line we back, whatever the game sets at runtime. Equal z_index plus being the
		# earlier sibling is what puts us behind it; guessing the value per game is a footgun.
		z_index = _src.z_index
