class_name HealthComponent
extends Node
## Gerencia a integridade física do jogador e dano letal (Sombras Vivas / Lunáticos).

@export var max_health: float = 100.0

var current_health: float = 100.0
var is_dead: bool = false


func _ready() -> void:
	current_health = clampf(current_health, 0.0, max_health)
	GameEvents.health_changed.emit(current_health, max_health)


func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	GameEvents.health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		is_dead = true
		GameEvents.player_died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = minf(max_health, current_health + amount)
	GameEvents.health_changed.emit(current_health, max_health)
