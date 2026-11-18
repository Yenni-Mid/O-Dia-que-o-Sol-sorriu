class_name ChaseState
extends Node
## Estado de perseguição e ataque corpo a corpo dos Lunáticos.
## Evita áreas de Sombra Viva ativa se o jogador apagar o lampião.

@export var chase_speed: float = 4.6
@export var attack_range: float = 1.6
@export var attack_damage: float = 25.0
@export var attack_cooldown: float = 1.2
@export var lose_sight_time: float = 4.0

var _enemy: CharacterBody3D
var _fsm: EnemyStateMachine
var _cooldown_timer: float = 0.0
var _lost_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float


func setup(enemy_node: Node, fsm_node: EnemyStateMachine) -> void:
	_enemy = enemy_node as CharacterBody3D
	_fsm = fsm_node


func enter() -> void:
	_lost_timer = 0.0


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

	var dist: float = _enemy.global_position.distance_to(player.global_position)
	var max_range: float = player.get_detection_distance(8.0, 22.0)
	if dist > max_range * 1.25:
		_lost_timer += delta
		if _lost_timer >= lose_sight_time:
			_fsm.transition_to("PatrolState")
			return
	else:
		_lost_timer = 0.0

	if dist <= attack_range:
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
		var dir: Vector3 = _fsm.compute_steered_direction(_enemy, player.global_position)
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
	if player.lantern_system != null and player.lantern_system.is_lit:
		return false
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return false
	var shadows: Array[Node] = scene_root.find_children("*", "ShadowHazard", true, false)
	for node: Node in shadows:
		var hazard: ShadowHazard = node as ShadowHazard
		if hazard != null and not hazard.is_suppressed() and hazard.overlaps_body(player):
			return true
	return false


func _find_player() -> PlayerController:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	var players: Array[Node] = scene_root.find_children("*", "PlayerController", true, false)
	if players.is_empty():
		return null
	return players[0] as PlayerController
