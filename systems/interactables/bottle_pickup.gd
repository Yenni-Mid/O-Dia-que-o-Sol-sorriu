extends Area3D
## Garrafa coletável (Layer 4) usada como isca sonora [G] contra os Cultistas.

const LAYER_INTERACTABLES: int = 1 << 3


func _ready() -> void:
	collision_layer = LAYER_INTERACTABLES
	collision_mask = 0
	monitorable = true
	monitoring = false

	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.28, 0.4, 0.28)
	col.shape = box
	col.position = Vector3(0.0, 0.14, 0.0)
	add_child(col)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.52, 0.26)
	mat.roughness = 0.35

	var base_mesh: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.055
	cyl.bottom_radius = 0.065
	cyl.height = 0.22
	cyl.radial_segments = 6
	base_mesh.mesh = cyl
	base_mesh.position = Vector3(0.0, 0.11, 0.0)
	base_mesh.material_override = mat
	add_child(base_mesh)

	var neck_mesh: MeshInstance3D = MeshInstance3D.new()
	var neck: CylinderMesh = CylinderMesh.new()
	neck.top_radius = 0.025
	neck.bottom_radius = 0.04
	neck.height = 0.09
	neck.radial_segments = 6
	neck_mesh.mesh = neck
	neck_mesh.position = Vector3(0.0, 0.26, 0.0)
	neck_mesh.material_override = mat
	add_child(neck_mesh)


func interact() -> void:
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if inv == null or not inv.has_method("add_bottle"):
		return
	if bool(inv.call("add_bottle")):
		AudioManager.play_pickup()
		GameEvents.status_message_requested.emit("Garrafa vazia guardada ([G] Arremessar)")
		queue_free()
	else:
		AudioManager.play_locked()
		GameEvents.status_message_requested.emit("Bolsos cheios de garrafas!")


func get_interaction_prompt() -> String:
	return "[E] Pegar Garrafa (Distração)"
