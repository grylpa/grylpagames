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
	COLOR = vec4(col, tex.a * keep);
}
