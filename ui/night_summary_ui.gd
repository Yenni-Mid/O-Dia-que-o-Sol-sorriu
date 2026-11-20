class_name NightSummaryUI
extends Control
## Cartão de Transição e Resumo ao sobreviver uma noite inteira e abrigar-se em casa até 19:15.

const UiTheme := preload("res://ui/ui_theme.gd")

var _next_night: int = 2
var _time: float = 0.0
var _serif_font: SystemFont
var _pixel_font: SystemFont

var _bg: ColorRect
var _title_glow: Label
var _title_label: Label
var _flavor_label: Label
var _summary_label: Label
var _confirm_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	_init_fonts()
	_build_ui()
	GameEvents.night_transition_requested.connect(_on_night_transition_requested)


func _exit_tree() -> void:
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
		_title_glow.modulate.a = 0.72 + 0.28 * sin(_time * 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if (
		event.is_action_pressed("interact")
		or event.is_action_pressed("ui_accept")
		or event.is_action_pressed("ui_cancel")
		or (event is InputEventKey and event.pressed and not event.echo and ((event as InputEventKey).physical_keycode == KEY_ENTER or (event as InputEventKey).physical_keycode == KEY_SPACE or (event as InputEventKey).physical_keycode == KEY_E))
	):
		_confirm_next_night()
		get_viewport().set_input_as_handled()


func _on_night_transition_requested(next_night_num: int) -> void:
	_next_night = maxi(2, next_night_num)
	var survived_night: int = maxi(1, _next_night - 1)
	var title_txt: String = "NOITE %d SOBREVIVIDA" % survived_night
	if _title_label != null:
		_title_label.text = title_txt
	if _title_glow != null:
		_title_glow.text = title_txt

	if _flavor_label != null:
		if _next_night == 2:
			_flavor_label.text = "O Sol Sorridente finalmente caiu além dos telhados.\nO culto deixou uma marca na sua varanda durante o dia — sintonize o rádio da casa antes de sair."
		else:
			_flavor_label.text = "Mais um dia suportado atrás das tábuas pregadas.\nA neblina sulfurosa cobriu os becos de novo; sintonize o rádio da entrada para a nova transmissão."

	if _summary_label != null:
		_summary_label.text = _build_summary_text()
	if _confirm_btn != null:
		_confirm_btn.text = "> INICIAR NOITE %d (19:15)" % _next_night

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _bg != null:
		_bg.modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.tween_property(_bg, "modulate:a", 1.0, 0.45)
	if _confirm_btn != null:
		_confirm_btn.grab_focus()


func _confirm_next_night() -> void:
	if not visible:
		return
	AudioManager.play_menu_confirm()
	AudioManager.play_lantern_ignite()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_summary_text() -> String:
	var echoes_total: int = maxi(1, get_tree().get_nodes_in_group("echo_note").size())
	var bottles: int = 0
	var bandages: int = 0
	var keys: Array = []
	var tools: Array = []
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if inv != null:
		if inv.has_method("get_bottles"):
			bottles = int(inv.call("get_bottles"))
		if inv.has_method("get_bandages"):
			bandages = int(inv.call("get_bandages"))
		if inv.has_method("get_keys"):
			keys = inv.call("get_keys") as Array
		if inv.has_method("get_tools"):
			tools = inv.call("get_tools") as Array

	return (
		"ECOS DESCOBERTOS:      %d / %d\n"
		+ "GARRAFAS: %d   •   BANDAGENS: %d\n"
		+ "CHAVES: %d   •   FERRAMENTAS: %d\n"
		+ "ATALHOS DESTRAVADOS:   %d / 2\n"
		+ "SANIDADE RESTAURADA:   +45%%  •  REFÚGIO SALVO"
	) % [
		SaveManager.get_collected_count(),
		echoes_total,
		bottles,
		bandages,
		keys.size(),
		tools.size(),
		SaveManager.get_unlocked_shortcuts_count(),
	]


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.025, 0.02, 0.016, 0.94)
	add_child(_bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(580.0, 0.0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title_box: Control = Control.new()
	title_box.custom_minimum_size = Vector2(580.0, 56.0)
	vbox.add_child(title_box)

	_title_glow = Label.new()
	_title_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_glow.offset_left = 2.0
	_title_glow.offset_top = 2.0
	_title_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_glow.add_theme_font_override("font", _serif_font)
	_title_glow.add_theme_font_size_override("font_size", 40)
	_title_glow.add_theme_color_override("font_color", Color(0.88, 0.48, 0.12, 0.85))
	title_box.add_child(_title_glow)

	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_override("font", _serif_font)
	_title_label.add_theme_font_size_override("font_size", 40)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.80))
	_title_label.add_theme_constant_override("outline_size", 6)
	_title_label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.96))
	title_box.add_child(_title_label)

	_flavor_label = Label.new()
	_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.add_theme_font_size_override("font_size", 14)
	_flavor_label.add_theme_color_override("font_color", Color(0.84, 0.78, 0.68))
	vbox.add_child(_flavor_label)

	var card: PanelContainer = PanelContainer.new()
	var card_style: StyleBoxFlat = UiTheme.make_box(Color(0.055, 0.048, 0.04, 0.96), UiTheme.AMBER, 2, 16)
	card.add_theme_stylebox_override("panel", card_style)
	vbox.add_child(card)

	_summary_label = Label.new()
	_summary_label.add_theme_font_override("font", _pixel_font)
	_summary_label.add_theme_font_size_override("font_size", 15)
	_summary_label.add_theme_constant_override("line_spacing", 6)
	_summary_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.83))
	card.add_child(_summary_label)

	_confirm_btn = Button.new()
	_confirm_btn.custom_minimum_size = Vector2(340.0, 44.0)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_btn.add_theme_font_override("font", _pixel_font)
	_confirm_btn.add_theme_font_size_override("font_size", 20)
	_confirm_btn.pressed.connect(_confirm_next_night)
	vbox.add_child(_confirm_btn)
