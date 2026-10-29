shader_type canvas_item;

// THE ROAD, on every road tile's sprite (pipe.gd gives them all one material). The tiles' own art is
// flat gray with yellow markings; this keeps the yellow -- dashed lines, center studs -- and turns
// the gray into asphalt: aggregate grain, broad
// worn and patched areas, the odd oil stain. Worked out in WORLD coordinates, so the texture runs on
// across tiles (and whatever a tile's rotation) instead of repeating in each one.

varying vec2 world;
varying vec2 tile_local;

// ROUNDED OUTER CORNERS (scripts/road_corners.gd convex): a corner flagged here is cut off on an arc
// of round_r, in the tile's own frame (the offset from the tile's center), so a bend's outside
// corner is round like its inside one. Each road tile has its own copy of this material.
uniform vec4 round_corners = vec4(0.0);
uniform float round_r = 8.0;
// Which sides of this tile the road continues through (r, d, l, u), set per tile by pipe.gd. A
// shared material (the corner fillets) leaves it all-open, which draws no tracks and no markings.
uniform vec4 open_sides = vec4(1.0);
const vec2 SIDE_DIR[4] = vec2[4](vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(-1.0, 0.0), vec2(0.0, -1.0));
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
	// THE ROAD'S SHAPE (2026-10-29): a slight crown -- lighter along the middle of each lane run --
	// and two darker tire tracks worn into each run, from the tile's center out through every open
	// side. Junctions get no center marking: the dashes stop at the crossing, as on a real road.
	float n_open = open_sides.x + open_sides.y + open_sides.z + open_sides.w;
	if (n_open < 2.5) {     // straights and bends only: on a 3-way the tracks crossed into a mess
		float crown = 0.0;
		float track = 0.0;
		for (int i = 0; i < 4; i++) {
			if (open_sides[i] > 0.5) {
				vec2 d = SIDE_DIR[i];
				float along = dot(tile_local, d);
				float across = abs(dot(tile_local, vec2(-d.y, d.x)));
				float reach = smoothstep(-6.0, -2.0, along);
				crown = max(crown, reach * (1.0 - smoothstep(4.0, 16.0, across)));
				track = max(track, reach * (1.0 - smoothstep(1.2, 2.6, abs(across - 9.0))));
			}
		}
		col *= 1.0 + 0.05 * crown;
		col *= 1.0 - 0.13 * track;
	}
	// the stud: where the tile's art is yellow, a small raised reflector with a highlight
	float dot_m = clamp((tex.r - tex.b) * 2.0, 0.0, 1.0);
	if (n_open > 2.5 && max(abs(tile_local.x), abs(tile_local.y)) < 15.0) {
		dot_m = 0.0;     // no dashes inside a junction
	}
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
	COLOR = vec4(col, tex.a * keep);
}
