class_name DoorInteractable
extends Node3D
## Porta tática (Layer 1 [Environment] + Layer 4 [Interactables]) com suporte a tranca por chave.

const LAYER_ENV_AND_INTERACT: int = (1 << 0) | (1 << 3)

@export var open_angle_deg: float = 92.0
@export var swing_speed: float = 6.0
@export var is_open: bool = false
@export var is_locked: bool = false
@export var required_key_id: String = ""
@export var key_display_name: String = ""
@export var should_stay_closed: bool = true

var started_locked: bool = false
var opened_by_player: bool = false
var _enemy_acting: bool = false
var _closed_yaw: float = 0.0
var _target_yaw: float = 0.0
var _audio_3d: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("door_interactable")
	started_locked = is_locked
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
	if is_locked:
		var inv: Node = get_tree().get_first_node_in_group("inventory")
		var key_label: String = key_display_name if not key_display_name.is_empty() else required_key_id
		if inv != null and inv.has_method("has_key") and bool(inv.call("has_key", required_key_id)):
			is_locked = false
			AudioManager.play_unlock()
			GameEvents.status_message_requested.emit("Destrancado com %s" % key_label)
		else:
			AudioManager.play_locked()
			GameEvents.status_message_requested.emit("Trancada — Requer: %s" % key_label)
			return

	is_open = not is_open
	if not _enemy_acting:
		opened_by_player = is_open
	_target_yaw = _closed_yaw + (open_angle_deg if is_open else 0.0)
	set_physics_process(true)
	_play_door_sound()


func open_by_enemy() -> void:
	if not is_locked and not is_open:
		_enemy_acting = true
		interact()
		_enemy_acting = false


func close_by_enemy() -> void:
	if is_open:
		is_open = false
		opened_by_player = false
		_target_yaw = _closed_yaw
		set_physics_process(true)
		_play_door_sound()


func close_by_haunt() -> void:
	if is_open:
		is_open = false
		opened_by_player = false
		_target_yaw = _closed_yaw
		set_physics_process(true)
		_play_door_sound()


func _play_door_sound() -> void:
	if _audio_3d != null and _audio_3d.stream != null:
		_audio_3d.pitch_scale = randf_range(0.88, 1.12)
		_audio_3d.play()
	else:
		AudioManager.play_door_creak()


func get_interaction_prompt() -> String:
	if is_locked:
		var key_label: String = key_display_name if not key_display_name.is_empty() else required_key_id
		var inv: Node = get_tree().get_first_node_in_group("inventory")
		if inv != null and inv.has_method("has_key") and bool(inv.call("has_key", required_key_id)):
			return "[E] Destrancar (%s)" % key_label
		return "[Trancada: %s]" % key_label
	return "[E] Fechar Porta" if is_open else "[E] Abrir Porta"
