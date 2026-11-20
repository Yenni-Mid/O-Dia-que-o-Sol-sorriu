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
var _clara_trades_done: int = 0
var _rafael_gave_bottle: bool = false
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
	var is_clara: bool = (npc_id == "clara")
	var is_rafael: bool = (npc_id == "rafael")
	var role: String = "SOBREVIVENTE DO POSTO" if is_marcos else (
		"VIZINHA REFUGIADA" if is_helena else (
			"FARMACÊUTICA REFUGIADA" if is_clara else (
				"VIGIA DO PASSADIÇO" if is_rafael else "SOBREVIVENTE"
			)
		)
	)
	var pitch: float = 0.78 if is_marcos else (1.16 if is_helena else (1.22 if is_clara else (0.86 if is_rafael else 1.0)))
	var accent: Color = Color(0.56, 0.78, 0.44) if is_marcos else (
		Color(0.88, 0.56, 0.64) if is_helena else (
			Color(0.54, 0.84, 0.78) if is_clara else (
				Color(0.56, 0.72, 0.90) if is_rafael else Color(0.95, 0.76, 0.34)
			)
		)
	)

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
		SaveManager.mark_school_code_known()
		var pages_h: Array[String] = [post_line if _completed else intro_line]
		_completed = true
		var cb_safe: Callable = func() -> void:
			_open_followup(role, pitch, accent, [
				"Entre pelo portão norte e siga pelo corredor da Escola Municipal Aurora Solar até a sala da Diretoria, na ala nordeste.",
				"A senha do cofre é 1710 — o dia em que o Sol parou no céu. Anotei isso no seu mapa. A Chave da Capela está trancada lá dentro."
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

	if is_clara:
		var bottles_cnt: int = int(inv.call("get_bottles")) if (inv != null and inv.has_method("get_bottles")) else 0
		var pages_c: Array[String] = []
		if _clara_trades_done >= 3:
			pages_c = [
				"Não tenho mais estoque de soro nem combustível sobrando atrás do balcão...",
				"Se os cultistas rondarem a vitrine, passe agachado pela grade de aço ou saia pela galeria dos fundos."
			]
		else:
			pages_c = [
				"Fique longe da vitrine e fale baixo! Abaixo a grade de ferro toda madrugada antes da primeira fresta de sol.",
				"Se me trouxer uma garrafa de vidro limpa (%d/3 trocas disponíveis), consigo destilar álcool para o seu lampião ou preparar uma bandagem." % _clara_trades_done
			]
		var choices_c: Array[Dictionary] = []
		if _clara_trades_done < 3 and bottles_cnt > 0:
			var cb_clara_trade: Callable = func() -> void:
				_open_clara_trade_menu(role, pitch, accent)
			choices_c.append({"label": "Trocar 1 Garrafa por suprimentos", "callback": cb_clara_trade})
		var cb_clara_lore: Callable = func() -> void:
			_open_followup(role, pitch, accent, [
				"Nos primeiros dias após o Sol sorrir, dezenas chegaram à drogaria com as pupilas queimadas em formato de círculo dourado.",
				"Nenhum colírio ou analgésico adiantava. Sob a luz do Sol, a mente vaza confissões compulsivas até queimar — apenas chamas humanas comuns, como lampiões a óleo e tambores de fogo, acalmam o nervo óptico."
			])
		choices_c.append({"label": "O que a luz do Sol faz com as pessoas?", "callback": cb_clara_lore})
		choices_c.append({"label": "Fique abaixada atrás do balcão."})
		_emit_dialogue(role, pitch, accent, pages_c, choices_c)
		return

	if is_rafael:
		var pages_r: Array[String] = []
		if not _rafael_gave_bottle:
			var added_bottle: bool = (inv != null and inv.has_method("add_bottle") and bool(inv.call("add_bottle")))
			_rafael_gave_bottle = true
			if added_bottle:
				AudioManager.play_pickup()
				pages_r = [
					"Subiu pela escada dos fundos? Aqui de cima do passadiço dá para vigiar os dois becos sem eles desconfiarem.",
					"Pegue esta garrafa vazia que sobrou da vigília (+1 Garrafa [G]). Atire no asfalto longe deles se precisar atravessar a avenida."
				]
			else:
				pages_r = [
					"Você está com os bolsos cheios de garrafas já! Aqui de cima do passadiço dá para vigiar os dois becos sem ser visto.",
					"Se deixar o óleo da mesa no canto direito, pode salvar seu lampião na volta da Escola."
				]
		else:
			pages_r = [
				"Ouvi tambores no pátio da Escola e passos rápidos de cultistas na avenida... mantenha o lampião baixo perto das esquinas."
			]
		var cb_patrol: Callable = func() -> void:
			_open_followup(role, pitch, accent, [
				"Os Cultistas do Lampião varrem a rua com um feixe largo. Nunca deixe uma porta aberta atrás de você — se eles notarem porta escancarada na ronda, param para investigar.",
				"Se ficar cercado sem ter para onde correr, pressione [Botão Direito] ou [V] para sobrecarregar o lampião: o clarão queima Sombras Vivas e cega o culto por quase três segundos."
			])
		var cb_shortcuts: Callable = func() -> void:
			_open_followup(role, pitch, accent, [
				"O muro da Escola tem duas grades de serviço trancadas por dentro: uma no lado oeste do portão principal e outra na travessa entre o Posto e o Pátio.",
				"Quando você atravessar pelo túnel do esgoto ou cortar as correntes do portão central, solte esses ferrolhos pelo lado de dentro para criar rotas de fuga em segundos."
			])
		var choices_r: Array[Dictionary] = [
			{"label": "Como funcionam as rondas dos Cultistas?", "callback": cb_patrol},
			{"label": "Existem atalhos rápidos nos becos?", "callback": cb_shortcuts},
			{"label": "Continue vigiando a avenida."},
		]
		_emit_dialogue(role, pitch, accent, pages_r, choices_r)
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


func _open_clara_trade_menu(role: String, pitch: float, accent: Color) -> void:
	var cb_band: Callable = func() -> void:
		var cur_inv: Node = get_tree().get_first_node_in_group("inventory")
		if cur_inv == null or not cur_inv.has_method("get_bottles") or int(cur_inv.call("get_bottles")) <= 0:
			_open_followup(role, pitch, accent, ["Você não está com nenhuma garrafa agora."])
			return
		if cur_inv.has_method("add_bandage") and bool(cur_inv.call("add_bandage")):
			cur_inv.call("consume_bottle")
			_clara_trades_done += 1
			AudioManager.play_pickup()
			_open_followup(role, pitch, accent, [
				"Aqui está — gaze estéril e antisséptico (+1 Bandagem [H]). Use se algum lunático cortar seu braço."
			])
		else:
			_open_followup(role, pitch, accent, [
				"Sua bolsa de bandagens já está cheia! Posso trocar a garrafa por óleo para o lampião se quiser."
			])

	var cb_oil: Callable = func() -> void:
		var cur_inv: Node = get_tree().get_first_node_in_group("inventory")
		var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
		if cur_inv == null or not cur_inv.has_method("consume_bottle") or not bool(cur_inv.call("consume_bottle")):
			_open_followup(role, pitch, accent, ["Você não está com nenhuma garrafa agora."])
			return
		_clara_trades_done += 1
		if player != null and player.lantern_system != null:
			player.lantern_system.add_oil(35.0)
		AudioManager.play_pickup()
		_open_followup(role, pitch, accent, [
			"Despejei álcool medicinal purificado no seu reservatório (+35% Óleo do Lampião). Queima claro sem fazer fumaça."
		])

	var trade_choices: Array[Dictionary] = [
		{"label": "Receber 1 Bandagem (+40 HP)", "callback": cb_band},
		{"label": "Receber +35% de Óleo para o Lampião", "callback": cb_oil},
		{"label": "Agora não."},
	]
	_emit_dialogue(role, pitch, accent, [
		"Preciso de vidro limpo para destilar álcool e soro. O que você prefere levar por esta garrafa?"
	], trade_choices)


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
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if npc_id == "clara":
		var b_cnt: int = int(inv.call("get_bottles")) if (inv != null and inv.has_method("get_bottles")) else 0
		if _clara_trades_done < 3 and b_cnt > 0:
			return "[E] Trocar Garrafa / Falar com %s" % npc_name
		return "[E] Conversar com %s" % npc_name
	if _completed or request_item == "none":
		return "[E] Conversar com %s" % npc_name
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
