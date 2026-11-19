@tool
class_name TwoStoryHouse
extends Node3D
## Casa de dois andares completa e mobiliada (1º e 2º andar com todos os cômodos e colisão na Layer 1).

const LAYER_ENVIRONMENT: int = 1
const _DoorScript := preload("res://systems/interactables/door_interactable.gd")
const _WardrobeScript := preload("res://systems/interactables/wardrobe_hide.gd")

var _materials: Dictionary = {}
var _textures: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _shape_cache: Dictionary = {}
var _psx_shader: Shader = null


func _ready() -> void:
	rebuild_house()


func rebuild_house() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()

	_init_textures()
	_init_materials()
	_mesh_cache.clear()
	_shape_cache.clear()

	var structure_root: Node3D = _create_group("Structure", self)
	var floor1_root: Node3D = _create_group("Floor1_Ground", self)
	var floor2_root: Node3D = _create_group("Floor2_Upper", self)

	_build_structure(structure_root)
	_build_ground_floor_furniture(floor1_root)
	_build_upper_floor_furniture(floor2_root)


func _init_textures() -> void:
	_textures.clear()
	_textures["wood"] = _make_wood_texture()
	_textures["tile"] = _make_tile_texture()
	_textures["wallpaper"] = _make_wallpaper_texture()
	_textures["brick"] = _make_brick_texture()
	_textures["fabric"] = _make_fabric_texture()


func _init_materials() -> void:
	_materials.clear()
	_materials["floor_wood"] = _make_mat(Color(0.55, 0.40, 0.27), _textures["wood"] as Texture2D, Vector2(6.0, 6.0))
	_materials["floor_tile"] = _make_mat(Color(0.76, 0.75, 0.71), _textures["tile"] as Texture2D, Vector2(5.0, 5.0))
	_materials["wall_ext"] = _make_mat(Color(0.66, 0.62, 0.56), _textures["brick"] as Texture2D, Vector2(4.0, 2.0))
	_materials["wall_int"] = _make_mat(Color(0.80, 0.77, 0.71), _textures["wallpaper"] as Texture2D, Vector2(3.0, 1.5))
	_materials["roof"] = _make_mat(Color(0.26, 0.21, 0.19), _textures["brick"] as Texture2D, Vector2(6.0, 6.0))
	_materials["wood_dark"] = _make_mat(Color(0.34, 0.22, 0.14), _textures["wood"] as Texture2D, Vector2(2.0, 2.0))
	_materials["wood_med"] = _make_mat(Color(0.54, 0.36, 0.22), _textures["wood"] as Texture2D, Vector2(2.0, 2.0))
	_materials["wood_plank"] = _make_mat(Color(0.46, 0.33, 0.20), _textures["wood"] as Texture2D, Vector2(2.0, 1.0))
	_materials["fabric_red"] = _make_mat(Color(0.58, 0.20, 0.20), _textures["fabric"] as Texture2D, Vector2(3.0, 3.0))
	_materials["fabric_blue"] = _make_mat(Color(0.24, 0.34, 0.52), _textures["fabric"] as Texture2D, Vector2(3.0, 3.0))
	_materials["fabric_green"] = _make_mat(Color(0.26, 0.42, 0.28), _textures["fabric"] as Texture2D, Vector2(3.0, 3.0))
	_materials["fabric_sheet"] = _make_mat(Color(0.82, 0.80, 0.74), _textures["fabric"] as Texture2D, Vector2(2.0, 2.0))
	_materials["metal_dark"] = _make_mat(Color(0.24, 0.25, 0.27))
	_materials["appliance"] = _make_mat(Color(0.74, 0.72, 0.66))
	_materials["porcelain"] = _make_mat(Color(0.86, 0.86, 0.82))
	_materials["glass_mirror"] = _make_mat(Color(0.55, 0.68, 0.72))
	_materials["carpet"] = _make_mat(Color(0.44, 0.18, 0.20), _textures["fabric"] as Texture2D, Vector2(4.0, 4.0))
	_materials["screen_off"] = _make_mat(Color(0.08, 0.09, 0.10))


func _make_mat(color: Color, tex: Texture2D = null, uv_scale: Vector2 = Vector2(2.0, 2.0)) -> Material:
	if _psx_shader == null:
		_psx_shader = load("res://shaders/psx_lit.gdshader") as Shader
	var shader: Shader = _psx_shader
	if shader != null:
		var smat: ShaderMaterial = ShaderMaterial.new()
		smat.shader = shader
		smat.set_shader_parameter("modulate_color", color)
		smat.set_shader_parameter("uv_scale", uv_scale)
		if tex != null:
			smat.set_shader_parameter("albedo_texture", tex)
		return smat
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	if tex != null:
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.9
	return mat


func _make_wood_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 101
	for y: int in range(64):
		var plank_row: int = y / 16
		var is_seam: bool = (y % 16) == 0
		var v_offset: int = (plank_row * 23) % 64
		for x: int in range(64):
			var v: float = 0.90 + sin(float(x + v_offset) * 0.28 + sin(float(y) * 0.35)) * 0.06
			v += rng.randf_range(-0.04, 0.04)
			if is_seam or ((x + plank_row * 32) % 64) == 0:
				v *= 0.58
			v = clampf(v, 0.45, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.96, v * 0.90, 1.0))
	return ImageTexture.create_from_image(img)


func _make_tile_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 202
	for y: int in range(64):
		for x: int in range(64):
			var tx: int = x / 16
			var ty: int = y / 16
			var grout: bool = (x % 16) == 0 or (y % 16) == 0
			var checker: float = 0.96 if ((tx + ty) % 2) == 0 else 0.86
			var grain: float = rng.randf_range(-0.03, 0.03)
			var v: float = 0.55 if grout else clampf(checker + grain, 0.5, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)


func _make_wallpaper_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 303
	for y: int in range(64):
		var stain: float = 0.08 if y > 52 else 0.0
		for x: int in range(64):
			var stripe: float = 0.96 if ((x / 4) % 2) == 0 else 0.86
			var grunginess: float = rng.randf_range(-0.03, 0.03) - stain
			var v: float = clampf(stripe + grunginess, 0.60, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.99, v * 0.95, 1.0))
	return ImageTexture.create_from_image(img)


func _make_brick_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 404
	for y: int in range(64):
		var row: int = y / 8
		var shift: int = 8 if (row % 2) == 1 else 0
		var mortar_h: bool = (y % 8) == 0
		for x: int in range(64):
			var bx: int = (x + shift) % 16
			var mortar_v: bool = bx == 0
			var v: float = 0.62 if (mortar_h or mortar_v) else clampf(0.88 + rng.randf_range(-0.08, 0.07), 0.60, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.95, v * 0.92, 1.0))
	return ImageTexture.create_from_image(img)


func _make_fabric_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 505
	for y: int in range(64):
		for x: int in range(64):
			var weave: float = 0.94 if ((x + y) % 2) == 0 else 0.82
			var v: float = clampf(weave + rng.randf_range(-0.04, 0.04), 0.65, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)


func _create_group(group_name: String, parent_node: Node3D) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = group_name
	parent_node.add_child(node)
	_set_owner_recursive(node)
	return node


func _add_room_light(parent_node: Node3D, light_name: String, pos: Vector3, energy: float = 0.35, range_val: float = 9.0) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = light_name
	light.position = pos
	light.light_color = Color(0.72, 0.78, 0.88)
	light.light_energy = energy
	light.omni_range = range_val
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	# Luzes distantes são desligadas pelo renderer (economia com múltiplas luzes).
	light.distance_fade_enabled = true
	light.distance_fade_begin = 22.0
	light.distance_fade_length = 6.0
	parent_node.add_child(light)
	_set_owner_recursive(light)


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

		_set_owner_recursive(body)
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
		_set_owner_recursive(mesh_only)
		return mesh_only


## Reaproveita BoxMesh/BoxShape3D de mesmo tamanho e subdivide caixas grandes para vertex_lighting PS1.
func _get_box_mesh(size: Vector3) -> BoxMesh:
	if _mesh_cache.has(size):
		return _mesh_cache[size] as BoxMesh
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	m.subdivide_width = clampi(int(size.x / 1.8), 0, 10)
	m.subdivide_height = clampi(int(size.y / 1.8), 0, 6)
	m.subdivide_depth = clampi(int(size.z / 1.8), 0, 10)
	_mesh_cache[size] = m
	return m


func _get_box_shape(size: Vector3) -> BoxShape3D:
	if _shape_cache.has(size):
		return _shape_cache[size] as BoxShape3D
	var s: BoxShape3D = BoxShape3D.new()
	s.size = size
	_shape_cache[size] = s
	return s


func _add_wall_with_door(
	parent_node: Node3D,
	wall_name: String,
	center: Vector3,
	length: float,
	height: float,
	thickness: float,
	along_x: bool,
	door_offset: float,
	door_width: float,
	door_height: float,
	mat_key: String
) -> void:
	var group: Node3D = _create_group(wall_name, parent_node)
	group.position = center

	var half_len: float = length * 0.5
	var door_min: float = door_offset - door_width * 0.5
	var door_max: float = door_offset + door_width * 0.5

	var left_len: float = door_min - (-half_len)
	if left_len > 0.05:
		var left_center: float = -half_len + left_len * 0.5
		var s_left: Vector3 = Vector3(left_len, height, thickness) if along_x else Vector3(thickness, height, left_len)
		var p_left: Vector3 = Vector3(left_center, height * 0.5, 0.0) if along_x else Vector3(0.0, height * 0.5, left_center)
		_add_box(group, "WallLeft", s_left, p_left, mat_key)

	var right_len: float = half_len - door_max
	if right_len > 0.05:
		var right_center: float = door_max + right_len * 0.5
		var s_right: Vector3 = Vector3(right_len, height, thickness) if along_x else Vector3(thickness, height, right_len)
		var p_right: Vector3 = Vector3(right_center, height * 0.5, 0.0) if along_x else Vector3(0.0, height * 0.5, right_center)
		_add_box(group, "WallRight", s_right, p_right, mat_key)

	var lintel_h: float = height - door_height
	if lintel_h > 0.05:
		var s_lintel: Vector3 = Vector3(door_width, lintel_h, thickness) if along_x else Vector3(thickness, lintel_h, door_width)
		var p_lintel: Vector3 = Vector3(door_offset, door_height + lintel_h * 0.5, 0.0) if along_x else Vector3(0.0, door_height + lintel_h * 0.5, door_offset)
		_add_box(group, "WallLintel", s_lintel, p_lintel, mat_key)

	_add_door(group, door_offset, door_width, door_height, along_x)


func _add_door(parent_node: Node3D, door_offset: float, door_width: float, door_height: float, along_x: bool) -> void:
	var door_pivot: Node3D = Node3D.new()
	door_pivot.name = "Door"
	door_pivot.set_script(_DoorScript)
	door_pivot.position = Vector3(door_offset - door_width * 0.5, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, door_offset - door_width * 0.5)
	parent_node.add_child(door_pivot)

	var leaf: StaticBody3D = StaticBody3D.new()
	leaf.name = "DoorLeaf"
	leaf.collision_layer = (1 << 0) | (1 << 3)
	leaf.collision_mask = 0
	var leaf_size: Vector3 = Vector3(door_width - 0.06, door_height - 0.04, 0.08) if along_x else Vector3(0.08, door_height - 0.04, door_width - 0.06)
	leaf.position = Vector3(door_width * 0.5, door_height * 0.5, 0.0) if along_x else Vector3(0.0, door_height * 0.5, door_width * 0.5)
	door_pivot.add_child(leaf)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = leaf_size
	mesh_inst.mesh = box_mesh
	if _materials.has("wood_dark"):
		mesh_inst.material_override = _materials["wood_dark"] as Material
	leaf.add_child(mesh_inst)

	var col: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = leaf_size
	col.shape = box_shape
	leaf.add_child(col)

	_set_owner_recursive(door_pivot)


func _add_wardrobe(
	parent_node: Node3D,
	part_name: String,
	size: Vector3,
	pos: Vector3,
	hide_offset: Vector3,
	exit_offset: Vector3
) -> void:
	var wardrobe: StaticBody3D = StaticBody3D.new()
	wardrobe.name = part_name
	wardrobe.set_script(_WardrobeScript)
	wardrobe.position = pos
	wardrobe.set("hide_offset", hide_offset)
	wardrobe.set("exit_offset", exit_offset)
	wardrobe.collision_layer = (1 << 0) | (1 << 3)
	wardrobe.collision_mask = 0
	parent_node.add_child(wardrobe)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	if _materials.has("wood_dark"):
		mesh_inst.material_override = _materials["wood_dark"] as Material
	wardrobe.add_child(mesh_inst)

	var col: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	col.shape = box_shape
	wardrobe.add_child(col)

	_set_owner_recursive(wardrobe)


func _add_wall_with_window(
	parent_node: Node3D,
	wall_name: String,
	center: Vector3,
	length: float,
	height: float,
	thickness: float,
	along_x: bool,
	win_offset: float,
	win_width: float,
	win_bottom: float,
	win_top: float,
	mat_key: String
) -> void:
	var group: Node3D = _create_group(wall_name, parent_node)
	group.position = center

	var half_len: float = length * 0.5
	var win_min: float = win_offset - win_width * 0.5
	var win_max: float = win_offset + win_width * 0.5

	var left_len: float = win_min - (-half_len)
	if left_len > 0.05:
		var lc: float = -half_len + left_len * 0.5
		var sl: Vector3 = Vector3(left_len, height, thickness) if along_x else Vector3(thickness, height, left_len)
		var pl: Vector3 = Vector3(lc, height * 0.5, 0.0) if along_x else Vector3(0.0, height * 0.5, lc)
		_add_box(group, "SegLeft", sl, pl, mat_key)

	var right_len: float = half_len - win_max
	if right_len > 0.05:
		var rc: float = win_max + right_len * 0.5
		var sr: Vector3 = Vector3(right_len, height, thickness) if along_x else Vector3(thickness, height, right_len)
		var pr: Vector3 = Vector3(rc, height * 0.5, 0.0) if along_x else Vector3(0.0, height * 0.5, rc)
		_add_box(group, "SegRight", sr, pr, mat_key)

	if win_bottom > 0.05:
		var sb: Vector3 = Vector3(win_width, win_bottom, thickness) if along_x else Vector3(thickness, win_bottom, win_width)
		var pb: Vector3 = Vector3(win_offset, win_bottom * 0.5, 0.0) if along_x else Vector3(0.0, win_bottom * 0.5, win_offset)
		_add_box(group, "SegSill", sb, pb, mat_key)

	var top_h: float = height - win_top
	if top_h > 0.05:
		var st: Vector3 = Vector3(win_width, top_h, thickness) if along_x else Vector3(thickness, top_h, win_width)
		var pt: Vector3 = Vector3(win_offset, win_top + top_h * 0.5, 0.0) if along_x else Vector3(0.0, win_top + top_h * 0.5, win_offset)
		_add_box(group, "SegHeader", st, pt, mat_key)

	# Tábuas pregadas na janela (deixam frestas de luz solar passar)
	var plank_size: Vector3 = Vector3(win_width + 0.2, 0.14, 0.06) if along_x else Vector3(0.06, 0.14, win_width + 0.2)
	var p1: Vector3 = Vector3(win_offset, win_bottom + 0.35, 0.0) if along_x else Vector3(0.0, win_bottom + 0.35, win_offset)
	var p2: Vector3 = Vector3(win_offset, win_top - 0.35, 0.0) if along_x else Vector3(0.0, win_top - 0.35, win_offset)
	_add_box(group, "WindowPlank1", plank_size, p1, "wood_plank", Vector3(0.0, 0.0, 4.0 if along_x else 0.0))
	_add_box(group, "WindowPlank2", plank_size, p2, "wood_plank", Vector3(0.0, 0.0, -3.0 if along_x else 0.0))


func _build_structure(root: Node3D) -> void:
	# Piso do 1º Andar e Varanda Frontal
	_add_box(root, "GroundFloorSlab", Vector3(16.0, 0.2, 14.0), Vector3(0.0, -0.1, 0.0), "floor_wood")
	_add_box(root, "PorchFloor", Vector3(6.0, 0.2, 3.0), Vector3(0.0, -0.1, 8.5), "wood_dark")
	_add_box(root, "PorchRoof", Vector3(6.4, 0.25, 3.2), Vector3(0.0, 3.4, 8.5), "roof")
	_add_box(root, "PorchPillarLeft", Vector3(0.25, 3.4, 0.25), Vector3(-2.8, 1.7, 9.8), "wood_dark")
	_add_box(root, "PorchPillarRight", Vector3(0.25, 3.4, 0.25), Vector3(2.8, 1.7, 9.8), "wood_dark")

	# Laje do 2º Andar (y = 3.6) com abertura central para a escada (X: -1.2..1.2, Z: -2.5..2.5)
	_add_box(root, "SecondFloorSlabWest", Vector3(6.8, 0.2, 14.0), Vector3(-4.6, 3.5, 0.0), "floor_wood")
	_add_box(root, "SecondFloorSlabEast", Vector3(6.8, 0.2, 14.0), Vector3(4.6, 3.5, 0.0), "floor_wood")
	_add_box(root, "SecondFloorSlabNorth", Vector3(2.4, 0.2, 4.5), Vector3(0.0, 3.5, -4.75), "floor_wood")
	_add_box(root, "SecondFloorSlabSouth", Vector3(2.4, 0.2, 4.5), Vector3(0.0, 3.5, 4.75), "floor_wood")

	# Telhado / Teto do 2º Andar (y = 7.2) com claraboia estreita no corredor
	_add_box(root, "RoofSlabWest", Vector3(7.6, 0.3, 14.6), Vector3(-4.2, 7.35, 0.0), "roof")
	_add_box(root, "RoofSlabEast", Vector3(7.6, 0.3, 14.6), Vector3(4.2, 7.35, 0.0), "roof")
	_add_box(root, "RoofSlabCenterNorth", Vector3(0.8, 0.3, 6.0), Vector3(0.0, 7.35, -4.3), "roof")
	_add_box(root, "RoofSlabCenterSouth", Vector3(0.8, 0.3, 6.0), Vector3(0.0, 7.35, 4.3), "roof")

	# Paredes Externas - 1º Andar (y = 0.0 a 3.6)
	_add_wall_with_door(root, "ExtWall1_SouthCenter", Vector3(0.0, 0.0, 7.0), 4.0, 3.6, 0.25, true, 0.0, 1.6, 2.4, "wall_ext")
	_add_wall_with_window(root, "ExtWall1_SouthWest", Vector3(-5.0, 0.0, 7.0), 6.0, 3.6, 0.25, true, 0.0, 2.0, 1.0, 2.4, "wall_ext")
	_add_wall_with_window(root, "ExtWall1_SouthEast", Vector3(5.0, 0.0, 7.0), 6.0, 3.6, 0.25, true, 0.0, 2.0, 1.0, 2.4, "wall_ext")
	_add_wall_with_window(root, "ExtWall1_North", Vector3(0.0, 0.0, -7.0), 16.0, 3.6, 0.25, true, 4.5, 2.2, 1.1, 2.4, "wall_ext")
	_add_wall_with_window(root, "ExtWall1_West", Vector3(-8.0, 0.0, 0.0), 14.0, 3.6, 0.25, false, 3.5, 2.0, 1.0, 2.4, "wall_ext")
	_add_wall_with_window(root, "ExtWall1_East", Vector3(8.0, 0.0, 0.0), 14.0, 3.6, 0.25, false, -3.5, 2.0, 1.0, 2.4, "wall_ext")

	# Paredes Externas - 2º Andar (y = 3.6 a 7.2)
	_add_wall_with_window(root, "ExtWall2_South", Vector3(0.0, 3.6, 7.0), 16.0, 3.6, 0.25, true, -5.0, 2.2, 1.0, 2.4, "wall_ext")
	_add_wall_with_window(root, "ExtWall2_North", Vector3(0.0, 3.6, -7.0), 16.0, 3.6, 0.25, true, 5.0, 2.2, 1.0, 2.4, "wall_ext")
	_add_wall_with_window(root, "ExtWall2_West", Vector3(-8.0, 3.6, 0.0), 14.0, 3.6, 0.25, false, 3.5, 2.0, 1.0, 2.4, "wall_ext")
	_add_wall_with_window(root, "ExtWall2_East", Vector3(8.0, 3.6, 0.0), 14.0, 3.6, 0.25, false, 3.5, 2.0, 1.0, 2.4, "wall_ext")

	# Paredes Internas - 1º Andar (Dividem Hall Central [-2..+2], Sala Estar, Jantar, Cozinha e Banheiro)
	_add_wall_with_door(root, "IntWall1_HallWestSouth", Vector3(-2.0, 0.0, 3.5), 7.0, 3.6, 0.18, false, 1.2, 1.4, 2.3, "wall_int")
	_add_wall_with_door(root, "IntWall1_HallWestNorth", Vector3(-2.0, 0.0, -3.5), 7.0, 3.6, 0.18, false, -1.2, 1.3, 2.3, "wall_int")
	_add_wall_with_door(root, "IntWall1_HallEastSouth", Vector3(2.0, 0.0, 3.5), 7.0, 3.6, 0.18, false, 1.2, 1.4, 2.3, "wall_int")
	_add_wall_with_door(root, "IntWall1_HallEastNorth", Vector3(2.0, 0.0, -3.5), 7.0, 3.6, 0.18, false, -1.2, 1.4, 2.3, "wall_int")
	_add_box(root, "IntWall1_WestDivider", Vector3(6.0, 3.6, 0.18), Vector3(-5.0, 1.8, 0.0), "wall_int")
	_add_wall_with_door(root, "IntWall1_EastDivider", Vector3(5.0, 0.0, 0.0), 6.0, 3.6, 0.18, true, 0.0, 1.5, 2.3, "wall_int")

	# Paredes Internas - 2º Andar (Dividem Corredor Superior, Quarto Leo, Quarto Casal, Escritório e Banheiro)
	_add_wall_with_door(root, "IntWall2_HallWestSouth", Vector3(-2.0, 3.6, 3.5), 7.0, 3.6, 0.18, false, 1.5, 1.3, 2.3, "wall_int")
	_add_wall_with_door(root, "IntWall2_HallWestNorth", Vector3(-2.0, 3.6, -3.5), 7.0, 3.6, 0.18, false, -1.5, 1.3, 2.3, "wall_int")
	_add_wall_with_door(root, "IntWall2_HallEastSouth", Vector3(2.0, 3.6, 3.5), 7.0, 3.6, 0.18, false, 1.5, 1.3, 2.3, "wall_int")
	_add_wall_with_door(root, "IntWall2_HallEastNorth", Vector3(2.0, 3.6, -3.5), 7.0, 3.6, 0.18, false, -1.5, 1.3, 2.3, "wall_int")
	_add_box(root, "IntWall2_WestDivider", Vector3(6.0, 3.6, 0.18), Vector3(-5.0, 5.4, 0.0), "wall_int")
	_add_box(root, "IntWall2_EastDivider", Vector3(6.0, 3.6, 0.18), Vector3(5.0, 5.4, 0.0), "wall_int")

	# Escadaria Central (sobe de Z = +2.5 [y = 0] até Z = -2.5 [y = 3.6])
	var stairs: Node3D = _create_group("Staircase", root)
	_add_box(stairs, "StairRampCollider", Vector3(2.0, 0.2, 6.18), Vector3(0.0, 1.75, 0.0), "wood_dark", Vector3(35.75, 0.0, 0.0), true)
	var step_count: int = 12
	for i: int in range(step_count):
		var t: float = float(i) / float(step_count)
		var step_y: float = 0.15 + t * 3.45
		var step_z: float = 2.3 - t * 4.6
		_add_box(stairs, "Step_%02d" % i, Vector3(2.1, 0.12, 0.42), Vector3(0.0, step_y, step_z), "wood_med", Vector3.ZERO, false)

	# Guarda-corpos do vão da escada no 2º andar
	_add_box(stairs, "RailWest", Vector3(0.12, 1.0, 5.0), Vector3(-1.15, 4.1, 0.0), "wood_dark")
	_add_box(stairs, "RailEast", Vector3(0.12, 1.0, 5.0), Vector3(1.15, 4.1, 0.0), "wood_dark")
	_add_box(stairs, "RailSouth", Vector3(2.2, 1.0, 0.12), Vector3(0.0, 4.1, 2.55), "wood_dark")


func _build_ground_floor_furniture(root: Node3D) -> void:
	# 0. Varanda e Hall Central
	var hall: Node3D = _create_group("HallAndPorch", root)
	_add_box(hall, "PorchBench", Vector3(1.6, 0.5, 0.55), Vector3(-1.8, 0.25, 8.2), "wood_med")
	_add_box(hall, "HallCarpet", Vector3(1.8, 0.02, 3.2), Vector3(0.0, 0.01, 4.8), "carpet", Vector3.ZERO, false)
	_add_box(hall, "EntrySideTable", Vector3(0.45, 0.78, 1.1), Vector3(-1.55, 0.39, 5.4), "wood_dark")
	_add_box(hall, "CoatRack", Vector3(0.25, 1.75, 0.25), Vector3(1.55, 0.88, 6.2), "wood_dark")
	_add_room_light(hall, "HallLight", Vector3(0.0, 3.1, 4.5))

	# 1. Sala de Estar (Living Room - Sudoeste: X -8..-2, Z 0..7)
	var living: Node3D = _create_group("LivingRoom", root)
	_add_box(living, "LivingRug", Vector3(3.4, 0.02, 4.0), Vector3(-5.0, 0.01, 3.5), "carpet", Vector3.ZERO, false)
	_add_box(living, "SofaBase", Vector3(2.4, 0.45, 0.9), Vector3(-5.0, 0.23, 1.2), "fabric_red")
	_add_box(living, "SofaBack", Vector3(2.4, 0.55, 0.22), Vector3(-5.0, 0.65, 0.84), "fabric_red")
	_add_box(living, "SofaArmL", Vector3(0.24, 0.65, 0.9), Vector3(-6.1, 0.33, 1.2), "fabric_red")
	_add_box(living, "SofaArmR", Vector3(0.24, 0.65, 0.9), Vector3(-3.9, 0.33, 1.2), "fabric_red")
	_add_box(living, "Armchair", Vector3(0.95, 0.75, 0.95), Vector3(-6.8, 0.38, 3.2), "fabric_green", Vector3(0.0, 20.0, 0.0))
	_add_box(living, "CoffeeTable", Vector3(1.4, 0.42, 0.75), Vector3(-5.0, 0.21, 3.0), "wood_dark")
	_add_box(living, "TVStand", Vector3(1.8, 0.55, 0.55), Vector3(-5.0, 0.28, 6.2), "wood_dark")
	_add_box(living, "CRT_TV_Body", Vector3(0.75, 0.62, 0.52), Vector3(-5.0, 0.86, 6.2), "metal_dark")
	_add_box(living, "CRT_TV_Screen", Vector3(0.62, 0.48, 0.04), Vector3(-5.0, 0.87, 5.93), "screen_off", Vector3.ZERO, false)
	_add_box(living, "Bookshelf", Vector3(0.45, 2.1, 1.6), Vector3(-7.55, 1.05, 5.2), "wood_dark")
	_add_box(living, "FloorLamp", Vector3(0.32, 1.65, 0.32), Vector3(-7.2, 0.83, 1.0), "wood_med")
	_add_room_light(living, "LivingRoomLight", Vector3(-5.0, 3.1, 3.5))

	# 2. Sala de Jantar (Dining Room - Sudeste: X 2..8, Z 0..7)
	var dining: Node3D = _create_group("DiningRoom", root)
	_add_box(dining, "DiningTableTop", Vector3(2.4, 0.12, 1.3), Vector3(5.0, 0.76, 3.6), "wood_dark")
	_add_box(dining, "DiningTableBase", Vector3(1.8, 0.72, 0.8), Vector3(5.0, 0.36, 3.6), "wood_dark")
	_add_box(dining, "Chair1", Vector3(0.48, 0.85, 0.48), Vector3(4.3, 0.43, 2.65), "wood_med")
	_add_box(dining, "Chair2", Vector3(0.48, 0.85, 0.48), Vector3(5.7, 0.43, 2.65), "wood_med")
	_add_box(dining, "Chair3", Vector3(0.48, 0.85, 0.48), Vector3(4.3, 0.43, 4.55), "wood_med")
	_add_box(dining, "Chair4_Fallen", Vector3(0.85, 0.48, 0.48), Vector3(6.1, 0.24, 4.8), "wood_med", Vector3(0.0, 32.0, 0.0))
	_add_box(dining, "SideboardHutch", Vector3(0.5, 1.85, 2.2), Vector3(7.5, 0.93, 3.5), "wood_dark")

	# 3. Cozinha (Kitchen - Nordeste: X 2..8, Z -7..0)
	var kitchen: Node3D = _create_group("Kitchen", root)
	_add_box(kitchen, "KitchenFloorTile", Vector3(5.6, 0.02, 6.6), Vector3(5.0, 0.01, -3.5), "floor_tile", Vector3.ZERO, false)
	_add_box(kitchen, "CounterNorth", Vector3(3.8, 0.9, 0.7), Vector3(4.6, 0.45, -6.4), "wood_med")
	_add_box(kitchen, "CounterEast", Vector3(0.7, 0.9, 3.2), Vector3(7.4, 0.45, -4.4), "wood_med")
	_add_box(kitchen, "KitchenSink", Vector3(0.8, 0.15, 0.5), Vector3(4.4, 0.93, -6.4), "metal_dark")
	_add_box(kitchen, "Fridge", Vector3(0.85, 1.95, 0.85), Vector3(7.3, 0.98, -1.6), "appliance")
	_add_box(kitchen, "StoveOven", Vector3(0.8, 0.92, 0.75), Vector3(6.8, 0.46, -6.4), "appliance")
	_add_box(kitchen, "UpperCabinet1", Vector3(2.8, 0.75, 0.4), Vector3(4.5, 2.35, -6.6), "wood_dark")
	_add_box(kitchen, "PrepIsland", Vector3(1.4, 0.85, 0.9), Vector3(4.6, 0.43, -3.4), "wood_med")

	# 4. Banheiro Térreo (Downstairs Bathroom - Noroeste: X -8..-2, Z -7..0)
	var bath1: Node3D = _create_group("DownstairsBathroom", root)
	_add_box(bath1, "Bath1FloorTile", Vector3(5.6, 0.02, 6.6), Vector3(-5.0, 0.01, -3.5), "floor_tile", Vector3.ZERO, false)
	_add_box(bath1, "ToiletBase", Vector3(0.55, 0.48, 0.68), Vector3(-7.2, 0.24, -6.1), "porcelain")
	_add_box(bath1, "ToiletTank", Vector3(0.52, 0.55, 0.26), Vector3(-7.2, 0.72, -6.4), "porcelain")
	_add_box(bath1, "SinkVanity", Vector3(0.9, 0.85, 0.55), Vector3(-5.2, 0.43, -6.45), "wood_dark")
	_add_box(bath1, "SinkBasin", Vector3(0.6, 0.15, 0.42), Vector3(-5.2, 0.9, -6.45), "porcelain")
	_add_box(bath1, "Mirror", Vector3(0.75, 0.95, 0.05), Vector3(-5.2, 1.65, -6.78), "glass_mirror", Vector3.ZERO, false)
	_add_box(bath1, "ShowerStall", Vector3(1.3, 2.1, 1.3), Vector3(-7.0, 1.05, -1.5), "porcelain")
	_add_box(bath1, "LinenCabinet", Vector3(0.5, 1.7, 0.8), Vector3(-3.2, 0.85, -6.35), "wood_med")


func _build_upper_floor_furniture(root: Node3D) -> void:
	var y2: float = 3.6

	# 0. Corredor Superior
	var hall2: Node3D = _create_group("UpstairsHallway", root)
	_add_box(hall2, "HallDresser", Vector3(1.2, 0.82, 0.48), Vector3(0.0, y2 + 0.41, -6.4), "wood_dark")
	_add_box(hall2, "HallRunnerRug", Vector3(1.5, 0.02, 3.2), Vector3(0.0, y2 + 0.01, 4.8), "carpet", Vector3.ZERO, false)
	_add_room_light(hall2, "UpstairsHallLight", Vector3(0.0, y2 + 3.1, 0.0))

	# 1. Quarto do Leo (Leo's Bedroom - Sudoeste: X -8..-2, Z 0..7)
	var leo_room: Node3D = _create_group("LeoBedroom", root)
	_add_box(leo_room, "SingleBedFrame", Vector3(1.2, 0.42, 2.1), Vector3(-7.0, y2 + 0.21, 5.5), "wood_med")
	_add_box(leo_room, "SingleMattress", Vector3(1.1, 0.22, 1.95), Vector3(-7.0, y2 + 0.5, 5.5), "fabric_blue")
	_add_box(leo_room, "LeoPillow", Vector3(0.7, 0.14, 0.4), Vector3(-7.0, y2 + 0.66, 6.2), "fabric_sheet", Vector3.ZERO, false)
	_add_box(leo_room, "Nightstand", Vector3(0.5, 0.55, 0.5), Vector3(-5.9, y2 + 0.28, 6.3), "wood_dark")
	_add_box(leo_room, "StudyDesk", Vector3(1.5, 0.76, 0.7), Vector3(-4.8, y2 + 0.38, 0.85), "wood_med")
	_add_box(leo_room, "DeskMonitorCRT", Vector3(0.46, 0.44, 0.42), Vector3(-4.8, y2 + 0.98, 0.75), "appliance")
	_add_box(leo_room, "StudyChair", Vector3(0.5, 0.82, 0.5), Vector3(-4.8, y2 + 0.41, 1.65), "wood_dark")
	_add_wardrobe(leo_room, "LeoWardrobe", Vector3(0.65, 2.05, 1.4), Vector3(-7.4, y2 + 1.03, 2.2), Vector3(0.0, -1.03, 0.0), Vector3(1.15, -1.03, 0.0))
	_add_box(leo_room, "WallShelf", Vector3(1.4, 0.1, 0.3), Vector3(-4.8, y2 + 1.75, 0.35), "wood_med")
	_add_room_light(leo_room, "LeoBedroomLight", Vector3(-5.0, y2 + 3.1, 3.5))

	# 2. Quarto Principal / Casal (Master Bedroom - Sudeste: X 2..8, Z 0..7)
	var master: Node3D = _create_group("MasterBedroom", root)
	_add_box(master, "DoubleBedFrame", Vector3(1.9, 0.45, 2.2), Vector3(5.8, y2 + 0.23, 5.4), "wood_dark")
	_add_box(master, "DoubleBedHeadboard", Vector3(1.95, 1.15, 0.18), Vector3(5.8, y2 + 0.58, 6.45), "wood_dark")
	_add_box(master, "DoubleMattress", Vector3(1.8, 0.24, 2.05), Vector3(5.8, y2 + 0.54, 5.38), "fabric_red")
	_add_box(master, "MasterPillowL", Vector3(0.65, 0.14, 0.4), Vector3(5.35, y2 + 0.72, 6.1), "fabric_sheet", Vector3.ZERO, false)
	_add_box(master, "MasterPillowR", Vector3(0.65, 0.14, 0.4), Vector3(6.25, y2 + 0.72, 6.1), "fabric_sheet", Vector3.ZERO, false)
	_add_box(master, "NightstandL", Vector3(0.52, 0.58, 0.52), Vector3(4.4, y2 + 0.29, 6.25), "wood_dark")
	_add_box(master, "NightstandR", Vector3(0.52, 0.58, 0.52), Vector3(7.2, y2 + 0.29, 6.25), "wood_dark")
	_add_box(master, "FootChest", Vector3(1.4, 0.48, 0.5), Vector3(5.8, y2 + 0.24, 3.95), "wood_med")
	_add_wardrobe(master, "MasterWardrobe", Vector3(0.7, 2.15, 2.2), Vector3(7.4, y2 + 1.08, 2.3), Vector3(0.0, -1.08, 0.0), Vector3(-1.15, -1.08, 0.0))
	_add_box(master, "VanityTable", Vector3(1.2, 0.76, 0.55), Vector3(4.2, y2 + 0.38, 0.65), "wood_med")
	_add_box(master, "VanityMirror", Vector3(0.85, 0.9, 0.06), Vector3(4.2, y2 + 1.22, 0.32), "glass_mirror", Vector3.ZERO, false)

	# 3. Escritório / Biblioteca (Study Room - Nordeste: X 2..8, Z -7..0)
	var study: Node3D = _create_group("StudyRoom", root)
	_add_box(study, "TallBookcase1", Vector3(1.8, 2.25, 0.45), Vector3(4.2, y2 + 1.13, -6.55), "wood_dark")
	_add_box(study, "TallBookcase2", Vector3(1.8, 2.25, 0.45), Vector3(6.3, y2 + 1.13, -6.55), "wood_dark")
	_add_box(study, "ExecutiveDesk", Vector3(1.8, 0.78, 0.95), Vector3(5.2, y2 + 0.39, -3.5), "wood_dark")
	_add_box(study, "LeatherChair", Vector3(0.65, 0.95, 0.65), Vector3(5.2, y2 + 0.48, -4.55), "fabric_green")
	_add_box(study, "FilingCabinet", Vector3(0.55, 1.35, 0.65), Vector3(7.35, y2 + 0.68, -1.8), "metal_dark")
	_add_box(study, "StudyRug", Vector3(3.0, 0.02, 2.6), Vector3(5.2, y2 + 0.01, -3.5), "carpet", Vector3.ZERO, false)

	# 4. Banheiro Superior (Upstairs Bathroom - Noroeste: X -8..-2, Z -7..0)
	var bath2: Node3D = _create_group("UpstairsBathroom", root)
	_add_box(bath2, "Bath2FloorTile", Vector3(5.6, 0.02, 6.6), Vector3(-5.0, y2 + 0.01, -3.5), "floor_tile", Vector3.ZERO, false)
	_add_box(bath2, "Bathtub", Vector3(1.75, 0.62, 0.85), Vector3(-6.7, y2 + 0.31, -6.1), "porcelain")
	_add_box(bath2, "UpperToiletBase", Vector3(0.55, 0.48, 0.68), Vector3(-7.2, y2 + 0.24, -1.5), "porcelain")
	_add_box(bath2, "UpperToiletTank", Vector3(0.52, 0.55, 0.26), Vector3(-7.45, y2 + 0.72, -1.5), "porcelain")
	_add_box(bath2, "UpperSinkVanity", Vector3(1.0, 0.85, 0.55), Vector3(-4.2, y2 + 0.43, -6.45), "wood_dark")
	_add_box(bath2, "UpperMirror", Vector3(0.85, 0.95, 0.05), Vector3(-4.2, y2 + 1.65, -6.78), "glass_mirror", Vector3.ZERO, false)
	_add_box(bath2, "LaundryHamper", Vector3(0.5, 0.68, 0.45), Vector3(-3.1, y2 + 0.34, -1.2), "wood_med")


func _set_owner_recursive(_node: Node) -> void:
	# Mantém a cena .tscn enxuta sem serializar centenas de nós procedurais em disco.
	pass
