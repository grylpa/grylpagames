shader_type canvas_item;

// THE STAKEOUT, three-quarter view (2026-11-15, the third try). Seen steeply from above, as an old
// top-down adventure game draws a town: the square and its EIGHT STREETS laid out flat (each answer
// direction is a street), the buildings between the streets drawn with their roofs AND the front
// wall that faces us, windows lit here and there, lamp posts at the street mouths standing up the
// screen, a round fountain in the middle, rain. The people are agent.gd's, drawn over.
//
// Why this view: straight down (the first try) made people shapes and lost the story; the street
// view (the second) brought people back but blurred the eight directions into a circle on a
// perspective floor and shrank the umbrellas' prints to thin domes -- both the WHAT and the WHERE got
// harder to catch. This keeps the top view's geometry and prints and the street view's people.
//
// FAIRNESS: the square, the streets, the lamps and the roofs are the same under a 45-degree turn.
// Only the front walls break that (they face us, at the top of the square), and they stand OUTSIDE
// the ring of spots, behind no one.
//
// Lights, driven by level.gd: `flash` (lightning -- the square only MODERATELY brighter, so the
// people, lit strongly by agent.gd, stand out), `mask` (rain running down the glass we look through),
// `lamps` (warm pools at the street mouths, for the answer). Laid out from CENTER and TILE.

uniform vec2 rect_pos = vec2(0.0);
uniform vec2 rect_size = vec2(680.0, 788.0);
uniform vec2 center = vec2(340.0, 394.0);
uniform float tile = 40.0;
uniform float flash = 0.0;
uniform float mask = 0.0;
uniform float lamps = 0.0;
uniform float plaza_r = 3.45;           // the open square's radius, tiles
uniform float lamp_r = 3.45;            // the lamp posts, at the kerb of each street's mouth
uniform float half_w = 0.72;            // a street's half width
uniform float wall_h = 0.55;            // how much of a front wall shows below a roof, tiles

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// distance to the nearest of the 8 street axes, and the position along it
vec2 street_coords(vec2 d) {
	float ang = atan(d.y, d.x);
	float k = round(ang / (PI * 0.25));
	float a = ang - k * PI * 0.25;
	float r = length(d);
	return vec2(abs(r * sin(a)), r * cos(a));
}

bool is_roof(vec2 d) {
	return length(d) > plaza_r + 0.15 && street_coords(d).x > half_w + 0.15;
}

void fragment() {
	vec2 p = rect_pos + UV * rect_size;
	vec2 d = (p - center) / tile;
	float r = length(d);
	float px = 1.2 / tile;
	vec2 sc = street_coords(d);
	vec3 warm = vec3(1.0, 0.78, 0.48);

	// --- the ground: cobbles in courses round the square, a running grid along the streets -------
	float in_plaza = 1.0 - smoothstep(plaza_r - px, plaza_r + px, r);
	float course = r / 0.30;
	float blocks = (atan(d.y, d.x) / TAU + 0.5) * floor(max(6.0, r * 21.0));
	vec2 cob = mix(vec2(sc.y / 0.30, sc.x / 0.26 + 0.5 * floor(sc.y / 0.30)),
		vec2(blocks + 0.5 * floor(course), course), in_plaza);
	vec2 cf = fract(cob);
	float joint = smoothstep(0.0, 0.10, min(min(cf.x, 1.0 - cf.x), min(cf.y, 1.0 - cf.y)));
	vec3 col = vec3(0.115, 0.122, 0.140) * (0.86 + 0.24 * hash(floor(cob))) * (0.72 + 0.28 * joint);
	float wet = smoothstep(0.55, 0.80, noise(p / 11.0));
	col = mix(col, col * 0.62, wet * 0.6);
	// kerbs along the streets and round the square
	float kerb = max((1.0 - smoothstep(0.0, 0.06, abs(sc.x - half_w))) * step(plaza_r, r),
		(1.0 - smoothstep(0.0, 0.06, abs(r - plaza_r))) * step(half_w, sc.x));
	col = mix(col, vec3(0.20, 0.20, 0.21), kerb * 0.8);
	// the fountain: a round basin of dark water inside a stone rim, a bowl in the middle
	float basin = 1.0 - smoothstep(1.05 - px, 1.05 + px, r);
	float rim = basin * smoothstep(0.88 - px, 0.88 + px, r);
	vec3 water = vec3(0.03, 0.05, 0.07) + vec3(0.04, 0.05, 0.07) * noise(d * 5.0 + TIME * 0.5);
	float ripple = 0.5 + 0.5 * sin(r * 26.0 - TIME * 3.0);
	water += vec3(0.03, 0.04, 0.05) * ripple * (1.0 - smoothstep(0.2, 0.85, r));
	col = mix(col, water, basin);
	col = mix(col, vec3(0.24, 0.23, 0.22), rim);
	float bowl = 1.0 - smoothstep(0.30 - px, 0.30 + px, r);
	col = mix(col, vec3(0.26, 0.25, 0.24) * (0.8 + 0.2 * (1.0 - r / 0.3)), bowl);

	// --- the buildings between the streets: roofs, and the front wall facing us ----------------
	bool roof = is_roof(d);
	bool wall = !roof && is_roof(d - vec2(0.0, wall_h));
	if (roof) {
		vec2 rr = vec2(sc.y, sc.x);
		float ridge = smoothstep(0.0, 0.08, abs(fract(rr.x / 0.9) - 0.5) - 0.40);
		float slates = 0.85 + 0.15 * hash(floor(vec2(rr.x / 0.22, rr.y / 0.30)));
		col = vec3(0.075, 0.072, 0.085) * slates * (0.8 + 0.2 * ridge);
	} else if (wall) {
		// how far down the wall, 0 under the eaves .. 1 at the street
		float wy = 0.0;
		for (int k = 1; k <= 8; k++) {
			if (is_roof(d - vec2(0.0, wall_h * float(k) / 8.0))) {
				wy = float(k) / 8.0;
				break;
			}
		}
		vec3 brick = vec3(0.13, 0.095, 0.085) * (0.9 + 0.1 * hash(floor(p / vec2(6.0, 3.0))));
		vec2 wg = vec2(d.x / 0.34, wy * 2.0);
		vec2 wf = fract(wg);
		float win = step(0.25, wf.x) * step(wf.x, 0.75) * step(0.2, wy) * step(wy, 0.7);
		float lit_win = step(0.72, hash(floor(wg) + floor(d.x / 3.0)));
		col = mix(brick * (0.75 + 0.25 * wy), mix(vec3(0.03, 0.035, 0.05), warm * 0.6, lit_win), win);
	}

	// --- the light ------------------------------------------------------------------------------
	vec3 lit = col * 0.55;
	float pool = 0.0;
	float heads = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * PI * 0.25;
		// a post at the KERB of each street's mouth (one side, the same for all eight), clear of the
		// queue standing down the middle of the street
		vec2 sdir = vec2(cos(a), sin(a));
		vec2 lp = sdir * lamp_r + vec2(-sdir.y, sdir.x) * (half_w + 0.12);
		float ld = length(d - lp);
		pool += exp(-ld * ld / 1.2);
		// the post stands UP the screen from its foot; the lantern at its top
		float pole = step(abs(d.x - lp.x), 0.04) * step(lp.y - 0.85, d.y) * step(d.y, lp.y);
		lit = mix(lit, vec3(0.05, 0.05, 0.06), pole);
		heads += 1.0 - smoothstep(0.07, 0.16, length(d - lp - vec2(0.0, -0.88)));
	}
	lit += col * warm * pool * 2.5 * lamps * (roof ? 0.2 : 1.0);
	lit += warm * heads * (0.30 + 0.90 * lamps);
	// lightning: the square only moderately brighter -- the people carry the light
	lit = mix(lit, col * vec3(0.80, 0.86, 1.0) * 1.9 + vec3(0.02, 0.03, 0.04), flash);

	// --- the rain: thin slanted streaks, splashes on the stones ---------------------------------
	vec2 q2 = vec2(p.x + p.y * 0.18, p.y);
	vec2 rc = vec2(13.0, 46.0);
	vec2 rg = q2 / rc + vec2(0.0, -TIME * 2.6);
	vec2 rcell = floor(rg);
	vec2 rf = fract(rg) * rc;
	float rx = 2.0 + 9.0 * hash(rcell + 3.1);
	float ry = 8.0 + 26.0 * hash(rcell + 9.7);
	float aw = fwidth(q2.x) * 0.9 + 0.25;
	float rain = (1.0 - smoothstep(0.0, aw, abs(rf.x - rx)))
		* smoothstep(ry, ry + 2.0, rf.y) * (1.0 - smoothstep(ry + 9.0, ry + 11.0, rf.y))
		* step(0.62, hash(rcell + 5.3));
	vec2 sg = p / 15.0;
	vec2 scell = floor(sg);
	float beat = fract(TIME / 1.15 + hash(scell + 1.7));
	vec2 spos = (scell + 0.2 + 0.6 * vec2(hash(scell + 2.3), hash(scell + 4.9))) * 15.0;
	float ring = 1.0 - smoothstep(0.0, 0.35 + fwidth(p.x), abs(length((p - spos) / vec2(1.0, 0.8)) - (0.5 + beat * 3.2)));
	float splash = ring * (1.0 - beat) * step(0.45, hash(scell + 8.1)) * (roof ? 0.0 : 1.0);
	lit += vec3(0.62, 0.68, 0.80) * (rain * (0.16 + 0.30 * flash + 0.10 * lamps) + splash * (0.14 + 0.25 * flash + 0.12 * lamps));

	// --- the mask: rain running down the glass, soft ------------------------------------------
	vec2 g = p / vec2(16.0, 1.0);
	float lane = floor(g.x);
	float lx = fract(g.x);
	float speed = 40.0 + 60.0 * hash(vec2(lane, 3.0));
	float wob = 0.5 + 0.18 * sin(p.y * 0.05 + lane * 2.0);
	float stream = step(0.45, hash(vec2(lane, 7.0))) * exp(-pow((lx - wob) / 0.10, 2.0));
	float head_y = fract(TIME * speed / 600.0 + hash(vec2(lane, 9.0))) * rect_size.y + rect_pos.y;
	stream *= smoothstep(head_y, head_y - 40.0, p.y) * 0.8 + 0.2;
	vec2 bead_i = floor(p / 14.0);
	vec2 bead_c = (bead_i + 0.1 + 0.8 * vec2(hash(bead_i), hash(bead_i + 2.0))) * 14.0;
	float bead_r = 1.2 + 2.2 * hash(bead_i + 6.0);
	float bead = (1.0 - smoothstep(bead_r * 0.5, bead_r, length(p - bead_c))) * step(0.72, hash(bead_i + 5.0));
	vec3 glass = vec3(0.07, 0.085, 0.11) + vec3(0.05, 0.055, 0.07) * noise(p / 70.0)
		+ vec3(0.16, 0.18, 0.22) * stream + vec3(0.20, 0.22, 0.26) * bead;
	lit = mix(lit, glass, mask);

	COLOR = vec4(lit, 1.0);
}
