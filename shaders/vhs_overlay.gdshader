shader_type canvas_item;

uniform float scanline_alpha : hint_range(0.0, 1.0) = 0.18;
uniform float scanline_count : hint_range(60.0, 480.0) = 240.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.35;
uniform vec4 tint_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);

void fragment() {
	float line = sin(UV.y * scanline_count * 3.14159) * 0.5 + 0.5;
	vec2 centered_uv = UV * 2.0 - 1.0;
	float vignette = clamp(dot(centered_uv, centered_uv) * vignette_intensity, 0.0, 1.0);
	float alpha = clamp((1.0 - line) * scanline_alpha + vignette * 0.5, 0.0, 0.75);
	COLOR = vec4(tint_color.rgb * 0.08, alpha);
}
