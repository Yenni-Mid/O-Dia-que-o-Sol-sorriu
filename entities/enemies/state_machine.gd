class_name EnemyStateMachine
extends Node
## Máquina de Estados Finitos (FSM) para os Lunáticos (Patrol, Suspicious, Chase, Attack).
## Também concentra serviços compartilhados pelos estados (busca do jogador, visão com cache, steering).

const VISION_CHECK_INTERVAL_MS: int = 120
const VISION_FOV_DOT: float = -0.15 ## ~100° para cada lado. Atrás disso só percebe a curta distância.
const CLOSE_SENSE_RANGE: float = 2.6

@export var initial_state: Node

var current_state: Node
var _states: Dictionary = {}
var _next_vision_ms: int = 0
var _cached_can_see: bool = false


func get_player() -> PlayerController:
	return get_tree().get_first_node_in_group("player") as PlayerController


## Linha de visão com cone de visão e cache (raycast no máximo a cada 120 ms por inimigo).
func can_see_player(enemy: CharacterBody3D, player: PlayerController, dark_range: float, lit_range: float) -> bool:
	if enemy == null or player == null:
		return false
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _next_vision_ms:
		return _cached_can_see
	_next_vision_ms = now_ms + VISION_CHECK_INTERVAL_MS
	_cached_can_see = _compute_can_see(enemy, player, dark_range, lit_range)
	return _cached_can_see


func _compute_can_see(enemy: CharacterBody3D, player: PlayerController, dark_range: float, lit_range: float) -> bool:
	var to_player: Vector3 = player.global_position - enemy.global_position
	var dist: float = to_player.length()
	if dist > player.get_detection_distance(dark_range, lit_range):
		return false
	if dist > CLOSE_SENSE_RANGE:
		var forward: Vector3 = -enemy.global_transform.basis.z
		var flat: Vector3 = Vector3(to_player.x, 0.0, to_player.z).normalized()
		if forward.dot(flat) < VISION_FOV_DOT:
			return false
	var vision_ray: RayCast3D = enemy.get_node_or_null("VisionRay") as RayCast3D
	if vision_ray == null:
		return true
	var eye_target: Vector3 = player.get_eye_position() if player.has_method("get_eye_position") else (player.global_position + Vector3(0.0, 1.2, 0.0))
	var world_to_player: Vector3 = eye_target - vision_ray.global_position
	vision_ray.target_position = vision_ray.global_transform.basis.inverse() * world_to_player
	vision_ray.force_raycast_update()
	if not vision_ray.is_colliding():
		return true
	return vision_ray.get_collider() == player


func try_open_blocking_door(enemy: CharacterBody3D) -> bool:
	if enemy == null:
		return false
	var world_3d: World3D = enemy.get_world_3d()
	if world_3d == null:
		return false
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if space_state == null:
		return false
	var origin: Vector3 = enemy.global_position + Vector3(0.0, 1.0, 0.0)
	var forward: Vector3 = -enemy.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		return false
	forward = forward.normalized()
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + forward * 1.5, 1 << 3, [enemy.get_rid()])
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Object = hit.get("collider", null) as Object
	if collider == null:
		return false
	var door_target: Node = null
	if collider.has_method("open_by_enemy"):
		door_target = collider as Node
	elif collider is Node:
		var p: Node = (collider as Node).get_parent()
		if p != null and p.has_method("open_by_enemy"):
			door_target = p
	if door_target != null and not bool(door_target.get("is_open")):
		door_target.call("open_by_enemy")
		return true
	return false


func is_player_in_unlit_shadow(player: PlayerController) -> bool:
	if player == null:
		return false
	if player.lantern_system != null and player.lantern_system.is_lit:
		return false
	for node: Node in get_tree().get_nodes_in_group("shadow_hazard"):
		var hazard: ShadowHazard = node as ShadowHazard
		if hazard != null and not hazard.is_suppressed() and hazard.overlaps_body(player):
			return true
	return false


func _ready() -> void:
	# Dessincroniza as checagens de visão entre inimigos para espalhar o custo entre frames.
	_next_vision_ms = Time.get_ticks_msec() + randi_range(0, VISION_CHECK_INTERVAL_MS)
	for child: Node in get_children():
		_states[child.name.to_lower()] = child
		if child.has_method("setup"):
			child.call("setup", get_parent(), self)
	if initial_state == null and get_child_count() > 0:
		initial_state = get_child(0)
	if initial_state != null:
		transition_to(initial_state.name)


func _physics_process(delta: float) -> void:
	if current_state != null and current_state.has_method("physics_update"):
		current_state.call("physics_update", delta)


func transition_to(state_name: String) -> void:
	var key: String = state_name.to_lower()
	if not _states.has(key):
		return
	var next_state: Node = _states[key] as Node
	if current_state == next_state:
		return
	if current_state != null and current_state.has_method("exit"):
		current_state.call("exit")
	current_state = next_state
	if current_state != null and current_state.has_method("enter"):
		current_state.call("enter")


func compute_steered_direction(enemy: CharacterBody3D, desired_target: Vector3, ray_distance: float = 1.4) -> Vector3:
	if enemy == null:
		return Vector3.ZERO

	var nav_target: Vector3 = desired_target
	var nav: NavigationAgent3D = enemy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav != null:
		var nav_map: RID = nav.get_navigation_map()
		if nav_map.is_valid() and NavigationServer3D.map_get_regions(nav_map).size() > 0 and NavigationServer3D.map_get_iteration_id(nav_map) > 0:
			nav.target_position = desired_target
			var next_pos: Vector3 = nav.get_next_path_position()
			var next_flat: Vector3 = next_pos - enemy.global_position
			next_flat.y = 0.0
			if next_flat.length_squared() > 0.01:
				nav_target = next_pos

	var dir: Vector3 = nav_target - enemy.global_position
	dir.y = 0.0
	if dir.length_squared() <= 0.0025:
		return Vector3.ZERO
	dir = dir.normalized()

	var world_3d: World3D = enemy.get_world_3d()
	if world_3d == null:
		return dir
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if space_state == null:
		return dir

	var origin: Vector3 = enemy.global_position + Vector3(0.0, 0.85, 0.0)
	var exclude_rids: Array[RID] = [enemy.get_rid()]
	var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
	var test_angles: Array[float] = [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0]

	for angle_deg: float in test_angles:
		var test_dir: Vector3 = dir.rotated(Vector3.UP, deg_to_rad(angle_deg))
		if _is_direction_clear(space_state, origin, test_dir, side, ray_distance, exclude_rids, is_zero_approx(angle_deg)):
			return test_dir

	return dir


func _is_direction_clear(
	space_state: PhysicsDirectSpaceState3D,
	origin: Vector3,
	test_dir: Vector3,
	side: Vector3,
	ray_distance: float,
	exclude_rids: Array[RID],
	check_shoulders: bool
) -> bool:
	var center_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		origin + test_dir * ray_distance,
		1,
		exclude_rids
	)
	if not space_state.intersect_ray(center_query).is_empty():
		return false

	if check_shoulders:
		var shoulder_dist: float = ray_distance * 0.85
		for offset_sign: float in [-1.0, 1.0]:
			var shoulder_origin: Vector3 = origin + side * (0.34 * offset_sign)
			var shoulder_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				shoulder_origin,
				shoulder_origin + test_dir * shoulder_dist,
				1,
				exclude_rids
			)
			if not space_state.intersect_ray(shoulder_query).is_empty():
				return false

	return true
