shader_type canvas_item;

// The soil's fine texture, on the ground layer (level.gd's _bg). It only ever nudges the brightness of
// what is drawn there -- the soil, its damp and dry patches -- by a few percent, so the ground stays
// FLAT and LOW IN CONTRAST, as everything added to it must (see ants_art.gd): sand grains, clumps of
// them, and here and there a small flat pebble, a shade paler or darker than the soil, never a color
// of its own and never a shadow. Anchored in world units, so panning never makes it crawl.
//
// It replaced about 20,000 drawn grain squares, which read as square speckle.
//
// The light also has a COLOR now (warm sun, cool shade), the dry ground fine cracks, and the pebbles a
// faint color of their own (user: the world was "still so ugly ... dull and boring", 2026-10-25).
// TWO THINGS LIVE ON IT, both brightness only (the world was "a bit boring", user,
// 2026-10-25): DAPPLED LIGHT -- the soft shadows of a canopy overhead, large, about 7% either way,
// and STILL (nothing on the ground may move: it would compete with the ants) -- and FALLEN DRY LEAVES, flat pale leaf shapes with a darker midrib, a few to a screen,
// clearly leaves and nothing that is food, a stone or a twig.

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

// The canopy's shade: two layers of smooth noise, thresholded softly into leafy blotches.
// -1 = in shade, +1 = a fleck of sun.
float dapple(vec2 p) {
	float n = noise(p / 95.0) * 0.6 + noise(p / 41.0 + 13.0) * 0.4;
	return smoothstep(0.50, 0.66, n) * -1.0 + (1.0 - smoothstep(0.26, 0.36, n)) * 1.0;
}

// A fallen leaf: one chance per 110-unit cell, an almond shape turned at random, a midrib along it.
// Returns +1 on the leaf blade, -1 on the rib, 0 off it.
float leaf(vec2 p) {
	float cell = 110.0;
	vec2 c = floor(p / cell);
	float best = 0.0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 cc = c + vec2(float(dx), float(dy));
			if (hash(cc + 21.7) > 0.22) {
				continue;
			}
			vec2 at = (cc + vec2(hash(cc + 2.2), hash(cc + 8.8))) * cell;
			float ang = hash(cc + 4.4) * 6.2832;
			float len = mix(14.0, 24.0, hash(cc + 6.6));
			vec2 d = p - at;
			vec2 q = vec2(cos(ang) * d.x + sin(ang) * d.y, -sin(ang) * d.x + cos(ang) * d.y);
			float u = q.x / len;
			if (abs(u) > 1.0) {
				continue;
			}
			float half_w = len * 0.42 * (1.0 - u * u) * (1.0 + 0.25 * u);
			float blade = 1.0 - smoothstep(half_w - 0.5, half_w + 0.5, abs(q.y));
			float rib = (1.0 - smoothstep(0.35, 0.9, abs(q.y))) * step(-0.95, u);
			if (blade > 0.0) {
				best = blade * (1.0 - rib) - rib;
			}
		}
	}
	return best;
}

// Dry ground cracks: the edges of a jittered cell pattern, faint, only where the soil is dry.
float cracks(vec2 p) {
	vec2 ip = floor(p);
	float d1 = 9.0;
	float d2 = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = ip + vec2(float(x), float(y));
			vec2 at = c + vec2(hash(c + 1.7), hash(c + 9.3));
			float d = length(p - at);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return 1.0 - smoothstep(0.02, 0.07, d2 - d1);
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
	float lf = leaf(world);
	float dp = dapple(world);
	float lum = dot(base.rgb, vec3(0.333));
	float dry = smoothstep(0.55, 0.62, lum);
	float cr = cracks(world / 26.0) * dry * (0.6 + 0.4 * noise(world / 60.0));
	float k = 1.0 + (grain + clump + peb + dp * 0.07 + lf * 0.10 - cr * 0.07) * is_soil;
	// the light's COLOR too: a warm fleck of sun, a cool shade
	vec3 tint = mix(vec3(1.0), dp > 0.0 ? vec3(1.04, 1.0, 0.92) : vec3(0.98, 0.985, 1.01), abs(dp) * is_soil);
	// pebbles take a little color of their own: pale ones a cool gray, dark ones a rusty red
	vec3 ptint = mix(vec3(1.0), peb > 0.0 ? vec3(0.97, 0.99, 1.03) : vec3(1.04, 0.96, 0.92), min(1.0, abs(peb) * 8.0) * is_soil);
	COLOR = vec4(base.rgb * k * tint * ptint, base.a);
}
