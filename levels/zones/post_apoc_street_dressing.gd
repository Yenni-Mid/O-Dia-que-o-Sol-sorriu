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
var _flicker_t: float = 0.0


func _ready() -> void:
	rebuild_dressing()


func rebuild_dressing() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()

	_mesh_cache.clear()
	_shape_cache.clear()
	_sodium_lights.clear()
	_init_textures()
	_init_materials()

	_build_abandoned_city_facades()
	_build_graffiti_murals()
	_build_alley_and_curb_clutter()
	_build_ground_litter_and_puddles()
	_build_powerlines_and_sodium_lights()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _sodium_lights.is_empty():
		return
	_flicker_t += delta
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	var night_now: bool = bool(dn.call("is_nighttime")) if (dn != null and dn.has_method("is_nighttime")) else true

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

	# 1. Cânion de sobrados e prédios degradados ao sul da rua principal (sem fechar o Abrigo X:-4..+4)
	var south_blocks: Array[Dictionary] = [
		{"pos": Vector3(-50.0, 5.5, 22.0), "size": Vector3(16.0, 11.0, 6.5), "mat": "ruin_brick"},
		{"pos": Vector3(-34.0, 4.6, 21.8), "size": Vector3(13.0, 9.2, 6.5), "mat": "ruin_concrete"},
		{"pos": Vector3(-14.0, 6.2, 23.0), "size": Vector3(14.4, 12.4, 5.4), "mat": "ruin_brick"},
		{"pos": Vector3(17.0, 6.4, 23.0), "size": Vector3(18.0, 12.8, 5.4), "mat": "ruin_concrete"},
		{"pos": Vector3(32.5, 5.0, 21.5), "size": Vector3(9.5, 10.0, 6.0), "mat": "ruin_brick"},
		{"pos": Vector3(52.0, 5.5, 22.5), "size": Vector3(18.0, 11.0, 6.5), "mat": "ruin_concrete"},
	]
	for i: int in range(south_blocks.size()):
		var b: Dictionary = south_blocks[i]
		var sz: Vector3 = b["size"] as Vector3
		var ps: Vector3 = b["pos"] as Vector3
		var mk: String = str(b["mat"])
		_add_box(g, "SouthTenement_%d" % i, sz, ps, mk, Vector3.ZERO, false)
		_add_box(g, "SouthCornice_%d" % i, Vector3(sz.x + 0.5, 0.35, sz.z + 0.4), Vector3(ps.x, ps.y * 2.0, ps.z), "ruin_dark", Vector3.ZERO, false)
		# Janelas escuras na fachada virada para a rua (-Z)
		for wx_off: float in [-sz.x * 0.28, 0.0, sz.x * 0.28]:
			_add_box(g, "SouthWinHi", Vector3(1.5, 2.0, 0.14), Vector3(ps.x + wx_off, 7.6, ps.z - sz.z * 0.5 - 0.02), "win_dark", Vector3.ZERO, false, 78.0)

	# 2. Andar superior em ruína sobre o Mini-Mercado (cria cânion no beco igual ao esboço)
	_add_box(g, "MarketUpperTenement", Vector3(8.0, 4.4, 14.4), Vector3(-21.5, 6.8, -0.25), "ruin_brick", Vector3.ZERO, false)
	_add_box(g, "MarketUpperCornice", Vector3(8.5, 0.35, 14.9), Vector3(-21.5, 9.1, -0.25), "ruin_dark", Vector3.ZERO, false)
	for wz: float in [-4.5, 0.0, 4.2]:
		_add_box(g, "MarketUpperWinE", Vector3(0.12, 1.7, 1.3), Vector3(-17.46, 6.6, wz), "win_dark", Vector3.ZERO, false, 68.0)

	# 3. Ruínas laterais na Avenida da Escola (fora das rotas de patrulha X = ±10)
	_add_box(g, "SchoolAvenueRuinW", Vector3(7.5, 8.4, 12.0), Vector3(-20.0, 4.2, -33.0), "ruin_brick", Vector3.ZERO, true)
	_add_box(g, "SchoolAvenueRuinE", Vector3(7.5, 9.0, 12.0), Vector3(19.0, 4.5, -33.0), "ruin_concrete", Vector3.ZERO, true)
	for wy: float in [2.6, 5.8]:
		_add_box(g, "RuinWinW", Vector3(0.14, 1.5, 1.8), Vector3(-16.22, wy, -33.0), "win_dark", Vector3.ZERO, false, 64.0)
		_add_box(g, "RuinWinE", Vector3(0.14, 1.5, 1.8), Vector3(15.22, wy, -33.0), "win_dark", Vector3.ZERO, false, 64.0)


func _build_graffiti_murals() -> void:
	var m: Node3D = Node3D.new()
	m.name = "GraffitiMurals"
	add_child(m)

	# Murais grafiteados encostados nas fachadas dos becos e muros perimetrais
	var panels: Array[Dictionary] = [
		# Beco Oeste do Mini-Mercado (visível logo ao sair na rua ou andar pelo beco)
		{"pos": Vector3(-17.34, 1.75, 2.2), "size": Vector3(0.04, 3.0, 5.2), "mat": "graffiti_a"},
		{"pos": Vector3(-17.34, 1.65, -1.6), "size": Vector3(0.04, 2.6, 3.2), "mat": "graffiti_b"},
		# Parede Oeste da Casa Principal no beco
		{"pos": Vector3(-8.15, 1.65, -2.2), "size": Vector3(0.04, 2.8, 4.8), "mat": "graffiti_b"},
		# Beco Leste da Casa Vizinha & Pracinha
		{"pos": Vector3(17.45, 1.65, 1.5), "size": Vector3(0.04, 2.8, 4.8), "mat": "graffiti_a"},
		{"pos": Vector3(8.15, 1.65, 2.2), "size": Vector3(0.04, 2.8, 4.2), "mat": "graffiti_b"},
		# Muros ao redor do Portão da Escola e Posto
		{"pos": Vector3(-7.5, 1.35, -19.76), "size": Vector3(5.6, 2.4, 0.04), "mat": "graffiti_a"},
		{"pos": Vector3(9.5, 1.35, -19.76), "size": Vector3(5.6, 2.4, 0.04), "mat": "graffiti_b"},
		{"pos": Vector3(-46.0, 1.45, 0.2), "size": Vector3(0.04, 2.5, 3.8), "mat": "graffiti_a"},
	]
	for idx: int in range(panels.size()):
		var d: Dictionary = panels[idx]
		_add_box(m, "Mural_%d" % idx, d["size"] as Vector3, d["pos"] as Vector3, str(d["mat"]), Vector3.ZERO, false, 58.0)


func _build_alley_and_curb_clutter() -> void:
	var c: Node3D = Node3D.new()
	c.name = "AlleyAndCurbClutter"
	add_child(c)

	# Caixotes, chapas corrugadas inclinadas, caçambas e sacos de lixo nas bordas de becos/meio-fios
	_add_box(c, "AlleyLeanSheet", Vector3(0.08, 2.1, 1.8), Vector3(-16.95, 1.0, 1.6), "rust_sheet", Vector3(0.0, 6.0, -14.0), true, 48.0)
	_add_box(c, "AlleyCrateLow", Vector3(0.95, 0.72, 0.95), Vector3(-16.6, 0.36, 3.5), "crate_wood", Vector3(0.0, 14.0, 0.0), true, 48.0)
	_add_box(c, "AlleyTrashA", Vector3(0.65, 0.55, 0.65), Vector3(-15.9, 0.28, 5.8), "trash_bag", Vector3(0.0, 22.0, 0.0), false, 42.0)
	_add_box(c, "AlleyTrashB", Vector3(0.55, 0.48, 0.58), Vector3(-16.3, 0.24, 6.4), "trash_bag", Vector3(0.0, -18.0, 0.0), false, 42.0)

	# Lado Leste perto da casa vizinha (encostado na parede Oeste em X=17.4)
	_add_box(c, "EastAlleyDumpster", Vector3(1.1, 1.15, 2.0), Vector3(16.7, 0.58, -1.8), "dumpster", Vector3(0.0, 4.0, 0.0), true, 52.0)
	_add_box(c, "EastAlleyCrate", Vector3(0.9, 0.85, 0.9), Vector3(8.7, 0.43, 4.8), "crate_wood", Vector3(0.0, -12.0, 0.0), true, 48.0)

	# Calçada Sul e Posto / Capela (fora da faixa central do asfalto)
	_add_box(c, "SouthCurbDumpster", Vector3(2.2, 1.2, 1.1), Vector3(-19.5, 0.6, 15.8), "dumpster", Vector3(0.0, -6.0, 0.0), true, 54.0)
	_add_box(c, "SouthCurbBarrier", Vector3(2.1, 0.78, 0.45), Vector3(10.5, 0.39, 15.8), "barrier", Vector3(0.0, 8.0, 0.0), true, 52.0)
	_add_box(c, "GasCurbCrates", Vector3(1.1, 0.9, 1.1), Vector3(-31.2, 0.45, 8.8), "crate_wood", Vector3(0.0, 18.0, 0.0), true, 50.0)
	_add_box(c, "GasCurbSheet", Vector3(1.8, 1.4, 0.08), Vector3(-32.4, 0.7, 8.6), "rust_sheet", Vector3(16.0, 10.0, 0.0), true, 48.0)
	_add_box(c, "ChapelGateBarricade", Vector3(2.0, 0.75, 0.42), Vector3(38.2, 0.38, 15.8), "barrier", Vector3(0.0, -9.0, 0.0), true, 52.0)


func _build_ground_litter_and_puddles() -> void:
	var lit: Node3D = Node3D.new()
	lit.name = "GroundLitter"
	add_child(lit)

	var spots: Array[Vector2] = [
		# Beco do Mini-Mercado
		Vector2(-15.4, 4.2), Vector2(-14.6, 1.8), Vector2(-13.8, -0.8), Vector2(-12.8, 2.5),
		Vector2(-15.8, -3.0), Vector2(-10.4, 0.4), Vector2(-9.6, 3.6), Vector2(-12.2, 6.2),
		# Rua Principal e calçadas
		Vector2(-18.5, 11.4), Vector2(-11.0, 14.2), Vector2(-3.2, 11.8), Vector2(3.8, 14.0),
		Vector2(8.5, 11.2), Vector2(15.2, 13.8), Vector2(19.5, 11.4), Vector2(28.0, 14.2),
		# Avenida Oeste (Posto) e Avenida Norte (Escola)
		Vector2(-30.5, 12.0), Vector2(-36.5, 14.2), Vector2(-42.0, 11.5), Vector2(-49.0, 13.6),
		Vector2(-1.4, -22.5), Vector2(1.6, -26.0), Vector2(-1.0, -32.5), Vector2(1.5, -39.0),
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

	# Poste extra na entrada do Posto (X=-31.0, Z=9.8)
	_add_box(pwr, "GasApproachPole", Vector3(0.16, 4.6, 0.16), Vector3(-31.0, 2.3, 9.8), "ruin_dark")
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
