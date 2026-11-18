class_name OilPickup
extends Area3D
## Refil de óleo interagível (Layer 4) que reabastece o lampião do jogador.

const LAYER_INTERACTABLES: int = 1 << 3 # Layer 4

@export var oil_amount: float = 35.0


func _ready() -> void:
	collision_layer = LAYER_INTERACTABLES
	collision_mask = 0
	monitorable = true
	monitoring = false


func interact() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var lanterns: Array[Node] = scene_root.find_children("*", "LanternSystem", true, false)
	if not lanterns.is_empty():
		var lantern: LanternSystem = lanterns[0] as LanternSystem
		if lantern != null:
			lantern.add_oil(oil_amount)
			AudioManager.play_lantern_ignite()
			queue_free()


func get_interaction_prompt() -> String:
	return "[E] Pegar Óleo (+%d)" % int(oil_amount)
