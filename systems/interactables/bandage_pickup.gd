extends Area3D
## Kit de Bandagens (Layer 4) que pode ser guardado no inventário e usado com [H] para curar +40 de Vida.

const LAYER_INTERACTABLES: int = 1 << 3


func _ready() -> void:
	collision_layer = LAYER_INTERACTABLES
	collision_mask = 0
	monitorable = true
	monitoring = false

	var col: CollisionShape3D = CollisionShape3D.new()
	var box_s: BoxShape3D = BoxShape3D.new()
	box_s.size = Vector3(0.36, 0.26, 0.36)
	col.shape = box_s
	col.position = Vector3(0.0, 0.1, 0.0)
	add_child(col)

	var kit_mat: StandardMaterial3D = StandardMaterial3D.new()
	kit_mat.albedo_color = Color(0.90, 0.88, 0.84)

	var cross_mat: StandardMaterial3D = StandardMaterial3D.new()
	cross_mat.albedo_color = Color(0.82, 0.12, 0.12)
	cross_mat.emission_enabled = true
	cross_mat.emission = Color(0.65, 0.08, 0.08)
	cross_mat.emission_energy_multiplier = 0.45

	var kit_mesh: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.28, 0.12, 0.22)
	kit_mesh.mesh = bm
	kit_mesh.position = Vector3(0.0, 0.06, 0.0)
	kit_mesh.material_override = kit_mat
	add_child(kit_mesh)

	for cross_size: Vector3 in [Vector3(0.12, 0.02, 0.04), Vector3(0.04, 0.02, 0.12)]:
		var c_mesh: MeshInstance3D = MeshInstance3D.new()
		var cm: BoxMesh = BoxMesh.new()
		cm.size = cross_size
		c_mesh.mesh = cm
		c_mesh.position = Vector3(0.0, 0.125, 0.0)
		c_mesh.material_override = cross_mat
		add_child(c_mesh)

	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(0.95, 0.45, 0.45)
	glow.light_energy = 0.35
	glow.omni_range = 1.4
	glow.shadow_enabled = false
	glow.distance_fade_enabled = true
	glow.distance_fade_begin = 10.0
	glow.distance_fade_length = 4.0
	glow.position = Vector3(0.0, 0.22, 0.0)
	add_child(glow)


func interact() -> void:
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if inv == null or not inv.has_method("add_bandage"):
		return
	if bool(inv.call("add_bandage")):
		AudioManager.play_pickup()
		GameEvents.status_message_requested.emit("Bandagem guardada ([H] Curar +40 Vida)")
		queue_free()
	else:
		AudioManager.play_locked()
		GameEvents.status_message_requested.emit("Limite máximo de bandagens atingido!")


func get_interaction_prompt() -> String:
	return "[E] Pegar Bandagem"
