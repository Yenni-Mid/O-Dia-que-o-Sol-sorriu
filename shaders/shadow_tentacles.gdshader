shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled, vertex_lighting;

// Sombra Viva: massa negra ondulante com veias pulsantes levemente emissivas
// (legível no escuro sem precisar de luz extra na cena).
uniform vec4 core_color : source_color = vec4(0.012, 0.004, 0.02, 1.0);
uniform vec4 vein_color : source_color = vec4(0.36, 0.05, 0.24, 1.0);
uniform float wave_speed = 3.2;
uniform float wave_height = 0.16;
uniform float vein_glow = 1.4;
uniform float jitter_intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec2 snap_resolution = vec2(320.0, 240.0);

void vertex() {
	float w = sin(TIME * wave_speed + VERTEX.x * 3.1) * cos(TIME * wave_speed * 0.77 + VERTEX.z * 3.7);
	float w2 = sin(TIME * 1.3 + (VERTEX.x + VERTEX.z) * 5.0) * 0.5;
	VERTEX.y += max(0.0, w + w2 * 0.5) * wave_height;

	vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 snapped = clip_pos;
	snapped.xyz /= clip_pos.w;
	snapped.xy = floor(snap_resolution * snapped.xy) / snap_resolution;
	snapped.xyz *= clip_pos.w;
	POSITION = mix(clip_pos, snapped, jitter_intensity);
}

void fragment() {
	vec2 p = UV * 6.0;
	float veins = abs(sin(p.x * 2.3 + sin(p.y * 3.1 + TIME * 1.2) * 1.4 + TIME * 0.6));
	veins = 1.0 - smoothstep(0.0, 0.14, veins);
	float pulse = 0.6 + 0.4 * sin(TIME * 2.4);
	ALBEDO = core_color.rgb;
	EMISSION = vein_color.rgb * veins * pulse * vein_glow;
	ROUGHNESS = 1.0;
}
