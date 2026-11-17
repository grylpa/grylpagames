extends "res://scripts/menu_poster.gd"

# PICKPOCKET'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): a CLOSE-UP -- the
# hustler's table (shell_table.gd) seen near and large, his hands shuffling the copper cups under the
# lantern, while behind him the game's dusk street (street.gd) is dimmed and only two figures pass, as
# silhouettes: someone, and the thief a step behind with a hand drifting to their pocket. A picture, not
# the game's wide street (the user: the first version looked "too much like something that is
# playable"). Made up, never the board: the menu also opens mid-game.

const PASSERBY: GDScript = preload("res://pickpocket/scripts/passerby.gd")
const STREET: GDScript = preload("res://pickpocket/scripts/street.gd")
const TABLE: GDScript = preload("res://pickpocket/scripts/shell_table.gd")

var _street: Node2D = null
var _far: Node2D = null
var _near: Node2D = null
var _table: Node2D = null
var _people: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lane_y: Array = [0.0, 0.0]
var _lane_h: Array = [0.0, 0.0]
var _laid_for: float = -1.0
var _w: float = 680.0
var _thief = null
var _mark = null

func _setup() -> void:
	_rng.seed = 11
	_street = STREET.new()
	add_child(_street)
	_far = Node2D.new()
	add_child(_far)
	_near = Node2D.new()
	add_child(_near)
	_table = TABLE.new()
	add_child(_table)
	_street.modulate = Color(0.42, 0.40, 0.52)
	for k in 2:
		var p = PASSERBY.new()
		p.randomize_look(_rng, k % PASSERBY.COATS.size())
		p.set_meta("lane", 0)
		p.dir = 1
		p.phase = _rng.randf() * TAU
		p.set_meta("speed", 44.0)
		p.modulate = Color(0.16, 0.14, 0.22)        # silhouettes against the lit shops
		_far.add_child(p)
		_people.append(p)
	# the pair: the mark, and the thief just behind, walking with them
	_mark = _people[0]
	_thief = _people[1]
	_mark.dir = 1
	_thief.dir = 1
	_thief.set_meta("speed", _mark.get_meta("speed"))

func _lay(full: Vector2, bottom: float) -> void:
	if absf(_laid_for - bottom) < 0.5:
		return
	_laid_for = bottom
	_w = full.x
	var top: float = 0.0
	var a: float = bottom - top
	# the shops start under the name, which stands in the dusk sky
	_lane_y = [top + 0.66 * a, top + 0.84 * a]
	_lane_h = [minf(0.26 * a, 240.0), minf(0.22 * a, 220.0)]
	_street.setup(full.x, top + 0.27 * a, float(_lane_y[0]), top + 0.58 * a, top + 0.67 * a, full.y)
	_street.queue_redraw()
	# the table NEAR: laid out at 1/ZOOM and drawn at ZOOM, so its cups, hands and lantern are large
	var zoom: float = 1.75
	var cup_h: float = clampf(0.07 * a, 34.0, 64.0)
	_table.layout(full.x / zoom, (top + 0.90 * a) / zoom, cup_h, 0.06 * a / zoom, 3)
	_table.scale = Vector2(zoom, zoom)
	_table.set_cups(3)
	for k in _people.size():
		var p = _people[k]
		var lane: int = int(p.get_meta("lane"))
		p.h = float(_lane_h[lane]) * (0.92 + 0.12 * h01(k))
		p.position.y = float(_lane_y[lane])
		if p.position.x == 0.0:
			p.position.x = full.x * 0.3
	_thief.position.x = _mark.position.x - _mark.h * 0.42

var _next_move: float = 0.6
var _moves: int = 0

func _tick(delta: float) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	_lay(full, bottom)
	var now: float = t * 1000.0
	# the hustler at work: a swap, another, now and then a feint, now and then the ball shown
	if t >= _next_move and not _table.busy():
		_moves += 1
		if _moves % 7 == 0:
			_table.start_reveal(int(_table.ball_cup), now, 380.0)
			_next_move = t + 1.6
		elif _moves % 7 == 1:
			_table.lower_all()
			_next_move = t + 0.5
		else:
			var a: int = _rng.randi() % 3
			var b: int = (a + 1 + _rng.randi() % 2) % 3
			_table.start_swap(a, b, now, 420.0, _rng.randf() < 0.2)
			_next_move = t + 0.55
	_table.update(now)
	# the walkers: across and out, back in from the other side
	for p in _people:
		var step: float = float(p.get_meta("speed")) * delta
		p.position.x += float(p.dir) * step
		p.advance(step)
		p.walking = true
		p.tick_motion(delta, _rng, p != _thief)
		var margin: float = p.h * 0.6
		if p.dir > 0 and p.position.x > _w + margin:
			p.position.x = -margin
		elif p.dir < 0 and p.position.x < -margin:
			p.position.x = _w + margin
		p.queue_redraw()
	# the thief keeps a step behind the mark, and every few seconds reaches for the pocket
	_thief.position.x = _mark.position.x - _mark.h * 0.42
	if _thief.position.x < -_thief.h:
		_thief.position.x += _w + _mark.h
	var u: float = fmod(t, 5.0)
	_thief.reach = clampf(sin(clampf((u - 2.0) / 1.6, 0.0, 1.0) * PI) * 1.2, 0.0, 1.0)
	_thief.reach_at = _mark.pocket_point() - _thief.position     # pocket_point is in the street's space

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Pickpocket", "Follow the ball and catch the pickpocket", Color(1.0, 0.86, 0.55), Color(0.10, 0.06, 0.12),
		Color(1.0, 0.65, 0.35, 0.22))
