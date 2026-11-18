extends NavigationRegion3D
## Gera a malha de navegação (NavMesh) em tempo de execução cobrindo a rua, varanda e a casa de dois andares.

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
	if is_inside_tree() and navigation_mesh != null:
		bake_navigation_mesh(false)
