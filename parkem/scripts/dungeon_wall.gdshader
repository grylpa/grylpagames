shader_type canvas_item;

// WHAT THE DUNGEON FLOOR LIES IN (Detour's DUNGEON theme; level.gd _fit_ground_to_board puts this on a
// rect where the courtyard's lawn was): DARKNESS -- near-black rough rock with only a faint, low-contrast
// grain and a few broad, slightly lighter patches, no joints and no pattern. A first version was dressed
// stone in courses -- a second set of tiles of a different shape and nearly the floor's color, which
// fought the floor's slabs and drew the eye away from the board (user, 2026-11-12). The lit floor is the
// only tiled thing on screen now. In WORLD coordinates. The node's tint is multiplied in (taken in
// vertex(); in fragment() COLOR is the texture).

varying vec2 world;
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

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

void fragment() {
	vec3 base = vec3(0.045, 0.045, 0.058);
	float broad = noise(world / 90.0) * 0.6 + noise(world / 31.0) * 0.4;
	float grain = (noise(world / 2.2) - 0.5) * 0.10 + (hash(floor(world / 1.4)) - 0.5) * 0.06;
	vec3 col = base * (0.80 + 0.45 * broad + grain);
	COLOR = vec4(col, 1.0) * tint;
}
