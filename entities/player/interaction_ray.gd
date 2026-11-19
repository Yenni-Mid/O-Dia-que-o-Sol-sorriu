class_name InteractionRay
extends RayCast3D
## RayCast3D de interação em 1ª pessoa (Mask: Layer 4 - Interactables) para Ecos, portas e refis de óleo.

const INTERACTABLES_MASK: int = 1 << 3 # Layer 4 (Interactables)

var _last_prompt: String = ""


func _ready() -> void:
	_ensure_input_actions()
	target_position = Vector3(0.0, 0.0, -2.2)
	collision_mask = INTERACTABLES_MASK
	collide_with_areas = true
	collide_with_bodies = true
	enabled = true


func _physics_process(_delta: float) -> void:
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if player != null and player.is_hidden:
		if not _last_prompt.is_empty():
			_last_prompt = ""
			GameEvents.interaction_prompt_changed.emit("")
		return

	var target: Object = _get_interactable_target()
	var next_prompt: String = ""
	if target != null:
		if target.has_method("get_interaction_prompt"):
			next_prompt = str(target.call("get_interaction_prompt"))
		else:
			next_prompt = "[E] Interagir"
	if next_prompt != _last_prompt:
		_last_prompt = next_prompt
		GameEvents.interaction_prompt_changed.emit(_last_prompt)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if player != null and player.is_hidden:
		return
	var target: Object = _get_interactable_target()
	if target != null:
		target.call("interact")
		get_viewport().set_input_as_handled()


func _get_interactable_target() -> Object:
	force_raycast_update()
	if not is_colliding():
		return null
	var collider: Object = get_collider()
	if collider == null:
		return null
	if collider.has_method("interact"):
		return collider
	if collider is Node:
		var parent_node: Node = (collider as Node).get_parent()
		if parent_node != null and parent_node.has_method("interact"):
			return parent_node
	return null


func _ensure_input_actions() -> void:
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = KEY_E
	InputMap.action_add_event("interact", key_event)
