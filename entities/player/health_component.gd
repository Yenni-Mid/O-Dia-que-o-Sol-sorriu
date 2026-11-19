class_name HealthComponent
extends Node
## Gerencia a integridade física do jogador e dano letal (Sombras Vivas / Lunáticos).

const HURT_SFX_COOLDOWN_MS: int = 450

@export var max_health: float = 100.0

var current_health: float = 100.0
var is_dead: bool = false
var _last_hurt_sfx_ms: int = -10000


func _ready() -> void:
	current_health = clampf(current_health, 0.0, max_health)
	GameEvents.health_changed.emit(current_health, max_health)


func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	GameEvents.health_changed.emit(current_health, max_health)
	GameEvents.player_damaged.emit(amount)

	# Golpes fortes (Lunáticos) sempre tocam som e tremem a câmera; dano contínuo das sombras é espaçado.
	var now_ms: int = Time.get_ticks_msec()
	if amount >= 5.0 or now_ms - _last_hurt_sfx_ms >= HURT_SFX_COOLDOWN_MS * 2:
		_last_hurt_sfx_ms = now_ms
		AudioManager.play_hurt()
		GameEvents.camera_shake_requested.emit(clampf(amount / 30.0, 0.15, 0.9))

	if current_health <= 0.0:
		is_dead = true
		GameEvents.player_died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = minf(max_health, current_health + amount)
	GameEvents.health_changed.emit(current_health, max_health)
