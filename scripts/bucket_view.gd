extends Control
class_name BucketView

# ONE OF THE THREE TARGETS of the pool-table game (bucketmadness), as a marker only (2026-11-02). The
# pockets themselves are DRAWN BY THE STAGE (scripts/bucket_stage.gd), in the table's own corners and
# the middle of its near rail -- a separate row of containers under the table read as buckets, which
# did not belong on a pool table. This control keeps its place in the layout (the rule plaque stands
# under it) and the game's API: `open_amount` (the stage lights that pocket's rim), `is_dumpster`
# (the middle one: the net), and `mouth_global()` -- where a ball must go to drop in, which the level
# sets from the stage's pocket positions (`mouth_at`).
#
# It was a drawn bucket and a drawn dumpster when the items were tiles, then briefly a pocket drawn
# in this control's own rect with a leather bag under it -- still a container in a row.

@export var is_dumpster: bool = false

var open_amount: float = 0.0:
	set(v):
		open_amount = clampf(v, 0.0, 1.0)

# The pocket's centre, global coordinates (set by the level each frame from the stage).
var mouth_at: Vector2 = Vector2.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func mouth_global() -> Vector2:
	return mouth_at if mouth_at != Vector2.ZERO else global_position + size * 0.5
