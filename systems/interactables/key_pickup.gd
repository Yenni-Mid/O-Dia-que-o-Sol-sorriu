extends Area3D
## Chave coletável (Layer 4) que destranca portas específicas pelo key_id.

const LAYER_INTERACTABLES: int = 1 << 3

@export var key_id: String = "basement_key"
@export var key_name: String = "Chave do Porão"

var _visual_root: Node3D


func _ready() -> void:
	collision_layer = LAYER_INTERACTABLES
	collision_mask = 0
	monitorable = true
	monitoring = false

	var col: CollisionShape3D = CollisionShape3D.new()
	var box_s: BoxShape3D = BoxShape3D.new()
	box_s.size = Vector3(0.35, 0.3, 0.35)
	col.shape = box_s
	col.position = Vector3(0.0, 0.12, 0.0)
	add_child(col)

	_visual_root = Node3D.new()
	_visual_root.position = Vector3(0.0, 0.14, 0.0)
	add_child(_visual_root)

	var gold_mat: StandardMaterial3D = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.95, 0.78, 0.26)
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(0.85, 0.62, 0.14)
	gold_mat.emission_energy_multiplier = 0.65

	var parts: Array[Dictionary] = [
		{"size": Vector3(0.08, 0.025, 0.08), "pos": Vector3(-0.07, 0.0, 0.0)},
		{"size": Vector3(0.16, 0.02, 0.025), "pos": Vector3(0.04, 0.0, 0.0)},
		{"size": Vector3(0.03, 0.02, 0.05), "pos": Vector3(0.09, 0.0, 0.03)},
	]
	for p: Dictionary in parts:
		var m: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = p["size"] as Vector3
		m.mesh = bm
		m.position = p["pos"] as Vector3
		m.material_override = gold_mat
		_visual_root.add_child(m)

	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.35)
	glow.light_energy = 0.45
	glow.omni_range = 1.6
	glow.shadow_enabled = false
	glow.distance_fade_enabled = true
	glow.distance_fade_begin = 10.0
	glow.distance_fade_length = 4.0
	glow.position = Vector3(0.0, 0.22, 0.0)
	add_child(glow)


func _process(delta: float) -> void:
	if _visual_root != null:
		_visual_root.rotation.y += delta * 1.4


func interact() -> void:
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if inv != null and inv.has_method("add_key"):
		inv.call("add_key", key_id)
	AudioManager.play_pickup()
	GameEvents.status_message_requested.emit("Chave coletada: %s" % key_name)
	queue_free()


func get_interaction_prompt() -> String:
	return "[E] Pegar %s" % key_name
