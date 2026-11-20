extends Control
## Diário de Campo e Mapa Rabiscado [Tab]:
## Aba 1: Mapa em tempo real do quarteirão + chaves e itens.
## Aba 2: Arquivo completo de Ecos já descobertos no SaveManager.

const UiTheme := preload("res://ui/ui_theme.gd")

@onready var tab_map_btn: Button = get_node_or_null("Panel/VBox/TopBar/MapTabBtn") as Button
@onready var tab_echoes_btn: Button = get_node_or_null("Panel/VBox/TopBar/EchoesTabBtn") as Button
@onready var close_btn: Button = get_node_or_null("Panel/VBox/TopBar/CloseBtn") as Button

@onready var map_view: Control = get_node_or_null("Panel/VBox/Content/MapView") as Control
@onready var map_canvas: Control = get_node_or_null("Panel/VBox/Content/MapView/MapCanvas") as Control
@onready var bag_summary: Label = get_node_or_null("Panel/VBox/Content/MapView/SideNotes/BagSummary") as Label

@onready var echoes_view: Control = get_node_or_null("Panel/VBox/Content/EchoesView") as Control
@onready var echo_list: VBoxContainer = get_node_or_null("Panel/VBox/Content/EchoesView/EchoListScroll/EchoList") as VBoxContainer
@onready var echo_title: Label = get_node_or_null("Panel/VBox/Content/EchoesView/DetailBox/EchoTitle") as Label
@onready var echo_body: Label = get_node_or_null("Panel/VBox/Content/EchoesView/DetailBox/EchoBody") as Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	theme = UiTheme.get_theme()
	if tab_map_btn != null:
		tab_map_btn.pressed.connect(_show_map_tab)
	if tab_echoes_btn != null:
		tab_echoes_btn.pressed.connect(_show_echoes_tab)
	if close_btn != null:
		close_btn.pressed.connect(_close_journal)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_journal"):
		if visible:
			_close_journal()
			get_viewport().set_input_as_handled()
		elif _can_open_journal():
			_open_journal()
			get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_close_journal()
		get_viewport().set_input_as_handled()


func _can_open_journal() -> bool:
	if get_tree().paused:
		return false
	var ui_layer: Node = get_parent()
	if ui_layer != null:
		for other_name: String in ["EchoReaderUI", "VHSTapeOverlay", "PauseMenu", "KeypadUI"]:
			var other: Control = ui_layer.get_node_or_null(other_name) as Control
			if other != null and other.visible:
				return false
	return true


func _open_journal() -> void:
	_show_map_tab()
	_refresh_summary()
	_rebuild_echo_list()
	if map_canvas != null:
		map_canvas.queue_redraw()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_paper()


func _close_journal() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	AudioManager.play_paper()


func _show_map_tab() -> void:
	if map_view != null:
		map_view.visible = true
	if echoes_view != null:
		echoes_view.visible = false
	if map_canvas != null:
		map_canvas.queue_redraw()
	AudioManager.play_ui_click()


func _show_echoes_tab() -> void:
	if map_view != null:
		map_view.visible = false
	if echoes_view != null:
		echoes_view.visible = true
	_rebuild_echo_list()
	AudioManager.play_ui_click()


func _refresh_summary() -> void:
	if bag_summary == null:
		return
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
	var keys_str: String = "Nenhuma" if keys.is_empty() else ", ".join(PackedStringArray(keys))
	var tool_names: Array[String] = []
	for t: Variant in tools:
		var tid: String = str(t)
		if tid == "bolt_cutters":
			tool_names.append("Alicate de Corte")
		elif tid == "crowbar":
			tool_names.append("Pé de Cabra")
		elif tid == "radio":
			tool_names.append("Rádio")
		else:
			tool_names.append(tid)
	var tools_str: String = "Nenhuma" if tool_names.is_empty() else ", ".join(PackedStringArray(tool_names))
	var hour_str: String = "--:--"
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn != null and dn.has_method("get_formatted_time"):
		hour_str = str(dn.call("get_formatted_time"))

	bag_summary.text = "RELÓGIO: %s\n\nITENS DE CAMPO:\n• [G] Garrafas (isca): %d\n• [H] Bandagens (+40 HP): %d\n• Ferramentas: %s\n• Chaves: %s\n\nANOTAÇÕES:\n• Saia da Casa à noite (19:15) e explore o quarteirão.\n• Ao clarear (05:00–06:00), volte para dentro da Casa!\n• Os Cultistas caçam a luz do lampião à noite.\n• De dia, o Sol Sorridente ainda queima quem ficar fora.\n\n[Q / C] Espreitar esquinas." % [
		hour_str,
		bottles,
		bandages,
		tools_str,
		keys_str,
	]


func _rebuild_echo_list() -> void:
	if echo_list == null:
		return
	for c: Node in echo_list.get_children():
		c.queue_free()

	var records: Dictionary = SaveManager.collected_echo_records
	if records.is_empty():
		if echo_title != null:
			echo_title.text = "Nenhum Eco recolhido ainda"
		if echo_body != null:
			echo_body.text = "Explore as sombras da casa, o abrigo, o ponto de ônibus, a pracinha e o porão para encontrar os diários deixados pelos sobreviventes."
		return

	var first_selected: bool = false
	for echo_id: Variant in records.keys():
		var rec: Dictionary = records[echo_id] as Dictionary
		var author: String = str(rec.get("author", str(echo_id)))
		var date_str: String = str(rec.get("date", ""))
		var body_str: String = str(rec.get("text", ""))
		var btn: Button = Button.new()
		btn.text = author
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func() -> void:
			_select_echo_detail(author, date_str, body_str)
		)
		echo_list.add_child(btn)
		if not first_selected:
			first_selected = true
			_select_echo_detail(author, date_str, body_str)


func _select_echo_detail(author: String, date_str: String, body_str: String) -> void:
	AudioManager.play_ui_click()
	if echo_title != null:
		echo_title.text = "%s — %s" % [author, date_str]
	if echo_body != null:
		echo_body.text = body_str
