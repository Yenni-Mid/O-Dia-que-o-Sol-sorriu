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
var _talk_cooldown: float = 0.0


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
	GameEvents.dialogue_closed.connect(_on_dialogue_closed)


func _on_dialogue_closed() -> void:
	_talk_cooldown = 0.25


func _process(delta: float) -> void:
	if _talk_cooldown > 0.0:
		_talk_cooldown = maxf(0.0, _talk_cooldown - delta)
	if _head_node != null:
		var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
		if player != null and global_position.distance_to(player.global_position) <= 3.8:
			var to_p: Vector3 = player.global_position - global_position
			var local_to_p: Vector3 = global_transform.basis.inverse() * to_p
			var yaw: float = clampf(atan2(-local_to_p.x, -local_to_p.z), -0.65, 0.65)
			_head_node.rotation.y = lerp_angle(_head_node.rotation.y, yaw, clampf(6.0 * delta, 0.0, 1.0))
		else:
			var t: float = Time.get_ticks_msec() * 0.0018
			_head_node.rotation.y = lerp_angle(_head_node.rotation.y, deg_to_rad(sin(t) * 18.0), clampf(3.0 * delta, 0.0, 1.0))


func interact() -> void:
	if _talk_cooldown > 0.0:
		return
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	_open_npc_dialogue(inv)


func _open_npc_dialogue(inv: Node) -> void:
	AudioManager.play_breath()
	var is_marcos: bool = (npc_id == "marcos")
	var is_helena: bool = (npc_id == "helena")
	var role: String = "SOBREVIVENTE DO POSTO" if is_marcos else ("VIZINHA REFUGIADA" if is_helena else "SOBREVIVENTE")
	var pitch: float = 0.78 if is_marcos else (1.16 if is_helena else 1.0)
	var accent: Color = Color(0.56, 0.78, 0.44) if is_marcos else (Color(0.88, 0.56, 0.64) if is_helena else Color(0.95, 0.76, 0.34))

	if is_marcos:
		var pages: Array[String] = []
		if _completed:
			pages = [post_line]
		else:
			pages = [
				intro_line,
				"Mantenha o lampião baixo perto das janelas... os cultistas de tocha rondam a avenida do posto procurando qualquer movimento."
			]
		var choices: Array[Dictionary] = []
		if not _completed and _has_required_item(inv):
			var item_label: String = "Entregar Bandagem (Trocar pelo Pé de Cabra)" if request_item == "bandage" else "Entregar Garrafa"
			var cb_trade: Callable = func() -> void:
				_perform_marcos_trade(role, pitch, accent)
			choices.append({"label": item_label, "callback": cb_trade})

		var cb_sewer: Callable = func() -> void:
			_open_followup(role, pitch, accent, [
				"Há uma saída subterrânea trancada por trás do posto que liga direto ao pátio da Escola Aurora Solar.",
				"As Sombras Vivas tomaram o tronco central, mas se você sacrificar 15% de óleo no gerador da cisterna, as luzes industriais limpam o caminho e abrem a grade."
			])
		choices.append({"label": "O que há na rede de esgoto aqui atrás?", "callback": cb_sewer})
		choices.append({"label": "Vou continuar procurando. Fique escondido."})
		_emit_dialogue(role, pitch, accent, pages, choices)
		return

	if is_helena:
		var pages_h: Array[String] = [post_line if _completed else intro_line]
		_completed = true
		var cb_safe: Callable = func() -> void:
			_open_followup(role, pitch, accent, [
				"Entre pelo portão norte e siga pelo corredor da Escola Municipal Aurora Solar até a sala da Diretoria, na ala nordeste.",
				"A senha do cofre é 1710 — o dia em que o Sol parou no céu. A Chave da Capela está trancada lá dentro."
			])
		var cb_leo: Callable = func() -> void:
			_open_followup(role, pitch, accent, [
				"Na noite em que pregaram tábuas na minha porta, ouvi passos apressados e o badalar de um sino vindo da pracinha.",
				"O Pregador de máscara dourada disse que levariam o menino até a Torre Central, além dos muros da Escola."
			])
		var choices_h: Array[Dictionary] = [
			{"label": "Onde exatamente fica o cofre da Escola?", "callback": cb_safe},
			{"label": "Você viu para onde levaram o meu filho Leo?", "callback": cb_leo},
			{"label": "Tranque a porta atrás de mim. Já volto."},
		]
		_emit_dialogue(role, pitch, accent, pages_h, choices_h)
		return

	# Fallback genérico reutilizável para novos NPCs
	var generic_pages: Array[String] = [post_line if _completed else intro_line]
	var generic_choices: Array[Dictionary] = []
	if not _completed and request_item != "none" and _has_required_item(inv):
		var cb_generic: Callable = func() -> void:
			_perform_generic_trade(role, pitch, accent)
		generic_choices.append({"label": "Entregar item solicitado", "callback": cb_generic})
	generic_choices.append({"label": "Entendido."})
	_emit_dialogue(role, pitch, accent, generic_pages, generic_choices)


func _perform_generic_trade(role: String, pitch: float, accent: Color) -> void:
	var cur_inv: Node = get_tree().get_first_node_in_group("inventory")
	if _consume_required_item(cur_inv):
		_grant_rewards(cur_inv)
		_completed = true
		AudioManager.play_pickup()
		_open_followup(role, pitch, accent, [reward_line])


func _perform_marcos_trade(role: String, pitch: float, accent: Color) -> void:
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if not _consume_required_item(inv):
		return
	_grant_rewards(inv)
	_completed = true
	AudioManager.play_pickup()
	_open_followup(role, pitch, accent, [
		reward_line,
		"Use o Pé de Cabra nas tábuas da Casa Vizinha e dentro da Escola. Se precisar de óleo, há um depósito atrás da grade elétrica da cisterna no esgoto."
	])


func _open_followup(role: String, pitch: float, accent: Color, pages: Array[String]) -> void:
	_emit_dialogue(role, pitch, accent, pages, [])


func _emit_dialogue(role: String, pitch: float, accent: Color, pages: Array[String], choices: Array[Dictionary]) -> void:
	GameEvents.dialogue_requested.emit({
		"speaker_name": npc_name,
		"speaker_role": role,
		"portrait_id": npc_id,
		"voice_pitch": pitch,
		"accent_color": accent,
		"pages": pages,
		"choices": choices,
	})


func _has_required_item(inv: Node) -> bool:
	if inv == null or request_item == "none":
		return false
	if request_item == "bandage" and inv.has_method("get_bandages"):
		return int(inv.call("get_bandages")) > 0
	if request_item == "bottle" and inv.has_method("get_bottles"):
		return int(inv.call("get_bottles")) > 0
	return false


func _consume_required_item(inv: Node) -> bool:
	if inv == null:
		return false
	if request_item == "bandage" and inv.has_method("consume_bandage"):
		return bool(inv.call("consume_bandage"))
	if request_item == "bottle" and inv.has_method("consume_bottle"):
		return bool(inv.call("consume_bottle"))
	return false


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
