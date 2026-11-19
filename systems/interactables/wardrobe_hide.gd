class_name WardrobeHide
extends StaticBody3D
## Guarda-roupa interativo onde o jogador pode se esconder dos Lunáticos (Layers 1 e 4).

@export var hide_offset: Vector3 = Vector3(0.65, 0.0, 0.0)
@export var exit_offset: Vector3 = Vector3(1.25, 0.0, 0.0)

var _occupant: PlayerController


func interact() -> void:
	if _occupant != null and _occupant.is_hidden:
		_occupant.exit_hiding_spot(global_position + exit_offset)
		_occupant = null
		AudioManager.play_door_creak()
		return

	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if player != null:
		_occupant = player
		player.enter_hiding_spot(global_position + hide_offset, global_position + exit_offset, self)
		AudioManager.play_door_creak()


func clear_occupant() -> void:
	_occupant = null


func get_interaction_prompt() -> String:
	if _occupant != null and _occupant.is_hidden:
		return "[E] Sair do Guarda-Roupa"
	return "[E] Esconder-se no Guarda-Roupa"
