extends ColorRect
## Controla os parâmetros dinâmicos do pós-processamento PSX a partir dos eventos de jogo
## (exposição ao sol, fogo do lampião, dano, sanidade baixa, morte e fade-in inicial).

var _mat: ShaderMaterial
var _sun: float = 0.0
var _sun_target: float = 0.0
var _fire: float = 0.0
var _fire_target: float = 0.0
var _damage: float = 0.0
var _sanity_ratio: float = 1.0
var _distortion: float = 0.0
var _fade: float = 1.0
var _fade_target: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = material as ShaderMaterial
	_sync_pixel_scale()
	GameEvents.lighting_zone_changed.connect(_on_zone_changed)
	GameEvents.sanity_changed.connect(_on_sanity_changed)
	GameEvents.player_damaged.connect(_on_player_damaged)
	GameEvents.player_died.connect(_on_game_over)
	GameEvents.sanity_depleted.connect(_on_game_over)


func _process(delta: float) -> void:
	if _mat == null:
		return
	_sun = move_toward(_sun, _sun_target, delta * 1.6)
	_fire = move_toward(_fire, _fire_target, delta * 2.0)
	_damage = move_toward(_damage, 0.0, delta * 1.8)
	var target_distortion: float = clampf((0.45 - _sanity_ratio) / 0.45, 0.0, 1.0)
	_distortion = move_toward(_distortion, target_distortion, delta * 0.5)
	_fade = move_toward(_fade, _fade_target, delta * 0.8)

	_mat.set_shader_parameter("sun_exposure", _sun)
	_mat.set_shader_parameter("fire_warmth", _fire)
	_mat.set_shader_parameter("damage_flash", _damage)
	_mat.set_shader_parameter("sanity_distortion", _distortion)
	_mat.set_shader_parameter("aberration", _damage * 1.2 + _sun * 0.35)
	_mat.set_shader_parameter("fade_to_black", _fade)


func _sync_pixel_scale() -> void:
	if _mat == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var container: SubViewportContainer = scene_root.get_node_or_null("SubViewportContainer") as SubViewportContainer
	if container != null and container.stretch:
		_mat.set_shader_parameter("pixel_scale", float(container.stretch_shrink))


func _on_zone_changed(zone: int) -> void:
	_sun_target = 1.0 if zone == 0 else 0.0
	_fire_target = 1.0 if zone == 2 else 0.0


func _on_sanity_changed(current: float, max_val: float) -> void:
	_sanity_ratio = current / maxf(max_val, 0.001)


func _on_player_damaged(amount: float) -> void:
	_damage = clampf(_damage + amount / 25.0, 0.0, 1.0)


func _on_game_over() -> void:
	_fade_target = 0.55
