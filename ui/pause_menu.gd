class_name PauseMenu
extends Control
## Menu de Pausa (Esc), ajuste de sensibilidade e telas de Game Over / Reinício.

var _is_game_over: bool = false

@onready var title_label: Label = get_node_or_null("Panel/VBoxContainer/TitleLabel") as Label
@onready var subtitle_label: Label = get_node_or_null("Panel/VBoxContainer/SubtitleLabel") as Label
@onready var resume_button: Button = get_node_or_null("Panel/VBoxContainer/ResumeButton") as Button
@onready var restart_button: Button = get_node_or_null("Panel/VBoxContainer/RestartButton") as Button
@onready var quit_button: Button = get_node_or_null("Panel/VBoxContainer/QuitButton") as Button
@onready var sensitivity_slider: HSlider = get_node_or_null("Panel/VBoxContainer/SensitivitySlider") as HSlider


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameEvents.player_died.connect(_on_player_died)
	GameEvents.sanity_depleted.connect(_on_sanity_depleted)
	if resume_button != null:
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button != null:
		restart_button.pressed.connect(_on_restart_pressed)
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)
	if sensitivity_slider != null:
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)


func _unhandled_input(event: InputEvent) -> void:
	if _is_game_over:
		return
	if event.is_action_pressed("ui_cancel"):
		var echo_ui: Control = get_parent().get_node_or_null("EchoReaderUI") as Control
		if echo_ui != null and echo_ui.visible:
			return
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if visible:
		_close_menu()
	else:
		_open_menu("PAUSA", "Pressione [ESC] ou Continuar para voltar ao jogo", true)


func _open_menu(title_text: String, subtitle_text: String, allow_resume: bool) -> void:
	if title_label != null:
		title_label.text = title_text
	if subtitle_label != null:
		subtitle_label.text = subtitle_text
	if resume_button != null:
		resume_button.visible = allow_resume
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_menu() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	if not _is_game_over:
		_close_menu()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	_is_game_over = false
	AudioManager.set_sun_drone_active(false)
	AudioManager.set_heartbeat_intensity(0.0)
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_sensitivity_changed(new_value: float) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var players: Array[Node] = scene_root.find_children("*", "PlayerController", true, false)
	for node: Node in players:
		var player: PlayerController = node as PlayerController
		if player != null:
			player.mouse_sensitivity = new_value


func _on_player_died() -> void:
	if _is_game_over:
		return
	_is_game_over = true
	_open_menu("DEVORADO PELAS SOMBRAS", "Sua vida chegou a zero na escuridão.", false)


func _on_sanity_depleted() -> void:
	if _is_game_over:
		return
	_is_game_over = true
	_open_menu("A VERDADE TE CONSUMIU", "A luz do Sol Sorridente destruiu sua sanidade.", false)
