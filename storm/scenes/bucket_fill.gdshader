shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0);
uniform vec4 water_color : source_color = vec4(0, 0.58, 1.0, 1.0);
uniform float interior_threshold : hint_range(0.0, 1.0) = 0.02;
uniform sampler2D mask_tex : filter_nearest, repeat_disable;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 mask = texture(mask_tex, UV);

	if (mask.a < 0.1) {
		discard;
	}

	// how "bright" the pixel is (white interior will be high, black outline low)
	float lum = dot(mask.rgb, vec3(0.299, 0.587, 0.114));
	bool is_interior = lum >= interior_threshold;

	// Above fill: always show original
	if (UV.y < 1.0 - fill_amount) {
		COLOR = tex;
	} else {
		// Below fill: tint only interior, keep outline as-is
		if (is_interior) {
			COLOR = vec4(water_color.rgb, water_color.a * tex.a);
		} else {
			COLOR = tex;
		}
	}
}
