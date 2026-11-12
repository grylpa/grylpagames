shader_type canvas_item;

// THE DRESSMAKER'S WORKTABLE under Polka Dots' panels (2026-11-12; main.gd puts it on a full-screen rect
// on its own layer behind everything): warm wooden boards running across, each its own tone, with long
// grain, the odd knot and a soft warm light from the top left. It replaced green felt. Only the
// surround -- the panels are the stimulus and are untouched.

uniform vec2 size = vec2(680.0, 788.0);

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

void fragment() {
	vec2 p = UV * size;
	float board_h = 92.0;
	float row = floor(p.y / board_h);
	float y_in = p.y - row * board_h;
	// boards end at staggered joints
	float len = 520.0;
	float off = hash(vec2(row, 3.0)) * len;
	float col_i = floor((p.x + off) / len);
	vec2 id = vec2(col_i, row);
	vec3 wood = mix(vec3(0.50, 0.32, 0.18), vec3(0.60, 0.40, 0.23), hash(id + 1.0));
	// grain: long wavy lines along the board
	float g = noise(vec2(p.x / 120.0, y_in / 3.0 + hash(id) * 30.0) + noise(p / 60.0) * 0.8);
	wood *= 0.88 + 0.16 * g;
	wood *= 0.95 + 0.06 * noise(vec2(p.x / 9.0, y_in / 1.4 + row * 7.0));
	// a knot now and then
	vec2 kc = vec2((col_i + 0.3 + 0.4 * hash(id + 5.0)) * len - off, row * board_h + board_h * (0.3 + 0.4 * hash(id + 7.0)));
	float kd = length((p - kc) * vec2(0.5, 1.3));
	wood *= 1.0 - 0.22 * (1.0 - smoothstep(4.0, 11.0, kd)) * step(0.55, hash(id + 9.0));
	// the joints between boards
	float jy = min(y_in, board_h - y_in);
	float jx = min(fract((p.x + off) / len) * len, len - fract((p.x + off) / len) * len);
	wood *= 1.0 - 0.45 * (1.0 - smoothstep(0.0, 1.5, min(jy, jx)));
	wood *= 1.0 + 0.06 * (1.0 - smoothstep(0.0, 3.0, jy)) * step(y_in, board_h * 0.5);
	// warm light from the top left, falling off toward the bottom right
	float light = 1.08 - 0.22 * dot(UV, vec2(0.5, 0.7));
	COLOR = vec4(wood * light, 1.0);
}
