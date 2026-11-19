shader_type canvas_item;

// Pós-processamento PSX: pixelização alinhada à SubViewport, color grading com split-toning
// (sombras frias / luzes quentes, sem o "filtro amarelo" chapado), vinheta, grão de filme,
// scanlines sutis, dithering Bayer 4x4 e efeitos dinâmicos de estado (sol, dano, sanidade, fogo).

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

group_uniforms Resolucao;
uniform float pixel_scale : hint_range(1.0, 8.0) = 4.0;
uniform int color_depth : hint_range(1, 8) = 6;
uniform float dither_strength : hint_range(0.0, 2.0) = 0.4;

group_uniforms Grading;
uniform float contrast : hint_range(0.5, 1.5) = 1.08;
uniform float saturation : hint_range(0.0, 1.5) = 0.86;
uniform float brightness : hint_range(0.5, 1.5) = 1.05;
uniform vec3 shadow_tint : source_color = vec3(0.86, 0.92, 1.0);
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.96, 0.88);

group_uniforms Filme;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.42;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.035;
uniform float scanline_strength : hint_range(0.0, 0.3) = 0.05;

group_uniforms Estado;
uniform float aberration : hint_range(0.0, 2.0) = 0.0;
uniform float sun_exposure : hint_range(0.0, 1.0) = 0.0;
uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;
uniform float sanity_distortion : hint_range(0.0, 1.0) = 0.0;
uniform float fire_warmth : hint_range(0.0, 1.0) = 0.0;
uniform float fade_to_black : hint_range(0.0, 1.0) = 0.0;

const mat4 BAYER_MATRIX = mat4(
	vec4(-4.0,  0.0, -3.0,  1.0),
	vec4( 2.0, -2.0,  3.0, -1.0),
	vec4(-3.0,  1.0, -4.0,  0.0),
	vec4( 3.0, -1.0,  2.0, -2.0)
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 snap_uv(vec2 uv, vec2 res) {
	return (floor(uv * res) + 0.5) / res;
}

void fragment() {
	vec2 res = (1.0 / SCREEN_PIXEL_SIZE) / pixel_scale;
	vec2 uv = SCREEN_UV;

	// Distorção ondulante da Epidemia da Verdade (sanidade baixa).
	float wob = sanity_distortion;
	uv.x += sin(uv.y * 26.0 + TIME * 2.3) * 0.004 * wob;
	uv.y += cos(uv.x * 19.0 + TIME * 1.7) * 0.003 * wob;

	vec2 cell = floor(uv * res);
	vec2 grid_uv = (cell + 0.5) / res;
	vec2 from_center = grid_uv - 0.5;

	// Aberração cromática radial (sempre alinhada aos pixels grandes).
	vec2 ca = from_center * (aberration + wob * 0.8) * 0.012;
	vec3 color;
	color.r = texture(screen_texture, snap_uv(clamp(grid_uv + ca, 0.0, 1.0), res)).r;
	color.g = texture(screen_texture, grid_uv).g;
	color.b = texture(screen_texture, snap_uv(clamp(grid_uv - ca, 0.0, 1.0), res)).b;

	// Color grading.
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luma), color, saturation - wob * 0.35);
	color = (color - 0.5) * contrast + 0.5;
	color *= brightness;
	luma = clamp(dot(color, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
	color *= mix(shadow_tint, highlight_tint, smoothstep(0.1, 0.8, luma));
	color *= mix(vec3(1.0), vec3(1.07, 1.0, 0.88), fire_warmth);

	// Exposição ao Sol Sorridente: imagem "queimada", desbotada e quente.
	vec3 bleached = vec3(luma) * vec3(1.25, 1.12, 0.8) + 0.07;
	color = mix(color, bleached, sun_exposure * 0.45);

	// Scanlines e grão (grão anima a 24 fps, como película).
	color *= 1.0 - scanline_strength * mod(cell.y, 2.0);
	float frame = floor(TIME * 24.0);
	color += (hash(cell + frame) - 0.5) * (grain_strength + wob * 0.04);

	// Vinheta + bordas de estado.
	float d = dot(from_center, from_center) * 2.0;
	float vig = smoothstep(0.15, 1.0, d);
	color *= 1.0 - vig * (vignette_strength + wob * 0.25);
	color += vec3(1.0, 0.8, 0.35) * vig * sun_exposure * 0.22;
	color = mix(color, vec3(0.55, 0.02, 0.02), clamp(damage_flash, 0.0, 1.0) * (0.12 + vig * 0.75));
	color *= 1.0 - fade_to_black;

	// Dithering Bayer 4x4 + quantização de cor (banding de PS1).
	ivec2 pixel_coord = ivec2(mod(cell, 4.0));
	float dither_value = BAYER_MATRIX[pixel_coord.x][pixel_coord.y];
	float levels = pow(2.0, float(color_depth)) - 1.0;
	color += (dither_value / 16.0) * (1.0 / levels) * dither_strength;
	color = clamp(floor(color * levels + 0.5) / levels, 0.0, 1.0);

	COLOR = vec4(color, 1.0);
}
