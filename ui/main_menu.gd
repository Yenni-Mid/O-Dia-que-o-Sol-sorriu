extends Control
## Menu Principal retrô PS1/VHS de "O Dia Que O Sol Sorriu".

const UiTheme := preload("res://ui/ui_theme.gd")
const FMV_INTRO_SCENE: String = "res://ui/fmv_intro.tscn"
const MAIN_GAME_SCENE: String = "res://levels/main_game.tscn"

var _time: float = 0.0
var _flicker_timer: float = 2.0

@onready var title_label: Label = get_node_or_null("MenuContainer/TitleLabel") as Label
@onready var echo_count_label: Label = get_node_or_null("MenuContainer/EchoCountLabel") as Label
@onready var new_game_button: Button = get_node_or_null("MenuContainer/ButtonList/NewGameButton") as Button
@onready var direct_demo_button: Button = get_node_or_null("MenuContainer/ButtonList/DirectDemoButton") as Button
@onready var controls_button: Button = get_node_or_null("MenuContainer/ButtonList/ControlsButton") as Button
@onready var options_button: Button = get_node_or_null("MenuContainer/ButtonList/OptionsButton") as Button
@onready var quit_button: Button = get_node_or_null("MenuContainer/ButtonList/QuitButton") as Button
@onready var controls_panel: PanelContainer = get_node_or_null("ControlsPanel") as PanelContainer
@onready var options_panel: PanelContainer = get_node_or_null("OptionsPanel") as PanelContainer
@onready var volume_label: Label = get_node_or_null("OptionsPanel/VBox/VolumeLabel") as Label
@onready var volume_slider: HSlider = get_node_or_null("OptionsPanel/VBox/VolumeSlider") as HSlider
@onready var sensitivity_slider: HSlider = get_node_or_null("OptionsPanel/VBox/SensitivitySlider") as HSlider
@onready var scale_option: OptionButton = get_node_or_null("OptionsPanel/VBox/ScaleRow/ScaleOption") as OptionButton
@onready var reset_progress_button: Button = get_node_or_null("OptionsPanel/VBox/ResetProgressButton") as Button
@onready var sun_emblem: TextureRect = get_node_or_null("SunEmblem") as TextureRect


func _ready() -> void:
	theme = UiTheme.get_theme()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	AudioManager.stop_all_tension()
	AudioManager.set_wind_active(true)

	if controls_panel != null:
		controls_panel.visible = false
	if options_panel != null:
		options_panel.visible = false
	_refresh_echo_count()
	_setup_options_controls()

	if sun_emblem != null:
		sun_emblem.texture = _build_sun_emblem_texture()
		sun_emblem.pivot_offset = sun_emblem.size * 0.5

	for btn: Button in [new_game_button, direct_demo_button, controls_button, options_button, quit_button]:
		if btn != null:
			btn.mouse_entered.connect(AudioManager.play_ui_click)
			btn.focus_entered.connect(AudioManager.play_ui_click)

	if new_game_button != null:
		new_game_button.pressed.connect(_on_new_game_pressed)
		new_game_button.grab_focus()
	if direct_demo_button != null:
		direct_demo_button.pressed.connect(_on_direct_demo_pressed)
	if controls_button != null:
		controls_button.pressed.connect(_on_controls_pressed)
	if options_button != null:
		options_button.pressed.connect(_on_options_pressed)
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)


func _process(delta: float) -> void:
	_time += delta
	if sun_emblem != null:
		var breath: float = 1.0 + sin(_time * 0.7) * 0.035
		sun_emblem.scale = Vector2(breath, breath)
		sun_emblem.rotation = sin(_time * 0.31) * 0.05
		sun_emblem.pivot_offset = sun_emblem.size * 0.5
	if title_label != null:
		_flicker_timer -= delta
		if _flicker_timer <= 0.0:
			_flicker_timer = randf_range(1.5, 4.5)
			title_label.modulate.a = 0.35
		title_label.modulate.a = move_toward(title_label.modulate.a, 1.0, delta * 3.0)


func _setup_options_controls() -> void:
	if volume_slider != null:
		volume_slider.value = SaveManager.master_volume
		_update_volume_label(SaveManager.master_volume)
		volume_slider.value_changed.connect(_on_volume_changed)
	if sensitivity_slider != null:
		sensitivity_slider.value = SaveManager.mouse_sensitivity
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	if scale_option != null:
		scale_option.clear()
		scale_option.add_item("2x (Nítido)", 2)
		scale_option.add_item("3x (Clássico)", 3)
		scale_option.add_item("4x (PS1 Autêntico)", 4)
		var sel_idx: int = clampi(SaveManager.psx_scale - 2, 0, 2)
		scale_option.select(sel_idx)
		scale_option.item_selected.connect(_on_scale_selected)
	if reset_progress_button != null:
		reset_progress_button.pressed.connect(_on_reset_progress_pressed)


func _refresh_echo_count() -> void:
	if echo_count_label != null:
		echo_count_label.text = "Ecos Descobertos: %d" % SaveManager.get_collected_count()


func _update_volume_label(val: float) -> void:
	if volume_label != null:
		volume_label.text = "Volume Geral: %d%%" % int(roundf(val * 100.0))


func _on_new_game_pressed() -> void:
	AudioManager.play_lantern_ignite()
	get_tree().change_scene_to_file(FMV_INTRO_SCENE)


func _on_direct_demo_pressed() -> void:
	AudioManager.play_door_creak()
	get_tree().change_scene_to_file(MAIN_GAME_SCENE)


func _on_controls_pressed() -> void:
	AudioManager.play_ui_click()
	if options_panel != null:
		options_panel.visible = false
	if controls_panel != null:
		controls_panel.visible = not controls_panel.visible


func _on_options_pressed() -> void:
	AudioManager.play_ui_click()
	if controls_panel != null:
		controls_panel.visible = false
	if options_panel != null:
		options_panel.visible = not options_panel.visible


func _on_volume_changed(val: float) -> void:
	SaveManager.master_volume = val
	AudioManager.set_master_volume(val)
	_update_volume_label(val)
	SaveManager.save_settings()


func _on_sensitivity_changed(val: float) -> void:
	SaveManager.mouse_sensitivity = val
	SaveManager.save_settings()


func _on_scale_selected(index: int) -> void:
	if scale_option == null:
		return
	var chosen_scale: int = scale_option.get_item_id(index)
	SaveManager.psx_scale = clampi(chosen_scale, 2, 4)
	SaveManager.save_settings()
	AudioManager.play_ui_click()


func _on_reset_progress_pressed() -> void:
	SaveManager.reset_progress()
	_refresh_echo_count()
	AudioManager.play_ui_click()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _build_sun_emblem_texture() -> ImageTexture:
	var size_px: int = 48
	var img: Image = Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	var center: float = float(size_px) * 0.5
	var radius: float = 17.0

	for y: int in range(size_px):
		for x: int in range(size_px):
			var dx: float = float(x) - center
			var dy: float = float(y) - center
			var dist: float = sqrt(dx * dx + dy * dy)
			var col: Color = Color(0.0, 0.0, 0.0, 0.0)
			if dist <= radius + 4.0:
				if dist <= radius:
					col = Color(0.95, 0.80, 0.25, 0.92)
					var left_eye: bool = absf(dx + 5.2) <= 1.8 and absf(dy + 3.5) <= 2.4
					var right_eye: bool = absf(dx - 5.2) <= 2.2 and absf(dy + 2.8) <= 1.8
					var smile_y: float = 5.4 - (dx * dx) * 0.048
					var is_smile: bool = absf(dx) <= 9.5 and absf(dy - smile_y) <= 1.35
					if left_eye or right_eye or is_smile:
						col = Color(0.12, 0.04, 0.03, 1.0)
				else:
					var glow: float = 1.0 - (dist - radius) / 4.0
					col = Color(0.95, 0.72, 0.20, clampf(glow * 0.35, 0.0, 0.35))
			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)
