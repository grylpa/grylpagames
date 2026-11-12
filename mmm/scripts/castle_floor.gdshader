shader_type canvas_item;

// THE PALACE FLOOR (2026-11-12), on every room and corridor tile (pipe.gd gives them one material): dressed
// stone slabs, ONE PER CELL (movement is tile based) -- each slab its own faint shade, fine grain, a soft bevel and thin joints. The
// ROOM'S COLOR is the node's tint and the stone is only a light texture over it: the color is what the
// player has to remember, so it stays even (+-6%), and nothing in the pattern changes from room to room.
// Corridors are the same stone in warm gray (pipe.gd). It replaced a tinted photo of marble tiles.

varying vec2 world;
varying vec4 tint;      // the node's tint (modulate): the room's color. In fragment() COLOR is the texture.
// THE TILE'S BOARD CELL, given by pipe.gd (each tile has its own material). The pattern is laid from it,
// NOT from MODEL_MATRIX: in this game that matrix moves with the camera, so as it glided between rooms or
// followed the player down a corridor, every tile kept changing which square of the checker it was, and
// the floor flashed between the two tones (user, 2026-11-12; measured: all tiles at once, ratio 0.86).
uniform vec2 cell = vec2(0.0);

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

// TRIAL (2026-11-12): 0 the stone slabs, 1 polished marble in a two-tone checker with veins, 2 painted
// parquet in a basket weave
uniform int style = 1;

void vertex() {
	world = cell * 40.0 + VERTEX;        // board space: fixed to the board, whatever the camera does
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// ONE SLAB PER BOARD CELL: movement is tile by tile, so the player must see the cells to judge a
	// step (slabs a tile and a half long, laid in offset courses, hid them -- user, 2026-11-12). The
	// sprite IS one cell, so its UV gives the place in it; the slab's shade is picked by the cell.
	vec2 id = cell;
	float fx = UV.x * 40.0;
	float fy = UV.y * 40.0;
	float edge = min(min(fx, 40.0 - fx), min(fy, 40.0 - fy));        // px to the cell's edge
	if (style == 1) {
		// POLISHED MARBLE: the cells in two close tones of the room's color, soft clouding, fine light
		// veins running on across the cells, a pillow bevel (lit top-left, shaded bottom-right) and a
		// broad sheen.
		// ANTI-ALIASED (2026-11-12): every hairline is sized in SCREEN pixels (`px` = world units per
		// pixel), and the veins fade out where they would be thinner than a pixel. Fixed-width hairlines
		// fell between pixels while the camera glided and zoomed from room to room, and the floor flashed.
		float px = max(fwidth(world.x), 0.001);
		float chk = mod(id.x + id.y, 2.0);
		float shade = mix(1.0, 0.86, chk);
		shade *= 0.95 + 0.09 * fbm(world / 22.0 + id * 0.7);
		float v = fbm(world / 46.0 + vec2(3.1, 7.7));
		float av = fwidth(v);
		float vein = (1.0 - smoothstep(0.011 - av, 0.011 + av, abs(v - 0.5))) * smoothstep(0.02, 0.006, av);
		float v2 = fbm(world / 19.0 + vec2(11.0, 2.0));
		float av2 = fwidth(v2);
		vein = max(vein, (1.0 - smoothstep(0.008 - av2, 0.008 + av2, abs(v2 - 0.5))) * 0.5 * smoothstep(0.015, 0.005, av2));
		float bev = max(2.4, 2.0 * px);
		shade *= 1.0 + 0.10 * (1.0 - smoothstep(0.0, bev, min(fx, fy)));
		shade *= 1.0 - 0.14 * (1.0 - smoothstep(0.0, bev, min(40.0 - fx, 40.0 - fy)));
		float jw = max(0.9, 1.2 * px);
		float joint = 1.0 - smoothstep(0.0, jw, edge);
		shade = mix(shade, 0.70, joint);
		vec3 col = tint.rgb * shade;
		col = mix(col, vec3(0.97, 0.96, 0.93), vein * 0.22 * (1.0 - joint));
		col += vec3(0.06) * smoothstep(0.55, 0.80, fbm(world / 260.0 + 1.3));
		COLOR = vec4(col, tex.a * tint.a);
	} else if (style == 2) {
		// PAINTED PARQUET, BASKET WEAVE: each cell four planks, running across in one cell and down in
		// the next; grain along the plank, each plank its own shade, a dark gap between planks
		float chk = mod(id.x + id.y, 2.0);
		vec2 q = chk < 0.5 ? vec2(fx, fy) : vec2(fy, fx);          // q.y runs across the planks
		float plank = floor(q.y / 10.0);
		float py = q.y - plank * 10.0;
		vec2 pid = id * 7.0 + vec2(plank, chk);
		float shade = 0.90 + 0.12 * hash(pid);
		shade *= 0.93 + 0.10 * noise(vec2(q.x / 9.0 + hash(pid) * 40.0, py / 1.2 + plank * 3.0));
		shade *= 1.0 - 0.06 * smoothstep(0.6, 0.95, noise(vec2(q.x / 3.0, py * 1.6 + plank * 9.0)));
		float gap = 1.0 - smoothstep(0.3, 1.0, min(py, 10.0 - py));
		shade = mix(shade, 0.62, gap);
		shade = mix(shade, 0.58, 1.0 - smoothstep(0.3, 1.0, edge));
		COLOR = vec4(tint.rgb * shade, tex.a * tint.a);
	} else {
	// the slab: its own shade, grain, a little wear in the middle, a soft bevel to its edge
	float shade = 0.95 + 0.07 * hash(id + 3.1);
	shade *= 0.97 + 0.05 * noise(world / 6.0) + 0.03 * (hash(floor(world / 1.3)) - 0.5);
	shade *= 1.0 + 0.03 * smoothstep(4.0, 16.0, edge);
	shade *= 0.95 + 0.05 * smoothstep(0.8, 4.0, edge);
	// the lit lip of the bevel toward the top left, the light's side
	float lip = (1.0 - smoothstep(0.8, 2.2, fy)) + (1.0 - smoothstep(0.8, 2.2, fx));
	shade += 0.03 * clamp(lip, 0.0, 1.0) * step(0.8, edge);
	// the joint: thin, a step darker, never black -- a room is ONE color
	float joint = 1.0 - smoothstep(0.5, 1.4, edge);
	shade = mix(shade, 0.80, joint);       // (0.62 read as bathroom tiles)
	COLOR = vec4(tint.rgb * shade, tex.a * tint.a);
	}
}
