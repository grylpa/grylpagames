shader_type canvas_item;

// THE ROAD, on every road tile's sprite (pipe.gd gives them all one material). The tiles' own art is
// a flat gray square with a yellow dot in the middle; this keeps the dot -- it marks each cell's
// center -- as a small reflective road stud, and turns the gray into asphalt: aggregate grain, broad
// worn and patched areas, the odd oil stain. Worked out in WORLD coordinates, so the texture runs on
// across tiles (and whatever a tile's rotation) instead of repeating in each one.

varying vec2 world;
varying vec2 tile_local;
varying vec2 cell_at;

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
	cell_at = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
}

// THE CITY (2026-10-30): the lot is a street grid seen from above. Every cell is a crossing of two
// streets through its center -- the cabs drive cell center to cell center, i.e. along the streets --
// and the space between streets is filled with CITY BLOCKS, one centered on each inner cell corner
// (a quarter of it in each of the four cells round that corner): a sidewalk and a rooftop, the roof
// gabled one way or the other in a muted tile color, now and then a small park with a tree. A block
// is drawn only at corners with road on all four sides (inner_corners); at the city's edge the
// streets just run on.
uniform vec4 inner_corners = vec4(0.0);
const float STREET_HALF = 6.5;       // half a street's width, from the cell's center line

float rbox_sdf(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec3 city(vec2 lp, vec2 at, vec2 w, vec3 road) {
	vec3 col = road;
	// no road markings: the grid of blocks is the city's structure (dashes and studs made it busy)
	col = vec3(0.24, 0.245, 0.255) * (0.94 + 0.10 * hash(floor(w / 1.3))) * (1.0 + (noise(w / 60.0) - 0.5) * 0.08);
	// which corner of the cell this pixel is toward, and is there a block there
	vec2 sg = vec2(lp.x >= 0.0 ? 1.0 : -1.0, lp.y >= 0.0 ? 1.0 : -1.0);
	int ci = sg.x > 0.0 ? (sg.y > 0.0 ? 0 : 3) : (sg.y > 0.0 ? 1 : 2);
	if (inner_corners[ci] < 0.5) {
		return col;
	}
	vec2 corner = sg * 20.0;
	vec2 bp = lp - corner;                         // pixel relative to the block's center
	vec2 bid = floor(at + corner + vec2(0.123));   // the block's identity, the same in its 4 cells
	float half_block = 20.0 - STREET_HALF;
	float d_walk = rbox_sdf(bp, vec2(half_block), 3.5);
	if (d_walk > 0.0) {
		// the street, with a soft shadow along the curb
		return col * (1.0 - 0.25 * (1.0 - smoothstep(0.0, 2.5, d_walk)));
	}
	vec3 walk = vec3(0.56, 0.55, 0.52) * (0.95 + 0.08 * hash(floor(w / 1.6)));
	if (d_walk > -0.8) {
		return vec3(0.72, 0.71, 0.67);              // the curb's lit edge
	}
	float d_lot = rbox_sdf(bp, vec2(half_block - 2.4), 2.0);
	if (d_lot > 0.0) {
		return walk;
	}
	float kind = hash(bid + 0.37);
	if (kind < 0.16) {
		// a small park: grass and a round tree
		vec3 g = vec3(0.26, 0.44, 0.24) * (0.94 + 0.1 * hash(floor(w / 1.4)));
		float t = length(bp - vec2(hash(bid) - 0.5, hash(bid + 1.0) - 0.5) * 3.0);
		vec3 tree = mix(vec3(0.16, 0.34, 0.16), vec3(0.24, 0.44, 0.20), smoothstep(4.5, 0.0, length(bp + vec2(1.2, 1.2))));
		return mix(g, tree, 1.0 - smoothstep(4.0, 4.8, t));
	}
	// a rooftop: soft shadow on the sidewalk, two slopes, lit on the top/left one
	vec3 roof = mix(vec3(0.58, 0.36, 0.28), vec3(0.50, 0.50, 0.52), step(0.55, hash(bid + 2.0)));
	roof = mix(roof, vec3(0.62, 0.52, 0.40), step(0.8, hash(bid + 5.0)));
	roof *= 0.92 + 0.12 * hash(bid + 3.0);
	bool along_x = hash(bid + 4.0) > 0.5;
	float across = along_x ? bp.y : bp.x;
	vec3 rc = across < 0.0 ? roof * 1.08 : roof * 0.86;
	float ridge = 1.0 - smoothstep(0.4, 1.0, abs(across));
	rc = mix(rc, roof * 1.2, ridge);
	// tile courses parallel to the ridge
	float course = abs(fract(across / 2.4) - 0.5);
	rc *= 1.0 - 0.06 * (1.0 - smoothstep(0.05, 0.15, course));
	return mix(rc * 0.9, rc, smoothstep(0.0, -1.0, d_lot));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 base = vec3(0.235, 0.240, 0.250);
	// aggregate: fine grains, light and dark
	float g = hash(floor(world / 1.3));
	float grain = (g - 0.5) * 0.10 + (hash(floor(world / 2.7) + 9.0) > 0.93 ? 0.10 : 0.0);
	// broad wear and patching
	float wear = (noise(world / 60.0) - 0.5) * 0.10 + (noise(world / 17.0) - 0.5) * 0.05;
	float patch = smoothstep(0.66, 0.72, noise(world / 140.0 + 4.0)) * -0.035;
	vec3 col = base * (1.0 + grain + wear + patch);
	// an oil stain here and there: darker, with a faint sheen
	float oil = smoothstep(0.90, 0.97, noise(world / 34.0 + 13.0)) * smoothstep(0.55, 0.7, noise(world / 300.0 + 2.0));
	col = mix(col, col * 0.72 + vec3(0.015, 0.0, 0.03), oil * 0.6);
	// the stud: where the tile's art is yellow, a small raised reflector with a highlight
	float dot_m = clamp((tex.r - tex.b) * 2.0, 0.0, 1.0);
	vec3 stud = vec3(0.96, 0.80, 0.25);
	col = mix(col, stud, dot_m);
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
	col = vec3(0.235, 0.24, 0.25) * (1.0 + (noise(world / 60.0) - 0.5) * 0.12);
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
