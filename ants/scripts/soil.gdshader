shader_type canvas_item;

// The soil's fine texture, on the ground layer (level.gd's _bg). It only ever nudges the brightness of
// what is drawn there -- the soil, its damp and dry patches -- by a few percent, so the ground stays
// FLAT and LOW IN CONTRAST, as everything added to it must (see ants_art.gd): sand grains, clumps of
// them, and here and there a small flat pebble, a shade paler or darker than the soil, never a color
// of its own and never a shadow. Anchored in world units, so panning never makes it crawl.
//
// It replaced about 20,000 drawn grain squares, which read as square speckle.

varying vec2 world;

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

// Pebbles: one chance per cell, a jittered disc with a soft edge. Returns -1..1 (darker / paler) * mask.
float pebbles(vec2 p, float cell, float chance, float r_lo, float r_hi) {
	vec2 c = floor(p / cell);
	float best = 0.0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 cc = c + vec2(float(dx), float(dy));
			if (hash(cc + 3.1) > chance) {
				continue;
			}
			vec2 at = (cc + vec2(hash(cc + 7.7), hash(cc + 1.9))) * cell;
			float r = mix(r_lo, r_hi, hash(cc + 5.3));
			// a little out of round
			vec2 d = p - at;
			float ang = atan(d.y, d.x);
			r *= 1.0 + 0.18 * sin(ang * 3.0 + hash(cc) * 6.28);
			float m = 1.0 - smoothstep(r - 0.6, r + 0.4, length(d));
			if (m > 0.0) {
				best = m * (hash(cc + 9.1) < 0.55 ? 1.0 : -1.0);
			}
		}
	}
	return best;
}

void vertex() {
	world = VERTEX;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	// the soil only: the dark wall round the world is left alone
	float is_soil = smoothstep(0.30, 0.42, dot(base.rgb, vec3(0.333)));
	float grain = (hash(floor(world / 1.4)) - 0.5) * 0.13 + (hash(floor(world / 0.8) + 11.0) - 0.5) * 0.05;
	float clump = (noise(world / 5.0) - 0.5) * 0.06 + (noise(world / 17.0) - 0.5) * 0.05;
	float peb = pebbles(world, 11.0, 0.12, 1.2, 2.8) * 0.10 + pebbles(world + 400.0, 37.0, 0.20, 2.6, 5.0) * 0.07;
	float k = 1.0 + (grain + clump + peb) * is_soil;
	COLOR = vec4(base.rgb * k, base.a);
}
