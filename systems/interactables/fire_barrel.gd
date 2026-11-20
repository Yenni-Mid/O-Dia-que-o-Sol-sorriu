extends StaticBody3D
## Tambor-Fogueira de refúgio: acende usando óleo do lampião, estabiliza sanidade, salva checkpoint e permite descansar até amanhecer/anoitecer.

const LAYER_ENV_AND_INTERACT: int = (1 << 0) | (1 << 3)
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

@export var barrel_id: String = "barrel_plaza"
@export var barrel_name: String = "Tambor-Fogueira"
@export var starts_lit: bool = false
@export var light_oil_cost: float = 15.0

var is_lit: bool = false
var _fire_root: Node3D
var _fire_light: OmniLight3D
var _fire_audio: AudioStreamPlayer3D
var _rest_confirm_timer: float = 0.0


func _ready() -> void:
	add_to_group("fire_barrel")
	collision_layer = LAYER_ENV_AND_INTERACT
	collision_mask = 0

	var col: CollisionShape3D = CollisionShape3D.new()
	var cyl_s: CylinderShape3D = CylinderShape3D.new()
	cyl_s.radius = 0.45
	cyl_s.height = 1.1
	col.shape = cyl_s
	col.position = Vector3(0.0, 0.55, 0.0)
	add_child(col)

	_build_visual()
	is_lit = starts_lit
	_apply_lit_visual()


func _process(delta: float) -> void:
	if _rest_confirm_timer > 0.0:
		_rest_confirm_timer -= delta
	if not is_lit:
		return

	var t: float = Time.get_ticks_msec() * 0.012
	var flicker: float = 0.88 + sin(t) * 0.10 + cos(t * 1.7) * 0.06
	if _fire_root != null:
		_fire_root.scale = Vector3(1.0, flicker, 1.0)
	if _fire_light != null:
		_fire_light.light_energy = 1.9 * flicker

	# Estabiliza suavemente a sanidade do jogador perto do fogo
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if player != null and player.global_position.distance_to(global_position) <= 4.5:
		if player.sanity_component != null and player.sanity_component.has_method("modify_sanity"):
			player.sanity_component.modify_sanity(5.5 * delta)


func interact() -> void:
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if not is_lit:
		if player == null or player.lantern_system == null:
			return
		var oil_now: float = float(player.lantern_system.current_oil)
		if oil_now < light_oil_cost:
			AudioManager.play_locked()
			GameEvents.status_message_requested.emit("Óleo insuficiente para acender o tambor (requer %.0f%%)." % light_oil_cost)
			return
		player.lantern_system.add_oil(-light_oil_cost)
		is_lit = true
		_apply_lit_visual()
		AudioManager.play_lantern_ignite()
		SaveManager.set_checkpoint(global_position + Vector3(0.0, 0.15, 1.5))
		if player.sanity_component != null:
			player.sanity_component.modify_sanity(25.0)
		GameEvents.status_message_requested.emit("%s aceso! Sanidade acalmou e ponto de retorno salvo." % barrel_name)
		_rest_confirm_timer = 5.0
		return

	var dn: Node = get_tree().get_first_node_in_group("day_night")
	var expedition_mode: bool = (dn != null and dn.has_method("is_night_expedition_mode") and bool(dn.call("is_night_expedition_mode")))

	# Já aceso: cura sanidade e salva checkpoint; em FullDayNight permite descansar com 2º [E] em <5s.
	if not expedition_mode and _rest_confirm_timer > 0.0:
		_rest_confirm_timer = 0.0
		_skip_to_next_phase()
		return

	if player != null and player.sanity_component != null:
		player.sanity_component.modify_sanity(20.0)
	SaveManager.set_checkpoint(global_position + Vector3(0.0, 0.15, 1.5))
	AudioManager.play_lantern_ignite()

	if expedition_mode:
		GameEvents.status_message_requested.emit("Refúgio salvo! Volte para dentro da Casa quando começar a clarear (05:00).")
		return

	_rest_confirm_timer = 5.0
	var target_label: String = "Amanhecer (06:20)" if (dn != null and dn.has_method("is_nighttime") and bool(dn.call("is_nighttime"))) else "Anoitecer (19:05)"
	GameEvents.status_message_requested.emit("Refúgio salvo! Pressione [E] de novo em 5s para descansar até %s." % target_label)


func get_interaction_prompt() -> String:
	if not is_lit:
		return "[E] Acender %s (-%.0f%% Óleo / Salvar)" % [barrel_name, light_oil_cost]
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	var expedition_mode: bool = (dn != null and dn.has_method("is_night_expedition_mode") and bool(dn.call("is_night_expedition_mode")))
	if not expedition_mode and _rest_confirm_timer > 0.0:
		if dn != null and dn.has_method("is_nighttime") and bool(dn.call("is_nighttime")):
			return "[E] Descansar até o Amanhecer (06:20)"
		return "[E] Descansar até a Noite (19:05)"
	return "[E] Aquecer-se / Salvar Ponto de Retorno"


func _skip_to_next_phase() -> void:
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn == null or not dn.has_method("skip_to_hour"):
		return
	var is_night_now: bool = bool(dn.call("is_nighttime")) if dn.has_method("is_nighttime") else false
	if is_night_now:
		dn.call("skip_to_hour", 6.35)
		GameEvents.status_message_requested.emit("Você descansou junto ao fogo até o amanhecer (06:20).")
	else:
		dn.call("skip_to_hour", 19.08)
		GameEvents.status_message_requested.emit("Você aguardou junto às brasas até a noite cair (19:05).")


func _apply_lit_visual() -> void:
	if _fire_root != null:
		_fire_root.visible = is_lit
	if _fire_light != null:
		_fire_light.visible = is_lit
	if _fire_audio != null and _fire_audio.stream != null:
		if is_lit:
			if not _fire_audio.playing:
				_fire_audio.play()
		elif _fire_audio.playing:
			_fire_audio.stop()


func _build_visual() -> void:
	var drum: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.42
	cyl.height = 1.0
	cyl.radial_segments = 10
	cyl.rings = 1
	drum.mesh = cyl
	drum.position = Vector3(0.0, 0.5, 0.0)
	var drum_mat: ShaderMaterial = ShaderMaterial.new()
	drum_mat.shader = PSX_LIT_SHADER
	drum_mat.set_shader_parameter("modulate_color", Color(0.46, 0.25, 0.16))
	drum_mat.set_shader_parameter("snap_resolution", Vector2(320.0, 180.0))
	drum.material_override = drum_mat
	add_child(drum)

	_fire_root = Node3D.new()
	_fire_root.name = "FireRoot"
	_fire_root.position = Vector3(0.0, 1.02, 0.0)
	add_child(_fire_root)

	var flame_mat: StandardMaterial3D = StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.58, 0.16)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.44, 0.08)
	flame_mat.emission_energy_multiplier = 2.0

	for offset: Vector3 in [Vector3(0.0, 0.16, 0.0), Vector3(-0.1, 0.1, 0.06), Vector3(0.1, 0.12, -0.05)]:
		var fm: MeshInstance3D = MeshInstance3D.new()
		var fb: BoxMesh = BoxMesh.new()
		fb.size = Vector3(0.22, 0.34, 0.22)
		fm.mesh = fb
		fm.position = offset
		fm.rotation_degrees = Vector3(0.0, 45.0, 0.0)
		fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fm.material_override = flame_mat
		_fire_root.add_child(fm)

	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.56, 0.20)
	_fire_light.light_energy = 1.9
	_fire_light.omni_range = 10.5
	_fire_light.shadow_enabled = false
	_fire_light.distance_fade_enabled = true
	_fire_light.distance_fade_begin = 24.0
	_fire_light.distance_fade_length = 8.0
	_fire_light.position = Vector3(0.0, 1.45, 0.0)
	add_child(_fire_light)

	_fire_audio = AudioStreamPlayer3D.new()
	_fire_audio.name = "FireAudio3D"
	_fire_audio.stream = AudioManager.get_fire_loop_stream()
	_fire_audio.max_distance = 13.0
	_fire_audio.volume_db = -7.0
	_fire_audio.position = Vector3(0.0, 1.1, 0.0)
	add_child(_fire_audio)
