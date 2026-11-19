@tool
extends Node3D
## Quarteirão da Demo ao redor da Casa de Dois Andares:
## rua asfaltada, calçadas, comércio fechado, casa vizinha, carro abandonado, ponto de ônibus com sombra,
## postes tortos, árvores secas, muros perimetrais e a Torre Central ("Espelho da Alma Partida") no horizonte.

const LAYER_ENVIRONMENT: int = 1
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

var _materials: Dictionary = {}
var _textures: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _shape_cache: Dictionary = {}


func _ready() -> void:
	rebuild_block()


func rebuild_block() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()

	_mesh_cache.clear()
	_shape_cache.clear()
	_init_textures()
	_init_materials()

	_build_ground_and_street()
	_build_perimeter_walls()
	_build_neighbor_buildings()
	_build_street_props_and_covers()
	_build_distant_horizon_tower()


# --------------------------------------------------------------------------- Texturas & Materiais PS1

func _init_textures() -> void:
	_textures.clear()
	_textures["asphalt"] = _make_asphalt_texture()
	_textures["sidewalk"] = _make_sidewalk_texture()
	_textures["dirt_grass"] = _make_dirt_grass_texture()
	_textures["concrete"] = _make_concrete_texture()
	_textures["facade_brick"] = _make_brick_texture()
	_textures["rusted_metal"] = _make_rusted_metal_texture()
	_textures["wood_plank"] = _make_wood_texture()
	_textures["cult_sign"] = _make_cult_smile_texture()


func _init_materials() -> void:
	_materials.clear()
	_materials["asphalt"] = _make_mat(Color(0.24, 0.23, 0.25), _textures["asphalt"] as Texture2D, Vector2(12.0, 2.0))
	_materials["road_stripe"] = _make_mat(Color(0.76, 0.62, 0.22), _textures["concrete"] as Texture2D, Vector2(1.0, 1.0))
	_materials["sidewalk"] = _make_mat(Color(0.56, 0.54, 0.50), _textures["sidewalk"] as Texture2D, Vector2(8.0, 1.0))
	_materials["dirt_grass"] = _make_mat(Color(0.38, 0.34, 0.25), _textures["dirt_grass"] as Texture2D, Vector2(6.0, 4.0))
	_materials["concrete"] = _make_mat(Color(0.52, 0.50, 0.46), _textures["concrete"] as Texture2D, Vector2(4.0, 2.0))
	_materials["concrete_dark"] = _make_mat(Color(0.32, 0.31, 0.30), _textures["concrete"] as Texture2D, Vector2(3.0, 2.0))
	_materials["wall_brick"] = _make_mat(Color(0.58, 0.46, 0.39), _textures["facade_brick"] as Texture2D, Vector2(5.0, 2.5))
	_materials["neighbor_stucco"] = _make_mat(Color(0.62, 0.58, 0.50), _textures["concrete"] as Texture2D, Vector2(4.0, 3.0))
	_materials["roof_dark"] = _make_mat(Color(0.18, 0.16, 0.15), _textures["facade_brick"] as Texture2D, Vector2(4.0, 4.0))
	_materials["awning"] = _make_mat(Color(0.56, 0.22, 0.18), _textures["wood_plank"] as Texture2D, Vector2(3.0, 1.0))
	_materials["car_rust"] = _make_mat(Color(0.46, 0.25, 0.19), _textures["rusted_metal"] as Texture2D, Vector2(2.0, 2.0))
	_materials["metal_dark"] = _make_mat(Color(0.18, 0.19, 0.21), _textures["rusted_metal"] as Texture2D, Vector2(2.0, 2.0))
	_materials["glass_broken"] = _make_mat(Color(0.14, 0.18, 0.20), _textures["concrete"] as Texture2D, Vector2(1.0, 1.0))
	_materials["wood_old"] = _make_mat(Color(0.38, 0.27, 0.17), _textures["wood_plank"] as Texture2D, Vector2(2.0, 1.5))
	_materials["bark"] = _make_mat(Color(0.24, 0.19, 0.15), _textures["wood_plank"] as Texture2D, Vector2(2.0, 3.0))
	_materials["cult_sign"] = _make_mat(Color(0.95, 0.92, 0.84), _textures["cult_sign"] as Texture2D, Vector2(1.0, 1.0))
	_materials["skyline"] = _make_mat(Color(0.16, 0.14, 0.15), _textures["concrete"] as Texture2D, Vector2(4.0, 10.0))

	var altar_mat: StandardMaterial3D = StandardMaterial3D.new()
	altar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	altar_mat.albedo_color = Color(0.95, 0.78, 0.36)
	_materials["tower_altar"] = altar_mat


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
	std.roughness = 0.9
	return std


func _make_asphalt_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 701
	for y: int in range(64):
		for x: int in range(64):
			var v: float = clampf(0.84 + rng.randf_range(-0.14, 0.12), 0.55, 1.0)
			if (x + y * 3) % 41 == 0:
				v *= 0.65
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)


func _make_sidewalk_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 702
	for y: int in range(64):
		for x: int in range(64):
			var seam: bool = (x % 32) == 0 or (y % 32) == 0
			var v: float = 0.62 if seam else clampf(0.92 + rng.randf_range(-0.06, 0.06), 0.65, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.99, v * 0.96, 1.0))
	return ImageTexture.create_from_image(img)


func _make_dirt_grass_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 703
	for y: int in range(64):
		for x: int in range(64):
			var patch: float = sin(float(x) * 0.25) * cos(float(y) * 0.25) * 0.08
			var g: float = clampf(0.86 + patch + rng.randf_range(-0.10, 0.10), 0.55, 1.0)
			img.set_pixel(x, y, Color(g * 0.98, g, g * 0.85, 1.0))
	return ImageTexture.create_from_image(img)


func _make_concrete_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 704
	for y: int in range(64):
		var streak: float = 0.08 if y > 48 else 0.0
		for x: int in range(64):
			var v: float = clampf(0.90 + rng.randf_range(-0.07, 0.06) - streak, 0.55, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)


func _make_brick_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 705
	for y: int in range(64):
		var row: int = y / 8
		var shift: int = 8 if (row % 2) == 1 else 0
		var mh: bool = (y % 8) == 0
		for x: int in range(64):
			var mv: bool = ((x + shift) % 16) == 0
			var v: float = 0.58 if (mh or mv) else clampf(0.90 + rng.randf_range(-0.08, 0.08), 0.60, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.95, v * 0.92, 1.0))
	return ImageTexture.create_from_image(img)


func _make_rusted_metal_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 706
	for y: int in range(64):
		for x: int in range(64):
			var rust: float = 0.82 if ((x * 7 + y * 5) % 19) < 6 else 0.96
			var v: float = clampf(rust + rng.randf_range(-0.08, 0.06), 0.50, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.88, v * 0.82, 1.0))
	return ImageTexture.create_from_image(img)


func _make_wood_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 707
	for y: int in range(64):
		var seam: bool = (y % 16) == 0
		for x: int in range(64):
			var v: float = 0.55 if seam else clampf(0.90 + sin(float(x) * 0.3) * 0.05 + rng.randf_range(-0.04, 0.04), 0.55, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.96, v * 0.90, 1.0))
	return ImageTexture.create_from_image(img)


func _make_cult_smile_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y: int in range(64):
		for x: int in range(64):
			var dx: float = float(x) - 32.0
			var dy: float = float(y) - 32.0
			var dist: float = sqrt(dx * dx + dy * dy)
			var col: Color = Color(0.86, 0.82, 0.72, 1.0)
			if absf(dist - 24.0) <= 2.2:
				col = Color(0.75, 0.12, 0.10, 1.0)
			elif absf(dx + 8.5) <= 2.6 and absf(dy + 7.0) <= 3.5:
				col = Color(0.12, 0.04, 0.04, 1.0)
			elif absf(dx - 8.5) <= 3.0 and absf(dy + 6.0) <= 2.6:
				col = Color(0.12, 0.04, 0.04, 1.0)
			else:
				var smile_y: float = 11.5 - (dx * dx) * 0.036
				if absf(dx) <= 16.0 and absf(dy - smile_y) <= 2.0:
					col = Color(0.78, 0.08, 0.08, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


# --------------------------------------------------------------------------- Construtores de Geometria

func _create_group(group_name: String) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = group_name
	add_child(n)
	return n


func _add_box(
	parent_node: Node3D,
	part_name: String,
	size: Vector3,
	pos: Vector3,
	mat_key: String,
	rot_deg: Vector3 = Vector3.ZERO,
	with_collision: bool = true
) -> Node3D:
	if with_collision:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = part_name
		body.position = pos
		body.rotation_degrees = rot_deg
		body.collision_layer = LAYER_ENVIRONMENT
		body.collision_mask = 0
		parent_node.add_child(body)

		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		mesh_inst.name = "Mesh"
		mesh_inst.mesh = _get_box_mesh(size)
		if _materials.has(mat_key):
			mesh_inst.material_override = _materials[mat_key] as Material
		body.add_child(mesh_inst)

		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "Collision"
		col.shape = _get_box_shape(size)
		body.add_child(col)
		return body
	else:
		var mesh_only: MeshInstance3D = MeshInstance3D.new()
		mesh_only.name = part_name
		mesh_only.position = pos
		mesh_only.rotation_degrees = rot_deg
		mesh_only.mesh = _get_box_mesh(size)
		mesh_only.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _materials.has(mat_key):
			mesh_only.material_override = _materials[mat_key] as Material
		parent_node.add_child(mesh_only)
		return mesh_only


func _get_box_mesh(size: Vector3) -> BoxMesh:
	if _mesh_cache.has(size):
		return _mesh_cache[size] as BoxMesh
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	m.subdivide_width = clampi(int(size.x / 2.2), 0, 10)
	m.subdivide_height = clampi(int(size.y / 2.2), 0, 6)
	m.subdivide_depth = clampi(int(size.z / 2.2), 0, 10)
	_mesh_cache[size] = m
	return m


func _get_box_shape(size: Vector3) -> BoxShape3D:
	if _shape_cache.has(size):
		return _shape_cache[size] as BoxShape3D
	var s: BoxShape3D = BoxShape3D.new()
	s.size = size
	_shape_cache[size] = s
	return s


# --------------------------------------------------------------------------- Seções do Quarteirão

func _build_ground_and_street() -> void:
	var g: Node3D = _create_group("StreetAndLots")
	# Rua asfaltada (X: -26..+26, Z: 10.6..15.2, topo exatamente em y = 0.0)
	_add_box(g, "MainRoadAsphalt", Vector3(52.0, 0.1, 4.6), Vector3(0.0, -0.05, 12.9), "asphalt")
	for i: int in range(-4, 5):
		_add_box(g, "RoadStripe_%d" % (i + 4), Vector3(2.8, 0.02, 0.16), Vector3(float(i) * 5.4, 0.005, 12.9), "road_stripe", Vector3.ZERO, false)

	# Calçada Norte em frente à casa (Z: 9.6..10.6)
	_add_box(g, "SidewalkNorth", Vector3(52.0, 0.12, 1.0), Vector3(0.0, -0.04, 10.1), "sidewalk")
	# Calçada Sul ladeando a saída do beco inicial (Z: 15.2..16.2)
	_add_box(g, "SidewalkSouthWest", Vector3(23.0, 0.12, 1.0), Vector3(-14.5, -0.04, 15.7), "sidewalk")
	_add_box(g, "SidewalkSouthEast", Vector3(23.0, 0.12, 1.0), Vector3(14.5, -0.04, 15.7), "sidewalk")

	# Terrenos / quintais ao redor da casa (contornam X: -8..+8, Z: -7..+7 e varanda X: -3..+3, Z: 7..10)
	_add_box(g, "YardWest", Vector3(18.0, 0.1, 29.6), Vector3(-17.0, -0.05, -5.2), "dirt_grass")
	_add_box(g, "YardEast", Vector3(18.0, 0.1, 29.6), Vector3(17.0, -0.05, -5.2), "dirt_grass")
	_add_box(g, "YardBackNorth", Vector3(16.0, 0.1, 13.0), Vector3(0.0, -0.05, -13.5), "dirt_grass")
	_add_box(g, "FrontLawnLeft", Vector3(5.0, 0.1, 2.6), Vector3(-5.5, -0.05, 8.3), "dirt_grass")
	_add_box(g, "FrontLawnRight", Vector3(5.0, 0.1, 2.6), Vector3(5.5, -0.05, 8.3), "dirt_grass")


func _build_perimeter_walls() -> void:
	var walls: Node3D = _create_group("PerimeterWalls")
	# Muro Norte de fundo (permite enxergar a Torre Central no horizonte)
	_add_box(walls, "WallNorth", Vector3(52.4, 2.8, 0.4), Vector3(0.0, 1.4, -20.0), "concrete")
	# Muros Oeste e Leste fechando o quarteirão
	_add_box(walls, "WallWest", Vector3(0.4, 3.2, 45.2), Vector3(-26.0, 1.6, 2.4), "concrete")
	_add_box(walls, "WallEast", Vector3(0.4, 3.2, 45.2), Vector3(26.0, 1.6, 2.4), "concrete")
	# Muros Sul fechando os dois lados da rua além da saída do abrigo inicial
	_add_box(walls, "WallSouthWest", Vector3(23.0, 3.0, 0.4), Vector3(-14.5, 1.5, 16.4), "concrete_dark")
	_add_box(walls, "WallSouthEast", Vector3(23.0, 3.0, 0.4), Vector3(14.5, 1.5, 16.4), "concrete_dark")


func _build_neighbor_buildings() -> void:
	var bldgs: Node3D = _create_group("NeighborBuildings")

	# 1. Mini-Mercado "Sol Nascente" (Oeste, X: -25.5..-17.5, Z: -7.5..+7.0)
	var market: Node3D = Node3D.new()
	market.name = "MiniMarket"
	bldgs.add_child(market)
	_add_box(market, "MarketBody", Vector3(8.0, 4.6, 14.5), Vector3(-21.5, 2.3, -0.25), "wall_brick")
	_add_box(market, "MarketParapet", Vector3(8.2, 0.9, 0.4), Vector3(-21.5, 4.95, 7.0), "concrete")
	_add_box(market, "MarketSignBoard", Vector3(5.6, 0.85, 0.16), Vector3(-21.5, 4.0, 7.12), "wood_old")
	# Toldo quebrado avançando na calçada para gerar sombra tática
	_add_box(market, "MarketAwning", Vector3(7.4, 0.16, 2.8), Vector3(-21.2, 2.9, 8.4), "awning", Vector3(8.0, 0.0, 0.0))
	_add_box(market, "AwningPostL", Vector3(0.14, 2.8, 0.14), Vector3(-24.6, 1.4, 9.5), "metal_dark")
	_add_box(market, "AwningPostR", Vector3(0.14, 2.8, 0.14), Vector3(-17.8, 1.4, 9.5), "metal_dark")
	_add_box(market, "BoardedWindowFront", Vector3(3.4, 1.6, 0.14), Vector3(-21.5, 1.5, 7.08), "wood_old")
	# Cerca baixa ligando o fundo do mercado à entrada do beco oeste
	_add_box(market, "AlleyCrateStack", Vector3(1.2, 1.1, 1.2), Vector3(-16.8, 0.55, 5.2), "wood_old")
	_add_box(market, "AlleyCrateTop", Vector3(0.8, 0.75, 0.8), Vector3(-16.7, 1.48, 5.1), "wood_old", Vector3(0.0, 18.0, 0.0))

	# 2. Casa Vizinha Abandonada (Leste, X: +17.5..+25.5, Z: -7.0..+7.5)
	var neighbor: Node3D = Node3D.new()
	neighbor.name = "NeighborHouse"
	bldgs.add_child(neighbor)
	_add_box(neighbor, "NeighborBody", Vector3(8.0, 6.2, 14.5), Vector3(21.5, 3.1, 0.25), "neighbor_stucco")
	_add_box(neighbor, "NeighborRoof", Vector3(8.6, 0.45, 15.1), Vector3(21.5, 6.42, 0.25), "roof_dark")
	_add_box(neighbor, "NeighborPorchRoof", Vector3(4.0, 0.22, 2.2), Vector3(20.5, 3.2, 8.6), "roof_dark")
	_add_box(neighbor, "NeighborBoardWin1", Vector3(1.8, 1.3, 0.12), Vector3(20.5, 1.6, 7.56), "wood_old")
	_add_box(neighbor, "NeighborBoardWin2", Vector3(1.8, 1.3, 0.12), Vector3(20.5, 4.6, 7.56), "wood_old")
	_add_box(neighbor, "NeighborLowWall", Vector3(7.6, 0.95, 0.25), Vector3(21.5, 0.48, 9.4), "concrete_dark")

	# 3. Garagens / Muros Sul atrás da calçada sul (dando profundidade atrás do muro)
	var south_row: Node3D = Node3D.new()
	south_row.name = "SouthBuildings"
	bldgs.add_child(south_row)
	_add_box(south_row, "GarageWest", Vector3(14.0, 4.4, 7.0), Vector3(-14.0, 2.2, 20.5), "wall_brick")
	_add_box(south_row, "GarageEast", Vector3(14.0, 4.8, 7.0), Vector3(14.0, 2.4, 20.5), "neighbor_stucco")


func _build_street_props_and_covers() -> void:
	var props: Node3D = _create_group("StreetPropsAndCovers")

	# 1. Carro Abandonado (X: -6.5, Z: 13.0) — cobertura contra o sol e Lunáticos
	var car: Node3D = Node3D.new()
	car.name = "AbandonedSedan"
	car.position = Vector3(-6.5, 0.0, 13.0)
	car.rotation_degrees = Vector3(0.0, 14.0, 0.0)
	props.add_child(car)
	_add_box(car, "CarChassis", Vector3(3.8, 0.68, 1.72), Vector3(0.0, 0.56, 0.0), "car_rust")
	_add_box(car, "CarCabin", Vector3(1.95, 0.62, 1.52), Vector3(-0.15, 1.20, 0.0), "car_rust")
	_add_box(car, "Windshield", Vector3(0.08, 0.52, 1.4), Vector3(0.82, 1.18, 0.0), "glass_broken", Vector3(0.0, 0.0, 18.0), false)
	for wx: float in [-1.25, 1.25]:
		for wz: float in [-0.78, 0.78]:
			_add_box(car, "Wheel", Vector3(0.56, 0.56, 0.24), Vector3(wx, 0.28, wz), "metal_dark", Vector3.ZERO, false)

	# 2. Ponto de Ônibus / Abrigo de Concreto (X: 12.5, Z: 10.4) — teto projeta sombra segura
	var bus: Node3D = Node3D.new()
	bus.name = "BusStopShelter"
	bus.position = Vector3(12.5, 0.0, 10.35)
	props.add_child(bus)
	_add_box(bus, "ShelterBackWall", Vector3(3.2, 2.4, 0.2), Vector3(0.0, 1.2, -0.95), "concrete_dark")
	_add_box(bus, "ShelterSideL", Vector3(0.2, 2.4, 1.6), Vector3(-1.5, 1.2, -0.2), "concrete_dark")
	_add_box(bus, "ShelterRoof", Vector3(3.6, 0.22, 2.4), Vector3(0.0, 2.5, 0.05), "concrete")
	_add_box(bus, "ShelterBench", Vector3(2.4, 0.48, 0.55), Vector3(0.0, 0.24, -0.3), "wood_old")
	_add_box(bus, "BusSignPole", Vector3(0.12, 2.9, 0.12), Vector3(2.1, 1.45, 0.3), "metal_dark")
	_add_box(bus, "BusSignPlate", Vector3(0.55, 0.65, 0.08), Vector3(2.1, 2.55, 0.3), "cult_sign", Vector3(0.0, 0.0, -6.0))

	# 3. Postes de Luz Quebrados ao longo da calçada
	var pole_positions: Array[Vector3] = [
		Vector3(-14.5, 0.0, 9.8),
		Vector3(-4.2, 0.0, 9.8),
		Vector3(5.6, 0.0, 9.8),
		Vector3(16.2, 0.0, 9.8),
		Vector3(9.5, 0.0, 15.6),
	]
	for i: int in range(pole_positions.size()):
		var pole: Node3D = Node3D.new()
		pole.name = "LightPole_%d" % i
		pole.position = pole_positions[i]
		pole.rotation_degrees = Vector3(0.0, 0.0, -5.0 if (i % 2 == 0) else 6.0)
		props.add_child(pole)
		_add_box(pole, "Post", Vector3(0.16, 4.6, 0.16), Vector3(0.0, 2.3, 0.0), "metal_dark")
		_add_box(pole, "Arm", Vector3(0.12, 0.12, 1.3), Vector3(0.0, 4.5, 0.6), "metal_dark")
		_add_box(pole, "DeadLamp", Vector3(0.28, 0.14, 0.45), Vector3(0.0, 4.42, 1.15), "concrete_dark", Vector3.ZERO, false)

	# 4. Totens / Placas do Culto nos cruzamentos
	_build_cult_sign(props, "CultSign_West", Vector3(-16.2, 0.0, 11.1), 22.0)
	_build_cult_sign(props, "CultSign_East", Vector3(17.2, 0.0, 11.4), -28.0)

	# 5. Árvores Secas Low-Poly
	_build_dead_tree(props, "DeadTree_West", Vector3(-11.2, 0.0, -4.5), 1.0)
	_build_dead_tree(props, "DeadTree_East", Vector3(14.5, 0.0, -6.5), 1.15)
	_build_dead_tree(props, "DeadTree_Market", Vector3(-18.5, 0.0, 10.6), 0.9)


func _build_cult_sign(parent_node: Node3D, sign_name: String, pos: Vector3, yaw_deg: float) -> void:
	var sign_node: Node3D = Node3D.new()
	sign_node.name = sign_name
	sign_node.position = pos
	sign_node.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	parent_node.add_child(sign_node)
	_add_box(sign_node, "Post", Vector3(0.1, 1.45, 0.1), Vector3(0.0, 0.725, 0.0), "wood_old")
	_add_box(sign_node, "Board", Vector3(0.75, 0.75, 0.06), Vector3(0.0, 1.25, 0.04), "cult_sign", Vector3(0.0, 0.0, 4.0))


func _build_dead_tree(parent_node: Node3D, tree_name: String, pos: Vector3, scale_factor: float) -> void:
	var tree: Node3D = Node3D.new()
	tree.name = tree_name
	tree.position = pos
	tree.scale = Vector3.ONE * scale_factor
	parent_node.add_child(tree)
	_add_box(tree, "Trunk", Vector3(0.42, 3.6, 0.42), Vector3(0.0, 1.8, 0.0), "bark", Vector3(2.0, 0.0, -3.0))
	_add_box(tree, "Branch1", Vector3(0.22, 1.9, 0.22), Vector3(-0.65, 3.4, 0.15), "bark", Vector3(0.0, 0.0, 42.0), false)
	_add_box(tree, "Branch2", Vector3(0.2, 1.7, 0.2), Vector3(0.6, 3.7, -0.2), "bark", Vector3(-18.0, 0.0, -38.0), false)
	_add_box(tree, "Branch3", Vector3(0.16, 1.4, 0.16), Vector3(0.1, 4.1, 0.5), "bark", Vector3(36.0, 0.0, 10.0), false)


func _build_distant_horizon_tower() -> void:
	var horizon: Node3D = _create_group("HorizonSkyline")
	# Torre Central ("Espelho da Alma Partida") no horizonte norte
	var tower: Node3D = Node3D.new()
	tower.name = "CentralTower"
	tower.position = Vector3(14.0, 0.0, -78.0)
	horizon.add_child(tower)
	_add_box(tower, "TowerBase", Vector3(14.0, 16.0, 14.0), Vector3(0.0, 8.0, 0.0), "skyline", Vector3.ZERO, false)
	_add_box(tower, "TowerShaft", Vector3(10.5, 40.0, 10.5), Vector3(0.0, 36.0, 0.0), "skyline", Vector3.ZERO, false)
	_add_box(tower, "RitualPillarL", Vector3(1.8, 9.0, 2.2), Vector3(-3.6, 60.5, 0.0), "skyline", Vector3.ZERO, false)
	_add_box(tower, "RitualPillarR", Vector3(1.8, 9.0, 2.2), Vector3(3.6, 60.5, 0.0), "skyline", Vector3.ZERO, false)
	_add_box(tower, "BrokenMirrorAltar", Vector3(4.2, 5.2, 0.6), Vector3(0.0, 59.5, 0.0), "tower_altar", Vector3(0.0, 0.0, 6.0), false)

	# Silhuetas de outros prédios distantes formando a cidade morta
	var buildings: Array[Dictionary] = [
		{"pos": Vector3(-38.0, 0.0, -84.0), "size": Vector3(12.0, 34.0, 12.0)},
		{"pos": Vector3(-16.0, 0.0, -88.0), "size": Vector3(10.0, 26.0, 10.0)},
		{"pos": Vector3(36.0, 0.0, -82.0), "size": Vector3(13.0, 30.0, 11.0)},
		{"pos": Vector3(56.0, 0.0, -90.0), "size": Vector3(14.0, 22.0, 12.0)},
	]
	for idx: int in range(buildings.size()):
		var b: Dictionary = buildings[idx]
		var s: Vector3 = b["size"] as Vector3
		var p: Vector3 = b["pos"] as Vector3
		_add_box(horizon, "CitySkyline_%d" % idx, s, p + Vector3(0.0, s.y * 0.5, 0.0), "skyline", Vector3.ZERO, false)
