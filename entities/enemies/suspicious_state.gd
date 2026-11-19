class_name SuspiciousState
extends Node
## Estado de investigação quando o Lunático ouve passos ou perde o jogador de vista.
## Atualiza alvo ao ouvir novos barulhos e abre portas fechadas no caminho.

@export var investigate_speed: float = 3.0
@export var reach_distance: float = 0.9
@export var look_around_duration: float = 3.0
@export var base_dark_vision_range: float = 8.0
@export var lit_vision_range: float = 22.0

var target_position: Vector3 = Vector3.ZERO
var _enemy: CharacterBody3D
var _fsm: EnemyStateMachine
var _wait_timer: float = 0.0
var _door_cooldown: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float


func setup(enemy_node: Node, fsm_node: EnemyStateMachine) -> void:
	_enemy = enemy_node as CharacterBody3D
	_fsm = fsm_node
	if not GameEvents.player_noise_emitted.is_connected(_on_player_noise_emitted):
		GameEvents.player_noise_emitted.connect(_on_player_noise_emitted)
	if not GameEvents.alarm_triggered.is_connected(_on_alarm_triggered):
		GameEvents.alarm_triggered.connect(_on_alarm_triggered)


func set_investigation_target(pos: Vector3) -> void:
	target_position = pos
	_wait_timer = look_around_duration


func enter() -> void:
	_wait_timer = look_around_duration
	_door_cooldown = 0.0


func exit() -> void:
	if _enemy != null:
		_enemy.velocity.x = 0.0
		_enemy.velocity.z = 0.0


func physics_update(delta: float) -> void:
	if _enemy == null:
		return
	if not _enemy.is_on_floor():
		_enemy.velocity.y -= _gravity * delta
	if _door_cooldown > 0.0:
		_door_cooldown -= delta

	var player: PlayerController = _find_player()
	if player != null and _can_see_player(player):
		_fsm.transition_to("ChaseState")
		return

	var flat_dist: float = Vector2(_enemy.global_position.x, _enemy.global_position.z).distance_to(Vector2(target_position.x, target_position.z))
	if flat_dist <= reach_distance:
		_enemy.velocity.x = 0.0
		_enemy.velocity.z = 0.0
		_enemy.rotate_y(1.2 * delta)
		_enemy.move_and_slide()
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_fsm.transition_to("PatrolState")
		return

	if _door_cooldown <= 0.0 and _fsm.try_open_blocking_door(_enemy):
		_door_cooldown = 1.5

	var dir: Vector3 = _fsm.compute_steered_direction(_enemy, target_position)
	if dir.length_squared() > 0.0025:
		_enemy.velocity.x = dir.x * investigate_speed
		_enemy.velocity.z = dir.z * investigate_speed
		var target_yaw: float = atan2(-dir.x, -dir.z)
		_enemy.rotation.y = lerp_angle(_enemy.rotation.y, target_yaw, minf(1.0, 8.0 * delta))
	else:
		_enemy.velocity.x = 0.0
		_enemy.velocity.z = 0.0
	_enemy.move_and_slide()


func _on_player_noise_emitted(origin: Vector3, radius: float) -> void:
	if _enemy == null or _fsm == null or not _fsm.is_night_active or _fsm.current_state != self:
		return
	if _enemy.global_position.distance_to(origin) <= radius:
		target_position = origin
		_wait_timer = look_around_duration


func _on_alarm_triggered(origin: Vector3) -> void:
	if _enemy == null or _fsm == null or not _fsm.is_night_active or _fsm.current_state != self:
		return
	target_position = origin
	_wait_timer = look_around_duration


func _can_see_player(player: PlayerController) -> bool:
	return _fsm.can_see_player(_enemy, player, base_dark_vision_range, lit_vision_range)


func _find_player() -> PlayerController:
	return _fsm.get_player() if _fsm != null else null
