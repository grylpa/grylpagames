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

// THE PLAZA (2026-10-29): a paved city square instead of a plain lot, and still plainly a GRID --
// the cabs move cell by cell, so every cell is one square of basket-weave brick (four quarters, the
// bricks turned in alternate quarters) framed by a granite border on the cell lines. Warm gray
// brick, each brick a slightly different tone.
vec3 plaza(vec2 lp, vec2 at, vec2 w) {
	vec2 id = floor(at / 40.0 + 0.5);
	vec2 q = lp + vec2(20.0);                       // 0..40 across the cell
	float border = min(min(q.x, q.y), min(40.0 - q.x, 40.0 - q.y));
	vec3 granite = vec3(0.40, 0.40, 0.42) * (0.92 + 0.12 * hash(floor(w / 1.5)));
	if (border < 2.6) {
		return mix(vec3(0.20, 0.20, 0.22), granite, smoothstep(0.3, 0.9, border));
	}
	vec2 inner = q - vec2(2.6);                     // 0..34.8
	vec2 quad = floor(inner / 17.4);
	vec2 qp = inner - quad * 17.4;                  // 0..17.4 inside a quarter
	bool turn = mod(quad.x + quad.y, 2.0) > 0.5;
	vec2 bp = turn ? qp.yx : qp;
	float row = floor(bp.y / 5.8);
	vec2 bq = vec2(bp.x, bp.y - row * 5.8);
	float joint = min(min(bq.y, 5.8 - bq.y), min(bp.x, 17.4 - bp.x));
	vec2 brick_id = id * 13.0 + quad * 3.0 + vec2(row, 0.0);
	vec3 brick = mix(vec3(0.56, 0.47, 0.40), vec3(0.64, 0.55, 0.46), hash(brick_id));
	brick *= 0.94 + 0.10 * hash(floor(w / 1.3));
	vec3 mortar = vec3(0.30, 0.27, 0.25);
	return mix(mortar, brick, smoothstep(0.35, 0.9, joint));
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
	col = plaza(tile_local, cell_at, world);
	COLOR = vec4(col, tex.a * keep);
}
