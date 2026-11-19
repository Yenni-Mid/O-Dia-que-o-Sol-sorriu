extends StaticBody3D
## Passagem bloqueada por correntes (exige Alicate de Corte) ou tábuas (exige Pé de Cabra).
## Entra no grupo "door_leaf" para manter o NavMesh transitável após abertura.

const LAYER_ENV_AND_INTERACT: int = (1 << 0) | (1 << 3)
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

@export_enum("chain_gate", "boarded_door") var passage_type: String = "chain_gate"
@export var required_tool: String = "bolt_cutters"
@export var passage_size: Vector3 = Vector3(3.6, 2.8, 0.28)
@export var label_name: String = "Portão Acorrentado"


func _ready() -> void:
	collision_layer = LAYER_ENV_AND_INTERACT
	collision_mask = 0
	add_to_group("door_leaf")

	if passage_type == "boarded_door" and required_tool == "bolt_cutters":
		required_tool = "crowbar"

	var col: CollisionShape3D = CollisionShape3D.new()
	var box_s: BoxShape3D = BoxShape3D.new()
	box_s.size = passage_size
	col.shape = box_s
	col.position = Vector3(0.0, passage_size.y * 0.5, 0.0)
	add_child(col)

	_build_visual()


func interact() -> void:
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if inv != null and inv.has_method("has_tool") and bool(inv.call("has_tool", required_tool)):
		if passage_type == "chain_gate":
			AudioManager.play_metal_cut()
			GameEvents.player_noise_emitted.emit(global_position, 8.0)
			GameEvents.status_message_requested.emit("%s aberto com o %s!" % [label_name, _get_tool_display_name()])
		else:
			AudioManager.play_wood_break()
			GameEvents.player_noise_emitted.emit(global_position, 14.0)
			GameEvents.status_message_requested.emit("%s arrombado com o %s! O barulho ecoou!" % [label_name, _get_tool_display_name()])
		queue_free()
		return

	AudioManager.play_locked()
	GameEvents.status_message_requested.emit("%s — Requer: %s" % [label_name, _get_tool_display_name()])


func get_interaction_prompt() -> String:
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	var has_req: bool = (inv != null and inv.has_method("has_tool") and bool(inv.call("has_tool", required_tool)))
	if has_req:
		if passage_type == "chain_gate":
			return "[E] Cortar Correntes (%s)" % _get_tool_display_name()
		return "[E] Arrancar Tábuas (%s)" % _get_tool_display_name()
	return "[Bloqueado — Requer %s]" % _get_tool_display_name()


func _get_tool_display_name() -> String:
	if required_tool == "bolt_cutters":
		return "Alicate de Corte"
	if required_tool == "crowbar":
		return "Pé de Cabra"
	return required_tool


func _make_mat(color: Color) -> ShaderMaterial:
	var smat: ShaderMaterial = ShaderMaterial.new()
	smat.shader = PSX_LIT_SHADER
	smat.set_shader_parameter("modulate_color", color)
	smat.set_shader_parameter("snap_resolution", Vector2(320.0, 180.0))
	return smat


func _add_bar(size: Vector3, pos: Vector3, mat: ShaderMaterial, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.rotation_degrees = rot_deg
	m.material_override = mat
	add_child(m)


func _build_visual() -> void:
	if passage_type == "chain_gate":
		var iron_mat: ShaderMaterial = _make_mat(Color(0.24, 0.25, 0.28))
		var rust_mat: ShaderMaterial = _make_mat(Color(0.46, 0.28, 0.16))
		var brass_mat: ShaderMaterial = _make_mat(Color(0.76, 0.62, 0.22))
		var w: float = passage_size.x
		var h: float = passage_size.y
		_add_bar(Vector3(w, 0.10, 0.10), Vector3(0.0, h * 0.85, 0.0), iron_mat)
		_add_bar(Vector3(w, 0.10, 0.10), Vector3(0.0, h * 0.22, 0.0), iron_mat)
		var bar_count: int = maxi(4, int(round(w / 0.52)))
		for i: int in range(bar_count):
			var frac: float = float(i) / float(maxi(1, bar_count - 1))
			var x_pos: float = lerpf(-w * 0.45, w * 0.45, frac)
			_add_bar(Vector3(0.07, h, 0.07), Vector3(x_pos, h * 0.5, 0.0), iron_mat)
		# Corrente cruzada e cadeado pesado no centro
		_add_bar(Vector3(w * 0.72, 0.09, 0.14), Vector3(0.0, h * 0.48, 0.0), rust_mat, Vector3(0.0, 0.0, 10.0))
		_add_bar(Vector3(w * 0.72, 0.09, 0.14), Vector3(0.0, h * 0.48, 0.0), rust_mat, Vector3(0.0, 0.0, -10.0))
		_add_bar(Vector3(0.24, 0.28, 0.18), Vector3(0.0, h * 0.45, 0.06), brass_mat)
	else:
		var wood_a: ShaderMaterial = _make_mat(Color(0.46, 0.31, 0.18))
		var wood_b: ShaderMaterial = _make_mat(Color(0.34, 0.22, 0.12))
		var dark_mat: ShaderMaterial = _make_mat(Color(0.14, 0.10, 0.07))
		var w: float = passage_size.x
		var h: float = passage_size.y
		_add_bar(Vector3(w * 0.94, 0.22, 0.10), Vector3(0.0, h * 0.72, 0.02), wood_a, Vector3(0.0, 0.0, -7.0))
		_add_bar(Vector3(w * 0.96, 0.24, 0.10), Vector3(0.0, h * 0.48, -0.02), wood_b, Vector3(0.0, 0.0, 6.0))
		_add_bar(Vector3(w * 0.92, 0.20, 0.10), Vector3(0.0, h * 0.26, 0.03), wood_a, Vector3(0.0, 0.0, -4.0))
		_add_bar(Vector3(w * 0.82, h * 0.96, 0.05), Vector3(0.0, h * 0.48, -0.05), dark_mat)
