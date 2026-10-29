shader_type canvas_item;

// Behind Storm's tool menu (level.gd _show_menu_blur): the board blurred, slightly dimmed, inside a
// rounded rect, with the slot over the tapped tile (`hole`, in this rect's pixels) left sharp.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 rect_size = vec2(100.0);
uniform vec4 hole = vec4(0.0);
uniform float corner = 10.0;
uniform float blur_lod = 3.6;

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 px = UV * rect_size;
	// outside the menu's rounded outline: nothing
	float outer = rounded_box(px - rect_size * 0.5, rect_size * 0.5, corner);
	// inside the tapped tile's slot: nothing (the board shows sharp)
	vec2 hc = hole.xy + hole.zw * 0.5;
	float inner = rounded_box(px - hc, hole.zw * 0.5 - vec2(2.0), corner * 0.6);
	float a = (1.0 - smoothstep(-1.0, 1.0, outer)) * smoothstep(-1.0, 1.0, inner);
	vec2 d = SCREEN_PIXEL_SIZE * 5.0;
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb * 0.4;
	c += textureLod(screen_tex, SCREEN_UV + vec2(d.x, d.y), blur_lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV + vec2(-d.x, d.y), blur_lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV + vec2(d.x, -d.y), blur_lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV + vec2(-d.x, -d.y), blur_lod).rgb * 0.15;
	COLOR = vec4(c * 0.88, a);
}
