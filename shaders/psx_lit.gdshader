shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled, vertex_lighting;

// Configurações da Textura
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 modulate_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

// Configurações do Efeito PS1
uniform float jitter_intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec2 snap_resolution = vec2(320.0, 180.0);
uniform float affine_amount : hint_range(0.0, 1.0) = 1.0;

// Variáveis passadas do Vertex para o Fragment
varying vec2 v_uv_affine;
varying float v_w;
varying vec2 v_uv_regular;

void vertex() {
	// Aplica escala e offset de UV
	v_uv_regular = UV * uv_scale + uv_offset;
	
	// Transforma o vértice para o espaço de recorte (Clip Space)
	vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	
	// 1. Vertex Snapping (Tremor de polígonos clássico do PS1)
	vec2 grid = snap_resolution * (1.0 - jitter_intensity * 0.5);
	vec4 snapped_pos = clip_pos;
	snapped_pos.xyz = clip_pos.xyz / clip_pos.w;
	snapped_pos.xy = floor(grid * snapped_pos.xy) / grid;
	snapped_pos.xyz *= clip_pos.w;
	
	POSITION = mix(clip_pos, snapped_pos, jitter_intensity);
	
	// 2. Affine Texture Mapping (Distorção de textura sem correção de perspectiva)
	v_w = POSITION.w;
	v_uv_affine = v_uv_regular * v_w;
}

void fragment() {
	// Interpola entre UV normal e UV distorcido do PS1
	vec2 final_uv = mix(v_uv_regular, v_uv_affine / v_w, affine_amount);
	
	vec4 tex_color = texture(albedo_texture, final_uv) * modulate_color * COLOR;
	
	ALBEDO = tex_color.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
