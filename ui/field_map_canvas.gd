extends Control
## Tela do Mapa Rabiscado à Mão de todo o quarteirão expandido (zoom e arraste).

const WORLD_MIN: Vector2 = Vector2(-68.0, -78.0)
const WORLD_MAX: Vector2 = Vector2(72.0, 27.0)
const PAPER_BG: Color = Color(0.84, 0.79, 0.65)
const GRID_COL: Color = Color(0.58, 0.64, 0.68, 0.28)
const INK_COL: Color = Color(0.18, 0.13, 0.08)
const SUB_COL: Color = Color(0.18, 0.30, 0.45, 0.80)

var _zoom: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _dragging: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func reset_view() -> void:
	_zoom = 1.0
	_pan_offset = Vector2.ZERO
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom = clampf(_zoom * 1.15, 0.7, 2.4)
			queue_redraw()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom = clampf(_zoom / 1.15, 0.7, 2.4)
			queue_redraw()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			reset_view()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_pan_offset += mm.relative
		var limit: Vector2 = size * 0.45 * _zoom
		_pan_offset.x = clampf(_pan_offset.x, -limit.x, limit.x)
		_pan_offset.y = clampf(_pan_offset.y, -limit.y, limit.y)
		queue_redraw()
		accept_event()


func _world_to_canvas(world_xz: Vector2) -> Vector2:
	var pad: float = 20.0
	var draw_w: float = maxf(10.0, size.x - pad * 2.0)
	var draw_h: float = maxf(10.0, size.y - pad * 2.0)
	var span: Vector2 = WORLD_MAX - WORLD_MIN
	var nx: float = (world_xz.x - WORLD_MIN.x) / span.x
	var ny: float = (world_xz.y - WORLD_MIN.y) / span.y
	var base: Vector2 = Vector2(pad + nx * draw_w, pad + ny * draw_h)
	var center: Vector2 = size * 0.5
	return center + (base - center) * _zoom + _pan_offset


func _world_rect(x0: float, z0: float, x1: float, z1: float) -> Rect2:
	var p0: Vector2 = _world_to_canvas(Vector2(x0, z0))
	var p1: Vector2 = _world_to_canvas(Vector2(x1, z1))
	return Rect2(p0, p1 - p0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER_BG, true)
	var step: float = 24.0
	var x_line: float = step
	while x_line < size.x:
		draw_line(Vector2(x_line, 0.0), Vector2(x_line, size.y), GRID_COL, 1.0)
		x_line += step
	var y_line: float = step
	while y_line < size.y:
		draw_line(Vector2(0.0, y_line), Vector2(size.x, y_line), GRID_COL, 1.0)
		y_line += step

	var fnt: Font = get_theme_default_font()

	# Ruas, avenidas e travessas urbanas
	_draw_area(-66.0, 10.6, 70.0, 15.2, Color(0.56, 0.52, 0.46, 0.55), INK_COL, "AVENIDA PRINCIPAL", fnt, 10)
	_draw_area(-26.0, -19.5, 36.0, -15.5, Color(0.56, 0.52, 0.46, 0.45), INK_COL, "RUA TRANSVERSAL NORTE", fnt, 8)
	_draw_area(-29.8, -19.5, -26.2, 9.6, Color(0.56, 0.52, 0.46, 0.42), INK_COL, "", fnt, 8)
	_draw_area(-2.6, -48.0, 2.6, -20.0, Color(0.58, 0.55, 0.49, 0.65), INK_COL, "", fnt, 9)

	# Quarteirão Central & Becos Urbanos
	_draw_area(-3.0, 15.5, 3.0, 25.0, Color(0.65, 0.60, 0.50, 0.7), INK_COL, "ABRIGO", fnt, 8)
	_draw_area(-25.5, 16.5, -18.5, 23.5, Color(0.60, 0.54, 0.46, 0.65), INK_COL, "", fnt, 8)
	_draw_area(-15.5, 16.5, -3.2, 23.5, Color(0.60, 0.54, 0.46, 0.65), INK_COL, "QUARTEIRÃO SUL", fnt, 8)
	_draw_area(3.2, 16.5, 14.5, 23.5, Color(0.60, 0.54, 0.46, 0.65), INK_COL, "", fnt, 8)
	_draw_area(17.5, 16.5, 35.5, 23.5, Color(0.60, 0.54, 0.46, 0.65), INK_COL, "LOJAS SUL", fnt, 8)
	_draw_area(-8.0, -7.0, 8.0, 7.0, Color(0.72, 0.64, 0.48, 0.85), INK_COL, "CASA", fnt, 10)
	_draw_area(-14.5, -7.0, -10.9, 7.0, Color(0.64, 0.55, 0.46, 0.80), INK_COL, "SOBRADO", fnt, 7)
	_draw_area(10.9, -7.0, 14.5, 7.0, Color(0.64, 0.55, 0.46, 0.80), INK_COL, "SOBRADO", fnt, 7)
	_draw_area(-25.0, -14.8, -10.9, -10.4, Color(0.60, 0.52, 0.44, 0.78), INK_COL, "CORTIÇOS", fnt, 7)
	_draw_area(10.9, -14.8, 25.0, -10.4, Color(0.60, 0.52, 0.44, 0.78), INK_COL, "CORTIÇOS", fnt, 7)
	_draw_area(-25.5, -7.5, -17.5, 7.0, Color(0.72, 0.58, 0.48, 0.85), INK_COL, "MERCADO", fnt, 9)
	_draw_area(17.5, -7.0, 25.5, 7.5, Color(0.68, 0.62, 0.54, 0.80), INK_COL, "VIZINHA", fnt, 8)
	_draw_area(25.5, -14.5, 36.0, 9.6, Color(0.64, 0.60, 0.56, 0.75), INK_COL, "PRACINHA", fnt, 9)

	# Zona Oeste: Posto Sol & Óleo
	_draw_area(-57.0, -16.5, -32.0, 9.6, Color(0.60, 0.58, 0.52, 0.50), INK_COL, "", fnt, 9)
	_draw_area(-57.0, -6.0, -46.0, 4.0, Color(0.74, 0.50, 0.42, 0.85), INK_COL, "POSTO", fnt, 9)
	_draw_area(-41.0, 0.5, -32.0, 7.5, Color(0.78, 0.45, 0.35, 0.75), INK_COL, "BOMBAS", fnt, 8)

	# Zona Norte: Escola Municipal Aurora Solar
	_draw_area(-26.0, -48.0, 24.0, -20.0, Color(0.58, 0.56, 0.50, 0.40), INK_COL, "PÁTIO DA ESCOLA", fnt, 9)
	_draw_area(-24.0, -72.0, 22.0, -48.0, Color(0.70, 0.66, 0.52, 0.88), INK_COL, "ESCOLA MUNICIPAL AURORA SOLAR", fnt, 10)

	# Zona Leste: Cemitério e Capela
	_draw_area(36.0, -24.0, 66.0, 9.6, Color(0.52, 0.54, 0.48, 0.45), INK_COL, "", fnt, 9)
	_draw_area(44.0, -21.0, 60.0, -3.0, Color(0.72, 0.62, 0.46, 0.88), INK_COL, "CAPELA", fnt, 10)
	if fnt != null:
		draw_string(fnt, _world_to_canvas(Vector2(38.5, 4.5)), "CEMITÉRIO", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK_COL)

	# Subsolo: Porão, Túnel e Rede de Esgotos
	_draw_dashed_box(-8.0, -7.2, 4.0, 1.0, SUB_COL)
	_draw_dashed_box(-44.4, -6.8, -8.0, -3.8, SUB_COL)
	_draw_dashed_box(-47.6, -47.6, -44.4, -3.7, SUB_COL)
	_draw_dashed_box(-53.6, -29.0, -47.6, -23.0, SUB_COL)
	_draw_dashed_box(-44.4, -15.4, -38.4, -12.6, SUB_COL)
	_draw_dashed_box(-44.4, -47.4, -38.4, -44.6, SUB_COL)

	# Tambores-Fogueira em tempo real
	for b_node: Node in get_tree().get_nodes_in_group("fire_barrel"):
		if b_node is Node3D:
			var b3: Node3D = b_node as Node3D
			var b_pos: Vector2 = _world_to_canvas(Vector2(b3.global_position.x, b3.global_position.z))
			var lit: bool = bool(b3.get("is_lit"))
			draw_circle(b_pos, 4.5 if lit else 3.5, Color(1.0, 0.48, 0.12) if lit else Color(0.35, 0.32, 0.28))
			draw_arc(b_pos, 5.0 if lit else 3.8, 0.0, TAU, 10, INK_COL, 1.2)

	# Jogador em tempo real
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if player != null:
		var p_pos: Vector2 = _world_to_canvas(Vector2(player.global_position.x, player.global_position.z))
		var fwd3: Vector3 = -player.global_transform.basis.z
		var fwd2: Vector2 = Vector2(fwd3.x, fwd3.z)
		if fwd2.length_squared() < 0.001:
			fwd2 = Vector2(0.0, -1.0)
		fwd2 = fwd2.normalized()
		var side2: Vector2 = Vector2(-fwd2.y, fwd2.x)

		var tip: Vector2 = p_pos + fwd2 * 11.0
		var wing_l: Vector2 = p_pos - fwd2 * 4.5 + side2 * 6.0
		var wing_r: Vector2 = p_pos - fwd2 * 4.5 - side2 * 6.0
		draw_colored_polygon(PackedVector2Array([tip, wing_l, wing_r]), Color(0.82, 0.14, 0.10))
		draw_circle(p_pos, 4.0, Color(0.98, 0.88, 0.35))
		draw_arc(p_pos, 4.0, 0.0, TAU, 12, INK_COL, 1.5)
		if fnt != null:
			var label_y: String = "ESGOTO" if player.global_position.y < -1.2 else ("2º ANDAR" if player.global_position.y > 2.5 else "VOCÊ")
			draw_string(fnt, p_pos + Vector2(8.0, 4.0), label_y, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.70, 0.10, 0.08))

	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), INK_COL, false, 2.0)
	if fnt != null:
		draw_string(fnt, Vector2(size.x * 0.5 - 105.0, 18.0), "↑ NORTE — ESCOLA / TORRE", HORIZONTAL_ALIGNMENT_CENTER, 210, 11, Color(0.58, 0.12, 0.08))
		draw_string(fnt, Vector2(12.0, size.y - 10.0), "Scroll: Zoom (%.1fx) | Arrastar: Mover | Dir.: Resetar" % _zoom, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SUB_COL)


func _draw_area(x0: float, z0: float, x1: float, z1: float, fill: Color, border: Color, label: String, fnt: Font, font_size: int) -> void:
	var r: Rect2 = _world_rect(x0, z0, x1, z1)
	draw_rect(r, fill, true)
	draw_rect(r, border, false, 1.5)
	if not label.is_empty() and fnt != null and r.size.x > 26.0:
		var center: Vector2 = r.position + Vector2(3.0, r.size.y * 0.5 + float(font_size) * 0.35)
		draw_string(fnt, center, label, HORIZONTAL_ALIGNMENT_CENTER, int(maxf(28.0, r.size.x - 6.0)), font_size, border)


func _draw_dashed_box(x0: float, z0: float, x1: float, z1: float, col: Color) -> void:
	var r: Rect2 = _world_rect(x0, z0, x1, z1)
	draw_rect(r, Color(col.r, col.g, col.b, 0.14), true)
	draw_dashed_line(r.position, r.position + Vector2(r.size.x, 0), col, 1.6, 4.0)
	draw_dashed_line(r.position + Vector2(r.size.x, 0), r.position + r.size, col, 1.6, 4.0)
	draw_dashed_line(r.position + r.size, r.position + Vector2(0, r.size.y), col, 1.6, 4.0)
	draw_dashed_line(r.position + Vector2(0, r.size.y), r.position, col, 1.6, 4.0)
