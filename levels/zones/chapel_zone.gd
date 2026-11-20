@tool
extends Node3D
## Zona Leste: Cemitério Esquecido, Avenida Leste e Capela do Sol Sorridente trancada por chave.

const LAYER_ENVIRONMENT: int = 1
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")
const _DoorScript := preload("res://systems/interactables/door_interactable.gd")

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
	_build_east_street_and_cemetery()
	_build_chapel()


func _init_materials() -> void:
	_materials.clear()
	_materials["asphalt"] = _make_mat(Color(0.22, 0.22, 0.24))
	_materials["stripe"] = _make_mat(Color(0.76, 0.62, 0.22))
	_materials["sidewalk"] = _make_mat(Color(0.54, 0.52, 0.48))
	_materials["dirt"] = _make_mat(Color(0.29, 0.28, 0.27))
	_materials["stone"] = _make_mat(Color(0.48, 0.46, 0.45))
	_materials["old_brick"] = _make_mat(Color(0.48, 0.31, 0.25))
	_materials["old_brick_dark"] = _make_mat(Color(0.31, 0.21, 0.18))
	_materials["stone_dark"] = _make_mat(Color(0.28, 0.27, 0.29))
	_materials["chapel_wall"] = _make_mat(Color(0.58, 0.54, 0.48))
	_materials["roof"] = _make_mat(Color(0.18, 0.14, 0.15))
	_materials["wood"] = _make_mat(Color(0.36, 0.24, 0.15))
	_materials["carpet"] = _make_mat(Color(0.52, 0.14, 0.12))
	_materials["altar_gold"] = _make_mat(Color(0.88, 0.72, 0.28))


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


func _build_east_street_and_cemetery() -> void:
	var g: Node3D = Node3D.new()
	g.name = "EastStreetAndCemetery"
	add_child(g)

	# Rua Leste X=+36..+70
	_add_box(g, "EastRoadAsphalt", Vector3(34.0, 0.1, 4.6), Vector3(53.0, -0.05, 12.9), "asphalt")
	for i: int in range(5):
		_add_box(g, "EastStripe_%d" % i, Vector3(2.8, 0.02, 0.16), Vector3(39.0 + float(i) * 5.8, 0.005, 12.9), "stripe", Vector3.ZERO, false, true)
	_add_box(g, "EastSidewalkN", Vector3(34.0, 0.12, 1.0), Vector3(53.0, -0.04, 10.1), "sidewalk")
	_add_box(g, "EastSidewalkS", Vector3(34.0, 0.12, 1.0), Vector3(53.0, -0.04, 15.7), "sidewalk")
	_add_box(g, "EastSouthLot", Vector3(34.0, 0.1, 8.0), Vector3(53.0, -0.05, 20.2), "dirt")

	# Terreno do Cemitério e pátio da Capela (X:+36..+70, Z:-24..+9.6)
	_add_box(g, "CemeteryGround", Vector3(34.0, 0.1, 33.6), Vector3(53.0, -0.05, -7.2), "dirt")
	_add_box(g, "ChapelPath", Vector3(3.4, 0.04, 12.0), Vector3(52.0, 0.01, 4.0), "stone")

	# Lápides e cruzes do cemitério
	var graves: Array[Vector2] = [
		Vector2(41.0, 5.2), Vector2(44.5, 5.4), Vector2(41.2, 1.8), Vector2(45.2, 1.5),
		Vector2(58.5, 5.0), Vector2(62.0, 4.8), Vector2(59.0, 1.4), Vector2(62.5, 1.0),
	]
	for idx: int in range(graves.size()):
		var gp: Vector2 = graves[idx]
		_add_box(g, "Tombstone_%d" % idx, Vector3(0.85, 1.15, 0.25), Vector3(gp.x, 0.58, gp.y), "stone_dark", Vector3(0.0, 6.0 if (idx % 2 == 0) else -8.0, 0.0), true, true)
		_add_box(g, "GraveSlab_%d" % idx, Vector3(1.1, 0.12, 1.8), Vector3(gp.x, 0.06, gp.y + 0.9), "stone", Vector3.ZERO, true, true)

	# Quarteirão Histórico Leste (substitui muros lisos por sobrados antigos, Beco do Campanário e rua bloqueada)
	_add_box(g, "EastNorthTenement_W", Vector3(16.0, 10.2, 4.2), Vector3(44.0, 5.1, -25.2), "old_brick_dark")
	_add_box(g, "EastNorthTenement_E", Vector3(18.0, 11.0, 4.2), Vector3(62.0, 5.5, -25.2), "old_brick")
	_add_box(g, "EastEndBlock_N", Vector3(4.5, 11.4, 32.0), Vector3(71.8, 5.7, -7.5), "old_brick_dark")
	_add_box(g, "EastEndBlock_S", Vector3(4.5, 9.8, 9.0), Vector3(71.8, 4.9, 20.5), "old_brick")
	# Sobrados Coloniais ladeando a Capela (criam o Beco do Campanário X: 40.8..44.0 e Beco Leste da Capela X: 60.0..63.2)
	_add_box(g, "ChapelWestTownhouse", Vector3(3.6, 9.4, 15.0), Vector3(39.0, 4.7, -12.0), "old_brick")
	_add_box(g, "ChapelWestOverpass", Vector3(3.2, 4.6, 3.0), Vector3(42.4, 6.6, -12.0), "old_brick_dark", Vector3.ZERO, false)
	_add_box(g, "ChapelEastTownhouse", Vector3(4.8, 9.8, 15.0), Vector3(65.8, 4.9, -12.0), "old_brick_dark")
	_add_box(g, "ChapelEastOverpass", Vector3(3.4, 4.8, 3.0), Vector3(61.7, 6.8, -12.0), "old_brick", Vector3.ZERO, false)
	# Quarteirão Sul da Capela (lojas antigas, Beco da Capela X: 51.5..54.5 e Galeria Sul Z: 21.5..24.0)
	_add_box(g, "EastSouthShopRow_W", Vector3(15.0, 9.4, 4.8), Vector3(43.8, 4.7, 18.9), "old_brick")
	_add_box(g, "EastSouthShopRow_E", Vector3(15.5, 10.0, 4.8), Vector3(62.2, 5.0, 18.9), "old_brick_dark")
	_add_box(g, "EastSouthGalleryBack", Vector3(34.0, 9.2, 0.8), Vector3(53.0, 4.6, 24.4), "old_brick_dark")
	# Barricada de veículos e continuação visual da Avenida Leste além do bloqueio
	_add_box(g, "CemeteryDeadEndVan", Vector3(2.4, 2.2, 5.6), Vector3(66.5, 1.1, 12.9), "stone_dark", Vector3(0.0, -10.0, 0.0))
	_add_box(g, "EastRoadBlockWall", Vector3(1.2, 2.2, 7.2), Vector3(69.6, 1.1, 12.9), "stone_dark")
	_add_box(g, "EastAvenueContinuation", Vector3(20.0, 0.1, 6.6), Vector3(80.0, -0.05, 12.9), "asphalt", Vector3.ZERO, false)
	_add_box(g, "EastBeyondBldg_N", Vector3(16.0, 12.0, 5.0), Vector3(80.0, 6.0, 5.8), "old_brick_dark", Vector3.ZERO, false)
	_add_box(g, "EastBeyondBldg_S", Vector3(16.0, 11.0, 5.0), Vector3(80.0, 5.5, 20.0), "old_brick", Vector3.ZERO, false)


func _build_chapel() -> void:
	var chp: Node3D = Node3D.new()
	chp.name = "SmilingSunChapel"
	add_child(chp)

	# Nave da Capela (X:+44..+60, Z:-21..-3) com Teto recortado na escadaria oeste (X:44.3..46.8, Z:-15.0..-6.8) e no Campanário!
	_add_box(chp, "ChapelFloor", Vector3(16.0, 0.08, 18.0), Vector3(52.0, 0.0, -12.0), "stone")
	_add_box(chp, "ChapelCarpet", Vector3(2.4, 0.03, 14.0), Vector3(52.0, 0.09, -11.0), "carpet", Vector3.ZERO, false, true)
	# Laje de teto/piso superior (Y = 5.20, topo em Y = 5.42) recortada para a escada do campanário
	_add_box(chp, "ChapelRoofEastMain", Vector3(13.2, 0.44, 19.0), Vector3(53.4, 5.20, -12.0), "roof")
	_add_box(chp, "ChapelRoofWestNorth", Vector3(2.8, 0.44, 6.2), Vector3(45.4, 5.20, -18.4), "roof")
	_add_box(chp, "ChapelRoofWestSouth", Vector3(2.8, 0.44, 4.2), Vector3(45.4, 5.20, -4.7), "roof")

	# Escadaria de madeira do Campanário ao longo da parede oeste interna (X:44.4..46.6, subindo de Z=-14.6 Y=0 até Z=-6.8 Y=5.42)
	_add_box(chp, "BelfryStairRamp", Vector3(2.1, 0.24, 9.5), Vector3(45.5, 2.68, -10.7), "wood", Vector3(34.6, 0.0, 0.0))
	_add_box(chp, "BelfryStairRail1F", Vector3(0.18, 1.2, 8.2), Vector3(46.65, 2.8, -10.7), "wood")

	# Mezanino e Torre do Sino Explorável no topo (Y = 5.42m, vista panorâmica da cidade e da Torre Central)
	_add_box(chp, "BelfryDeckGuardN", Vector3(12.8, 1.15, 0.25), Vector3(53.2, 6.0, -7.2), "stone_dark")
	_add_box(chp, "BelfryDeckGuardE", Vector3(0.25, 1.15, 4.2), Vector3(59.6, 6.0, -5.2), "stone_dark")
	_add_box(chp, "BelfryDeckGuardW", Vector3(0.25, 1.15, 12.2), Vector3(44.3, 6.0, -8.8), "stone_dark")
	_add_box(chp, "BelfryDeckGuardS_W", Vector3(5.6, 1.15, 0.25), Vector3(47.1, 6.0, -3.2), "stone_dark")
	_add_box(chp, "BelfryDeckGuardS_E", Vector3(5.6, 1.15, 0.25), Vector3(56.9, 6.0, -3.2), "stone_dark")
	# 4 Pilares do Campanário Aberto (X: 49.8..54.2, Z: -7.2..-3.2, Y: 5.4..10.8) + Guarda-corpos de pedra nos 4 arcos
	for bpx: float in [50.1, 53.9]:
		for bpz: float in [-6.9, -3.5]:
			_add_box(chp, "BelfryPillar", Vector3(0.65, 5.4, 0.65), Vector3(bpx, 8.1, bpz), "chapel_wall")
	_add_box(chp, "BelfryParapetS", Vector3(3.8, 1.15, 0.25), Vector3(52.0, 6.0, -3.4), "chapel_wall")
	_add_box(chp, "BelfryArchTopS", Vector3(4.4, 1.4, 0.35), Vector3(52.0, 10.1, -3.4), "chapel_wall")
	_add_box(chp, "BelfryArchTopN", Vector3(4.4, 1.4, 0.35), Vector3(52.0, 10.1, -7.0), "chapel_wall")
	_add_box(chp, "BelfryArchTopW", Vector3(0.35, 1.4, 4.2), Vector3(50.0, 10.1, -5.2), "chapel_wall")
	_add_box(chp, "BelfryArchTopE", Vector3(0.35, 1.4, 4.2), Vector3(54.0, 10.1, -5.2), "chapel_wall")
	_add_box(chp, "BellTowerCap", Vector3(5.0, 0.6, 5.0), Vector3(52.0, 11.1, -5.2), "roof")
	# Grande Sino de Bronze suspenso no centro do Campanário
	_add_box(chp, "BellYokeBeam", Vector3(3.2, 0.24, 0.28), Vector3(52.0, 9.2, -5.2), "wood", Vector3.ZERO, false)
	_add_box(chp, "GreatBronzeBell", Vector3(1.1, 1.25, 1.1), Vector3(52.0, 8.35, -5.2), "altar_gold", Vector3.ZERO, false)
	_add_box(chp, "BelfryWatchLectern", Vector3(1.1, 0.88, 0.65), Vector3(52.0, 5.86, -4.1), "wood")
	_add_box(chp, "SunSymbol", Vector3(1.6, 1.6, 0.2), Vector3(52.0, 10.2, -3.1), "altar_gold", Vector3(0.0, 0.0, 45.0), false)

	_add_box(chp, "ChapelWallW", Vector3(0.35, 5.2, 18.0), Vector3(44.15, 2.6, -12.0), "chapel_wall")
	_add_box(chp, "ChapelWallE", Vector3(0.35, 5.2, 18.0), Vector3(59.85, 2.6, -12.0), "chapel_wall")
	_add_box(chp, "ChapelWallN", Vector3(16.0, 5.2, 0.35), Vector3(52.0, 2.6, -20.85), "chapel_wall")

	# Fachada Sul com porta trancada pela Chave da Capela (X=51.1..52.9, Z=-3.15)
	_add_box(chp, "ChapelFrontW", Vector3(7.1, 5.2, 0.35), Vector3(47.55, 2.6, -3.15), "chapel_wall")
	_add_box(chp, "ChapelFrontE", Vector3(7.1, 5.2, 0.35), Vector3(56.45, 2.6, -3.15), "chapel_wall")
	_add_box(chp, "ChapelFrontTop", Vector3(1.8, 2.6, 0.35), Vector3(52.0, 3.9, -3.15), "chapel_wall")

	var door: Node3D = Node3D.new()
	door.name = "ChapelMainDoor"
	door.set_script(_DoorScript)
	door.position = Vector3(51.1, 0.0, -3.15)
	door.set("is_locked", true)
	door.set("required_key_id", "chapel_key")
	door.set("key_display_name", "Chave da Capela")
	chp.add_child(door)
	var leaf: StaticBody3D = StaticBody3D.new()
	leaf.name = "DoorLeaf"
	leaf.collision_layer = (1 << 0) | (1 << 3)
	leaf.position = Vector3(0.9, 1.3, 0.0)
	door.add_child(leaf)
	var lm: MeshInstance3D = MeshInstance3D.new()
	lm.mesh = _get_box_mesh(Vector3(1.74, 2.54, 0.1))
	lm.material_override = _materials["wood"] as Material
	leaf.add_child(lm)
	var lc: CollisionShape3D = CollisionShape3D.new()
	lc.shape = _get_box_shape(Vector3(1.74, 2.54, 0.1))
	leaf.add_child(lc)

	# Bancos da capela (recuados na esquerda para dar passagem livre à Escadaria do Campanário em X:44.4..46.8) e Altar dourado
	for pz: float in [-7.5, -10.0, -12.5]:
		_add_box(chp, "PewL", Vector3(3.1, 0.78, 0.65), Vector3(48.7, 0.39, pz), "wood", Vector3.ZERO, true, true)
		_add_box(chp, "PewR", Vector3(4.0, 0.78, 0.65), Vector3(56.0, 0.39, pz), "wood", Vector3.ZERO, true, true)

	_add_box(chp, "AltarStep", Vector3(7.5, 0.35, 3.6), Vector3(52.0, 0.18, -18.2), "stone_dark")
	_add_box(chp, "ChapelAltarTable", Vector3(3.0, 1.0, 1.1), Vector3(52.0, 0.85, -18.3), "altar_gold")

	var altar_light: OmniLight3D = OmniLight3D.new()
	altar_light.position = Vector3(52.0, 3.2, -16.5)
	altar_light.light_color = Color(1.0, 0.74, 0.34)
	altar_light.light_energy = 1.2
	altar_light.omni_range = 10.5
	altar_light.shadow_enabled = false
	altar_light.distance_fade_enabled = true
	altar_light.distance_fade_begin = 26.0
	chp.add_child(altar_light)
