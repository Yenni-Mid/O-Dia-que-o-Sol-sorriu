extends Node
## Gerenciador de salvamento de progresso (Ecos coletados) e preferências (volume, sensibilidade, escala PSX).

const SAVE_FILE_PATH: String = "user://savegame.cfg"

var collected_echoes: Array[String] = []
var collected_echo_records: Dictionary = {}
var unlocked_safes: Array[String] = []
var known_school_code: bool = false
var unlocked_shortcuts: Array[String] = []

var has_checkpoint: bool = false
var checkpoint_position: Vector3 = Vector3.ZERO

var mouse_sensitivity: float = 0.0022
var master_volume: float = 0.85
var psx_scale: int = 4


func _ready() -> void:
	load_game()
	AudioManager.set_master_volume(master_volume)
	GameEvents.echo_opened.connect(_on_echo_opened)


func register_echo(echo_id: String, author: String = "", date_written: String = "", text: String = "") -> void:
	if echo_id.is_empty():
		return
	var changed: bool = false
	if not collected_echoes.has(echo_id):
		collected_echoes.append(echo_id)
		changed = true
	if not author.is_empty() or not text.is_empty():
		collected_echo_records[echo_id] = {
			"author": author,
			"date": date_written,
			"text": text,
		}
		changed = true
	if changed:
		save_game()


func has_echo(echo_id: String) -> bool:
	return collected_echoes.has(echo_id)


func get_collected_count() -> int:
	return collected_echoes.size()


func save_settings() -> void:
	save_game()


func reset_progress() -> void:
	collected_echoes.clear()
	collected_echo_records.clear()
	unlocked_safes.clear()
	known_school_code = false
	unlocked_shortcuts.clear()
	has_checkpoint = false
	checkpoint_position = Vector3.ZERO
	save_game()


func set_checkpoint(pos: Vector3) -> void:
	has_checkpoint = true
	checkpoint_position = pos
	GameEvents.checkpoint_saved.emit(pos)


func clear_checkpoint() -> void:
	has_checkpoint = false
	checkpoint_position = Vector3.ZERO


func mark_safe_unlocked(safe_id: String) -> void:
	if safe_id.is_empty():
		return
	if not unlocked_safes.has(safe_id):
		unlocked_safes.append(safe_id)
		save_game()


func is_safe_unlocked(safe_id: String) -> bool:
	return unlocked_safes.has(safe_id)


func mark_school_code_known() -> void:
	if not known_school_code:
		known_school_code = true
		save_game()


func is_school_code_known() -> bool:
	return (
		known_school_code
		or has_echo("echo_neighbor_09")
		or has_echo("echo_school_lib_11")
		or has_echo("echo_school_office_12")
		or is_safe_unlocked("safe_school")
	)


func mark_shortcut_unlocked(shortcut_id: String) -> void:
	if shortcut_id.is_empty():
		return
	if not unlocked_shortcuts.has(shortcut_id):
		unlocked_shortcuts.append(shortcut_id)
		save_game()


func is_shortcut_unlocked(shortcut_id: String) -> bool:
	return unlocked_shortcuts.has(shortcut_id)


func get_unlocked_shortcuts_count() -> int:
	return unlocked_shortcuts.size()


func save_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("progress", "collected_echoes", collected_echoes)
	config.set_value("progress", "collected_echo_records", collected_echo_records)
	config.set_value("progress", "unlocked_safes", unlocked_safes)
	config.set_value("progress", "known_school_code", known_school_code)
	config.set_value("progress", "unlocked_shortcuts", unlocked_shortcuts)
	config.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("settings", "master_volume", master_volume)
	config.set_value("settings", "psx_scale", psx_scale)
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

	var saved_records: Variant = config.get_value("progress", "collected_echo_records", {})
	if saved_records is Dictionary:
		collected_echo_records = (saved_records as Dictionary).duplicate(true)

	var saved_safes: Variant = config.get_value("progress", "unlocked_safes", [])
	if saved_safes is Array:
		unlocked_safes.clear()
		for safe_item: Variant in saved_safes:
			unlocked_safes.append(str(safe_item))

	known_school_code = bool(config.get_value("progress", "known_school_code", false))

	var saved_shortcuts: Variant = config.get_value("progress", "unlocked_shortcuts", [])
	if saved_shortcuts is Array:
		unlocked_shortcuts.clear()
		for sc_item: Variant in saved_shortcuts:
			unlocked_shortcuts.append(str(sc_item))

	mouse_sensitivity = clampf(float(config.get_value("settings", "mouse_sensitivity", 0.0022)), 0.0005, 0.008)
	master_volume = clampf(float(config.get_value("settings", "master_volume", 0.85)), 0.0, 1.0)
	psx_scale = clampi(int(config.get_value("settings", "psx_scale", 4)), 2, 4)


func _on_echo_opened(data: EchoData) -> void:
	if data != null:
		register_echo(data.echo_id, data.author_name, data.date_written, data.confession_text)
		if data.echo_id == "echo_neighbor_09" or data.echo_id == "echo_school_lib_11" or data.echo_id == "echo_school_office_12":
			mark_school_code_known()
