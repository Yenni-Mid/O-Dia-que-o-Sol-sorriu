extends Area3D
## Ferramenta de exploração coletável (Alicate de Corte, Pé de Cabra ou Rádio Portátil).

const LAYER_INTERACTABLES: int = 1 << 3
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

@export_enum("bolt_cutters", "crowbar", "radio") var tool_id: String = "bolt_cutters"
@export var tool_name: String = "Alicate de Corte"

var _visual_root: Node3D


func _ready() -> void:
	collision_layer = LAYER_INTERACTABLES
	collision_mask = 0
	monitorable = true
	monitoring = false

	var col: CollisionShape3D = CollisionShape3D.new()
	var box_s: BoxShape3D = BoxShape3D.new()
	box_s.size = Vector3(0.45, 0.36, 0.45)
	col.shape = box_s
	col.position = Vector3(0.0, 0.16, 0.0)
	add_child(col)

	_visual_root = Node3D.new()
	_visual_root.position = Vector3(0.0, 0.18, 0.0)
	add_child(_visual_root)

	_build_tool_visual()

	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(0.55, 0.88, 1.0) if tool_id == "radio" else Color(1.0, 0.65, 0.35)
	glow.light_energy = 0.55
	glow.omni_range = 2.0
	glow.shadow_enabled = false
	glow.distance_fade_enabled = true
	glow.distance_fade_begin = 11.0
	glow.distance_fade_length = 4.0
	glow.position = Vector3(0.0, 0.25, 0.0)
	add_child(glow)


func _process(delta: float) -> void:
	if _visual_root != null:
		_visual_root.rotation.y += delta * 1.15


func interact() -> void:
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if inv != null and inv.has_method("add_tool"):
		inv.call("add_tool", tool_id)
	AudioManager.play_pickup()
	if tool_id == "radio":
		GameEvents.status_message_requested.emit("Rádio Portátil adquirido! Estática aumenta perto de ameaças.")
	elif tool_id == "bolt_cutters":
		GameEvents.status_message_requested.emit("Alicate de Corte adquirido! Agora pode cortar portões acorrentados.")
	elif tool_id == "crowbar":
		GameEvents.status_message_requested.emit("Pé de Cabra adquirido! Agora pode forçar portas tapadas com tábuas.")
	else:
		GameEvents.status_message_requested.emit("Ferramenta adquirida: %s" % tool_name)
	queue_free()


func get_interaction_prompt() -> String:
	return "[E] Pegar %s" % tool_name


func _make_mat(color: Color, emissive: bool = false) -> Material:
	if emissive:
		var std: StandardMaterial3D = StandardMaterial3D.new()
		std.albedo_color = color
		std.emission_enabled = true
		std.emission = color
		std.emission_energy_multiplier = 1.2
		return std
	var smat: ShaderMaterial = ShaderMaterial.new()
	smat.shader = PSX_LIT_SHADER
	smat.set_shader_parameter("modulate_color", color)
	smat.set_shader_parameter("snap_resolution", Vector2(320.0, 180.0))
	return smat


func _add_box(size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.rotation_degrees = rot_deg
	m.material_override = mat
	_visual_root.add_child(m)


func _build_tool_visual() -> void:
	var steel_mat: Material = _make_mat(Color(0.55, 0.58, 0.62))
	var red_mat: Material = _make_mat(Color(0.72, 0.16, 0.14))
	if tool_id == "bolt_cutters":
		_add_box(Vector3(0.04, 0.03, 0.34), Vector3(-0.04, 0.0, 0.05), red_mat, Vector3(0.0, 12.0, 0.0))
		_add_box(Vector3(0.04, 0.03, 0.34), Vector3(0.04, 0.0, 0.05), red_mat, Vector3(0.0, -12.0, 0.0))
		_add_box(Vector3(0.11, 0.04, 0.16), Vector3(0.0, 0.0, -0.14), steel_mat)
	elif tool_id == "crowbar":
		_add_box(Vector3(0.04, 0.03, 0.44), Vector3(0.0, 0.0, 0.0), red_mat)
		_add_box(Vector3(0.05, 0.03, 0.12), Vector3(0.03, 0.02, -0.22), steel_mat, Vector3(-28.0, 35.0, 0.0))
	else:
		var dark_mat: Material = _make_mat(Color(0.16, 0.18, 0.20))
		var led_mat: Material = _make_mat(Color(0.28, 0.95, 0.45), true)
		_add_box(Vector3(0.22, 0.14, 0.08), Vector3(0.0, 0.0, 0.0), dark_mat)
		_add_box(Vector3(0.02, 0.22, 0.02), Vector3(0.08, 0.15, 0.0), steel_mat)
		_add_box(Vector3(0.03, 0.03, 0.02), Vector3(-0.06, 0.03, -0.042), led_mat)
