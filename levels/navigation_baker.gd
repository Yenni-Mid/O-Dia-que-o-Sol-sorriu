extends NavigationRegion3D
## Gera a malha de navegação (NavMesh) em tempo de execução cobrindo a rua, o quarteirão e a casa de dois andares.
## Remove temporariamente a colisão das folhas de porta durante o bake para que os vãos fiquem transitáveis.

@export var auto_bake_on_ready: bool = true


func _ready() -> void:
	if Engine.is_editor_hint() or not auto_bake_on_ready:
		return
	if navigation_mesh == null:
		var nav_mesh: NavigationMesh = NavigationMesh.new()
		nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
		nav_mesh.geometry_collision_mask = 1
		nav_mesh.agent_radius = 0.5
		nav_mesh.agent_height = 1.75
		nav_mesh.agent_max_climb = 0.5
		nav_mesh.agent_max_slope = 46.0
		nav_mesh.cell_size = 0.25
		nav_mesh.cell_height = 0.25
		navigation_mesh = nav_mesh
	call_deferred("_bake_safe")


func _bake_safe() -> void:
	if not is_inside_tree() or navigation_mesh == null:
		return

	var saved_layers: Array[Dictionary] = []
	for door_node: Node in get_tree().get_nodes_in_group("door_leaf"):
		if door_node is CollisionObject3D:
			var col_obj: CollisionObject3D = door_node as CollisionObject3D
			saved_layers.append({
				"node": col_obj,
				"layer": col_obj.collision_layer,
			})
			col_obj.collision_layer &= ~1

	bake_navigation_mesh(false)

	for entry: Dictionary in saved_layers:
		var col_obj: CollisionObject3D = entry["node"] as CollisionObject3D
		if is_instance_valid(col_obj):
			col_obj.collision_layer = int(entry["layer"])
