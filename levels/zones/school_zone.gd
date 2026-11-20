@tool
extends Node3D
## Zona Norte: Avenida da Escola urbanizada, Pátio Escolar detalhado e Escola Municipal "Aurora Solar"
## de 2 andares com pórtico clássico, torre do relógio e 4 alas internas ricamente mobiliadas.

const LAYER_ENVIRONMENT: int = 1
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")
const _DoorScript := preload("res://systems/interactables/door_interactable.gd")
const _WardrobeScript := preload("res://systems/interactables/wardrobe_hide.gd")

var _materials: Dictionary = {}
var _textures: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _shape_cache: Dictionary = {}


func _ready() -> void:
	rebuild_zone()


func _exit_tree() -> void:
	_materials.clear()
	_textures.clear()
	_mesh_cache.clear()
	_shape_cache.clear()


func rebuild_zone() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()

	_mesh_cache.clear()
	_shape_cache.clear()
	_init_textures()
	_init_materials()
	_build_courtyard_ground_and_walkway()
	_build_school_building()
	_build_sewer_north_hut_and_walls()


func _init_textures() -> void:
	_textures.clear()
	_textures["stucco"] = _make_stucco_texture()
	_textures["wainscot"] = _make_wainscot_texture()
	_textures["checker_tile"] = _make_checker_tile_texture()
	_textures["city_brick"] = _make_city_brick_texture()
	_textures["window_grid"] = _make_window_grid_texture()
	_textures["pavement"] = _make_pavement_texture()


func _init_materials() -> void:
	_materials.clear()
	_materials["pavement"] = _make_mat(Color(0.46, 0.44, 0.40), _textures["pavement"] as Texture2D, Vector2(8.0, 8.0))
	_materials["dirt"] = _make_mat(Color(0.28, 0.27, 0.26), _textures["pavement"] as Texture2D, Vector2(14.0, 14.0))
	_materials["school_wall"] = _make_mat(Color(0.66, 0.60, 0.49), _textures["stucco"] as Texture2D, Vector2(6.0, 2.0))
	_materials["school_upper"] = _make_mat(Color(0.56, 0.42, 0.34), _textures["city_brick"] as Texture2D, Vector2(8.0, 2.5))
	_materials["school_int"] = _make_mat(Color(0.72, 0.68, 0.58), _textures["wainscot"] as Texture2D, Vector2(4.0, 1.0))
	_materials["city_brick"] = _make_mat(Color(0.48, 0.31, 0.26), _textures["city_brick"] as Texture2D, Vector2(5.0, 4.0))
	_materials["city_brick_dark"] = _make_mat(Color(0.32, 0.22, 0.19), _textures["city_brick"] as Texture2D, Vector2(5.0, 4.0))
	_materials["school_trim"] = _make_mat(Color(0.24, 0.31, 0.27), _textures["stucco"] as Texture2D, Vector2(3.0, 1.0))
	_materials["school_floor"] = _make_mat(Color(0.58, 0.56, 0.50), _textures["checker_tile"] as Texture2D, Vector2(12.0, 8.0))
	_materials["roof"] = _make_mat(Color(0.20, 0.17, 0.16), _textures["pavement"] as Texture2D, Vector2(6.0, 6.0))
	_materials["concrete"] = _make_mat(Color(0.48, 0.46, 0.44), _textures["stucco"] as Texture2D, Vector2(3.0, 2.0))
	_materials["concrete_dark"] = _make_mat(Color(0.29, 0.28, 0.28), _textures["stucco"] as Texture2D, Vector2(3.0, 2.0))
	_materials["wood"] = _make_mat(Color(0.40, 0.27, 0.16))
	_materials["wood_dark"] = _make_mat(Color(0.26, 0.17, 0.10))
	_materials["board"] = _make_mat(Color(0.14, 0.24, 0.16))
	_materials["metal_dark"] = _make_mat(Color(0.20, 0.21, 0.24))
	_materials["window_glass"] = _make_mat(Color(0.75, 0.78, 0.82), _textures["window_grid"] as Texture2D, Vector2(1.0, 1.0))
	_materials["clock_face"] = _make_mat(Color(0.82, 0.76, 0.62))
	_materials["bed_sheet"] = _make_mat(Color(0.68, 0.66, 0.60))
	_materials["books_mix"] = _make_mat(Color(0.54, 0.24, 0.20))


func _make_mat(color: Color, tex: Texture2D = null, uv_scale: Vector2 = Vector2(2.0, 2.0)) -> Material:
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


func _make_stucco_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8101
	for y: int in range(64):
		var damp: float = 0.22 * clampf(float(y - 44) / 20.0, 0.0, 1.0)
		var top_stain: float = 0.14 * clampf(float(10 - y) / 10.0, 0.0, 1.0)
		for x: int in range(64):
			var v: float = clampf(0.90 - damp - top_stain + rng.randf_range(-0.07, 0.06), 0.42, 1.0)
			if (x * 5 + y * 3) % 53 == 0:
				v *= 0.72
			img.set_pixel(x, y, Color(v, v * 0.98, v * 0.93, 1.0))
	return ImageTexture.create_from_image(img)


func _make_wainscot_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8102
	for y: int in range(64):
		for x: int in range(64):
			var n: float = rng.randf_range(-0.05, 0.05)
			var col: Color
			if y >= 40:
				var tile_seam: bool = (x % 8 == 0) or (y % 8 == 0)
				var base_g: float = 0.34 if tile_seam else 0.48
				col = Color(base_g * 0.76 + n, base_g * 0.94 + n, base_g * 0.82 + n, 1.0)
			elif y >= 37 and y < 40:
				col = Color(0.28 + n, 0.20 + n, 0.14 + n, 1.0)
			else:
				var v: float = clampf(0.88 + n, 0.60, 1.0)
				col = Color(v, v * 0.97, v * 0.90, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _make_checker_tile_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8103
	for y: int in range(64):
		for x: int in range(64):
			var grout: bool = (x % 16 == 0) or (y % 16 == 0)
			var checker: bool = (((x / 16) + (y / 16)) % 2) == 0
			var v: float = 0.42 if grout else (0.90 if checker else 0.68)
			v = clampf(v + rng.randf_range(-0.05, 0.05), 0.30, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.98, v * 0.93, 1.0))
	return ImageTexture.create_from_image(img)


func _make_city_brick_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8104
	for y: int in range(64):
		var row: int = y / 8
		var shift: int = 8 if (row % 2 == 1) else 0
		var mh: bool = (y % 8 == 0)
		var soot: float = 0.64 + 0.36 * clampf(float(64 - y) / 24.0, 0.0, 1.0)
		for x: int in range(64):
			var mv: bool = ((x + shift) % 16 == 0)
			var v: float = 0.46 if (mh or mv) else clampf(0.88 + rng.randf_range(-0.10, 0.08), 0.48, 1.0)
			v *= soot
			img.set_pixel(x, y, Color(v, v * 0.92, v * 0.88, 1.0))
	return ImageTexture.create_from_image(img)


func _make_window_grid_texture() -> ImageTexture:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in range(32):
		for x: int in range(32):
			var frame: bool = x < 3 or x >= 29 or y < 3 or y >= 29 or (x >= 15 and x <= 16) or (y >= 15 and y <= 16)
			var col: Color = Color(0.28, 0.26, 0.22, 1.0) if frame else Color(0.08, 0.10, 0.13, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _make_pavement_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8105
	for y: int in range(64):
		for x: int in range(64):
			var seam: bool = (x % 32 == 0) or (y % 32 == 0)
			var v: float = 0.56 if seam else clampf(0.86 + rng.randf_range(-0.08, 0.08), 0.50, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.99, v * 0.96, 1.0))
	return ImageTexture.create_from_image(img)


func _get_box_mesh(size: Vector3) -> BoxMesh:
	if _mesh_cache.has(size):
		return _mesh_cache[size] as BoxMesh
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	m.subdivide_width = clampi(int(size.x / 3.0), 0, 8)
	m.subdivide_depth = clampi(int(size.z / 3.0), 0, 8)
	_mesh_cache[size] = m
	return m


func _get_box_shape(size: Vector3) -> BoxShape3D:
	if _shape_cache.has(size):
		return _shape_cache[size] as BoxShape3D
	var s: BoxShape3D = BoxShape3D.new()
	s.size = size
	_shape_cache[size] = s
	return s


func _add_box(p: Node3D, n: String, size: Vector3, pos: Vector3, mat_key: String, rot_deg: Vector3 = Vector3.ZERO, with_col: bool = true, prop_cull: bool = false) -> Node3D:
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
		if prop_cull:
			m.visibility_range_end = 58.0
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
	if prop_cull:
		m_only.visibility_range_end = 58.0
	m_only.material_override = _materials.get(mat_key, null) as Material
	p.add_child(m_only)
	return m_only


func _add_door(p: Node3D, d_name: String, pos: Vector3, w: float, along_x: bool) -> void:
	var door: Node3D = Node3D.new()
	door.name = d_name
	door.set_script(_DoorScript)
	door.position = pos
	p.add_child(door)

	var leaf: StaticBody3D = StaticBody3D.new()
	leaf.name = "DoorLeaf"
	leaf.collision_layer = (1 << 0) | (1 << 3)
	var leaf_sz: Vector3 = Vector3(w - 0.06, 2.34, 0.08) if along_x else Vector3(0.08, 2.34, w - 0.06)
	leaf.position = Vector3(w * 0.5, 1.18, 0.0) if along_x else Vector3(0.0, 1.18, w * 0.5)
	door.add_child(leaf)
	var lm: MeshInstance3D = MeshInstance3D.new()
	lm.mesh = _get_box_mesh(leaf_sz)
	lm.material_override = _materials["wood"] as Material
	leaf.add_child(lm)
	var lc: CollisionShape3D = CollisionShape3D.new()
	lc.shape = _get_box_shape(leaf_sz)
	leaf.add_child(lc)


func _build_courtyard_ground_and_walkway() -> void:
	var g: Node3D = Node3D.new()
	g.name = "SchoolCourtyard"
	add_child(g)

	# Chão do pátio recortado ao redor do poço norte do esgoto (X:-44.6..-38.4, Z:-47.5..-44.5)
	_add_box(g, "CourtSouthGround", Vector3(80.0, 0.1, 24.5), Vector3(-14.0, -0.05, -32.25), "dirt")
	_add_box(g, "CourtPitLeft", Vector3(9.4, 0.1, 3.0), Vector3(-49.3, -0.05, -46.0), "dirt")
	_add_box(g, "CourtPitRight", Vector3(64.4, 0.1, 3.0), Vector3(-6.2, -0.05, -46.0), "dirt")
	_add_box(g, "CourtNorthGround", Vector3(80.0, 0.1, 28.5), Vector3(-14.0, -0.05, -61.75), "dirt")

	# Calçadão central do portão (0, -20) até o Pórtico da Escola (0, -48) + passarela oeste até a saída do esgoto
	_add_box(g, "SchoolWalkway", Vector3(5.6, 0.04, 28.0), Vector3(0.0, 0.01, -34.0), "pavement", Vector3.ZERO, false)
	_add_box(g, "SchoolPlazaApron", Vector3(22.0, 0.04, 6.2), Vector3(0.0, 0.01, -45.0), "pavement", Vector3.ZERO, false)
	_add_box(g, "SewerConnectorPath", Vector3(26.0, 0.03, 3.2), Vector3(-22.0, 0.008, -45.5), "pavement", Vector3.ZERO, false)

	# Mastro em pedestal escalonado, mural externo de avisos e bancos do pátio
	_add_box(g, "FlagpolePlinth", Vector3(1.1, 0.36, 1.1), Vector3(-5.8, 0.18, -39.0), "concrete")
	_add_box(g, "Flagpole", Vector3(0.16, 6.6, 0.16), Vector3(-5.8, 3.3, -39.0), "metal_dark", Vector3.ZERO, false)
	_add_box(g, "CourtBenchW", Vector3(2.4, 0.48, 0.65), Vector3(-4.6, 0.24, -33.0), "wood", Vector3(0.0, 8.0, 0.0), true, true)
	_add_box(g, "CourtBenchE", Vector3(2.4, 0.48, 0.65), Vector3(4.8, 0.24, -37.0), "wood", Vector3(0.0, -10.0, 0.0), true, true)

	# Mural de avisos coberto no pátio leste (fora da rota de patrulha X=-10..+10)
	_add_box(g, "NoticeBoardPostL", Vector3(0.14, 2.2, 0.14), Vector3(6.2, 1.1, -44.2), "wood_dark", Vector3.ZERO, false, true)
	_add_box(g, "NoticeBoardPostR", Vector3(0.14, 2.2, 0.14), Vector3(8.2, 1.1, -44.2), "wood_dark", Vector3.ZERO, false, true)
	_add_box(g, "NoticeBoardPanel", Vector3(2.2, 1.1, 0.12), Vector3(7.2, 1.45, -44.2), "board", Vector3.ZERO, false, true)
	_add_box(g, "NoticeBoardRoof", Vector3(2.5, 0.14, 0.65), Vector3(7.2, 2.25, -44.2), "roof", Vector3.ZERO, false, true)

	# Postes ornamentais da Avenida da Escola (sem colisão para nunca prender o jogador ou o cultista)
	for pz: float in [-24.5, -34.5, -43.5]:
		for px: float in [-3.4, 3.4]:
			_add_box(g, "CourtLampPost", Vector3(0.16, 4.2, 0.16), Vector3(px, 2.1, pz), "metal_dark", Vector3.ZERO, false, true)
			_add_box(g, "CourtLampHead", Vector3(0.34, 0.24, 0.34), Vector3(px, 4.25, pz), "concrete_dark", Vector3.ZERO, false, true)


func _build_school_building() -> void:
	var sch: Node3D = Node3D.new()
	sch.name = "SchoolBuilding"
	add_child(sch)

	# 1. Estrutura Principal de 2 Andares (X:-24..+22, Z:-72..-48)
	_add_box(sch, "SchoolFloor", Vector3(46.0, 0.08, 24.0), Vector3(-1.0, 0.02, -60.0), "school_floor")
	_add_box(sch, "SchoolCeiling1F", Vector3(46.4, 0.30, 24.4), Vector3(-1.0, 4.10, -60.0), "concrete_dark")

	# Segundo Andar Arquitetônico (Y: 4.25..8.45) com cornija superior e telhado escalonado
	_add_box(sch, "SchoolSecondStoryMass", Vector3(45.8, 4.1, 23.8), Vector3(-1.0, 6.3, -60.0), "school_upper")
	_add_box(sch, "SchoolMidBeltCourse", Vector3(46.8, 0.35, 24.6), Vector3(-1.0, 4.25, -60.0), "concrete", Vector3.ZERO, false)
	_add_box(sch, "SchoolUpperCornice", Vector3(47.2, 0.45, 25.0), Vector3(-1.0, 8.45, -60.0), "concrete_dark", Vector3.ZERO, false)
	_add_box(sch, "SchoolRoofCrown", Vector3(44.0, 0.65, 22.0), Vector3(-1.0, 8.95, -60.0), "roof", Vector3.ZERO, false)

	# 2. Pórtico Monumental de Entrada e Torre do Relógio (X:-4.8..+4.8, Z:-48.1..-45.6)
	_add_box(sch, "PorticoStep", Vector3(10.4, 0.08, 2.8), Vector3(0.0, 0.02, -46.8), "concrete", Vector3.ZERO, false)
	for col_x: float in [-4.4, -1.9, 1.9, 4.4]:
		_add_box(sch, "PorticoColumnBase", Vector3(0.68, 0.45, 0.68), Vector3(col_x, 0.22, -45.9), "concrete_dark", Vector3.ZERO, false)
		_add_box(sch, "PorticoColumnShaft", Vector3(0.50, 3.8, 0.50), Vector3(col_x, 2.2, -45.9), "concrete", Vector3.ZERO, false)
	_add_box(sch, "PorticoCanopySlab", Vector3(10.6, 0.42, 2.8), Vector3(0.0, 4.25, -46.8), "concrete_dark")
	_add_box(sch, "PorticoBalustrade", Vector3(10.4, 0.85, 0.25), Vector3(0.0, 4.85, -45.55), "school_trim", Vector3.ZERO, false)
	_add_box(sch, "SchoolSignHeader", Vector3(10.0, 0.95, 0.28), Vector3(0.0, 4.75, -47.85), "school_trim", Vector3.ZERO, false)

	# Frontão / Torre do Relógio acima da entrada central (Y: 8.4..11.4)
	_add_box(sch, "ClockTowerBody", Vector3(7.6, 2.6, 3.6), Vector3(0.0, 9.7, -49.2), "school_upper", Vector3.ZERO, false)
	_add_box(sch, "ClockTowerCap", Vector3(8.2, 0.45, 4.2), Vector3(0.0, 11.15, -49.2), "concrete_dark", Vector3.ZERO, false)
	_add_box(sch, "ClockDial", Vector3(1.7, 1.7, 0.14), Vector3(0.0, 9.75, -47.34), "clock_face", Vector3.ZERO, false)
	_add_box(sch, "ClockHandH", Vector3(0.10, 0.58, 0.06), Vector3(0.14, 9.88, -47.25), "metal_dark", Vector3(0.0, 0.0, -48.0), false)
	_add_box(sch, "ClockHandM", Vector3(0.08, 0.78, 0.06), Vector3(-0.10, 9.95, -47.25), "metal_dark", Vector3(0.0, 0.0, 22.0), false)

	# 3. Paredes Externas do Térreo (Norte, Oeste, Leste e Fachada Sul com pilastras e janelas gradeadas)
	_add_box(sch, "SchoolWallN", Vector3(46.0, 4.0, 0.3), Vector3(-1.0, 2.0, -71.85), "school_wall")
	_add_box(sch, "SchoolWallW", Vector3(0.3, 4.0, 24.0), Vector3(-23.85, 2.0, -60.0), "school_wall")
	_add_box(sch, "SchoolWallE", Vector3(0.3, 4.0, 24.0), Vector3(21.85, 2.0, -60.0), "school_wall")

	# Parede Frontal Sul (Z = -48.15) com entrada dupla central (X:-1.2..+1.2)
	_add_box(sch, "SchoolFrontW", Vector3(22.8, 4.0, 0.3), Vector3(-12.6, 2.0, -48.15), "school_wall")
	_add_box(sch, "SchoolFrontE", Vector3(20.8, 4.0, 0.3), Vector3(11.6, 2.0, -48.15), "school_wall")
	_add_box(sch, "SchoolFrontTop", Vector3(2.4, 1.5, 0.3), Vector3(0.0, 3.25, -48.15), "school_trim")
	_add_door(sch, "SchoolMainDoor", Vector3(-1.2, 0.0, -48.15), 2.4, true)

	# Pilastras verticais e janelas do 1º e 2º andar na fachada frontal (Z = -47.98)
	var front_win_xs: Array[float] = [-20.5, -15.5, -10.5, -6.2, 6.2, 10.5, 15.0, 19.2]
	for idx: int in range(front_win_xs.size()):
		var wx: float = front_win_xs[idx]
		_add_box(sch, "FrontWin1F_%d" % idx, Vector3(2.1, 1.75, 0.10), Vector3(wx, 2.15, -47.96), "window_glass", Vector3.ZERO, false, true)
		_add_box(sch, "FrontSill1F_%d" % idx, Vector3(2.35, 0.16, 0.24), Vector3(wx, 1.20, -47.92), "concrete_dark", Vector3.ZERO, false, true)
		_add_box(sch, "FrontWin2F_%d" % idx, Vector3(2.0, 1.85, 0.12), Vector3(wx, 6.25, -48.04), "window_glass", Vector3.ZERO, false, true)
		_add_box(sch, "FrontSill2F_%d" % idx, Vector3(2.25, 0.16, 0.24), Vector3(wx, 5.25, -48.00), "concrete_dark", Vector3.ZERO, false, true)
		if idx % 2 == 0:
			_add_box(sch, "WindowPlank_%d" % idx, Vector3(2.3, 0.24, 0.08), Vector3(wx, 2.05, -47.88), "wood", Vector3(0.0, 0.0, 5.0 if idx < 4 else -6.0), false, true)

	for pil_x: float in [-23.6, -18.0, -13.0, -8.2, 8.2, 12.8, 17.2, 21.6]:
		_add_box(sch, "FacadePilaster", Vector3(0.45, 8.2, 0.22), Vector3(pil_x, 4.1, -48.0), "city_brick_dark", Vector3.ZERO, false, true)

	# 4. Divisórias Internas com Passagens Amplas (2.8m) para Zero Travamento
	# Paredes laterais do Foyer Central (X=-6.0 e X=+6.0) com aberturas de 2.8m em Z: -53.9..-51.1
	_add_box(sch, "HallDividerW_S", Vector3(0.25, 3.8, 2.9), Vector3(-6.0, 1.9, -49.65), "school_int")
	_add_box(sch, "HallDividerW_N", Vector3(0.25, 3.8, 2.0), Vector3(-6.0, 1.9, -54.9), "school_int")
	_add_box(sch, "HallDividerW_Arch", Vector3(0.25, 1.1, 2.8), Vector3(-6.0, 3.25, -52.5), "school_int")
	_add_box(sch, "HallDividerE_S", Vector3(0.25, 3.8, 2.9), Vector3(6.0, 1.9, -49.65), "school_int")
	_add_box(sch, "HallDividerE_N", Vector3(0.25, 3.8, 2.0), Vector3(6.0, 1.9, -54.9), "school_int")
	_add_box(sch, "HallDividerE_Arch", Vector3(0.25, 1.1, 2.8), Vector3(6.0, 3.25, -52.5), "school_int")

	# Parede longitudinal do corredor principal em Z = -59.0:
	# Abertura Oeste (Sala de Aula 01): X = -15.5..-12.6 (2.9m, alinhada com BlockedPassage_SchoolClass1 em X=-14)
	# Abertura Leste (Diretoria): X = +13.2..+14.8 (1.6m, alinhada com PrincipalDoor)
	_add_box(sch, "CorrWallN_1", Vector3(8.5, 3.8, 0.25), Vector3(-19.75, 1.9, -59.0), "school_int")
	_add_box(sch, "CorrWallN_2", Vector3(25.8, 3.8, 0.25), Vector3(0.3, 1.9, -59.0), "school_int")
	_add_box(sch, "CorrWallN_3", Vector3(7.2, 3.8, 0.25), Vector3(18.4, 1.9, -59.0), "school_int")
	_add_box(sch, "Class1DoorTop", Vector3(2.9, 1.0, 0.25), Vector3(-14.05, 3.3, -59.0), "school_int")
	_add_box(sch, "PrincipalDoorTop", Vector3(1.6, 1.4, 0.25), Vector3(14.0, 3.1, -59.0), "school_int")
	# Divisória entre Sala de Aula 01 e Diretoria em X = 0 (ala norte)
	_add_box(sch, "NorthWingCenterWall", Vector3(0.25, 3.8, 12.8), Vector3(0.0, 1.9, -65.4), "school_int")
	_add_door(sch, "PrincipalDoor", Vector3(13.2, 0.0, -59.0), 1.6, true)

	# 5. Mobiliário do Foyer Central e Corredor Principal (sem colisão nos itens de parede para passagem livre)
	_add_box(sch, "FoyerTrophyCase", Vector3(0.45, 2.2, 2.2), Vector3(5.6, 1.1, -49.6), "wood_dark", Vector3.ZERO, false, true)
	_add_box(sch, "FoyerTrophyGlass", Vector3(0.08, 1.4, 1.9), Vector3(5.35, 1.3, -49.6), "window_glass", Vector3.ZERO, false, true)
	_add_box(sch, "FoyerHonorBoard", Vector3(0.08, 1.4, 2.2), Vector3(-5.82, 1.7, -49.6), "board", Vector3.ZERO, false, true)
	_add_box(sch, "CorridorLockerBankW", Vector3(4.8, 2.0, 0.45), Vector3(-4.5, 1.0, -58.65), "metal_dark", Vector3.ZERO, false, true)
	_add_box(sch, "CorridorLockerBankE", Vector3(5.4, 2.0, 0.45), Vector3(6.5, 1.0, -58.65), "metal_dark", Vector3.ZERO, false, true)
	_add_box(sch, "CorridorBanner", Vector3(4.2, 0.65, 0.08), Vector3(0.0, 2.9, -58.82), "school_trim", Vector3.ZERO, false, true)

	# 6. Ala Oeste Sul: Biblioteca Escolar (X:-23.6..-6.4, Z:-58.6..-48.4)
	# Nota EchoNote_SchoolLibrary fica em (-14.5, 0.05, -52.5) — mantemos amplo corredor livre ao redor!
	_add_box(sch, "LibraryShelf1", Vector3(0.75, 2.5, 4.8), Vector3(-21.2, 1.25, -52.5), "wood_dark", Vector3.ZERO, true, true)
	_add_box(sch, "LibraryBooks1", Vector3(0.55, 1.9, 4.4), Vector3(-21.2, 1.30, -52.5), "books_mix", Vector3.ZERO, false, true)
	_add_box(sch, "LibraryShelf2", Vector3(0.75, 2.5, 4.8), Vector3(-17.6, 1.25, -52.5), "wood_dark", Vector3.ZERO, true, true)
	_add_box(sch, "LibraryBooks2", Vector3(0.55, 1.9, 4.4), Vector3(-17.6, 1.30, -52.5), "books_mix", Vector3.ZERO, false, true)
	_add_box(sch, "LibraryWallShelfS", Vector3(6.4, 2.4, 0.65), Vector3(-13.5, 1.2, -48.65), "wood_dark", Vector3.ZERO, false, true)
	_add_box(sch, "LibraryReadingTable", Vector3(2.2, 0.78, 1.2), Vector3(-11.5, 0.39, -51.5), "wood", Vector3.ZERO, true, true)
	_add_box(sch, "LibrarianCounter", Vector3(1.8, 0.92, 0.75), Vector3(-8.2, 0.46, -50.2), "wood_dark", Vector3.ZERO, false, true)

	# 7. Ala Oeste Norte: Sala de Aula 01 (X:-23.6..-0.3, Z:-71.6..-59.3)
	# Porta fica em X=-14.0, Z=-59.0 -> Corredor central de X=-16.0 a X=-11.6 totalmente livre de carteiras!
	_add_box(sch, "TeacherPlatform", Vector3(6.5, 0.16, 2.2), Vector3(-13.0, 0.08, -70.2), "wood_dark", Vector3.ZERO, false, true)
	_add_box(sch, "ChalkboardFrame", Vector3(5.6, 1.85, 0.10), Vector3(-13.0, 1.95, -71.62), "wood_dark", Vector3.ZERO, false, true)
	_add_box(sch, "Chalkboard", Vector3(5.2, 1.55, 0.14), Vector3(-13.0, 1.95, -71.56), "board", Vector3.ZERO, false, true)
	_add_box(sch, "TeacherDesk", Vector3(1.8, 0.78, 0.85), Vector3(-13.0, 0.48, -69.5), "wood_dark", Vector3.ZERO, true, true)
	_add_box(sch, "ClassroomCupboard", Vector3(0.65, 2.2, 2.4), Vector3(-23.2, 1.1, -65.0), "wood_dark", Vector3.ZERO, false, true)
	for dx: float in [-20.2, -17.4, -9.8, -6.8, -3.8]:
		for dz: float in [-67.2, -63.6]:
			_add_box(sch, "StudentDesk", Vector3(1.1, 0.72, 0.70), Vector3(dx, 0.36, dz), "wood", Vector3.ZERO, true, true)
			_add_box(sch, "StudentChair", Vector3(0.52, 0.44, 0.48), Vector3(dx, 0.22, dz + 0.55), "wood_dark", Vector3.ZERO, false, true)

	# 8. Ala Leste Norte: Diretoria & Secretaria (X:+0.3..+21.6, Z:-71.6..-59.3)
	# PrincipalDesk em (13.5, 0.42, -66.0) sob EchoNote_SchoolOffice (13.5, 0.88, -66.0)
	# CodeSafe_School fica em (17.5, 0.05, -70.6)
	_add_box(sch, "PrincipalDesk", Vector3(2.4, 0.85, 1.1), Vector3(13.5, 0.42, -66.0), "wood_dark", Vector3.ZERO, true, true)
	_add_box(sch, "PrincipalChair", Vector3(0.65, 0.95, 0.65), Vector3(13.5, 0.48, -67.2), "wood", Vector3.ZERO, false, true)
	_add_box(sch, "OfficeBookcaseW", Vector3(0.65, 2.4, 6.0), Vector3(1.0, 1.2, -65.5), "wood_dark", Vector3.ZERO, false, true)
	_add_box(sch, "OfficeFilingCab1", Vector3(0.75, 1.45, 0.65), Vector3(15.2, 0.72, -71.1), "metal_dark", Vector3.ZERO, false, true)
	_add_box(sch, "OfficeFilingCab2", Vector3(0.75, 1.45, 0.65), Vector3(19.6, 0.72, -71.1), "metal_dark", Vector3.ZERO, false, true)
	_add_box(sch, "OfficeBoard", Vector3(3.4, 1.3, 0.10), Vector3(11.0, 1.9, -71.60), "board", Vector3.ZERO, false, true)
	_add_box(sch, "SecretaryCounter", Vector3(3.8, 0.88, 0.75), Vector3(6.2, 0.44, -62.5), "wood", Vector3.ZERO, true, true)

	# 9. Ala Leste Sul: Enfermaria & Refeitório (X:+6.4..+21.6, Z:-58.6..-48.4)
	# SchoolLocker (esconderijo) fica em (19.8, 1.0, -52.0)
	_add_box(sch, "InfirmaryCotFrame", Vector3(1.1, 0.52, 2.2), Vector3(19.2, 0.26, -49.5), "metal_dark", Vector3.ZERO, false, true)
	_add_box(sch, "InfirmaryMattress", Vector3(1.0, 0.14, 2.05), Vector3(19.2, 0.56, -49.5), "bed_sheet", Vector3.ZERO, false, true)
	_add_box(sch, "InfirmaryScreen", Vector3(0.10, 1.75, 2.2), Vector3(17.2, 0.88, -50.2), "school_trim", Vector3.ZERO, false, true)
	_add_box(sch, "CafeteriaTable1", Vector3(3.2, 0.76, 1.0), Vector3(11.5, 0.38, -50.8), "wood", Vector3.ZERO, true, true)
	_add_box(sch, "CafeteriaBench1", Vector3(3.0, 0.42, 0.42), Vector3(11.5, 0.21, -49.9), "wood_dark", Vector3.ZERO, false, true)
	_add_box(sch, "CafeteriaTable2", Vector3(3.2, 0.76, 1.0), Vector3(11.5, 0.38, -54.2), "wood", Vector3.ZERO, false, true)

	var nurse_locker: StaticBody3D = StaticBody3D.new()
	nurse_locker.name = "SchoolLocker"
	nurse_locker.set_script(_WardrobeScript)
	nurse_locker.position = Vector3(19.8, 1.0, -52.0)
	nurse_locker.set("hide_offset", Vector3(0.0, -1.0, 0.0))
	nurse_locker.set("exit_offset", Vector3(-1.1, -1.0, 0.0))
	nurse_locker.collision_layer = (1 << 0) | (1 << 3)
	sch.add_child(nurse_locker)
	var nlm: MeshInstance3D = MeshInstance3D.new()
	nlm.mesh = _get_box_mesh(Vector3(0.75, 2.0, 1.2))
	nlm.material_override = _materials["metal_dark"] as Material
	nurse_locker.add_child(nlm)
	var nlc: CollisionShape3D = CollisionShape3D.new()
	nlc.shape = _get_box_shape(Vector3(0.75, 2.0, 1.2))
	nurse_locker.add_child(nlc)

	# Iluminação interna da Escola (Foyer, Corredor e Diretoria)
	var lobby_light: OmniLight3D = OmniLight3D.new()
	lobby_light.position = Vector3(0.0, 3.5, -52.5)
	lobby_light.light_color = Color(0.88, 0.78, 0.56)
	lobby_light.light_energy = 0.52
	lobby_light.omni_range = 10.5
	lobby_light.shadow_enabled = false
	lobby_light.distance_fade_enabled = true
	lobby_light.distance_fade_begin = 26.0
	sch.add_child(lobby_light)

	var office_light: OmniLight3D = OmniLight3D.new()
	office_light.position = Vector3(14.5, 3.3, -67.0)
	office_light.light_color = Color(0.95, 0.74, 0.42)
	office_light.light_energy = 0.42
	office_light.omni_range = 7.5
	office_light.shadow_enabled = false
	office_light.distance_fade_enabled = true
	office_light.distance_fade_begin = 22.0
	sch.add_child(office_light)


func _build_sewer_north_hut_and_walls() -> void:
	var n: Node3D = Node3D.new()
	n.name = "SchoolPerimeterAndSewerHut"
	add_child(n)

	# Guarita sobre a rampa norte do esgoto (X:-44.8..-35.5, Z:-48..-44) — aberta para Leste rumo à Escola
	_add_box(n, "NorthPitHutN", Vector3(9.4, 2.8, 0.25), Vector3(-40.1, 1.4, -47.8), "concrete_dark")
	_add_box(n, "NorthPitHutS", Vector3(9.4, 2.8, 0.25), Vector3(-40.1, 1.4, -44.2), "concrete_dark")
	_add_box(n, "NorthPitHutW", Vector3(0.25, 2.8, 3.8), Vector3(-44.8, 1.4, -46.0), "concrete_dark")
	_add_box(n, "NorthPitHutRoof", Vector3(9.8, 0.25, 4.2), Vector3(-40.1, 2.9, -46.0), "roof")

	# Quarteirão Urbano Norte ao redor da Escola (prédios de 3 e 4 andares com cornijas, janelas e becos)
	_add_box(n, "SchoolWestTenement_S", Vector3(4.2, 11.2, 26.0), Vector3(-55.5, 5.6, -33.5), "city_brick_dark")
	_add_box(n, "SchoolWestTenement_N", Vector3(4.2, 12.0, 26.0), Vector3(-55.5, 6.0, -62.5), "city_brick")
	_add_box(n, "SchoolEastTenement_S", Vector3(4.2, 10.8, 26.0), Vector3(27.5, 5.4, -33.5), "city_brick")
	_add_box(n, "SchoolEastTenement_N", Vector3(4.2, 11.8, 26.0), Vector3(27.5, 5.9, -62.5), "city_brick_dark")
	_add_box(n, "SchoolNorthBlock_W", Vector3(38.0, 12.4, 4.5), Vector3(-34.0, 6.2, -77.5), "city_brick_dark")
	_add_box(n, "SchoolNorthBlock_E", Vector3(38.0, 11.6, 4.5), Vector3(8.0, 5.8, -77.5), "city_brick")
	_add_box(n, "SchoolNorthAlleyGate", Vector3(6.0, 4.2, 0.8), Vector3(-13.0, 2.1, -76.0), "concrete_dark")
	_add_box(n, "SchoolSouthWestRow", Vector3(28.0, 10.2, 3.4), Vector3(-40.0, 5.1, -20.8), "city_brick_dark")

	# Prédios Urbanos ladeando a Avenida da Escola (mantêm o pátio X:-14..+14 e a passarela do esgoto Z:-47.5..-41.5 100% livres!)
	_add_box(n, "AvenueFlankBldg_W", Vector3(9.2, 10.4, 17.5), Vector3(-19.2, 5.2, -31.0), "city_brick")
	_add_box(n, "AvenueFlankBldg_W_Cornice", Vector3(9.6, 0.4, 17.9), Vector3(-19.2, 10.4, -31.0), "concrete_dark", Vector3.ZERO, false)
	_add_box(n, "AvenueWestAnnex", Vector3(9.5, 9.2, 15.0), Vector3(-32.5, 4.6, -31.5), "city_brick_dark")
	_add_box(n, "AvenueWestOverpass", Vector3(4.0, 4.8, 3.4), Vector3(-25.8, 6.8, -31.0), "city_brick", Vector3.ZERO, false)
	_add_box(n, "AvenueFlankBldg_E", Vector3(9.4, 11.0, 18.0), Vector3(19.3, 5.5, -31.2), "city_brick_dark")
	_add_box(n, "AvenueFlankBldg_E_Cornice", Vector3(9.8, 0.4, 18.4), Vector3(19.3, 11.0, -31.2), "concrete_dark", Vector3.ZERO, false)
	_add_box(n, "AvenueEastRoofTower", Vector3(2.6, 2.8, 2.6), Vector3(19.3, 12.4, -31.2), "concrete_dark", Vector3.ZERO, false)
