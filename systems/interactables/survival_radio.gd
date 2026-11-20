class_name SurvivalRadio
extends StaticBody3D
## Rádio de Emergência na sala da Casa Principal (Layer 4).
## Sintoniza boletins distorcidos dinâmicos por noite (Noite 1, Noite 2, Noite 3+) via DialogueUI.

const LAYER_ENV_AND_INTERACT: int = (1 << 0) | (1 << 3)
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

var _last_heard_night: int = 0
var _pulse_time: float = 0.0
var _talk_cooldown: float = 0.0

var _led_mat: StandardMaterial3D
var _led_light: OmniLight3D
var _static_audio: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("survival_radio")
	collision_layer = LAYER_ENV_AND_INTERACT
	collision_mask = 0
	_build_visual()
	_setup_audio()
	GameEvents.night_transition_requested.connect(_on_night_transition_requested)
	GameEvents.dialogue_closed.connect(_on_dialogue_closed)


func _exit_tree() -> void:
	if _static_audio != null:
		_static_audio.stop()
		_static_audio.stream = null
	_led_mat = null
	_led_light = null
	_static_audio = null


func _on_night_transition_requested(_night_number: int) -> void:
	_refresh_signal_state()


func _on_dialogue_closed() -> void:
	_talk_cooldown = 0.25


func _process(delta: float) -> void:
	if _talk_cooldown > 0.0:
		_talk_cooldown = maxf(0.0, _talk_cooldown - delta)
	_pulse_time += delta
	var cur_night: int = _get_current_night()
	var has_unread: bool = _last_heard_night < cur_night
	if _led_mat != null:
		var pulse: float = 0.55 + 0.45 * absf(sin(_pulse_time * 3.4)) if has_unread else 0.12
		_led_mat.emission_energy_multiplier = pulse * 1.8
		_led_mat.albedo_color = Color(0.45, 0.96, 0.42) if has_unread else Color(0.24, 0.34, 0.24)
	if _led_light != null:
		_led_light.visible = has_unread
		_led_light.light_energy = 0.28 + 0.14 * absf(sin(_pulse_time * 3.4))
	if _static_audio != null and not Engine.is_editor_hint():
		if has_unread and not _static_audio.playing and _static_audio.stream != null:
			_static_audio.play()
		elif not has_unread and _static_audio.playing:
			_static_audio.stop()


func _refresh_signal_state() -> void:
	if _static_audio != null and not Engine.is_editor_hint():
		if _last_heard_night < _get_current_night() and _static_audio.stream != null and not _static_audio.playing:
			_static_audio.play()


func interact() -> void:
	if _talk_cooldown > 0.0:
		return
	var cur_night: int = _get_current_night()
	_last_heard_night = cur_night
	AudioManager.play_ui_click()
	_open_broadcast_for_night(cur_night, true)


func _open_broadcast_for_night(night_num: int, allow_archive_choice: bool) -> void:
	var band_title: String = _get_band_title(night_num)
	var pages: Array[String] = _get_pages_for_night(night_num)
	var choices: Array[Dictionary] = []

	if allow_archive_choice and night_num >= 2:
		var prev_night: int = night_num - 1
		var cb_prev: Callable = func() -> void:
			_open_broadcast_for_night(prev_night, false)
		choices.append({
			"label": "Reouvir transmissão gravada da Noite %d" % prev_night,
			"callback": cb_prev,
		})
	choices.append({"label": "Desligar o dial do rádio."})

	GameEvents.dialogue_requested.emit({
		"speaker_name": "RÁDIO DE EMERGÊNCIA",
		"speaker_role": band_title,
		"portrait_id": "radio",
		"voice_pitch": 0.92,
		"accent_color": Color(0.54, 0.86, 0.56),
		"pages": pages,
		"choices": choices,
	})


func _get_band_title(night_num: int) -> String:
	if night_num <= 1:
		return "FAIXA 88.4 MHz — NOITE 1"
	if night_num == 2:
		return "SINAL PIRATA 64.0 — NOITE 2"
	return "PORTADORA AUTOMÁTICA — NOITE %d" % night_num


func _get_pages_for_night(night_num: int) -> Array[String]:
	if night_num <= 1:
		return [
			"[Estática — Defesa Civil]: \"Repito: todas as linhas de energia do setor norte entraram em colapso às 14h12. Não tentem cruzar as avenidas abertas após o nascer do Sol.\"",
			"[Sinal intermitente]: \"Os portadores de lampião tomaram a praça e a estrada do posto durante a noite. Qualquer fogo humano aceso atrai patrulhas — mas na escuridão total a mente cede mais rápido.\"",
			"[Voz abafada na faixa]: \"Sobreviventes se esconderam na loja do Posto Oeste e atrás da grade da Farmácia. Voltem para dentro de casa antes das 05h00 da manhã.\""
		]
	if night_num == 2:
		return [
			"[Sinal Pirata — Vigia Desconhecido]: \"Se você ainda está vivo na casa central... eles andaram rondando sua varanda de dia. Deixaram tinta vermelha nos degraus.\"",
			"[Ruído metálico]: \"Descobrimos no registro escolar que o Diretor Arnaldo trancou a Chave da Capela no cofre da Diretoria antes de apagar as luzes. A combinação é o dia do eclipse: 1710.\"",
			"[Transmissão falhando]: \"Eles notam portas deixadas abertas na rota. Fechem as portas atrás de si e destravem os atalhos pelo pátio da Escola se precisarem correr.\""
		]
	return [
		"[Portadora da Torre Central]: \"...três chaves... o sino da meia-noite já responde ao Espelho da Alma Partida ao norte da Escola...\"",
		"[Interferência aguda]: \"Se a escuridão tomar o túnel sob o mercado, abasteçam o gerador de óleo na cisterna subterrânea para acender a galeria e abrir a grade de suprimentos.\"",
		"[Último pulso — Estática pura]: \"Sobrevivam até o clarear. Não olhem para cima quando o horizonte ficar amarelo.\""
	]


func get_interaction_prompt() -> String:
	var cur_night: int = _get_current_night()
	if _last_heard_night < cur_night:
		return "[E] Sintonizar Rádio — Novo Boletim (Noite %d)" % cur_night
	return "[E] Ouvir Rádio de Emergência (Noite %d)" % cur_night


func _get_current_night() -> int:
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn != null and dn.has_method("get_night_number"):
		return maxi(1, int(dn.call("get_night_number")))
	return 1


func _setup_audio() -> void:
	_static_audio = AudioStreamPlayer3D.new()
	_static_audio.name = "RadioHum3D"
	_static_audio.stream = AudioManager.get_radio_static_stream()
	_static_audio.max_distance = 6.5
	_static_audio.volume_db = -21.0
	add_child(_static_audio)


func _make_psx_mat(color: Color) -> Material:
	if PSX_LIT_SHADER != null:
		var smat: ShaderMaterial = ShaderMaterial.new()
		smat.shader = PSX_LIT_SHADER
		smat.set_shader_parameter("modulate_color", color)
		smat.set_shader_parameter("snap_resolution", Vector2(320.0, 180.0))
		return smat
	var std: StandardMaterial3D = StandardMaterial3D.new()
	std.albedo_color = color
	return std


func _add_part(size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.rotation_degrees = rot_deg
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


func _build_visual() -> void:
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.46, 0.30, 0.24)
	col.shape = box
	col.position = Vector3(0.0, 0.14, 0.0)
	add_child(col)

	var wood_mat: Material = _make_psx_mat(Color(0.28, 0.18, 0.11))
	var metal_mat: Material = _make_psx_mat(Color(0.16, 0.17, 0.19))
	var knob_mat: Material = _make_psx_mat(Color(0.68, 0.64, 0.56))

	_add_part(Vector3(0.42, 0.24, 0.18), Vector3(0.0, 0.12, 0.0), wood_mat)
	_add_part(Vector3(0.18, 0.16, 0.02), Vector3(-0.08, 0.12, 0.092), metal_mat)
	_add_part(Vector3(0.04, 0.04, 0.02), Vector3(0.14, 0.07, 0.096), knob_mat)
	_add_part(Vector3(0.04, 0.04, 0.02), Vector3(0.06, 0.07, 0.096), knob_mat)
	_add_part(Vector3(0.018, 0.32, 0.018), Vector3(0.16, 0.36, -0.05), knob_mat, Vector3(0.0, 0.0, -14.0))

	_led_mat = StandardMaterial3D.new()
	_led_mat.albedo_color = Color(0.45, 0.96, 0.42)
	_led_mat.emission_enabled = true
	_led_mat.emission = Color(0.32, 0.90, 0.36)
	_led_mat.emission_energy_multiplier = 1.4
	_add_part(Vector3(0.14, 0.06, 0.02), Vector3(0.10, 0.16, 0.094), _led_mat)

	_led_light = OmniLight3D.new()
	_led_light.light_color = Color(0.42, 0.92, 0.48)
	_led_light.light_energy = 0.32
	_led_light.omni_range = 1.6
	_led_light.shadow_enabled = false
	_led_light.position = Vector3(0.10, 0.22, 0.18)
	add_child(_led_light)
