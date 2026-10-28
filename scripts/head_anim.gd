extends AnimatedSprite2D

func _ready() -> void:
	pass
	# play("circular")

func play_def():
	play("circular")

# SMOOTH TURNS for every head that uses this scene (players, monsters, trucks). The games move a
# creature tile center to tile center and set `rotation` straight to the new heading, so a corner
# was a right angle taken on the spot and a reversal flipped in one frame.
#  - POSITION: the head is drawn at a PathSmoother point of its creature's path, which equals the
#    true position on a straight run and rounds each corner (the head's own offset only; the
#    creature, its collision shape and everything the game reads stay where the game put them).
#  - FACING: along that rounded path while it is moving; otherwise (standing, doubling back) the
#    rotation the game set. Either way the drawn rotation swings toward it at TURN_RATE.
# The game's own rotation is read each frame after the agent set it (a parent processes before its
# children); a value equal to what this wrote last frame means the game set nothing new.
const TURN_RATE: float = PI * 0.5 / 0.10    # a right angle in 0.10 s, a reversal in 0.20 s
const SMOOTH_WINDOW: float = 18.0
var _target_rot: float = 0.0
var _written_rot: float = INF
var _path: PathSmoother = PathSmoother.new(SMOOTH_WINDOW)

func _process(delta: float) -> void:
	var host: Node2D = get_parent() as Node2D
	if host != null:
		_path.push(host.global_position)
		global_position = _path.point()
	if not is_equal_approx(rotation, _written_rot):
		_target_rot = rotation
		if _written_rot == INF:
			_written_rot = rotation
			return
		rotation = _written_rot
	var want: float = _target_rot
	if _path.has_heading():
		want = _path.heading() - (host.global_rotation if host != null else 0.0)
	var diff: float = wrapf(want - rotation, -PI, PI)
	var step: float = TURN_RATE * delta
	rotation = want if absf(diff) <= step else rotation + signf(diff) * step
	_written_rot = rotation
