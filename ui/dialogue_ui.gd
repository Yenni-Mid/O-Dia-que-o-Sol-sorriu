class_name DialogueUI
extends Control
## Interface de Diálogo estilo survival horror PS1:
## Retrato pixel-art à esquerda, caixa carvão/pergaminho acima da HUD,
## efeito máquina de escrever com blip vocal do personagem, múltiplas páginas e escolhas [1-3].

const UiTheme := preload("res://ui/ui_theme.gd")
const CHARS_PER_SECOND: float = 48.0

var _pages: Array[String] = []
var _page_index: int = 0
var _choices: Array[Dictionary] = []
var _speaker_pitch: float = 1.0
var _typed_chars: float = 0.0
var _total_chars: int = 0
var _typing: bool = false
var _hint_pulse: float = 0.0
var _dialogue_generation: int = 0
var _portraits: Dictionary = {}
var _choice_buttons: Array[Button] = []

var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _portrait_rect: TextureRect
var _name_label: Label
var _role_label: Label
var _page_label: Label
var _body_label: Label
var _choices_box: VBoxContainer
var _hint_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	_build_ui()
	GameEvents.dialogue_requested.connect(_on_dialogue_requested)


func _exit_tree() -> void:
	_portraits.clear()
	_choice_buttons.clear()
	_choices.clear()
	_pages.clear()
	_panel = null
	_panel_style = null
	_portrait_rect = null


func _process(delta: float) -> void:
	if not visible:
		return
	_hint_pulse += delta
	if _hint_label != null:
		_hint_label.modulate.a = 0.62 + 0.38 * absf(sin(_hint_pulse * 4.2))

	if not _typing or _body_label == null:
		return

	var prev_int: int = int(_typed_chars)
	_typed_chars = minf(float(_total_chars), _typed_chars + CHARS_PER_SECOND * delta)
	var next_int: int = int(_typed_chars)
	_body_label.visible_characters = next_int

	if next_int > prev_int and (next_int / 3) > (prev_int / 3):
		var full_txt: String = _body_label.text
		var idx: int = clampi(next_int - 1, 0, maxi(0, full_txt.length() - 1))
		if idx < full_txt.length():
			var ch: String = full_txt.substr(idx, 1)
			if ch != " " and ch != "\n":
				AudioManager.play_dialogue_blip(_speaker_pitch)

	if next_int >= _total_chars:
		_finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_close_dialogue()
		get_viewport().set_input_as_handled()
		return

	var choices_active: bool = not _typing and _page_index >= _pages.size() - 1 and not _choices.is_empty()
	if choices_active:
		if event is InputEventKey and event.pressed and not event.echo:
			var kev: InputEventKey = event as InputEventKey
			if kev.physical_keycode == KEY_1 and _choice_buttons.size() >= 1:
				_trigger_choice(0)
				get_viewport().set_input_as_handled()
				return
			elif kev.physical_keycode == KEY_2 and _choice_buttons.size() >= 2:
				_trigger_choice(1)
				get_viewport().set_input_as_handled()
				return
			elif kev.physical_keycode == KEY_3 and _choice_buttons.size() >= 3:
				_trigger_choice(2)
				get_viewport().set_input_as_handled()
				return
			elif kev.physical_keycode == KEY_W or kev.physical_keycode == KEY_UP:
				_move_choice_focus(-1)
				get_viewport().set_input_as_handled()
				return
			elif kev.physical_keycode == KEY_S or kev.physical_keycode == KEY_DOWN:
				_move_choice_focus(1)
				get_viewport().set_input_as_handled()
				return
			elif kev.physical_keycode == KEY_E or kev.physical_keycode == KEY_ENTER or kev.physical_keycode == KEY_SPACE:
				_activate_focused_choice()
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_advance_dialogue()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not choices_active:
			_advance_dialogue()
			get_viewport().set_input_as_handled()


func _on_dialogue_requested(payload: Dictionary) -> void:
	_dialogue_generation += 1

	var sp_name: String = str(payload.get("speaker_name", "SOBREVIVENTE"))
	var sp_role: String = str(payload.get("speaker_role", ""))
	var portrait_id: String = str(payload.get("portrait_id", "default"))
	var accent: Color = payload.get("accent_color", UiTheme.AMBER) as Color
	_speaker_pitch = clampf(float(payload.get("voice_pitch", 1.0)), 0.6, 1.5)

	_pages.clear()
	var raw_pages: Variant = payload.get("pages", [])
	if raw_pages is Array:
		for p: Variant in (raw_pages as Array):
			var s: String = str(p).strip_edges()
			if not s.is_empty():
				_pages.append(s)
	if _pages.is_empty():
		_pages.append("...")

	_choices.clear()
	var raw_choices: Variant = payload.get("choices", [])
	if raw_choices is Array:
		for c: Variant in (raw_choices as Array):
			if c is Dictionary:
				_choices.append(c as Dictionary)
				if _choices.size() >= 3:
					break

	if _name_label != null:
		_name_label.text = sp_name.to_upper()
	if _role_label != null:
		_role_label.text = ("•  " + sp_role.to_upper()) if not sp_role.is_empty() else ""
	if _panel_style != null:
		_panel_style.border_color = accent
	if _portrait_rect != null:
		_portrait_rect.texture = _get_portrait_texture(portrait_id)

	_page_index = 0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_paper()
	_show_current_page()


func _show_current_page() -> void:
	if _page_label != null:
		_page_label.text = "%d/%d" % [_page_index + 1, _pages.size()]
	_clear_choices_ui()

	if _body_label != null:
		_body_label.text = _pages[_page_index]
		_total_chars = _body_label.text.length()
		_typed_chars = 0.0
		_body_label.visible_characters = 0
		_typing = true
	else:
		_typing = false
	_update_hint_text()


func _finish_typing() -> void:
	_typing = false
	_typed_chars = float(_total_chars)
	if _body_label != null:
		_body_label.visible_characters = -1
	var is_last_page: bool = _page_index >= _pages.size() - 1
	if is_last_page and not _choices.is_empty():
		_populate_choices_ui()
	_update_hint_text()


func _advance_dialogue() -> void:
	if _typing:
		_finish_typing()
		return
	if _page_index < _pages.size() - 1:
		_page_index += 1
		AudioManager.play_ui_click()
		_show_current_page()
		return
	if not _choices.is_empty():
		return
	_close_dialogue()


func _populate_choices_ui() -> void:
	_clear_choices_ui()
	if _choices_box == null:
		return
	_choices_box.visible = true
	for i: int in range(_choices.size()):
		var ch_dict: Dictionary = _choices[i]
		var lbl_txt: String = str(ch_dict.get("label", "Continuar"))
		var btn: Button = Button.new()
		btn.text = "[%d] %s" % [i + 1, lbl_txt]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(540.0, 30.0)
		btn.add_theme_font_size_override("font_size", 14)
		var captured_idx: int = i
		btn.pressed.connect(func() -> void:
			_trigger_choice(captured_idx)
		)
		_choices_box.add_child(btn)
		_choice_buttons.append(btn)
	if not _choice_buttons.is_empty():
		_choice_buttons[0].grab_focus()


func _clear_choices_ui() -> void:
	_choice_buttons.clear()
	if _choices_box == null:
		return
	_choices_box.visible = false
	for child: Node in _choices_box.get_children():
		child.queue_free()


func _move_choice_focus(dir: int) -> void:
	if _choice_buttons.is_empty():
		return
	var current_idx: int = 0
	for i: int in range(_choice_buttons.size()):
		if _choice_buttons[i].has_focus():
			current_idx = i
			break
	var next_idx: int = (current_idx + dir + _choice_buttons.size()) % _choice_buttons.size()
	_choice_buttons[next_idx].grab_focus()
	AudioManager.play_menu_hover()


func _activate_focused_choice() -> void:
	if _choice_buttons.is_empty():
		return
	for i: int in range(_choice_buttons.size()):
		if _choice_buttons[i].has_focus():
			_trigger_choice(i)
			return
	_trigger_choice(0)


func _trigger_choice(idx: int) -> void:
	if idx < 0 or idx >= _choices.size():
		return
	var gen_before: int = _dialogue_generation
	var ch_dict: Dictionary = _choices[idx]
	var cb: Variant = ch_dict.get("callback", null)
	AudioManager.play_ui_click()
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call()
	# Se o callback não abriu um novo diálogo de continuação, encerra o diálogo atual.
	if _dialogue_generation == gen_before:
		_close_dialogue()


func _update_hint_text() -> void:
	if _hint_label == null:
		return
	if _typing:
		_hint_label.text = "[E / CLIQUE] PULAR"
	elif _page_index < _pages.size() - 1:
		_hint_label.text = "▼ [E] CONTINUAR"
	elif not _choices.is_empty():
		_hint_label.text = "[1-%d] ESCOLHER RESPOSTA  •  [ESC] SAIR" % _choices.size()
	else:
		_hint_label.text = "[E / ESC] ENCERRAR"


func _close_dialogue() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_typing = false
	_pages.clear()
	_choices.clear()
	_clear_choices_ui()
	AudioManager.play_menu_back()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	call_deferred("_finish_close_deferred")


func _finish_close_deferred() -> void:
	if not visible:
		get_tree().paused = false
	GameEvents.dialogue_closed.emit()


func _build_ui() -> void:
	# Faixa escurecida suave na base atrás da caixa de diálogo (não bloqueia a parte superior da cena)
	var scrim: ColorRect = ColorRect.new()
	scrim.name = "BottomScrim"
	scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	scrim.offset_top = -290.0
	scrim.offset_bottom = 0.0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.color = Color(0.015, 0.012, 0.01, 0.34)
	add_child(scrim)

	# Painel principal posicionado acima dos clusters inferiores da HUD (Óleo/Sanidade e Vida)
	_panel = PanelContainer.new()
	_panel.name = "DialoguePanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -360.0
	_panel.offset_right = 360.0
	_panel.offset_top = -256.0
	_panel.offset_bottom = -96.0

	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.045, 0.04, 0.035, 0.95)
	_panel_style.border_color = Color(0.76, 0.56, 0.24, 0.95)
	_panel_style.set_border_width_all(2)
	_panel_style.border_width_left = 5
	_panel_style.content_margin_left = 14.0
	_panel_style.content_margin_right = 14.0
	_panel_style.content_margin_top = 12.0
	_panel_style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", _panel_style)
	add_child(_panel)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	_panel.add_child(hbox)

	# Moldura do retrato pixel-art à esquerda
	var portrait_frame: PanelContainer = PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(88.0, 88.0)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var pf_style: StyleBoxFlat = UiTheme.make_box(Color(0.08, 0.07, 0.06, 0.98), Color(0.42, 0.32, 0.18), 2, 4)
	portrait_frame.add_theme_stylebox_override("panel", pf_style)
	hbox.add_child(portrait_frame)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(78.0, 78.0)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_frame.add_child(_portrait_rect)

	# Coluna direita: cabeçalho, texto, escolhas e prompt de continuação
	var content_vbox: VBoxContainer = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(content_vbox)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content_vbox.add_child(header)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", UiTheme.AMBER)
	header.add_child(_name_label)

	_role_label = Label.new()
	_role_label.add_theme_font_size_override("font_size", 12)
	_role_label.add_theme_color_override("font_color", Color(0.68, 0.64, 0.56))
	_role_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_role_label)

	var header_spacer: Control = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	_page_label = Label.new()
	_page_label.add_theme_font_size_override("font_size", 12)
	_page_label.add_theme_color_override("font_color", Color(0.72, 0.68, 0.58))
	header.add_child(_page_label)

	_body_label = Label.new()
	_body_label.custom_minimum_size = Vector2(560.0, 56.0)
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 15)
	_body_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.83))
	_body_label.add_theme_constant_override("line_spacing", 3)
	content_vbox.add_child(_body_label)

	_choices_box = VBoxContainer.new()
	_choices_box.visible = false
	_choices_box.add_theme_constant_override("separation", 5)
	content_vbox.add_child(_choices_box)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", UiTheme.AMBER)
	content_vbox.add_child(_hint_label)


func _get_portrait_texture(portrait_id: String) -> ImageTexture:
	if _portraits.has(portrait_id):
		return _portraits[portrait_id] as ImageTexture

	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var coat_col: Color = Color(0.24, 0.28, 0.22)
	var hair_col: Color = Color(0.22, 0.16, 0.11)
	var skin_col: Color = Color(0.74, 0.58, 0.44)
	var bg_col: Color = Color(0.08, 0.07, 0.06)

	if portrait_id == "helena":
		coat_col = Color(0.38, 0.22, 0.27)
		hair_col = Color(0.56, 0.54, 0.52)
		skin_col = Color(0.76, 0.62, 0.52)
		bg_col = Color(0.09, 0.07, 0.08)
	elif portrait_id == "player":
		coat_col = Color(0.16, 0.14, 0.12)
		hair_col = Color(0.14, 0.10, 0.08)
		skin_col = Color(0.72, 0.56, 0.44)
	elif portrait_id == "default":
		coat_col = Color(0.22, 0.22, 0.24)
		hair_col = Color(0.18, 0.16, 0.14)

	for y: int in range(32):
		for x: int in range(32):
			var c: Color = bg_col
			var dist_vignette: float = Vector2(float(x - 16), float(y - 14)).length()
			if dist_vignette < 15.0:
				var glow: float = (1.0 - dist_vignette / 15.0) * 0.08
				c = Color(bg_col.r + glow, bg_col.g + glow * 0.7, bg_col.b + glow * 0.4, 1.0)

			var dx: float = float(x - 16)
			# Ombros e casaco
			if y >= 22 and absf(dx) <= 9.0 + float(y - 22) * 0.55:
				c = coat_col
				if absf(dx) < 3.0 and y < 26:
					c = coat_col.darkened(0.38)
				if portrait_id == "marcos" and y >= 22 and y <= 24 and absf(dx) < 5.0:
					c = Color(0.46, 0.20, 0.16)
				elif portrait_id == "helena" and y >= 22 and y <= 25 and absf(dx) < 5.5:
					c = Color(0.52, 0.34, 0.38)

			# Pescoço
			if y >= 18 and y <= 22 and absf(dx) <= 2.6:
				c = skin_col.darkened(0.18)

			# Cabeça oval + sombreamento estilo PS1
			var head_d: float = (dx * dx) / (5.8 * 5.8) + (float(y - 13) * float(y - 13)) / (6.8 * 6.8)
			if head_d <= 1.0:
				var side_shade: float = clampf(0.95 - (dx + 2.0) * 0.035, 0.62, 1.0)
				c = Color(skin_col.r * side_shade, skin_col.g * side_shade, skin_col.b * side_shade, 1.0)
				# Cabelo / Barba
				if y <= 9 or (y <= 13 and absf(dx) >= 4.4):
					c = hair_col
				elif portrait_id == "helena" and y <= 18 and absf(dx) >= 4.6:
					c = hair_col
				elif portrait_id == "marcos" and y >= 15 and absf(dx) <= 4.4:
					c = hair_col.darkened(0.15)
				# Olhos e expressão séria
				if y == 12 and (absf(dx + 2.1) <= 0.8 or absf(dx - 2.1) <= 0.8):
					c = Color(0.08, 0.06, 0.05)
				elif y == 11 and (absf(dx + 2.2) <= 1.4 or absf(dx - 2.2) <= 1.4):
					c = hair_col.darkened(0.2)
				elif y == 16 and absf(dx) <= 1.6 and portrait_id != "marcos":
					c = Color(0.44, 0.24, 0.20)
			elif portrait_id == "helena" and y >= 7 and y <= 16 and absf(dx) <= 6.2 and (y <= 9 or absf(dx) >= 4.8):
				c = hair_col

			img.set_pixel(x, y, c)

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_portraits[portrait_id] = tex
	return tex
