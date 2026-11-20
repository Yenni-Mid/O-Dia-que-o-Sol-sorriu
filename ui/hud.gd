class_name GameHUD
extends Control
## HUD minimalista de horror retrô, construída em código:
## - Sinais vitais (Vida / Mente / Óleo) com barras suavizadas e pulso de alerta;
## - Indicador de zona de luz colorido; mira que reage a interagíveis;
## - Objetivo da demo (Ecos coletados), toast de coleta, confissões e frestas do guarda-roupa.

const UiTheme := preload("res://ui/ui_theme.gd")

const COLOR_HEALTH: Color = Color(0.82, 0.2, 0.18)
const COLOR_SANITY: Color = Color(0.55, 0.72, 0.9)
const COLOR_OIL: Color = Color(1.0, 0.6, 0.2)
const COLOR_STAMINA: Color = Color(0.66, 0.78, 0.42)
const ZONE_TEXTS: Array[String] = ["EXPOSTO AO SOL", "ESCURIDÃO", "PROTEGIDO PELO FOGO"]
const ZONE_COLORS: Array[Color] = [Color(1.0, 0.85, 0.35), Color(0.6, 0.66, 0.78), Color(1.0, 0.62, 0.28)]

var _health_bar: ProgressBar
var _sanity_bar: ProgressBar
var _oil_bar: ProgressBar
var _stamina_bar: ProgressBar
var _stamina_row: HBoxContainer
var _health_target: float = 100.0
var _sanity_target: float = 100.0
var _oil_target: float = 100.0
var _stamina_target: float = 100.0

var _vitals_panel: PanelContainer
var _zone_label: Label
var _prompt_label: Label
var _confession_label: Label
var _objective_label: Label
var _toast_label: Label
var _clock_label: Label
var _radio_label: Label
var _inventory_label: Label
var _crosshair: ColorRect
var _hiding_overlay: Control

var _confession_timer: float = 0.0
var _toast_timer: float = 0.0
var _pulse_time: float = 0.0
var _radio_level: float = 0.0
var _is_dawn_urgent: bool = false
var _cached_bottles: int = 1
var _cached_bandages: int = 1
var _cached_keys_count: int = 0
var _cached_tools_count: int = 0
var _collected_ids: Dictionary = {}
var _total_echoes: int = 0


func _ready() -> void:
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in get_children():
		child.queue_free()
	_build_layout()

	GameEvents.oil_changed.connect(_on_oil_changed)
	GameEvents.sanity_changed.connect(_on_sanity_changed)
	GameEvents.health_changed.connect(_on_health_changed)
	GameEvents.stamina_changed.connect(_on_stamina_changed)
	GameEvents.lighting_zone_changed.connect(_on_lighting_zone_changed)
	GameEvents.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	GameEvents.confession_triggered.connect(_on_confession_triggered)
	GameEvents.player_hidden_changed.connect(_on_player_hidden_changed)
	GameEvents.echo_opened.connect(_on_echo_opened)
	GameEvents.time_of_day_changed.connect(_on_time_of_day_changed)
	GameEvents.inventory_changed.connect(_on_inventory_changed)
	GameEvents.tools_changed.connect(_on_tools_changed)
	GameEvents.radio_interference_changed.connect(_on_radio_interference_changed)
	GameEvents.status_message_requested.connect(_on_status_message_requested)
	call_deferred("_count_echoes")


func _process(delta: float) -> void:
	_pulse_time += delta
	var k: float = clampf(8.0 * delta, 0.0, 1.0)
	if _health_bar != null:
		_health_bar.value = lerpf(_health_bar.value, _health_target, k)
		var low_hp: bool = _health_target / maxf(_health_bar.max_value, 0.001) < 0.3
		_health_bar.modulate = Color(1, 1, 1, 0.55 + 0.45 * absf(sin(_pulse_time * 5.0))) if low_hp else Color.WHITE
	if _sanity_bar != null:
		_sanity_bar.value = lerpf(_sanity_bar.value, _sanity_target, k)
	if _oil_bar != null:
		_oil_bar.value = lerpf(_oil_bar.value, _oil_target, k)
		var low_oil: bool = _oil_target / maxf(_oil_bar.max_value, 0.001) < 0.2
		_oil_bar.modulate = Color(1, 1, 1, 0.5 + 0.5 * absf(sin(_pulse_time * 3.0))) if low_oil else Color.WHITE
	if _stamina_bar != null and _stamina_row != null:
		_stamina_bar.value = lerpf(_stamina_bar.value, _stamina_target, clampf(12.0 * delta, 0.0, 1.0))
		var target_alpha: float = 0.92 if _stamina_target < 99.0 else 0.0
		_stamina_row.modulate.a = move_toward(_stamina_row.modulate.a, target_alpha, delta * 3.5)

	if _confession_timer > 0.0 and _confession_label != null:
		_confession_timer -= delta
		_confession_label.modulate.a = clampf(_confession_timer / 0.8, 0.0, 1.0)
	if _toast_timer > 0.0 and _toast_label != null:
		_toast_timer -= delta
		_toast_label.modulate.a = clampf(_toast_timer / 0.8, 0.0, 1.0)
	if _radio_label != null and _radio_level > 0.03:
		var freq: float = lerpf(4.0, 16.0, _radio_level)
		_radio_label.modulate.a = 0.5 + 0.5 * absf(sin(_pulse_time * freq))
	if _clock_label != null:
		_clock_label.modulate.a = (0.58 + 0.42 * absf(sin(_pulse_time * 5.0))) if _is_dawn_urgent else 1.0


# --------------------------------------------------------------------------- Layout

func _build_layout() -> void:
	# Frestas do guarda-roupa (visível só escondido)
	_hiding_overlay = Control.new()
	_hiding_overlay.name = "HidingOverlay"
	_hiding_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hiding_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hiding_overlay.visible = false
	add_child(_hiding_overlay)
	var slats: Array[Vector2] = [Vector2(0.0, 0.36), Vector2(0.43, 0.47), Vector2(0.53, 0.57), Vector2(0.64, 1.0)]
	for s: Vector2 in slats:
		var slat: ColorRect = ColorRect.new()
		slat.color = Color(0.02, 0.015, 0.01, 0.94)
		slat.anchor_left = 0.0
		slat.anchor_right = 1.0
		slat.anchor_top = s.x
		slat.anchor_bottom = s.y
		slat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hiding_overlay.add_child(slat)

	# Mira
	_crosshair = ColorRect.new()
	_crosshair.name = "Crosshair"
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_crosshair)
	_set_crosshair_active(false)

	# Prompt de interação
	_prompt_label = _make_label(15, UiTheme.AMBER)
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_label.offset_left = -260.0
	_prompt_label.offset_right = 260.0
	_prompt_label.offset_top = 22.0
	_prompt_label.offset_bottom = 48.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt_label)

	# Confissões (topo central)
	_confession_label = _make_label(18, Color(1.0, 0.86, 0.5))
	_confession_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_confession_label.offset_left = -380.0
	_confession_label.offset_right = 380.0
	_confession_label.offset_top = 56.0
	_confession_label.offset_bottom = 110.0
	_confession_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confession_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confession_label.modulate.a = 0.0
	add_child(_confession_label)

	# Toast de coleta (acima do centro)
	_toast_label = _make_label(20, Color(0.82, 0.9, 1.0))
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.offset_left = -300.0
	_toast_label.offset_right = 300.0
	_toast_label.offset_top = -120.0
	_toast_label.offset_bottom = -90.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.modulate.a = 0.0
	add_child(_toast_label)

	# Objetivo (topo esquerdo)
	var obj_box: VBoxContainer = VBoxContainer.new()
	obj_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_box.position = Vector2(22.0, 18.0)
	obj_box.add_theme_constant_override("separation", 0)
	add_child(obj_box)
	var obj_title: Label = _make_label(11, UiTheme.AMBER)
	obj_title.text = "OBJETIVO"
	obj_box.add_child(obj_title)
	_objective_label = _make_label(15, UiTheme.INK)
	_objective_label.text = "Sobreviva. Procure os Ecos deixados na casa."
	obj_box.add_child(_objective_label)

	# Sinais vitais (canto inferior esquerdo)
	_vitals_panel = PanelContainer.new()
	_vitals_panel.name = "Vitals"
	_vitals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals_panel.add_theme_stylebox_override("panel", UiTheme.make_box(Color(0.03, 0.025, 0.02, 0.62), Color(0.3, 0.24, 0.15, 0.7), 1, 10))
	_vitals_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_vitals_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_vitals_panel.offset_left = 20.0
	_vitals_panel.offset_top = -20.0
	_vitals_panel.offset_bottom = -20.0
	add_child(_vitals_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 5)
	_vitals_panel.add_child(vbox)

	_zone_label = _make_label(12, ZONE_COLORS[1])
	_zone_label.text = ZONE_TEXTS[1]
	vbox.add_child(_zone_label)
	_health_bar = _make_bar_row(vbox, "VIDA", COLOR_HEALTH)
	_sanity_bar = _make_bar_row(vbox, "MENTE", COLOR_SANITY)
	_oil_bar = _make_bar_row(vbox, "ÓLEO", COLOR_OIL)
	_stamina_bar = _make_bar_row(vbox, "FÔLEGO", COLOR_STAMINA)
	_stamina_row = _stamina_bar.get_parent() as HBoxContainer
	if _stamina_row != null:
		_stamina_row.modulate.a = 0.0

	# Relógio Dia/Noite (canto superior direito)
	_clock_label = _make_label(14, UiTheme.AMBER)
	_clock_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock_label.offset_left = -360.0
	_clock_label.offset_right = -22.0
	_clock_label.offset_top = 18.0
	_clock_label.offset_bottom = 44.0
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.text = "NOITE 1 | 19:15 — NOITE [CULTISTAS À SOLTA]"
	add_child(_clock_label)

	# Alerta de estática do Rádio (abaixo do relógio)
	_radio_label = _make_label(13, Color(1.0, 0.42, 0.25))
	_radio_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_radio_label.offset_left = -360.0
	_radio_label.offset_right = -22.0
	_radio_label.offset_top = 46.0
	_radio_label.offset_bottom = 70.0
	_radio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_radio_label.text = ""
	_radio_label.visible = false
	add_child(_radio_label)

	# Barra compacta de inventário e diário (canto inferior direito)
	_inventory_label = _make_label(13, UiTheme.INK)
	_inventory_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_inventory_label.offset_left = -460.0
	_inventory_label.offset_right = -22.0
	_inventory_label.offset_top = -42.0
	_inventory_label.offset_bottom = -16.0
	_inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_inventory_label.text = "[G] Garrafas: 1   |   [H] Bandagens: 1   |   [Tab] Mapa"
	add_child(_inventory_label)


func _make_label(font_size: int, color: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_bar_row(parent_box: VBoxContainer, title: String, color: Color) -> ProgressBar:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	parent_box.add_child(row)

	var lbl: Label = _make_label(12, color.lightened(0.3))
	lbl.text = title
	lbl.custom_minimum_size = Vector2(52.0, 0.0)
	row.add_child(lbl)

	var bar: ProgressBar = ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(200.0, 9.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	var fill: StyleBoxFlat = UiTheme.make_box(color, Color(0, 0, 0, 0), 0, 0)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return bar


func _set_crosshair_active(active: bool) -> void:
	if _crosshair == null:
		return
	var s: float = 6.0 if active else 3.0
	_crosshair.offset_left = -s * 0.5
	_crosshair.offset_top = -s * 0.5
	_crosshair.offset_right = s * 0.5
	_crosshair.offset_bottom = s * 0.5
	_crosshair.color = Color(1.0, 0.78, 0.35, 0.95) if active else Color(1.0, 0.94, 0.82, 0.55)


# --------------------------------------------------------------------------- Eventos

func _count_echoes() -> void:
	var echo_nodes: Array[Node] = get_tree().get_nodes_in_group("echo_note")
	_total_echoes = echo_nodes.size()
	for node: Node in echo_nodes:
		var eid: String = ""
		var data_val: Variant = node.get("echo_data")
		if data_val is EchoData and not (data_val as EchoData).echo_id.is_empty():
			eid = (data_val as EchoData).echo_id
		elif node.get("fallback_id") != null:
			eid = str(node.get("fallback_id"))
		if not eid.is_empty() and SaveManager.has_echo(eid):
			_collected_ids[eid] = true
	_update_objective()


func _update_objective() -> void:
	if _objective_label == null:
		return
	var count: int = _collected_ids.size()
	if _total_echoes > 0 and count >= _total_echoes:
		_objective_label.text = "Todos os Ecos do quarteirão foram lidos. A Torre Central aguarda no horizonte..."
	else:
		_objective_label.text = "Encontre os Ecos deixados nas sombras  [%d/%d]" % [count, _total_echoes]
	GameEvents.objective_changed.emit(_objective_label.text)


func _on_echo_opened(data: EchoData) -> void:
	if data == null or _collected_ids.has(data.echo_id):
		return
	_collected_ids[data.echo_id] = true
	_update_objective()
	GameEvents.echo_collected.emit(_collected_ids.size(), _total_echoes)
	if _toast_label != null:
		_toast_label.text = "ECO RECOLHIDO  %d/%d" % [_collected_ids.size(), _total_echoes]
		_toast_label.modulate.a = 1.0
		_toast_timer = 3.0


func _on_oil_changed(current: float, max_val: float) -> void:
	if _oil_bar != null:
		_oil_bar.max_value = max_val
	_oil_target = current


func _on_sanity_changed(current: float, max_val: float) -> void:
	if _sanity_bar != null:
		_sanity_bar.max_value = max_val
	_sanity_target = current


func _on_health_changed(current: float, max_val: float) -> void:
	if _health_bar != null:
		_health_bar.max_value = max_val
	_health_target = current


func _on_stamina_changed(current: float, max_val: float) -> void:
	if _stamina_bar != null:
		_stamina_bar.max_value = max_val
	_stamina_target = current


func _on_lighting_zone_changed(zone: int) -> void:
	if _zone_label == null or zone < 0 or zone >= ZONE_TEXTS.size():
		return
	_zone_label.text = ZONE_TEXTS[zone]
	_zone_label.add_theme_color_override("font_color", ZONE_COLORS[zone])


func _on_interaction_prompt_changed(prompt_text: String) -> void:
	if _prompt_label != null:
		_prompt_label.text = prompt_text
	_set_crosshair_active(not prompt_text.is_empty())


func _on_confession_triggered(text: String) -> void:
	if _confession_label == null:
		return
	_confession_label.text = text
	_confession_label.modulate.a = 1.0
	_confession_timer = 4.0


func _on_player_hidden_changed(is_hidden: bool) -> void:
	if _hiding_overlay != null:
		_hiding_overlay.visible = is_hidden
	if _vitals_panel != null:
		_vitals_panel.modulate.a = 0.35 if is_hidden else 1.0
	if _zone_label != null and is_hidden:
		_zone_label.text = "ESCONDIDO  —  [E] para sair"
		_zone_label.add_theme_color_override("font_color", UiTheme.INK)


func _on_time_of_day_changed(hour: float, is_night: bool, phase_name: String) -> void:
	if _clock_label == null:
		return
	var total_minutes: int = int(floorf(hour * 60.0))
	var hh: int = (total_minutes / 60) % 24
	var mm: int = total_minutes % 60
	var night_prefix: String = ""
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn != null and dn.has_method("get_night_number"):
		night_prefix = "NOITE %d | " % int(dn.call("get_night_number"))
	_clock_label.text = "%s%02d:%02d — %s" % [night_prefix, hh, mm, phase_name]
	_is_dawn_urgent = (hour >= 5.0 and hour < 6.0)
	var col: Color = Color(1.0, 0.56, 0.22) if _is_dawn_urgent else (Color(0.95, 0.32, 0.28) if is_night else UiTheme.AMBER)
	_clock_label.add_theme_color_override("font_color", col)


func _on_inventory_changed(bottles: int, bandages: int, keys: Array) -> void:
	_cached_bottles = bottles
	_cached_bandages = bandages
	_cached_keys_count = keys.size()
	_refresh_inventory_label()


func _on_tools_changed(tools: Array) -> void:
	_cached_tools_count = tools.size()
	_refresh_inventory_label()


func _refresh_inventory_label() -> void:
	if _inventory_label == null:
		return
	var key_str: String = "" if _cached_keys_count <= 0 else ("   |   Chaves: %d" % _cached_keys_count)
	var tool_str: String = "" if _cached_tools_count <= 0 else ("   |   Ferramentas: %d" % _cached_tools_count)
	_inventory_label.text = "[G] Garrafas: %d   |   [H] Bandagens: %d%s%s   |   [Tab] Mapa" % [_cached_bottles, _cached_bandages, tool_str, key_str]


func _on_radio_interference_changed(level: float) -> void:
	_radio_level = clampf(level, 0.0, 1.0)
	if _radio_label == null:
		return
	if _radio_level <= 0.03:
		_radio_label.visible = false
		return
	_radio_label.visible = true
	var bars: int = clampi(int(round(_radio_level * 4.0)), 1, 4)
	var meter: String = "|".repeat(bars) + ".".repeat(4 - bars)
	_radio_label.text = "RÁDIO [%s] AMEAÇA PRÓXIMA" % meter
	var col: Color = Color(1.0, 0.72, 0.25) if _radio_level < 0.6 else Color(1.0, 0.28, 0.22)
	_radio_label.add_theme_color_override("font_color", col)


func _on_status_message_requested(text: String) -> void:
	if _toast_label == null or text.is_empty():
		return
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_timer = 3.2
