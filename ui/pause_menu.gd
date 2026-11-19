class_name PauseMenu
extends Control
## Menu de Pausa (Esc), ajuste de sensibilidade e telas de Game Over / Reinício.

const UiTheme := preload("res://ui/ui_theme.gd")
const MAIN_MENU_SCENE: String = "res://ui/main_menu.tscn"

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
	theme = UiTheme.get_theme()
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", 28)
		title_label.add_theme_color_override("font_color", UiTheme.AMBER)
	if subtitle_label != null:
		subtitle_label.add_theme_font_size_override("font_size", 13)
	GameEvents.player_died.connect(_on_player_died)
	GameEvents.sanity_depleted.connect(_on_sanity_depleted)
	if resume_button != null:
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button != null:
		restart_button.pressed.connect(_on_restart_pressed)
	if quit_button != null:
		quit_button.text = "Voltar ao Menu Principal"
		quit_button.pressed.connect(_on_quit_pressed)
	if sensitivity_slider != null:
		sensitivity_slider.value = SaveManager.mouse_sensitivity
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)


func _unhandled_input(event: InputEvent) -> void:
	if _is_game_over:
		return
	if event.is_action_pressed("ui_cancel"):
		for modal_name: String in ["EchoReaderUI", "FieldJournalUI", "VHSTapeOverlay"]:
			var modal: Control = get_parent().get_node_or_null(modal_name) as Control
			if modal != null and modal.visible:
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
	var first_button: Button = resume_button if allow_resume else restart_button
	if first_button != null:
		first_button.grab_focus()


func _close_menu() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	AudioManager.play_ui_click()
	if not _is_game_over:
		_close_menu()


func _on_restart_pressed() -> void:
	AudioManager.play_ui_click()
	get_tree().paused = false
	_is_game_over = false
	AudioManager.stop_all_tension()
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	AudioManager.play_ui_click()
	get_tree().paused = false
	AudioManager.stop_all_tension()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_sensitivity_changed(new_value: float) -> void:
	SaveManager.mouse_sensitivity = new_value
	SaveManager.save_settings()
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
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
