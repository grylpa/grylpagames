shader_type canvas_item;

uniform vec4 color_left : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 color_right : source_color = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
    vec4 base_tex = texture(TEXTURE, UV);
    vec4 target_color;
    if (UV.x < 0.5) {
        target_color = color_left;
    } else {
        target_color = color_right;
    }
    COLOR.rgb = base_tex.rgb * target_color.rgb;
    COLOR.a = base_tex.a;
}
