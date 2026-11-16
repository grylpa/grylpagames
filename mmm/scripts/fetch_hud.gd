extends Control

# MIND PALACE'S STORE-AND-FETCH OVERLAY (2026-11-15). The first version said everything in one small
# gold line ("Carrying teacup   Bring umbrella") and the player was handed the next object without
# noticing; the user: "everything should be much much more in-your-face". So:
#   CARDS        two big cards at the top: CARRYING (the object in hand) and WHERE IS (the map's
#                question, its border pulsing while it is open). Each with the object's badge.
#   ANNOUNCE     a new object in hand or a new question first pops up LARGE in the upper third
#                ("NEW OBJECT / CROWN / Put it in an empty room", "WHERE IS THE / ANCHOR / Tap its room
#                on the map"), holds, then flies up into its card. The game keeps running underneath.
#   POPS         results at a point on the screen (over the pedestal): "STORED", "+8", "That's the
#                teacup", rising and fading.
# Screen space, drawn, never takes input. level.gd owns one (in its own CanvasLayer).

const BADGE: Script = preload("res://mmm/scripts/object_badge.gd")

const CARD_TOP: float = 100.0
const CARD_H: float = 104.0
const CARD_GAP: float = 14.0
const POP_IN_S: float = 0.18
const HOLD_S: float = 1.25
const FLY_S: float = 0.38
const POP_S: float = 1.3
const GOLD: Color = Color(1.0, 0.82, 0.36)
const REQ: Color = Color(1.0, 0.45, 0.30)
const INK: Color = Color(0.06, 0.06, 0.09, 0.90)

var objects: Array = []                   # level.gd's OBJECTS: [symbol, name, color]
var carry: int = -1
var request: int = -1
var _ann: Array = []                      # queued announcements: {"obj", "kind", "t"}
var _pops: Array = []                     # {"text", "color", "pos", "t"}
var _now: float = 0.0
var _req_since: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_now += delta
	if not _ann.is_empty():
		var a: Dictionary = _ann[0]
		if a["t"] < 0.0 and _now >= float(a["after"]):
			a["t"] = _now
		if float(a["t"]) >= 0.0 and _now - float(a["t"]) > POP_IN_S + HOLD_S + FLY_S:
			_ann.pop_front()
	var keep: Array = []
	for p in _pops:
		if _now - float(p["t"]) < POP_S:
			keep.append(p)
	_pops = keep
	queue_redraw()

# `delay`: seconds before the announcement may start -- after a store, so the "STORED" over the pedestal
# is read first instead of sitting under the next object's card.
func set_carry(o: int, announce: bool, delay: float = 0.0) -> void:
	carry = o
	if o >= 0 and announce:
		_ann.append({"obj": o, "kind": "new", "t": -1.0, "after": _now + delay})

# A vault just opened: its object pops up big ("FOUND / CROWN / Remember this room"), holds, and shrinks
# away -- there is no card for it, nothing is carried.
func announce_found(o: int, room: String = "") -> void:
	_ann.append({"obj": o, "kind": "found", "t": -1.0, "after": _now, "room": room})

# The room's name as the player walks in: large, letter-spaced, over the room, then gone.
const ROOM_S: float = 2.2
var _room_name: String = ""
var _room_t: float = -100.0
func show_room(room: String) -> void:
	_room_name = room.to_upper()
	_room_t = _now

# A question on the map goes straight into the BANNER at the top (popping in), not into a big card in the
# middle: there it covered rooms of the map being asked about. The map is framed below the banner.
func set_request(o: int) -> void:
	request = o
	if o >= 0:
		_req_since = _now

const BANNER_H: float = 128.0
func banner_rect() -> Rect2:
	return Rect2(CARD_GAP, CARD_TOP, size.x - 2.0 * CARD_GAP, BANNER_H)

func pop(text: String, color: Color, at: Vector2) -> void:
	_pops.append({"text": text, "color": color, "pos": at, "t": _now})

func clear_all() -> void:
	carry = -1
	request = -1
	_ann.clear()
	_pops.clear()

# The two cards' rects, for the tutorial's caption to keep clear of.
# Only the cards actually showing (an empty Rect2 when neither is).
func cards_rect() -> Rect2:
	var r: Rect2 = Rect2()
	if carry >= 0:
		r = _card_rect(0)
	if request >= 0:
		r = banner_rect() if r.size.x <= 0.0 else r.merge(banner_rect())
	return r

func _card_rect(slot: int) -> Rect2:
	var w: float = (size.x - 3.0 * CARD_GAP) * 0.5
	return Rect2(CARD_GAP + float(slot) * (w + CARD_GAP), CARD_TOP, w, CARD_H)

func _sym(o: int) -> String:
	return str(objects[o][0])

func _name(o: int) -> String:
	return str(objects[o][1]).to_upper()

func _col(o: int) -> Color:
	return objects[o][2]

func _draw() -> void:
	if objects.is_empty():
		return
	# Which card is still being announced (it appears only once the announcement has flown into it).
	var flying: Dictionary = _ann[0] if not _ann.is_empty() else {}
	var hide_carry: bool = false
	var hide_req: bool = false
	for a in _ann:
		if a["kind"] == "new" and int(a["obj"]) == carry:
			hide_carry = true
		if a["kind"] == "bring" and int(a["obj"]) == request:
			hide_req = true
	if carry >= 0 and not hide_carry:
		_draw_card(_card_rect(0), carry, "CARRYING", GOLD, 0.0)
	if request >= 0 and not hide_req:
		_draw_banner(request)
	_draw_room_name()
	if not flying.is_empty() and float(flying["t"]) >= 0.0:
		_draw_announcement(flying)
	for p in _pops:
		_draw_pop(p)

# The map's question: a full-width banner, popping in (scaled through a transform: no new font sizes).
func _draw_banner(o: int) -> void:
	var t: float = _now - _req_since
	var u: float = minf(1.0, t / POP_IN_S)
	var s: float = 0.75 + 0.25 * u + 0.08 * sin(u * PI)
	var r: Rect2 = banner_rect()
	var c: Vector2 = r.get_center()
	var pulse: float = 0.5 + 0.5 * sin(t * 5.0)
	draw_set_transform(c, 0.0, Vector2(s, s))
	var lr: Rect2 = Rect2(-r.size * 0.5, r.size)
	_panel(lr, REQ, 4.0 + 3.0 * pulse)
	var br: float = lr.size.y * 0.34
	var pad: float = lr.size.y * 0.16
	var bc: Vector2 = Vector2(lr.position.x + pad + br, 0.0)
	BADGE.draw(self, bc, br, _sym(o), _col(o))
	var f: Font = get_theme_default_font()
	var tf: Font = MainGlobals.get_text_font()
	var tx: float = bc.x + br + pad
	var tw: float = lr.end.x - tx - pad * 0.6
	var hfs: int = MainGlobals.ui_font_size(16)
	var nfs: int = _fit(f, _name(o), tw, MainGlobals.ui_font_size(30))
	var sfs: int = MainGlobals.ui_font_size(13)
	var y: float = -(hfs + nfs + sfs) * 0.62
	draw_string(f, Vector2(tx, y + hfs), "WHERE IS THE", HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, REQ)
	draw_string(f, Vector2(tx, y + hfs + nfs * 1.15), _name(o), HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color.WHITE)
	draw_string(tf, Vector2(tx, y + hfs + nfs * 1.15 + sfs * 1.6), "Tap its room on the map",
		HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(1, 1, 1, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_room_name() -> void:
	var t: float = _now - _room_t
	if t < 0.0 or t > ROOM_S or _room_name == "":
		return
	var a: float = minf(1.0, t / 0.25) * (1.0 - smoothstep(ROOM_S - 0.6, ROOM_S, t))
	var f: Font = get_theme_default_font()
	var fs: int = MainGlobals.ui_font_size(30)
	var sz: Vector2 = f.get_string_size(_room_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at: Vector2 = Vector2((size.x - sz.x) * 0.5, CARD_TOP + 44.0)   # where the cards are; while walking there are none
	draw_string_outline(f, at, _room_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.75 * a))
	draw_string(f, at, _room_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.93, 0.78, a))

func _draw_card(r: Rect2, o: int, label: String, accent: Color, pulse: float) -> void:
	_panel(r, accent, 3.0 + 3.0 * pulse)
	var br: float = r.size.y * 0.36
	BADGE.draw(self, Vector2(r.position.x + 14.0 + br, r.get_center().y), br, _sym(o), _col(o))
	var f: Font = get_theme_default_font()
	var tx: float = r.position.x + 28.0 + br * 2.0
	var tw: float = r.end.x - tx - 10.0
	draw_string(f, Vector2(tx, r.position.y + 30.0), label, HORIZONTAL_ALIGNMENT_LEFT, tw,
		MainGlobals.ui_font_size(15), accent)
	var nfs: int = _fit(f, _name(o), tw, MainGlobals.ui_font_size(26))
	draw_string(f, Vector2(tx, r.position.y + 30.0 + nfs * 1.25), _name(o), HORIZONTAL_ALIGNMENT_LEFT, tw, nfs, Color.WHITE)

# Laid out ONCE at the big size (font sizes fitted then and kept in the announcement), then drawn
# through a transform as it pops in and flies to its card. Fitting the text to the moving rect asked
# for a new font size every frame, and each new size is rasterized afresh: half a second a frame.
func _draw_announcement(a: Dictionary) -> void:
	var t: float = _now - float(a["t"])
	var o: int = int(a["obj"])
	var is_new: bool = a["kind"] != "bring"
	var is_found: bool = a["kind"] == "found"
	var accent: Color = GOLD if is_new else REQ
	var big_h: float = minf(size.y * 0.19, 230.0)
	var big: Rect2 = Rect2(size.x * 0.06, size.y * 0.27 - big_h * 0.5, size.x * 0.88, big_h)   # above the room's center, where the player usually is
	var slot: Rect2 = _card_rect(0 if is_new else 1)
	var head: String = "FOUND" if is_found else ("NEW OBJECT" if is_new else "WHERE IS THE")
	var sub: String = ("In the %s" % str(a.get("room", "")) if str(a.get("room", "")) != "" else "Remember this room") if is_found else ("Put it in an empty room" if is_new else "Tap its room on the map")
	var f: Font = get_theme_default_font()
	var tf: Font = MainGlobals.get_text_font()
	var br: float = big.size.y * 0.34
	var pad: float = big.size.y * 0.14
	var tw: float = big.size.x - (pad * 2.7 + br * 2.0)
	if not a.has("fs"):
		a["fs"] = [_fit(f, head, tw, int(big.size.y * 0.15)), _fit(f, _name(o), tw, int(big.size.y * 0.27)),
			_fit(tf, sub, tw, int(big.size.y * 0.12))]
	var hfs: int = a["fs"][0]
	var nfs: int = a["fs"][1]
	var sfs: int = a["fs"][2]
	# where it is: 0 = big in the center, 1 = in its card; s = the pop-in's scale
	var k: float = 0.0
	var s: float = 1.0
	if t < POP_IN_S:
		var u: float = t / POP_IN_S
		s = 0.55 + 0.45 * u + 0.12 * sin(u * PI)
	elif t > POP_IN_S + HOLD_S:
		k = clampf((t - POP_IN_S - HOLD_S) / FLY_S, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
	var center: Vector2 = big.get_center().lerp(slot.get_center(), k)
	var scl: float = s * lerpf(1.0, slot.size.x / big.size.x, k)
	if is_found:                          # no card to fly into: it shrinks away where it is
		center = big.get_center()
		scl = s * (1.0 - k)
		if scl < 0.02:
			return
	if k < 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.28 * (1.0 - k) * minf(1.0, t / POP_IN_S)))
	draw_set_transform(center, 0.0, Vector2(scl, scl))
	var r: Rect2 = Rect2(-big.size * 0.5, big.size)
	_panel(r, accent, 5.0)
	var bc: Vector2 = Vector2(r.position.x + pad + br, 0.0)
	BADGE.draw(self, bc, br, _sym(o), _col(o))
	var tx: float = bc.x + br + pad
	var y: float = -(hfs + nfs + sfs) * 0.62
	draw_string(f, Vector2(tx, y + hfs), head, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, accent)
	draw_string(f, Vector2(tx, y + hfs + nfs * 1.15), _name(o), HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color.WHITE)
	draw_string(tf, Vector2(tx, y + hfs + nfs * 1.15 + sfs * 1.6), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs,
		Color(1, 1, 1, 0.80 * (1.0 - k)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_pop(p: Dictionary) -> void:
	var t: float = (_now - float(p["t"])) / POP_S
	var a: float = 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
	var f: Font = get_theme_default_font()
	var fs: int = MainGlobals.ui_font_size(34)
	var sc: float = 0.6 + 0.4 * minf(1.0, t / 0.12)    # popped in by scaling, never a new font size
	var txt: String = str(p["text"])
	var sz: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	sc *= minf(1.0, (size.x - 24.0) / maxf(1.0, sz.x))    # a long one is shrunk to fit the screen
	sz *= minf(1.0, (size.x - 24.0) / maxf(1.0, sz.x))
	var at: Vector2 = Vector2(p["pos"]) + Vector2(0.0, -40.0 - 50.0 * t)
	at.x = clampf(at.x, sz.x * 0.5 + 8.0, size.x - sz.x * 0.5 - 8.0)
	var c: Color = p["color"]
	var full_w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_set_transform(at, 0.0, Vector2(sc, sc))
	draw_string_outline(f, Vector2(-full_w * 0.5, 0.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.85 * a))
	draw_string(f, Vector2(-full_w * 0.5, 0.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(c.r, c.g, c.b, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _panel(r: Rect2, accent: Color, border: float) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = INK
	sb.border_color = accent
	sb.set_border_width_all(int(border))
	sb.set_corner_radius_all(int(minf(18.0, r.size.y * 0.2)))
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	draw_style_box(sb, r)

func _fit(f: Font, txt: String, w: float, fs: int) -> int:
	var fit_fs: int = fs
	while fit_fs > 6 and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fit_fs).x > w:
		fit_fs -= 1
	return fit_fs
