class_name AttackState
extends Node
## Estado de ataque corpo a corpo do Lunático ao alcançar o jogador.

@export var attack_range: float = 1.7
@export var attack_damage: float = 25.0
@export var attack_cooldown: float = 1.1

var _enemy: CharacterBody3D
var _fsm: EnemyStateMachine
var _cooldown_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float


func setup(enemy_node: Node, fsm_node: EnemyStateMachine) -> void:
	_enemy = enemy_node as CharacterBody3D
	_fsm = fsm_node


func enter() -> void:
	_cooldown_timer = 0.15


func exit() -> void:
	pass


func physics_update(delta: float) -> void:
	if _enemy == null:
		return
	if not _enemy.is_on_floor():
		_enemy.velocity.y -= _gravity * delta

	_enemy.velocity.x = 0.0
	_enemy.velocity.z = 0.0
	_enemy.move_and_slide()

	var player: PlayerController = _find_player()
	if player == null:
		_fsm.transition_to("PatrolState")
		return

	var dist: float = _enemy.global_position.distance_to(player.global_position)
	if dist > attack_range * 1.15:
		_fsm.transition_to("ChaseState")
		return

	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		_cooldown_timer = attack_cooldown
		var health: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			health.take_damage(attack_damage)


func _find_player() -> PlayerController:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	var players: Array[Node] = scene_root.find_children("*", "PlayerController", true, false)
	if players.is_empty():
		return null
	return players[0] as PlayerController
