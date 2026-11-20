extends Control
## Menu Principal 3D PS1 de "O Dia Que O Sol Sorriu":
## Diorama 3D em tempo real ao fundo (quarto barricado, feixes solares na janela, foto do Leo, mapa e lampião)
## + tipografia serifada clássica com brilho quente no título e lista pixelada monoespaçada (> INICIAR, CONTINUAR, OPÇÕES, SAIR).

const UiTheme := preload("res://ui/ui_theme.gd")
const FMV_INTRO_SCENE: String = "res://ui/fmv_intro.tscn"
const MAIN_GAME_SCENE: String = "res://levels/main_game.tscn"

const MENU_ITEMS: Array[String] = ["INICIAR", "CONTINUAR", "OPÇÕES", "SAIR"]
const COLOR_ACTIVE_TEXT: Color = Color(1.0, 0.95, 0.84, 1.0)
const COLOR_ACTIVE_GLOW: Color = Color(0.88, 0.48, 0.12, 0.85)
const COLOR_INACTIVE_TEXT: Color = Color(0.45, 0.48, 0.51, 0.90)
const COLOR_INACTIVE_SHADOW: Color = Color(0.03, 0.03, 0.04, 0.92)

var _time: float = 0.0
var _selected_index: int = 0
var _is_transitioning: bool = false
var _play_vhs_intro: bool = true

var _serif_font: SystemFont
var _pixel_font: SystemFont
var _row_buttons: Array[Control] = []
var _row_arrows: Array[Label] = []
var _row_labels: Array[Label] = []

@onready var diorama_container: SubViewportContainer = get_node_or_null("DioramaViewportContainer") as SubViewportContainer
@onready var diorama_3d: Node3D = get_node_or_null("DioramaViewportContainer/SubViewport/MenuDiorama3D") as Node3D
@onready var title_label: Label = get_node_or_null("TitleGroup/TitleLabel") as Label
@onready var title_glow_label: Label = get_node_or_null("TitleGroup/TitleGlowLabel") as Label
@onready var menu_list: VBoxContainer = get_node_or_null("MenuList") as VBoxContainer
@onready var options_panel: PanelContainer = get_node_or_null("OptionsPanel") as PanelContainer
@onready var controls_panel: PanelContainer = get_node_or_null("ControlsPanel") as PanelContainer
@onready var echo_count_label: Label = get_node_or_null("OptionsPanel/VBox/EchoCountLabel") as Label
@onready var volume_label: Label = get_node_or_null("OptionsPanel/VBox/VolumeLabel") as Label
@onready var volume_slider: HSlider = get_node_or_null("OptionsPanel/VBox/VolumeSlider") as HSlider
@onready var sensitivity_slider: HSlider = get_node_or_null("OptionsPanel/VBox/SensitivitySlider") as HSlider
@onready var scale_option: OptionButton = get_node_or_null("OptionsPanel/VBox/ScaleRow/ScaleOption") as OptionButton
@onready var intro_check: CheckBox = get_node_or_null("OptionsPanel/VBox/IntroCheck") as CheckBox
@onready var controls_toggle_btn: Button = get_node_or_null("OptionsPanel/VBox/ButtonsRow/ControlsToggleButton") as Button
@onready var reset_progress_button: Button = get_node_or_null("OptionsPanel/VBox/ButtonsRow/ResetProgressButton") as Button
@onready var close_options_btn: Button = get_node_or_null("OptionsPanel/VBox/CloseOptionsButton") as Button
@onready var close_controls_btn: Button = get_node_or_null("ControlsPanel/VBox/CloseControlsButton") as Button
@onready var fade_black: ColorRect = get_node_or_null("FadeBlack") as ColorRect


func _ready() -> void:
	theme = UiTheme.get_theme()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false

	# Paisagem sonora do menu: vento abafado lá fora + crepitar suave do lampião a óleo na mesa
	AudioManager.stop_all_tension()
	AudioManager.set_wind_active(true)
	AudioManager.play_ambience(AudioManager.get_fire_loop_stream(), -21.0)

	_init_retro_fonts()
	_build_menu_rows()
	_setup_options_controls()
	_refresh_echo_count()
	_apply_diorama_scale()
	_update_menu_visuals()

	if fade_black != null:
		fade_black.color = Color(0.0, 0.0, 0.0, 0.88)
		var tw: Tween = create_tween()
		tw.tween_property(fade_black, "color:a", 0.0, 0.45)


func _exit_tree() -> void:
	_row_buttons.clear()
	_row_arrows.clear()
	_row_labels.clear()
	_serif_font = null
	_pixel_font = null


func _init_retro_fonts() -> void:
	_serif_font = SystemFont.new()
	_serif_font.font_names = PackedStringArray(["Georgia", "Times New Roman", "Palatino Linotype", "Serif"])
	_serif_font.font_weight = 700

	_pixel_font = SystemFont.new()
	_pixel_font.font_names = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "Monospace"])
	_pixel_font.font_weight = 700
	_pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_pixel_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED

	if title_label != null:
		title_label.add_theme_font_override("font", _serif_font)
	if title_glow_label != null:
		title_glow_label.add_theme_font_override("font", _serif_font)


func _build_menu_rows() -> void:
	if menu_list == null:
		return
	for ch: Node in menu_list.get_children():
		ch.queue_free()
	_row_buttons.clear()
	_row_arrows.clear()
	_row_labels.clear()

	for idx: int in range(MENU_ITEMS.size()):
		var row: Control = Control.new()
		row.name = "MenuRow_%d" % idx
		row.custom_minimum_size = Vector2(360.0, 48.0)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		menu_list.add_child(row)

		var arrow_lbl: Label = Label.new()
		arrow_lbl.name = "Arrow"
		arrow_lbl.text = ">"
		arrow_lbl.position = Vector2(0.0, 0.0)
		arrow_lbl.size = Vector2(36.0, 48.0)
		arrow_lbl.add_theme_font_override("font", _pixel_font)
		arrow_lbl.add_theme_font_size_override("font_size", 38)
		arrow_lbl.add_theme_constant_override("outline_size", 6)
		arrow_lbl.add_theme_constant_override("shadow_offset_x", 2)
		arrow_lbl.add_theme_constant_override("shadow_offset_y", 2)
		arrow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(arrow_lbl)

		var item_lbl: Label = Label.new()
		item_lbl.name = "Text"
		item_lbl.text = MENU_ITEMS[idx]
		item_lbl.position = Vector2(42.0, 0.0)
		item_lbl.size = Vector2(318.0, 48.0)
		item_lbl.add_theme_font_override("font", _pixel_font)
		item_lbl.add_theme_font_size_override("font_size", 38)
		item_lbl.add_theme_constant_override("outline_size", 6)
		item_lbl.add_theme_constant_override("shadow_offset_x", 2)
		item_lbl.add_theme_constant_override("shadow_offset_y", 2)
		item_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(item_lbl)

		var captured_idx: int = idx
		row.mouse_entered.connect(func() -> void:
			_on_row_hovered(captured_idx)
		)
		row.gui_input.connect(func(ev: InputEvent) -> void:
			_on_row_gui_input(ev, captured_idx)
		)

		_row_buttons.append(row)
		_row_arrows.append(arrow_lbl)
		_row_labels.append(item_lbl)


func _process(delta: float) -> void:
	_time += delta
	var glow_pulse: float = 0.88 + 0.12 * sin(_time * 2.6)
	if title_glow_label != null:
		title_glow_label.modulate.a = 0.78 + 0.22 * sin(_time * 1.9)
	if _selected_index >= 0 and _selected_index < _row_arrows.size():
		var active_arrow: Label = _row_arrows[_selected_index]
		if active_arrow != null:
			active_arrow.position.x = sin(_time * 5.2) * 2.5
			active_arrow.modulate = Color(1.0, 1.0, 1.0, glow_pulse)


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if controls_panel != null and controls_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_controls_panel()
			get_viewport().set_input_as_handled()
		return

	if options_panel != null and options_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_options_panel()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_W):
		_set_selected_index((_selected_index - 1 + MENU_ITEMS.size()) % MENU_ITEMS.size(), true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_S):
		_set_selected_index((_selected_index + 1) % MENU_ITEMS.size(), true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and ((event as InputEventKey).physical_keycode == KEY_ENTER or (event as InputEventKey).physical_keycode == KEY_SPACE)):
		_activate_menu_item(_selected_index)
		get_viewport().set_input_as_handled()


func _on_row_hovered(idx: int) -> void:
	if _is_transitioning or (options_panel != null and options_panel.visible) or (controls_panel != null and controls_panel.visible):
		return
	_set_selected_index(idx, true)


func _on_row_gui_input(event: InputEvent, idx: int) -> void:
	if _is_transitioning or (options_panel != null and options_panel.visible) or (controls_panel != null and controls_panel.visible):
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_set_selected_index(idx, false)
			_activate_menu_item(idx)
			get_viewport().set_input_as_handled()


func _set_selected_index(next_idx: int, play_sound: bool) -> void:
	var clamped: int = clampi(next_idx, 0, MENU_ITEMS.size() - 1)
	if clamped != _selected_index:
		_selected_index = clamped
		if play_sound:
			AudioManager.play_menu_hover()
	_update_menu_visuals()


func _update_menu_visuals() -> void:
	for i: int in range(_row_labels.size()):
		var is_sel: bool = (i == _selected_index)
		var arr: Label = _row_arrows[i]
		var lbl: Label = _row_labels[i]
		if arr != null:
			arr.visible = is_sel
			arr.add_theme_color_override("font_color", COLOR_ACTIVE_TEXT)
			arr.add_theme_color_override("font_shadow_color", COLOR_ACTIVE_GLOW)
			arr.add_theme_color_override("font_outline_color", Color(0.24, 0.11, 0.02, 0.92))
		if lbl != null:
			if is_sel:
				lbl.add_theme_color_override("font_color", COLOR_ACTIVE_TEXT)
				lbl.add_theme_color_override("font_shadow_color", COLOR_ACTIVE_GLOW)
				lbl.add_theme_color_override("font_outline_color", Color(0.24, 0.11, 0.02, 0.92))
			else:
				lbl.add_theme_color_override("font_color", COLOR_INACTIVE_TEXT)
				lbl.add_theme_color_override("font_shadow_color", COLOR_INACTIVE_SHADOW)
				lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.06, 0.94))


func _activate_menu_item(idx: int) -> void:
	match idx:
		0: # INICIAR
			_start_new_game()
		1: # CONTINUAR
			_continue_game()
		2: # OPÇÕES
			_open_options_panel()
		3: # SAIR
			_quit_game()


func _start_new_game() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	AudioManager.play_menu_confirm()
	AudioManager.play_lantern_ignite()
	SaveManager.clear_checkpoint()
	var target_scene: String = FMV_INTRO_SCENE if _play_vhs_intro else MAIN_GAME_SCENE
	_transition_to_scene(target_scene)


func _continue_game() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	AudioManager.play_menu_confirm()
	AudioManager.play_door_creak()
	_transition_to_scene(MAIN_GAME_SCENE)


func _transition_to_scene(scene_path: String) -> void:
	if diorama_3d != null and diorama_3d.has_method("trigger_start_zoom"):
		diorama_3d.call("trigger_start_zoom")
	if fade_black != null:
		var tw: Tween = create_tween()
		tw.tween_property(fade_black, "color:a", 1.0, 0.36)
		tw.tween_callback(func() -> void:
			AudioManager.stop_ambience()
			get_tree().change_scene_to_file(scene_path)
		)
	else:
		AudioManager.stop_ambience()
		get_tree().change_scene_to_file(scene_path)


func _open_options_panel() -> void:
	AudioManager.play_menu_confirm()
	AudioManager.play_paper()
	_refresh_echo_count()
	if controls_panel != null:
		controls_panel.visible = false
	if options_panel != null:
		options_panel.visible = true


func _close_options_panel() -> void:
	AudioManager.play_menu_back()
	if options_panel != null:
		options_panel.visible = false


func _open_controls_panel() -> void:
	AudioManager.play_menu_hover()
	AudioManager.play_paper()
	if options_panel != null:
		options_panel.visible = false
	if controls_panel != null:
		controls_panel.visible = true


func _close_controls_panel() -> void:
	AudioManager.play_menu_back()
	if controls_panel != null:
		controls_panel.visible = false
	if options_panel != null:
		options_panel.visible = true


func _quit_game() -> void:
	AudioManager.play_menu_back()
	AudioManager.stop_ambience()
	get_tree().quit()


func _setup_options_controls() -> void:
	if options_panel != null:
		options_panel.visible = false
	if controls_panel != null:
		controls_panel.visible = false

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
		scale_option.add_item("3x (Clássico PS1)", 3)
		scale_option.add_item("4x (PS1 Autêntico)", 4)
		var sel_idx: int = clampi(SaveManager.psx_scale - 2, 0, 2)
		scale_option.select(sel_idx)
		scale_option.item_selected.connect(_on_scale_selected)
	if intro_check != null:
		intro_check.button_pressed = _play_vhs_intro
		intro_check.toggled.connect(func(pressed: bool) -> void:
			_play_vhs_intro = pressed
			AudioManager.play_menu_hover()
		)
	if controls_toggle_btn != null:
		controls_toggle_btn.pressed.connect(_open_controls_panel)
	if reset_progress_button != null:
		reset_progress_button.pressed.connect(_on_reset_progress_pressed)
	if close_options_btn != null:
		close_options_btn.pressed.connect(_close_options_panel)
	if close_controls_btn != null:
		close_controls_btn.pressed.connect(_close_controls_panel)


func _apply_diorama_scale() -> void:
	if diorama_container != null:
		diorama_container.stretch_shrink = clampi(SaveManager.psx_scale, 2, 4)


func _refresh_echo_count() -> void:
	if echo_count_label != null:
		echo_count_label.text = "Ecos Descobertos: %d / 17" % SaveManager.get_collected_count()


func _update_volume_label(val: float) -> void:
	if volume_label != null:
		volume_label.text = "Volume Geral: %d%%" % int(roundf(val * 100.0))


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
	_apply_diorama_scale()
	AudioManager.play_menu_hover()


func _on_reset_progress_pressed() -> void:
	SaveManager.reset_progress()
	_refresh_echo_count()
	AudioManager.play_menu_back()
