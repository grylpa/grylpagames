shader_type canvas_item;

// THE ROAD, on every road tile's sprite (pipe.gd gives each tile its own copy of one material). The
// tile's own art (a flat gray square with a yellow dot) is replaced by rough asphalt with a faint
// grid on the cell lines; only its alpha is kept. Worked out in WORLD coordinates, so the texture
// runs on across tiles (and whatever a tile's rotation) instead of repeating in each one. (A drawn
// city of blocks and rooftops, and a stud on each cell's center, were tried and removed.)

varying vec2 world;
varying vec2 tile_local;

// ROUNDED OUTER CORNERS (scripts/road_corners.gd convex): a corner flagged here is cut off on an arc
// of round_r, in the tile's own frame (the offset from the tile's center), so a bend's outside
// corner is round like its inside one. Each road tile has its own copy of this material.
uniform vec4 round_corners = vec4(0.0);
uniform float round_r = 8.0;
const vec2 CORNER_SIGN[4] = vec2[4](vec2(1.0, 1.0), vec2(-1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0));
// THE PLAZA'S DETAILS (2026-11-12), all flat paint and texture, so the cabs still drive over every cell:
// set per tile by pipe.gd. `cell` is the tile's board cell (picks its manhole or stain); `bay` points
// from a BAY (a notch along the edge: a dead end, road on one side only) toward the square, zero
// elsewhere -- a bay is outlined in worn yellow paint like a taxi rank.
uniform vec2 cell = vec2(0.0);
uniform vec2 bay = vec2(0.0);

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
	// the sprite's own pixels (a 40 px tile, centered) turned like the tile but NOT scaled, whatever
	// scale the board is drawn at
	tile_local = mat2(normalize(MODEL_MATRIX[0].xy), normalize(MODEL_MATRIX[1].xy)) * VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float keep = 1.0;
	for (int i = 0; i < 4; i++) {
		if (round_corners[i] > 0.5) {
			vec2 q = tile_local * CORNER_SIGN[i] - vec2(20.0 - round_r);
			if (q.x > 0.0 && q.y > 0.0) {
				keep = min(keep, 1.0 - smoothstep(round_r - 0.6, round_r + 0.6, length(q)));
			}
		}
	}
	// THE SQUARE (2026-10-30): plain asphalt with a faint painted grid on the cell lines, so the grid
	// the cabs move on is plain and nothing sits under them. Kept DISTINCT from the night sidewalk
	// round it (city_surround.gd): a wet, neon-reflecting asphalt was tried and read as a cloud
	// layer over the whole screen.
	// ROUGH: coarse aggregate (light and dark stones a pixel or two across), a finer grain over it,
	// broad wear, and small cracks and patches here and there
	vec3 col = vec3(0.235, 0.24, 0.25) * (1.0 + (noise(world / 60.0) - 0.5) * 0.12);
	col *= 0.95 + 0.09 * hash(floor(world / 1.1));
	float stone = hash(floor(world / 2.2) + 7.0);
	col *= stone > 0.94 ? 1.10 : (stone < 0.05 ? 0.90 : 1.0);
	col *= 1.0 - 0.05 * smoothstep(0.55, 0.85, noise(world / 9.0 + 3.0));
	float crack = abs(noise(world / 18.0 + 5.0) - 0.5);
	col *= 1.0 - 0.15 * (1.0 - smoothstep(0.004, 0.012, crack)) * smoothstep(0.6, 0.8, noise(world / 90.0 + 8.0));
	float gl = min(20.0 - abs(tile_local.x), 20.0 - abs(tile_local.y));
	col = mix(col, vec3(0.42, 0.42, 0.40), (1.0 - smoothstep(0.3, 0.9, gl)) * 0.55);
	vec2 q = tile_local;
	// an OIL STAIN on a few cells: a dark ragged blot with a faint rainbow sheen
	if (hash(cell + 4.4) > 0.95) {
		vec2 sc = vec2(hash(cell + 1.1) - 0.5, hash(cell + 2.2) - 0.5) * 16.0;
		float r = 9.0 + 5.0 * noise((q - sc) / 4.0 + cell);
		float blot = 1.0 - smoothstep(r - 3.0, r, length(q - sc));
		col *= 1.0 - 0.22 * blot;
		vec3 sheen = 0.5 + 0.5 * cos(6.2832 * (noise(q / 3.0 + cell) + vec3(0.0, 0.33, 0.67)));
		col += sheen * 0.025 * blot;
	}
	// a MANHOLE COVER on a few others: cast iron, a raised rim, a ring of studs and a cross-hatched face
	if (hash(cell + 9.7) > 0.985) {
		vec2 mc = vec2(hash(cell + 3.3) - 0.5, hash(cell + 5.5) - 0.5) * 10.0;
		vec2 m = q - mc;
		float d = length(m);
		float disc = 1.0 - smoothstep(8.6, 9.4, d);
		vec3 iron = vec3(0.17, 0.17, 0.18) * (0.9 + 0.2 * noise(m / 2.0 + cell));
		float hatch = step(0.5, fract((m.x + m.y) / 2.4)) * step(0.5, fract((m.x - m.y) / 2.4));
		iron *= 0.86 + 0.24 * hatch * (1.0 - smoothstep(5.8, 6.4, d));
		iron = mix(iron, vec3(0.30, 0.30, 0.31), (1.0 - smoothstep(0.5, 1.2, abs(d - 7.6))));   // the rim
		iron += vec3(0.08, 0.04, 0.0) * smoothstep(0.65, 0.9, noise(m / 3.0 + 7.0));           // rust
		col = mix(col, iron, disc);
		col *= 1.0 - 0.25 * (1.0 - smoothstep(9.0, 10.5, d)) * step(9.0, d);               // its seat
	}
	// a few small PUDDLES: darker and smoother, each taking up ONE of the street's neon colors, shimmering
	// (big blobs in several colors at once looked like paint spills)
	float pud = smoothstep(0.84, 0.87, noise(world / 34.0 + 11.0)) * step(0.62, noise(world / 300.0 + 2.0));
	if (pud > 0.0) {
		float h = hash(floor(world / 120.0) + 31.0);
		vec3 neon = h < 0.33 ? vec3(1.0, 0.60, 0.22) : (h < 0.66 ? vec3(0.95, 0.30, 0.65) : vec3(0.25, 0.75, 0.95));
		float ripple = 0.5 + 0.5 * sin(world.x * 0.35 + world.y * 0.22 + TIME * 1.3 + noise(world / 8.0) * 6.0);
		// wet asphalt is mostly DARKER and smooth (no grain); the neon only a faint tint, and a soft
		// highlight moving along it (in full neon the puddles read as smears of paint)
		vec3 wet = vec3(0.195, 0.20, 0.215) + neon * 0.035 + vec3(0.06) * pow(ripple, 6.0);
		col = mix(col, wet, pud * 0.8);
	}
	// a BAY: worn yellow lines along its three closed sides, 3 px in from the edge
	if (length(bay) > 0.5) {
		vec2 a = normalize(bay);                       // toward the square
		vec2 b = vec2(-a.y, a.x);
		float along = dot(q, a);                       // -20 (the closed end) .. 20 (open to the square)
		float across = dot(q, b);
		float w = 1.0 - smoothstep(0.7, 1.3, abs(abs(across) - 15.5));
		float sides = w * step(along, 20.0) * step(-16.6, along);
		float end = (1.0 - smoothstep(0.7, 1.3, abs(along + 15.5))) * step(abs(across), 16.3);
		float paint = clamp(sides + end, 0.0, 1.0) * (0.55 + 0.45 * step(0.35, noise(q / 2.5 + cell * 3.0)));
		col = mix(col, vec3(0.86, 0.70, 0.18), paint * 0.75);
	}
	COLOR = vec4(col, tex.a * keep);
}
