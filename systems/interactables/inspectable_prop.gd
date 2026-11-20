class_name InspectableProp
extends Area3D
## Objeto-chave examinável em 3D (Layer 4) que abre o ItemInspectUI.

const LAYER_INTERACTABLES: int = 1 << 3

@export var item_id: String = "leo_photo"
@export var item_title: String = "Foto do Leo"
@export_multiline var item_description: String = "Um retrato amassado do Leo antes do Sol sorrir."
@export_multiline var back_note: String = "No verso a caneta: \"Não olhe para a Torre.\""


func _ready() -> void:
	collision_layer = LAYER_INTERACTABLES
	collision_mask = 0
	monitorable = true
	monitoring = false

	var col: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(0.45, 0.25, 0.45)
	col.shape = bs
	col.position = Vector3(0.0, 0.08, 0.0)
	add_child(col)

	var m: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.24, 0.02, 0.30)
	m.mesh = bm
	m.position = Vector3(0.0, 0.02, 0.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.84, 0.80, 0.70) if item_id == "leo_photo" else Color(0.72, 0.68, 0.58)
	m.material_override = mat
	add_child(m)


func interact() -> void:
	GameEvents.item_inspect_requested.emit({
		"item_id": item_id,
		"title": item_title,
		"description": item_description,
		"back_note": back_note,
	})


func get_interaction_prompt() -> String:
	return "[E] Examinar %s" % item_title
