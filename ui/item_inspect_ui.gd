class_name ItemInspectUI
extends Control
## Visualizador 3D de objetos-chave estilo Resident Evil / Silent Hill:
## Gira o modelo 3D livremente com arraste do mouse ou teclas W/A/S/D, exibindo título e anotações.

const UiTheme := preload("res://ui/ui_theme.gd")

var _dragging: bool = false
var _rot_x: float = -0.25
var _rot_y: float = 0.25

var _viewport: SubViewport
var _model_pivot: Node3D
var _title_label: Label
var _desc_label: Label
var _back_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	_build_ui()
	GameEvents.item_inspect_requested.connect(_on_item_inspect_requested)


func _exit_tree() -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_clear_model_pivot()
	_model_pivot = null
	_viewport = null


func _process(delta: float) -> void:
	if not visible or _model_pivot == null:
		return
	var rx: float = 0.0
	var ry: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		ry -= 2.0 * delta
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		ry += 2.0 * delta
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		rx -= 2.0 * delta
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		rx += 2.0 * delta
	if not is_zero_approx(rx) or not is_zero_approx(ry):
		_rot_x = clampf(_rot_x + rx, -1.35, 1.35)
		_rot_y += ry
		_apply_pivot_rotation()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		_close_inspect()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_rot_y += mm.relative.x * 0.012
		_rot_x = clampf(_rot_x + mm.relative.y * 0.012, -1.35, 1.35)
		_apply_pivot_rotation()
		get_viewport().set_input_as_handled()


func _on_item_inspect_requested(payload: Dictionary) -> void:
	var item_id: String = str(payload.get("item_id", "leo_photo"))
	var title_txt: String = str(payload.get("title", "OBJETO"))
	var desc_txt: String = str(payload.get("description", ""))
	var back_txt: String = str(payload.get("back_note", ""))

	if _title_label != null:
		_title_label.text = title_txt.to_upper()
	if _desc_label != null:
		_desc_label.text = desc_txt
	if _back_label != null:
		_back_label.text = back_txt
		_back_label.visible = not back_txt.is_empty()

	_rot_x = -0.18
	_rot_y = 0.22
	_rebuild_inspect_model(item_id)
	_apply_pivot_rotation()

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_paper()


func _close_inspect() -> void:
	visible = false
	_dragging = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	AudioManager.play_menu_back()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _apply_pivot_rotation() -> void:
	if _model_pivot != null:
		_model_pivot.rotation = Vector3(_rot_x, _rot_y, 0.0)


func _clear_model_pivot() -> void:
	if _model_pivot == null:
		return
	for ch: Node in _model_pivot.get_children():
		ch.queue_free()


func _rebuild_inspect_model(item_id: String) -> void:
	_clear_model_pivot()
	if _model_pivot == null:
		return

	if item_id == "leo_photo":
		# Foto Polaroid/retrato do Leo com verso rabiscado
		var paper_mat: StandardMaterial3D = StandardMaterial3D.new()
		paper_mat.albedo_color = Color(0.88, 0.84, 0.76)
		paper_mat.roughness = 0.85

		var back_mat: StandardMaterial3D = StandardMaterial3D.new()
		back_mat.albedo_color = Color(0.76, 0.70, 0.56)
		back_mat.roughness = 0.9

		var photo_tex: ImageTexture = _make_leo_photo_texture()
		var face_mat: StandardMaterial3D = StandardMaterial3D.new()
		face_mat.albedo_texture = photo_tex
		face_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		face_mat.roughness = 0.7

		_add_mesh_box(Vector3(0.46, 0.54, 0.012), Vector3.ZERO, paper_mat)
		_add_mesh_box(Vector3(0.38, 0.38, 0.006), Vector3(0.0, 0.04, 0.008), face_mat)
		_add_mesh_box(Vector3(0.36, 0.40, 0.005), Vector3(0.0, 0.0, -0.008), back_mat)
	else:
		# Recorte de jornal do Eclipse Solar (17/10)
		var news_tex: ImageTexture = _make_newspaper_texture()
		var news_mat: StandardMaterial3D = StandardMaterial3D.new()
		news_mat.albedo_texture = news_tex
		news_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		news_mat.roughness = 0.9
		_add_mesh_box(Vector3(0.56, 0.42, 0.012), Vector3.ZERO, news_mat)


func _add_mesh_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.material_override = mat
	_model_pivot.add_child(m)


func _make_leo_photo_texture() -> ImageTexture:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in range(32):
		for x: int in range(32):
			var c: Color = Color(0.18, 0.22, 0.26, 1.0)
			var dx: float = float(x - 16)
			if y >= 22 and absf(dx) <= 9.0 + float(y - 22) * 0.5:
				c = Color(0.24, 0.36, 0.54, 1.0)
			if y >= 18 and y <= 22 and absf(dx) <= 2.4:
				c = Color(0.76, 0.60, 0.46, 1.0)
			var hd: float = (dx * dx) / (5.4 * 5.4) + (float(y - 13) * float(y - 13)) / (6.2 * 6.2)
			if hd <= 1.0:
				c = Color(0.82, 0.66, 0.52, 1.0)
				if y <= 9 or (y <= 12 and absf(dx) >= 4.2):
					c = Color(0.22, 0.14, 0.09, 1.0)
				if y == 12 and (absf(dx + 2.0) <= 0.7 or absf(dx - 2.0) <= 0.7):
					c = Color(0.08, 0.06, 0.05, 1.0)
				if y == 16 and absf(dx) <= 1.8:
					c = Color(0.55, 0.26, 0.22, 1.0)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _make_newspaper_texture() -> ImageTexture:
	var img: Image = Image.create(48, 36, false, Image.FORMAT_RGBA8)
	for y: int in range(36):
		for x: int in range(48):
			var c: Color = Color(0.78, 0.74, 0.64, 1.0)
			if y >= 3 and y <= 7 and x >= 4 and x <= 43:
				c = Color(0.16, 0.14, 0.12, 1.0) # manchete
			elif x >= 26 and x <= 42 and y >= 11 and y <= 26:
				var d: float = Vector2(float(x - 34), float(y - 18)).length()
				c = Color(0.92, 0.76, 0.22, 1.0) if d <= 6.5 else Color(0.24, 0.22, 0.20, 1.0)
			elif x >= 4 and x <= 23 and y >= 11 and y <= 31 and (y % 3 == 0):
				c = Color(0.28, 0.26, 0.24, 1.0) # linhas de texto
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _build_ui() -> void:
	var dimmer: ColorRect = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.015, 0.012, 0.01, 0.88)
	add_child(dimmer)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -350.0
	panel.offset_top = -245.0
	panel.offset_right = 350.0
	panel.offset_bottom = 245.0
	var p_style: StyleBoxFlat = UiTheme.make_box(Color(0.045, 0.04, 0.035, 0.96), UiTheme.AMBER, 2, 14)
	panel.add_theme_stylebox_override("panel", p_style)
	add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", UiTheme.AMBER)
	vbox.add_child(_title_label)

	var vp_container: SubViewportContainer = SubViewportContainer.new()
	vp_container.custom_minimum_size = Vector2(660.0, 260.0)
	vp_container.stretch = true
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(vp_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(330, 130)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp_container.add_child(_viewport)

	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0.0, 0.0, 0.92)
	cam.fov = 45.0
	_viewport.add_child(cam)

	var light: OmniLight3D = OmniLight3D.new()
	light.position = Vector3(0.6, 0.6, 1.2)
	light.light_color = Color(1.0, 0.88, 0.72)
	light.light_energy = 1.9
	light.omni_range = 4.0
	_viewport.add_child(light)

	_model_pivot = Node3D.new()
	_viewport.add_child(_model_pivot)

	_desc_label = Label.new()
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 15)
	_desc_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.83))
	vbox.add_child(_desc_label)

	_back_label = Label.new()
	_back_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_back_label.add_theme_font_size_override("font_size", 13)
	_back_label.add_theme_color_override("font_color", Color(0.90, 0.68, 0.36))
	vbox.add_child(_back_label)

	var hint_row: HBoxContainer = HBoxContainer.new()
	hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hint_row.add_theme_constant_override("separation", 16)
	vbox.add_child(hint_row)

	var hint: Label = Label.new()
	hint.text = "Arraste com o mouse ou [WASD] para girar"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.68, 0.64, 0.56))
	hint_row.add_child(hint)

	var close_btn: Button = Button.new()
	close_btn.text = "Guardar [E / ESC]"
	close_btn.pressed.connect(_close_inspect)
	hint_row.add_child(close_btn)
