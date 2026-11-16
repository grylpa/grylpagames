extends RefCounted

# TIP THE SCALES' PUZZLE: the crates, the hidden weights, the scale clues, and the logic that solves them.
# Ported from the rules of Mor's desktop "Scales" (mor/einstein/plan.md, assumptions.md), itself built on
# the Einstein riddle's model: a COLOR is a row, its crates A.. are the row's tiles, and a crate's weight
# plays the part of its column.
#
#   - `rows` colors of `cols` crates; within a color the crates weigh 1..cols kg, each weight once. Crates
#     of different colors may weigh the same.
#   - Every clue is a balance scale that is TRUE for the hidden weights (see the types below).
#   - The generator adds random true clues until LOGIC ALONE (the two rule families below, applied to a
#     fixpoint) fixes every crate, removes every clue that is not needed, then adds the level's spare
#     clues. So each puzzle has exactly one answer and needs no guessing.
#
# The solver keeps one bit mask of possible weights per crate (bit v-1 = v kg). Its rules:
#   CLUE RULE   for a clue, try every combination of its crates' remaining weights (at most four crates)
#               and keep only the weights some satisfying combination uses (two crates of one color never
#               share a weight).
#   COLOR RULES a crate down to one weight takes it from the rest of its color; a weight only one crate
#               of a color can still take is that crate's.
#
# Pure logic, no nodes: generate() can run on a worker thread.

enum T { EQUAL, OFFSET, SUM_EQ, SUM_LIGHTER, PAIRS_EQ, BETWEEN, HEAVIER, SUM_HEAVIER }
const N_TYPES: int = 8
# how many crates each type names
const ARITY: Array = [2, 2, 3, 3, 4, 3, 2, 3]

var rows: int = 3
var cols: int = 4
var answer: PackedInt32Array = PackedInt32Array()     # per crate, its weight (1..cols)
var clues: Array = []                                 # each {"t": T, "c": [crate ids], "k": int}
var depth: int = 0                                    # rounds of deduction the puzzle needs

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _full: int = 0
var _vals: Array = []        # mask -> Array of its weights
var _by_crate: Array = []    # crate -> indices of the clues naming it (for the solver's dirty tracking)

func _init(n_rows: int = 3, n_cols: int = 4, seed_i: int = -1) -> void:
	rows = n_rows
	cols = n_cols
	_full = (1 << cols) - 1
	_vals.resize(1 << cols)
	for m in (1 << cols):
		var vs: Array = []
		for v in range(1, cols + 1):
			if m & (1 << (v - 1)):
				vs.append(v)
		_vals[m] = vs
	if seed_i >= 0:
		_rng.seed = seed_i
	else:
		_rng.randomize()

func n_crates() -> int:
	return rows * cols

func row_of(i: int) -> int:
	return i / cols

func full_masks() -> PackedInt32Array:
	var m: PackedInt32Array = PackedInt32Array()
	m.resize(n_crates())
	m.fill(_full)
	return m

static func bit(v: int) -> int:
	return 1 << (v - 1)

static func popcount(m: int) -> int:
	var n: int = 0
	while m != 0:
		m &= m - 1
		n += 1
	return n

static func single_value(m: int) -> int:
	# the weight of a one-bit mask, 0 otherwise
	if m == 0 or (m & (m - 1)) != 0:
		return 0
	var v: int = 1
	while (m & 1) == 0:
		m >>= 1
		v += 1
	return v

static func holds(t: int, v: Array, k: int) -> bool:
	match t:
		T.EQUAL:
			return v[0] == v[1]
		T.OFFSET:
			return v[0] == v[1] + k
		T.SUM_EQ:
			return v[0] + v[1] == v[2]
		T.SUM_LIGHTER:
			return v[0] + v[1] < v[2]
		T.PAIRS_EQ:
			return v[0] + v[1] == v[2] + v[3]
		T.BETWEEN:
			return (v[1] < v[0] and v[0] < v[2]) or (v[2] < v[0] and v[0] < v[1])
		T.HEAVIER:
			return v[0] > v[1]
		T.SUM_HEAVIER:
			return v[0] + v[1] > v[2]
	return false

# ---------------------------------------------------------------------------------------------------
# GENERATION

# `mix`: a weight per clue type (N_TYPES); `spare`: clues added after minimizing; `k_max`: the largest
# brass weight on an OFFSET clue; `tries`: puzzles generated, the deepest kept.
func generate(mix: Array, spare: int, k_max: int, tries: int = 1) -> void:
	var best_ans: PackedInt32Array = PackedInt32Array()
	var best_clues: Array = []
	var best_depth: int = -1
	for _t in maxi(1, tries):
		_generate_once(mix, spare, k_max)
		if depth > best_depth:
			best_depth = depth
			best_ans = answer.duplicate()
			best_clues = clues.duplicate(true)
	answer = best_ans
	clues = best_clues
	depth = best_depth
	_index_clues()

func _generate_once(mix: Array, spare: int, k_max: int) -> void:
	answer = PackedInt32Array()
	answer.resize(n_crates())
	for r in rows:
		var ws: Array = range(1, cols + 1)
		_shuffle(ws)
		for c in cols:
			answer[r * cols + c] = ws[c]
	clues = []
	var keys: Dictionary = {}
	var masks: PackedInt32Array = full_masks()
	var guard: int = 0
	while not _solved(masks) and guard < 600:
		guard += 1
		var cl: Dictionary = _random_clue(mix, k_max)
		if cl.is_empty():
			continue
		var key: String = clue_key(cl)
		if keys.has(key):
			continue
		keys[key] = true
		clues.append(cl)
		_index_clues()
		propagate(masks, clues, [clues.size() - 1])
	# MINIMIZE: drop every clue the rest can do without
	var order: Array = range(clues.size())
	_shuffle(order)
	var keep: Array = []
	for i in clues.size():
		keep.append(true)
	for i in order:
		keep[i] = false
		var trial: Array = []
		for j in clues.size():
			if keep[j]:
				trial.append(clues[j])
		if not solves_by_logic(trial):
			keep[i] = true
	var kept: Array = []
	for j in clues.size():
		if keep[j]:
			kept.append(clues[j])
	clues = kept
	# the level's spare clues: more to go on, never a different answer (they are true)
	var added: int = 0
	guard = 0
	keys.clear()
	for cl in clues:
		keys[clue_key(cl)] = true
	while added < spare and guard < 200:
		guard += 1
		var cl2: Dictionary = _random_clue(mix, k_max)
		if cl2.is_empty() or keys.has(clue_key(cl2)):
			continue
		keys[clue_key(cl2)] = true
		clues.append(cl2)
		added += 1
	_shuffle(clues)
	_index_clues()
	depth = depth_of(clues)

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp

func _pick_type(mix: Array) -> int:
	var total: float = 0.0
	for w in mix:
		total += float(w)
	var x: float = _rng.randf() * total
	for t in N_TYPES:
		x -= float(mix[t])
		if x < 0.0:
			return t
	return T.HEAVIER

func _crate_with(row: int, v: int) -> int:
	for c in cols:
		if answer[row * cols + c] == v:
			return row * cols + c
	return -1

func _rand_crate() -> int:
	return _rng.randi_range(0, n_crates() - 1)

# A random clue of a random type, TRUE for the answer; {} if this try found none.
func _random_clue(mix: Array, k_max: int) -> Dictionary:
	var t: int = _pick_type(mix)
	for _try in 40:
		match t:
			T.EQUAL:
				if rows < 2:
					return {}
				var a: int = _rand_crate()
				var r2: int = _rng.randi_range(0, rows - 2)
				if r2 >= row_of(a):
					r2 += 1
				return {"t": t, "c": [a, _crate_with(r2, answer[a])], "k": 0}
			T.OFFSET:
				var a: int = _rand_crate()
				var b: int = _rand_crate()
				var k: int = answer[a] - answer[b]
				if a != b and k >= 1 and k <= k_max:
					return {"t": t, "c": [a, b], "k": k}
			T.SUM_EQ:
				var a: int = _rand_crate()
				var b: int = _rand_crate()
				var s: int = answer[a] + answer[b]
				if a == b or s > cols:
					continue
				var c: int = _crate_with(_rng.randi_range(0, rows - 1), s)
				if c != a and c != b:
					return {"t": t, "c": [a, b, c], "k": 0}
			T.SUM_LIGHTER, T.SUM_HEAVIER, T.BETWEEN:
				var a: int = _rand_crate()
				var b: int = _rand_crate()
				var c: int = _rand_crate()
				if a == b or a == c or b == c:
					continue
				if holds(t, [answer[a], answer[b], answer[c]], 0):
					return {"t": t, "c": [a, b, c], "k": 0}
			T.PAIRS_EQ:
				var cs: Array = [_rand_crate(), _rand_crate(), _rand_crate(), _rand_crate()]
				if cs[0] == cs[1] or cs[0] == cs[2] or cs[0] == cs[3] or cs[1] == cs[2] \
						or cs[1] == cs[3] or cs[2] == cs[3]:
					continue
				if holds(t, [answer[cs[0]], answer[cs[1]], answer[cs[2]], answer[cs[3]]], 0):
					return {"t": t, "c": cs, "k": 0}
			T.HEAVIER:
				var a: int = _rand_crate()
				var b: int = _rand_crate()
				if a != b and answer[a] > answer[b]:
					return {"t": t, "c": [a, b], "k": 0}
	return {}

# The same fact, however it is written, has one key (A + B = C and B + A = C).
static func clue_key(cl: Dictionary) -> String:
	var t: int = int(cl["t"])
	var c: Array = (cl["c"] as Array).duplicate()
	match t:
		T.EQUAL:
			c.sort()
		T.SUM_EQ, T.SUM_LIGHTER, T.SUM_HEAVIER:
			var p: Array = [c[0], c[1]]
			p.sort()
			c = [p[0], p[1], c[2]]
		T.PAIRS_EQ:
			var p1: Array = [c[0], c[1]]
			p1.sort()
			var p2: Array = [c[2], c[3]]
			p2.sort()
			if p2[0] < p1[0]:
				c = [p2[0], p2[1], p1[0], p1[1]]
			else:
				c = [p1[0], p1[1], p2[0], p2[1]]
		T.BETWEEN:
			var e: Array = [c[1], c[2]]
			e.sort()
			c = [c[0], e[0], e[1]]
	return "%d:%s:%d" % [t, str(c), int(cl["k"])]

func _index_clues() -> void:
	_by_crate.clear()
	_by_crate.resize(n_crates())
	for i in n_crates():
		_by_crate[i] = []
	for ci in clues.size():
		for c in clues[ci]["c"]:
			if not (_by_crate[c] as Array).has(ci):
				(_by_crate[c] as Array).append(ci)

# ---------------------------------------------------------------------------------------------------
# THE SOLVER

func _solved(masks: PackedInt32Array) -> bool:
	for m in masks:
		if single_value(m) == 0:
			return false
	return true

# What one clue allows: per crate of the clue, the mask of weights some satisfying combination uses.
# [] when no combination satisfies it (a contradiction).
func clue_support(cl: Dictionary, masks: PackedInt32Array) -> Array:
	var t: int = int(cl["t"])
	var k: int = int(cl["k"])
	var cs: Array = cl["c"]
	var n: int = cs.size()
	var sup: Array = []
	sup.resize(n)
	sup.fill(0)
	var any: bool = false
	var v0s: Array = _vals[masks[cs[0]]]
	var v1s: Array = _vals[masks[cs[1]]]
	var same01: bool = row_of(cs[0]) == row_of(cs[1])
	if n == 2:
		for a in v0s:
			for b in v1s:
				if same01 and a == b:
					continue
				if holds(t, [a, b], k):
					sup[0] |= bit(a)
					sup[1] |= bit(b)
					any = true
	elif n == 3:
		var v2s: Array = _vals[masks[cs[2]]]
		var same02: bool = row_of(cs[0]) == row_of(cs[2])
		var same12: bool = row_of(cs[1]) == row_of(cs[2])
		for a in v0s:
			for b in v1s:
				if same01 and a == b:
					continue
				for c in v2s:
					if (same02 and a == c) or (same12 and b == c):
						continue
					if holds(t, [a, b, c], k):
						sup[0] |= bit(a)
						sup[1] |= bit(b)
						sup[2] |= bit(c)
						any = true
	else:
		var v2s: Array = _vals[masks[cs[2]]]
		var v3s: Array = _vals[masks[cs[3]]]
		var r: Array = [row_of(cs[0]), row_of(cs[1]), row_of(cs[2]), row_of(cs[3])]
		for a in v0s:
			for b in v1s:
				if r[0] == r[1] and a == b:
					continue
				for c in v2s:
					if (r[0] == r[2] and a == c) or (r[1] == r[2] and b == c):
						continue
					for d in v3s:
						if (r[0] == r[3] and a == d) or (r[1] == r[3] and b == d) or (r[2] == r[3] and c == d):
							continue
						if a + b == c + d:
							sup[0] |= bit(a)
							sup[1] |= bit(b)
							sup[2] |= bit(c)
							sup[3] |= bit(d)
							any = true
	return sup if any else []

# The color rules on one row: changed crates appended to `changed`; false on a contradiction.
func _row_rules(masks: PackedInt32Array, r: int, changed: Array) -> bool:
	var base: int = r * cols
	var again: bool = true
	while again:
		again = false
		for c in cols:
			var v: int = single_value(masks[base + c])
			if v == 0:
				continue
			for c2 in cols:
				if c2 != c and (masks[base + c2] & bit(v)):
					masks[base + c2] &= ~bit(v)
					if masks[base + c2] == 0:
						return false
					changed.append(base + c2)
					again = true
		for v in range(1, cols + 1):
			var who: int = -1
			var n: int = 0
			for c in cols:
				if masks[base + c] & bit(v):
					n += 1
					who = base + c
			if n == 0:
				return false
			if n == 1 and masks[who] != bit(v):
				masks[who] = bit(v)
				changed.append(who)
				again = true
	return true

# Apply every rule until nothing changes. `start` (clue indices) limits the first pass to those clues;
# null = all. Returns false on a contradiction. Uses the clue index of THIS puzzle (`_by_crate`) only when
# `list` is `clues`; for any other list it re-applies every clue each pass.
func propagate(masks: PackedInt32Array, list: Array, start = null) -> bool:
	var own: bool = list == clues and _by_crate.size() == n_crates()
	var pending: Dictionary = {}
	if start == null or not own:
		for i in list.size():
			pending[i] = true
	else:
		for i in start:
			pending[i] = true
	var rows_dirty: Dictionary = {}
	for r in rows:
		rows_dirty[r] = true
	var guard: int = 0
	while (not pending.is_empty() or not rows_dirty.is_empty()) and guard < 2000:
		guard += 1
		var changed: Array = []
		for ci in pending.keys():
			var cl: Dictionary = list[ci]
			var sup: Array = clue_support(cl, masks)
			if sup.is_empty():
				return false
			var cs: Array = cl["c"]
			for j in cs.size():
				var nm: int = masks[cs[j]] & int(sup[j])
				if nm != masks[cs[j]]:
					masks[cs[j]] = nm
					changed.append(cs[j])
		pending.clear()
		for r in rows_dirty.keys():
			if not _row_rules(masks, r, changed):
				return false
		rows_dirty.clear()
		for i in changed:
			rows_dirty[row_of(i)] = true
			if own:
				for ci in _by_crate[i]:
					pending[ci] = true
		if not own and not changed.is_empty():
			for i in list.size():
				pending[i] = true
		if changed.is_empty():
			rows_dirty.clear()
	return true

func solves_by_logic(list: Array) -> bool:
	var masks: PackedInt32Array = full_masks()
	if not propagate(masks, list):
		return false
	return _solved(masks)

# Rounds of deduction: each round applies every rule once to the state the last round left.
func depth_of(list: Array) -> int:
	var masks: PackedInt32Array = full_masks()
	var d: int = 0
	while not _solved(masks) and d < 200:
		var before: PackedInt32Array = masks.duplicate()
		var next: PackedInt32Array = masks.duplicate()
		for cl in list:
			var sup: Array = clue_support(cl, before)
			if sup.is_empty():
				return d
			var cs: Array = cl["c"]
			for j in cs.size():
				next[cs[j]] &= int(sup[j])
		var ignored: Array = []
		for r in rows:
			_row_rules(next, r, ignored)
		d += 1
		if next == masks:
			return d
		masks = next
	return d

# Solutions by search (tests only): up to `limit`.
func count_solutions(list: Array, limit: int = 2) -> int:
	var masks: PackedInt32Array = full_masks()
	if not propagate(masks, list):
		return 0
	return _count(masks, list, limit)

func _count(masks: PackedInt32Array, list: Array, limit: int) -> int:
	var pick: int = -1
	var best: int = 99
	for i in masks.size():
		var p: int = popcount(masks[i])
		if p > 1 and p < best:
			best = p
			pick = i
	if pick < 0:
		return 1
	var n: int = 0
	for v in _vals[masks[pick]]:
		var m2: PackedInt32Array = masks.duplicate()
		m2[pick] = bit(v)
		if propagate(m2, list):
			n += _count(m2, list, limit)
			if n >= limit:
				return n
	return n

# ---------------------------------------------------------------------------------------------------
# THE HINT: one deduction from the player's board, the simplest available, and why.
#
# {} when the board is solved. Otherwise {"kind": "row"|"clue", "clue": index or -1, "row": r,
# "remove": {crate: mask of weights to take away}, "place": {crate: weight}}. The color rule first (a
# weight only one crate of a color can still take), then clues naming fewer crates before more, the
# `live` ones before any set aside. `masks` are the player's, which always still hold the true weights
# (the game refuses anything else), so a step always exists until the board is solved.
func next_step(masks: PackedInt32Array, live: Array) -> Dictionary:
	if _solved(masks):
		return {}
	# a crate down to one weight that the board has not settled yet
	for i in masks.size():
		if single_value(masks[i]) != 0:
			for c2 in cols:
				var j: int = row_of(i) * cols + c2
				if j != i and (masks[j] & masks[i]):
					return {"kind": "row", "clue": -1, "row": row_of(i), "remove": {j: masks[j] & masks[i]}, "place": {}}
	for r in rows:
		for v in range(1, cols + 1):
			var who: int = -1
			var n: int = 0
			for c in cols:
				if masks[r * cols + c] & bit(v):
					n += 1
					who = r * cols + c
			if n == 1 and masks[who] != bit(v):
				return {"kind": "row", "clue": -1, "row": r, "remove": {}, "place": {who: v}}
	var order: Array = range(clues.size())
	order.sort_custom(func(a, b) -> bool:
		var la: int = 0 if live.has(a) else 1
		var lb: int = 0 if live.has(b) else 1
		if la != lb:
			return la < lb
		return (clues[a]["c"] as Array).size() < (clues[b]["c"] as Array).size())
	for ci in order:
		var cl: Dictionary = clues[ci]
		var sup: Array = clue_support(cl, masks)
		if sup.is_empty():
			continue
		var remove: Dictionary = {}
		var place: Dictionary = {}
		var cs: Array = cl["c"]
		for j in cs.size():
			var gone: int = masks[cs[j]] & ~int(sup[j])
			if gone != 0:
				remove[cs[j]] = gone
				var left: int = masks[cs[j]] & int(sup[j])
				if single_value(left) != 0:
					place[cs[j]] = single_value(left)
		if not remove.is_empty():
			return {"kind": "clue", "clue": ci, "row": -1, "remove": remove, "place": place}
	return {}
