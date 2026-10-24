shader_type canvas_item;

// THE WATER, on the CanvasGroup that holds one room's puddles (scripts/flood_layer.gd). The group has
// already drawn every circle into one layer, white where there is water, so overlaps are merged; this
// turns that layer into water and lights its shoreline -- the outline of all the puddles together,
// found by looking a few pixels around for dry floor -- and keeps it to this room's floor: a pixel on
// any tile that is not this room's floor (floor_mask: room id + 1 on floor, 0 on walls, bricks
// and drains; a doorway is floor) is dropped. The shoreline is found from the circles alone, so it is not drawn
// along a wall.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 water_color : source_color = vec4(0.15, 0.45, 0.95, 0.85);
uniform float shore_px = 3.0;   // how wide the bright shoreline is
uniform float depth_px = 22.0;  // how far in from the shore the water reaches its deepest color
uniform sampler2D floor_mask : filter_nearest, repeat_disable;
uniform float room_code = 1.0;  // this room's id + 1, as the mask stores it
uniform vec2 board_tiles = vec2(1.0, 1.0);
uniform float tile_px = 40.0;
// THE SURFACE. The water moves: a slow ripple field (two drifting noises) gives it normals, the
// light from the top left glints off them, and the floor seen through it is brightened and dimmed in
// soft moving patches, as light through a ruffled surface is. `t` is the game's clock in seconds
// (flood_layer.gd), so it stills when the game does. Before, the water was a flat tinted disc.
uniform float t = 0.0;

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

float ripple(vec2 p) {
	return noise(p * 2.2 + vec2(t * 0.35, t * 0.22)) * 0.6 + noise(p * 4.1 - vec2(t * 0.28, -t * 0.4) + 3.7) * 0.4;
}

// Where this pixel is, in the flood layer's own pixels -- taken from the group's geometry in the
// vertex stage. Working it out from SCREEN_UV and the layer's screen transform put the floor mask
// in the wrong place entirely: water on drains, none against the walls.
varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

float cover(vec2 uv) {
	return textureLod(screen_texture, uv, 0.0).a;
}

void fragment() {
	float a = cover(SCREEN_UV);
	if (a <= 0.001) {
		discard;
	}
	vec2 tp = local_px / tile_px;
	ivec2 cell = ivec2(floor(tp));
	if (cell.x < 0 || cell.y < 0 || float(cell.x) >= board_tiles.x || float(cell.y) >= board_tiles.y) {
		discard;
	}
	if (abs(texelFetch(floor_mask, cell, 0).r * 255.0 - room_code) > 0.5) {
		discard;
	}
	// How close is the nearest dry floor? Looked for in eight directions at two distances.
	float near_dry = 0.0;
	float far_dry = 0.0;
	for (int k = 0; k < 8; k++) {
		vec2 dir = vec2(cos(float(k) * 0.785398), sin(float(k) * 0.785398)) * SCREEN_PIXEL_SIZE;
		near_dry = max(near_dry, 1.0 - cover(SCREEN_UV + dir * shore_px));
		far_dry += (1.0 - cover(SCREEN_UV + dir * depth_px)) / 8.0;
	}
	vec3 shallow = mix(water_color.rgb, vec3(1.0), 0.28);
	vec3 deep = water_color.rgb * 0.8;
	float depth = 1.0 - far_dry;
	vec3 col = mix(shallow, deep, depth);
	// the surface: normals from the ripple field, a glint from the top-left light, moving patches
	float e = 0.05;
	float hx = ripple(tp + vec2(e, 0.0)) - ripple(tp - vec2(e, 0.0));
	float hy = ripple(tp + vec2(0.0, e)) - ripple(tp - vec2(0.0, e));
	vec3 n = normalize(vec3(-hx * 2.2, -hy * 2.2, 1.0));
	vec3 half_v = normalize(normalize(vec3(-0.45, -0.55, 0.70)) + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(n, half_v), 0.0), 60.0);
	col *= 0.90 + 0.18 * ripple(tp * 0.7 + 9.0);
	col = mix(col, vec3(0.85, 0.94, 1.0), near_dry * 0.45);
	col += vec3(1.0, 1.0, 0.97) * spec * 0.55 * smoothstep(0.0, 0.4, depth + 0.2);
	COLOR = vec4(col, water_color.a * a * mix(0.55, 0.88, depth));
}
