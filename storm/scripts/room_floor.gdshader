shader_type canvas_item;

// STORM'S ROOM FLOORS (2026-11-12), on every room tile's PipeFloor2 sprite (pipe.gd gives each tile its
// own copy of the material). Three floors a house has, ONE TILE PER CELL in every one of them -- the
// player walks, places tools and catches leaks cell by cell, so the grid must always read ("don't lose
// the tiles"). The ROOM'S COLOR is the node's tint and stays the main thing seen: it is how the player
// remembers which room is which.
//   kind 0 POLISHED MARBLE: two close tones of the room's color in a checker, soft clouding, fine pale
//          veins running on across the cells, a pillow bevel and a broad sheen (Mind Palace's floor).
//   kind 1 GLAZED CERAMIC: a glossy tile in a thin grout close to its tone, a raised rim with a soft inner line, a
//          faint crackle in the glaze, and the window light caught on the glaze as a slow broad streak.
//   kind 2 TERRACOTTA: matte fired clay in a narrow mortar a step darker, every tile its own hue, pitted, its
//          corners worn round.
// They replaced boards, small kitchen tiles and carpet drawn per cell on the CPU, whose planks and
// patterns hid the cells or read as a parquet ("unclear").
//
// The pattern is laid from the tile's BOARD CELL (uniform `cell`), never from MODEL_MATRIX: the camera
// moves the matrix, and a checker laid from it flashes between its tones as the view glides (Mind
// Palace, 2026-11-12). Hairlines are sized in SCREEN pixels so nothing shimmers when the camera zooms.

uniform vec2 cell = vec2(0.0);
uniform int kind = 0;
// marble only: 1 lays it as a checker of two tones, 0 one even tone (most rooms: "not all rooms should be
// checkerboard -- most should not")
uniform float checker = 0.0;

varying vec2 world;
varying vec4 tint;      // the node's tint: the room's color

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return v;
}

// distance (px) to the edge of a rounded square of half-size h and corner radius r, centered at 0;
// negative inside
float rbox(vec2 q, float h, float r) {
	vec2 d = abs(q) - vec2(h - r);
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

void vertex() {
	world = cell * 40.0 + VERTEX;
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 q = UV * 40.0;                 // px inside the cell, 0..40
	vec2 c = q - 20.0;                  // from the cell's center
	float px = max(fwidth(world.x), 0.001);
	vec3 col;
	if (kind == 0) {
		float chk = mod(cell.x + cell.y, 2.0) * checker;
		float shade = mix(1.0, 0.87, chk);
		// EVERY SLAB ITS OWN TONE (no two marble slabs quite match), and CLOUDING in the stone: what gives an
		// even (non-checker) floor the depth Mind Palace's checker gives -- flat, it looked plain beside it
		shade *= 0.92 + 0.12 * hash(cell + 13.7);
		shade *= 0.90 + 0.16 * fbm(world / 28.0 + cell * 0.7);
		shade *= 1.0 - 0.08 * smoothstep(0.55, 0.85, fbm(world / 60.0 + 4.2));
		float v = fbm(world / 46.0 + vec2(3.1, 7.7));
		float av = fwidth(v);
		float vein = (1.0 - smoothstep(0.011 - av, 0.011 + av, abs(v - 0.5))) * smoothstep(0.02, 0.006, av);
		float v2 = fbm(world / 19.0 + vec2(11.0, 2.0));
		float av2 = fwidth(v2);
		vein = max(vein, (1.0 - smoothstep(0.008 - av2, 0.008 + av2, abs(v2 - 0.5))) * 0.5 * smoothstep(0.015, 0.005, av2));
		float bev = max(2.4, 2.0 * px);
		shade *= 1.0 + 0.10 * (1.0 - smoothstep(0.0, bev, min(q.x, q.y)));
		shade *= 1.0 - 0.14 * (1.0 - smoothstep(0.0, bev, min(40.0 - q.x, 40.0 - q.y)));
		float edge = min(min(q.x, 40.0 - q.x), min(q.y, 40.0 - q.y));
		float joint = 1.0 - smoothstep(0.0, max(0.9, 1.2 * px), edge);
		shade = mix(shade, 0.68, joint);
		col = tint.rgb * shade;
		col = mix(col, vec3(0.97, 0.96, 0.93), vein * 0.34 * (1.0 - joint));      // bolder veins (0.24)
		col += vec3(0.06) * smoothstep(0.55, 0.80, fbm(world / 260.0 + 1.3));
	} else if (kind == 1) {
		// the tile: a rounded square inside a light grout, its own faint shade
		float d = rbox(c, 19.2, 2.2);                    // < 0 on the glaze (a thin grout: calm, like Mind Palace)
		float aa = max(0.6, px);
		float on_tile = 1.0 - smoothstep(-aa, aa, d);
		float shade = 1.0 + 0.05 * (hash(cell + 1.7) - 0.5);
		shade *= 0.97 + 0.05 * noise(world / 9.0 + cell);
		// the raised rim: lit on the top and left, shaded bottom and right, over the outer 3 px
		float rim = 1.0 - smoothstep(0.0, 3.2, -d);
		vec2 nrm = normalize(c + 0.001);
		float lit = dot(nrm, normalize(vec2(-1.0, -1.2)));
		shade *= 1.0 + rim * 0.16 * lit;
		// a soft inner line where the rim meets the flat of the tile
		float inner = 1.0 - smoothstep(0.0, max(0.7, px), abs(d + 4.2));
		shade *= 1.0 - 0.07 * inner;
		// a faint crackle in the glaze, only where it is wider than a pixel
		float cr = abs(fbm(world / 7.0 + cell * 3.1) - 0.5);
		float acr = fwidth(cr);
		shade *= 1.0 - 0.05 * (1.0 - smoothstep(0.006 - acr, 0.006 + acr, cr)) * smoothstep(0.02, 0.008, acr);
		vec3 glaze = tint.rgb * shade;
		// GLOSS: the room's window light caught on the glaze, a broad soft streak across the floor at an
		// angle (in board space, so it is still), plus a small hot spot near each tile's top left
		float streak = smoothstep(0.62, 0.92, fbm(vec2((world.x + world.y * 0.55) / 70.0, 2.0)));
		glaze += vec3(0.16) * streak * (1.0 - rim * 0.6);
		glaze += vec3(0.20) * (1.0 - smoothstep(0.0, 7.0, length(c - vec2(-8.0, -9.0)))) * 0.6;
		vec3 grout = mix(vec3(0.88, 0.87, 0.84), tint.rgb, 0.55) * (0.92 + 0.08 * noise(world / 2.0));     // close to the tile
		col = mix(grout, glaze, on_tile);
	} else {
		// TERRACOTTA: matte clay, every tile its own hue and depth, in a narrow mortar a step darker
		float d = rbox(c + vec2(hash(cell) - 0.5, hash(cell + 9.0) - 0.5) * 0.5, 18.9, 3.0);       // a narrow joint
		float aa = max(0.7, px);
		float on_tile = 1.0 - smoothstep(-aa, aa, d);
		float h = hash(cell + 4.4);
		vec3 clay = tint.rgb * mix(vec3(1.04, 0.95, 0.88), vec3(0.92, 0.88, 0.84), h);
		float grain = 0.90 + 0.14 * fbm(world / 5.0 + cell * 2.3);
		// pits: small dark specks
		float pit = smoothstep(0.80, 0.86, noise(world / 1.6 + cell * 5.0)) * smoothstep(0.5, 0.2, px);
		grain *= 1.0 - 0.18 * pit;
		// worn: the tile's middle a touch lighter, its edges rounded down into the mortar
		grain *= 1.0 + 0.05 * (1.0 - smoothstep(4.0, 16.0, length(c)));
		grain *= 1.0 - 0.22 * (1.0 - smoothstep(0.0, 3.5, -d));
		float lip = (1.0 - smoothstep(0.0, 3.0, -d)) * clamp(dot(normalize(c + 0.001), normalize(vec2(-1.0, -1.2))), 0.0, 1.0);
		grain *= 1.0 + 0.12 * lip;
		vec3 tile = clay * grain;
		vec3 mortar = tint.rgb * 0.72 * (0.88 + 0.16 * noise(world / 1.5));       // a step darker, not a dark grid
		col = mix(mortar, tile, on_tile);
	}
	COLOR = vec4(col, tex.a * tint.a);
}
