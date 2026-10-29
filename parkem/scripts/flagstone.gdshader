shader_type canvas_item;

// THE MAZE FLOOR, on every floor tile's sprite (pipe.gd gives them one shared material): worn
// FLAGSTONES -- irregular slabs (the nearest of a jittered grid of points, two to three tiles across),
// each its own shade, with darker mortar between them, faint grain and a little moss in the joints.
// LOW CONTRAST on purpose: the doors drawn over the floor are the player's only control -- a closed
// one is a thin diagonal LINE -- and must stay the clearest lines on it, so the joints are thin and
// faint (a first version's dark, wide mortar ran at every angle and competed with them). In world coordinates, so the slabs run across tiles.

varying vec2 world;
varying vec2 cell_local;
varying vec2 cell_at;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + 17.3));
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	// the sprite is ONE board cell (40 px, centered): its own pixel offset, and where it is
	cell_local = VERTEX;
	cell_at = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
}

// 0 = the old courtyard (stone paving with moss in the joints), 1 = a forest floor (rejected),
// 2 = a dungeon floor (set by pipe.gd)
uniform int floor_style = 1;

vec3 forest_floor(vec2 w) {
	// FOREST FLOOR: dark loam, broad patches of moss, a mat of old leaves, pebbles and the odd root
	vec3 soil = mix(vec3(0.20, 0.15, 0.10), vec3(0.27, 0.20, 0.13), noise(w / 9.0));
	soil *= 0.92 + 0.12 * hash(floor(w / 1.5));
	float moss = smoothstep(0.64, 0.80, noise(w / 38.0 + 3.0) * 0.7 + noise(w / 9.0) * 0.3);
	vec3 col = mix(soil, mix(vec3(0.14, 0.24, 0.10), vec3(0.20, 0.32, 0.13), noise(w / 3.0)), moss * 0.9);
	// old leaves: small cells, each a leaf in an autumn brown, only where there is no moss
	vec2 lc = floor(w / 7.0);
	vec2 lp = fract(w / 7.0) - 0.5 - (hash2(lc) - 0.5) * 0.5;
	float ang = hash(lc + 4.0) * 6.283;
	vec2 rp = vec2(cos(ang) * lp.x + sin(ang) * lp.y, -sin(ang) * lp.x + cos(ang) * lp.y);
	float leaf = 1.0 - smoothstep(0.85, 1.0, length(rp * vec2(2.4, 5.2)));
	leaf *= step(0.55, hash(lc + 8.0)) * (1.0 - moss);
	vec3 leaf_c = mix(vec3(0.42, 0.24, 0.10), vec3(0.52, 0.38, 0.14), hash(lc + 2.0));
	col = mix(col, leaf_c * (0.85 + 0.25 * hash(lc)), leaf * 0.9);
	// pebbles
	vec2 pc = floor(w / 11.0);
	float peb = 1.0 - smoothstep(0.9, 1.4, length((fract(w / 11.0) - hash2(pc)) * 11.0));
	col = mix(col, vec3(0.50, 0.48, 0.44), peb * step(0.82, hash(pc + 1.7)));
	// roots: thin wandering dark lines
	float root = abs(noise(w / 30.0 + 11.0) - 0.5);
	col = mix(col, vec3(0.13, 0.09, 0.06), (1.0 - smoothstep(0.004, 0.014, root)) * 0.8);
	return col;
}

vec3 dungeon_floor(vec3 stone_base, float edge, float mortar, vec2 id, vec2 w) {
	// DUNGEON: big dark blue-gray slabs, worn smooth in the middle, deep black joints, hairline
	// cracks, and warm torchlight pooling here and there on the floor
	vec3 slab = mix(vec3(0.20, 0.21, 0.25), vec3(0.27, 0.28, 0.32), hash(id + 3.1));
	slab *= 0.94 + 0.10 * noise(w / 5.0);
	slab *= 1.0 + 0.10 * smoothstep(0.10, 0.30, edge);      // worn smooth away from the edges
	vec3 col = mix(slab, vec3(0.05, 0.05, 0.07), mortar * 1.6);
	float crack = abs(noise(w / 14.0 + id) - 0.5);
	col *= 1.0 - 0.35 * (1.0 - smoothstep(0.006, 0.016, crack)) * step(0.6, hash(id + 6.0));
	float torch = smoothstep(0.62, 0.95, noise(w / 160.0 + 2.0));
	col += vec3(0.30, 0.16, 0.05) * torch * 0.55;
	return col;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// ONE SLAB PER BOARD CELL (2026-10-29): the creatures move cell by cell, and slabs that ran
	// across the cells (a jittered Voronoi) hid the grid -- there was no way to tell where a creature
	// would turn. Each cell is now a squarish slab, its edges a little irregular so it still reads as
	// stone, each with its own tone.
	vec2 id = floor(cell_at / 40.0 + 0.5);
	float irregular = (noise(world / 4.0) - 0.5) * 1.4 + (noise(world / 13.0 + id) - 0.5) * 1.2;
	float edge_px = 20.0 - max(abs(cell_local.x), abs(cell_local.y)) + irregular;
	float edge = max(edge_px, 0.0) / 40.0;
	float mortar = (1.0 - smoothstep(0.015, 0.045, edge)) * 0.45;
	// AN OLD COURTYARD (2026-10-29): weathered gray-beige paving, each slab its own tone with soft
	// stains, MOSS creeping out of the joints in patches, and a little light on each slab's edge.
	vec3 stone = mix(vec3(0.50, 0.48, 0.43), vec3(0.60, 0.57, 0.50), hash(id + 3.1)) * (0.92 + 0.10 * hash(id + 5.7));
	stone *= 1.0 + (hash(floor(world / 1.4)) - 0.5) * 0.07;
	stone *= 1.0 - 0.10 * smoothstep(0.55, 0.85, noise(world / 22.0 + id * 3.0));      // stains
	vec3 joint = vec3(0.24, 0.23, 0.20);
	vec3 col = mix(stone, joint, mortar);
	col += vec3(0.025) * (1.0 - smoothstep(0.07, 0.14, edge)) * (1.0 - mortar);
	// moss: in the joints, spreading a little onto the slabs, only where a slow noise allows
	float mossy = smoothstep(0.45, 0.75, noise(world / 70.0 + 7.0));
	float near_joint = 1.0 - smoothstep(0.02, 0.09 + 0.06 * noise(world / 6.0), edge);
	float moss = near_joint * mossy * (0.6 + 0.4 * noise(world / 3.0));
	col = mix(col, mix(vec3(0.20, 0.32, 0.14), vec3(0.32, 0.44, 0.18), noise(world / 4.0)), clamp(moss, 0.0, 0.85));
	if (floor_style == 1) {
		col = forest_floor(world);
	} else if (floor_style == 2) {
		col = dungeon_floor(col, edge, mortar, id, world);
	}
	COLOR = vec4(col, tex.a);
}
