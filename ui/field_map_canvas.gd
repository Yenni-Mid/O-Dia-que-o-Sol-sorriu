extends Control
## Canvas do Mapa Rabiscado à Mão de todo o quarteirão expandido (pergaminho dobrado, anotações de sobrevivência,
## zoom/arraste no Diário [Tab] e versão compacta para o Mapa Físico 3D [M] na mão esquerda).

const WORLD_MIN: Vector2 = Vector2(-68.0, -86.0)
const WORLD_MAX: Vector2 = Vector2(74.0, 31.0)
const PAPER_BG: Color = Color(0.72, 0.65, 0.50)
const INK_COL: Color = Color(0.16, 0.11, 0.07, 0.92)
const INK_FAINT: Color = Color(0.24, 0.18, 0.12, 0.52)
const SUB_COL: Color = Color(0.16, 0.28, 0.44, 0.82)
const RED_X_COL: Color = Color(0.62, 0.10, 0.08, 0.90)
const SUN_YELLOW: Color = Color(0.90, 0.74, 0.16, 0.88)

@export var is_diegetic_paper: bool = false

var _zoom: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _parchment_tex: ImageTexture = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if is_diegetic_paper else Control.MOUSE_FILTER_STOP
	clip_contents = true
	if _parchment_tex == null:
		_parchment_tex = _build_parchment_texture()


func _exit_tree() -> void:
	_parchment_tex = null


func reset_view() -> void:
	_zoom = 1.0
	_pan_offset = Vector2.ZERO
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if is_diegetic_paper:
		return
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
	var pad_x: float = 16.0 if is_diegetic_paper else 20.0
	var pad_y: float = 14.0 if is_diegetic_paper else 18.0
	var draw_w: float = maxf(10.0, size.x - pad_x * 2.0)
	var draw_h: float = maxf(10.0, size.y - pad_y * 2.0)
	var span: Vector2 = WORLD_MAX - WORLD_MIN
	var nx: float = (world_xz.x - WORLD_MIN.x) / span.x
	var ny: float = (world_xz.y - WORLD_MIN.y) / span.y
	var base: Vector2 = Vector2(pad_x + nx * draw_w, pad_y + ny * draw_h)
	if is_diegetic_paper:
		return base
	var center: Vector2 = size * 0.5
	return center + (base - center) * _zoom + _pan_offset


func _world_rect(x0: float, z0: float, x1: float, z1: float) -> Rect2:
	var p0: Vector2 = _world_to_canvas(Vector2(x0, z0))
	var p1: Vector2 = _world_to_canvas(Vector2(x1, z1))
	return Rect2(p0, p1 - p0)


func _draw() -> void:
	if _parchment_tex != null:
		draw_texture_rect(_parchment_tex, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), PAPER_BG, true)

	var fnt: Font = get_theme_default_font()

	# Fundo sombreado das vias & becos principais (desenho à tinta sobre pergaminho)
	_draw_street_strip(-66.0, 10.6, 70.0, 15.2)
	_draw_street_strip(-26.0, -19.5, 36.0, -15.5)
	_draw_street_strip(-29.8, -19.5, -26.2, 9.6)
	_draw_street_strip(-2.8, -48.0, 2.8, -20.0)
	# Viela traseira e becos estreitos
	_draw_street_strip(-25.5, -10.4, 25.5, -7.0)

	# Destaque amarelo rabiscado de perigo solar na pista Leste ("RUA DE LUZ")
	_draw_yellow_street_highlight(Vector2(18.0, 12.9), Vector2(56.0, 12.9))
	_draw_yellow_street_highlight(Vector2(-2.0, -21.0), Vector2(28.0, -17.5))

	# Quarteirão Sul & Abrigo / Farmácia
	_draw_building(-3.0, 15.5, 3.0, 25.0, Color(0.56, 0.48, 0.35, 0.52), "ABRIGO", fnt, 8)
	_draw_building(-25.5, 16.5, -18.5, 23.5, Color(0.46, 0.39, 0.29, 0.45), "", fnt, 7)
	_draw_building(-15.5, 16.5, -3.2, 23.5, Color(0.46, 0.39, 0.29, 0.45), "LOJAS W", fnt, 8)
	_draw_building(3.2, 16.5, 14.5, 23.5, Color(0.52, 0.44, 0.33, 0.50), "FARMÁCIA", fnt, 7)
	_draw_building(17.5, 16.5, 35.5, 23.5, Color(0.46, 0.39, 0.29, 0.45), "LOJAS E", fnt, 8)

	# Quarteirão Central: Casa, Sobrados, Cortiços, Mercado, Vizinha, Pracinha
	_draw_building(-8.0, -7.0, 8.0, 7.0, Color(0.62, 0.52, 0.36, 0.62), "CASA", fnt, 9)
	_draw_building(-14.5, -7.0, -10.9, 7.0, Color(0.48, 0.40, 0.30, 0.52), "", fnt, 7)
	_draw_building(10.9, -7.0, 14.5, 7.0, Color(0.48, 0.40, 0.30, 0.52), "", fnt, 7)
	_draw_building(-25.0, -14.8, -10.9, -10.4, Color(0.46, 0.39, 0.29, 0.50), "CORTIÇOS", fnt, 7)
	_draw_building(10.9, -14.8, 25.0, -10.4, Color(0.46, 0.39, 0.29, 0.50), "CORTIÇOS", fnt, 7)
	_draw_building(-25.5, -7.5, -17.5, 7.0, Color(0.58, 0.46, 0.34, 0.58), "MERC.", fnt, 7)
	_draw_building(17.5, -7.0, 25.5, 7.5, Color(0.54, 0.47, 0.37, 0.55), "VIZ.", fnt, 7)
	_draw_building(25.5, -14.5, 36.0, 9.6, Color(0.50, 0.45, 0.38, 0.42), "PRAÇA", fnt, 8)

	# Zona Oeste: Posto Sol & Óleo e Galpão Industrial
	_draw_building(-57.0, -16.5, -32.0, 9.6, Color(0.50, 0.46, 0.38, 0.30), "", fnt, 8)
	_draw_building(-60.0, -16.5, -48.5, -10.5, Color(0.48, 0.40, 0.31, 0.52), "GALPÃO", fnt, 7)
	_draw_building(-57.0, -6.0, -46.0, 4.0, Color(0.60, 0.42, 0.32, 0.58), "POSTO", fnt, 8)
	_draw_building(-41.0, 0.5, -32.0, 7.5, Color(0.64, 0.38, 0.28, 0.55), "BOMBAS", fnt, 7)
	_draw_building(-64.5, 16.5, -30.0, 21.5, Color(0.46, 0.39, 0.29, 0.45), "COMÉRCIO OESTE", fnt, 7)

	# Zona Norte: Pátio e Escola Municipal Aurora Solar
	_draw_building(-26.0, -48.0, 24.0, -20.0, Color(0.48, 0.44, 0.36, 0.24), "", fnt, 8)
	_draw_building(-23.8, -39.5, -14.5, -22.2, Color(0.50, 0.42, 0.32, 0.52), "ED. A", fnt, 7)
	_draw_building(-37.0, -39.0, -27.5, -24.0, Color(0.48, 0.40, 0.30, 0.48), "ANEXO", fnt, 7)
	_draw_building(14.5, -40.2, 24.0, -22.2, Color(0.50, 0.42, 0.32, 0.52), "ED. S", fnt, 7)
	_draw_building(-24.0, -72.0, 22.0, -48.0, Color(0.60, 0.54, 0.38, 0.62), "ESCOLA AURORA", fnt, 10)

	# Zona Leste: Cemitério, Sobrados Coloniais e Capela
	_draw_building(36.0, -24.0, 66.0, 9.6, Color(0.44, 0.44, 0.36, 0.30), "", fnt, 8)
	_draw_building(37.2, -19.5, 40.8, -4.5, Color(0.48, 0.40, 0.31, 0.50), "", fnt, 7)
	_draw_building(63.4, -19.5, 68.2, -4.5, Color(0.48, 0.40, 0.31, 0.50), "", fnt, 7)
	_draw_building(44.0, -21.0, 60.0, -3.0, Color(0.60, 0.50, 0.35, 0.62), "CAPELA", fnt, 9)
	_draw_building(36.5, 16.5, 69.5, 21.5, Color(0.46, 0.39, 0.29, 0.45), "LOJAS CAPELA", fnt, 7)

	# Subsolo tracejado (Porão, Túnel e Rede de Esgotos) — fica verde/aceso quando o Gerador do esgoto está ligado
	var gen: Node = get_tree().get_first_node_in_group("oil_generator")
	var gen_running: bool = (gen != null and bool(gen.get("is_running")))
	var sewer_col: Color = Color(0.16, 0.50, 0.24, 0.90) if gen_running else SUB_COL
	_draw_dashed_box(-8.0, -7.2, 4.0, 1.0, sewer_col)
	_draw_dashed_box(-44.4, -6.8, -8.0, -3.8, sewer_col)
	_draw_dashed_box(-47.6, -47.6, -44.4, -3.7, sewer_col)
	_draw_dashed_box(-53.6, -29.0, -47.6, -23.0, sewer_col)
	_draw_dashed_box(-44.4, -15.4, -38.4, -12.6, sewer_col)
	_draw_dashed_box(-44.4, -47.4, -38.4, -44.6, sewer_col)
	if gen_running:
		var gen_p: Vector2 = _world_to_canvas(Vector2(-50.6, -26.0))
		draw_arc(gen_p, 6.5, 0.0, TAU, 12, Color(0.22, 0.65, 0.28, 0.95), 1.6)
		if fnt != null:
			_draw_free_label(fnt, Vector2(-59.5, -26.0), "GERADOR\nOK", 8, Color(0.14, 0.44, 0.18, 0.95))

	# Rótulos claros em áreas abertas (nunca cortados dentro de caixas estreitas)
	if fnt != null:
		_draw_free_label(fnt, Vector2(-14.0, 12.9), "AV. PRINCIPAL", 8, INK_COL)
		_draw_free_label(fnt, Vector2(38.0, 12.9), "RUA DE LUZ", 9, Color(0.32, 0.20, 0.04))
		_draw_free_label(fnt, Vector2(5.0, -17.5), "RUA TRANSVERSAL", 7, INK_COL)
		_draw_free_label(fnt, Vector2(0.0, -34.0), "PÁTIO", 8, INK_COL)
		_draw_free_label(fnt, Vector2(52.0, 4.8), "CEMITÉRIO", 8, INK_COL)

	# Checa sanidade atual para rabiscos perturbadores e sóis sinistros (< 45%)
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	var sanity_ratio: float = 1.0
	if player != null and player.sanity_component != null:
		sanity_ratio = player.sanity_component.get_sanity_ratio()
	var low_sanity: bool = sanity_ratio < 0.45

	# Marcações de sobrevivência: Sóis amarelos, Torre no topo, X vermelhos e becos
	_draw_sun_doodle(_world_to_canvas(Vector2(38.0, -60.0)), 12.0 if is_diegetic_paper else 14.0, low_sanity)
	_draw_sun_doodle(_world_to_canvas(Vector2(-54.0, -58.0)), 11.0 if is_diegetic_paper else 13.0, low_sanity)
	if fnt != null:
		_draw_free_label(fnt, Vector2(47.0, -47.0), "SOL QUEIMA\nDE DIA", 8, Color(0.28, 0.18, 0.05))
		_draw_free_label(fnt, Vector2(-12.0, 27.6), "becos nas sombras", 8, INK_COL)

	# Anotação automática à caneta do código do cofre da Diretoria (1710) após descobrir com Dona Helena ou notas
	if SaveManager.is_school_code_known() and fnt != null:
		_draw_school_code_note(fnt, SaveManager.is_safe_unlocked("safe_school"))

	# Seta apontando para a rota segura dos becos sombrios
	_draw_ink_arrow(_world_to_canvas(Vector2(-15.5, 25.8)), _world_to_canvas(Vector2(-16.0, 4.0)), INK_COL, 1.5)
	_draw_ink_arrow(_world_to_canvas(Vector2(-16.0, 4.0)), _world_to_canvas(Vector2(-9.5, -8.5)), INK_COL, 1.5)

	# Emblema da TORRE ao Norte no topo + setas convergindo
	_draw_tower_emblem(fnt)

	# Marcas "X" vermelhas desenhadas à mão nos pontos de patrulha / perigo
	for xp: Vector2 in [
		Vector2(-37.0, 12.9),
		Vector2(30.5, 1.5),
		Vector2(0.0, -28.0),
		Vector2(47.5, 5.5),
	]:
		_draw_red_x(_world_to_canvas(xp), 6.5)

	# Bilhetinho colado no canto inferior direito ("ÓLEO" + desenhinho de lampião)
	_draw_oil_sticky_note(fnt)

	# Cadeados vivos em portas trancadas, passagens bloqueadas e atalhos destraváveis
	for d_node: Node in get_tree().get_nodes_in_group("door_interactable"):
		if d_node is Node3D and bool(d_node.get("started_locked")):
			var d3: Node3D = d_node as Node3D
			var d_pos: Vector2 = _world_to_canvas(Vector2(d3.global_position.x, d3.global_position.z))
			_draw_padlock_icon(d_pos, not bool(d_node.get("is_locked")))

	for bp_node: Node in get_tree().get_nodes_in_group("blocked_passage"):
		if bp_node is Node3D:
			var bp3: Node3D = bp_node as Node3D
			var bp_pos: Vector2 = _world_to_canvas(Vector2(bp3.global_position.x, bp3.global_position.z))
			_draw_padlock_icon(bp_pos, false)

	for sg_node: Node in get_tree().get_nodes_in_group("shortcut_gate"):
		if sg_node is Node3D:
			var sg3: Node3D = sg_node as Node3D
			var sg_pos: Vector2 = _world_to_canvas(Vector2(sg3.global_position.x, sg3.global_position.z))
			_draw_shortcut_icon(sg_pos, bool(sg_node.get("is_unlocked")))

	# Tambores-Fogueira em tempo real (brilho e raios a tinta quando acesos)
	for b_node: Node in get_tree().get_nodes_in_group("fire_barrel"):
		if b_node is Node3D:
			var b3: Node3D = b_node as Node3D
			var b_pos: Vector2 = _world_to_canvas(Vector2(b3.global_position.x, b3.global_position.z))
			var lit: bool = bool(b3.get("is_lit"))
			if lit:
				draw_arc(b_pos, 7.6, 0.0, TAU, 12, Color(0.95, 0.56, 0.14, 0.55), 1.4)
				for r_idx: int in range(4):
					var ang: float = float(r_idx) * PI * 0.5 + 0.35
					draw_line(b_pos + Vector2(cos(ang), sin(ang)) * 5.8, b_pos + Vector2(cos(ang), sin(ang)) * 9.2, Color(0.75, 0.24, 0.06, 0.85), 1.2)
			draw_circle(b_pos, 4.5 if lit else 3.5, Color(0.98, 0.48, 0.12) if lit else Color(0.32, 0.28, 0.24))
			draw_arc(b_pos, 5.0 if lit else 3.8, 0.0, TAU, 10, INK_COL, 1.2)

	# Jogador em tempo real
	if player != null:
		var p_pos: Vector2 = _world_to_canvas(Vector2(player.global_position.x, player.global_position.z))
		var fwd3: Vector3 = -player.global_transform.basis.z
		var fwd2: Vector2 = Vector2(fwd3.x, fwd3.z)
		if fwd2.length_squared() < 0.001:
			fwd2 = Vector2(0.0, -1.0)
		fwd2 = fwd2.normalized()
		var side2: Vector2 = Vector2(-fwd2.y, fwd2.x)

		var tip: Vector2 = p_pos + fwd2 * 10.5
		var wing_l: Vector2 = p_pos - fwd2 * 4.5 + side2 * 5.8
		var wing_r: Vector2 = p_pos - fwd2 * 4.5 - side2 * 5.8
		draw_colored_polygon(PackedVector2Array([tip, wing_l, wing_r]), Color(0.78, 0.12, 0.09))
		draw_circle(p_pos, 3.8, Color(0.98, 0.88, 0.35))
		draw_arc(p_pos, 3.8, 0.0, TAU, 12, INK_COL, 1.5)
		if fnt != null:
			var label_y: String = "ESGOTO" if player.global_position.y < -1.2 else ("2º ANDAR" if player.global_position.y > 2.5 else "VOCÊ")
			draw_string(fnt, p_pos + Vector2(8.0, 4.0), label_y, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.65, 0.08, 0.06))

		# Rabiscos perturbadores de alucinação no mapa quando Sanidade < 45%
		if low_sanity and fnt != null:
			_draw_low_sanity_scrawls(fnt, sanity_ratio, p_pos)

	# Borda dupla rascunhada + instrução de zoom somente no modo Diário [Tab]
	draw_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), INK_FAINT, false, 1.6)
	if not is_diegetic_paper and fnt != null:
		draw_string(fnt, Vector2(14.0, size.y - 10.0), "Scroll: Zoom (%.1fx) | Arrastar: Mover | Dir.: Resetar" % _zoom, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SUB_COL)


func _draw_street_strip(x0: float, z0: float, x1: float, z1: float) -> void:
	var r: Rect2 = _world_rect(x0, z0, x1, z1)
	draw_rect(r, Color(0.36, 0.29, 0.20, 0.24), true)
	draw_line(r.position, r.position + Vector2(r.size.x, 0.0), INK_FAINT, 1.1)
	draw_line(r.position + Vector2(0.0, r.size.y), r.position + r.size, INK_FAINT, 1.1)


func _draw_building(x0: float, z0: float, x1: float, z1: float, fill: Color, label: String, fnt: Font, font_size: int) -> void:
	var r: Rect2 = _world_rect(x0, z0, x1, z1)
	draw_rect(r, fill, true)
	_draw_sketchy_rect(r, INK_COL, 1.5)
	if not label.is_empty() and fnt != null:
		var tw: float = fnt.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if r.size.x >= tw + 4.0 and r.size.y >= float(font_size) + 2.0:
			var tx: float = r.position.x + (r.size.x - tw) * 0.5
			var ty: float = r.position.y + r.size.y * 0.5 + float(font_size) * 0.35
			draw_string(fnt, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK_COL)


func _draw_sketchy_rect(r: Rect2, col: Color, lw: float) -> void:
	var ov: float = 2.0
	var tl: Vector2 = r.position
	var tr: Vector2 = r.position + Vector2(r.size.x, 0.0)
	var br: Vector2 = r.position + r.size
	var bl: Vector2 = r.position + Vector2(0.0, r.size.y)
	draw_line(tl - Vector2(ov, 0.0), tr + Vector2(ov, 0.0), col, lw)
	draw_line(tr - Vector2(0.0, ov), br + Vector2(0.0, ov), col, lw)
	draw_line(br + Vector2(ov, 0.0), bl - Vector2(ov, 0.0), col, lw)
	draw_line(bl + Vector2(0.0, ov), tl - Vector2(0.0, ov), col, lw)


func _draw_free_label(fnt: Font, world_pos: Vector2, text: String, font_size: int, col: Color) -> void:
	var lines: PackedStringArray = text.split("\n")
	var base: Vector2 = _world_to_canvas(world_pos)
	for i: int in range(lines.size()):
		var ln: String = lines[i]
		var tw: float = fnt.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var p: Vector2 = base + Vector2(-tw * 0.5, float(i) * float(font_size + 2) + float(font_size) * 0.35)
		draw_string(fnt, p, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _draw_yellow_street_highlight(w0: Vector2, w1: Vector2) -> void:
	var p0: Vector2 = _world_to_canvas(w0)
	var p1: Vector2 = _world_to_canvas(w1)
	var segs: int = 12
	var pts: PackedVector2Array = PackedVector2Array()
	var dir: Vector2 = (p1 - p0).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	for i: int in range(segs + 1):
		var t: float = float(i) / float(segs)
		var wave: float = sin(t * TAU * 2.5) * 2.2
		pts.append(p0.lerp(p1, t) + perp * wave)
	for i: int in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], Color(0.92, 0.78, 0.18, 0.52), 7.0)


func _draw_sun_doodle(center: Vector2, radius: float, haunting: bool = false) -> void:
	draw_circle(center, radius * 0.55, Color(0.92, 0.78, 0.16, 0.35))
	draw_arc(center, radius * 0.58, 0.0, TAU, 16, SUN_YELLOW, 2.0)
	for r_i: int in range(8):
		var ang: float = float(r_i) * TAU / 8.0 + 0.15
		var p_in: Vector2 = center + Vector2(cos(ang), sin(ang)) * (radius * 0.72)
		var p_out: Vector2 = center + Vector2(cos(ang), sin(ang)) * (radius * 1.12)
		draw_line(p_in, p_out, SUN_YELLOW, 1.8)
	if haunting:
		draw_circle(center + Vector2(-radius * 0.20, -radius * 0.14), 1.3, RED_X_COL)
		draw_circle(center + Vector2(radius * 0.20, -radius * 0.14), 1.3, RED_X_COL)
		draw_arc(center + Vector2(0.0, radius * 0.04), radius * 0.28, 0.25, PI - 0.25, 8, RED_X_COL, 1.4)


func _draw_school_code_note(fnt: Font, safe_opened: bool) -> void:
	var note_pos: Vector2 = _world_to_canvas(Vector2(29.0, -75.0))
	var safe_pos: Vector2 = _world_to_canvas(Vector2(17.5, -70.6))
	var txt: String = "COFRE: 1710"
	var tw: float = fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var ink: Color = Color(0.28, 0.22, 0.16, 0.68) if safe_opened else Color(0.60, 0.08, 0.07, 0.94)
	draw_line(note_pos + Vector2(-tw * 0.45, 5.0), safe_pos, ink, 1.1)
	draw_circle(safe_pos, 3.0, ink)
	draw_string(fnt, note_pos + Vector2(-tw * 0.5, 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ink)
	draw_arc(note_pos + Vector2(0.0, -1.5), maxf(18.0, tw * 0.62), 0.15, TAU - 0.15, 16, ink, 1.2)
	if safe_opened:
		draw_line(note_pos + Vector2(-tw * 0.52, 2.0), note_pos + Vector2(tw * 0.52, -5.0), Color(0.16, 0.48, 0.22, 0.90), 1.8)


func _draw_padlock_icon(center: Vector2, unlocked: bool) -> void:
	var col: Color = Color(0.22, 0.48, 0.26, 0.72) if unlocked else RED_X_COL
	draw_arc(center + Vector2(0.0, -3.5), 2.8, PI, TAU, 8, col, 1.4)
	var body: Rect2 = Rect2(center + Vector2(-3.5, -2.5), Vector2(7.0, 5.5))
	draw_rect(body, Color(0.84, 0.72, 0.54, 0.92), true)
	draw_rect(body, col, false, 1.3)
	if unlocked:
		draw_line(center + Vector2(-4.5, 4.0), center + Vector2(4.5, -5.0), Color(0.16, 0.48, 0.22, 0.95), 1.6)


func _draw_shortcut_icon(center: Vector2, unlocked: bool) -> void:
	if not unlocked:
		_draw_padlock_icon(center, false)
		return
	var col: Color = Color(0.14, 0.50, 0.22, 0.94)
	draw_circle(center, 5.5, Color(0.78, 0.88, 0.70, 0.82))
	draw_arc(center, 5.5, 0.0, TAU, 12, col, 1.4)
	draw_line(center + Vector2(-3.5, 0.0), center + Vector2(3.5, 0.0), col, 1.5)
	draw_line(center + Vector2(0.0, -3.5), center + Vector2(0.0, 3.5), col, 1.5)


func _draw_low_sanity_scrawls(fnt: Font, sanity_ratio: float, player_canvas_pos: Vector2) -> void:
	var intensity: float = clampf((0.45 - sanity_ratio) / 0.30, 0.28, 0.95)
	var tick: int = Time.get_ticks_msec() / 420
	var jx: float = sin(float(tick) * 2.7) * 2.5
	var jy: float = cos(float(tick) * 3.1) * 2.0
	var scrawl_col: Color = Color(0.68, 0.06, 0.05, intensity)

	var p_sun: Vector2 = _world_to_canvas(Vector2(50.0, -70.0)) + Vector2(jx, jy)
	draw_string(fnt, p_sun, "O SOL TE VÊ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, scrawl_col)

	var p_back: Vector2 = _world_to_canvas(Vector2(-60.0, 27.6)) + Vector2(-jx, jy)
	draw_string(fnt, p_back, "NÃO OLHE PRA TRÁS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, scrawl_col)

	if sanity_ratio < 0.28:
		var p_up: Vector2 = _world_to_canvas(Vector2(-60.0, -76.0)) + Vector2(jy, -jx)
		draw_string(fnt, p_up, "OLHE PARA CIMA", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, scrawl_col)
		for s_i: int in range(4):
			var ang: float = float(s_i + (tick % 5)) * 1.45
			var a_pt: Vector2 = player_canvas_pos + Vector2(cos(ang), sin(ang)) * 13.0
			var b_pt: Vector2 = player_canvas_pos + Vector2(cos(ang + 0.5), sin(ang + 0.5)) * 23.0
			draw_line(a_pt, b_pt, Color(0.55, 0.05, 0.05, intensity * 0.72), 1.3)


func _draw_red_x(center: Vector2, half_sz: float) -> void:
	draw_line(center + Vector2(-half_sz, -half_sz), center + Vector2(half_sz, half_sz), RED_X_COL, 2.4)
	draw_line(center + Vector2(-half_sz + 1.5, half_sz), center + Vector2(half_sz, -half_sz + 1.0), RED_X_COL, 2.4)


func _draw_ink_arrow(from_p: Vector2, to_p: Vector2, col: Color, lw: float) -> void:
	draw_line(from_p, to_p, col, lw)
	var d: Vector2 = (to_p - from_p).normalized()
	var side: Vector2 = Vector2(-d.y, d.x)
	draw_line(to_p, to_p - d * 6.0 + side * 3.5, col, lw)
	draw_line(to_p, to_p - d * 6.0 - side * 3.5, col, lw)


func _draw_tower_emblem(fnt: Font) -> void:
	var c: Vector2 = _world_to_canvas(Vector2(0.0, -79.5))
	var r_rad: float = 16.0 if is_diegetic_paper else 18.0
	draw_circle(c, r_rad, Color(0.80, 0.73, 0.56, 0.75))
	draw_arc(c, r_rad, 0.0, TAU, 20, INK_COL, 1.8)
	draw_arc(c, r_rad + 2.0, 0.4, TAU - 0.3, 18, INK_FAINT, 1.0)
	# Desenhinho de prédio/torre no centro do círculo
	var b_rect: Rect2 = Rect2(c + Vector2(-5.5, -9.0), Vector2(11.0, 17.0))
	draw_rect(b_rect, Color(0.42, 0.34, 0.24, 0.8), true)
	draw_rect(b_rect, INK_COL, false, 1.4)
	draw_line(c + Vector2(-1.5, -6.0), c + Vector2(-1.5, 6.0), INK_COL, 1.0)
	draw_line(c + Vector2(1.5, -6.0), c + Vector2(1.5, 6.0), INK_COL, 1.0)

	# 4 Setas apontando para a Torre (igual à Imagem 3)
	_draw_ink_arrow(c + Vector2(-34.0, -8.0), c + Vector2(-r_rad - 3.0, -3.0), INK_COL, 1.5)
	_draw_ink_arrow(c + Vector2(34.0, -6.0), c + Vector2(r_rad + 3.0, -2.0), INK_COL, 1.5)
	_draw_ink_arrow(c + Vector2(-12.0, r_rad + 12.0), c + Vector2(-5.0, r_rad + 3.0), INK_COL, 1.4)
	_draw_ink_arrow(c + Vector2(12.0, r_rad + 12.0), c + Vector2(5.0, r_rad + 3.0), INK_COL, 1.4)
	if fnt != null:
		draw_string(fnt, c + Vector2(-58.0, -8.0), "↑ TORRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.54, 0.10, 0.07))


func _draw_oil_sticky_note(fnt: Font) -> void:
	var note_w: float = 88.0 if is_diegetic_paper else 98.0
	var note_h: float = 64.0 if is_diegetic_paper else 70.0
	var note_pos: Vector2 = Vector2(size.x - note_w - 16.0, size.y - note_h - (16.0 if is_diegetic_paper else 28.0))
	var nr: Rect2 = Rect2(note_pos, Vector2(note_w, note_h))
	draw_rect(nr, Color(0.82, 0.76, 0.61, 0.94), true)
	_draw_sketchy_rect(nr, INK_COL, 1.4)
	# Fitinhas no topo da nota
	draw_rect(Rect2(note_pos + Vector2(8.0, -4.0), Vector2(18.0, 7.0)), Color(0.58, 0.50, 0.36, 0.72), true)
	draw_rect(Rect2(note_pos + Vector2(note_w - 26.0, -3.0), Vector2(18.0, 7.0)), Color(0.58, 0.50, 0.36, 0.72), true)
	if fnt != null:
		draw_string(fnt, note_pos + Vector2(10.0, 20.0), "ÓLEO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK_COL)
	# Desenho miniatura de lampião ao lado do texto ÓLEO
	var lc: Vector2 = note_pos + Vector2(note_w * 0.68, note_h * 0.58)
	draw_arc(lc + Vector2(0.0, -10.0), 6.0, PI, TAU, 10, INK_COL, 1.4)
	draw_rect(Rect2(lc + Vector2(-6.0, -7.0), Vector2(12.0, 14.0)), Color(0.95, 0.72, 0.24, 0.45), true)
	draw_rect(Rect2(lc + Vector2(-6.0, -7.0), Vector2(12.0, 14.0)), INK_COL, false, 1.3)
	draw_rect(Rect2(lc + Vector2(-8.0, 7.0), Vector2(16.0, 5.0)), INK_COL, false, 1.3)
	draw_line(note_pos + Vector2(22.0, 24.0), lc + Vector2(-8.0, -2.0), INK_COL, 1.2)


func _draw_dashed_box(x0: float, z0: float, x1: float, z1: float, col: Color) -> void:
	var r: Rect2 = _world_rect(x0, z0, x1, z1)
	draw_rect(r, Color(col.r, col.g, col.b, 0.14), true)
	draw_dashed_line(r.position, r.position + Vector2(r.size.x, 0.0), col, 1.6, 4.0)
	draw_dashed_line(r.position + Vector2(r.size.x, 0.0), r.position + r.size, col, 1.6, 4.0)
	draw_dashed_line(r.position + r.size, r.position + Vector2(0.0, r.size.y), col, 1.6, 4.0)
	draw_dashed_line(r.position + Vector2(0.0, r.size.y), r.position, col, 1.6, 4.0)


func _build_parchment_texture() -> ImageTexture:
	var w: int = 256
	var h: int = 192
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4040
	var crease_x1: int = w / 3
	var crease_x2: int = (w * 2) / 3
	var crease_y: int = h / 2

	for y: int in range(h):
		var ey: float = absf(float(y) / float(h - 1) * 2.0 - 1.0)
		for x: int in range(w):
			var ex: float = absf(float(x) / float(w - 1) * 2.0 - 1.0)
			var edge_dark: float = 1.0 - 0.26 * pow(maxf(ex, ey), 3.0)
			var grain: float = sin(float(x) * 0.08) * cos(float(y) * 0.09) * 0.035
			var stain_a: float = clampf(1.0 - Vector2(float(x - 52), float(y - 44)).length() / 36.0, 0.0, 1.0) * 0.09
			var stain_b: float = clampf(1.0 - Vector2(float(x - 200), float(y - 140)).length() / 42.0, 0.0, 1.0) * 0.11
			var v: float = clampf((0.76 + grain + rng.randf_range(-0.028, 0.028) - stain_a - stain_b) * edge_dark, 0.36, 0.88)

			# Vincos nítidos das dobras do mapa (3 colunas x 2 linhas)
			var dx1: int = absi(x - crease_x1)
			var dx2: int = absi(x - crease_x2)
			var dy1: int = absi(y - crease_y)
			if dx1 == 0 or dx2 == 0 or dy1 == 0:
				v *= 0.66
			elif dx1 == 1 or dx2 == 1 or dy1 == 1:
				v = clampf(v * 1.08, 0.36, 0.92)

			img.set_pixel(x, y, Color(v * 1.01, v * 0.92, v * 0.72, 1.0))

	return ImageTexture.create_from_image(img)
