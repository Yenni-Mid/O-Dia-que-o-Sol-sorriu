class_name DoorInteractable
extends Node3D
## Porta tática que abre/fecha 90 graus (Layer 1 [Environment] + Layer 4 [Interactables]).
## Otimizada: desliga _physics_process em repouso e usa áudio 3D espacial.

const LAYER_ENV_AND_INTERACT: int = (1 << 0) | (1 << 3) # Layers 1 e 4

@export var open_angle_deg: float = 92.0
@export var swing_speed: float = 6.0
@export var is_open: bool = false

var _closed_yaw: float = 0.0
var _target_yaw: float = 0.0
var _audio_3d: AudioStreamPlayer3D


func _ready() -> void:
	_closed_yaw = rotation_degrees.y
	_target_yaw = _closed_yaw + (open_angle_deg if is_open else 0.0)
	if is_open:
		rotation_degrees.y = _target_yaw
	set_physics_process(false)

	var leaf: Node = get_node_or_null("DoorLeaf")
	if leaf != null:
		leaf.add_to_group("door_leaf")
	else:
		for child: Node in get_children():
			if child is CollisionObject3D:
				child.add_to_group("door_leaf")

	_audio_3d = AudioStreamPlayer3D.new()
	_audio_3d.name = "DoorAudio3D"
	_audio_3d.stream = AudioManager.get_door_stream()
	_audio_3d.max_distance = 14.0
	_audio_3d.volume_db = -4.0
	add_child(_audio_3d)


func _physics_process(delta: float) -> void:
	rotation_degrees.y = lerpf(rotation_degrees.y, _target_yaw, clampf(swing_speed * delta, 0.0, 1.0))
	if absf(rotation_degrees.y - _target_yaw) <= 0.15:
		rotation_degrees.y = _target_yaw
		set_physics_process(false)


func interact() -> void:
	is_open = not is_open
	_target_yaw = _closed_yaw + (open_angle_deg if is_open else 0.0)
	set_physics_process(true)
	if _audio_3d != null and _audio_3d.stream != null:
		_audio_3d.pitch_scale = randf_range(0.88, 1.12)
		_audio_3d.play()
	else:
		AudioManager.play_door_creak()


func open_by_enemy() -> void:
	if not is_open:
		interact()


func get_interaction_prompt() -> String:
	return "[E] Fechar Porta" if is_open else "[E] Abrir Porta"
