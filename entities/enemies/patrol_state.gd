class_name PatrolState
extends Node
## Estado de patrulha e suspeita dos Lunáticos nas áreas ensolaradas.

@export var patrol_speed: float = 2.2
@export var suspicious_speed: float = 3.0
@export var base_dark_vision_range: float = 8.0
@export var lit_vision_range: float = 22.0
@export var waypoint_reach_distance: float = 0.8
@export var patrol_group_name: String = ""
@export var custom_waypoints: PackedVector3Array = PackedVector3Array()

var _enemy: CharacterBody3D
var _fsm: EnemyStateMachine
var _waypoints: Array[Vector3] = []
var _waypoint_index: int = 0
var _waypoint_stall_timer: float = 0.0
var _investigating_point: bool = false
var _last_heard_position: Vector3 = Vector3.ZERO
var _suspicious_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float


func setup(enemy_node: Node, fsm_node: EnemyStateMachine) -> void:
	_enemy = enemy_node as CharacterBody3D
	_fsm = fsm_node
	if not GameEvents.player_noise_emitted.is_connected(_on_player_noise_emitted):
		GameEvents.player_noise_emitted.connect(_on_player_noise_emitted)


func enter() -> void:
	_investigating_point = false
	_suspicious_timer = 0.0
	_waypoint_stall_timer = 0.0
	if _waypoints.is_empty() and _enemy != null:
		_resolve_waypoints()


func exit() -> void:
	pass


func physics_update(delta: float) -> void:
	if _enemy == null:
		return

	if not _enemy.is_on_floor():
		_enemy.velocity.y -= _gravity * delta

	var player: PlayerController = _find_player()
	if player != null and _can_see_player(player):
		_fsm.transition_to("ChaseState")
		return

	var target_pos: Vector3 = _enemy.global_position
	var move_speed: float = patrol_speed

	if _investigating_point:
		target_pos = _last_heard_position
		move_speed = suspicious_speed
		if _enemy.global_position.distance_to(target_pos) <= waypoint_reach_distance:
			_suspicious_timer -= delta
			_enemy.velocity.x = 0.0
			_enemy.velocity.z = 0.0
			_enemy.move_and_slide()
			if _suspicious_timer <= 0.0:
				_investigating_point = false
			return
	elif not _waypoints.is_empty():
		target_pos = _waypoints[_waypoint_index]
		_waypoint_stall_timer += delta
		var reached: bool = Vector2(_enemy.global_position.x, _enemy.global_position.z).distance_to(Vector2(target_pos.x, target_pos.z)) <= waypoint_reach_distance
		if reached or _waypoint_stall_timer >= 9.0:
			_waypoint_index = (_waypoint_index + 1) % _waypoints.size()
			_waypoint_stall_timer = 0.0
			target_pos = _waypoints[_waypoint_index]

	var dir: Vector3 = _compute_steered_direction(target_pos)
	if dir.length_squared() > 0.0025:
		_enemy.velocity.x = dir.x * move_speed
		_enemy.velocity.z = dir.z * move_speed
		var target_yaw: float = atan2(-dir.x, -dir.z)
		_enemy.rotation.y = lerp_angle(_enemy.rotation.y, target_yaw, minf(1.0, 7.0 * delta))
	else:
		_enemy.velocity.x = 0.0
		_enemy.velocity.z = 0.0

	_enemy.move_and_slide()


func _compute_steered_direction(desired_target: Vector3) -> Vector3:
	if _fsm != null:
		return _fsm.compute_steered_direction(_enemy, desired_target)
	var fallback_dir: Vector3 = desired_target - _enemy.global_position
	fallback_dir.y = 0.0
	return fallback_dir.normalized() if fallback_dir.length_squared() > 0.0025 else Vector3.ZERO


func _resolve_waypoints() -> void:
	_waypoints.clear()
	if not custom_waypoints.is_empty():
		for pt: Vector3 in custom_waypoints:
			_waypoints.append(pt)
		return

	if not patrol_group_name.is_empty():
		var tree: SceneTree = get_tree()
		if tree != null:
			var group_nodes: Array[Node] = tree.get_nodes_in_group(patrol_group_name)
			for grp_node: Node in group_nodes:
				if grp_node is Marker3D:
					_waypoints.append((grp_node as Marker3D).global_position)
				else:
					for child: Node in grp_node.get_children():
						if child is Marker3D:
							_waypoints.append((child as Marker3D).global_position)
			if not _waypoints.is_empty():
				return

	var parent_node: Node = _enemy.get_parent()
	var wp_container: Node = _enemy.get_node_or_null("PatrolWaypoints")
	if wp_container == null and parent_node != null:
		wp_container = parent_node.get_node_or_null("PatrolWaypoints")
	if wp_container != null:
		for child: Node in wp_container.get_children():
			if child is Marker3D:
				_waypoints.append((child as Marker3D).global_position)
		if not _waypoints.is_empty():
			return

	var origin: Vector3 = _enemy.global_position
	_waypoints = [
		origin + Vector3(-4.0, 0.0, 0.0),
		origin + Vector3(4.0, 0.0, 0.0),
	]


func _can_see_player(player: PlayerController) -> bool:
	var dist: float = _enemy.global_position.distance_to(player.global_position)
	var max_range: float = player.get_detection_distance(base_dark_vision_range, lit_vision_range)
	if dist > max_range:
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


func _on_player_noise_emitted(origin: Vector3, radius: float) -> void:
	if _enemy == null or _fsm == null or _fsm.current_state != self:
		return
	if _enemy.global_position.distance_to(origin) <= radius:
		var susp_node: Node = _fsm.get_node_or_null("SuspiciousState")
		if susp_node != null and susp_node.has_method("set_investigation_target"):
			susp_node.call("set_investigation_target", origin)
			_fsm.transition_to("SuspiciousState")
		else:
			_last_heard_position = origin
			_investigating_point = true
			_suspicious_timer = 3.0
