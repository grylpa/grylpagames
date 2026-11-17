shader_type canvas_item;

// THE DARK OVER A 3-D POSTER (scripts/menu_poster3d.gd `add_darkness`): a veil of `dark_col` at `dark`, with holes
// where light falls -- round pools (`lamps`: xy the place on screen, z the radius, w the strength) and cones
// (`cones`: xy the lamp, z its heading, w its reach; `cone_w` the strength, `cone_half` the half-angle). A see-through
// 3-D view cannot add light; taking darkness away can.

uniform vec2 size = vec2(680.0, 1200.0);
uniform vec4 dark_col : source_color = vec4(0.0, 0.0, 0.02, 1.0);
uniform float dark = 0.0;
uniform vec4 lamps[12];
uniform vec4 cones[2];
uniform vec2 cone_w = vec2(0.0);       // a vec2, not a float array: the compatibility renderer dropped the array
uniform float cone_half = 0.42;

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
	COLOR = vec4(dark_col.rgb, dark * (1.0 - clamp(l, 0.0, 1.0)));
}
