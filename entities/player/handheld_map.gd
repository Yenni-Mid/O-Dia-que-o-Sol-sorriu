class_name HandheldMap
extends Node3D
## Mapa Físico Diegético [M] segurado na mão esquerda em 1ª pessoa (sem pausar o jogo).
## O papel dobrado recebe iluminação real em tempo real — no breu sem o lampião aceso,
## ou longe de uma fogueira/poste, o pergaminho fica quase ilegível.

const MapCanvasScript := preload("res://ui/field_map_canvas.gd")

const HIDDEN_POS: Vector3 = Vector3(-0.18, -0.56, -0.34)
const HIDDEN_ROT_DEG: Vector3 = Vector3(58.0, 14.0, 12.0)
const RAISED_POS: Vector3 = Vector3(-0.055, -0.025, -0.43)
const RAISED_ROT_DEG: Vector3 = Vector3(6.0, 7.0, -1.2)

var is_open: bool = false
var _open_blend: float = 0.0
var _redraw_timer: float = 0.0
var _sway_time: float = 0.0

var _viewport: SubViewport
var _map_canvas: Control
var _paper_mesh_inst: MeshInstance3D
var _paper_mat: StandardMaterial3D
var _lantern_fill: OmniLight3D
var _left_hand_group: Node3D


func _ready() -> void:
	_ensure_input_actions()
	_build_map_viewport()
	_build_folded_paper_mesh()
	_build_left_hand_and_sleeve()
	_build_lantern_fill_light()

	position = HIDDEN_POS
	rotation_degrees = HIDDEN_ROT_DEG
	visible = false

	GameEvents.player_hidden_changed.connect(_on_auto_close_flag)
	GameEvents.echo_opened.connect(_on_echo_opened)
	GameEvents.dialogue_requested.connect(_on_dialogue_requested)
	GameEvents.vhs_tape_requested.connect(_on_vhs_requested)
	GameEvents.keypad_requested.connect(_on_keypad_requested)
	GameEvents.item_inspect_requested.connect(_on_dialogue_requested)
	GameEvents.night_transition_requested.connect(_on_night_transition_close)
	GameEvents.player_died.connect(_on_force_close)
	GameEvents.sanity_depleted.connect(_on_force_close)


func _exit_tree() -> void:
	if _paper_mat != null:
		_paper_mat.albedo_texture = null
	if _paper_mesh_inst != null:
		_paper_mesh_inst.material_override = null
		_paper_mesh_inst.mesh = null
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_paper_mat = null
	_paper_mesh_inst = null
	_map_canvas = null
	_viewport = null
	_lantern_fill = null
	_left_hand_group = null


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("toggle_map"):
		return
	if get_tree().paused:
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and bool(player.get("is_hidden")):
		return
	set_map_open(not is_open, true)
	get_viewport().set_input_as_handled()


func set_map_open(open_state: bool, play_audio: bool = true) -> void:
	if is_open == open_state:
		return
	is_open = open_state
	if is_open:
		visible = true
		if _viewport != null:
			_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if _map_canvas != null:
			_map_canvas.queue_redraw()
		_redraw_timer = 0.0
	if play_audio:
		AudioManager.play_paper()
	GameEvents.map_toggled.emit(is_open)


func _process(delta: float) -> void:
	if get_tree().paused and is_open:
		set_map_open(false, false)

	var target_blend: float = 1.0 if is_open else 0.0
	_open_blend = move_toward(_open_blend, target_blend, 6.2 * delta)
	var ease_t: float = smoothstep(0.0, 1.0, _open_blend)

	if _open_blend <= 0.005 and not is_open:
		visible = false
		if _viewport != null and _viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if _lantern_fill != null:
			_lantern_fill.visible = false
		return

	visible = true
	_sway_time += delta
	var sway_x: float = sin(_sway_time * 1.9) * 0.0022 * ease_t
	var sway_y: float = cos(_sway_time * 2.5) * 0.0028 * ease_t
	position = HIDDEN_POS.lerp(RAISED_POS, ease_t) + Vector3(sway_x, sway_y, 0.0)
	rotation_degrees = HIDDEN_ROT_DEG.lerp(RAISED_ROT_DEG, ease_t)

	# Atualiza o desenho em tempo real do jogador/fogueiras sem sobrecarregar cada frame
	_redraw_timer += delta
	if _redraw_timer >= 0.12 and _map_canvas != null:
		_redraw_timer = 0.0
		_map_canvas.queue_redraw()

	# Dependência do Lampião: ilumina o mapa em sincronia com a chama da mão direita!
	_sync_lantern_fill_light(ease_t)


func _sync_lantern_fill_light(ease_t: float) -> void:
	if _lantern_fill == null:
		return
	var lantern: LanternSystem = get_tree().get_first_node_in_group("lantern") as LanternSystem
	if lantern != null and lantern.is_lit and ease_t > 0.15:
		_lantern_fill.visible = true
		var base_energy: float = 1.35
		if lantern.omni_light != null:
			base_energy = lantern.omni_light.light_energy
		var flicker_scale: float = clampf(base_energy / 1.35, 0.45, 2.2)
		_lantern_fill.light_energy = 0.85 * flicker_scale * ease_t
	else:
		_lantern_fill.visible = false


func _build_map_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "MapTextureViewport"
	_viewport.size = Vector2i(512, 384)
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	_map_canvas = Control.new()
	_map_canvas.name = "DiegeticMapCanvas"
	_map_canvas.set_script(MapCanvasScript)
	_map_canvas.set("is_diegetic_paper", true)
	_map_canvas.position = Vector2.ZERO
	_map_canvas.size = Vector2(512.0, 384.0)
	_viewport.add_child(_map_canvas)


func _build_folded_paper_mesh() -> void:
	# Grade 3x2 dobrada (4 vertices x 3 linhas) simulando vincos físicos no papel
	var total_w: float = 0.44
	var total_h: float = 0.30
	var cols: int = 3
	var rows: int = 2
	var z_offsets: Array[Array] = [
		[0.004, -0.009, 0.006, -0.005],
		[-0.002, 0.011, -0.006, 0.004],
		[0.006, -0.007, 0.007, -0.004],
	]

	var grid_pts: Array[Array] = []
	var grid_uvs: Array[Array] = []
	for r: int in range(rows + 1):
		var row_pts: Array[Vector3] = []
		var row_uvs: Array[Vector2] = []
		var v_coord: float = float(r) / float(rows)
		var y_val: float = lerpf(total_h * 0.5, -total_h * 0.5, v_coord)
		for c: int in range(cols + 1):
			var u_coord: float = float(c) / float(cols)
			var x_val: float = lerpf(-total_w * 0.5, total_w * 0.5, u_coord)
			var z_val: float = float((z_offsets[r] as Array)[c])
			row_pts.append(Vector3(x_val, y_val, z_val))
			row_uvs.append(Vector2(u_coord, v_coord))
		grid_pts.append(row_pts)
		grid_uvs.append(row_uvs)

	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()

	for r: int in range(rows):
		for c: int in range(cols):
			var p00: Vector3 = (grid_pts[r] as Array)[c] as Vector3
			var p10: Vector3 = (grid_pts[r] as Array)[c + 1] as Vector3
			var p01: Vector3 = (grid_pts[r + 1] as Array)[c] as Vector3
			var p11: Vector3 = (grid_pts[r + 1] as Array)[c + 1] as Vector3
			var uv00: Vector2 = (grid_uvs[r] as Array)[c] as Vector2
			var uv10: Vector2 = (grid_uvs[r] as Array)[c + 1] as Vector2
			var uv01: Vector2 = (grid_uvs[r + 1] as Array)[c] as Vector2
			var uv11: Vector2 = (grid_uvs[r + 1] as Array)[c + 1] as Vector2

			var panel_normal: Vector3 = (p11 - p00).cross(p10 - p00).normalized()
			if panel_normal.z < 0.0:
				panel_normal = -panel_normal

			# Triângulo 1 (p00 -> p10 -> p11)
			verts.append_array([p00, p10, p11])
			norms.append_array([panel_normal, panel_normal, panel_normal])
			uvs.append_array([uv00, uv10, uv11])

			# Triângulo 2 (p00 -> p11 -> p01)
			verts.append_array([p00, p11, p01])
			norms.append_array([panel_normal, panel_normal, panel_normal])
			uvs.append_array([uv00, uv11, uv01])

	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	_paper_mat = StandardMaterial3D.new()
	_paper_mat.albedo_texture = _viewport.get_texture()
	_paper_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_paper_mat.roughness = 0.94
	_paper_mat.metallic = 0.0
	_paper_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_paper_mesh_inst = MeshInstance3D.new()
	_paper_mesh_inst.name = "FoldedPaperMesh"
	_paper_mesh_inst.mesh = mesh
	_paper_mesh_inst.material_override = _paper_mat
	_paper_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_paper_mesh_inst)


func _build_left_hand_and_sleeve() -> void:
	_left_hand_group = Node3D.new()
	_left_hand_group.name = "LeftHandGroup"
	_left_hand_group.position = Vector3(-0.22, -0.04, 0.015)
	_left_hand_group.rotation_degrees = Vector3(8.0, 14.0, -18.0)
	add_child(_left_hand_group)

	var skin_mat: StandardMaterial3D = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.72, 0.56, 0.44)
	skin_mat.roughness = 0.85

	var sleeve_mat: StandardMaterial3D = StandardMaterial3D.new()
	sleeve_mat.albedo_color = Color(0.14, 0.12, 0.10)
	sleeve_mat.roughness = 0.92

	# Palma e dedos apoiando atrás da borda esquerda do mapa + polegar segurando a frente
	var palm_mesh: BoxMesh = BoxMesh.new()
	palm_mesh.size = Vector3(0.056, 0.072, 0.026)
	_add_hand_part("LeftPalm", palm_mesh, Vector3(-0.012, 0.0, -0.018), skin_mat)

	var thumb_mesh: BoxMesh = BoxMesh.new()
	thumb_mesh.size = Vector3(0.028, 0.044, 0.016)
	var thumb_mi: MeshInstance3D = _add_hand_part("LeftThumb", thumb_mesh, Vector3(0.016, 0.020, 0.008), skin_mat)
	thumb_mi.rotation_degrees = Vector3(0.0, 0.0, -24.0)

	var fingers_mesh: BoxMesh = BoxMesh.new()
	fingers_mesh.size = Vector3(0.036, 0.058, 0.020)
	_add_hand_part("LeftFingers", fingers_mesh, Vector3(0.014, -0.012, -0.020), skin_mat)

	var sleeve_mesh: BoxMesh = BoxMesh.new()
	sleeve_mesh.size = Vector3(0.076, 0.068, 0.22)
	var sleeve_mi: MeshInstance3D = _add_hand_part("LeftCoatSleeve", sleeve_mesh, Vector3(-0.045, -0.052, 0.095), sleeve_mat)
	sleeve_mi.rotation_degrees = Vector3(-24.0, -16.0, 0.0)


func _add_hand_part(p_name: String, m_res: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = p_name
	mi.mesh = m_res
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_left_hand_group.add_child(mi)
	return mi


func _build_lantern_fill_light() -> void:
	_lantern_fill = OmniLight3D.new()
	_lantern_fill.name = "PaperLanternFill"
	_lantern_fill.position = Vector3(0.24, 0.02, 0.24)
	_lantern_fill.light_color = Color(1.0, 0.65, 0.24)
	_lantern_fill.light_energy = 0.0
	_lantern_fill.omni_range = 1.15
	_lantern_fill.omni_attenuation = 1.6
	_lantern_fill.shadow_enabled = false
	_lantern_fill.visible = false
	add_child(_lantern_fill)


func _on_auto_close_flag(state: bool) -> void:
	if state and is_open:
		set_map_open(false, false)


func _on_echo_opened(_data: EchoData) -> void:
	if is_open:
		set_map_open(false, false)


func _on_dialogue_requested(_payload: Dictionary) -> void:
	if is_open:
		set_map_open(false, false)


func _on_vhs_requested(_id: String, _title: String, _lines: Array) -> void:
	if is_open:
		set_map_open(false, false)


func _on_keypad_requested(_safe: Node, _title: String, _code: String) -> void:
	if is_open:
		set_map_open(false, false)


func _on_night_transition_close(_night_num: int) -> void:
	if is_open:
		set_map_open(false, false)


func _on_force_close() -> void:
	if is_open:
		set_map_open(false, false)


func _ensure_input_actions() -> void:
	if InputMap.has_action("toggle_map"):
		return
	InputMap.add_action("toggle_map")
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = KEY_M
	InputMap.action_add_event("toggle_map", key_event)
