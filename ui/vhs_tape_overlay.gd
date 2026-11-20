extends Control
## Interface aprimorada de reprodução das Fitas VHS (CRT PS1):
## Cenas pixel-art reconhecíveis por fita, caixa de legenda de alto contraste,
## tempo de leitura dinâmico e controles de Anterior / Pausar / Próxima / Ejetar.

const UiTheme := preload("res://ui/ui_theme.gd")

var _lines: Array[String] = []
var _line_idx: int = 0
var _line_timer: float = 0.0
var _line_duration: float = 6.0
var _elapsed: float = 0.0
var _paused_tape: bool = false
var _static_player: AudioStreamPlayer

var _title_label: Label
var _counter_label: Label
var _line_count_label: Label
var _preview_rect: TextureRect
var _tracking_bar: ColorRect
var _subtitle_label: Label
var _progress_bar: ProgressBar
var _prev_btn: Button
var _pause_btn: Button
var _next_btn: Button
var _eject_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	_build_ui()

	_static_player = AudioStreamPlayer.new()
	_static_player.name = "VHSStaticPlayer"
	_static_player.stream = AudioManager.get_vhs_static_stream()
	_static_player.volume_db = -23.0
	add_child(_static_player)

	GameEvents.vhs_tape_requested.connect(_on_vhs_tape_requested)


func _exit_tree() -> void:
	if _static_player != null:
		_static_player.stop()
		_static_player.stream = null
	if _preview_rect != null:
		_preview_rect.texture = null
	_lines.clear()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _tracking_bar != null:
		var frame_h: float = 300.0
		var y_track: float = fposmod(_elapsed * 44.0, frame_h + 24.0) - 24.0
		_tracking_bar.position.y = y_track

	if _counter_label != null:
		var secs: int = int(_elapsed)
		var state_txt: String = "PAUSE ⏸" if _paused_tape else ("PLAY ▶ " if int(_elapsed * 2.0) % 2 == 0 else "PLAY   ")
		_counter_label.text = "%s  SP 00:%02d:%02d" % [state_txt, secs / 60, secs % 60]
		_counter_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30) if _paused_tape else Color(0.95, 0.34, 0.26))

	if not _paused_tape:
		_line_timer -= delta
		if _progress_bar != null:
			_progress_bar.value = clampf((_line_timer / maxf(_line_duration, 0.1)) * 100.0, 0.0, 100.0)
		if _line_timer <= 0.0:
			_advance_line()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_tape()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_advance_line()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var kev: InputEventKey = event as InputEventKey
		if kev.physical_keycode == KEY_A or kev.physical_keycode == KEY_LEFT:
			_prev_line()
			get_viewport().set_input_as_handled()
		elif kev.physical_keycode == KEY_D or kev.physical_keycode == KEY_RIGHT:
			_advance_line()
			get_viewport().set_input_as_handled()
		elif kev.physical_keycode == KEY_P:
			_toggle_pause_tape()
			get_viewport().set_input_as_handled()


func _on_vhs_tape_requested(tape_id: String, title: String, lines: Array) -> void:
	_lines.clear()
	for entry: Variant in lines:
		var s: String = str(entry).strip_edges()
		if not s.is_empty():
			_lines.append(s)
	if _lines.is_empty():
		_lines.append("[Fita danificada — apenas estática.]")

	_line_idx = 0
	_elapsed = 0.0
	_paused_tape = false

	if _title_label != null:
		_title_label.text = title
	if _preview_rect != null:
		_preview_rect.texture = _build_tape_thumbnail(tape_id)

	_apply_current_line()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _static_player != null and _static_player.stream != null:
		_static_player.play()


func _apply_current_line() -> void:
	var txt: String = _lines[_line_idx]
	_line_duration = clampf(3.8 + float(txt.length()) * 0.045, 5.2, 9.0)
	_line_timer = _line_duration
	if _subtitle_label != null:
		_subtitle_label.text = txt
	if _line_count_label != null:
		_line_count_label.text = "TRECHO %d / %d" % [_line_idx + 1, _lines.size()]
	if _prev_btn != null:
		_prev_btn.disabled = (_line_idx <= 0)
	if _pause_btn != null:
		_pause_btn.text = "▶ Continuar [P]" if _paused_tape else "⏸ Pausar [P]"
	if _progress_bar != null:
		_progress_bar.value = 100.0


func _prev_line() -> void:
	if _line_idx <= 0:
		return
	_line_idx -= 1
	AudioManager.play_ui_click()
	_apply_current_line()


func _advance_line() -> void:
	AudioManager.play_ui_click()
	_line_idx += 1
	if _line_idx >= _lines.size():
		close_tape()
		return
	_apply_current_line()


func _toggle_pause_tape() -> void:
	_paused_tape = not _paused_tape
	AudioManager.play_ui_click()
	if _pause_btn != null:
		_pause_btn.text = "▶ Continuar [P]" if _paused_tape else "⏸ Pausar [P]"


func close_tape() -> void:
	visible = false
	if _static_player != null and _static_player.playing:
		_static_player.stop()
	AudioManager.play_menu_back()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_ui() -> void:
	var dimmer: ColorRect = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.0, 0.0, 0.0, 0.84)
	add_child(dimmer)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -380.0
	panel.offset_top = -255.0
	panel.offset_right = 380.0
	panel.offset_bottom = 255.0
	var p_style: StyleBoxFlat = UiTheme.make_box(Color(0.04, 0.04, 0.045, 0.98), Color(0.76, 0.56, 0.24), 2, 14)
	panel.add_theme_stylebox_override("panel", p_style)
	add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Cabeçalho VCR
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", UiTheme.AMBER)
	header.add_child(_title_label)

	_line_count_label = Label.new()
	_line_count_label.add_theme_font_size_override("font_size", 14)
	_line_count_label.add_theme_color_override("font_color", Color(0.84, 0.82, 0.76))
	header.add_child(_line_count_label)

	_counter_label = Label.new()
	_counter_label.add_theme_font_size_override("font_size", 15)
	_counter_label.add_theme_color_override("font_color", Color(0.95, 0.34, 0.26))
	header.add_child(_counter_label)

	# Tela CRT com faixa de tracking e caixa de legenda escura nítida
	var frame_box: Control = Control.new()
	frame_box.clip_contents = true
	frame_box.custom_minimum_size = Vector2(732.0, 340.0)
	frame_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(frame_box)

	_preview_rect = TextureRect.new()
	_preview_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_rect.stretch_mode = TextureRect.STRETCH_SCALE
	frame_box.add_child(_preview_rect)

	_tracking_bar = ColorRect.new()
	_tracking_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_tracking_bar.offset_bottom = 18.0
	_tracking_bar.color = Color(0.82, 0.88, 0.86, 0.14)
	_tracking_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_box.add_child(_tracking_bar)

	# Caixa de Legenda com alto contraste (resolve ilegibilidade das fitas!)
	var sub_panel: PanelContainer = PanelContainer.new()
	sub_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sub_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sub_panel.offset_left = 14.0
	sub_panel.offset_right = -14.0
	sub_panel.offset_top = -126.0
	sub_panel.offset_bottom = -12.0
	var sp_style: StyleBoxFlat = StyleBoxFlat.new()
	sp_style.bg_color = Color(0.025, 0.025, 0.03, 0.92)
	sp_style.border_color = Color(0.92, 0.76, 0.32, 0.85)
	sp_style.set_border_width_all(1)
	sp_style.border_width_left = 4
	sp_style.content_margin_left = 16.0
	sp_style.content_margin_right = 16.0
	sp_style.content_margin_top = 12.0
	sp_style.content_margin_bottom = 10.0
	sub_panel.add_theme_stylebox_override("panel", sp_style)
	frame_box.add_child(sub_panel)

	var sub_vbox: VBoxContainer = VBoxContainer.new()
	sub_vbox.add_theme_constant_override("separation", 8)
	sub_panel.add_child(sub_vbox)

	_subtitle_label = Label.new()
	_subtitle_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 19)
	_subtitle_label.add_theme_constant_override("line_spacing", 4)
	_subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.84))
	_subtitle_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_subtitle_label.add_theme_constant_override("outline_size", 4)
	sub_vbox.add_child(_subtitle_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0.0, 4.0)
	_progress_bar.show_percentage = false
	_progress_bar.max_value = 100.0
	_progress_bar.value = 100.0
	sub_vbox.add_child(_progress_bar)

	# Controles de reprodução do videocassete
	var controls: HBoxContainer = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	vbox.add_child(controls)

	_prev_btn = Button.new()
	_prev_btn.text = "◀ Anterior [A]"
	_prev_btn.pressed.connect(_prev_line)
	controls.add_child(_prev_btn)

	_pause_btn = Button.new()
	_pause_btn.text = "⏸ Pausar [P]"
	_pause_btn.pressed.connect(_toggle_pause_tape)
	controls.add_child(_pause_btn)

	_next_btn = Button.new()
	_next_btn.text = "▶ Próxima [E / Espaço]"
	_next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_btn.pressed.connect(_advance_line)
	controls.add_child(_next_btn)

	_eject_btn = Button.new()
	_eject_btn.text = "⏏ Ejetar [ESC]"
	_eject_btn.pressed.connect(close_tape)
	controls.add_child(_eject_btn)


func _build_tape_thumbnail(tape_id: String) -> ImageTexture:
	var w: int = 160
	var h: int = 96
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = tape_id.hash()

	for y: int in range(h):
		var scan: float = 0.84 if (y % 2) == 0 else 1.0
		for x: int in range(w):
			var noise: float = rng.randf_range(-0.04, 0.04)
			var col: Color = Color(0.08, 0.08, 0.09)

			if tape_id == "tape_tv":
				# Estúdio de noticiário interrompido pelo Sol Sorridente
				col = Color(0.10, 0.14, 0.22) if y < 64 else Color(0.16, 0.12, 0.09)
				if y >= 58 and y <= 65:
					col = Color(0.68, 0.14, 0.12) # faixa de plantão
				# Âncora na bancada (esquerda) + tela do Sol ao lado (direita)
				if x >= 32 and x <= 56 and y >= 32 and y <= 60:
					col = Color(0.20, 0.22, 0.26)
				var head_d: float = Vector2(float(x - 44), float(y - 24)).length()
				if head_d <= 8.0:
					col = Color(0.72, 0.58, 0.46)
				if x >= 88 and x <= 138 and y >= 14 and y <= 50:
					col = Color(0.24, 0.20, 0.08)
					var sd: float = Vector2(float(x - 113), float(y - 32)).length()
					if sd <= 12.0:
						col = Color(0.95, 0.78, 0.22)
						if (absf(float(x - 109)) < 1.8 or absf(float(x - 117)) < 1.8) and y >= 27 and y <= 30:
							col = Color(0.10, 0.06, 0.04)
						if absf(float(x - 113)) <= 6.0 and y >= 35 and y <= 37:
							col = Color(0.12, 0.05, 0.04)
			elif tape_id == "tape_market":
				# Câmera de segurança verde do Mini-Mercado com prateleiras e cultista na porta
				col = Color(0.07, 0.14, 0.10) if y < 56 else Color(0.12, 0.18, 0.14)
				if (x >= 12 and x <= 38) or (x >= 122 and x <= 148):
					if y >= 22 and y <= 68:
						col = Color(0.14, 0.24, 0.17)
				if x >= 66 and x <= 94 and y >= 16 and y <= 62:
					col = Color(0.04, 0.07, 0.05) # porta dos fundos/vitrine
					if absf(float(x - 80)) <= 7.0 and y >= 28:
						col = Color(0.18, 0.20, 0.16)
					if absf(float(x - 80)) <= 4.0 and y >= 26 and y <= 34:
						col = Color(0.84, 0.80, 0.62) # máscara olhando
			elif tape_id == "tape_plaza":
				# Pracinha à noite com Pregador no altar e feixe dourado
				col = Color(0.08, 0.06, 0.10) if y < 58 else Color(0.14, 0.12, 0.13)
				var moon_d: float = Vector2(float(x - 80), float(y - 24)).length()
				if moon_d <= 14.0:
					col = Color(0.82, 0.64, 0.24)
				if x >= 68 and x <= 92 and y >= 48 and y <= 64:
					col = Color(0.24, 0.22, 0.24) # pedestal do altar
				if absf(float(x - 80)) <= 5.0 and y >= 28 and y <= 50:
					col = Color(0.16, 0.08, 0.18) # Pregador
					if y >= 28 and y <= 34 and absf(float(x - 80)) <= 3.5:
						col = Color(0.96, 0.78, 0.26)
			elif tape_id == "tape_gas":
				# Posto de Gasolina na neblina com marquise e bombas vermelhas
				col = Color(0.10, 0.11, 0.13) if y < 60 else Color(0.16, 0.15, 0.16)
				if x >= 26 and x <= 134 and y >= 24 and y <= 31:
					col = Color(0.54, 0.18, 0.14) # marquise do posto
				if (absi(x - 42) <= 2 or absi(x - 118) <= 2) and y >= 31 and y <= 60:
					col = Color(0.36, 0.36, 0.38) # pilares
				if (absi(x - 66) <= 4 or absi(x - 94) <= 4) and y >= 44 and y <= 60:
					col = Color(0.62, 0.20, 0.16) # bombas de combustível
			else:
				# tape_chapel: Nave da Capela com vitral solar ao fundo e bancos
				col = Color(0.09, 0.07, 0.08) if y < 62 else Color(0.22, 0.08, 0.08)
				var win_d: float = Vector2(float(x - 80), float(y - 26)).length()
				if win_d <= 12.0:
					col = Color(0.92, 0.70, 0.24)
				if y >= 50 and y <= 64 and absi(x - 80) <= 10:
					col = Color(0.34, 0.22, 0.14) # altar
				if y >= 66 and y <= 78 and (absi(x - 52) <= 18 or absi(x - 108) <= 18):
					col = Color(0.26, 0.16, 0.10) # bancos

			# Borda de monitor CRT nas extremidades
			if x < 3 or x >= w - 3 or y < 3 or y >= h - 3:
				col = col.darkened(0.65)

			img.set_pixel(x, y, Color(
				clampf(col.r * scan + noise, 0.0, 1.0),
				clampf(col.g * scan + noise, 0.0, 1.0),
				clampf(col.b * scan + noise, 0.0, 1.0),
				1.0
			))
	return ImageTexture.create_from_image(img)
