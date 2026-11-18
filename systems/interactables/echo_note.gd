class_name EchoNote
extends Area3D
## Diário "Eco" deixado nas sombras por sobreviventes (Layer 4).

const LAYER_INTERACTABLES: int = 1 << 3 # Layer 4

@export var echo_data: EchoData
@export var fallback_id: String = "echo_01"
@export var fallback_author: String = "Sobrevivente Anônimo"
@export var fallback_date: String = "Dia 14 após o Sorriso"
@export_multiline var fallback_text: String = "Não olhe para cima quando o céu ficar amarelo. A luz faz você confessar tudo o que escondeu a vida inteira. Mantenha o lampião aceso nas sombras."


func _ready() -> void:
	collision_layer = LAYER_INTERACTABLES
	collision_mask = 0
	monitorable = true
	monitoring = false
	if echo_data == null:
		echo_data = EchoData.new()
		echo_data.echo_id = fallback_id
		echo_data.author_name = fallback_author
		echo_data.date_written = fallback_date
		echo_data.confession_text = fallback_text


func interact() -> void:
	if echo_data != null:
		GameEvents.echo_opened.emit(echo_data)


func get_interaction_prompt() -> String:
	if echo_data != null and not echo_data.author_name.is_empty():
		return "[E] Ler Eco: %s" % echo_data.author_name
	return "[E] Ler Eco"
