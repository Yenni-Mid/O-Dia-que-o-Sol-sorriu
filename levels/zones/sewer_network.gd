@tool
extends Node3D
## Rede de Esgoto Subterrânea (Y = -3.2): liga o Túnel da Casa (-24.8, -5.3) ao Posto (-46, -14) e à Escola (-46, -46).

const LAYER_ENVIRONMENT: int = 1
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

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
	_build_west_connector()
	_build_main_spine()
	_build_cistern_room()
	_build_ramp_gas_station()
	_build_ramp_school()


func _init_materials() -> void:
	_materials.clear()
	_materials["sewer_wall"] = _make_mat(Color(0.24, 0.26, 0.25))
	_materials["sewer_floor"] = _make_mat(Color(0.20, 0.22, 0.21))
	_materials["water_sludge"] = _make_mat(Color(0.11, 0.16, 0.12))
	_materials["pipe_rust"] = _make_mat(Color(0.40, 0.25, 0.18))
	_materials["concrete_dark"] = _make_mat(Color(0.29, 0.28, 0.29))


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
	_mesh_cache[size] = m
	return m


func _get_box_shape(size: Vector3) -> BoxShape3D:
	if _shape_cache.has(size):
		return _shape_cache[size] as BoxShape3D
	var s: BoxShape3D = BoxShape3D.new()
	s.size = size
	_shape_cache[size] = s
	return s


func _add_box(p: Node3D, n: String, size: Vector3, pos: Vector3, mat_key: String, rot_deg: Vector3 = Vector3.ZERO, with_col: bool = true) -> Node3D:
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
	m_only.material_override = _materials.get(mat_key, null) as Material
	p.add_child(m_only)
	return m_only


func _add_dim_bulb(p: Node3D, pos: Vector3) -> void:
	var l: OmniLight3D = OmniLight3D.new()
	l.position = pos
	l.light_color = Color(0.62, 0.78, 0.56)
	l.light_energy = 0.55
	l.omni_range = 7.0
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 20.0
	l.distance_fade_length = 6.0
	p.add_child(l)


func _build_west_connector() -> void:
	var g: Node3D = Node3D.new()
	g.name = "SewerConnectorEW"
	add_child(g)
	# Liga X=-24.8 até X=-44.4 em Z=-5.3 (largura 3.0m, teto em -0.35, piso em -3.2)
	_add_box(g, "EWFloor", Vector3(19.6, 0.2, 3.2), Vector3(-34.6, -3.3, -5.3), "sewer_floor")
	_add_box(g, "EWCeiling", Vector3(19.6, 0.2, 3.2), Vector3(-34.6, -0.35, -5.3), "sewer_wall")
	_add_box(g, "EWWallN", Vector3(19.6, 3.1, 0.25), Vector3(-34.6, -1.8, -6.8), "sewer_wall")
	_add_box(g, "EWWallS", Vector3(19.6, 3.1, 0.25), Vector3(-34.6, -1.8, -3.8), "sewer_wall")
	_add_box(g, "EWPipe", Vector3(19.0, 0.28, 0.28), Vector3(-34.6, -1.1, -6.55), "pipe_rust", Vector3.ZERO, false)
	_add_dim_bulb(g, Vector3(-34.6, -0.75, -5.3))


func _build_main_spine() -> void:
	var sp: Node3D = Node3D.new()
	sp.name = "SewerSpineNS"
	add_child(sp)
	# Tronco principal X=-47.6..-44.4 (centro -46.0), Z=-47.6..-3.7
	_add_box(sp, "SpineFloor", Vector3(3.4, 0.2, 44.0), Vector3(-46.0, -3.3, -25.65), "sewer_floor")
	_add_box(sp, "SpineSludge", Vector3(1.1, 0.02, 42.5), Vector3(-46.0, -3.19, -25.65), "water_sludge", Vector3.ZERO, false)
	_add_box(sp, "SpineCeiling", Vector3(3.4, 0.2, 44.0), Vector3(-46.0, -0.35, -25.65), "sewer_wall")

	_add_box(sp, "SpineCapS", Vector3(3.4, 3.1, 0.25), Vector3(-46.0, -1.8, -3.7), "sewer_wall")
	_add_box(sp, "SpineCapN", Vector3(3.4, 3.1, 0.25), Vector3(-46.0, -1.8, -47.6), "sewer_wall")

	# Parede Oeste recortada em Z:-29..-23 para a Câmara da Cisterna
	_add_box(sp, "SpineWallW_S", Vector3(0.25, 3.1, 19.3), Vector3(-47.6, -1.8, -13.35), "sewer_wall")
	_add_box(sp, "SpineWallW_N", Vector3(0.25, 3.1, 18.6), Vector3(-47.6, -1.8, -38.3), "sewer_wall")

	# Parede Leste com aberturas em Z:-6.8..-3.8 (túnel leste), Z:-15.3..-12.7 (rampa posto), Z:-47.3..-44.7 (rampa escola)
	_add_box(sp, "SpineWallE_1", Vector3(0.25, 3.1, 5.9), Vector3(-44.4, -1.8, -9.75), "sewer_wall")
	_add_box(sp, "SpineWallE_2", Vector3(0.25, 3.1, 29.4), Vector3(-44.4, -1.8, -30.0), "sewer_wall")
	_add_dim_bulb(sp, Vector3(-46.0, -0.75, -19.0))
	_add_dim_bulb(sp, Vector3(-46.0, -0.75, -36.0))


func _build_cistern_room() -> void:
	var c: Node3D = Node3D.new()
	c.name = "SewerCisternChamber"
	add_child(c)
	# Câmara X:-53.6..-47.6, Z:-29.0..-23.0
	_add_box(c, "CisternFloor", Vector3(6.2, 0.2, 6.2), Vector3(-50.6, -3.3, -26.0), "sewer_floor")
	_add_box(c, "CisternCeiling", Vector3(6.2, 0.2, 6.2), Vector3(-50.6, -0.35, -26.0), "sewer_wall")
	_add_box(c, "CisternWallW", Vector3(0.25, 3.1, 6.2), Vector3(-53.6, -1.8, -26.0), "sewer_wall")
	_add_box(c, "CisternWallN", Vector3(6.2, 3.1, 0.25), Vector3(-50.6, -1.8, -29.0), "sewer_wall")
	_add_box(c, "CisternWallS", Vector3(6.2, 3.1, 0.25), Vector3(-50.6, -1.8, -23.0), "sewer_wall")
	_add_box(c, "CisternPillar", Vector3(0.7, 3.0, 0.7), Vector3(-50.6, -1.8, -26.0), "concrete_dark")
	_add_dim_bulb(c, Vector3(-50.6, -0.75, -26.0))


func _build_ramp_gas_station() -> void:
	var r: Node3D = Node3D.new()
	r.name = "SewerRampGasStation"
	add_child(r)
	# Rampa subindo para Leste de X=-44.4 (Y=-3.2) até X=-38.4 (Y=0.0) em Z=-14.0
	_add_box(r, "GasRampSlope", Vector3(6.8, 0.2, 2.6), Vector3(-41.4, -1.68, -14.0), "concrete_dark", Vector3(0.0, 0.0, 28.07))
	_add_box(r, "GasPitWallN", Vector3(6.2, 3.3, 0.25), Vector3(-41.4, -1.6, -15.4), "sewer_wall")
	_add_box(r, "GasPitWallS", Vector3(6.2, 3.3, 0.25), Vector3(-41.4, -1.6, -12.6), "sewer_wall")


func _build_ramp_school() -> void:
	var r: Node3D = Node3D.new()
	r.name = "SewerRampSchool"
	add_child(r)
	# Rampa subindo para Leste de X=-44.4 (Y=-3.2) até X=-38.4 (Y=0.0) em Z=-46.0
	_add_box(r, "SchoolRampSlope", Vector3(6.8, 0.2, 2.6), Vector3(-41.4, -1.68, -46.0), "concrete_dark", Vector3(0.0, 0.0, 28.07))
	_add_box(r, "SchoolPitWallN", Vector3(6.2, 3.3, 0.25), Vector3(-41.4, -1.6, -47.4), "sewer_wall")
	_add_box(r, "SchoolPitWallS", Vector3(6.2, 3.3, 0.25), Vector3(-41.4, -1.6, -44.6), "sewer_wall")
