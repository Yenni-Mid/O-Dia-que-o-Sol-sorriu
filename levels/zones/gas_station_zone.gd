@tool
extends Node3D
## Zona Oeste: Posto de Gasolina "Sol & Óleo", Loja de Conveniência explorável e acesso ao esgoto.

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
	_build_west_street()
	_build_gas_station_pad_and_canopy()
	_build_convenience_store()
	_build_sewer_shed_and_perimeter()


func _init_materials() -> void:
	_materials.clear()
	_materials["asphalt"] = _make_mat(Color(0.22, 0.22, 0.24))
	_materials["stripe"] = _make_mat(Color(0.76, 0.62, 0.22))
	_materials["sidewalk"] = _make_mat(Color(0.54, 0.52, 0.48))
	_materials["concrete"] = _make_mat(Color(0.48, 0.46, 0.43))
	_materials["concrete_dark"] = _make_mat(Color(0.30, 0.29, 0.29))
	_materials["dirt"] = _make_mat(Color(0.35, 0.31, 0.23))
	_materials["brick"] = _make_mat(Color(0.56, 0.43, 0.36))
	_materials["metal_red"] = _make_mat(Color(0.62, 0.20, 0.16))
	_materials["metal_dark"] = _make_mat(Color(0.18, 0.19, 0.22))
	_materials["roof"] = _make_mat(Color(0.20, 0.18, 0.18))
	_materials["wood"] = _make_mat(Color(0.38, 0.26, 0.16))
	_materials["tile"] = _make_mat(Color(0.66, 0.64, 0.58))
	_materials["rust"] = _make_mat(Color(0.45, 0.24, 0.17))


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


func _build_west_street() -> void:
	var street: Node3D = Node3D.new()
	street.name = "WestStreet"
	add_child(street)
	# Avenida Oeste continuando de X=-26 até X=-66
	_add_box(street, "WestRoadAsphalt", Vector3(40.0, 0.1, 4.6), Vector3(-46.0, -0.05, 12.9), "asphalt")
	for i: int in range(6):
		_add_box(street, "WestStripe_%d" % i, Vector3(2.8, 0.02, 0.16), Vector3(-29.5 - float(i) * 5.8, 0.005, 12.9), "stripe", Vector3.ZERO, false, true)
	_add_box(street, "WestSidewalkN", Vector3(40.0, 0.12, 1.0), Vector3(-46.0, -0.04, 10.1), "sidewalk")
	_add_box(street, "WestSidewalkS", Vector3(40.0, 0.12, 1.0), Vector3(-46.0, -0.04, 15.7), "sidewalk")
	_add_box(street, "WestSouthLot", Vector3(40.0, 0.1, 8.0), Vector3(-46.0, -0.05, 20.2), "dirt")


func _build_gas_station_pad_and_canopy() -> void:
	var gs: Node3D = Node3D.new()
	gs.name = "GasStationForecourt"
	add_child(gs)

	# Pátio recortado para manter aberto o fosso do esgoto (X:-44.6..-38.4, Z:-15.5..-12.5)
	_add_box(gs, "PadNorth", Vector3(40.0, 0.1, 4.5), Vector3(-46.0, -0.05, -17.75), "dirt")
	_add_box(gs, "PadPitWest", Vector3(21.4, 0.1, 3.0), Vector3(-55.3, -0.05, -14.0), "dirt")
	_add_box(gs, "PadPitEast", Vector3(12.4, 0.1, 3.0), Vector3(-32.2, -0.05, -14.0), "dirt")
	_add_box(gs, "PadBackConcrete", Vector3(40.0, 0.1, 4.5), Vector3(-46.0, -0.05, -10.25), "concrete")
	_add_box(gs, "ForecourtSlab", Vector3(40.0, 0.1, 17.6), Vector3(-46.0, -0.05, 0.8), "concrete")

	# Marquise e bombas de combustível (X:-41..-33, Z:1..7)
	_add_box(gs, "CanopyRoof", Vector3(11.0, 0.45, 7.6), Vector3(-36.5, 4.3, 4.0), "metal_red")
	_add_box(gs, "CanopyTrim", Vector3(11.2, 0.25, 7.8), Vector3(-36.5, 4.6, 4.0), "concrete")
	for px: float in [-40.6, -32.4]:
		for pz: float in [1.2, 6.8]:
			_add_box(gs, "CanopyPillar", Vector3(0.32, 4.2, 0.32), Vector3(px, 2.1, pz), "concrete")

	for bx: float in [-38.2, -34.8]:
		_add_box(gs, "PumpIsland", Vector3(1.3, 0.24, 3.4), Vector3(bx, 0.12, 4.0), "concrete_dark")
		_add_box(gs, "FuelPump", Vector3(0.65, 1.55, 0.65), Vector3(bx, 1.0, 4.0), "metal_red", Vector3.ZERO, true, true)

	var sodium: OmniLight3D = OmniLight3D.new()
	sodium.position = Vector3(-36.5, 3.8, 4.0)
	sodium.light_color = Color(1.0, 0.78, 0.42)
	sodium.light_energy = 1.4
	sodium.omni_range = 12.0
	sodium.shadow_enabled = false
	sodium.distance_fade_enabled = true
	sodium.distance_fade_begin = 26.0
	sodium.distance_fade_length = 8.0
	gs.add_child(sodium)


func _build_convenience_store() -> void:
	var st: Node3D = Node3D.new()
	st.name = "ConvenienceStore"
	add_child(st)

	# Prédio do Posto (X:-57..-46, Z:-6..+4)
	_add_box(st, "StoreFloor", Vector3(11.0, 0.1, 10.0), Vector3(-51.5, -0.02, -1.0), "tile")
	_add_box(st, "StoreRoof", Vector3(11.4, 0.35, 10.4), Vector3(-51.5, 3.85, -1.0), "roof")
	_add_box(st, "StoreWallW", Vector3(0.28, 3.8, 10.0), Vector3(-56.86, 1.9, -1.0), "brick")
	_add_box(st, "StoreWallN", Vector3(11.0, 3.8, 0.28), Vector3(-51.5, 1.9, -5.86), "brick")
	_add_box(st, "StoreWallS", Vector3(11.0, 3.8, 0.28), Vector3(-51.5, 1.9, 3.86), "brick")

	# Parede Leste com porta dupla em Z = -1.0 (vão 1.6m: Z = -1.8..-0.2)
	_add_box(st, "StoreWallE_N", Vector3(0.28, 3.8, 4.2), Vector3(-46.14, 1.9, -3.9), "brick")
	_add_box(st, "StoreWallE_S", Vector3(0.28, 3.8, 4.2), Vector3(-46.14, 1.9, 1.9), "brick")
	_add_box(st, "StoreWallE_Top", Vector3(0.28, 1.4, 1.6), Vector3(-46.14, 3.1, -1.0), "brick")

	var door: Node3D = Node3D.new()
	door.name = "GasStoreDoor"
	door.set_script(_DoorScript)
	door.position = Vector3(-46.14, 0.0, -1.8)
	st.add_child(door)
	var leaf: StaticBody3D = StaticBody3D.new()
	leaf.name = "DoorLeaf"
	leaf.collision_layer = (1 << 0) | (1 << 3)
	leaf.position = Vector3(0.0, 1.18, 0.8)
	door.add_child(leaf)
	var lm: MeshInstance3D = MeshInstance3D.new()
	lm.mesh = _get_box_mesh(Vector3(0.08, 2.34, 1.54))
	lm.material_override = _materials["wood"] as Material
	leaf.add_child(lm)
	var lc: CollisionShape3D = CollisionShape3D.new()
	lc.shape = _get_box_shape(Vector3(0.08, 2.34, 1.54))
	leaf.add_child(lc)

	# Balcão, prateleiras e armário para esconderijo
	_add_box(st, "CashierCounter", Vector3(0.8, 0.95, 3.2), Vector3(-50.8, 0.48, -0.8), "wood", Vector3.ZERO, true, true)
	_add_box(st, "ShelfA", Vector3(3.2, 1.75, 0.6), Vector3(-50.5, 0.88, 2.3), "metal_dark", Vector3.ZERO, true, true)

	var lock: StaticBody3D = StaticBody3D.new()
	lock.name = "GasLocker"
	lock.set_script(_WardrobeScript)
	lock.position = Vector3(-55.6, 1.0, -4.7)
	lock.set("hide_offset", Vector3(0.0, -1.0, 0.0))
	lock.set("exit_offset", Vector3(1.1, -1.0, 0.0))
	lock.collision_layer = (1 << 0) | (1 << 3)
	st.add_child(lock)
	var lkm: MeshInstance3D = MeshInstance3D.new()
	lkm.mesh = _get_box_mesh(Vector3(0.75, 2.0, 1.2))
	lkm.material_override = _materials["metal_dark"] as Material
	lock.add_child(lkm)
	var lkc: CollisionShape3D = CollisionShape3D.new()
	lkc.shape = _get_box_shape(Vector3(0.75, 2.0, 1.2))
	lock.add_child(lkc)

	var st_light: OmniLight3D = OmniLight3D.new()
	st_light.position = Vector3(-51.0, 3.2, -1.0)
	st_light.light_color = Color(0.75, 0.84, 0.72)
	st_light.light_energy = 0.55
	st_light.omni_range = 7.5
	st_light.shadow_enabled = false
	st_light.distance_fade_enabled = true
	st_light.distance_fade_begin = 22.0
	st.add_child(st_light)


func _build_sewer_shed_and_perimeter() -> void:
	var shed: Node3D = Node3D.new()
	shed.name = "SewerAccessShed"
	add_child(shed)

	# Guarita sobre a boca do esgoto (X:-44.8..-35.5, Z:-16.2..-11.8)
	_add_box(shed, "ShedWallN", Vector3(9.4, 2.6, 0.25), Vector3(-40.1, 1.3, -15.8), "concrete_dark")
	_add_box(shed, "ShedWallS", Vector3(9.4, 2.6, 0.25), Vector3(-40.1, 1.3, -12.2), "concrete_dark")
	_add_box(shed, "ShedWallW", Vector3(0.25, 2.6, 3.8), Vector3(-44.8, 1.3, -14.0), "concrete_dark")
	_add_box(shed, "ShedRoof", Vector3(9.6, 0.22, 4.0), Vector3(-40.1, 2.7, -14.0), "roof")

	# Muros de perímetro da Zona Oeste e barricada do fim da rua
	_add_box(shed, "WestZoneWallN", Vector3(40.0, 2.8, 0.4), Vector3(-46.0, 1.4, -20.0), "concrete")
	_add_box(shed, "WestZoneWallW", Vector3(0.4, 3.2, 45.0), Vector3(-66.0, 1.6, 2.0), "concrete")
	_add_box(shed, "WestZoneWallS", Vector3(40.0, 2.8, 0.4), Vector3(-46.0, 1.4, 24.2), "concrete_dark")

	# Caminhão tombado fechando o fim da avenida oeste (X=-62.5)
	_add_box(shed, "WreckedTruck", Vector3(2.4, 2.3, 6.2), Vector3(-62.5, 1.15, 13.0), "rust", Vector3(0.0, 8.0, 0.0))
	_add_box(shed, "RoadBlock1", Vector3(0.3, 1.0, 2.6), Vector3(-59.5, 0.5, 11.4), "metal_red", Vector3.ZERO, true, true)
	_add_box(shed, "RoadBlock2", Vector3(0.3, 1.0, 2.6), Vector3(-59.5, 0.5, 14.3), "metal_red", Vector3.ZERO, true, true)
