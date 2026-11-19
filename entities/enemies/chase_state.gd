class_name ChaseState
extends Node
## Estado de perseguição e ataque corpo a corpo dos Lunáticos.
## Usa linha de visão real (guardando última posição vista), abre portas e evita Sombras Vivas se o lampião estiver apagado.

@export var chase_speed: float = 4.6
@export var attack_range: float = 1.6
@export var attack_damage: float = 25.0
@export var attack_cooldown: float = 1.2
@export var lose_sight_time: float = 4.0

var _enemy: CharacterBody3D
var _fsm: EnemyStateMachine
var _cooldown_timer: float = 0.0
var _lost_timer: float = 0.0
var _door_cooldown: float = 0.0
var _door_pause_timer: float = 0.0
var _last_known_pos: Vector3 = Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float


func setup(enemy_node: Node, fsm_node: EnemyStateMachine) -> void:
	_enemy = enemy_node as CharacterBody3D
	_fsm = fsm_node


func enter() -> void:
	_lost_timer = 0.0
	_door_cooldown = 0.0
	_door_pause_timer = 0.0
	var player: PlayerController = _find_player()
	if player != null:
		_last_known_pos = player.global_position
	elif _enemy != null:
		_last_known_pos = _enemy.global_position


func exit() -> void:
	if _enemy != null:
		_enemy.velocity.x = 0.0
		_enemy.velocity.z = 0.0


func physics_update(delta: float) -> void:
	if _enemy == null:
		return
	if not _enemy.is_on_floor():
		_enemy.velocity.y -= _gravity * delta

	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	if _door_cooldown > 0.0:
		_door_cooldown -= delta

	var player: PlayerController = _find_player()
	if player == null:
		_fsm.transition_to("PatrolState")
		return

	# Lunáticos evitam entrar em Sombras Vivas se o jogador estiver com o lampião apagado.
	if _is_player_in_unlit_shadow(player):
		_enemy.velocity.x = 0.0
		_enemy.velocity.z = 0.0
		_enemy.move_and_slide()
		_lost_timer += delta
		if _lost_timer >= lose_sight_time * 0.5:
			_fsm.transition_to("PatrolState")
		return

	var sees_player: bool = _fsm.can_see_player(_enemy, player, 8.0, 22.0)
	if sees_player:
		_last_known_pos = player.global_position
		_lost_timer = 0.0
	else:
		_lost_timer += delta
		var flat_dist_last: float = Vector2(_enemy.global_position.x, _enemy.global_position.z).distance_to(Vector2(_last_known_pos.x, _last_known_pos.z))
		if flat_dist_last <= 1.1 or _lost_timer >= lose_sight_time:
			var susp_node: Node = _fsm.get_node_or_null("SuspiciousState")
			if susp_node != null and susp_node.has_method("set_investigation_target"):
				susp_node.call("set_investigation_target", _last_known_pos)
				_fsm.transition_to("SuspiciousState")
			else:
				_fsm.transition_to("PatrolState")
			return

	var dist: float = _enemy.global_position.distance_to(player.global_position)
	if sees_player and dist <= attack_range:
		if _fsm.get_node_or_null("AttackState") != null:
			_fsm.transition_to("AttackState")
			return
		_enemy.velocity.x = 0.0
		_enemy.velocity.z = 0.0
		if _cooldown_timer <= 0.0:
			_cooldown_timer = attack_cooldown
			var health: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
			if health != null:
				health.take_damage(attack_damage)
	else:
		if _door_pause_timer > 0.0:
			_door_pause_timer -= delta
			_enemy.velocity.x = 0.0
			_enemy.velocity.z = 0.0
		else:
			if _door_cooldown <= 0.0 and _fsm.try_open_blocking_door(_enemy):
				_door_cooldown = 1.5
				_door_pause_timer = 0.35
				_enemy.velocity.x = 0.0
				_enemy.velocity.z = 0.0
			else:
				var move_target: Vector3 = player.global_position if sees_player else _last_known_pos
				var dir: Vector3 = _fsm.compute_steered_direction(_enemy, move_target)
				if dir.length_squared() > 0.0025:
					_enemy.velocity.x = dir.x * chase_speed
					_enemy.velocity.z = dir.z * chase_speed
					var target_yaw: float = atan2(-dir.x, -dir.z)
					_enemy.rotation.y = lerp_angle(_enemy.rotation.y, target_yaw, minf(1.0, 10.0 * delta))
				else:
					_enemy.velocity.x = 0.0
					_enemy.velocity.z = 0.0

	_enemy.move_and_slide()


func _is_player_in_unlit_shadow(player: PlayerController) -> bool:
	return _fsm.is_player_in_unlit_shadow(player)


func _find_player() -> PlayerController:
	return _fsm.get_player() if _fsm != null else null
