shader_type canvas_item;

// GORILLA'S GROUND: a RAINFOREST FLOOR (2026-10-30) in place of the short lawn -- dark rich soil with
// soft patches of moss, a litter of small fallen leaves, and dappled light from a canopy overhead.
// Continuous, in the field's own coordinates (it follows the board), so nothing lines up with the
// cells. Kept LOW in contrast and darker than the room's colored floor, so the room, the food and the
// creatures stay the brightest things on the board.

uniform float seed = 13.0;

varying vec2 world;

void vertex() {
	world = VERTEX;
}

// Kept small before hashing: at the board's world coordinates a plain fract-hash ran out of float
// precision and the noise came out in hard-edged squares.
float hash(vec2 p) {
	p = mod(p + seed * 7.0, 289.0);
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 7.0) * 0.30 + noise(p * 4.3 + 3.0) * 0.15;
}

void fragment() {
	vec2 w = world;
	// soil: dark brown, a little grain
	vec3 col = mix(vec3(0.20, 0.14, 0.09), vec3(0.28, 0.20, 0.12), fbm(w / 40.0));
	col *= 0.93 + 0.12 * hash(floor(w / 1.4));
	// moss in soft patches, a rich green with a little yellow where it is thick
	float moss = smoothstep(0.42, 0.66, fbm(w / 120.0 + 5.0));
	vec3 moss_c = mix(vec3(0.15, 0.30, 0.10), vec3(0.26, 0.40, 0.12), noise(w / 3.0) * 0.6 + moss * 0.4);
	col = mix(col, moss_c, moss * 0.9);
	// leaf litter: small fallen leaves, each in its own little cell, turned its own way, thinner where
	// the moss is
	for (int layer = 0; layer < 2; layer++) {
		float sz = layer == 0 ? 9.0 : 6.5;
		vec2 q = w / sz + float(layer) * 17.3;
		vec2 id = floor(q);
		vec2 lp = fract(q) - 0.5 - (vec2(hash(id), hash(id + 3.1)) - 0.5) * 0.45;
		float ang = hash(id + 9.7) * 6.2832;
		vec2 rp = vec2(cos(ang) * lp.x + sin(ang) * lp.y, -sin(ang) * lp.x + cos(ang) * lp.y);
		float leaf = 1.0 - smoothstep(0.80, 1.0, length(rp * vec2(2.3, 5.0)));
		float present = step(0.74 + moss * 0.2, hash(id + 1.9));
		vec3 leaf_c = mix(vec3(0.46, 0.27, 0.10), vec3(0.55, 0.42, 0.16), hash(id + 5.5));
		leaf_c = mix(leaf_c, vec3(0.30, 0.36, 0.13), step(0.8, hash(id + 2.2)));
		// a darker midrib down the leaf
		leaf_c *= 1.0 - 0.25 * (1.0 - smoothstep(0.0, 0.03, abs(rp.y)));
		col = mix(col, leaf_c * (0.85 + 0.25 * hash(id)), leaf * present * 0.85);
	}
	// dappled canopy light: soft warm spots, and the shade between them
	float dapple = smoothstep(0.58, 0.80, fbm(w / 75.0 + 11.0));
	col *= 0.86 + 0.12 * fbm(w / 200.0);
	col += vec3(0.20, 0.17, 0.07) * dapple * 0.55;
	COLOR = vec4(col, 1.0);
}
