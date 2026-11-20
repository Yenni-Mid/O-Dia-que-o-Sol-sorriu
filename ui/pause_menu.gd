class_name PauseMenu
extends Control
## Menu de Pausa (Esc), Submenu de Opções ao vivo e Tela Atmosférica de Game Over PS1.

const UiTheme := preload("res://ui/ui_theme.gd")
const MAIN_MENU_SCENE: String = "res://ui/main_menu.tscn"

const COLOR_ACTIVE_TEXT: Color = Color(1.0, 0.95, 0.84, 1.0)
const COLOR_ACTIVE_GLOW: Color = Color(0.88, 0.48, 0.12, 0.85)
const COLOR_INACTIVE_TEXT: Color = Color(0.48, 0.50, 0.53, 0.90)
const COLOR_INACTIVE_SHADOW: Color = Color(0.03, 0.03, 0.04, 0.92)

var _is_game_over: bool = false
var _selected_index: int = 0
var _time: float = 0.0

var _serif_font: SystemFont
var _pixel_font: SystemFont
var _dead_icon_tex: ImageTexture

var _dimmer: ColorRect
var _title_glow: Label
var _title_label: Label
var _subtitle_label: Label
var _stats_label: Label
var _dead_icon_rect: TextureRect
var _menu_list: VBoxContainer
var _options_panel: PanelContainer
var _volume_label: Label
var _volume_slider: HSlider
var _sens_label: Label
var _sens_slider: HSlider
var _scale_option: OptionButton

var _row_actions: Array[String] = []
var _row_controls: Array[Control] = []
var _row_arrows: Array[Label] = []
var _row_labels: Array[Label] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	_init_fonts()
	_dead_icon_tex = _build_extinguished_lantern_icon()
	_build_ui()

	GameEvents.player_died.connect(_on_player_died)
	GameEvents.sanity_depleted.connect(_on_sanity_depleted)


func _exit_tree() -> void:
	_row_actions.clear()
	_row_controls.clear()
	_row_arrows.clear()
	_row_labels.clear()
	if _dead_icon_rect != null:
		_dead_icon_rect.texture = null
	_dead_icon_tex = null
	_serif_font = null
	_pixel_font = null


func _init_fonts() -> void:
	_serif_font = SystemFont.new()
	_serif_font.font_names = PackedStringArray(["Georgia", "Times New Roman", "Palatino Linotype", "Serif"])
	_serif_font.font_weight = 700

	_pixel_font = SystemFont.new()
	_pixel_font.font_names = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "Monospace"])
	_pixel_font.font_weight = 700
	_pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_pixel_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _title_glow != null:
		_title_glow.modulate.a = 0.72 + 0.28 * sin(_time * 2.1)
	if _selected_index >= 0 and _selected_index < _row_arrows.size():
		var arr: Label = _row_arrows[_selected_index]
		if arr != null:
			arr.position.x = sin(_time * 5.2) * 2.5


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if _is_game_over:
			return
		if event.is_action_pressed("ui_cancel"):
			for modal_name: String in ["EchoReaderUI", "FieldJournalUI", "VHSTapeOverlay", "KeypadUI", "DialogueUI", "NightSummaryUI"]:
				var modal: Control = get_parent().get_node_or_null(modal_name) as Control
				if modal != null and modal.visible:
					return
			_open_pause_menu()
			get_viewport().set_input_as_handled()
		return

	if _options_panel != null and _options_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_options_panel()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") and not _is_game_over:
		_close_menu()
		AudioManager.play_menu_back()
		get_viewport().set_input_as_handled()
		return

	if _row_actions.is_empty():
		return

	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_W):
		_set_selected_index((_selected_index - 1 + _row_actions.size()) % _row_actions.size(), true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_S):
		_set_selected_index((_selected_index + 1) % _row_actions.size(), true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and ((event as InputEventKey).physical_keycode == KEY_ENTER or (event as InputEventKey).physical_keycode == KEY_SPACE)):
		_activate_action(_row_actions[_selected_index])
		get_viewport().set_input_as_handled()


func _open_pause_menu() -> void:
	_is_game_over = false
	if _dimmer != null:
		_dimmer.color = Color(0.02, 0.018, 0.015, 0.78)
	if _dead_icon_rect != null:
		_dead_icon_rect.visible = false
	if _options_panel != null:
		_options_panel.visible = false

	_set_titles("PAUSA", "Pressione [ESC] ou escolha uma opção para retomar a vigília.", Color(0.98, 0.88, 0.68), Color(0.88, 0.48, 0.12, 0.85))
	if _stats_label != null:
		_stats_label.text = _format_run_stats()

	var items: Array[Dictionary] = [
		{"label": "CONTINUAR", "action": "resume"},
	]
	if SaveManager.has_checkpoint:
		items.append({"label": "RECARREGAR REFÚGIO", "action": "retry_checkpoint"})
	else:
		items.append({"label": "REINICIAR EXPEDIÇÃO", "action": "restart_fresh"})
	items.append({"label": "OPÇÕES", "action": "options"})
	items.append({"label": "MENU PRINCIPAL", "action": "main_menu"})

	_populate_rows(items)
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_paper()


func _open_game_over(title_txt: String, subtitle_txt: String) -> void:
	if _is_game_over:
		return
	_is_game_over = true
	AudioManager.stop_all_tension()
	AudioManager.play_lantern_extinguish()

	if _dimmer != null:
		_dimmer.color = Color(0.06, 0.012, 0.012, 0.86)
	if _dead_icon_rect != null:
		_dead_icon_rect.visible = true
	if _options_panel != null:
		_options_panel.visible = false

	_set_titles(title_txt, subtitle_txt, Color(0.96, 0.36, 0.28), Color(0.58, 0.06, 0.04, 0.90))
	if _stats_label != null:
		_stats_label.text = _format_run_stats()

	var items: Array[Dictionary] = []
	if SaveManager.has_checkpoint:
		items.append({"label": "TENTAR DO ÚLTIMO REFÚGIO", "action": "retry_checkpoint"})
		items.append({"label": "RECOMEÇAR DO INÍCIO", "action": "restart_fresh"})
	else:
		items.append({"label": "RECOMEÇAR EXPEDIÇÃO", "action": "restart_fresh"})
	items.append({"label": "MENU PRINCIPAL", "action": "main_menu"})

	_populate_rows(items)
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_menu() -> void:
	visible = false
	if _options_panel != null:
		_options_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_titles(main_t: String, sub_t: String, col: Color, glow_col: Color) -> void:
	if _title_label != null:
		_title_label.text = main_t
		_title_label.add_theme_color_override("font_color", col)
	if _title_glow != null:
		_title_glow.text = main_t
		_title_glow.add_theme_color_override("font_color", glow_col)
	if _subtitle_label != null:
		_subtitle_label.text = sub_t


func _format_run_stats() -> String:
	var night_num: int = 1
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn != null and dn.has_method("get_night_number"):
		night_num = int(dn.call("get_night_number"))
	var echoes_total: int = maxi(1, get_tree().get_nodes_in_group("echo_note").size())
	var shortcuts_cnt: int = SaveManager.get_unlocked_shortcuts_count()
	return "NOITE %d  •  ECOS COLETADOS: %d / %d  •  ATALHOS: %d / 2" % [
		night_num,
		SaveManager.get_collected_count(),
		echoes_total,
		shortcuts_cnt,
	]


func _populate_rows(items: Array[Dictionary]) -> void:
	if _menu_list == null:
		return
	for c: Node in _menu_list.get_children():
		c.queue_free()
	_row_actions.clear()
	_row_controls.clear()
	_row_arrows.clear()
	_row_labels.clear()

	for i: int in range(items.size()):
		var entry: Dictionary = items[i]
		var lbl_txt: String = str(entry.get("label", ""))
		var action_id: String = str(entry.get("action", ""))

		var row: Control = Control.new()
		row.custom_minimum_size = Vector2(460.0, 38.0)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_menu_list.add_child(row)

		var arr: Label = Label.new()
		arr.text = ">"
		arr.position = Vector2(0.0, 0.0)
		arr.size = Vector2(30.0, 38.0)
		arr.add_theme_font_override("font", _pixel_font)
		arr.add_theme_font_size_override("font_size", 26)
		arr.add_theme_constant_override("outline_size", 5)
		arr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(arr)

		var txt: Label = Label.new()
		txt.text = lbl_txt
		txt.position = Vector2(34.0, 0.0)
		txt.size = Vector2(420.0, 38.0)
		txt.add_theme_font_override("font", _pixel_font)
		txt.add_theme_font_size_override("font_size", 26)
		txt.add_theme_constant_override("outline_size", 5)
		txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(txt)

		var captured_idx: int = i
		var cb_hover: Callable = func() -> void:
			_on_row_hovered(captured_idx)
		var cb_input: Callable = func(ev: InputEvent) -> void:
			_on_row_gui_input(ev, captured_idx)
		row.mouse_entered.connect(cb_hover)
		row.gui_input.connect(cb_input)

		_row_actions.append(action_id)
		_row_controls.append(row)
		_row_arrows.append(arr)
		_row_labels.append(txt)

	_selected_index = 0
	_update_row_visuals()


func _on_row_hovered(idx: int) -> void:
	if _options_panel != null and _options_panel.visible:
		return
	_set_selected_index(idx, true)


func _on_row_gui_input(event: InputEvent, idx: int) -> void:
	if _options_panel != null and _options_panel.visible:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_set_selected_index(idx, false)
			if idx >= 0 and idx < _row_actions.size():
				_activate_action(_row_actions[idx])
			get_viewport().set_input_as_handled()


func _set_selected_index(idx: int, play_sfx: bool) -> void:
	if _row_actions.is_empty():
		return
	var clamped: int = clampi(idx, 0, _row_actions.size() - 1)
	if clamped != _selected_index:
		_selected_index = clamped
		if play_sfx:
			AudioManager.play_menu_hover()
	_update_row_visuals()


func _update_row_visuals() -> void:
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


func _activate_action(action_id: String) -> void:
	match action_id:
		"resume":
			AudioManager.play_menu_confirm()
			if not _is_game_over:
				_close_menu()
		"retry_checkpoint":
			AudioManager.play_menu_confirm()
			get_tree().paused = false
			_is_game_over = false
			AudioManager.stop_all_tension()
			get_tree().reload_current_scene()
		"restart_fresh":
			AudioManager.play_menu_confirm()
			SaveManager.clear_checkpoint()
			get_tree().paused = false
			_is_game_over = false
			AudioManager.stop_all_tension()
			get_tree().reload_current_scene()
		"options":
			_open_options_panel()
		"main_menu":
			AudioManager.play_menu_back()
			get_tree().paused = false
			_is_game_over = false
			SaveManager.clear_checkpoint()
			AudioManager.stop_all_tension()
			get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _open_options_panel() -> void:
	AudioManager.play_menu_confirm()
	AudioManager.play_paper()
	_sync_options_values()
	if _options_panel != null:
		_options_panel.visible = true
	if _menu_list != null:
		_menu_list.visible = false


func _close_options_panel() -> void:
	AudioManager.play_menu_back()
	if _options_panel != null:
		_options_panel.visible = false
	if _menu_list != null:
		_menu_list.visible = true


func _sync_options_values() -> void:
	if _volume_slider != null:
		_volume_slider.set_value_no_signal(SaveManager.master_volume)
		if _volume_label != null:
			_volume_label.text = "Volume Geral: %d%%" % int(roundf(SaveManager.master_volume * 100.0))
	if _sens_slider != null:
		_sens_slider.set_value_no_signal(SaveManager.mouse_sensitivity)
		if _sens_label != null:
			_sens_label.text = "Sensibilidade do Mouse: %.4f" % SaveManager.mouse_sensitivity
	if _scale_option != null:
		_scale_option.select(clampi(SaveManager.psx_scale - 2, 0, 2))


func _on_volume_changed(val: float) -> void:
	SaveManager.master_volume = val
	AudioManager.set_master_volume(val)
	if _volume_label != null:
		_volume_label.text = "Volume Geral: %d%%" % int(roundf(val * 100.0))
	SaveManager.save_settings()


func _on_sensitivity_changed(new_value: float) -> void:
	SaveManager.mouse_sensitivity = new_value
	SaveManager.save_settings()
	if _sens_label != null:
		_sens_label.text = "Sensibilidade do Mouse: %.4f" % new_value
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if player != null:
		player.mouse_sensitivity = new_value


func _on_scale_selected(index: int) -> void:
	if _scale_option == null:
		return
	var chosen_scale: int = clampi(_scale_option.get_item_id(index), 2, 4)
	SaveManager.psx_scale = chosen_scale
	SaveManager.save_settings()
	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		var container: SubViewportContainer = scene_root.get_node_or_null("SubViewportContainer") as SubViewportContainer
		if container != null:
			container.stretch_shrink = chosen_scale
		var fx: ColorRect = scene_root.get_node_or_null("CanvasLayer_UI/PSXPostProcess") as ColorRect
		if fx != null and fx.material is ShaderMaterial:
			(fx.material as ShaderMaterial).set_shader_parameter("pixel_scale", float(chosen_scale))
	AudioManager.play_menu_hover()


func _on_player_died() -> void:
	_open_game_over("A CHAMA SE APAGOU", "Sua vida chegou a zero nas sombras do quarteirão.")


func _on_sanity_depleted() -> void:
	_open_game_over("O SOL SORRIU PARA VOCÊ", "A luz do Sol Sorridente despedaçou sua sanidade.")


func _build_ui() -> void:
	_dimmer = ColorRect.new()
	_dimmer.name = "Dimmer"
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmer.color = Color(0.02, 0.018, 0.015, 0.78)
	add_child(_dimmer)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.custom_minimum_size = Vector2(560.0, 0.0)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 10)
	center.add_child(main_vbox)

	_dead_icon_rect = TextureRect.new()
	_dead_icon_rect.custom_minimum_size = Vector2(64.0, 64.0)
	_dead_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dead_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dead_icon_rect.texture = _dead_icon_tex
	_dead_icon_rect.visible = false
	main_vbox.add_child(_dead_icon_rect)

	var title_box: Control = Control.new()
	title_box.custom_minimum_size = Vector2(560.0, 58.0)
	main_vbox.add_child(title_box)

	_title_glow = Label.new()
	_title_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_glow.offset_left = 2.0
	_title_glow.offset_top = 2.0
	_title_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_glow.add_theme_font_override("font", _serif_font)
	_title_glow.add_theme_font_size_override("font_size", 40)
	title_box.add_child(_title_glow)

	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_override("font", _serif_font)
	_title_label.add_theme_font_size_override("font_size", 40)
	_title_label.add_theme_constant_override("outline_size", 6)
	_title_label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.96))
	title_box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 14)
	_subtitle_label.add_theme_color_override("font_color", Color(0.84, 0.80, 0.72))
	main_vbox.add_child(_subtitle_label)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_override("font", _pixel_font)
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.add_theme_color_override("font_color", UiTheme.AMBER)
	main_vbox.add_child(_stats_label)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 12.0)
	main_vbox.add_child(spacer)

	_menu_list = VBoxContainer.new()
	_menu_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_menu_list.add_theme_constant_override("separation", 6)
	main_vbox.add_child(_menu_list)

	# Subpainel de Opções
	_options_panel = PanelContainer.new()
	_options_panel.visible = false
	_options_panel.custom_minimum_size = Vector2(460.0, 0.0)
	_options_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var opt_style: StyleBoxFlat = UiTheme.make_box(Color(0.045, 0.04, 0.035, 0.96), UiTheme.AMBER, 2, 16)
	_options_panel.add_theme_stylebox_override("panel", opt_style)
	main_vbox.add_child(_options_panel)

	var opt_vbox: VBoxContainer = VBoxContainer.new()
	opt_vbox.add_theme_constant_override("separation", 10)
	_options_panel.add_child(opt_vbox)

	var opt_head: Label = Label.new()
	opt_head.text = "OPÇÕES"
	opt_head.add_theme_font_override("font", _pixel_font)
	opt_head.add_theme_font_size_override("font_size", 20)
	opt_head.add_theme_color_override("font_color", UiTheme.AMBER)
	opt_vbox.add_child(opt_head)

	_volume_label = Label.new()
	opt_vbox.add_child(_volume_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.02
	_volume_slider.value_changed.connect(_on_volume_changed)
	opt_vbox.add_child(_volume_slider)

	_sens_label = Label.new()
	opt_vbox.add_child(_sens_label)

	_sens_slider = HSlider.new()
	_sens_slider.min_value = 0.0008
	_sens_slider.max_value = 0.006
	_sens_slider.step = 0.0002
	_sens_slider.value_changed.connect(_on_sensitivity_changed)
	opt_vbox.add_child(_sens_slider)

	var scale_row: HBoxContainer = HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 10)
	opt_vbox.add_child(scale_row)

	var scale_lbl: Label = Label.new()
	scale_lbl.text = "Resolução PS1:"
	scale_row.add_child(scale_lbl)

	_scale_option = OptionButton.new()
	_scale_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_option.add_item("2x (Nítido)", 2)
	_scale_option.add_item("3x (Clássico PS1)", 3)
	_scale_option.add_item("4x (PS1 Autêntico)", 4)
	_scale_option.item_selected.connect(_on_scale_selected)
	scale_row.add_child(_scale_option)

	var back_btn: Button = Button.new()
	back_btn.text = "Voltar [ESC]"
	back_btn.pressed.connect(_close_options_panel)
	opt_vbox.add_child(back_btn)


func _build_extinguished_lantern_icon() -> ImageTexture:
	var img: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for y: int in range(48):
		for x: int in range(48):
			var c: Color = Color(0, 0, 0, 0)
			# Fiozinho de fumaça subindo do lampião apagado
			if y >= 4 and y <= 13:
				var sx: float = 24.0 + sin(float(y) * 0.55) * 3.0
				if absf(float(x) - sx) <= 1.2:
					var fade: float = clampf(float(y) / 14.0, 0.25, 0.78)
					c = Color(0.56, 0.54, 0.52, fade)
			# Chapéu / chaminé do lampião
			if y >= 14 and y <= 17 and absi(x - 24) <= (4 + (y - 14) * 2):
				c = Color(0.24, 0.20, 0.16, 1.0)
			# Vidro vazio escuro + hastes
			if y >= 18 and y <= 33 and absi(x - 24) <= 9:
				if absi(x - 24) >= 7 or x == 24:
					c = Color(0.26, 0.22, 0.18, 1.0)
				else:
					c = Color(0.08, 0.08, 0.10, 0.85)
				if y == 29 and absi(x - 24) <= 2:
					c = Color(0.76, 0.26, 0.08, 0.90) # brasa morrendo
			# Tanque base
			if y >= 34 and y <= 41 and absi(x - 24) <= 11:
				c = Color(0.32, 0.22, 0.14, 1.0) if (y < 40) else Color(0.18, 0.14, 0.10, 1.0)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
