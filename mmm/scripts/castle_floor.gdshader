shader_type canvas_item;

// ROOM KINDS (2026-11-16): each room is a kind (room_kinds.gd -- kitchen, library, garden, ...) with its
// own floor: `use_cols` on, `style` and the two colors `col_a` / `col_b` per room (pipe.gd sets them;
// every tile has its own material). The colors no longer have to be remembered, so the floors may look
// like what they are. Corridors and the map's plain gray still go by the node's tint (`use_cols` off).
// Every style keeps each CELL readable (movement is tile based): its pattern lines up with the cells
// or a faint joint marks them.
//
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
uniform bool use_cols = false;
uniform vec3 col_a = vec3(0.8);
uniform vec3 col_b = vec3(0.4);

void vertex() {
	world = cell * 40.0 + VERTEX;        // board space: fixed to the board, whatever the camera does
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 base = use_cols ? col_a : tint.rgb;      // a room kind's own color, or the tint
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
		float shade = use_cols ? 1.0 : mix(1.0, 0.86, chk);
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
		vec3 col = (use_cols ? mix(col_a, col_b, chk) : tint.rgb) * shade;
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
		COLOR = vec4(base * shade, tex.a * tint.a);
	} else if (style == 3) {
		// CHECKER TILES (kitchen): four glazed tiles a cell, alternating col_a / col_b, grout between,
		// a faint gloss and the light's sheen
		float tx = floor(fx / 20.0);
		float ty = floor(fy / 20.0);
		float c2 = mod(tx + ty, 2.0);
		vec3 col = mix(col_a, col_b, c2);
		float lx = fx - tx * 20.0;
		float ly = fy - ty * 20.0;
		float te = min(min(lx, 20.0 - lx), min(ly, 20.0 - ly));
		col *= 0.96 + 0.05 * noise(world / 5.0);
		col *= 1.0 + 0.06 * (1.0 - smoothstep(0.0, 3.0, min(lx, ly)));
		col += vec3(0.05) * smoothstep(0.55, 0.85, fbm(world / 90.0 + 2.0));
		float g = 1.0 - smoothstep(0.4, 1.3, te);
		col = mix(col, vec3(0.55, 0.54, 0.50), g);
		col = mix(col, vec3(0.30), 1.0 - smoothstep(0.3, 1.0, edge));      // the cell's own joint, darker
		COLOR = vec4(col, tex.a * tint.a);
	} else if (style == 4) {
		// MOSAIC (bathroom): sixteen small tiles a cell, mostly col_a with a few col_b, white grout;
		// the cell's edge a slightly wider joint
		vec2 t = floor(vec2(fx, fy) / 10.0);
		vec2 l = vec2(fx, fy) - t * 10.0;
		float h = hash(id * 4.0 + t);
		vec3 col = h > 0.82 ? col_b : col_a * (0.92 + 0.10 * h);
		col *= 1.0 + 0.08 * (1.0 - smoothstep(0.0, 2.0, min(l.x, l.y)));
		float te = min(min(l.x, 10.0 - l.x), min(l.y, 10.0 - l.y));
		col = mix(col, vec3(0.93, 0.93, 0.90), 1.0 - smoothstep(0.3, 1.0, te));
		col = mix(col, vec3(0.62, 0.64, 0.64), 1.0 - smoothstep(0.3, 1.2, edge));
		COLOR = vec4(col, tex.a * tint.a);
	} else if (style == 5) {
		// PLANKS (library, study): three boards a cell running across, butt joints at the cell's edge on
		// alternate rows, grain along the board, each board its own shade
		float row = floor(fy / (40.0 / 3.0));
		float ly = fy - row * (40.0 / 3.0);
		vec2 bid = vec2(id.y * 3.0 + row, floor(id.x / 2.0 + mod(row, 2.0) * 0.5));
		float shade = 0.86 + 0.18 * hash(bid);
		shade *= 0.92 + 0.12 * noise(vec2(world.x / 14.0 + hash(bid) * 30.0, ly / 1.4 + row * 5.0));
		shade *= 1.0 - 0.08 * smoothstep(0.65, 0.95, noise(vec2(world.x / 4.0, ly * 1.8 + row * 7.0)));
		float gap = 1.0 - smoothstep(0.3, 1.0, min(ly, 40.0 / 3.0 - ly));
		shade = mix(shade, 0.45, gap);
		float butt = 1.0 - smoothstep(0.3, 1.0, min(fx, 40.0 - fx));
		shade = mix(shade, 0.50, butt * 0.8);
		COLOR = vec4(col_a * shade, tex.a * tint.a);
	} else if (style == 6) {
		// CARPET (bedroom, nursery): a soft pile in col_a, a small diamond in col_b in each carpet tile
		// (the cell), a faint seam between tiles
		float pile = 0.90 + 0.10 * noise(world / 1.6) + 0.05 * noise(world / 7.0);
		vec2 c = vec2(fx, fy) - 20.0;
		float dm = abs(c.x) + abs(c.y);
		float diamond = 1.0 - smoothstep(6.0, 7.2, dm);
		float ring = (1.0 - smoothstep(0.6, 1.4, abs(dm - 12.0))) * 0.6;
		vec3 col = mix(col_a, col_b, max(diamond * 0.85, ring * 0.5)) * pile;
		col *= 1.0 - 0.10 * (1.0 - smoothstep(0.3, 1.5, edge));
		COLOR = vec4(col, tex.a * tint.a);
	} else if (style == 7) {
		// FLAGSTONES IN GRASS (garden): one stone a cell, its outline wobbly, grass (col_b) in the gaps
		float wob = 2.2 + 2.2 * noise(world / 5.0 + id * 3.0);
		float stone = smoothstep(wob - 0.8, wob + 0.8, edge);
		float sh = 0.88 + 0.14 * hash(id) + 0.06 * noise(world / 3.0);
		vec3 st = col_a * sh * (1.0 + 0.06 * (1.0 - smoothstep(wob, wob + 4.0, min(fx, fy))));
		vec3 gr = col_b * (0.75 + 0.35 * noise(world / 1.2) + 0.10 * noise(world / 6.0));
		COLOR = vec4(mix(gr, st, stone), tex.a * tint.a);
	} else if (style == 8) {
		// TERRACOTTA (sunroom): one fired tile a cell, each its own shade, cream grout (col_b), soft wear
		float sh = 0.86 + 0.20 * hash(id + 5.0);
		sh *= 0.94 + 0.10 * fbm(world / 9.0 + id);
		vec3 col = col_a * sh;
		col *= 1.0 + 0.06 * (1.0 - smoothstep(1.5, 4.0, min(fx, fy)));
		col *= 1.0 - 0.08 * (1.0 - smoothstep(1.5, 4.0, min(40.0 - fx, 40.0 - fy)));
		col = mix(col, col_b * 0.85, 1.0 - smoothstep(0.8, 2.0, edge));
		COLOR = vec4(col, tex.a * tint.a);
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
	COLOR = vec4(base * shade, tex.a * tint.a);
	}
}
