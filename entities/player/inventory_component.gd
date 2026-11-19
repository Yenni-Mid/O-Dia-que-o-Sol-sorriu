extends Node
## Inventário tático do jogador: garrafas de distração, bandagens curativas e chaves de portas trancadas.

@export var max_bottles: int = 4
@export var max_bandages: int = 3

var bottles: int = 1
var bandages: int = 1
var keys: Array[String] = []


func _ready() -> void:
	add_to_group("inventory")
	call_deferred("emit_state")


func add_bottle() -> bool:
	if bottles >= max_bottles:
		return false
	bottles += 1
	emit_state()
	return true


func consume_bottle() -> bool:
	if bottles <= 0:
		return false
	bottles -= 1
	emit_state()
	return true


func add_bandage() -> bool:
	if bandages >= max_bandages:
		return false
	bandages += 1
	emit_state()
	return true


func consume_bandage() -> bool:
	if bandages <= 0:
		return false
	bandages -= 1
	emit_state()
	return true


func add_key(key_id: String) -> void:
	if key_id.is_empty() or keys.has(key_id):
		return
	keys.append(key_id)
	emit_state()


func has_key(key_id: String) -> bool:
	return keys.has(key_id)


func get_bottles() -> int:
	return bottles


func get_bandages() -> int:
	return bandages


func get_keys() -> Array[String]:
	return keys.duplicate()


func emit_state() -> void:
	GameEvents.inventory_changed.emit(bottles, bandages, keys.duplicate())
