class_name SuspiciousState
extends Node
## Estado de investigação quando o Lunático ouve passos dentro do noise_radius do jogador.

@export var investigate_speed: float = 3.0
@export var reach_distance: float = 0.9
@export var look_around_duration: float = 3.0
@export var base_dark_vision_range: float = 8.0
@export var lit_vision_range: float = 22.0

var target_position: Vector3 = Vector3.ZERO
var _enemy: CharacterBody3D
var _fsm: EnemyStateMachine
var _wait_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float


func setup(enemy_node: Node, fsm_node: EnemyStateMachine) -> void:
	_enemy = enemy_node as CharacterBody3D
	_fsm = fsm_node


func set_investigation_target(pos: Vector3) -> void:
	target_position = pos
	_wait_timer = look_around_duration


func enter() -> void:
	_wait_timer = look_around_duration


func exit() -> void:
	if _enemy != null:
		_enemy.velocity.x = 0.0
		_enemy.velocity.z = 0.0


func physics_update(delta: float) -> void:
	if _enemy == null:
		return
	if not _enemy.is_on_floor():
		_enemy.velocity.y -= _gravity * delta

	var player: PlayerController = _find_player()
	if player != null and _can_see_player(player):
		_fsm.transition_to("ChaseState")
		return

	var flat_dist: float = Vector2(_enemy.global_position.x, _enemy.global_position.z).distance_to(Vector2(target_position.x, target_position.z))
	if flat_dist <= reach_distance:
		_enemy.velocity.x = 0.0
		_enemy.velocity.z = 0.0
		_enemy.rotate_y(1.2 * delta)
		_enemy.move_and_slide()
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_fsm.transition_to("PatrolState")
		return

	var dir: Vector3 = _fsm.compute_steered_direction(_enemy, target_position)
	if dir.length_squared() > 0.0025:
		_enemy.velocity.x = dir.x * investigate_speed
		_enemy.velocity.z = dir.z * investigate_speed
		var target_yaw: float = atan2(-dir.x, -dir.z)
		_enemy.rotation.y = lerp_angle(_enemy.rotation.y, target_yaw, minf(1.0, 8.0 * delta))
	else:
		_enemy.velocity.x = 0.0
		_enemy.velocity.z = 0.0
	_enemy.move_and_slide()


func _can_see_player(player: PlayerController) -> bool:
	var dist: float = _enemy.global_position.distance_to(player.global_position)
	if dist > player.get_detection_distance(base_dark_vision_range, lit_vision_range):
		return false
	var vision_ray: RayCast3D = _enemy.get_node_or_null("VisionRay") as RayCast3D
	if vision_ray == null:
		return true
	var world_to_player: Vector3 = (player.global_position + Vector3(0.0, 1.2, 0.0)) - vision_ray.global_position
	vision_ray.target_position = vision_ray.global_transform.basis.inverse() * world_to_player
	vision_ray.force_raycast_update()
	if not vision_ray.is_colliding():
		return true
	return vision_ray.get_collider() == player


func _find_player() -> PlayerController:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	var players: Array[Node] = scene_root.find_children("*", "PlayerController", true, false)
	if players.is_empty():
		return null
	return players[0] as PlayerController
