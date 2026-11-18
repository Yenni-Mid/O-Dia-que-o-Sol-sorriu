class_name EnemyStateMachine
extends Node
## Máquina de Estados Finitos (FSM) para os Lunáticos (Patrol, Suspicious, Chase, Attack).

@export var initial_state: Node

var current_state: Node
var _states: Dictionary = {}


func _ready() -> void:
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
