shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Feixe de luz "volumétrico" falso: cilindro aditivo com bordas suaves (fresnel invertido),
// fade nas pontas e leve oscilação. Custo mínimo comparado a fog volumétrico real.
uniform vec4 shaft_color : source_color = vec4(1.0, 0.86, 0.52, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 0.22;

void fragment() {
	float along = UV.y;
	float facing = pow(abs(dot(NORMAL, VIEW)), 1.6);
	float fade = smoothstep(0.0, 0.12, along) * (1.0 - smoothstep(0.6, 1.0, along));
	float drift = 0.85 + 0.15 * sin(TIME * 1.3 + along * 6.0 + UV.x * 12.0);
	ALBEDO = shaft_color.rgb;
	ALPHA = clamp(facing * fade * intensity * drift, 0.0, 1.0);
}
