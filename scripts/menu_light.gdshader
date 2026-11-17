shader_type canvas_item;
render_mode blend_add;

// THE LIGHT IN THE DARK OF A 3-D POSTER (scripts/menu_poster3d.gd `add_darkness`): the same pools and cones as
// menu_darkness.gdshader, ADDED in `light_col` (a 2-D layer can add light; the see-through 3-D view cannot), so a
// headlight's beam or a lamp's pool reads as warm light, not only as less dark.

uniform vec2 size = vec2(680.0, 1200.0);
uniform vec4 dark_col : source_color = vec4(0.0, 0.0, 0.02, 1.0);
uniform float dark = 0.0;
uniform vec4 lamps[12];
uniform vec4 cones[2];
uniform vec2 cone_w = vec2(0.0);       // a vec2, not a float array: the compatibility renderer dropped the array
uniform float cone_half = 0.42;
uniform vec4 light_col : source_color = vec4(1.0, 0.85, 0.55, 1.0);
uniform float gain = 0.0;

void fragment() {
	vec2 p = UV * size;
	float l = 0.0;
	for (int i = 0; i < 12; i++) {
		vec4 L = lamps[i];
		if (L.w <= 0.0) { continue; }
		float d = length(p - L.xy) / max(L.z, 1.0);
		l += L.w * pow(clamp(1.0 - d, 0.0, 1.0), 1.5);
	}
	for (int j = 0; j < 2; j++) {
		vec4 C = cones[j];
		float cw = (j == 0) ? cone_w.x : cone_w.y;
		if (cw <= 0.0) { continue; }
		vec2 v = p - C.xy;
		vec2 dir = vec2(cos(C.z), sin(C.z));
		float a = dot(v, dir);
		if (a > 0.0) {
			float perp = abs(v.x * dir.y - v.y * dir.x);
			float ang = atan(perp, a);
			float f = (1.0 - smoothstep(cone_half * 0.5, cone_half, ang)) * clamp(1.0 - a / C.w, 0.0, 1.0) * smoothstep(0.0, 18.0, a);
			l += cw * f;
		}
	}
	COLOR = vec4(light_col.rgb * gain * clamp(l, 0.0, 1.0), 1.0);
}
