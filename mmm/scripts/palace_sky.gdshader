shader_type canvas_item;

// WHAT THE PALACE STANDS IN (2026-11-12, level.gd _fit_ground_to_board puts this where the lawn was): a
// palace of the MIND, so it floats in a night sky -- deep indigo, slow clouds of faint violet and teal
// nebula, stars at two sizes that twinkle, and wisps of mist drifting past. Not plain darkness (asked
// for "something interesting"), but dim and cool throughout, so the rooms' colors stay the brightest
// and most saturated things on the screen. In WORLD coordinates (the layer follows the camera), so the
// sky stays put as the camera moves through the rooms.

varying vec2 world;
uniform vec2 origin = vec2(0.0);
varying vec4 tint;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// board space from the rect's own place (level.gd sets `origin`), not MODEL_MATRIX, which moves with
	// the camera here (see castle_floor.gdshader): the hall's slabs would slide under the rooms
	world = origin + VERTEX;
	tint = COLOR;
}

// one star layer: at most one star in each `cell`-sized square, `p` of the squares have one
vec3 stars(vec2 w, float cell, float p, float size, float t) {
	vec2 c = floor(w / cell);
	float h = hash(c + 0.37);
	if (h < 1.0 - p) {
		return vec3(0.0);
	}
	vec2 at = (c + 0.2 + 0.6 * vec2(hash(c + 1.3), hash(c + 7.9))) * cell;
	float d = length(w - at);
	float lum = (h - (1.0 - p)) / p;
	float tw = 0.65 + 0.35 * sin(t * (0.8 + 2.2 * hash(c + 4.2)) + h * 60.0);
	float core = 1.0 - smoothstep(0.0, size, d);
	float glow = (1.0 - smoothstep(0.0, size * 4.0, d)) * 0.25;
	vec3 hue = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.92, 0.80), hash(c + 9.1));
	return hue * (core + glow) * (0.45 + 0.55 * lum) * tw;
}

// TRIAL (2026-11-12): 0 the starry sky, 1 a moat of dark water at night, 2 a sea of moonlit clouds,
// 3 the dark GREAT HALL the rooms stand in
uniform int style = 3;

vec3 dark_hall(vec2 w, float t) {
	// big slabs of near-black marble, three tiles across, faintly veined; gold inlay lines between them and
	// a gold ring on one slab in four
	float S = 120.0;       // three tiles: at two the gold lines read as graph paper
	vec2 id = floor(w / S);
	vec2 f = w - id * S;
	float edge = min(min(f.x, S - f.x), min(f.y, S - f.y));
	// (hairlines sized in screen pixels, `px`: see castle_floor.gdshader -- fixed widths flashed as the
	// camera glided between rooms)
	float px = max(fwidth(w.x), 0.001);
	vec3 col = vec3(0.065, 0.068, 0.085) * (0.88 + 0.18 * hash(id + 2.0));
	float v = fbm(w / 70.0 + id * 0.3);
	float av = fwidth(v);
	col += vec3(0.03) * (1.0 - smoothstep(0.012 - av, 0.012 + av, abs(v - 0.5))) * smoothstep(0.03, 0.010, av);
	col *= 0.94 + 0.10 * fbm(w / 25.0);
	vec3 gold = vec3(0.62, 0.48, 0.22);
	float lw = max(1.0, 1.2 * px);
	float inlay = 1.0 - smoothstep(0.0, lw, edge);
	float r = length(f - S * 0.5);
	float ring = (1.0 - smoothstep(0.0, lw, abs(r - 18.0))) + (1.0 - smoothstep(0.0, lw * 0.8, abs(r - 12.0))) * 0.6;
	ring *= step(0.5, mod(id.x, 2.0)) * step(0.5, mod(id.y, 2.0));       // one slab in four
	float g = clamp(inlay + ring, 0.0, 1.0);
	// (the candlelight is the candelabra's own, drawn with them: hall_decor.gd)
	vec3 warm = vec3(0.0);
	col += warm * 0.7;
	col = mix(col, gold * (0.40 + 1.4 * length(warm)), g * 0.55);
	return col;
}

vec3 moat(vec2 w, float t) {
	// dark water, its surface in two sets of slow waves crossing; the slope of the surface catches the
	// moonlight in soft bands, and now and then a glint
	vec2 a = w / 150.0 + vec2(t * 0.025, t * 0.015);
	vec2 b = w / 95.0 - vec2(t * 0.02, -t * 0.018);
	float h = fbm(a) + 0.6 * fbm(b);
	float hx = fbm(a + vec2(0.04, 0.0)) + 0.6 * fbm(b + vec2(0.04, 0.0));
	float hy = fbm(a + vec2(0.0, 0.04)) + 0.6 * fbm(b + vec2(0.0, 0.04));
	vec2 slope = vec2(hx - h, hy - h) / 0.04;
	float lit = clamp(dot(slope, vec2(-0.5, -0.8)) * 0.35 + 0.5, 0.0, 1.0);
	vec3 col = mix(vec3(0.025, 0.06, 0.085), vec3(0.06, 0.13, 0.17), smoothstep(0.2, 0.8, lit));
	// the moon's path: a broad soft band of light on the water, broken up by the waves
	col += vec3(0.22, 0.28, 0.34) * pow(smoothstep(0.55, 0.95, lit), 3.0) * 0.7;
	float g = noise(w / 4.0 + vec2(t * 0.5, -t * 0.3));
	col += vec3(0.75, 0.82, 0.95) * pow(g, 24.0) * smoothstep(0.65, 0.9, lit) * 1.2;
	return col;
}

vec3 cloud_sea(vec2 w, float t) {
	// a night sky far below, and over it three layers of cloud drifting at their own speeds, the
	// nearer ones bigger and brighter, each lit on its upper-left side by the moon (the cloud's
	// thickness a little toward the light, less its own)
	vec3 col = vec3(0.025, 0.035, 0.08) + stars(w, 13.0, 0.08, 0.9, t) * 0.5;
	for (int i = 0; i < 3; i++) {
		float k = float(i);
		float sc = 260.0 - k * 60.0;
		vec2 drift = vec2(t * (0.006 + k * 0.006), t * 0.002);
		vec2 p = w / sc + drift + k * 13.7;
		float d = fbm(p);
		float dl = fbm(p + vec2(-0.05, -0.08));
		float c = smoothstep(0.48 - k * 0.02, 0.70, d);
		float light = clamp((dl - d) * 6.0 + 0.5, 0.0, 1.0);
		vec3 cc = mix(vec3(0.09, 0.10, 0.17), vec3(0.42 + k * 0.05, 0.45 + k * 0.05, 0.58 + k * 0.04), light);
		col = mix(col, cc, c * (0.55 + 0.15 * k));
	}
	return col;
}

void fragment() {
	float t = TIME;
	if (style == 3) {
		COLOR = vec4(dark_hall(world, t), 1.0) * tint;
	} else if (style == 1) {
		COLOR = vec4(moat(world, t), 1.0) * tint;
	} else if (style == 2) {
		COLOR = vec4(cloud_sea(world, t), 1.0) * tint;
	} else {
	vec3 col = vec3(0.030, 0.034, 0.075);
	// nebula: two slow clouds, violet and teal
	float n1 = fbm(world / 300.0 + vec2(t * 0.006, 0.0));
	float n2 = fbm(world / 220.0 + vec2(5.2, t * 0.004));
	col += vec3(0.13, 0.06, 0.18) * smoothstep(0.45, 0.80, n1);
	col += vec3(0.03, 0.10, 0.13) * smoothstep(0.50, 0.82, n2);
	// stars: many faint small ones, a few brighter
	col += stars(world, 11.0, 0.10, 0.9, t) * 0.55;
	col += stars(world + 300.0, 47.0, 0.20, 1.5, t * 0.7) * 0.85;
	// mist drifting past
	float m = fbm(world / 130.0 + vec2(t * 0.020, t * 0.007));
	col += vec3(0.09, 0.10, 0.15) * smoothstep(0.55, 0.85, m) * 0.6;
	COLOR = vec4(col, 1.0) * tint;
	}
}
