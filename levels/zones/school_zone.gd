@tool
extends Node3D
## Zona Norte: Avenida Norte, Pátio Escolar e Escola Municipal "Aurora Solar" 100% explorável.

const LAYER_ENVIRONMENT: int = 1
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")
const _DoorScript := preload("res://systems/interactables/door_interactable.gd")
const _WardrobeScript := preload("res://systems/interactables/wardrobe_hide.gd")

var _materials: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _shape_cache: Dictionary = {}


func _ready() -> void:
	rebuild_zone()


func rebuild_zone() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()

	_mesh_cache.clear()
	_shape_cache.clear()
	_init_materials()
	_build_courtyard_ground_and_walkway()
	_build_school_building()
	_build_sewer_north_hut_and_walls()


func _init_materials() -> void:
	_materials.clear()
	_materials["pavement"] = _make_mat(Color(0.46, 0.44, 0.41))
	_materials["dirt"] = _make_mat(Color(0.28, 0.27, 0.26))
	_materials["school_wall"] = _make_mat(Color(0.64, 0.58, 0.48))
	_materials["city_brick"] = _make_mat(Color(0.48, 0.31, 0.26))
	_materials["city_brick_dark"] = _make_mat(Color(0.32, 0.22, 0.19))
	_materials["school_trim"] = _make_mat(Color(0.28, 0.34, 0.30))
	_materials["school_floor"] = _make_mat(Color(0.56, 0.54, 0.48))
	_materials["roof"] = _make_mat(Color(0.20, 0.17, 0.16))
	_materials["concrete"] = _make_mat(Color(0.48, 0.46, 0.44))
	_materials["concrete_dark"] = _make_mat(Color(0.29, 0.28, 0.28))
	_materials["wood"] = _make_mat(Color(0.40, 0.27, 0.16))
	_materials["board"] = _make_mat(Color(0.14, 0.24, 0.16))
	_materials["metal_dark"] = _make_mat(Color(0.20, 0.21, 0.24))


func _make_mat(color: Color) -> Material:
	if PSX_LIT_SHADER != null:
		var smat: ShaderMaterial = ShaderMaterial.new()
		smat.shader = PSX_LIT_SHADER
		smat.set_shader_parameter("modulate_color", color)
		smat.set_shader_parameter("snap_resolution", Vector2(320.0, 180.0))
		return smat
	var std: StandardMaterial3D = StandardMaterial3D.new()
	std.albedo_color = color
	return std


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
			m.visibility_range_end = 56.0
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
		m_only.visibility_range_end = 56.0
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

	# Calçadão central do portão (0, -20) até a porta da escola (0, -48)
	_add_box(g, "SchoolWalkway", Vector3(5.2, 0.04, 28.0), Vector3(0.0, 0.01, -34.0), "pavement")
	_add_box(g, "SchoolPlazaApron", Vector3(16.0, 0.04, 5.5), Vector3(0.0, 0.01, -45.2), "pavement")

	# Mastro e bancos quebrados no pátio
	_add_box(g, "Flagpole", Vector3(0.16, 6.2, 0.16), Vector3(-5.8, 3.1, -39.0), "metal_dark")
	_add_box(g, "CourtBenchW", Vector3(2.4, 0.48, 0.65), Vector3(-4.2, 0.24, -33.0), "wood", Vector3(0.0, 12.0, 0.0), true, true)
	_add_box(g, "CourtBenchE", Vector3(2.4, 0.48, 0.65), Vector3(4.5, 0.24, -37.0), "wood", Vector3(0.0, -16.0, 0.0), true, true)


func _build_school_building() -> void:
	var sch: Node3D = Node3D.new()
	sch.name = "SchoolBuilding"
	add_child(sch)

	# Prédio (X:-24..+22, Z:-72..-48)
	_add_box(sch, "SchoolFloor", Vector3(46.0, 0.08, 24.0), Vector3(-1.0, 0.02, -60.0), "school_floor")
	_add_box(sch, "SchoolRoof", Vector3(46.8, 0.35, 24.8), Vector3(-1.0, 4.15, -60.0), "roof")
	_add_box(sch, "SchoolSignHeader", Vector3(11.0, 1.1, 0.35), Vector3(0.0, 4.85, -47.9), "school_trim")

	# Paredes Externas: Norte, Oeste e Leste
	_add_box(sch, "SchoolWallN", Vector3(46.0, 4.0, 0.3), Vector3(-1.0, 2.0, -71.85), "school_wall")
	_add_box(sch, "SchoolWallW", Vector3(0.3, 4.0, 24.0), Vector3(-23.85, 2.0, -60.0), "school_wall")
	_add_box(sch, "SchoolWallE", Vector3(0.3, 4.0, 24.0), Vector3(21.85, 2.0, -60.0), "school_wall")

	# Parede Frontal Sul (Z = -48.15) com entrada central (X:-1.2..+1.2)
	_add_box(sch, "SchoolFrontW", Vector3(22.8, 4.0, 0.3), Vector3(-12.6, 2.0, -48.15), "school_wall")
	_add_box(sch, "SchoolFrontE", Vector3(20.8, 4.0, 0.3), Vector3(11.6, 2.0, -48.15), "school_wall")
	_add_box(sch, "SchoolFrontTop", Vector3(2.4, 1.5, 0.3), Vector3(0.0, 3.25, -48.15), "school_trim")
	_add_door(sch, "SchoolMainDoor", Vector3(-1.2, 0.0, -48.15), 2.4, true)

	# Corredor interno dividindo ala Sul (Z:-56..-48) da ala Norte (Z:-72..-59)
	# Paredes laterais do hall (X=-6 e X=+6) com aberturas em Z = -52
	_add_box(sch, "HallDividerW_S", Vector3(0.25, 3.8, 3.2), Vector3(-6.0, 1.9, -49.7), "school_wall")
	_add_box(sch, "HallDividerW_N", Vector3(0.25, 3.8, 3.2), Vector3(-6.0, 1.9, -54.5), "school_wall")
	_add_box(sch, "HallDividerE_S", Vector3(0.25, 3.8, 3.2), Vector3(6.0, 1.9, -49.7), "school_wall")
	_add_box(sch, "HallDividerE_N", Vector3(0.25, 3.8, 3.2), Vector3(6.0, 1.9, -54.5), "school_wall")

	# Parede longitudinal do corredor em Z = -59 com aberturas: Oeste X=-14, Diretoria X=+14 (largura 1.6m)
	_add_box(sch, "CorrWallN_1", Vector3(8.5, 3.8, 0.25), Vector3(-19.75, 1.9, -59.0), "school_wall")
	_add_box(sch, "CorrWallN_2", Vector3(25.8, 3.8, 0.25), Vector3(0.3, 1.9, -59.0), "school_wall")
	_add_box(sch, "CorrWallN_3", Vector3(7.2, 3.8, 0.25), Vector3(18.4, 1.9, -59.0), "school_wall")
	_add_box(sch, "PrincipalDoorTop", Vector3(1.6, 1.4, 0.25), Vector3(14.0, 3.1, -59.0), "school_wall")
	# Divisória entre Sala de Aula Oeste e Diretoria Leste em X = 0 (ala norte)
	_add_box(sch, "NorthWingCenterWall", Vector3(0.25, 3.8, 12.8), Vector3(0.0, 1.9, -65.4), "school_wall")
	_add_door(sch, "PrincipalDoor", Vector3(13.2, 0.0, -59.0), 1.6, true)

	# Mobília: Sala de Aula (Oeste Norte) e Diretoria (Leste Norte)
	_add_box(sch, "Chalkboard", Vector3(4.8, 1.6, 0.12), Vector3(-13.0, 1.9, -71.55), "board", Vector3.ZERO, true, true)
	for dx: float in [-16.0, -12.0, -8.0]:
		for dz: float in [-67.5, -63.5]:
			_add_box(sch, "Desk", Vector3(1.1, 0.72, 0.7), Vector3(dx, 0.36, dz), "wood", Vector3.ZERO, true, true)

	# Estantes da Biblioteca (Oeste Sul) e mesa da Diretoria
	_add_box(sch, "LibraryShelf1", Vector3(0.7, 2.2, 4.6), Vector3(-18.5, 1.1, -52.5), "wood", Vector3.ZERO, true, true)
	_add_box(sch, "LibraryShelf2", Vector3(0.7, 2.2, 4.6), Vector3(-12.5, 1.1, -52.5), "wood", Vector3.ZERO, true, true)
	_add_box(sch, "PrincipalDesk", Vector3(2.4, 0.85, 1.1), Vector3(13.5, 0.42, -66.0), "wood", Vector3.ZERO, true, true)

	# Armário na Enfermaria / Ala Leste Sul para o jogador se esconder
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

	var lobby_light: OmniLight3D = OmniLight3D.new()
	lobby_light.position = Vector3(0.0, 3.4, -52.5)
	lobby_light.light_color = Color(0.84, 0.80, 0.65)
	lobby_light.light_energy = 0.45
	lobby_light.omni_range = 9.0
	lobby_light.shadow_enabled = false
	lobby_light.distance_fade_enabled = true
	lobby_light.distance_fade_begin = 24.0
	sch.add_child(lobby_light)


func _build_sewer_north_hut_and_walls() -> void:
	var n: Node3D = Node3D.new()
	n.name = "SchoolPerimeterAndSewerHut"
	add_child(n)

	# Guarita sobre a rampa norte do esgoto (X:-44.8..-35.5, Z:-48..-44)
	_add_box(n, "NorthPitHutN", Vector3(9.4, 2.6, 0.25), Vector3(-40.1, 1.3, -47.8), "concrete_dark")
	_add_box(n, "NorthPitHutS", Vector3(9.4, 2.6, 0.25), Vector3(-40.1, 1.3, -44.2), "concrete_dark")
	_add_box(n, "NorthPitHutW", Vector3(0.25, 2.6, 3.8), Vector3(-44.8, 1.3, -46.0), "concrete_dark")
	_add_box(n, "NorthPitHutRoof", Vector3(9.6, 0.22, 4.0), Vector3(-40.1, 2.7, -46.0), "roof")

	# Quarteirão Urbano Norte ao redor da Escola (substitui muros lisos por prédios de 3-4 andares e becos)
	_add_box(n, "SchoolWestTenement_S", Vector3(4.2, 10.8, 26.0), Vector3(-55.5, 5.4, -33.5), "city_brick_dark")
	_add_box(n, "SchoolWestTenement_N", Vector3(4.2, 11.6, 26.0), Vector3(-55.5, 5.8, -62.5), "city_brick")
	_add_box(n, "SchoolEastTenement_S", Vector3(4.2, 10.4, 26.0), Vector3(27.5, 5.2, -33.5), "city_brick")
	_add_box(n, "SchoolEastTenement_N", Vector3(4.2, 11.4, 26.0), Vector3(27.5, 5.7, -62.5), "city_brick_dark")
	_add_box(n, "SchoolNorthBlock_W", Vector3(38.0, 12.0, 4.5), Vector3(-34.0, 6.0, -77.5), "city_brick_dark")
	_add_box(n, "SchoolNorthBlock_E", Vector3(38.0, 11.2, 4.5), Vector3(8.0, 5.6, -77.5), "city_brick")
	_add_box(n, "SchoolNorthAlleyGate", Vector3(6.0, 3.6, 0.8), Vector3(-13.0, 1.8, -76.0), "concrete_dark")
	_add_box(n, "SchoolSouthWestRow", Vector3(28.0, 9.8, 3.4), Vector3(-40.0, 4.9, -20.5), "city_brick_dark")
	# Sobrados ladeando a Avenida da Escola (formam corredor urbano e becos laterais sem obstruir patrulha X:-10..+10)
	_add_box(n, "AvenueFlankBldg_W", Vector3(8.5, 9.6, 15.0), Vector3(-18.5, 4.8, -30.0), "city_brick")
	_add_box(n, "AvenueFlankBldg_E", Vector3(9.0, 10.2, 17.0), Vector3(19.0, 5.1, -31.0), "city_brick_dark")
