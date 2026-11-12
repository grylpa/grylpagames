shader_type canvas_item;

// THE GARDEN PATH, on every path tile's sprite (pipe.gd gives each its own copy). Lights Out is a WALK
// through a garden at night (2026-11-12, it was drawn as asphalt roads -- markings, crown and tire
// tracks -- on the daytime lawn of the vehicle games): pale FLAGSTONES, irregular slabs a third of a
// tile or so across (the nearest of a jittered grid of points), each its own tone, in cool moonlight,
// with dark soil in the joints and a little moss creeping out of them. In WORLD coordinates, so the
// stones run on across tiles instead of repeating in each. The tiles' own art is used only for its
// alpha (the road markings it carries are dropped).

varying vec2 world;
varying vec2 tile_local;
varying vec4 tint;      // the node's own tint (modulate), taken in vertex(): see fragment()

// ROUNDED OUTER CORNERS (scripts/road_corners.gd convex): a corner flagged here is cut off on an arc
// of round_r, in the tile's own frame, so a bend's outside corner is round like its inside one.
uniform vec4 round_corners = vec4(0.0);
uniform float round_r = 8.0;
uniform vec4 open_sides = vec4(1.0);     // which sides the path runs on through (r, d, l, u); the mine uses it
// 0 the garden's flagstones; 1 a coal mine's tunnel floor (LightsoutLevelConfig.LOOK, set by pipe.gd)
uniform int look = 0;
const vec2 SIDE_DIR[4] = vec2[4](vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(-1.0, 0.0), vec2(0.0, -1.0));
const vec2 CORNER_SIGN[4] = vec2[4](vec2(1.0, 1.0), vec2(-1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0));

const float STONE = 19.0;      // px between stone centers (13 read as busy crazy paving)

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + 17.3));
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
	tile_local = mat2(normalize(MODEL_MATRIX[0].xy), normalize(MODEL_MATRIX[1].xy)) * VERTEX;
	tint = COLOR;
}

// A COAL MINE'S TUNNEL FLOOR: packed earth and gravel, brown-gray, with coal dust in patches, small
// stones, and the floor falling into shadow toward each tunnel wall (a closed side of the tile).
vec3 mine_floor() {
	// (lighter than the rock by a clear step: at 0.30 the floor and the rock measured the same brightness
	// on a phone, contrast 1.04, told apart only by hue and texture)
	vec3 earth = vec3(0.42, 0.37, 0.31);
	earth *= 0.88 + 0.20 * noise(world / 9.0) + 0.08 * (noise(world / 2.5) - 0.5);
	earth *= 1.0 + (hash(floor(world / 1.2)) - 0.5) * 0.10;                      // grit
	float dust = smoothstep(0.55, 0.85, noise(world / 30.0 + 3.0));
	earth = mix(earth, vec3(0.08, 0.08, 0.09), dust * 0.55);                       // coal dust
	// small stones: the nearest of a fine jittered grid, a few of them lighter, a few coal-black
	vec2 g = world / 7.0;
	vec2 gi = floor(g);
	vec2 pt = gi + 0.2 + 0.6 * hash2(gi);
	float d = length(g - pt) * 7.0;
	float r = 0.6 + 1.6 * hash(gi + 4.0);
	float pebble = (1.0 - smoothstep(r - 0.6, r + 0.4, d)) * step(0.78, hash(gi + 9.0));      // sparse
	vec3 pc = hash(gi + 2.0) > 0.85 ? vec3(0.10, 0.10, 0.11) : vec3(0.40, 0.36, 0.31);
	earth = mix(earth, pc, pebble * 0.6);
	// the walls: darker toward every side the tunnel does not continue through
	float shade = 1.0;
	for (int i = 0; i < 4; i++) {
		if (open_sides[i] < 0.5) {
			float to_wall = 20.0 - dot(tile_local, SIDE_DIR[i]);
			shade = min(shade, 0.55 + 0.45 * smoothstep(0.0, 9.0, to_wall));
		}
	}
	return earth * shade;
}

void fragment() {
	// the node's tint is multiplied in at the end: assigning COLOR outright dropped it, so the paths could
	// not be dimmed when the lights go off (level.gd PATHS_DARK). It is taken in vertex(), because here
	// COLOR already carries the tile art's texture (gray, with road markings).
	vec4 tex = texture(TEXTURE, UV);
	// the stones: the nearest and second-nearest jittered points; the joint is where they tie
	vec2 g = world / STONE;
	vec2 gi = floor(g);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = gi + vec2(float(x), float(y));
			vec2 pt = c + 0.15 + 0.7 * hash2(c);
			float d = length(g - pt);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = c;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float edge = (d2 - d1) * STONE;                          // px to the joint, roughly
	// thin joints, kept LOW in contrast: the bombs, docks and doors on the path must stay the clearest things
	float joint = (1.0 - smoothstep(0.4, 1.2, edge + (noise(world / 3.0) - 0.5) * 0.6)) * 0.75;
	// each stone its own pale tone, in cool moonlight, with fine grain and soft stains
	vec3 stone = mix(vec3(0.56, 0.58, 0.60), vec3(0.68, 0.69, 0.70), hash(id + 3.1));
	stone *= 0.93 + 0.08 * hash(id + 5.7);
	stone *= 1.0 + (hash(floor(world / 1.3)) - 0.5) * 0.06;
	stone *= 1.0 - 0.08 * smoothstep(0.55, 0.85, noise(world / 18.0 + id * 2.0));
	// a little light on each stone's rounded top, darker toward its edge
	stone *= 0.90 + 0.10 * smoothstep(0.5, 4.0, edge);
	vec3 soil = vec3(0.24, 0.25, 0.24);
	vec3 col = mix(stone, soil, joint);
	// moss in the joints here and there
	float mossy = smoothstep(0.50, 0.80, noise(world / 60.0 + 7.0));
	float near_joint = 1.0 - smoothstep(0.8, 2.6, edge);
	col = mix(col, vec3(0.16, 0.24, 0.15), clamp(near_joint * mossy * 0.8, 0.0, 0.8));
	if (look == 1) {
		col = mine_floor();
	}
	float keep = 1.0;
	for (int i = 0; i < 4; i++) {
		if (round_corners[i] > 0.5) {
			vec2 q = tile_local * CORNER_SIGN[i] - vec2(20.0 - round_r);
			if (q.x > 0.0 && q.y > 0.0) {
				keep = min(keep, 1.0 - smoothstep(round_r - 0.6, round_r + 0.6, length(q)));
			}
		}
	}
	COLOR = vec4(col, tex.a * keep) * tint;
}
