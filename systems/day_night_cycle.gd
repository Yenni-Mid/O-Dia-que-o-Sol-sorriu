extends Node
## Controla o ciclo de tempo do quarteirão.
## Modo NightExpedition (padrão): explorações noturnas (19:15..06:00) com aviso ao clarear (05:00) e retorno obrigatório para casa.
## Modo FullDayNight preservado integralmente para reutilização futura do ciclo completo diurno/noturno.

@export_enum("NightExpedition", "FullDayNight") var cycle_mode: int = 0
@export var night_expedition_duration_sec: float = 360.0
@export var night_start_hour: float = 19.25

@export var full_day_duration_sec: float = 260.0
@export var saved_day_start_hour: float = 14.5
@export var start_hour: float = 19.25

var current_hour: float = 19.25
var is_night: bool = true
var night_number: int = 1

var _sun_light: DirectionalLight3D
var _world_env: WorldEnvironment
var _smiling_sun: Node3D
var _last_emitted_bucket: int = -1
var _dawn_warn_500_sent: bool = false
var _dawn_warn_530_sent: bool = false
var _home_shelter_dwell: float = 0.0
var _transitioning_night: bool = false


func _ready() -> void:
	add_to_group("day_night")
	start_hour = night_start_hour if cycle_mode == 0 else saved_day_start_hour
	current_hour = fposmod(start_hour, 24.0)
	is_night = _compute_is_night(current_hour)
	call_deferred("_sync_initial_state")


func _sync_initial_state() -> void:
	_resolve_scene_nodes()
	_apply_lighting()
	_emit_time(true)
	if is_night:
		GameEvents.night_started.emit()
	else:
		GameEvents.day_started.emit()


func _process(delta: float) -> void:
	var hours_per_sec: float = 0.0
	if cycle_mode == 0 and is_night:
		hours_per_sec = 10.75 / maxf(60.0, night_expedition_duration_sec)
	else:
		if full_day_duration_sec <= 0.0:
			return
		hours_per_sec = 24.0 / full_day_duration_sec

	current_hour = fposmod(current_hour + delta * hours_per_sec, 24.0)

	var next_night: bool = _compute_is_night(current_hour)
	if next_night != is_night:
		is_night = next_night
		AudioManager.play_phase_chime()
		if is_night:
			GameEvents.night_started.emit()
			GameEvents.status_message_requested.emit("A NOITE CAIU — Os Cultistas caçam a luz do lampião!")
		else:
			GameEvents.day_started.emit()
			if cycle_mode == 0:
				GameEvents.status_message_requested.emit("O SOL SORRIDENTE NASCEU — Entre na Casa principal imediatamente!")
			else:
				GameEvents.status_message_requested.emit("O SOL SORRIDENTE NASCEU — Os Cultistas recuaram. Evite a luz direta!")

	if cycle_mode == 0:
		_process_night_expedition(delta)

	_apply_lighting()
	_emit_time(false)


func _process_night_expedition(delta: float) -> void:
	if current_hour >= 5.0 and current_hour < 6.0:
		if not _dawn_warn_500_sent:
			_dawn_warn_500_sent = true
			AudioManager.play_dawn_warning()
			GameEvents.dawn_approaching.emit(night_number)
			GameEvents.status_message_requested.emit("ESTÁ CLAREANDO (05:00) — Volte para dentro da Casa antes das 06:00!")
		if current_hour >= 5.5 and not _dawn_warn_530_sent:
			_dawn_warn_530_sent = true
			AudioManager.play_dawn_warning()
			GameEvents.status_message_requested.emit("ALVORADA IMINENTE (05:30) — Corra para casa agora!")

	if not is_night:
		if is_player_inside_home():
			_home_shelter_dwell += delta
			if _home_shelter_dwell >= 1.6 and not _transitioning_night:
				shelter_at_home_until_next_night()
		else:
			_home_shelter_dwell = 0.0


func is_night_expedition_mode() -> bool:
	return cycle_mode == 0


func set_cycle_mode(mode_idx: int) -> void:
	cycle_mode = clampi(mode_idx, 0, 1)
	if cycle_mode == 1:
		skip_to_hour(saved_day_start_hour)
	else:
		skip_to_hour(night_start_hour)


func get_night_number() -> int:
	return night_number


func is_dawn_approaching() -> bool:
	return current_hour >= 5.0 and current_hour < 6.0


func is_player_inside_home() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false
	var pos: Vector3 = player.global_position
	return pos.x >= -7.9 and pos.x <= 7.9 and pos.z >= -6.9 and pos.z <= 6.9 and pos.y >= -0.4


func shelter_at_home_until_next_night() -> void:
	if _transitioning_night:
		return
	_transitioning_night = true
	night_number += 1
	_dawn_warn_500_sent = false
	_dawn_warn_530_sent = false
	_home_shelter_dwell = 0.0

	GameEvents.night_transition_requested.emit(night_number)
	skip_to_hour(night_start_hour)

	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if player != null and player.sanity_component != null:
		player.sanity_component.modify_sanity(45.0)

	SaveManager.set_checkpoint(Vector3(0.0, 0.15, 4.2))
	AudioManager.play_phase_chime()
	GameEvents.status_message_requested.emit("NOITE %d (19:15) — O Sol Sorridente se pôs. Seguro para sair da Casa." % night_number)
	_transitioning_night = false


func is_nighttime() -> bool:
	return is_night


func get_hour() -> float:
	return current_hour


func skip_to_hour(target_hour: float) -> void:
	current_hour = fposmod(target_hour, 24.0)
	var next_night: bool = _compute_is_night(current_hour)
	if next_night != is_night:
		is_night = next_night
		if is_night:
			GameEvents.night_started.emit()
		else:
			GameEvents.day_started.emit()
	_apply_lighting()
	_emit_time(true)


func get_formatted_time() -> String:
	var total_minutes: int = int(floorf(current_hour * 60.0))
	var hh: int = (total_minutes / 60) % 24
	var mm: int = total_minutes % 60
	return "%02d:%02d" % [hh, mm]


func _compute_is_night(hour_val: float) -> bool:
	return hour_val >= 19.0 or hour_val < 6.0


func _get_phase_name() -> String:
	if is_night:
		if current_hour >= 5.0 and current_hour < 6.0:
			return "CLAREANDO [VOLTE PARA CASA!]"
		return "NOITE [CULTISTAS À SOLTA]"
	if current_hour >= 17.2:
		return "CREPÚSCULO [SOL BAIXO]"
	if current_hour <= 7.5:
		return "ALVORADA [SOL SORRIDENTE]"
	return "DIA [SOL SORRIDENTE]"


func _emit_time(force: bool) -> void:
	var bucket: int = int(floorf(current_hour * 12.0))
	if force or bucket != _last_emitted_bucket:
		_last_emitted_bucket = bucket
		GameEvents.time_of_day_changed.emit(current_hour, is_night, _get_phase_name())


func _resolve_scene_nodes() -> void:
	if _sun_light == null:
		_sun_light = get_tree().get_first_node_in_group("sun_light") as DirectionalLight3D
	if _smiling_sun == null:
		_smiling_sun = get_tree().get_first_node_in_group("smiling_sun") as Node3D
	if _world_env == null:
		var parent_node: Node = get_parent()
		if parent_node != null:
			_world_env = parent_node.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if _world_env == null and get_tree().current_scene != null:
			var envs: Array[Node] = get_tree().current_scene.find_children("*", "WorldEnvironment", true, false)
			if not envs.is_empty():
				_world_env = envs[0] as WorldEnvironment


func _apply_lighting() -> void:
	_resolve_scene_nodes()

	var dusk_weight: float = 0.0
	var day_t: float = 0.0
	var pre_dawn: float = 0.0
	if not is_night:
		day_t = clampf((current_hour - 6.0) / 13.0, 0.0, 1.0)
		dusk_weight = 1.0 - clampf(sin(day_t * PI) * 1.4, 0.0, 1.0)
	elif current_hour >= 5.0 and current_hour < 6.0:
		pre_dawn = clampf(current_hour - 5.0, 0.0, 1.0)

	if _sun_light != null:
		if is_night:
			var moon_dir: Vector3 = Vector3(0.25, 0.82, 0.51).normalized()
			var dawn_dir: Vector3 = Vector3(-0.75, sin(deg_to_rad(9.0)), 0.72).normalized()
			var active_dir: Vector3 = moon_dir.lerp(dawn_dir, pre_dawn).normalized()
			_sun_light.global_transform.basis = Basis.looking_at(-active_dir, Vector3.UP)
			_sun_light.light_color = Color(0.40, 0.48, 0.66).lerp(Color(0.95, 0.58, 0.34), pre_dawn)
			_sun_light.light_energy = lerpf(0.16, 0.44, pre_dawn)
		else:
			var elev_deg: float = lerpf(11.0, 62.0, sin(day_t * PI))
			var azim_x: float = lerpf(-0.75, 0.75, day_t)
			var sun_dir: Vector3 = Vector3(azim_x, sin(deg_to_rad(elev_deg)), 0.72).normalized()
			_sun_light.global_transform.basis = Basis.looking_at(-sun_dir, Vector3.UP)
			_sun_light.light_color = Color(1.0, 0.92, 0.74).lerp(Color(1.0, 0.56, 0.28), dusk_weight)
			_sun_light.light_energy = lerpf(1.35, 0.48, dusk_weight)

	if _smiling_sun != null:
		_smiling_sun.visible = (current_hour >= 5.55 and current_hour <= 19.1)

	if _world_env != null and _world_env.environment != null:
		var env: Environment = _world_env.environment
		if is_night:
			env.ambient_light_color = Color(0.28, 0.34, 0.48).lerp(Color(0.56, 0.45, 0.40), pre_dawn)
			env.ambient_light_energy = lerpf(0.24, 0.46, pre_dawn)
			env.fog_light_color = Color(0.08, 0.10, 0.16).lerp(Color(0.46, 0.32, 0.24), pre_dawn)
			if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
				var sky_mat: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial
				sky_mat.sky_top_color = Color(0.03, 0.04, 0.09).lerp(Color(0.14, 0.13, 0.20), pre_dawn)
				sky_mat.sky_horizon_color = Color(0.10, 0.12, 0.20).lerp(Color(0.76, 0.40, 0.24), pre_dawn)
				sky_mat.ground_horizon_color = Color(0.07, 0.08, 0.12).lerp(Color(0.32, 0.21, 0.16), pre_dawn)
		else:
			var amb_day: Color = Color(0.64, 0.66, 0.72).lerp(Color(0.58, 0.46, 0.38), dusk_weight)
			env.ambient_light_color = amb_day
			env.ambient_light_energy = lerpf(0.72, 0.48, dusk_weight)
			env.fog_light_color = Color(0.55, 0.50, 0.42).lerp(Color(0.52, 0.34, 0.22), dusk_weight)
			if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
				var sky_mat: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial
				sky_mat.sky_top_color = Color(0.25, 0.28, 0.33).lerp(Color(0.14, 0.12, 0.18), dusk_weight)
				sky_mat.sky_horizon_color = Color(0.74, 0.60, 0.36).lerp(Color(0.78, 0.38, 0.20), dusk_weight)
				sky_mat.ground_horizon_color = Color(0.42, 0.34, 0.24).lerp(Color(0.32, 0.20, 0.14), dusk_weight)
