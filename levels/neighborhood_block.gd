@tool
extends Node3D
## Quarteirão Completo da Demo:
## - Rua principal, calçadas, muros perimetrais, carro abandonado e ponto de ônibus com cobertura;
## - Mini-Mercado "Sol Nascente" 100% explorável (balcão, depósito trancado e armário);
## - Porão da Casa conectado por túnel subterrâneo ao Mini-Mercado (tomado por Sombras Vivas);
## - Pracinha do Culto a Leste com altar improvisado e bancos;
## - Torre Central ("Espelho da Alma Partida") no horizonte norte.

const LAYER_ENVIRONMENT: int = 1
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")
const _DoorScript := preload("res://systems/interactables/door_interactable.gd")
const _WardrobeScript := preload("res://systems/interactables/wardrobe_hide.gd")

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
	_build_explorable_market()
	_build_basement_and_tunnel()
	_build_neighbor_buildings()
	_build_cult_plaza()
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
	_materials["asphalt"] = _make_mat(Color(0.24, 0.23, 0.25), _textures["asphalt"] as Texture2D, Vector2(14.0, 2.0))
	_materials["road_stripe"] = _make_mat(Color(0.76, 0.62, 0.22), _textures["concrete"] as Texture2D, Vector2(1.0, 1.0))
	_materials["sidewalk"] = _make_mat(Color(0.56, 0.54, 0.50), _textures["sidewalk"] as Texture2D, Vector2(10.0, 1.0))
	_materials["plaza_stone"] = _make_mat(Color(0.32, 0.31, 0.30), _textures["sidewalk"] as Texture2D, Vector2(8.0, 12.0))
	_materials["dirt_grass"] = _make_mat(Color(0.28, 0.27, 0.26), _textures["sidewalk"] as Texture2D, Vector2(10.0, 10.0))
	_materials["alley_stone"] = _make_mat(Color(0.24, 0.23, 0.22), _textures["asphalt"] as Texture2D, Vector2(6.0, 8.0))
	_materials["sobrado_brick"] = _make_mat(Color(0.48, 0.34, 0.27), _textures["facade_brick"] as Texture2D, Vector2(4.0, 4.0))
	_materials["sobrado_dark"] = _make_mat(Color(0.33, 0.31, 0.29), _textures["concrete"] as Texture2D, Vector2(3.0, 4.0))
	_materials["window_black"] = _make_mat(Color(0.06, 0.06, 0.08))
	_materials["concrete"] = _make_mat(Color(0.52, 0.50, 0.46), _textures["concrete"] as Texture2D, Vector2(4.0, 2.0))
	_materials["concrete_dark"] = _make_mat(Color(0.32, 0.31, 0.30), _textures["concrete"] as Texture2D, Vector2(3.0, 2.0))
	_materials["basement_wall"] = _make_mat(Color(0.28, 0.29, 0.31), _textures["concrete"] as Texture2D, Vector2(4.0, 2.0))
	_materials["wall_brick"] = _make_mat(Color(0.58, 0.46, 0.39), _textures["facade_brick"] as Texture2D, Vector2(5.0, 2.5))
	_materials["market_tile"] = _make_mat(Color(0.68, 0.67, 0.63), _textures["sidewalk"] as Texture2D, Vector2(5.0, 5.0))
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
			var v: float = clampf(0.80 + rng.randf_range(-0.16, 0.12), 0.48, 1.0)
			if (x + y * 3) % 41 == 0 or (absi((x * 2 - y) % 53) <= 1 and (x + y) % 5 < 3):
				v *= 0.56
			img.set_pixel(x, y, Color(v, v * 0.99, v * 0.97, 1.0))
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
		var soot: float = 0.60 + 0.40 * clampf(float(64 - y) / 26.0, 0.0, 1.0)
		for x: int in range(64):
			var mv: bool = ((x + shift) % 16) == 0
			var v: float = 0.50 if (mh or mv) else clampf(0.88 + rng.randf_range(-0.10, 0.08), 0.52, 1.0)
			v *= soot
			img.set_pixel(x, y, Color(v, v * 0.93, v * 0.89, 1.0))
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


# --------------------------------------------------------------------------- Construtores

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
	m.subdivide_width = clampi(int(size.x / 2.0), 0, 10)
	m.subdivide_height = clampi(int(size.y / 2.0), 0, 6)
	m.subdivide_depth = clampi(int(size.z / 2.0), 0, 10)
	_mesh_cache[size] = m
	return m


func _get_box_shape(size: Vector3) -> BoxShape3D:
	if _shape_cache.has(size):
		return _shape_cache[size] as BoxShape3D
	var s: BoxShape3D = BoxShape3D.new()
	s.size = size
	_shape_cache[size] = s
	return s


func _add_door_node(
	parent_node: Node3D,
	door_name: String,
	pivot_pos: Vector3,
	door_width: float,
	door_height: float,
	along_x: bool,
	is_locked: bool = false,
	req_key: String = "",
	key_label: String = ""
) -> void:
	var door_pivot: Node3D = Node3D.new()
	door_pivot.name = door_name
	door_pivot.set_script(_DoorScript)
	door_pivot.position = pivot_pos
	door_pivot.set("is_locked", is_locked)
	door_pivot.set("required_key_id", req_key)
	door_pivot.set("key_display_name", key_label)
	parent_node.add_child(door_pivot)

	var leaf: StaticBody3D = StaticBody3D.new()
	leaf.name = "DoorLeaf"
	leaf.collision_layer = (1 << 0) | (1 << 3)
	leaf.collision_mask = 0
	var leaf_size: Vector3 = Vector3(door_width - 0.06, door_height - 0.04, 0.08) if along_x else Vector3(0.08, door_height - 0.04, door_width - 0.06)
	leaf.position = Vector3(door_width * 0.5, door_height * 0.5, 0.0) if along_x else Vector3(0.0, door_height * 0.5, door_width * 0.5)
	door_pivot.add_child(leaf)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.mesh = _get_box_mesh(leaf_size)
	mesh_inst.material_override = _materials["wood_old"] as Material
	leaf.add_child(mesh_inst)

	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = _get_box_shape(leaf_size)
	leaf.add_child(col)


func _add_wardrobe_node(parent_node: Node3D, w_name: String, size: Vector3, pos: Vector3, hide_off: Vector3, exit_off: Vector3) -> void:
	var wardrobe: StaticBody3D = StaticBody3D.new()
	wardrobe.name = w_name
	wardrobe.set_script(_WardrobeScript)
	wardrobe.position = pos
	wardrobe.set("hide_offset", hide_off)
	wardrobe.set("exit_offset", exit_off)
	wardrobe.collision_layer = (1 << 0) | (1 << 3)
	wardrobe.collision_mask = 0
	parent_node.add_child(wardrobe)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.mesh = _get_box_mesh(size)
	mesh_inst.material_override = _materials["metal_dark"] as Material
	wardrobe.add_child(mesh_inst)

	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = _get_box_shape(size)
	wardrobe.add_child(col)


# --------------------------------------------------------------------------- Chão & Muros

func _build_ground_and_street() -> void:
	var g: Node3D = _create_group("StreetAndLots")
	# Rua principal estendida até a Pracinha Leste (X: -26..+36, Z: 10.6..15.2)
	_add_box(g, "MainRoadAsphalt", Vector3(62.0, 0.1, 4.6), Vector3(5.0, -0.05, 12.9), "asphalt")
	for i: int in range(-4, 7):
		_add_box(g, "RoadStripe_%d" % (i + 4), Vector3(2.8, 0.02, 0.16), Vector3(float(i) * 5.4, 0.005, 12.9), "road_stripe", Vector3.ZERO, false)

	# Rua Transversal Norte (X: -26..+36, Z: -19.5..-15.5) ligando os becos e a Avenida da Escola
	_add_box(g, "NorthCrossRoadAsphalt", Vector3(62.0, 0.02, 4.0), Vector3(5.0, 0.004, -17.5), "asphalt", Vector3.ZERO, false)
	for j: int in range(-4, 6):
		_add_box(g, "NorthStripe_%d" % (j + 4), Vector3(2.4, 0.02, 0.14), Vector3(float(j) * 5.6, 0.008, -17.5), "road_stripe", Vector3.ZERO, false)

	# Pisos de paralelepípedo escuro nos becos estreitos (sem colisão extra para não alterar altura do chão)
	_add_box(g, "AlleyPave_Market", Vector3(2.8, 0.02, 16.5), Vector3(-16.0, 0.004, -0.5), "alley_stone", Vector3.ZERO, false)
	_add_box(g, "AlleyPave_HouseWest", Vector3(2.7, 0.02, 16.5), Vector3(-9.45, 0.004, -0.5), "alley_stone", Vector3.ZERO, false)
	_add_box(g, "AlleyPave_HouseEast", Vector3(2.7, 0.02, 16.5), Vector3(9.45, 0.004, -0.5), "alley_stone", Vector3.ZERO, false)
	_add_box(g, "AlleyPave_NeighborWest", Vector3(2.8, 0.02, 16.5), Vector3(16.0, 0.004, -0.5), "alley_stone", Vector3.ZERO, false)
	_add_box(g, "AlleyPave_BackLane", Vector3(50.0, 0.02, 3.0), Vector3(0.0, 0.004, -8.7), "alley_stone", Vector3.ZERO, false)
	_add_box(g, "AlleyPave_SouthWest", Vector3(3.0, 0.02, 6.8), Vector3(-17.0, 0.004, 19.3), "alley_stone", Vector3.ZERO, false)
	_add_box(g, "AlleyPave_SouthEast", Vector3(3.0, 0.02, 6.8), Vector3(16.0, 0.004, 19.3), "alley_stone", Vector3.ZERO, false)

	# Calçadas Norte e Sul
	_add_box(g, "SidewalkNorth", Vector3(62.0, 0.12, 1.0), Vector3(5.0, -0.04, 10.1), "sidewalk")
	_add_box(g, "SidewalkSouthWest", Vector3(23.0, 0.12, 1.0), Vector3(-14.5, -0.04, 15.7), "sidewalk")
	_add_box(g, "SidewalkSouthEast", Vector3(33.0, 0.12, 1.0), Vector3(19.5, -0.04, 15.7), "sidewalk")

	# Lotes pavimentados Oeste (contorna o Mini-Mercado X:-25.5..-17.5, Z:-7.5..+7.0 para preservar o poço da rampa!)
	_add_box(g, "YardWest_NorthStrip", Vector3(18.0, 0.1, 12.5), Vector3(-17.0, -0.05, -13.75), "dirt_grass")
	_add_box(g, "YardWest_Alley", Vector3(9.5, 0.1, 17.1), Vector3(-12.75, -0.05, 1.05), "dirt_grass")
	_add_box(g, "YardWest_MarketFront", Vector3(8.5, 0.1, 2.6), Vector3(-21.75, -0.05, 8.3), "dirt_grass")
	_add_box(g, "YardWest_Edge", Vector3(0.5, 0.1, 14.5), Vector3(-25.75, -0.05, -0.25), "dirt_grass")

	# Lotes pavimentados Leste entre Casa e Pracinha (X: +8..+25.5, Z: -20..+9.6)
	_add_box(g, "YardEast", Vector3(17.5, 0.1, 29.6), Vector3(16.75, -0.05, -5.2), "dirt_grass")

	# Fundo Norte da Casa recortado ao redor do poço da rampa do Porão (vão em X:-1.3..+1.3, Z:-13.0..-7.0)
	_add_box(g, "YardBack_West", Vector3(6.7, 0.1, 13.0), Vector3(-4.65, -0.05, -13.5), "dirt_grass")
	_add_box(g, "YardBack_East", Vector3(6.7, 0.1, 13.0), Vector3(4.65, -0.05, -13.5), "dirt_grass")
	_add_box(g, "YardBack_FarNorth", Vector3(2.6, 0.1, 7.0), Vector3(0.0, -0.05, -16.5), "dirt_grass")

	# Calçamento frontal ladeando a varanda
	_add_box(g, "FrontLawnLeft", Vector3(5.0, 0.1, 2.6), Vector3(-5.5, -0.05, 8.3), "dirt_grass")
	_add_box(g, "FrontLawnRight", Vector3(5.0, 0.1, 2.6), Vector3(5.5, -0.05, 8.3), "dirt_grass")


func _build_perimeter_walls() -> void:
	var walls: Node3D = _create_group("PerimeterWalls")
	# Fachadas de prédios e bloqueios urbanos na Rua Transversal Norte (vão central livre X: -2.1..+2.1 para a Avenida da Escola)
	_add_box(walls, "NorthBlockadeBldgW", Vector3(13.5, 9.6, 2.8), Vector3(-19.25, 4.8, -21.2), "sobrado_brick")
	_add_box(walls, "NorthBlockadeBldgW_Trim", Vector3(13.8, 0.4, 3.0), Vector3(-19.25, 9.6, -21.2), "concrete_dark")
	_add_box(walls, "NorthBlockadeBldgE", Vector3(23.5, 10.2, 2.8), Vector3(24.25, 5.1, -21.2), "sobrado_dark")
	_add_box(walls, "NorthBlockadeBldgE_Trim", Vector3(23.8, 0.4, 3.0), Vector3(24.25, 10.2, -21.2), "concrete_dark")
	# Barricadas de quarentena ladeando o portão da Avenida da Escola
	_add_box(walls, "NorthQuarantineWallW", Vector3(9.0, 3.4, 0.6), Vector3(-8.0, 1.7, -20.0), "wall_brick")
	_add_box(walls, "NorthQuarantineWallE", Vector3(9.0, 3.4, 0.6), Vector3(8.0, 1.7, -20.0), "wall_brick")
	_add_box(walls, "SchoolGatePillarW", Vector3(1.4, 4.2, 0.9), Vector3(-2.8, 2.1, -20.0), "concrete_dark")
	_add_box(walls, "SchoolGatePillarE", Vector3(1.4, 4.2, 0.9), Vector3(2.8, 2.1, -20.0), "concrete_dark")
	_add_box(walls, "SchoolGateArchBeam", Vector3(7.0, 0.8, 0.9), Vector3(0.0, 4.4, -20.0), "concrete_dark")

	# Sobrado Norte da Pracinha (fecha o canto NE com arquitetura urbana em vez de muro liso)
	_add_box(walls, "PlazaTownhouseN", Vector3(10.2, 9.2, 4.0), Vector3(30.6, 4.6, -16.5), "sobrado_brick")
	_add_box(walls, "PlazaTownhouseN_Cornice", Vector3(10.5, 0.35, 4.3), Vector3(30.6, 9.2, -16.5), "concrete_dark")

	# Divisa Oeste com o Quarteirão do Posto: aberta na Rua Principal (Z: +9.6..+16.2) e na Rua Transversal Norte (Z: -19.8..-15.2)
	_add_box(walls, "WestBoundaryTenement", Vector3(1.4, 8.8, 24.4), Vector3(-26.0, 4.4, -2.8), "sobrado_dark")
	_add_box(walls, "WestBoundarySouthShop", Vector3(1.4, 8.4, 8.8), Vector3(-26.0, 4.2, 20.6), "sobrado_brick")

	# Divisa Leste com o Cemitério/Capela: arco de passagem urbana na Pracinha (Z: -2.0..+4.0) + Rua Principal aberta
	_add_box(walls, "EastBoundaryNorthBldg", Vector3(1.8, 9.0, 17.6), Vector3(36.0, 4.5, -10.8), "sobrado_dark")
	_add_box(walls, "EastBoundaryMidPillar", Vector3(1.6, 4.6, 5.4), Vector3(36.0, 2.3, 6.7), "wall_brick")
	_add_box(walls, "EastBoundaryArchTop", Vector3(1.6, 3.8, 6.4), Vector3(36.0, 6.5, 1.0), "sobrado_brick")
	_add_box(walls, "EastBoundarySouthShop", Vector3(1.6, 8.6, 8.8), Vector3(36.0, 4.3, 20.6), "sobrado_brick")

	# Fundo dos Becos Sul sem saída (Z = 22.8) e fachadas contínuas nos trechos sem beco
	_add_box(walls, "AlleySouthWest_BackWall", Vector3(3.6, 8.5, 0.6), Vector3(-17.0, 4.25, 22.8), "sobrado_dark")
	_add_box(walls, "AlleySouthEast_BackWall", Vector3(3.6, 8.5, 0.6), Vector3(16.0, 4.25, 22.8), "sobrado_dark")


# --------------------------------------------------------------------------- Mini-Mercado Explorável

func _build_explorable_market() -> void:
	var mkt: Node3D = _create_group("MiniMarketExploravel")

	# Piso interno recortado deixando o poço da rampa em X:-24.8..-21.8, Z:-5.5..+0.5
	_add_box(mkt, "MarketFloorFront", Vector3(8.0, 0.1, 6.5), Vector3(-21.5, -0.05, 3.75), "market_tile")
	_add_box(mkt, "MarketFloorBackRight", Vector3(4.3, 0.1, 8.0), Vector3(-19.65, -0.05, -3.5), "market_tile")
	_add_box(mkt, "MarketFloorBackTop", Vector3(3.7, 0.1, 2.0), Vector3(-23.65, -0.05, -6.5), "market_tile")
	_add_box(mkt, "MarketFloorStairEdge", Vector3(0.7, 0.1, 6.0), Vector3(-25.15, -0.05, -2.5), "market_tile")

	# Teto, platibanda, letreiro e toldo frontal
	_add_box(mkt, "MarketRoof", Vector3(8.3, 0.25, 14.8), Vector3(-21.5, 4.6, -0.25), "roof_dark")
	_add_box(mkt, "MarketParapet", Vector3(8.2, 0.85, 0.35), Vector3(-21.5, 5.1, 7.0), "concrete")
	_add_box(mkt, "MarketSignBoard", Vector3(5.6, 0.85, 0.16), Vector3(-21.5, 3.9, 7.18), "wood_old")
	_add_box(mkt, "MarketAwning", Vector3(7.4, 0.16, 2.8), Vector3(-21.2, 2.9, 8.4), "awning", Vector3(8.0, 0.0, 0.0))
	_add_box(mkt, "AwningPostL", Vector3(0.14, 2.8, 0.14), Vector3(-24.6, 1.4, 9.5), "metal_dark")
	_add_box(mkt, "AwningPostR", Vector3(0.14, 2.8, 0.14), Vector3(-17.8, 1.4, 9.5), "metal_dark")

	# Paredes Oeste e Norte
	_add_box(mkt, "MarketWallWest", Vector3(0.25, 4.6, 14.5), Vector3(-25.5, 2.3, -0.25), "wall_brick")
	_add_box(mkt, "MarketWallNorth", Vector3(8.0, 4.6, 0.25), Vector3(-21.5, 2.3, -7.5), "wall_brick")

	# Parede Sul com Porta Frontal em X = -21.5 (largura 1.6m, altura 2.4m)
	_add_box(mkt, "MarketWallSouthL", Vector3(3.2, 4.6, 0.25), Vector3(-23.9, 2.3, 7.0), "wall_brick")
	_add_box(mkt, "MarketWallSouthR", Vector3(3.2, 4.6, 0.25), Vector3(-19.1, 2.3, 7.0), "wall_brick")
	_add_box(mkt, "MarketWallSouthTop", Vector3(1.6, 2.2, 0.25), Vector3(-21.5, 3.5, 7.0), "wall_brick")
	_add_door_node(mkt, "MarketFrontDoor", Vector3(-22.3, 0.0, 7.0), 1.6, 2.4, true, false)

	# Parede Leste com Porta Traseira Trancada em Z = -4.0 (largura 1.4m, altura 2.3m)
	_add_box(mkt, "MarketWallEastS", Vector3(0.25, 4.6, 10.3), Vector3(-17.5, 2.3, 1.85), "wall_brick")
	_add_box(mkt, "MarketWallEastN", Vector3(0.25, 4.6, 2.8), Vector3(-17.5, 2.3, -6.1), "wall_brick")
	_add_box(mkt, "MarketWallEastTop", Vector3(0.25, 2.3, 1.4), Vector3(-17.5, 3.45, -4.0), "wall_brick")
	_add_door_node(
		mkt,
		"MarketBackDoor",
		Vector3(-17.5, 0.0, -4.7),
		1.4,
		2.3,
		false,
		true,
		"market_back_key",
		"Chave dos Fundos do Mercado"
	)

	# Divisória do depósito interno (com passagem aberta em X: -20.2..-18.6)
	_add_box(mkt, "StorageDividerL", Vector3(1.6, 3.8, 0.2), Vector3(-21.0, 1.9, -2.5), "concrete_dark")
	_add_box(mkt, "StorageDividerR", Vector3(1.1, 3.8, 0.2), Vector3(-18.05, 1.9, -2.5), "concrete_dark")

	# Móveis internos do mercado
	_add_box(mkt, "CheckoutCounter", Vector3(2.4, 0.9, 0.7), Vector3(-19.5, 0.45, 2.8), "wood_old")
	_add_box(mkt, "StoreShelf1", Vector3(0.7, 1.8, 3.0), Vector3(-23.2, 0.9, 3.2), "wood_old")
	_add_box(mkt, "FallenShelf", Vector3(1.6, 0.65, 0.8), Vector3(-20.2, 0.33, -0.4), "wood_old", Vector3(0.0, 22.0, 0.0))
	_add_wardrobe_node(mkt, "MarketLocker", Vector3(0.7, 2.0, 1.3), Vector3(-18.2, 1.0, -6.2), Vector3(0.0, -1.0, 0.0), Vector3(-1.1, -1.0, 0.0))

	# Luz fraca de vitrine no mercado frontal (o depósito nos fundos permanece escuro)
	var m_light: OmniLight3D = OmniLight3D.new()
	m_light.position = Vector3(-21.5, 3.8, 3.2)
	m_light.light_color = Color(0.72, 0.76, 0.84)
	m_light.light_energy = 0.24
	m_light.omni_range = 7.0
	m_light.shadow_enabled = false
	m_light.distance_fade_enabled = true
	m_light.distance_fade_begin = 20.0
	mkt.add_child(m_light)

	# Caixotes do lado de fora no beco
	_add_box(mkt, "AlleyCrateStack", Vector3(1.2, 1.1, 1.2), Vector3(-16.8, 0.55, 5.2), "wood_old")
	_add_box(mkt, "AlleyCrateTop", Vector3(0.8, 0.75, 0.8), Vector3(-16.7, 1.48, 5.1), "wood_old", Vector3(0.0, 18.0, 0.0))


# --------------------------------------------------------------------------- Porão & Túnel Subterrâneo

func _build_basement_and_tunnel() -> void:
	var bsm: Node3D = _create_group("BasementAndTunnel")

	# 1. Abrigo e porta trancada no quintal norte da casa (X: -1.4..+1.4, Z: -13.2..-7.0)
	_add_box(bsm, "CellarHoodWallW", Vector3(0.2, 2.4, 6.2), Vector3(-1.4, 1.2, -10.1), "concrete_dark")
	_add_box(bsm, "CellarHoodWallE", Vector3(0.2, 2.4, 6.2), Vector3(1.4, 1.2, -10.1), "concrete_dark")
	_add_box(bsm, "CellarHoodRoof", Vector3(3.1, 0.2, 6.4), Vector3(0.0, 2.45, -10.1), "roof_dark")
	_add_box(bsm, "CellarDoorSideL", Vector3(0.65, 2.4, 0.22), Vector3(-1.02, 1.2, -13.2), "concrete_dark")
	_add_box(bsm, "CellarDoorSideR", Vector3(0.65, 2.4, 0.22), Vector3(1.02, 1.2, -13.2), "concrete_dark")
	_add_door_node(
		bsm,
		"BasementDoor",
		Vector3(-0.7, 0.0, -13.2),
		1.4,
		2.3,
		true,
		true,
		"basement_key",
		"Chave do Porão"
	)

	# Paredes laterais do fosso da rampa (Y: -3.2..0.0) e rampa descendente (+30.65° no eixo X)
	_add_box(bsm, "NorthPitWallW", Vector3(0.25, 3.2, 6.0), Vector3(-1.35, -1.6, -10.2), "basement_wall")
	_add_box(bsm, "NorthPitWallE", Vector3(0.25, 3.2, 6.0), Vector3(1.35, -1.6, -10.2), "basement_wall")
	_add_box(bsm, "NorthPitHeadwall", Vector3(2.8, 3.2, 0.25), Vector3(0.0, -1.6, -13.2), "basement_wall")
	_add_box(bsm, "BasementEntryRamp", Vector3(2.45, 0.2, 6.4), Vector3(0.0, -1.65, -9.9), "concrete_dark", Vector3(30.65, 0.0, 0.0))

	# 2. Salão do Porão sob a casa (X: -8.0..+4.0, Z: -7.2..+1.0, chão em Y = -3.2)
	_add_box(bsm, "BasementFloor", Vector3(12.2, 0.2, 8.4), Vector3(-2.0, -3.3, -3.1), "basement_wall")
	_add_box(bsm, "BasementCeiling", Vector3(12.2, 0.2, 8.4), Vector3(-2.0, -0.35, -3.1), "basement_wall")
	_add_box(bsm, "BasementWallSouth", Vector3(12.2, 3.1, 0.25), Vector3(-2.0, -1.8, 1.1), "basement_wall")
	_add_box(bsm, "BasementWallEast", Vector3(0.25, 3.1, 8.4), Vector3(4.1, -1.8, -3.1), "basement_wall")
	# Parede Norte com abertura para a rampa (X: -1.25..+1.25)
	_add_box(bsm, "BasementWallNorthW", Vector3(6.8, 3.1, 0.25), Vector3(-4.65, -1.8, -7.2), "basement_wall")
	_add_box(bsm, "BasementWallNorthE", Vector3(2.8, 3.1, 0.25), Vector3(2.7, -1.8, -7.2), "basement_wall")
	# Parede Oeste com abertura para o Túnel Subterrâneo (Z: -6.8..-3.8)
	_add_box(bsm, "BasementWallWestS", Vector3(0.25, 3.1, 4.9), Vector3(-8.0, -1.8, -1.35), "basement_wall")
	# Pilares, caldeira e estantes do porão
	_add_box(bsm, "BasementPillar1", Vector3(0.55, 3.0, 0.55), Vector3(-4.5, -1.8, -1.5), "concrete_dark")
	_add_box(bsm, "OldBoiler", Vector3(1.6, 2.0, 1.3), Vector3(2.4, -2.2, -1.4), "metal_dark")
	_add_box(bsm, "CellarShelf", Vector3(0.65, 1.8, 2.4), Vector3(-6.8, -2.3, -0.5), "wood_old")

	# 3. Túnel Subterrâneo (X: -24.8..-8.0, Z: -6.8..-3.8, Y = -3.2)
	_add_box(bsm, "TunnelFloor", Vector3(16.8, 0.2, 3.2), Vector3(-16.4, -3.3, -5.3), "basement_wall")
	_add_box(bsm, "TunnelCeiling", Vector3(16.8, 0.2, 3.2), Vector3(-16.4, -0.35, -5.3), "basement_wall")
	_add_box(bsm, "TunnelWallNorth", Vector3(16.8, 3.1, 0.25), Vector3(-16.4, -1.8, -6.8), "basement_wall")
	_add_box(bsm, "TunnelWallSouth", Vector3(14.0, 3.1, 0.25), Vector3(-14.9, -1.8, -3.8), "basement_wall")

	# 4. Poço e Rampa Oeste saindo dentro do Mini-Mercado (abertura em Z: -6.8..-3.8 liga ao Esgoto Oeste)
	_add_box(bsm, "MarketPitWallW_South", Vector3(0.25, 3.4, 4.4), Vector3(-24.8, -1.65, -1.6), "basement_wall")
	_add_box(bsm, "MarketPitWallE", Vector3(0.25, 3.4, 4.4), Vector3(-21.8, -1.65, -1.6), "basement_wall")
	_add_box(bsm, "MarketPitSouthCap", Vector3(3.1, 3.4, 0.25), Vector3(-23.3, -1.65, 0.55), "basement_wall")
	_add_box(bsm, "MarketExitRamp", Vector3(2.75, 0.2, 6.0), Vector3(-23.3, -1.65, -2.0), "concrete_dark", Vector3(-32.6, 0.0, 0.0))


# --------------------------------------------------------------------------- Outras Fachadas & Pracinha do Culto

func _build_neighbor_buildings() -> void:
	var bldgs: Node3D = _create_group("NeighborBuildings")

	# Casa Vizinha Semi-Explorável (Leste, X: +17.5..+25.5, Z: -7.0..+7.5)
	var neighbor: Node3D = Node3D.new()
	neighbor.name = "NeighborHouse"
	bldgs.add_child(neighbor)
	_add_box(neighbor, "NeighborFloor", Vector3(7.6, 0.06, 14.2), Vector3(21.5, 0.03, 0.25), "wood_old")
	_add_box(neighbor, "NeighborUpperMass", Vector3(8.0, 3.2, 14.5), Vector3(21.5, 4.8, 0.25), "neighbor_stucco")
	_add_box(neighbor, "NeighborRoof", Vector3(8.6, 0.45, 15.1), Vector3(21.5, 6.42, 0.25), "roof_dark")
	_add_box(neighbor, "NeighborWallW", Vector3(0.25, 3.2, 14.5), Vector3(17.62, 1.6, 0.25), "neighbor_stucco")
	_add_box(neighbor, "NeighborWallE", Vector3(0.25, 3.2, 14.5), Vector3(25.38, 1.6, 0.25), "neighbor_stucco")
	_add_box(neighbor, "NeighborWallN", Vector3(8.0, 3.2, 0.25), Vector3(21.5, 1.6, -6.88), "neighbor_stucco")
	# Fachada Sul com vão de porta em X=20.5 (largura 1.6m) e janela lateral em X=23.3
	_add_box(neighbor, "NeighborFrontW", Vector3(2.2, 3.2, 0.25), Vector3(18.6, 1.6, 7.38), "neighbor_stucco")
	_add_box(neighbor, "NeighborDoorTop", Vector3(1.6, 0.8, 0.25), Vector3(20.5, 2.8, 7.38), "neighbor_stucco")
	_add_box(neighbor, "NeighborFrontMid", Vector3(1.2, 3.2, 0.25), Vector3(21.9, 1.6, 7.38), "neighbor_stucco")
	_add_box(neighbor, "NeighborWinSill", Vector3(1.6, 1.05, 0.25), Vector3(23.3, 0.52, 7.38), "neighbor_stucco")
	_add_box(neighbor, "NeighborWinTop", Vector3(1.6, 1.0, 0.25), Vector3(23.3, 2.7, 7.38), "neighbor_stucco")
	_add_box(neighbor, "NeighborFrontE", Vector3(1.4, 3.2, 0.25), Vector3(24.8, 1.6, 7.38), "neighbor_stucco")
	_add_box(neighbor, "NeighborTable", Vector3(1.8, 0.78, 0.9), Vector3(23.6, 0.42, 1.0), "wood_old")
	_add_box(neighbor, "NeighborPorchRoof", Vector3(4.0, 0.22, 2.2), Vector3(20.5, 3.2, 8.6), "roof_dark")
	_add_box(neighbor, "NeighborBoardWin2", Vector3(1.8, 1.3, 0.12), Vector3(20.5, 4.6, 7.56), "wood_old")
	_add_box(neighbor, "NeighborLowWallW", Vector3(1.9, 0.95, 0.25), Vector3(18.65, 0.48, 9.4), "concrete_dark")
	_add_box(neighbor, "NeighborLowWallE", Vector3(3.9, 0.95, 0.25), Vector3(23.35, 0.48, 9.4), "concrete_dark")

	# Quarteirão Sul contínuo (sobrados e lojas geminadas com Beco Sul Oeste X:-18.5..-15.5, Beco do Abrigo X:-3.2..+3.2 e Beco Sul Leste X:+14.5..+17.5)
	var south_row: Node3D = Node3D.new()
	south_row.name = "SouthBuildings"
	bldgs.add_child(south_row)
	_add_box(south_row, "SouthBlock_FarWest", Vector3(7.0, 9.6, 7.0), Vector3(-22.0, 4.8, 20.0), "sobrado_brick")
	_add_box(south_row, "SouthBlock_MidWest", Vector3(12.3, 11.2, 7.0), Vector3(-9.35, 5.6, 20.0), "wall_brick")
	_add_box(south_row, "SouthBlock_MidEast", Vector3(11.3, 10.4, 7.0), Vector3(8.85, 5.2, 20.0), "neighbor_stucco")
	_add_box(south_row, "SouthBlock_FarEast", Vector3(18.0, 9.8, 7.0), Vector3(26.5, 4.9, 20.0), "sobrado_brick")
	# Pontes/arcos superiores sobre as entradas dos Becos Sul (Y: 3.8..9.6)
	_add_box(south_row, "SouthAlleyW_Overpass", Vector3(3.0, 5.4, 3.5), Vector3(-17.0, 6.5, 18.4), "sobrado_dark")
	_add_box(south_row, "SouthAlleyE_Overpass", Vector3(3.0, 5.4, 3.5), Vector3(16.0, 6.5, 18.4), "sobrado_dark")

	# Sobrados Urbanos Interiores dividindo os terrenos largos em becos estreitos de 2.7m-3.0m
	# 1. Sobrado Oeste (X: -14.5..-10.9) cria Beco do Mercado (X: -17.5..-14.5) e Beco Oeste da Casa (X: -10.9..-8.0)
	var sobrado_w: Node3D = Node3D.new()
	sobrado_w.name = "SobradoOeste"
	bldgs.add_child(sobrado_w)
	_add_box(sobrado_w, "WingNorth", Vector3(3.6, 9.4, 5.7), Vector3(-12.7, 4.7, -4.15), "sobrado_brick")
	_add_box(sobrado_w, "WingSouth", Vector3(3.6, 9.4, 5.7), Vector3(-12.7, 4.7, 4.15), "sobrado_brick")
	_add_box(sobrado_w, "UpperBridge", Vector3(3.6, 6.2, 2.6), Vector3(-12.7, 6.3, 0.0), "sobrado_dark")
	_add_box(sobrado_w, "RoofLedge", Vector3(3.9, 0.35, 14.3), Vector3(-12.7, 9.4, 0.0), "concrete_dark")

	# 2. Sobrado Leste (X: +10.9..+14.5) cria Beco Leste da Casa (X: +8.0..+10.9) e Beco da Vizinha (X: +14.5..+17.5)
	var sobrado_e: Node3D = Node3D.new()
	sobrado_e.name = "SobradoLeste"
	bldgs.add_child(sobrado_e)
	_add_box(sobrado_e, "WingNorth", Vector3(3.6, 9.0, 5.7), Vector3(12.7, 4.5, -4.15), "sobrado_dark")
	_add_box(sobrado_e, "WingSouth", Vector3(3.6, 9.0, 5.7), Vector3(12.7, 4.5, 4.15), "wall_brick")
	_add_box(sobrado_e, "UpperBridge", Vector3(3.6, 5.8, 2.6), Vector3(12.7, 6.1, 0.0), "sobrado_brick")
	_add_box(sobrado_e, "RoofLedge", Vector3(3.9, 0.35, 14.3), Vector3(12.7, 9.0, 0.0), "concrete_dark")

	# 3. Cortiços Traseiros Norte (Z: -14.8..-10.4) criam a Viela Traseira (Z: -10.4..-7.0) e a Rua Transversal Norte (Z: -19.8..-14.8)
	var corticos: Node3D = Node3D.new()
	corticos.name = "CorticosNorte"
	bldgs.add_child(corticos)
	_add_box(corticos, "CorticoWest_A", Vector3(7.5, 8.8, 4.4), Vector3(-21.25, 4.4, -12.6), "sobrado_dark")
	_add_box(corticos, "CorticoWest_B", Vector3(3.8, 9.6, 4.4), Vector3(-12.8, 4.8, -12.6), "sobrado_brick")
	_add_box(corticos, "CorticoWest_Arch", Vector3(2.8, 5.4, 4.2), Vector3(-16.1, 6.5, -12.6), "wall_brick")
	_add_box(corticos, "CorticoEast_A", Vector3(3.8, 9.2, 4.4), Vector3(12.8, 4.6, -12.6), "sobrado_brick")
	_add_box(corticos, "CorticoEast_B", Vector3(7.5, 8.6, 4.4), Vector3(21.25, 4.3, -12.6), "sobrado_dark")
	_add_box(corticos, "CorticoEast_Arch", Vector3(2.8, 5.2, 4.2), Vector3(16.1, 6.4, -12.6), "wall_brick")


func _build_cult_plaza() -> void:
	var plaza: Node3D = _create_group("CultPlaza")
	# Piso de pedra da Pracinha (X: +25.5..+36.0, Z: -20.0..+9.6)
	_add_box(plaza, "PlazaStoneGround", Vector3(10.5, 0.1, 29.6), Vector3(30.75, -0.05, -5.2), "plaza_stone")

	# Bancos quebrados e mureta da praça
	_add_box(plaza, "PlazaBenchNorth", Vector3(2.2, 0.5, 0.6), Vector3(28.2, 0.25, -4.5), "wood_old")
	_add_box(plaza, "PlazaBenchSouth", Vector3(2.2, 0.5, 0.6), Vector3(33.2, 0.25, 4.8), "wood_old", Vector3(0.0, -24.0, 0.0))
	_add_box(plaza, "PlazaBenchWest", Vector3(0.6, 0.45, 2.0), Vector3(27.2, 0.23, 1.8), "wood_old", Vector3(0.0, 12.0, 0.0))

	# Altar Improvisado do Culto no centro da pracinha (30.5, 0, 0)
	_add_box(plaza, "AltarPedestal", Vector3(1.8, 0.9, 1.8), Vector3(30.5, 0.45, 0.0), "concrete_dark")
	_add_box(plaza, "AltarPillarL", Vector3(0.32, 2.4, 0.32), Vector3(29.7, 1.9, -0.7), "wood_old")
	_add_box(plaza, "AltarPillarR", Vector3(0.32, 2.4, 0.32), Vector3(31.3, 1.9, -0.7), "wood_old")
	_add_box(plaza, "AltarCrossbeam", Vector3(2.1, 0.24, 0.35), Vector3(30.5, 3.0, -0.7), "wood_old")
	_add_box(plaza, "AltarMirrorShard", Vector3(0.95, 1.4, 0.08), Vector3(30.5, 2.0, -0.6), "tower_altar", Vector3(0.0, 0.0, 7.0))
	_build_cult_sign(plaza, "PlazaTotemL", Vector3(28.5, 0.0, 7.2), -15.0)
	_build_cult_sign(plaza, "PlazaTotemR", Vector3(33.0, 0.0, -8.5), 25.0)


# --------------------------------------------------------------------------- Props da Rua & Horizonte

func _build_street_props_and_covers() -> void:
	var props: Node3D = _create_group("StreetPropsAndCovers")

	# 1. Carro Abandonado (X: -6.5, Z: 13.0)
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

	# 1B. Carro tombado perto da entrada da Pracinha (X: 22.8, Z: 13.0)
	var wreck: Node3D = Node3D.new()
	wreck.name = "WreckedVan"
	wreck.position = Vector3(22.8, 0.55, 13.0)
	wreck.rotation_degrees = Vector3(0.0, -18.0, 22.0)
	props.add_child(wreck)
	_add_box(wreck, "VanBody", Vector3(3.6, 1.35, 1.75), Vector3.ZERO, "car_rust")

	# 2. Ponto de Ônibus / Abrigo de Concreto (X: 12.5, Z: 10.35)
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

	# 3. Postes de Luz Quebrados
	var pole_positions: Array[Vector3] = [
		Vector3(-14.5, 0.0, 9.8),
		Vector3(-4.2, 0.0, 9.8),
		Vector3(5.6, 0.0, 9.8),
		Vector3(16.2, 0.0, 9.8),
		Vector3(28.0, 0.0, 9.8),
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

	# 4. Totens / Placas do Culto
	_build_cult_sign(props, "CultSign_West", Vector3(-16.2, 0.0, 11.1), 22.0)
	_build_cult_sign(props, "CultSign_East", Vector3(17.2, 0.0, 11.4), -28.0)

	# 5. Postes e Marcos Urbanos de Beco (substituindo árvores de quintal por arquitetura urbana)
	_add_box(props, "AlleyBollard_West", Vector3(0.28, 1.1, 0.28), Vector3(-11.0, 0.55, 8.8), "rust")
	_add_box(props, "AlleyBollard_East", Vector3(0.28, 1.1, 0.28), Vector3(11.0, 0.55, 8.8), "rust")


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
	var tower: Node3D = Node3D.new()
	tower.name = "CentralTower"
	tower.position = Vector3(14.0, 0.0, -125.0)
	horizon.add_child(tower)
	_add_box(tower, "TowerBase", Vector3(14.0, 16.0, 14.0), Vector3(0.0, 8.0, 0.0), "skyline", Vector3.ZERO, false)
	_add_box(tower, "TowerShaft", Vector3(10.5, 40.0, 10.5), Vector3(0.0, 36.0, 0.0), "skyline", Vector3.ZERO, false)
	_add_box(tower, "RitualPillarL", Vector3(1.8, 9.0, 2.2), Vector3(-3.6, 60.5, 0.0), "skyline", Vector3.ZERO, false)
	_add_box(tower, "RitualPillarR", Vector3(1.8, 9.0, 2.2), Vector3(3.6, 60.5, 0.0), "skyline", Vector3.ZERO, false)
	_add_box(tower, "BrokenMirrorAltar", Vector3(4.2, 5.2, 0.6), Vector3(0.0, 59.5, 0.0), "tower_altar", Vector3(0.0, 0.0, 6.0), false)

	var buildings: Array[Dictionary] = [
		{"pos": Vector3(-54.0, 0.0, -132.0), "size": Vector3(12.0, 34.0, 12.0)},
		{"pos": Vector3(-22.0, 0.0, -138.0), "size": Vector3(10.0, 26.0, 10.0)},
		{"pos": Vector3(42.0, 0.0, -130.0), "size": Vector3(13.0, 30.0, 11.0)},
		{"pos": Vector3(68.0, 0.0, -140.0), "size": Vector3(14.0, 22.0, 12.0)},
	]
	for idx: int in range(buildings.size()):
		var b: Dictionary = buildings[idx]
		var s: Vector3 = b["size"] as Vector3
		var p: Vector3 = b["pos"] as Vector3
		_add_box(horizon, "CitySkyline_%d" % idx, s, p + Vector3(0.0, s.y * 0.5, 0.0), "skyline", Vector3.ZERO, false)
