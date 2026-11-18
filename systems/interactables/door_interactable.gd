class_name DoorInteractable
extends Node3D
## Porta tática que abre/fecha 90 graus (Layer 1 [Environment] + Layer 4 [Interactables]).

const LAYER_ENV_AND_INTERACT: int = (1 << 0) | (1 << 3) # Layers 1 e 4

@export var open_angle_deg: float = 92.0
@export var swing_speed: float = 6.0
@export var is_open: bool = false

var _closed_yaw: float = 0.0
var _target_yaw: float = 0.0


func _ready() -> void:
	_closed_yaw = rotation_degrees.y
	_target_yaw = _closed_yaw + (open_angle_deg if is_open else 0.0)


func _physics_process(delta: float) -> void:
	rotation_degrees.y = lerpf(rotation_degrees.y, _target_yaw, clampf(swing_speed * delta, 0.0, 1.0))


func interact() -> void:
	is_open = not is_open
	_target_yaw = _closed_yaw + (open_angle_deg if is_open else 0.0)
	AudioManager.play_door_creak()


func get_interaction_prompt() -> String:
	return "[E] Fechar Porta" if is_open else "[E] Abrir Porta"
