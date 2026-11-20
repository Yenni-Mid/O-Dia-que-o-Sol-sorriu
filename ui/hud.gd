class_name GameHUD
extends Control
## HUD diegética de survival horror retrô PS1:
## - Canto inferior esquerdo: ícone do lampião + barra dourada de Óleo + Olho de Sanidade dinâmico;
## - Canto inferior direito: silhueta de postura (agachado/andando/correndo), barra de Vida, Fôlego e inventário compacto;
## - Centro: mira pontual + prompt em caixa alta estilizada;
## - Topo: objetivo da demo, relógio noturno/alvorada e medidor de interferência do rádio.

const UiTheme := preload("res://ui/ui_theme.gd")
const HudIcons := preload("res://ui/hud_icons.gd")

const COLOR_BONE: Color = Color(0.95, 0.91, 0.83)
const ZONE_TEXTS: Array[String] = ["SOL DIRETO", "ESCURIDÃO", "FOGO HUMANO"]
const ZONE_COLORS: Array[Color] = [Color(1.0, 0.84, 0.34), Color(0.68, 0.72, 0.80), Color(1.0, 0.66, 0.28)]

var _health_bar: ProgressBar
var _sanity_bar: ProgressBar
var _oil_bar: ProgressBar
var _stamina_bar: ProgressBar
var _stamina_row: HBoxContainer

var _health_target: float = 100.0
var _sanity_target: float = 100.0
var _oil_target: float = 100.0
var _stamina_target: float = 100.0

var _vitals_panel: Control
var _right_hud: Control
var _lantern_icon: TextureRect
var _sanity_eye_icon: TextureRect
var _posture_icon: TextureRect
var _zone_label: Label
var _prompt_label: Label
var _confession_label: Label
var _objective_label: Label
var _toast_label: Label
var _clock_label: Label
var _radio_label: Label
var _bottles_lbl: Label
var _bandages_lbl: Label
var _tools_box: HBoxContainer
var _tools_lbl: Label
var _keys_box: HBoxContainer
var _keys_lbl: Label
var _crosshair: ColorRect
var _crosshair_border: ColorRect
var _hiding_overlay: Control

var _confession_timer: float = 0.0
var _toast_timer: float = 0.0
var _pulse_time: float = 0.0
var _radio_level: float = 0.0
var _is_dawn_urgent: bool = false
var _eye_state: int = -1
var _in_sunlight: bool = false
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
	GameEvents.lantern_toggled.connect(_on_lantern_toggled)
	GameEvents.lantern_depleted.connect(_on_lantern_depleted)
	GameEvents.player_movement_state_changed.connect(_on_player_movement_state_changed)

	call_deferred("_count_echoes")
	call_deferred("_sync_initial_player_visuals")


func _sync_initial_player_visuals() -> void:
	var lantern: Node = get_tree().get_first_node_in_group("lantern")
	if lantern != null:
		_on_lantern_toggled(bool(lantern.get("is_lit")))
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.get("current_state") != null:
		_on_player_movement_state_changed(int(player.get("current_state")), 0.0, 1.0)


func _process(delta: float) -> void:
	_pulse_time += delta
	var k: float = clampf(8.0 * delta, 0.0, 1.0)

	if _health_bar != null:
		_health_bar.value = lerpf(_health_bar.value, _health_target, k)
		var low_hp: bool = _health_target / maxf(_health_bar.max_value, 0.001) < 0.3
		_health_bar.modulate = Color(1, 1, 1, 0.60 + 0.40 * absf(sin(_pulse_time * 5.0))) if low_hp else Color.WHITE

	if _sanity_bar != null:
		_sanity_bar.value = lerpf(_sanity_bar.value, _sanity_target, k)

	if _oil_bar != null:
		_oil_bar.value = lerpf(_oil_bar.value, _oil_target, k)
		var low_oil: bool = _oil_target / maxf(_oil_bar.max_value, 0.001) < 0.2
		_oil_bar.modulate = Color(1, 1, 1, 0.55 + 0.45 * absf(sin(_pulse_time * 3.5))) if low_oil else Color.WHITE

	if _stamina_bar != null and _stamina_row != null:
		_stamina_bar.value = lerpf(_stamina_bar.value, _stamina_target, clampf(12.0 * delta, 0.0, 1.0))
		var target_alpha: float = 0.94 if _stamina_target < 99.0 else 0.0
		_stamina_row.modulate.a = move_toward(_stamina_row.modulate.a, target_alpha, delta * 3.5)

	if _sanity_eye_icon != null:
		var san_ratio: float = _sanity_target / maxf(_sanity_bar.max_value if _sanity_bar != null else 100.0, 0.001)
		if _in_sunlight or san_ratio < 0.38:
			_sanity_eye_icon.position = Vector2(sin(_pulse_time * 37.0) * 1.4, cos(_pulse_time * 43.0) * 1.0)
		else:
			_sanity_eye_icon.position = Vector2.ZERO

	if _confession_timer > 0.0 and _confession_label != null:
		_confession_timer -= delta
		_confession_label.modulate.a = clampf(_confession_timer / 0.8, 0.0, 1.0)
	if _toast_timer > 0.0 and _toast_label != null:
		_toast_timer -= delta
		_toast_label.modulate.a = clampf(_toast_timer / 0.8, 0.0, 1.0)
	if _radio_label != null and _radio_level > 0.03:
		var freq: float = lerpf(4.0, 16.0, _radio_level)
		_radio_label.modulate.a = 0.55 + 0.45 * absf(sin(_pulse_time * freq))
	if _clock_label != null:
		_clock_label.modulate.a = (0.58 + 0.42 * absf(sin(_pulse_time * 5.0))) if _is_dawn_urgent else 1.0


# --------------------------------------------------------------------------- Layout

func _build_layout() -> void:
	# Frestas do guarda-roupa
	_hiding_overlay = Control.new()
	_hiding_overlay.name = "HidingOverlay"
	_hiding_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hiding_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hiding_overlay.visible = false
	add_child(_hiding_overlay)
	for s: Vector2 in [Vector2(0.0, 0.36), Vector2(0.43, 0.47), Vector2(0.53, 0.57), Vector2(0.64, 1.0)]:
		var slat: ColorRect = ColorRect.new()
		slat.color = Color(0.02, 0.015, 0.01, 0.94)
		slat.anchor_left = 0.0
		slat.anchor_right = 1.0
		slat.anchor_top = s.x
		slat.anchor_bottom = s.y
		slat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hiding_overlay.add_child(slat)

	# Mira pontual com borda preta
	_crosshair_border = ColorRect.new()
	_crosshair_border.name = "CrosshairBorder"
	_crosshair_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair_border.color = Color(0, 0, 0, 0.9)
	_crosshair_border.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_crosshair_border)

	_crosshair = ColorRect.new()
	_crosshair.name = "Crosshair"
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_crosshair)
	_set_crosshair_active(false)

	# Prompt central estilo PS1 ([E] LER ECO)
	_prompt_label = _make_label(20, COLOR_BONE)
	_prompt_label.add_theme_constant_override("outline_size", 6)
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_label.offset_left = -280.0
	_prompt_label.offset_right = 280.0
	_prompt_label.offset_top = 18.0
	_prompt_label.offset_bottom = 52.0
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

	# Toast de mensagens/coleta
	_toast_label = _make_label(19, Color(0.95, 0.88, 0.68))
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.offset_left = -360.0
	_toast_label.offset_right = 360.0
	_toast_label.offset_top = -126.0
	_toast_label.offset_bottom = -92.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.modulate.a = 0.0
	add_child(_toast_label)

	# Objetivo compacto (topo esquerdo com filete âmbar)
	var obj_panel: PanelContainer = PanelContainer.new()
	obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_panel.position = Vector2(22.0, 18.0)
	var obj_style: StyleBoxFlat = StyleBoxFlat.new()
	obj_style.bg_color = Color(0.03, 0.025, 0.02, 0.56)
	obj_style.border_color = UiTheme.AMBER
	obj_style.border_width_left = 3
	obj_style.content_margin_left = 10.0
	obj_style.content_margin_right = 12.0
	obj_style.content_margin_top = 5.0
	obj_style.content_margin_bottom = 5.0
	obj_panel.add_theme_stylebox_override("panel", obj_style)
	add_child(obj_panel)

	var obj_box: VBoxContainer = VBoxContainer.new()
	obj_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_box.add_theme_constant_override("separation", 0)
	obj_panel.add_child(obj_box)
	var obj_title: Label = _make_label(11, UiTheme.AMBER)
	obj_title.text = "OBJETIVO"
	obj_box.add_child(obj_title)
	_objective_label = _make_label(14, COLOR_BONE)
	_objective_label.text = "Sobreviva. Procure os Ecos deixados nas sombras."
	obj_box.add_child(_objective_label)

	# Topo direito (Relógio + Rádio)
	var top_right: VBoxContainer = VBoxContainer.new()
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_right.offset_right = -24.0
	top_right.offset_top = 18.0
	top_right.add_theme_constant_override("separation", 3)
	add_child(top_right)

	_clock_label = _make_label(14, UiTheme.AMBER)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.text = "NOITE 1 | 19:15 — NOITE [CULTISTAS À SOLTA]"
	top_right.add_child(_clock_label)

	_radio_label = _make_label(13, Color(1.0, 0.42, 0.25))
	_radio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_radio_label.text = ""
	_radio_label.visible = false
	top_right.add_child(_radio_label)

	# Canto inferior esquerdo: Lampião + Barra Óleo + Olho Sanidade (diegético sem caixa)
	var left_cluster: HBoxContainer = HBoxContainer.new()
	left_cluster.name = "BottomLeftVitals"
	left_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_cluster.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left_cluster.grow_vertical = Control.GROW_DIRECTION_BEGIN
	left_cluster.offset_left = 24.0
	left_cluster.offset_bottom = -20.0
	left_cluster.alignment = BoxContainer.ALIGNMENT_END
	left_cluster.add_theme_constant_override("separation", 20)
	add_child(left_cluster)
	_vitals_panel = left_cluster

	# Bloco Óleo
	var oil_block: HBoxContainer = HBoxContainer.new()
	oil_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oil_block.add_theme_constant_override("separation", 8)
	left_cluster.add_child(oil_block)

	_lantern_icon = TextureRect.new()
	_lantern_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lantern_icon.custom_minimum_size = Vector2(40.0, 52.0)
	_lantern_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lantern_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lantern_icon.texture = HudIcons.get_lantern_icon(false)
	oil_block.add_child(_lantern_icon)

	var oil_col: VBoxContainer = VBoxContainer.new()
	oil_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oil_col.alignment = BoxContainer.ALIGNMENT_END
	oil_col.add_theme_constant_override("separation", 3)
	oil_block.add_child(oil_col)

	var oil_title: Label = _make_label(17, COLOR_BONE)
	oil_title.text = "ÓLEO"
	oil_col.add_child(oil_title)

	_oil_bar = _make_textured_bar(
		Vector2(168.0, 19.0),
		Color(0.06, 0.04, 0.03, 0.92),
		HudIcons.get_bar_gradient(Color(1.0, 0.88, 0.42), Color(0.95, 0.56, 0.14), Color(0.68, 0.28, 0.06))
	)
	oil_col.add_child(_oil_bar)

	# Bloco Sanidade (Olho pixel-art + título + micro-barra + zona de luz)
	var sanity_block: VBoxContainer = VBoxContainer.new()
	sanity_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sanity_block.alignment = BoxContainer.ALIGNMENT_END
	sanity_block.add_theme_constant_override("separation", 2)
	left_cluster.add_child(sanity_block)

	var eye_holder: Control = Control.new()
	eye_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eye_holder.custom_minimum_size = Vector2(56.0, 36.0)
	eye_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sanity_block.add_child(eye_holder)

	_sanity_eye_icon = TextureRect.new()
	_sanity_eye_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sanity_eye_icon.size = Vector2(56.0, 36.0)
	_sanity_eye_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sanity_eye_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sanity_eye_icon.texture = HudIcons.get_sanity_eye_icon(0)
	eye_holder.add_child(_sanity_eye_icon)

	var san_title: Label = _make_label(14, COLOR_BONE)
	san_title.text = "SANIDADE"
	san_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sanity_block.add_child(san_title)

	_sanity_bar = _make_textured_bar(
		Vector2(92.0, 6.0),
		Color(0.06, 0.05, 0.05, 0.88),
		HudIcons.get_bar_gradient(Color(0.76, 0.86, 0.96), Color(0.45, 0.62, 0.82), Color(0.26, 0.38, 0.56))
	)
	_sanity_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sanity_block.add_child(_sanity_bar)

	_zone_label = _make_label(11, ZONE_COLORS[1])
	_zone_label.text = ZONE_TEXTS[1]
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sanity_block.add_child(_zone_label)

	# Canto inferior direito: Itens compactos + Silhueta de Postura + Vida
	var right_cluster: VBoxContainer = VBoxContainer.new()
	right_cluster.name = "BottomRightVitals"
	right_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_cluster.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right_cluster.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_cluster.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right_cluster.offset_right = -24.0
	right_cluster.offset_bottom = -20.0
	right_cluster.alignment = BoxContainer.ALIGNMENT_END
	right_cluster.add_theme_constant_override("separation", 6)
	add_child(right_cluster)
	_right_hud = right_cluster

	# Linha de inventário tático com mini-ícones
	var inv_strip: HBoxContainer = HBoxContainer.new()
	inv_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_strip.alignment = BoxContainer.ALIGNMENT_END
	inv_strip.add_theme_constant_override("separation", 12)
	right_cluster.add_child(inv_strip)

	_bottles_lbl = _make_item_badge(inv_strip, "bottle", "[G] 1")
	_bandages_lbl = _make_item_badge(inv_strip, "bandage", "[H] 1")
	_tools_lbl = _make_item_badge(inv_strip, "tool", "0")
	_tools_box = _tools_lbl.get_parent() as HBoxContainer
	_tools_box.visible = false
	_keys_lbl = _make_item_badge(inv_strip, "key", "0")
	_keys_box = _keys_lbl.get_parent() as HBoxContainer
	_keys_box.visible = false
	_make_item_badge(inv_strip, "map", "[TAB]")

	# Linha Postura + Barra Vida
	var health_row: HBoxContainer = HBoxContainer.new()
	health_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_row.alignment = BoxContainer.ALIGNMENT_END
	health_row.add_theme_constant_override("separation", 8)
	right_cluster.add_child(health_row)

	_posture_icon = TextureRect.new()
	_posture_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_posture_icon.custom_minimum_size = Vector2(36.0, 40.0)
	_posture_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_posture_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_posture_icon.texture = HudIcons.get_posture_icon(1)
	health_row.add_child(_posture_icon)

	var health_col: VBoxContainer = VBoxContainer.new()
	health_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_col.alignment = BoxContainer.ALIGNMENT_END
	health_col.add_theme_constant_override("separation", 3)
	health_row.add_child(health_col)

	var life_header: HBoxContainer = HBoxContainer.new()
	life_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	life_header.alignment = BoxContainer.ALIGNMENT_END
	life_header.add_theme_constant_override("separation", 10)
	health_col.add_child(life_header)

	_stamina_row = HBoxContainer.new()
	_stamina_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_row.modulate.a = 0.0
	life_header.add_child(_stamina_row)

	_stamina_bar = _make_textured_bar(
		Vector2(86.0, 6.0),
		Color(0.05, 0.05, 0.04, 0.86),
		HudIcons.get_bar_gradient(Color(0.76, 0.88, 0.46), Color(0.56, 0.72, 0.30), Color(0.38, 0.48, 0.18))
	)
	_stamina_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stamina_row.add_child(_stamina_bar)

	var life_title: Label = _make_label(17, COLOR_BONE)
	life_title.text = "VIDA"
	life_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	life_header.add_child(life_title)

	_health_bar = _make_textured_bar(
		Vector2(182.0, 19.0),
		Color(0.08, 0.03, 0.03, 0.92),
		HudIcons.get_bar_gradient(Color(0.84, 0.24, 0.20), Color(0.62, 0.11, 0.10), Color(0.36, 0.05, 0.05))
	)
	health_col.add_child(_health_bar)


func _make_label(font_size: int, color: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("outline_size", 5)
	return lbl


func _make_textured_bar(min_size: Vector2, bg_color: Color, grad_tex: ImageTexture) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = min_size
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0

	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.border_color = Color(0.03, 0.02, 0.02, 1.0)
	bg.set_border_width_all(3)
	bar.add_theme_stylebox_override("background", bg)

	var fill: StyleBoxTexture = StyleBoxTexture.new()
	fill.texture = grad_tex
	fill.content_margin_top = 3.0
	fill.content_margin_bottom = 3.0
	fill.content_margin_left = 3.0
	fill.content_margin_right = 3.0
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _make_item_badge(parent_box: HBoxContainer, icon_kind: String, initial_txt: String) -> Label:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	parent_box.add_child(row)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.custom_minimum_size = Vector2(20.0, 20.0)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.texture = HudIcons.get_item_icon(icon_kind)
	row.add_child(icon_rect)

	var lbl: Label = _make_label(13, COLOR_BONE)
	lbl.text = initial_txt
	row.add_child(lbl)
	return lbl


func _set_crosshair_active(active: bool) -> void:
	if _crosshair == null or _crosshair_border == null:
		return
	var s: float = 5.0 if active else 3.0
	var b: float = s + 2.0
	_crosshair_border.offset_left = -b * 0.5
	_crosshair_border.offset_top = -b * 0.5
	_crosshair_border.offset_right = b * 0.5
	_crosshair_border.offset_bottom = b * 0.5

	_crosshair.offset_left = -s * 0.5
	_crosshair.offset_top = -s * 0.5
	_crosshair.offset_right = s * 0.5
	_crosshair.offset_bottom = s * 0.5
	_crosshair.color = Color(1.0, 0.80, 0.35, 1.0) if active else Color(0.96, 0.94, 0.88, 0.90)


func _refresh_sanity_eye() -> void:
	if _sanity_eye_icon == null:
		return
	var max_v: float = _sanity_bar.max_value if _sanity_bar != null else 100.0
	var ratio: float = _sanity_target / maxf(max_v, 0.001)
	var next_state: int = 0
	if _in_sunlight or ratio < 0.35:
		next_state = 2
	elif ratio < 0.65:
		next_state = 1
	if next_state != _eye_state:
		_eye_state = next_state
		_sanity_eye_icon.texture = HudIcons.get_sanity_eye_icon(next_state)


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
	_refresh_sanity_eye()


func _on_health_changed(current: float, max_val: float) -> void:
	if _health_bar != null:
		_health_bar.max_value = max_val
	_health_target = current


func _on_stamina_changed(current: float, max_val: float) -> void:
	if _stamina_bar != null:
		_stamina_bar.max_value = max_val
	_stamina_target = current


func _on_lighting_zone_changed(zone: int) -> void:
	_in_sunlight = (zone == 0)
	_refresh_sanity_eye()
	if _zone_label == null or zone < 0 or zone >= ZONE_TEXTS.size():
		return
	_zone_label.text = ZONE_TEXTS[zone]
	_zone_label.add_theme_color_override("font_color", ZONE_COLORS[zone])


func _on_interaction_prompt_changed(prompt_text: String) -> void:
	if _prompt_label != null:
		_prompt_label.text = prompt_text.to_upper() if not prompt_text.is_empty() else ""
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
	if _right_hud != null:
		_right_hud.modulate.a = 0.35 if is_hidden else 1.0
	if _zone_label != null and is_hidden:
		_zone_label.text = "ESCONDIDO"
		_zone_label.add_theme_color_override("font_color", COLOR_BONE)


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
	if _bottles_lbl != null:
		_bottles_lbl.text = "[G] %d" % bottles
	if _bandages_lbl != null:
		_bandages_lbl.text = "[H] %d" % bandages
	if _keys_lbl != null and _keys_box != null:
		_keys_box.visible = not keys.is_empty()
		_keys_lbl.text = "%d" % keys.size()


func _on_tools_changed(tools: Array) -> void:
	if _tools_lbl != null and _tools_box != null:
		_tools_box.visible = not tools.is_empty()
		_tools_lbl.text = "%d" % tools.size()


func _on_lantern_toggled(lit: bool) -> void:
	if _lantern_icon != null:
		_lantern_icon.texture = HudIcons.get_lantern_icon(lit)


func _on_lantern_depleted() -> void:
	_on_lantern_toggled(false)


func _on_player_movement_state_changed(state: int, _noise_r: float, _vis_mult: float) -> void:
	if _posture_icon != null:
		_posture_icon.texture = HudIcons.get_posture_icon(state)


func _on_radio_interference_changed(level: float) -> void:
	_radio_level = clampf(level, 0.0, 1.0)
	if _radio_label == null:
		return
	if _radio_level <= 0.03:
		_radio_label.visible = false
		return
	_radio_label.visible = true
	var bars: int = clampi(int(round(_radio_level * 4.0)), 1, 4)
	var meter: String = "▮".repeat(bars) + "▯".repeat(4 - bars)
	_radio_label.text = "[RÁDIO] %s AMEAÇA PRÓXIMA" % meter
	var col: Color = Color(1.0, 0.72, 0.25) if _radio_level < 0.6 else Color(1.0, 0.28, 0.22)
	_radio_label.add_theme_color_override("font_color", col)


func _on_status_message_requested(text: String) -> void:
	if _toast_label == null or text.is_empty():
		return
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_timer = 3.2
