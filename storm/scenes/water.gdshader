shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0);
uniform vec4 water_color : source_color = vec4(0, 0.58, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (tex.a < 0.01) {
		discard;
	}

	// Above fill → show original bucket (outline + interior)
	if (UV.y < 1.0 - fill_amount) {
		discard;
	} else {
		// Below fill → water tint (still uses texture alpha so exterior stays cut)
		COLOR = vec4(water_color.rgb, water_color.a * tex.a);
	}
}
