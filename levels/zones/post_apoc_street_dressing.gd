@tool
extends Node3D
## Ambientação pós-apocalíptica de cidade abandonada PS1:
## - Prédios urbanos altos e degradados ao sul/norte fechando o cânion das ruas;
## - Murais de pichação e fuligem em tijolos pixelados nos becos e muros;
## - Caixotes, latões tombados, chapas corrugadas, sacos de lixo e papéis no chão;
## - Cabos aéreos e postes de sódio moribundos piscando à noite.

const LAYER_ENVIRONMENT: int = 1
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

var _materials: Dictionary = {}
var _textures: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _shape_cache: Dictionary = {}
var _sodium_lights: Array[Dictionary] = []
var _watcher_windows: Array[Dictionary] = []
var _alley_rats: Array[Dictionary] = []
var _night2_porch_mark: Node3D = null
var _night3_school_mark: Node3D = null
var _ash_particles: CPUParticles3D = null
var _flicker_t: float = 0.0


func _ready() -> void:
	rebuild_dressing()


func _exit_tree() -> void:
	_materials.clear()
	_textures.clear()
	_mesh_cache.clear()
	_shape_cache.clear()
	_sodium_lights.clear()
	_watcher_windows.clear()
	_alley_rats.clear()
	_night2_porch_mark = null
	_night3_school_mark = null
	_ash_particles = null


func rebuild_dressing() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()

	_mesh_cache.clear()
	_shape_cache.clear()
	_sodium_lights.clear()
	_watcher_windows.clear()
	_alley_rats.clear()
	_night2_porch_mark = null
	_night3_school_mark = null
	_ash_particles = null
	_init_textures()
	_init_materials()

	_build_abandoned_city_facades()
	_build_graffiti_murals()
	_build_alley_and_curb_clutter()
	_build_ground_litter_and_puddles()
	_build_powerlines_and_sodium_lights()
	_build_steaming_manholes_watchers_and_ash()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_flicker_t += delta
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	var night_now: bool = bool(dn.call("is_nighttime")) if (dn != null and dn.has_method("is_nighttime")) else true
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D

	for i: int in range(_sodium_lights.size()):
		var entry: Dictionary = _sodium_lights[i]
		var light: OmniLight3D = entry["light"] as OmniLight3D
		var bulb_mat: StandardMaterial3D = entry["mat"] as StandardMaterial3D
		var seed_off: float = float(entry["seed"])
		if not night_now:
			if light != null:
				light.visible = false
			if bulb_mat != null:
				bulb_mat.emission_enabled = false
			continue
		var buzz: float = sin((_flicker_t + seed_off) * 29.0) * sin((_flicker_t + seed_off) * 7.3)
		var alive: bool = buzz > -0.68
		var energy: float = (0.72 + 0.28 * sin((_flicker_t + seed_off) * 4.5)) if alive else 0.14
		if light != null:
			light.visible = true
			light.light_energy = energy * 1.15
		if bulb_mat != null:
			bulb_mat.emission_enabled = true
			bulb_mat.emission_energy_multiplier = 2.0 if alive else 0.3

	# Partículas de cinzas e fuligem acompanhando o jogador nas ruas e becos
	if _ash_particles != null and player != null:
		var p_pos: Vector3 = player.global_position
		var inside_home: bool = p_pos.x >= -7.9 and p_pos.x <= 7.9 and p_pos.z >= -6.9 and p_pos.z <= 6.9 and p_pos.y >= -0.4
		var underground: bool = p_pos.y < -1.0
		_ash_particles.global_position = p_pos + Vector3(0.0, 2.4, 0.0)
		_ash_particles.emitting = not inside_home and not underground

	# Janelas Vigiadas ("Cidade Vigiada"): velas no 2º/3º andar se apagam quando o jogador se aproxima
	if player != null:
		var p_pos: Vector3 = player.global_position
		for w_idx: int in range(_watcher_windows.size()):
			var w: Dictionary = _watcher_windows[w_idx]
			var w_pos: Vector3 = w["pos"] as Vector3
			var w_light: OmniLight3D = w["light"] as OmniLight3D
			var w_mat: StandardMaterial3D = w["mat"] as StandardMaterial3D
			var spooked_t: float = float(w["spooked_timer"])
			var dist_xz: float = Vector2(p_pos.x - w_pos.x, p_pos.z - w_pos.z).length()
			if dist_xz < 8.8 and spooked_t <= 0.0:
				spooked_t = 28.0
				w["spooked_timer"] = spooked_t
			elif spooked_t > 0.0:
				if dist_xz > 18.0:
					spooked_t = maxf(0.0, spooked_t - delta)
					w["spooked_timer"] = spooked_t
			var show_candle: bool = night_now and (spooked_t <= 0.0)
			if w_light != null:
				w_light.visible = show_candle
				if show_candle:
					var c_seed: float = float(w["seed"])
					w_light.light_energy = 0.55 + 0.18 * sin((_flicker_t + c_seed) * 6.4)
			if w_mat != null:
				w_mat.emission_enabled = show_candle
				w_mat.albedo_color = Color(0.95, 0.62, 0.24) if show_candle else Color(0.05, 0.05, 0.07)

		# Ratos de beco que fogem para baixo das caçambas/frestas quando o jogador se aproxima
		for r_idx: int in range(_alley_rats.size()):
			var r: Dictionary = _alley_rats[r_idx]
			var r_node: Node3D = r["node"] as Node3D
			if r_node == null:
				continue
			var home_p: Vector3 = r["home"] as Vector3
			var hide_p: Vector3 = r["hide"] as Vector3
			var flee_t: float = float(r["flee_timer"])
			if p_pos.distance_to(home_p) < 6.2:
				flee_t = 14.0
				r["flee_timer"] = flee_t
			elif flee_t > 0.0 and p_pos.distance_to(home_p) > 12.0:
				flee_t = maxf(0.0, flee_t - delta)
				r["flee_timer"] = flee_t
			var target_p: Vector3 = hide_p if flee_t > 0.0 else home_p
			r_node.position = r_node.position.move_toward(target_p, (4.8 if flee_t > 0.0 else 1.4) * delta)
			r_node.visible = r_node.position.distance_to(hide_p) > 0.12

	if _night2_porch_mark != null and dn != null and dn.has_method("get_night_number"):
		var cur_n: int = int(dn.call("get_night_number"))
		_night2_porch_mark.visible = cur_n >= 2
		if _night3_school_mark != null:
			_night3_school_mark.visible = cur_n >= 3


# --------------------------------------------------------------------------- Texturas & Materiais PS1

func _init_textures() -> void:
	_textures.clear()
	_textures["graffiti_a"] = _make_graffiti_brick_texture(101, true)
	_textures["graffiti_b"] = _make_graffiti_brick_texture(202, false)
	_textures["ruin_wall"] = _make_ruined_concrete_texture(303)
	_textures["crate"] = _make_crate_texture(404)
	_textures["rust_sheet"] = _make_corrugated_rust_texture(505)
	_textures["litter"] = _make_litter_sheet_texture(606)


func _init_materials() -> void:
	_materials.clear()
	_materials["ruin_brick"] = _make_mat(Color(0.46, 0.34, 0.28), _textures["graffiti_a"] as Texture2D, Vector2(3.0, 4.0))
	_materials["ruin_concrete"] = _make_mat(Color(0.40, 0.39, 0.37), _textures["ruin_wall"] as Texture2D, Vector2(3.0, 4.0))
	_materials["ruin_dark"] = _make_mat(Color(0.24, 0.23, 0.22), _textures["ruin_wall"] as Texture2D, Vector2(2.0, 3.0))
	_materials["win_dark"] = _make_mat(Color(0.06, 0.06, 0.08))
	_materials["graffiti_a"] = _make_mat(Color(0.86, 0.80, 0.72), _textures["graffiti_a"] as Texture2D, Vector2(1.0, 1.0))
	_materials["graffiti_b"] = _make_mat(Color(0.86, 0.80, 0.72), _textures["graffiti_b"] as Texture2D, Vector2(1.0, 1.0))
	_materials["crate_wood"] = _make_mat(Color(0.56, 0.42, 0.26), _textures["crate"] as Texture2D, Vector2(1.0, 1.0))
	_materials["rust_sheet"] = _make_mat(Color(0.50, 0.31, 0.22), _textures["rust_sheet"] as Texture2D, Vector2(2.0, 2.0))
	_materials["dumpster"] = _make_mat(Color(0.18, 0.24, 0.19), _textures["rust_sheet"] as Texture2D, Vector2(2.0, 1.0))
	_materials["trash_bag"] = _make_mat(Color(0.08, 0.08, 0.09))
	_materials["cable"] = _make_mat(Color(0.05, 0.05, 0.06))
	_materials["litter_paper"] = _make_mat(Color(0.76, 0.72, 0.62), _textures["litter"] as Texture2D, Vector2(1.0, 1.0))
	_materials["litter_grime"] = _make_mat(Color(0.12, 0.11, 0.10))
	_materials["barrier"] = _make_mat(Color(0.46, 0.45, 0.43), _textures["ruin_wall"] as Texture2D, Vector2(2.0, 1.0))
	var puddle_mat: StandardMaterial3D = StandardMaterial3D.new()
	puddle_mat.albedo_color = Color(0.06, 0.07, 0.08, 1.0)
	puddle_mat.metallic = 0.55
	puddle_mat.roughness = 0.07
	_materials["wet_puddle"] = puddle_mat


func _make_mat(color: Color, tex: Texture2D = null, uv_scale: Vector2 = Vector2(1.0, 1.0)) -> Material:
	if PSX_LIT_SHADER != null:
		var smat: ShaderMaterial = ShaderMaterial.new()
		smat.shader = PSX_LIT_SHADER
		smat.set_shader_parameter("modulate_color", color)
		smat.set_shader_parameter("uv_scale", uv_scale)
		smat.set_shader_parameter("snap_resolution", Vector2(320.0, 180.0))
		if tex != null:
			smat.set_shader_parameter("albedo_texture", tex)
		return smat
	var std: StandardMaterial3D = StandardMaterial3D.new()
	std.albedo_color = color
	return std


func _make_graffiti_brick_texture(seed_val: int, with_smile_tag: bool) -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	for y: int in range(64):
		var row: int = y / 6
		var shift: int = 8 if (row % 2) == 1 else 0
		var mh: bool = (y % 6) == 0
		var soot: float = 0.48 + 0.52 * clampf(float(64 - y) / 28.0, 0.0, 1.0)
		for x: int in range(64):
			var mv: bool = ((x + shift) % 14) == 0
			var c: Color = Color(0.28, 0.24, 0.22) if (mh or mv) else Color(0.56, 0.34, 0.25)
			var n: float = rng.randf_range(-0.08, 0.08)
			img.set_pixel(x, y, Color(clampf(c.r * soot + n, 0.06, 0.9), clampf(c.g * soot + n, 0.05, 0.8), clampf(c.b * soot + n, 0.05, 0.75), 1.0))

	# Pichações estilo PS1
	var black_tag: Color = Color(0.06, 0.05, 0.05)
	var green_tag: Color = Color(0.28, 0.46, 0.22)
	var rust_tag: Color = Color(0.68, 0.22, 0.14)
	for i: int in range(18):
		var px: int = clampi(8 + i * 2 + int(sin(float(i) * 0.8) * 3.0), 3, 60)
		var py: int = clampi(24 + int(cos(float(i) * 1.1) * 7.0), 4, 58)
		img.set_pixel(px, py, black_tag)
		img.set_pixel(px + 1, py, black_tag)
		if i % 3 == 0:
			img.set_pixel(px, py - 1, black_tag)

	if with_smile_tag:
		# Símbolo distorcido do culto em vermelho/preto
		for a: int in range(24):
			var ang: float = float(a) * TAU / 24.0
			var cx: int = clampi(int(round(46.0 + cos(ang) * 9.0)), 2, 61)
			var cy: int = clampi(int(round(20.0 + sin(ang) * 9.0)), 2, 61)
			img.set_pixel(cx, cy, rust_tag)
		img.set_pixel(43, 17, black_tag)
		img.set_pixel(49, 17, black_tag)
		for sx: int in range(41, 52):
			var sy: int = 23 + int(absf(float(sx - 46)) * 0.25)
			img.set_pixel(sx, sy, rust_tag)
	else:
		# Mancha verde ácida no muro inferior
		for gx: int in range(12, 46):
			var gy: int = clampi(42 + int(sin(float(gx) * 0.35) * 4.0), 4, 60)
			img.set_pixel(gx, gy, green_tag)
			img.set_pixel(gx, gy - 1, green_tag)

	return ImageTexture.create_from_image(img)


func _make_ruined_concrete_texture(seed_val: int) -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	for y: int in range(64):
		var streak: float = 0.16 if (y > 46 or y < 8) else 0.0
		var seam: bool = (y % 32) == 0
		for x: int in range(64):
			var v: float = 0.48 if seam else clampf(0.84 - streak + rng.randf_range(-0.10, 0.08), 0.34, 0.96)
			if (x * 5 + y * 2) % 61 == 0:
				v *= 0.65
			img.set_pixel(x, y, Color(v * 0.98, v * 0.96, v * 0.92, 1.0))
	return ImageTexture.create_from_image(img)


func _make_crate_texture(seed_val: int) -> ImageTexture:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	for y: int in range(32):
		for x: int in range(32):
			var border: bool = x < 3 or x >= 29 or y < 3 or y >= 29
			var diag: bool = absi(x - y) <= 1 or absi((31 - x) - y) <= 1
			var slat: bool = (y % 8) == 0
			var v: float = 0.52 if border else (0.62 if diag else (0.48 if slat else 0.86))
			v = clampf(v + rng.randf_range(-0.06, 0.06), 0.3, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.88, v * 0.72, 1.0))
	return ImageTexture.create_from_image(img)


func _make_corrugated_rust_texture(seed_val: int) -> ImageTexture:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	for y: int in range(32):
		for x: int in range(32):
			var rib: float = 0.72 if (x % 4) == 0 else (1.02 if (x % 4) == 2 else 0.88)
			var rust: float = 0.78 if ((x * 7 + y * 3) % 13) < 4 else 1.0
			var n: float = rng.randf_range(-0.05, 0.05)
			img.set_pixel(x, y, Color(clampf(rib * rust + n, 0.25, 1.0), clampf(rib * rust * 0.76 + n, 0.2, 0.95), clampf(rib * rust * 0.65 + n, 0.18, 0.9), 1.0))
	return ImageTexture.create_from_image(img)


func _make_litter_sheet_texture(seed_val: int) -> ImageTexture:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	for y: int in range(16):
		for x: int in range(16):
			var col: Color = Color(0.84, 0.80, 0.70) if (y % 3 != 0) else Color(0.45, 0.42, 0.36)
			if x == 0 or x == 15 or y == 0 or y == 15:
				col = Color(0.28, 0.25, 0.20)
			var j: float = rng.randf_range(-0.06, 0.06)
			img.set_pixel(x, y, Color(clampf(col.r + j, 0.1, 1.0), clampf(col.g + j, 0.1, 1.0), clampf(col.b + j, 0.1, 1.0), 1.0))
	return ImageTexture.create_from_image(img)


# --------------------------------------------------------------------------- Helpers de Geometria

func _get_box_mesh(size: Vector3) -> BoxMesh:
	if _mesh_cache.has(size):
		return _mesh_cache[size] as BoxMesh
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	m.subdivide_width = clampi(int(size.x / 3.0), 0, 6)
	m.subdivide_depth = clampi(int(size.z / 3.0), 0, 6)
	_mesh_cache[size] = m
	return m


func _get_box_shape(size: Vector3) -> BoxShape3D:
	if _shape_cache.has(size):
		return _shape_cache[size] as BoxShape3D
	var s: BoxShape3D = BoxShape3D.new()
	s.size = size
	_shape_cache[size] = s
	return s


func _add_box(p: Node3D, n: String, size: Vector3, pos: Vector3, mat_key: String, rot_deg: Vector3 = Vector3.ZERO, with_col: bool = true, cull_dist: float = 0.0) -> Node3D:
	if with_col:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = n
		body.position = pos
		body.rotation_degrees = rot_deg
		body.collision_layer = LAYER_ENVIRONMENT
		body.collision_mask = 0
		p.add_child(body)
		var m: MeshInstance3D = MeshInstance3D.new()
		m.mesh = _get_box_mesh(size)
		m.material_override = _materials.get(mat_key, null) as Material
		if cull_dist > 0.0:
			m.visibility_range_end = cull_dist
		body.add_child(m)
		var col: CollisionShape3D = CollisionShape3D.new()
		col.shape = _get_box_shape(size)
		body.add_child(col)
		return body
	var m_only: MeshInstance3D = MeshInstance3D.new()
	m_only.name = n
	m_only.position = pos
	m_only.rotation_degrees = rot_deg
	m_only.mesh = _get_box_mesh(size)
	m_only.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if cull_dist > 0.0:
		m_only.visibility_range_end = cull_dist
	m_only.material_override = _materials.get(mat_key, null) as Material
	p.add_child(m_only)
	return m_only


# --------------------------------------------------------------------------- Camadas da Cidade

func _build_abandoned_city_facades() -> void:
	var g: Node3D = Node3D.new()
	g.name = "AbandonedCityFacades"
	add_child(g)

	# 1. Segunda fileira de prédios altos atrás do Quarteirão Sul (Z = 25.8) formando cânion urbano profundo
	var south_blocks: Array[Dictionary] = [
		{"pos": Vector3(-54.0, 7.2, 26.2), "size": Vector3(16.0, 14.4, 5.5), "mat": "ruin_brick"},
		{"pos": Vector3(-35.0, 6.6, 26.2), "size": Vector3(15.0, 13.2, 5.5), "mat": "ruin_concrete"},
		{"pos": Vector3(-16.0, 7.8, 26.0), "size": Vector3(15.0, 15.6, 5.2), "mat": "ruin_brick"},
		{"pos": Vector3(15.0, 7.6, 26.0), "size": Vector3(16.0, 15.2, 5.2), "mat": "ruin_concrete"},
		{"pos": Vector3(33.0, 6.8, 26.0), "size": Vector3(12.0, 13.6, 5.4), "mat": "ruin_brick"},
		{"pos": Vector3(53.0, 7.4, 26.2), "size": Vector3(18.0, 14.8, 5.5), "mat": "ruin_concrete"},
	]
	for i: int in range(south_blocks.size()):
		var b: Dictionary = south_blocks[i]
		var sz: Vector3 = b["size"] as Vector3
		var ps: Vector3 = b["pos"] as Vector3
		var mk: String = str(b["mat"])
		_add_box(g, "SouthTenement_%d" % i, sz, ps, mk, Vector3.ZERO, false)
		_add_box(g, "SouthCornice_%d" % i, Vector3(sz.x + 0.5, 0.35, sz.z + 0.4), Vector3(ps.x, ps.y * 2.0, ps.z), "ruin_dark", Vector3.ZERO, false)
		for wx_off: float in [-sz.x * 0.28, 0.0, sz.x * 0.28]:
			_add_box(g, "SouthWinHi", Vector3(1.5, 2.0, 0.14), Vector3(ps.x + wx_off, 10.6, ps.z - sz.z * 0.5 - 0.02), "win_dark", Vector3.ZERO, false, 78.0)

	# 2. Andar superior em ruína sobre o Mini-Mercado e Casa Vizinha (fecha o cânion vertical dos becos)
	_add_box(g, "MarketUpperTenement", Vector3(8.0, 4.8, 14.4), Vector3(-21.5, 7.0, -0.25), "ruin_brick", Vector3.ZERO, false)
	_add_box(g, "MarketUpperCornice", Vector3(8.5, 0.35, 14.9), Vector3(-21.5, 9.5, -0.25), "ruin_dark", Vector3.ZERO, false)
	_add_box(g, "NeighborUpperTenement", Vector3(8.0, 4.6, 14.4), Vector3(21.5, 6.7, 0.25), "ruin_concrete", Vector3.ZERO, false)
	_add_box(g, "NeighborUpperCornice", Vector3(8.5, 0.35, 14.9), Vector3(21.5, 9.1, 0.25), "ruin_dark", Vector3.ZERO, false)
	for wz: float in [-4.5, 0.0, 4.2]:
		_add_box(g, "MarketUpperWinE", Vector3(0.12, 1.7, 1.3), Vector3(-17.46, 6.8, wz), "win_dark", Vector3.ZERO, false, 68.0)
		_add_box(g, "NeighborUpperWinW", Vector3(0.12, 1.7, 1.3), Vector3(17.46, 6.6, wz), "win_dark", Vector3.ZERO, false, 68.0)
		# Janelas e sacadas de ferro nos Sobrados Oeste e Leste (voltadas para os becos)
		_add_box(g, "SobradoW_WinW", Vector3(0.12, 1.6, 1.2), Vector3(-14.54, 6.0, wz), "win_dark", Vector3.ZERO, false, 64.0)
		_add_box(g, "SobradoW_WinE", Vector3(0.12, 1.6, 1.2), Vector3(-10.86, 6.0, wz), "win_dark", Vector3.ZERO, false, 64.0)
		_add_box(g, "SobradoE_WinW", Vector3(0.12, 1.6, 1.2), Vector3(10.86, 5.8, wz), "win_dark", Vector3.ZERO, false, 64.0)
		_add_box(g, "SobradoE_WinE", Vector3(0.12, 1.6, 1.2), Vector3(14.54, 5.8, wz), "win_dark", Vector3.ZERO, false, 64.0)

	# 3. Vigas, tubulações aéreas e passadiços metálicos cruzando o alto dos becos (Y = 4.2..7.5, igual à Imagem 2)
	_add_box(g, "AlleyMarket_OverbeamA", Vector3(3.0, 0.35, 0.45), Vector3(-16.0, 5.2, 3.2), "ruin_dark", Vector3.ZERO, false, 60.0)
	_add_box(g, "AlleyMarket_OverbeamB", Vector3(3.0, 0.35, 0.45), Vector3(-16.0, 6.4, -3.2), "ruin_dark", Vector3.ZERO, false, 60.0)
	_add_box(g, "AlleyMarket_FireBalcony", Vector3(0.75, 0.18, 2.8), Vector3(-14.85, 4.6, 2.0), "rust_sheet", Vector3.ZERO, false, 58.0)
	_add_box(g, "AlleyHouseW_Overbeam", Vector3(2.9, 0.32, 0.40), Vector3(-9.45, 5.4, -2.5), "ruin_dark", Vector3.ZERO, false, 60.0)
	_add_box(g, "AlleyHouseE_Overbeam", Vector3(2.9, 0.32, 0.40), Vector3(9.45, 5.4, 2.2), "ruin_dark", Vector3.ZERO, false, 60.0)
	_add_box(g, "AlleyNeighbor_OverbeamA", Vector3(3.0, 0.35, 0.45), Vector3(16.0, 5.1, 2.8), "ruin_dark", Vector3.ZERO, false, 60.0)
	_add_box(g, "AlleyNeighbor_OverbeamB", Vector3(3.0, 0.35, 0.45), Vector3(16.0, 6.3, -3.0), "ruin_dark", Vector3.ZERO, false, 60.0)
	_add_box(g, "AlleyNeighbor_FireBalcony", Vector3(0.75, 0.18, 2.8), Vector3(14.85, 4.5, -1.5), "rust_sheet", Vector3.ZERO, false, 58.0)

	# 4. Detalhes de janelas nos prédios laterais da Avenida da Escola
	for wy: float in [3.2, 6.4]:
		for wz_av: float in [-35.0, -30.0, -25.0]:
			_add_box(g, "RuinWinW", Vector3(0.14, 1.5, 1.6), Vector3(-14.55, wy, wz_av), "win_dark", Vector3.ZERO, false, 64.0)
			_add_box(g, "RuinWinE", Vector3(0.14, 1.5, 1.6), Vector3(14.55, wy, wz_av), "win_dark", Vector3.ZERO, false, 64.0)

	# 5. Camada extra de prédios altos, torres d'água, aparelhos de ar-condicionado e canos verticais nos becos
	var skyline_towers: Array[Dictionary] = [
		{"pos": Vector3(-44.0, 8.5, -26.5), "size": Vector3(14.0, 17.0, 6.0), "mat": "ruin_brick"},
		{"pos": Vector3(38.0, 8.2, -29.5), "size": Vector3(15.0, 16.4, 6.0), "mat": "ruin_concrete"},
		{"pos": Vector3(58.0, 8.8, -29.5), "size": Vector3(16.0, 17.6, 6.0), "mat": "ruin_brick"},
		{"pos": Vector3(-72.0, 8.0, -14.0), "size": Vector3(6.0, 16.0, 14.0), "mat": "ruin_concrete"},
		{"pos": Vector3(76.0, 8.4, -10.0), "size": Vector3(6.0, 16.8, 16.0), "mat": "ruin_brick"},
	]
	for t_idx: int in range(skyline_towers.size()):
		var td: Dictionary = skyline_towers[t_idx]
		_add_box(g, "OuterSkylineTower_%d" % t_idx, td["size"] as Vector3, td["pos"] as Vector3, str(td["mat"]), Vector3.ZERO, false, 95.0)

	# Caixas de ar-condicionado enferrujadas, canos de esgoto verticais e placas tortas penduradas nos becos (sem colisão)
	var alley_wall_details: Array[Dictionary] = [
		{"pos": Vector3(-17.32, 3.6, 1.2), "size": Vector3(0.42, 0.55, 0.72), "mat": "rust_sheet"},
		{"pos": Vector3(-14.68, 4.1, -1.8), "size": Vector3(0.42, 0.55, 0.72), "mat": "rust_sheet"},
		{"pos": Vector3(-10.72, 3.8, 2.5), "size": Vector3(0.42, 0.55, 0.72), "mat": "rust_sheet"},
		{"pos": Vector3(10.72, 3.9, -2.0), "size": Vector3(0.42, 0.55, 0.72), "mat": "rust_sheet"},
		{"pos": Vector3(14.68, 3.7, 1.5), "size": Vector3(0.42, 0.55, 0.72), "mat": "rust_sheet"},
		{"pos": Vector3(-17.40, 4.5, 4.8), "size": Vector3(0.12, 9.0, 0.12), "mat": "ruin_dark"},
		{"pos": Vector3(-14.60, 4.5, -4.8), "size": Vector3(0.12, 9.0, 0.12), "mat": "ruin_dark"},
		{"pos": Vector3(14.60, 4.5, 4.5), "size": Vector3(0.12, 9.0, 0.12), "mat": "ruin_dark"},
		{"pos": Vector3(-15.1, 3.4, 6.6), "size": Vector3(0.95, 0.55, 0.08), "mat": "rust_sheet"},
		{"pos": Vector3(15.1, 3.4, 6.8), "size": Vector3(0.95, 0.55, 0.08), "mat": "rust_sheet"},
	]
	for d_idx: int in range(alley_wall_details.size()):
		var ad: Dictionary = alley_wall_details[d_idx]
		_add_box(g, "AlleyWallDetail_%d" % d_idx, ad["size"] as Vector3, ad["pos"] as Vector3, str(ad["mat"]), Vector3.ZERO, false, 58.0)


func _build_graffiti_murals() -> void:
	var m: Node3D = Node3D.new()
	m.name = "GraffitiMurals"
	add_child(m)

	# Murais grafiteados encostados nas paredes de tijolo dos becos estreitos
	var panels: Array[Dictionary] = [
		# Beco do Mini-Mercado (paredes X=-17.46 e X=-14.54)
		{"pos": Vector3(-17.34, 1.75, 2.2), "size": Vector3(0.04, 3.0, 5.2), "mat": "graffiti_a"},
		{"pos": Vector3(-17.34, 1.65, -1.8), "size": Vector3(0.04, 2.6, 3.0), "mat": "graffiti_b"},
		{"pos": Vector3(-14.54, 1.70, 3.6), "size": Vector3(0.04, 2.8, 4.2), "mat": "graffiti_b"},
		{"pos": Vector3(-14.54, 1.65, -3.8), "size": Vector3(0.04, 2.6, 3.8), "mat": "graffiti_a"},
		# Beco Oeste da Casa Principal (paredes X=-10.86 e X=-8.15)
		{"pos": Vector3(-10.86, 1.65, 3.4), "size": Vector3(0.04, 2.7, 4.0), "mat": "graffiti_a"},
		{"pos": Vector3(-8.15, 1.65, -2.2), "size": Vector3(0.04, 2.8, 4.8), "mat": "graffiti_b"},
		# Beco Leste da Casa & Beco da Vizinha (paredes X=+8.15, +10.86, +14.54, +17.45)
		{"pos": Vector3(8.15, 1.65, 2.2), "size": Vector3(0.04, 2.8, 4.2), "mat": "graffiti_b"},
		{"pos": Vector3(10.86, 1.65, -3.5), "size": Vector3(0.04, 2.6, 3.8), "mat": "graffiti_a"},
		{"pos": Vector3(14.54, 1.70, 3.5), "size": Vector3(0.04, 2.8, 4.2), "mat": "graffiti_b"},
		{"pos": Vector3(17.45, 1.65, 1.5), "size": Vector3(0.04, 2.8, 4.8), "mat": "graffiti_a"},
		# Becos Sul Oeste e Leste + Barricadas do Portão da Escola e Posto
		{"pos": Vector3(-18.45, 1.65, 19.2), "size": Vector3(0.04, 2.6, 4.2), "mat": "graffiti_a"},
		{"pos": Vector3(14.55, 1.65, 19.2), "size": Vector3(0.04, 2.6, 4.2), "mat": "graffiti_b"},
		{"pos": Vector3(-7.5, 1.35, -19.65), "size": Vector3(5.6, 2.4, 0.04), "mat": "graffiti_a"},
		{"pos": Vector3(9.5, 1.35, -19.65), "size": Vector3(5.6, 2.4, 0.04), "mat": "graffiti_b"},
		{"pos": Vector3(-46.0, 1.45, 0.2), "size": Vector3(0.04, 2.5, 3.8), "mat": "graffiti_a"},
	]
	for idx: int in range(panels.size()):
		var d: Dictionary = panels[idx]
		_add_box(m, "Mural_%d" % idx, d["size"] as Vector3, d["pos"] as Vector3, str(d["mat"]), Vector3.ZERO, false, 58.0)


func _build_alley_and_curb_clutter() -> void:
	var c: Node3D = Node3D.new()
	c.name = "AlleyAndCurbClutter"
	add_child(c)

	# Todos os props decorativos laterais dos becos usam with_col=false para NUNCA travar ou estreitar a passagem do jogador!
	_add_box(c, "AlleyLeanSheet", Vector3(0.08, 2.1, 1.8), Vector3(-17.18, 1.0, 1.6), "rust_sheet", Vector3(0.0, 6.0, -11.0), false, 48.0)
	_add_box(c, "AlleyCrateLow", Vector3(0.72, 0.68, 0.72), Vector3(-14.92, 0.34, 3.4), "crate_wood", Vector3(0.0, 14.0, 0.0), false, 48.0)
	_add_box(c, "AlleyCrateNorth", Vector3(0.70, 0.65, 0.70), Vector3(-14.92, 0.32, -5.6), "crate_wood", Vector3(0.0, -10.0, 0.0), false, 48.0)
	_add_box(c, "AlleyTrashA", Vector3(0.65, 0.55, 0.65), Vector3(-16.95, 0.28, 5.9), "trash_bag", Vector3(0.0, 22.0, 0.0), false, 42.0)
	_add_box(c, "AlleyTrashB", Vector3(0.55, 0.48, 0.58), Vector3(-14.95, 0.24, 6.2), "trash_bag", Vector3(0.0, -18.0, 0.0), false, 42.0)

	# Beco Oeste da Casa (X: -10.9..-8.0) e Viela Traseira (Z: -10.4..-7.0)
	_add_box(c, "WestHouseAlleyCrate", Vector3(0.68, 0.68, 0.68), Vector3(-10.50, 0.34, -3.2), "crate_wood", Vector3(0.0, 9.0, 0.0), false, 48.0)
	_add_box(c, "BackLaneDumpsterW", Vector3(1.8, 1.05, 0.80), Vector3(-19.5, 0.52, -9.95), "dumpster", Vector3(0.0, 3.0, 0.0), false, 50.0)
	_add_box(c, "BackLaneDumpsterE", Vector3(1.8, 1.05, 0.80), Vector3(19.5, 0.52, -9.95), "dumpster", Vector3(0.0, -4.0, 0.0), false, 50.0)

	# Beco Leste da Casa (X: +8.0..+10.9) e Beco da Vizinha (X: +14.5..+17.5)
	_add_box(c, "EastAlleyDumpster", Vector3(0.82, 1.10, 1.8), Vector3(17.02, 0.55, -1.8), "dumpster", Vector3(0.0, 4.0, 0.0), false, 52.0)
	_add_box(c, "EastAlleySheet", Vector3(0.08, 1.9, 1.6), Vector3(14.85, 0.92, 2.4), "rust_sheet", Vector3(0.0, -5.0, 10.0), false, 48.0)
	_add_box(c, "EastAlleyCrate", Vector3(0.72, 0.72, 0.72), Vector3(8.50, 0.36, 4.8), "crate_wood", Vector3(0.0, -12.0, 0.0), false, 48.0)

	# Becos Sul e Galeria Comercial Sul
	_add_box(c, "SouthAlleyW_Crate", Vector3(0.75, 0.72, 0.75), Vector3(-18.0, 0.36, 20.2), "crate_wood", Vector3(0.0, 16.0, 0.0), false, 48.0)
	_add_box(c, "SouthAlleyW_Trash", Vector3(0.65, 0.52, 0.65), Vector3(-15.9, 0.26, 20.8), "trash_bag", Vector3.ZERO, false, 42.0)
	_add_box(c, "SouthAlleyE_Crate", Vector3(0.75, 0.72, 0.75), Vector3(17.0, 0.36, 20.4), "crate_wood", Vector3(0.0, -14.0, 0.0), false, 48.0)
	_add_box(c, "SouthAlleyE_Sheet", Vector3(0.08, 1.8, 1.5), Vector3(14.88, 0.88, 19.4), "rust_sheet", Vector3(0.0, 4.0, 10.0), false, 48.0)

	# Calçada Sul e Posto / Capela (sem colisão nos obstáculos de meio-fio para evitar travamentos na calçada)
	_add_box(c, "SouthCurbDumpster", Vector3(2.0, 1.15, 0.95), Vector3(-21.5, 0.58, 16.1), "dumpster", Vector3(0.0, -6.0, 0.0), false, 54.0)
	_add_box(c, "SouthCurbBarrier", Vector3(2.0, 0.75, 0.42), Vector3(10.5, 0.38, 16.1), "barrier", Vector3(0.0, 8.0, 0.0), false, 52.0)
	_add_box(c, "GasCurbCrates", Vector3(1.0, 0.85, 1.0), Vector3(-31.2, 0.42, 8.8), "crate_wood", Vector3(0.0, 18.0, 0.0), false, 50.0)
	_add_box(c, "GasCurbSheet", Vector3(1.7, 1.3, 0.08), Vector3(-32.4, 0.65, 8.6), "rust_sheet", Vector3(16.0, 10.0, 0.0), false, 48.0)
	_add_box(c, "ChapelGateBarricade", Vector3(1.9, 0.72, 0.40), Vector3(39.5, 0.36, 16.1), "barrier", Vector3(0.0, -9.0, 0.0), false, 52.0)


func _build_ground_litter_and_puddles() -> void:
	var lit: Node3D = Node3D.new()
	lit.name = "GroundLitter"
	add_child(lit)

	var spots: Array[Vector2] = [
		# Beco do Mini-Mercado (X: -17.2..-14.8) e Beco Oeste da Casa (X: -10.5..-8.4)
		Vector2(-15.9, 4.8), Vector2(-16.2, 2.2), Vector2(-15.6, -0.6), Vector2(-16.1, -3.4),
		Vector2(-15.8, -5.8), Vector2(-9.5, 4.2), Vector2(-9.2, 0.8), Vector2(-9.6, -4.0),
		# Beco Leste da Casa (X: 8.4..10.5), Beco da Vizinha (X: 14.8..17.2) e Becos Sul
		Vector2(9.4, 3.6), Vector2(9.6, -2.4), Vector2(15.8, 4.4), Vector2(16.1, 1.2),
		Vector2(15.7, -3.6), Vector2(-17.0, 18.5), Vector2(-16.8, 21.0), Vector2(16.0, 19.2),
		# Rua Principal e calçadas
		Vector2(-18.5, 11.4), Vector2(-11.0, 14.2), Vector2(-3.2, 11.8), Vector2(3.8, 14.0),
		Vector2(8.5, 11.2), Vector2(15.2, 13.8), Vector2(19.5, 11.4), Vector2(28.0, 14.2),
		# Avenida Oeste (Posto), Rua Transversal Norte e Avenida da Escola
		Vector2(-30.5, 12.0), Vector2(-36.5, 14.2), Vector2(-42.0, 11.5), Vector2(-49.0, 13.6),
		Vector2(-16.0, -17.2), Vector2(16.0, -17.4), Vector2(-1.4, -22.5), Vector2(1.6, -26.0),
		# Pracinha e Cemitério
		Vector2(27.5, -1.5), Vector2(32.5, 2.2), Vector2(40.5, 12.2), Vector2(49.5, 7.8),
	]
	for i: int in range(spots.size()):
		var p: Vector2 = spots[i]
		var is_grime: bool = (i % 3) == 1
		var sz: Vector3 = Vector3(1.15, 0.02, 0.95) if is_grime else Vector3(0.46, 0.015, 0.36)
		var mat_k: String = "litter_grime" if is_grime else "litter_paper"
		var yaw: float = float((i * 37) % 180)
		_add_box(lit, "Litter_%d" % i, sz, Vector3(p.x, 0.018 + float(i % 2) * 0.005, p.y), mat_k, Vector3(0.0, yaw, 0.0), false, 44.0)

	# Poças d'água escura / óleo com reflexo especular nos becos e avenidas
	var puddle_spots: Array[Vector3] = [
		Vector3(-16.0, 0.014, 1.0),
		Vector3(-16.1, 0.014, -4.5),
		Vector3(-9.45, 0.014, -1.2),
		Vector3(9.45, 0.014, 1.4),
		Vector3(16.0, 0.014, -0.8),
		Vector3(-14.2, 0.014, 12.6),
		Vector3(15.8, 0.014, 13.1),
		Vector3(-35.5, 0.014, 12.2),
		Vector3(0.0, 0.014, -28.0),
	]
	for p_idx: int in range(puddle_spots.size()):
		var pp: Vector3 = puddle_spots[p_idx]
		var psz: Vector3 = Vector3(1.65 + float(p_idx % 3) * 0.45, 0.01, 1.25 + float(p_idx % 2) * 0.40)
		var puddle_node: Node3D = _add_box(lit, "WetPuddle_%d" % p_idx, psz, pp, "wet_puddle", Vector3(0.0, float(p_idx * 29), 0.0), false, 52.0)
		puddle_node.add_to_group("wet_puddle")


func _build_powerlines_and_sodium_lights() -> void:
	var pwr: Node3D = Node3D.new()
	pwr.name = "PowerLinesAndStreetlights"
	add_child(pwr)

	# Cabos aéreos cruzando a avenida pelos postes existentes
	var cable_spans: Array[Dictionary] = [
		{"pos": Vector3(-19.5, 4.45, 10.1), "len": 16.0},
		{"pos": Vector3(-5.0, 4.42, 10.1), "len": 14.0},
		{"pos": Vector3(11.0, 4.44, 10.1), "len": 18.0},
		{"pos": Vector3(24.0, 4.45, 10.1), "len": 15.0},
		{"pos": Vector3(-36.0, 4.42, 10.1), "len": 18.0},
		{"pos": Vector3(44.0, 4.44, 10.1), "len": 16.0},
	]
	for idx: int in range(cable_spans.size()):
		var sp: Dictionary = cable_spans[idx]
		_add_box(pwr, "PowerCable_%d" % idx, Vector3(float(sp["len"]), 0.035, 0.035), sp["pos"] as Vector3, "cable", Vector3.ZERO, false, 64.0)

	# Poste extra na entrada do Posto (X=-31.0, Z=9.8) sem colisão para não prender na calçada
	_add_box(pwr, "GasApproachPole", Vector3(0.16, 4.6, 0.16), Vector3(-31.0, 2.3, 9.8), "ruin_dark", Vector3.ZERO, false)
	_add_box(pwr, "GasApproachArm", Vector3(0.12, 0.12, 1.25), Vector3(-31.0, 4.5, 10.4), "ruin_dark", Vector3.ZERO, false)

	# 3 Lâmpadas de sódio moribundas com iluminação quente à noite
	var light_positions: Array[Vector3] = [
		Vector3(-14.5, 4.25, 10.85),
		Vector3(16.2, 4.25, 10.85),
		Vector3(-31.0, 4.25, 10.85),
	]
	for idx: int in range(light_positions.size()):
		var lpos: Vector3 = light_positions[idx]
		var b_mat: StandardMaterial3D = StandardMaterial3D.new()
		b_mat.albedo_color = Color(1.0, 0.72, 0.30)
		b_mat.emission_enabled = true
		b_mat.emission = Color(1.0, 0.62, 0.20)
		b_mat.emission_energy_multiplier = 2.0

		var bulb: MeshInstance3D = MeshInstance3D.new()
		bulb.name = "SodiumBulb_%d" % idx
		bulb.mesh = _get_box_mesh(Vector3(0.24, 0.10, 0.36))
		bulb.position = lpos + Vector3(0.0, 0.10, 0.0)
		bulb.material_override = b_mat
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bulb.visibility_range_end = 56.0
		pwr.add_child(bulb)

		var l3: OmniLight3D = OmniLight3D.new()
		l3.name = "SodiumOmni_%d" % idx
		l3.position = lpos
		l3.light_color = Color(1.0, 0.65, 0.24)
		l3.light_energy = 1.15
		l3.omni_range = 9.5
		l3.shadow_enabled = false
		l3.distance_fade_enabled = true
		l3.distance_fade_begin = 26.0
		l3.distance_fade_length = 8.0
		pwr.add_child(l3)

		_sodium_lights.append({
			"light": l3,
			"mat": b_mat,
			"seed": float(idx) * 3.7,
		})


func _build_steaming_manholes_watchers_and_ash() -> void:
	var fx: Node3D = Node3D.new()
	fx.name = "UrbanAtmosphereFX"
	add_child(fx)

	# 1. Bueiros fumegantes (vapor subindo das grelhas de esgoto nos becos e ruas)
	var steam_mat: StandardMaterial3D = StandardMaterial3D.new()
	steam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	steam_mat.albedo_color = Color(0.68, 0.64, 0.56, 0.18)
	steam_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	var puff_mesh: QuadMesh = QuadMesh.new()
	puff_mesh.size = Vector2(0.55, 0.55)
	puff_mesh.material = steam_mat

	var manhole_positions: Array[Vector3] = [
		Vector3(-16.0, 0.02, -1.5),
		Vector3(-2.5, 0.02, 13.0),
		Vector3(16.0, 0.02, 2.5),
		Vector3(-28.0, 0.02, 12.8),
		Vector3(0.0, 0.02, -17.5),
	]
	for m_idx: int in range(manhole_positions.size()):
		var mp: Vector3 = manhole_positions[m_idx]
		_add_box(fx, "ManholeGrate_%d" % m_idx, Vector3(0.85, 0.02, 0.85), mp, "ruin_dark", Vector3.ZERO, false, 48.0)
		var vap: CPUParticles3D = CPUParticles3D.new()
		vap.name = "ManholeSteam_%d" % m_idx
		vap.position = mp + Vector3(0.0, 0.08, 0.0)
		vap.amount = 10
		vap.lifetime = 2.6
		vap.preprocess = 1.0
		vap.mesh = puff_mesh
		vap.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		vap.emission_box_extents = Vector3(0.25, 0.05, 0.25)
		vap.direction = Vector3(0.12, 1.0, 0.05)
		vap.spread = 18.0
		vap.gravity = Vector3(0.0, 0.18, 0.0)
		vap.initial_velocity_min = 0.28
		vap.initial_velocity_max = 0.52
		vap.scale_amount_min = 0.7
		vap.scale_amount_max = 1.6
		vap.visibility_range_end = 36.0
		fx.add_child(vap)

	# 2. Cinzas e fuligem flutuando no ar ao redor do jogador (visíveis na luz do lampião)
	var ash_mat: StandardMaterial3D = StandardMaterial3D.new()
	ash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ash_mat.albedo_color = Color(0.85, 0.78, 0.65, 0.42)
	ash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var ash_quad: QuadMesh = QuadMesh.new()
	ash_quad.size = Vector2(0.032, 0.032)
	ash_quad.material = ash_mat

	_ash_particles = CPUParticles3D.new()
	_ash_particles.name = "OutdoorFloatingAsh"
	_ash_particles.position = Vector3(0.0, 2.4, 8.0)
	_ash_particles.amount = 42
	_ash_particles.lifetime = 4.2
	_ash_particles.preprocess = 2.0
	_ash_particles.mesh = ash_quad
	_ash_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_ash_particles.emission_box_extents = Vector3(7.5, 2.2, 7.5)
	_ash_particles.direction = Vector3(0.25, -1.0, 0.15)
	_ash_particles.spread = 35.0
	_ash_particles.gravity = Vector3(0.04, -0.14, 0.02)
	_ash_particles.initial_velocity_min = 0.08
	_ash_particles.initial_velocity_max = 0.24
	fx.add_child(_ash_particles)

	# 3. "Cidade Vigiada" — Janelas do 2º/3º andar com luz trêmula de vela que se apaga se o jogador chegar perto
	var watcher_spots: Array[Dictionary] = [
		{"pos": Vector3(-14.55, 6.0, 3.8), "size": Vector3(0.14, 1.45, 1.15), "light_off": Vector3(-0.45, 0.0, 0.0)},
		{"pos": Vector3(14.55, 5.8, -3.8), "size": Vector3(0.14, 1.45, 1.15), "light_off": Vector3(0.45, 0.0, 0.0)},
		{"pos": Vector3(-9.35, 6.8, 16.45), "size": Vector3(1.25, 1.55, 0.14), "light_off": Vector3(0.0, 0.0, -0.45)},
		{"pos": Vector3(26.5, 6.6, 16.45), "size": Vector3(1.25, 1.55, 0.14), "light_off": Vector3(0.0, 0.0, -0.45)},
		{"pos": Vector3(-14.55, 6.4, -29.8), "size": Vector3(0.14, 1.45, 1.25), "light_off": Vector3(0.45, 0.0, 0.0)},
	]
	for w_idx: int in range(watcher_spots.size()):
		var wd: Dictionary = watcher_spots[w_idx]
		var wpos: Vector3 = wd["pos"] as Vector3
		var wsz: Vector3 = wd["size"] as Vector3
		var loff: Vector3 = wd["light_off"] as Vector3

		var c_mat: StandardMaterial3D = StandardMaterial3D.new()
		c_mat.albedo_color = Color(0.95, 0.62, 0.24)
		c_mat.emission_enabled = true
		c_mat.emission = Color(0.95, 0.52, 0.16)
		c_mat.emission_energy_multiplier = 1.35

		var pane: MeshInstance3D = MeshInstance3D.new()
		pane.name = "WatcherWindow_%d" % w_idx
		pane.mesh = _get_box_mesh(wsz)
		pane.position = wpos
		pane.material_override = c_mat
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pane.visibility_range_end = 56.0
		fx.add_child(pane)

		var clight: OmniLight3D = OmniLight3D.new()
		clight.name = "WatcherCandle_%d" % w_idx
		clight.position = wpos + loff
		clight.light_color = Color(1.0, 0.58, 0.20)
		clight.light_energy = 0.6
		clight.omni_range = 4.8
		clight.shadow_enabled = false
		clight.distance_fade_enabled = true
		clight.distance_fade_begin = 24.0
		clight.distance_fade_length = 6.0
		fx.add_child(clight)

		_watcher_windows.append({
			"pos": wpos,
			"light": clight,
			"mat": c_mat,
			"seed": float(w_idx) * 2.3,
			"spooked_timer": 0.0,
		})

	# 4. Ratos low-poly nos becos que correm para as frestas/caçambas quando o jogador se aproxima
	var rat_data: Array[Dictionary] = [
		{"home": Vector3(-15.8, 0.06, 2.8), "hide": Vector3(-17.3, 0.06, 1.6)},
		{"home": Vector3(-16.1, 0.06, -2.5), "hide": Vector3(-14.6, 0.06, -3.4)},
		{"home": Vector3(-9.5, 0.06, -1.8), "hide": Vector3(-10.8, 0.06, -3.2)},
		{"home": Vector3(15.9, 0.06, 0.4), "hide": Vector3(17.1, 0.06, -1.8)},
		{"home": Vector3(-16.8, 0.06, 19.2), "hide": Vector3(-18.2, 0.06, 20.5)},
		{"home": Vector3(16.1, 0.06, 19.0), "hide": Vector3(17.2, 0.06, 20.4)},
	]
	for r_idx: int in range(rat_data.size()):
		var rd: Dictionary = rat_data[r_idx]
		var r_home: Vector3 = rd["home"] as Vector3
		var r_hide: Vector3 = rd["hide"] as Vector3
		var rat_node: Node3D = _add_box(fx, "AlleyRat_%d" % r_idx, Vector3(0.18, 0.10, 0.34), r_home, "trash_bag", Vector3.ZERO, false, 36.0)
		_alley_rats.append({
			"node": rat_node,
			"home": r_home,
			"hide": r_hide,
			"flee_timer": 0.0,
		})

	# 5. Marca de Vigília do Culto na varanda da Casa Principal (revelada a partir da Noite 2) e no pátio da Escola (Noite 3+)
	_night2_porch_mark = _add_box(fx, "Night2PorchCultMark", Vector3(1.1, 0.02, 1.1), Vector3(0.0, 0.025, 7.55), "graffiti_a", Vector3.ZERO, false, 38.0)
	_night2_porch_mark.visible = false
	_night3_school_mark = _add_box(fx, "Night3SchoolCultMark", Vector3(1.5, 0.02, 1.5), Vector3(0.0, 0.03, -24.5), "graffiti_b", Vector3.ZERO, false, 40.0)
	_night3_school_mark.visible = false
