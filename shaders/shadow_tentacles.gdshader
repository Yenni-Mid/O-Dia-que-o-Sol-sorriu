shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled, vertex_lighting;

uniform vec4 core_color : source_color = vec4(0.02, 0.01, 0.04, 1.0);
uniform vec4 edge_color : source_color = vec4(0.18, 0.03, 0.12, 1.0);
uniform float wave_speed = 4.2;
uniform float wave_height = 0.14;

void vertex() {
	float wave = sin(TIME * wave_speed + VERTEX.x * 3.5) * cos(TIME * (wave_speed * 0.8) + VERTEX.z * 3.5);
	VERTEX.y += max(0.0, wave) * wave_height;
}

void fragment() {
	float pulse = sin(TIME * 3.0 + UV.x * 8.0 + UV.y * 8.0) * 0.5 + 0.5;
	ALBEDO = mix(core_color.rgb, edge_color.rgb, pulse * 0.45);
	ROUGHNESS = 1.0;
}
