class_name SanityComponent
extends Node
## Gerencia a exposição à luz do Sol Sorridente, escuridão absoluta, recuperação pelo Fogo Humano e alucinações da Epidemia da Verdade.

enum LightingZone {
	EXPOSED_TO_SUN = 0,
	ABSOLUTE_DARKNESS = 1,
	PROTECTED_BY_FIRE = 2,
}

const ENVIRONMENT_COLLISION_MASK: int = 1 << 0 # Layer 1 (Environment)
const CONFESSIONS: Array[String] = [
	"\"Eu prometi ao Leo que buscaria ele na escola naquele dia...\"",
	"\"Eu ouvi os gritos na rua e tranquei a porta por dentro.\"",
	"\"O sol está sorrindo porque sabe que eu menti.\"",
	"\"Nove meses... e eu ainda vejo a fita VHS todas as noites.\"",
	"\"Não olhe para cima. Quem olha confessa tudo até queimar.\"",
]

@export var max_sanity: float = 100.0
@export var sun_drain_rate: float = 8.0
@export var darkness_drain_rate: float = 1.5
@export var lantern_recovery_rate: float = 3.0
@export var sun_ray_length: float = 100.0

@export var sun_exposure_ray: RayCast3D
@export var lantern_system: LanternSystem
@export var directional_light: DirectionalLight3D
@export var whispers_audio: AudioStreamPlayer

var current_sanity: float = 100.0
var in_sunlight: bool = false
var current_zone: LightingZone = LightingZone.ABSOLUTE_DARKNESS
var _depleted_emitted: bool = false
var _confession_timer: float = 2.0
var _confession_index: int = 0
var _light_search_cooldown: float = 0.0
var _last_emitted_sanity: float = -1.0


func _ready() -> void:
	current_sanity = clampf(current_sanity, 0.0, max_sanity)
	_resolve_dependencies()
	_configure_raycast()
	_emit_sanity()
	GameEvents.lighting_zone_changed.emit(int(current_zone))


func _emit_sanity() -> void:
	_last_emitted_sanity = current_sanity
	GameEvents.sanity_changed.emit(current_sanity, max_sanity)


func _physics_process(delta: float) -> void:
	in_sunlight = _check_sun_exposure()

	var previous_zone: LightingZone = current_zone
	var sanity_rate: float = 0.0

	if in_sunlight:
		current_zone = LightingZone.EXPOSED_TO_SUN
		sanity_rate = -sun_drain_rate
	elif lantern_system != null and lantern_system.is_lit:
		current_zone = LightingZone.PROTECTED_BY_FIRE
		sanity_rate = lantern_recovery_rate
	else:
		current_zone = LightingZone.ABSOLUTE_DARKNESS
		sanity_rate = -darkness_drain_rate

	if current_zone != previous_zone:
		_update_zone_audio_feedback()
		GameEvents.lighting_zone_changed.emit(int(current_zone))

	_apply_sanity_delta(sanity_rate * delta)
	_update_confessions_and_heartbeat(delta)


func modify_sanity(amount: float) -> void:
	_apply_sanity_delta(amount)


func get_sanity_ratio() -> float:
	if max_sanity <= 0.0:
		return 0.0
	return current_sanity / max_sanity


func _update_confessions_and_heartbeat(delta: float) -> void:
	var ratio: float = get_sanity_ratio()
	var heart_level: float = clampf((0.55 - ratio) / 0.55, 0.0, 1.0)
	if in_sunlight:
		heart_level = maxf(heart_level, 0.45)
	AudioManager.set_heartbeat_intensity(heart_level)

	if in_sunlight or current_sanity < 50.0:
		_confession_timer -= delta
		if _confession_timer <= 0.0:
			_confession_timer = 5.5
			var line: String = CONFESSIONS[_confession_index % CONFESSIONS.size()]
			_confession_index += 1
			GameEvents.confession_triggered.emit(line)
			AudioManager.play_whisper()
	else:
		_confession_timer = 1.5


func _check_sun_exposure() -> bool:
	if directional_light == null:
		# Busca na árvore no máximo 1x por segundo (antes rodava find_children a cada frame se não achasse).
		_light_search_cooldown -= get_physics_process_delta_time()
		if _light_search_cooldown <= 0.0:
			_light_search_cooldown = 1.0
			_find_directional_light()
	if sun_exposure_ray == null or directional_light == null:
		return false
	if not directional_light.visible:
		return false

	var light_incident_dir: Vector3 = -directional_light.global_transform.basis.z.normalized()
	var to_sun_world_vector: Vector3 = -light_incident_dir * sun_ray_length
	sun_exposure_ray.target_position = sun_exposure_ray.global_transform.basis.inverse() * to_sun_world_vector
	sun_exposure_ray.force_raycast_update()
	return not sun_exposure_ray.is_colliding()


func _apply_sanity_delta(delta_amount: float) -> void:
	if is_zero_approx(delta_amount):
		return
	var previous_sanity: float = current_sanity
	current_sanity = clampf(current_sanity + delta_amount, 0.0, max_sanity)
	if not is_equal_approx(previous_sanity, current_sanity):
		var at_bound: bool = current_sanity <= 0.0 or current_sanity >= max_sanity
		if absf(current_sanity - _last_emitted_sanity) >= 0.2 or at_bound:
			_emit_sanity()
		if current_sanity <= 0.0 and not _depleted_emitted:
			_depleted_emitted = true
			GameEvents.sanity_depleted.emit()
		elif current_sanity > 0.0:
			_depleted_emitted = false


func _update_zone_audio_feedback() -> void:
	AudioManager.set_sun_drone_active(current_zone == LightingZone.EXPOSED_TO_SUN)
	if whispers_audio == null:
		return
	if current_zone == LightingZone.EXPOSED_TO_SUN:
		if not whispers_audio.playing:
			whispers_audio.play()
	else:
		if whispers_audio.playing:
			whispers_audio.stop()


func _resolve_dependencies() -> void:
	var parent_node: Node = get_parent()
	if parent_node != null:
		if sun_exposure_ray == null:
			sun_exposure_ray = parent_node.get_node_or_null("SunExposureRay") as RayCast3D
		if lantern_system == null:
			lantern_system = parent_node.get_node_or_null("HeadPivot/HandPivot/LanternSystem") as LanternSystem
	if directional_light == null:
		_find_directional_light()


func _find_directional_light() -> void:
	var grouped: Node = get_tree().get_first_node_in_group("sun_light")
	if grouped is DirectionalLight3D:
		directional_light = grouped as DirectionalLight3D
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var found: Array[Node] = scene_root.find_children("*", "DirectionalLight3D", true, false)
	if not found.is_empty():
		directional_light = found[0] as DirectionalLight3D


func _configure_raycast() -> void:
	if sun_exposure_ray == null:
		return
	sun_exposure_ray.enabled = true
	sun_exposure_ray.collision_mask = ENVIRONMENT_COLLISION_MASK
	sun_exposure_ray.hit_from_inside = false
