shader_type canvas_item;

// THE MAZE FLOOR: AN OVERGROWN TEMPLE (2026-11-12). On every maze tile's floor sprite (pipe.gd gives each
// its own material and tells it its cell). Worn sandstone flagstones, ONE PER CELL -- the player, the
// monsters and the babies move cell by cell, and the cells must read -- each slab its own warm tone,
// fine grain, a few cracks, its edges worn round, and MOSS creeping out of the joints, thicker in some
// parts of the temple than others. The level's floor color (the node's tint) only warms or cools the
// stone a little. It replaced a flat tinted floor under thin white wall bars. Laid from the cell, not
// MODEL_MATRIX.

uniform vec2 cell = vec2(0.0);
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
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 q = UV * 40.0;                         // px in the cell
	vec2 w = cell * 40.0 + q;                   // px on the board, for patterns that run on across cells
	float edge = min(min(q.x, 40.0 - q.x), min(q.y, 40.0 - q.y));
	// the slab: warm sandstone, its own tone, grain, a soft blotch or two of weathering
	// (darker than first set: the slim walls are pale stone, and must stand out against it)
	vec3 sand = mix(vec3(0.48, 0.40, 0.29), vec3(0.55, 0.46, 0.34), hash(cell + 3.1));
	sand *= 0.93 + 0.10 * noise(w / 7.0) + 0.05 * (hash(floor(w / 1.4)) - 0.5);
	sand *= 1.0 - 0.07 * smoothstep(0.55, 0.85, noise(w / 16.0 + cell * 1.7));
	// worn edges: darker toward the joint, a lighter worn lip on the top and left (the light's side)
	sand *= 0.86 + 0.14 * smoothstep(0.5, 3.5, edge);
	sand *= 1.0 + 0.05 * (1.0 - smoothstep(0.5, 2.5, min(q.x, q.y))) * step(0.6, edge);
	// a hairline crack across some slabs
	if (hash(cell + 7.7) > 0.70) {
		float cr = abs(noise(w / 9.0 + cell) - 0.5);
		sand *= 1.0 - 0.30 * (1.0 - smoothstep(0.008, 0.02, cr)) * smoothstep(3.0, 6.0, edge);
	}
	// the joint, and MOSS growing out of it -- more in the damp parts of the temple
	float joint = 1.0 - smoothstep(0.5, 1.4, edge);
	vec3 col = mix(sand, vec3(0.20, 0.17, 0.13), joint);
	float damp = smoothstep(0.35, 0.75, noise(w / 120.0 + 9.0));
	float moss_reach = 1.5 + 6.0 * damp * noise(w / 5.0 + 2.0);
	float moss = (1.0 - smoothstep(moss_reach - 1.5, moss_reach, edge)) * (0.35 + 0.65 * damp);
	moss *= smoothstep(0.35, 0.6, noise(w / 3.0 + 5.0));
	vec3 green = mix(vec3(0.20, 0.32, 0.12), vec3(0.34, 0.46, 0.18), noise(w / 2.0));
	col = mix(col, green, clamp(moss, 0.0, 0.85));
	// the level's floor color: only a little
	col = mix(col, col * (tint.rgb * 1.3 + 0.2), 0.20);
	COLOR = vec4(col, tex.a * tint.a);
}
