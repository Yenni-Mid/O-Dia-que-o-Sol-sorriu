extends StaticBody3D
## Sobrevivente paranoico refugiado em interiores do quarteirão: dialoga e realiza trocas por ferramentas ou chaves.

const LAYER_ENV_AND_INTERACT: int = (1 << 0) | (1 << 3)
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

@export var npc_id: String = "marcos"
@export var npc_name: String = "Seu Marcos"
@export var coat_color: Color = Color(0.24, 0.28, 0.22)
@export_multiline var intro_line: String = "Não aponte essa luz aqui! Se você tiver uma bandagem pro meu braço, te dou meu pé de cabra..."
@export_multiline var reward_line: String = "Obrigado... Pegue o Pé de Cabra! A escola tem a chave da Capela, o código do cofre está nas notas do pátio."
@export_multiline var post_line: String = "Ouvi sinos na praça de madrugada... Não fique na rua depois das sete."
@export_enum("none", "bandage", "bottle") var request_item: String = "bandage"
@export var reward_tool_id: String = ""
@export var reward_tool_name: String = ""
@export var reward_key_id: String = ""
@export var reward_key_name: String = ""

var _completed: bool = false
var _head_node: Node3D


func _ready() -> void:
	collision_layer = LAYER_ENV_AND_INTERACT
	collision_mask = 0

	var col: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.65
	col.shape = cap
	col.position = Vector3(0.0, 0.82, 0.0)
	add_child(col)

	_build_visual()


func _process(_delta: float) -> void:
	if _head_node != null:
		var t: float = Time.get_ticks_msec() * 0.0018
		_head_node.rotation_degrees.y = sin(t) * 18.0


func interact() -> void:
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if _completed:
		AudioManager.play_breath()
		GameEvents.status_message_requested.emit("%s: \"%s\"" % [npc_name, post_line])
		return

	if request_item == "none":
		_grant_rewards(inv)
		_completed = true
		AudioManager.play_breath()
		GameEvents.status_message_requested.emit("%s: \"%s\"" % [npc_name, intro_line])
		return

	var has_req: bool = false
	if inv != null:
		if request_item == "bandage" and inv.has_method("get_bandages") and int(inv.call("get_bandages")) > 0:
			has_req = bool(inv.call("consume_bandage"))
		elif request_item == "bottle" and inv.has_method("get_bottles") and int(inv.call("get_bottles")) > 0:
			has_req = bool(inv.call("consume_bottle"))

	if has_req:
		_grant_rewards(inv)
		_completed = true
		AudioManager.play_pickup()
		GameEvents.status_message_requested.emit("%s: \"%s\"" % [npc_name, reward_line])
	else:
		AudioManager.play_breath()
		GameEvents.status_message_requested.emit("%s: \"%s\"" % [npc_name, intro_line])


func _grant_rewards(inv: Node) -> void:
	if inv == null:
		return
	if not reward_tool_id.is_empty() and inv.has_method("add_tool"):
		inv.call("add_tool", reward_tool_id)
	if not reward_key_id.is_empty() and inv.has_method("add_key"):
		inv.call("add_key", reward_key_id)


func get_interaction_prompt() -> String:
	if _completed or request_item == "none":
		return "[E] Conversar com %s" % npc_name
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if request_item == "bandage":
		if inv != null and inv.has_method("get_bandages") and int(inv.call("get_bandages")) > 0:
			return "[E] Entregar Bandagem para %s" % npc_name
		return "[E] Falar com %s (Pede Bandagem)" % npc_name
	if request_item == "bottle":
		if inv != null and inv.has_method("get_bottles") and int(inv.call("get_bottles")) > 0:
			return "[E] Entregar Garrafa para %s" % npc_name
		return "[E] Falar com %s (Pede Garrafa)" % npc_name
	return "[E] Conversar com %s" % npc_name


func _make_mat(color: Color) -> ShaderMaterial:
	var smat: ShaderMaterial = ShaderMaterial.new()
	smat.shader = PSX_LIT_SHADER
	smat.set_shader_parameter("modulate_color", color)
	smat.set_shader_parameter("snap_resolution", Vector2(320.0, 180.0))
	return smat


func _add_part(parent_n: Node3D, size: Vector3, pos: Vector3, mat: ShaderMaterial) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.material_override = mat
	parent_n.add_child(m)


func _build_visual() -> void:
	var coat_mat: ShaderMaterial = _make_mat(coat_color)
	var pants_mat: ShaderMaterial = _make_mat(Color(0.14, 0.14, 0.16))
	var skin_mat: ShaderMaterial = _make_mat(Color(0.68, 0.56, 0.46))
	var eye_mat: ShaderMaterial = _make_mat(Color(0.08, 0.08, 0.08))

	_add_part(self, Vector3(0.18, 0.65, 0.18), Vector3(-0.11, 0.32, 0.0), pants_mat)
	_add_part(self, Vector3(0.18, 0.65, 0.18), Vector3(0.11, 0.32, 0.0), pants_mat)
	_add_part(self, Vector3(0.50, 0.72, 0.28), Vector3(0.0, 0.96, 0.0), coat_mat)
	_add_part(self, Vector3(0.14, 0.52, 0.14), Vector3(-0.32, 0.92, 0.0), coat_mat)
	_add_part(self, Vector3(0.14, 0.52, 0.14), Vector3(0.32, 0.92, 0.0), coat_mat)

	_head_node = Node3D.new()
	_head_node.position = Vector3(0.0, 1.46, 0.0)
	add_child(_head_node)
	_add_part(_head_node, Vector3(0.26, 0.28, 0.26), Vector3.ZERO, skin_mat)
	_add_part(_head_node, Vector3(0.05, 0.05, 0.03), Vector3(-0.06, 0.03, -0.13), eye_mat)
	_add_part(_head_node, Vector3(0.05, 0.05, 0.03), Vector3(0.06, 0.03, -0.13), eye_mat)

	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.light_color = Color(0.95, 0.78, 0.42)
	lamp.light_energy = 0.55
	lamp.omni_range = 3.2
	lamp.shadow_enabled = false
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 14.0
	lamp.distance_fade_length = 4.0
	lamp.position = Vector3(0.0, 1.25, -0.45)
	add_child(lamp)
