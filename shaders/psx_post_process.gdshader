shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int color_depth : hint_range(1, 8) = 6;
uniform float dither_strength : hint_range(0.0, 2.0) = 0.35;
uniform vec2 target_resolution = vec2(320.0, 240.0);

const mat4 BAYER_MATRIX = mat4(
	vec4(-4.0,  0.0, -3.0,  1.0),
	vec4( 2.0, -2.0,  3.0, -1.0),
	vec4(-3.0,  1.0, -4.0,  0.0),
	vec4( 3.0, -1.0,  2.0, -2.0)
);

void fragment() {
	vec2 grid_uv = floor(SCREEN_UV * target_resolution) / target_resolution;
	vec3 color = texture(screen_texture, grid_uv).rgb;
	
	ivec2 pixel_coord = ivec2(mod(floor(SCREEN_UV * target_resolution), 4.0));
	float dither_value = BAYER_MATRIX[pixel_coord.x][pixel_coord.y];
	
	float levels = pow(2.0, float(color_depth)) - 1.0;
	
	color += (dither_value / 16.0) * (1.0 / levels) * dither_strength;
	color = clamp(floor(color * levels + 0.5) / levels, 0.0, 1.0);
	
	COLOR = vec4(color, 1.0);
}
