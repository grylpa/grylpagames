shader_type canvas_item;

// Define two colors that can be set externally via script (Uniforms)
uniform vec4 color_left : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Default: Red
uniform vec4 color_right : source_color = vec4(0.0, 0.0, 1.0, 1.0); // Default: Blue

void fragment() {
    // 1. Get the base texture color and alpha.
    // This assumes your base sprite is white/grayscale and has the correct shape/alpha mask.
    vec4 base_tex = texture(TEXTURE, UV);
    
    // 2. Determine which color to apply based on the X-coordinate (UV.x)
    // UV.x ranges from 0.0 (left edge) to 1.0 (right edge).
    vec4 target_color;
    
    if (UV.x < 0.5) {
        // Left half
        target_color = color_left;
    } else {
        // Right half
        target_color = color_right;
    }
    
    // 3. Apply the custom color, but retain the original sprite's transparency (alpha).
    // Multiplying the white base texture by the target color gives us the final color.
    COLOR.rgb = base_tex.rgb * target_color.rgb;
    COLOR.a = base_tex.a; // Preserve the original sprite's transparency/shape
}
