extends Control
## Tela do Mapa Rabiscado à Mão do Quarteirão (estilo survival horror PS1).
## Converte coordenadas 3D reais para o mapa e desenha a posição e direção do jogador em tempo real.

const WORLD_MIN: Vector2 = Vector2(-28.0, -22.0)
const WORLD_MAX: Vector2 = Vector2(38.0, 27.0)
const PAPER_BG: Color = Color(0.84, 0.79, 0.65)
const GRID_COL: Color = Color(0.58, 0.64, 0.68, 0.28)
const INK_COL: Color = Color(0.18, 0.13, 0.08)
const SUB_COL: Color = Color(0.18, 0.30, 0.45, 0.75)


func _world_to_canvas(world_xz: Vector2) -> Vector2:
	var pad: float = 24.0
	var draw_w: float = maxf(10.0, size.x - pad * 2.0)
	var draw_h: float = maxf(10.0, size.y - pad * 2.0)
	var span: Vector2 = WORLD_MAX - WORLD_MIN
	var nx: float = (world_xz.x - WORLD_MIN.x) / span.x
	var ny: float = (world_xz.y - WORLD_MIN.y) / span.y
	return Vector2(pad + nx * draw_w, pad + ny * draw_h)


func _world_rect(x0: float, z0: float, x1: float, z1: float) -> Rect2:
	var p0: Vector2 = _world_to_canvas(Vector2(x0, z0))
	var p1: Vector2 = _world_to_canvas(Vector2(x1, z1))
	return Rect2(p0, p1 - p0)


func _draw() -> void:
	# Papel quadriculado
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

	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), INK_COL, false, 2.0)

	var fnt: Font = get_theme_default_font()

	# Rua Principal
	_draw_area(-26.0, 10.6, 36.0, 15.2, Color(0.58, 0.54, 0.48, 0.55), INK_COL, "RUA PRINCIPAL", fnt, 11)
	# Abrigo Inicial
	_draw_area(-3.0, 15.5, 3.0, 25.0, Color(0.65, 0.60, 0.50, 0.7), INK_COL, "ABRIGO", fnt, 10)
	# Casa de Dois Andares
	_draw_area(-8.0, -7.0, 8.0, 7.0, Color(0.72, 0.64, 0.48, 0.85), INK_COL, "CASA (2 ANDARES)", fnt, 12)
	# Varanda
	_draw_area(-3.0, 7.0, 3.0, 10.0, Color(0.68, 0.58, 0.42, 0.8), INK_COL, "", fnt, 10)
	# Mini-Mercado
	_draw_area(-25.5, -7.5, -17.5, 7.0, Color(0.72, 0.58, 0.48, 0.85), INK_COL, "MINI-MERCADO", fnt, 10)
	# Pracinha do Culto
	_draw_area(25.5, -20.0, 36.0, 9.6, Color(0.64, 0.60, 0.56, 0.75), INK_COL, "PRACINHA DO CULTO", fnt, 10)
	# Ponto de Ônibus
	_draw_area(10.7, 9.2, 14.3, 11.4, Color(0.52, 0.56, 0.62, 0.8), INK_COL, "PONTO", fnt, 9)
	# Carro Abandonado
	_draw_area(-8.5, 12.1, -4.5, 13.9, Color(0.55, 0.32, 0.25, 0.85), INK_COL, "CARRO", fnt, 9)

	# Passagem Subterrânea (Porão + Túnel traçados em azul rabiscado)
	_draw_dashed_box(-8.0, -7.2, 4.0, 1.0, SUB_COL)
	_draw_dashed_box(-24.8, -6.8, -8.0, -3.8, SUB_COL)
	_draw_dashed_box(-1.3, -13.2, 1.3, -7.2, SUB_COL)
	if fnt != null:
		var cellar_pt: Vector2 = _world_to_canvas(Vector2(-13.0, -8.2))
		draw_string(fnt, cellar_pt, "SUBSOLO: TÚNEL / PORÃO (SOMBRAS)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SUB_COL)
		var north_pt: Vector2 = Vector2(size.x * 0.5 - 95.0, 18.0)
		draw_string(fnt, north_pt, "↑ NORTE — TORRE CENTRAL", HORIZONTAL_ALIGNMENT_CENTER, 190, 12, Color(0.58, 0.12, 0.08))

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

		var tip: Vector2 = p_pos + fwd2 * 13.0
		var wing_l: Vector2 = p_pos - fwd2 * 5.0 + side2 * 7.0
		var wing_r: Vector2 = p_pos - fwd2 * 5.0 - side2 * 7.0
		var tri: PackedVector2Array = PackedVector2Array([tip, wing_l, wing_r])
		draw_colored_polygon(tri, Color(0.82, 0.14, 0.10))
		draw_circle(p_pos, 4.5, Color(0.98, 0.88, 0.35))
		draw_arc(p_pos, 4.5, 0.0, TAU, 12, INK_COL, 1.5)
		if fnt != null:
			var label_y: String = "SUBSOLO" if player.global_position.y < -1.2 else ("2º ANDAR" if player.global_position.y > 2.5 else "VOCÊ")
			draw_string(fnt, p_pos + Vector2(8.0, 4.0), label_y, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.70, 0.10, 0.08))


func _draw_area(x0: float, z0: float, x1: float, z1: float, fill: Color, border: Color, label: String, fnt: Font, font_size: int) -> void:
	var r: Rect2 = _world_rect(x0, z0, x1, z1)
	draw_rect(r, fill, true)
	draw_rect(r, border, false, 1.8)
	if not label.is_empty() and fnt != null:
		var center: Vector2 = r.position + Vector2(4.0, r.size.y * 0.5 + float(font_size) * 0.35)
		draw_string(fnt, center, label, HORIZONTAL_ALIGNMENT_CENTER, int(maxf(40.0, r.size.x - 8.0)), font_size, border)


func _draw_dashed_box(x0: float, z0: float, x1: float, z1: float, col: Color) -> void:
	var r: Rect2 = _world_rect(x0, z0, x1, z1)
	draw_rect(r, Color(col.r, col.g, col.b, 0.14), true)
	draw_dashed_line(r.position, r.position + Vector2(r.size.x, 0), col, 1.8, 5.0)
	draw_dashed_line(r.position + Vector2(r.size.x, 0), r.position + r.size, col, 1.8, 5.0)
	draw_dashed_line(r.position + r.size, r.position + Vector2(0, r.size.y), col, 1.8, 5.0)
	draw_dashed_line(r.position + Vector2(0, r.size.y), r.position, col, 1.8, 5.0)
