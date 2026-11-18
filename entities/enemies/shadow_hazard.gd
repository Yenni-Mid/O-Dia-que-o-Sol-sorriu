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

@onready var visual_mesh: Node3D = get_node_or_null("ShadowMesh") as Node3D


func _ready() -> void:
	collision_layer = LAYER_CORRUPTED_SHADOWS
	collision_mask = MASK_PLAYER_AND_LANTERN
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	var suppressed_by_light: bool = _is_suppressed_by_lantern()
	if visual_mesh != null:
		var target_scale_y: float = 0.15 if suppressed_by_light else 1.0
		visual_mesh.scale.y = lerpf(visual_mesh.scale.y, target_scale_y, clampf(8.0 * delta, 0.0, 1.0))

	if _tracked_player == null:
		return

	if suppressed_by_light:
		_tracked_player.reset_speed_modifier()
	else:
		_tracked_player.set_speed_modifier(slow_multiplier)
		if _player_health != null:
			_player_health.take_damage(damage_per_second * delta)


func is_suppressed() -> bool:
	return _is_suppressed_by_lantern()


func _is_suppressed_by_lantern() -> bool:
	if _active_safe_zones > 0:
		return true
	var overlapping: Array[Area3D] = get_overlapping_areas()
	for area: Area3D in overlapping:
		if (area.collision_layer & (1 << 4)) != 0 and area.monitoring:
			return true
	return false


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
	if (area.collision_layer & (1 << 4)) != 0:
		_active_safe_zones += 1


func _on_area_exited(area: Area3D) -> void:
	if (area.collision_layer & (1 << 4)) != 0:
		_active_safe_zones = maxi(0, _active_safe_zones - 1)
