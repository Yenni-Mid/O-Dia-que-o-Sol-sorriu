extends StaticBody3D
## Cofre numérico de 4 dígitos: aciona o KeypadUI ao interagir e entrega chaves/suprimentos quando aberto.

const LAYER_ENV_AND_INTERACT: int = (1 << 0) | (1 << 3)
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

@export var safe_id: String = "safe_school"
@export var safe_title: String = "Cofre da Diretoria (4 dígitos)"
@export var expected_code: String = "1710"
@export var reward_key_id: String = "chapel_key"
@export var reward_key_name: String = "Chave da Capela"
@export var reward_tool_id: String = ""
@export var reward_tool_name: String = ""
@export var reward_oil: float = 25.0
@export var reward_bandages: int = 1

var is_unlocked: bool = false
var _door_pivot: Node3D


func _ready() -> void:
	collision_layer = LAYER_ENV_AND_INTERACT
	collision_mask = 0

	var col: CollisionShape3D = CollisionShape3D.new()
	var box_s: BoxShape3D = BoxShape3D.new()
	box_s.size = Vector3(0.85, 0.95, 0.75)
	col.shape = box_s
	col.position = Vector3(0.0, 0.475, 0.0)
	add_child(col)

	_build_visual()

	if SaveManager.is_safe_unlocked(safe_id):
		is_unlocked = true
		if _door_pivot != null:
			_door_pivot.rotation_degrees.y = -95.0


func interact() -> void:
	if is_unlocked:
		GameEvents.status_message_requested.emit("Cofre já aberto e vasculhado.")
		return
	AudioManager.play_ui_click()
	GameEvents.keypad_requested.emit(self, safe_title, expected_code)


func on_code_accepted() -> void:
	if is_unlocked:
		return
	is_unlocked = true
	SaveManager.mark_safe_unlocked(safe_id)
	AudioManager.play_unlock()

	if _door_pivot != null:
		var tw: Tween = create_tween()
		tw.tween_property(_door_pivot, "rotation_degrees:y", -95.0, 0.55)

	var rewards: Array[String] = []
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if inv != null:
		if not reward_key_id.is_empty() and inv.has_method("add_key"):
			inv.call("add_key", reward_key_id)
			rewards.append(reward_key_name if not reward_key_name.is_empty() else reward_key_id)
		if not reward_tool_id.is_empty() and inv.has_method("add_tool"):
			inv.call("add_tool", reward_tool_id)
			rewards.append(reward_tool_name if not reward_tool_name.is_empty() else reward_tool_id)
		for _i: int in range(reward_bandages):
			if inv.has_method("add_bandage") and bool(inv.call("add_bandage")):
				rewards.append("1x Bandagem")

	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if player != null and player.lantern_system != null and reward_oil > 0.0:
		player.lantern_system.add_oil(reward_oil)
		rewards.append("+%.0f%% Óleo" % reward_oil)

	var loot_txt: String = ", ".join(rewards) if not rewards.is_empty() else "compartimento vazio"
	GameEvents.status_message_requested.emit("Cofre Destrancado! Obtido: %s." % loot_txt)


func get_interaction_prompt() -> String:
	if is_unlocked:
		return "[Cofre Aberto]"
	return "[E] Abrir %s" % safe_title


func _make_mat(color: Color, emissive: bool = false) -> Material:
	if emissive:
		var std: StandardMaterial3D = StandardMaterial3D.new()
		std.albedo_color = color
		std.emission_enabled = true
		std.emission = color
		std.emission_energy_multiplier = 0.9
		return std
	var smat: ShaderMaterial = ShaderMaterial.new()
	smat.shader = PSX_LIT_SHADER
	smat.set_shader_parameter("modulate_color", color)
	smat.set_shader_parameter("snap_resolution", Vector2(320.0, 180.0))
	return smat


func _add_box(parent_n: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.material_override = mat
	parent_n.add_child(m)


func _build_visual() -> void:
	var steel_dark: Material = _make_mat(Color(0.16, 0.18, 0.21))
	var steel_door: Material = _make_mat(Color(0.24, 0.27, 0.30))
	var brass: Material = _make_mat(Color(0.78, 0.62, 0.22))
	var led_mat: Material = _make_mat(Color(0.88, 0.25, 0.20), true)

	# Corpo oco traseiro/laterais/topo/base
	_add_box(self, Vector3(0.84, 0.10, 0.72), Vector3(0.0, 0.05, 0.0), steel_dark)
	_add_box(self, Vector3(0.84, 0.10, 0.72), Vector3(0.0, 0.90, 0.0), steel_dark)
	_add_box(self, Vector3(0.10, 0.76, 0.72), Vector3(-0.37, 0.475, 0.0), steel_dark)
	_add_box(self, Vector3(0.10, 0.76, 0.72), Vector3(0.37, 0.475, 0.0), steel_dark)
	_add_box(self, Vector3(0.66, 0.76, 0.12), Vector3(0.0, 0.475, -0.30), steel_dark)

	_door_pivot = Node3D.new()
	_door_pivot.position = Vector3(-0.34, 0.475, 0.34)
	add_child(_door_pivot)

	_add_box(_door_pivot, Vector3(0.68, 0.76, 0.08), Vector3(0.34, 0.0, 0.0), steel_door)
	_add_box(_door_pivot, Vector3(0.16, 0.16, 0.06), Vector3(0.34, 0.04, 0.06), brass)
	_add_box(_door_pivot, Vector3(0.22, 0.06, 0.06), Vector3(0.52, -0.10, 0.06), brass)
	_add_box(_door_pivot, Vector3(0.06, 0.04, 0.02), Vector3(0.34, 0.20, 0.05), led_mat)
