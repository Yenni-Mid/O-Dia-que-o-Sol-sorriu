extends Node
## Gerenciador de salvamento de progresso e Ecos (diários) coletados.

const SAVE_FILE_PATH: String = "user://savegame.cfg"

var collected_echoes: Array[String] = []


func _ready() -> void:
	GameEvents.echo_opened.connect(_on_echo_opened)


func register_echo(echo_id: String) -> void:
	if echo_id.is_empty() or collected_echoes.has(echo_id):
		return
	collected_echoes.append(echo_id)
	save_game()


func has_echo(echo_id: String) -> bool:
	return collected_echoes.has(echo_id)


func save_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("progress", "collected_echoes", collected_echoes)
	config.save(SAVE_FILE_PATH)


func load_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_FILE_PATH) != OK:
		return
	var saved_list: Variant = config.get_value("progress", "collected_echoes", [])
	if saved_list is Array:
		collected_echoes.clear()
		for item: Variant in saved_list:
			collected_echoes.append(str(item))


func _on_echo_opened(data: EchoData) -> void:
	if data != null:
		register_echo(data.echo_id)
