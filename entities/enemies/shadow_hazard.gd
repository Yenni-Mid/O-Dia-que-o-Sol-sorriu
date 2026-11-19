class_name ShadowHazard
extends Area3D
## Sombra Viva no chão (Layer 6, Mask: Layer 2 [Player] e Layer 5 [LanternLight]).
## Reduz a velocidade do jogador em 50% e causa 15.0 de dano/s se nenhuma SafeZoneArea estiver ativa.

const LAYER_CORRUPTED_SHADOWS: int = 1 << 5 # Layer 6
const MASK_PLAYER_AND_LANTERN: int = (1 << 1) | (1 << 4) # Layers 2 e 5

@export var damage_per_second: float = 15.0
@export var slow_multiplier: float = 0.5

var _tracked_player: PlayerController
var _player_health: HealthComponent
var _active_safe_zones: int = 0
var _hum_3d: AudioStreamPlayer3D

@onready var visual_mesh: Node3D = get_node_or_null("ShadowMesh") as Node3D


func _ready() -> void:
	add_to_group("shadow_hazard")
	collision_layer = LAYER_CORRUPTED_SHADOWS
	collision_mask = MASK_PLAYER_AND_LANTERN
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	GameEvents.lantern_toggled.connect(_on_lantern_toggled)

	_hum_3d = AudioStreamPlayer3D.new()
	_hum_3d.name = "ShadowHum3D"
	_hum_3d.stream = AudioManager.get_shadow_hum_stream()
	_hum_3d.max_distance = 9.0
	_hum_3d.volume_db = -12.0
	add_child(_hum_3d)
	if _hum_3d.stream != null:
		_hum_3d.play()


func _physics_process(delta: float) -> void:
	var suppressed_by_light: bool = _active_safe_zones > 0
	if visual_mesh != null:
		var target_scale_y: float = 0.15 if suppressed_by_light else 1.0
		visual_mesh.scale.y = lerpf(visual_mesh.scale.y, target_scale_y, clampf(8.0 * delta, 0.0, 1.0))
		var target_xz: float = 0.82 if suppressed_by_light else 1.0
		var xz: float = lerpf(visual_mesh.scale.x, target_xz, clampf(5.0 * delta, 0.0, 1.0))
		visual_mesh.scale.x = xz
		visual_mesh.scale.z = xz

	if _hum_3d != null:
		var target_db: float = -30.0 if suppressed_by_light else -12.0
		_hum_3d.volume_db = lerpf(_hum_3d.volume_db, target_db, clampf(6.0 * delta, 0.0, 1.0))

	if _tracked_player == null:
		return

	if suppressed_by_light:
		_tracked_player.reset_speed_modifier()
	else:
		_tracked_player.set_speed_modifier(slow_multiplier)
		if _player_health != null:
			_player_health.take_damage(damage_per_second * delta)


func is_suppressed() -> bool:
	return _active_safe_zones > 0


func _on_lantern_toggled(is_lit: bool) -> void:
	if not is_lit:
		_active_safe_zones = 0


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		_tracked_player = body as PlayerController
		_player_health = _tracked_player.get_node_or_null("HealthComponent") as HealthComponent


func _on_body_exited(body: Node3D) -> void:
	if body == _tracked_player and _tracked_player != null:
		_tracked_player.reset_speed_modifier()
		_tracked_player = null
		_player_health = null


func _on_area_entered(area: Area3D) -> void:
	if (area.collision_layer & (1 << 4)) != 0 and area.monitoring:
		_active_safe_zones += 1


func _on_area_exited(area: Area3D) -> void:
	if (area.collision_layer & (1 << 4)) != 0:
		_active_safe_zones = maxi(0, _active_safe_zones - 1)
