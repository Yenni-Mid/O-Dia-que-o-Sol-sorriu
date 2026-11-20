extends Node3D
## Diorama 3D PS1 em tempo real para o Menu Principal de "O Dia Que O Sol Sorriu":
## Quarto escuro barricado com janela pregada com tábuas, feixes diagonais de luz solar e poeira dourada,
## cama na penumbra à esquerda, papéis espalhados no chão e mesa em primeiro plano à direita
## com a fotografia do Leo, o mapa rabiscado em amarelo e o lampião a óleo aceso.

const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

var _time: float = 0.0
var _camera: Camera3D
var _cam_base_pos: Vector3 = Vector3(-0.56, 1.36, 2.18)
var _cam_base_rot: Vector3 = Vector3.ZERO
var _lantern_light: OmniLight3D
var _flame_inner: MeshInstance3D
var _flame_outer: MeshInstance3D
var _window_spot: SpotLight3D
var _shaft_mats: Array[StandardMaterial3D] = []
var _zoom_target: float = 0.0


func _ready() -> void:
	_build_environment_and_camera()
	_build_room_shell()
	_build_boarded_window_and_sunbeams()
	_build_bed_and_floor_papers()
	_build_foreground_desk_and_props()


func _exit_tree() -> void:
	_shaft_mats.clear()
	_camera = null
	_lantern_light = null
	_flame_inner = null
	_flame_outer = null
	_window_spot = null


func trigger_start_zoom() -> void:
	_zoom_target = 1.0


func _process(delta: float) -> void:
	_time += delta

	# Oscilação orgânica da chama do lampião sobre a mesa
	var flicker: float = 0.5 + 0.5 * (sin(_time * 11.3) * 0.55 + cos(_time * 19.7) * 0.45)
	var zoom_boost: float = _zoom_target * 1.35
	if _lantern_light != null:
		_lantern_light.light_energy = 1.55 + flicker * 0.38 + zoom_boost
	if _flame_inner != null:
		var sy: float = 0.88 + flicker * 0.34 + _zoom_target * 0.3
		_flame_inner.scale = Vector3(1.0, sy, 1.0)
	if _flame_outer != null:
		var oy: float = 0.92 + flicker * 0.28 + _zoom_target * 0.35
		_flame_outer.scale = Vector3(1.0 + _zoom_target * 0.2, oy, 1.0 + _zoom_target * 0.2)

	# Pulso sutil dos feixes solares na janela barricada
	var sun_breath: float = 1.0 + sin(_time * 0.85) * 0.06
	if _window_spot != null:
		_window_spot.light_energy = 2.15 * sun_breath
	for i: int in range(_shaft_mats.size()):
		var sm: StandardMaterial3D = _shaft_mats[i]
		if sm != null:
			var base_a: float = 0.12 if (i % 2 == 0) else 0.085
			sm.albedo_color.a = base_a * (0.94 + 0.10 * sin(_time * 1.1 + float(i)))

	# Respiração suave da câmera em 1ª pessoa (+ leve aproximação ao iniciar)
	if _camera != null:
		var sway_x: float = sin(_time * 0.55) * 0.014
		var sway_y: float = cos(_time * 0.72) * 0.010
		var target_pos: Vector3 = _cam_base_pos + Vector3(sway_x, sway_y, 0.0)
		if _zoom_target > 0.0:
			target_pos = _cam_base_pos.lerp(Vector3(0.35, 1.18, 1.25), clampf(_zoom_target, 0.0, 1.0))
			_zoom_target = minf(1.0, _zoom_target + delta * 1.8)
		_camera.position = _camera.position.lerp(target_pos, clampf(delta * 4.5, 0.0, 1.0))
		_camera.rotation = _cam_base_rot + Vector3(cos(_time * 0.48) * 0.004, sin(_time * 0.37) * 0.005, 0.0)


func _build_environment_and_camera() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "MenuWorldEnv"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.025, 0.02, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.19, 0.13, 1.0)
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08
	env.glow_enabled = true
	env.glow_intensity = 0.52
	env.glow_bloom = 0.06
	env.fog_enabled = true
	env.fog_light_color = Color(0.18, 0.13, 0.07, 1.0)
	env.fog_density = 0.035
	we.environment = env
	add_child(we)

	_camera = Camera3D.new()
	_camera.name = "MenuCamera3D"
	_camera.fov = 50.0
	_camera.position = _cam_base_pos
	add_child(_camera)
	_camera.look_at_from_position(_cam_base_pos, Vector3(0.26, 1.06, -1.10), Vector3.UP)
	_cam_base_rot = _camera.rotation


func _build_room_shell() -> void:
	var room: Node3D = Node3D.new()
	room.name = "RoomShell"
	add_child(room)

	var wall_tex: ImageTexture = _make_grimy_wall_texture(false)
	var right_wall_tex: ImageTexture = _make_grimy_wall_texture(true)
	var floor_tex: ImageTexture = _make_dark_floor_texture()

	var mat_wall_dark: Material = _make_psx_mat(Color(0.32, 0.27, 0.21), wall_tex, Vector2(2.0, 1.5))
	var mat_wall_right: Material = _make_psx_mat(Color(0.56, 0.46, 0.34), right_wall_tex, Vector2(1.0, 1.0))
	var mat_floor: Material = _make_psx_mat(Color(0.26, 0.23, 0.19), floor_tex, Vector2(3.0, 3.0))
	var mat_ceil: Material = _make_psx_mat(Color(0.12, 0.10, 0.08), wall_tex, Vector2(2.0, 2.0))

	# Piso, teto e paredes escuras com abertura da janela na parede de fundo (Z = -2.35)
	_add_mesh_box(room, "Floor", Vector3(5.2, 0.1, 5.6), Vector3(0.0, -0.05, 0.0), mat_floor)
	_add_mesh_box(room, "Ceiling", Vector3(5.2, 0.1, 5.6), Vector3(0.0, 2.85, 0.0), mat_ceil)
	_add_mesh_box(room, "LeftWall", Vector3(0.15, 2.9, 5.6), Vector3(-2.35, 1.4, 0.0), mat_wall_dark)
	_add_mesh_box(room, "RightWall", Vector3(0.15, 2.9, 5.6), Vector3(1.65, 1.4, 0.0), mat_wall_right)

	# Parede de fundo (Z = -2.35) recortada para a janela em X: 0.02..1.18, Y: 1.08..2.22
	_add_mesh_box(room, "BackWallLeft", Vector3(2.42, 2.9, 0.16), Vector3(-1.19, 1.4, -2.35), mat_wall_dark)
	_add_mesh_box(room, "BackWallRight", Vector3(0.52, 2.9, 0.16), Vector3(1.44, 1.4, -2.35), mat_wall_dark)
	_add_mesh_box(room, "BackWallBottom", Vector3(1.16, 1.08, 0.16), Vector3(0.60, 0.54, -2.35), mat_wall_dark)
	_add_mesh_box(room, "BackWallTop", Vector3(1.16, 0.68, 0.16), Vector3(0.60, 2.56, -2.35), mat_wall_dark)


func _build_boarded_window_and_sunbeams() -> void:
	var win: Node3D = Node3D.new()
	win.name = "BoardedWindow"
	add_child(win)

	var wood_tex: ImageTexture = _make_plank_wood_texture()
	var mat_frame: Material = _make_psx_mat(Color(0.24, 0.18, 0.12), wood_tex, Vector2(1.0, 1.0))
	var mat_plank: Material = _make_psx_mat(Color(0.38, 0.25, 0.13), wood_tex, Vector2(2.0, 1.0))

	# Céu amarelo intenso lá fora + silhuetas de prédios pós-apocalípticos vistos pela janela
	var sky_mat: StandardMaterial3D = StandardMaterial3D.new()
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mat.albedo_color = Color(1.0, 0.90, 0.38, 1.0)
	_add_mesh_box(win, "OutsideSunSky", Vector3(2.4, 2.0, 0.05), Vector3(0.60, 1.68, -2.95), sky_mat)

	var bldg_mat_a: StandardMaterial3D = StandardMaterial3D.new()
	bldg_mat_a.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bldg_mat_a.albedo_color = Color(0.84, 0.68, 0.25, 1.0)
	var bldg_mat_b: StandardMaterial3D = StandardMaterial3D.new()
	bldg_mat_b.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bldg_mat_b.albedo_color = Color(0.74, 0.58, 0.20, 1.0)
	_add_mesh_box(win, "OutsideCityBldg1", Vector3(0.45, 0.72, 0.05), Vector3(0.95, 1.38, -2.78), bldg_mat_b)
	_add_mesh_box(win, "OutsideCityBldg2", Vector3(0.42, 0.54, 0.05), Vector3(0.55, 1.28, -2.82), bldg_mat_a)

	# Moldura e cruzeta da janela (X: 0.02..1.18, Y: 1.08..2.22, Z = -2.35)
	_add_mesh_box(win, "WinSill", Vector3(1.28, 0.07, 0.24), Vector3(0.60, 1.06, -2.30), mat_frame)
	_add_mesh_box(win, "WinTopFrame", Vector3(1.26, 0.07, 0.20), Vector3(0.60, 2.23, -2.32), mat_frame)
	_add_mesh_box(win, "WinLeftFrame", Vector3(0.07, 1.18, 0.20), Vector3(0.02, 1.65, -2.32), mat_frame)
	_add_mesh_box(win, "WinRightFrame", Vector3(0.07, 1.18, 0.20), Vector3(1.18, 1.65, -2.32), mat_frame)
	_add_mesh_box(win, "WinMullionV", Vector3(0.05, 1.14, 0.08), Vector3(0.60, 1.65, -2.35), mat_frame)
	_add_mesh_box(win, "WinMullionH", Vector3(1.14, 0.05, 0.08), Vector3(0.60, 1.65, -2.35), mat_frame)

	# 3 Tábuas pregadas em zigue-zague na janela (exatamente como na Imagem 1)
	_add_mesh_box(win, "BoardPlankTop", Vector3(1.38, 0.19, 0.05), Vector3(0.58, 1.94, -2.23), mat_plank, Vector3(0.0, 0.0, 10.5))
	_add_mesh_box(win, "BoardPlankMid", Vector3(1.36, 0.18, 0.05), Vector3(0.60, 1.61, -2.21), mat_plank, Vector3(0.0, 0.0, -15.5))
	_add_mesh_box(win, "BoardPlankBot", Vector3(1.38, 0.20, 0.05), Vector3(0.60, 1.29, -2.23), mat_plank, Vector3(0.0, 0.0, 11.0))

	# Luz direcional/spot dourada entrando pelas frestas da janela rumo ao chão à esquerda
	_window_spot = SpotLight3D.new()
	_window_spot.name = "WindowSunSpot"
	_window_spot.position = Vector3(0.65, 1.72, -2.45)
	_window_spot.light_color = Color(1.0, 0.86, 0.38)
	_window_spot.light_energy = 2.15
	_window_spot.spot_range = 5.5
	_window_spot.spot_angle = 36.0
	_window_spot.shadow_enabled = true
	win.add_child(_window_spot)
	_window_spot.look_at_from_position(_window_spot.position, Vector3(-0.35, 0.15, -0.35), Vector3.UP)

	# Feixes volumétricos diagonais de luz solar (SunShafts) descendo da janela para a esquerda
	var shaft_tex: ImageTexture = _make_sunbeam_gradient_texture()
	var shaft_configs: Array[Dictionary] = [
		{"pos": Vector3(0.10, 1.05, -1.55), "size": Vector2(0.55, 2.35), "rot": Vector3(18.0, -16.0, -28.0)},
		{"pos": Vector3(0.28, 0.98, -1.42), "size": Vector2(0.65, 2.45), "rot": Vector3(20.0, -10.0, -22.0)},
		{"pos": Vector3(0.50, 0.96, -1.35), "size": Vector2(0.52, 2.30), "rot": Vector3(22.0, -6.0, -15.0)},
		{"pos": Vector3(0.02, 1.12, -1.48), "size": Vector2(0.75, 2.40), "rot": Vector3(19.0, 22.0, -25.0)},
	]
	_shaft_mats.clear()
	for s_idx: int in range(shaft_configs.size()):
		var sc: Dictionary = shaft_configs[s_idx]
		var smat: StandardMaterial3D = StandardMaterial3D.new()
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.cull_mode = BaseMaterial3D.CULL_DISABLED
		smat.albedo_color = Color(1.0, 0.86, 0.36, 0.12 if (s_idx % 2 == 0) else 0.085)
		smat.albedo_texture = shaft_tex
		_shaft_mats.append(smat)

		var qm: QuadMesh = QuadMesh.new()
		qm.size = sc["size"] as Vector2
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "SunBeam_%d" % s_idx
		mi.mesh = qm
		mi.position = sc["pos"] as Vector3
		mi.rotation_degrees = sc["rot"] as Vector3
		mi.material_override = smat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		win.add_child(mi)

	# Partículas de poeira dourada brilhando nos raios solares
	var dust_mat: StandardMaterial3D = StandardMaterial3D.new()
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.albedo_color = Color(1.0, 0.88, 0.42, 0.78)
	dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var dust_quad: QuadMesh = QuadMesh.new()
	dust_quad.size = Vector2(0.022, 0.022)
	dust_quad.material = dust_mat

	var motes: CPUParticles3D = CPUParticles3D.new()
	motes.name = "WindowDustMotes"
	motes.position = Vector3(0.18, 1.05, -1.35)
	motes.amount = 34
	motes.lifetime = 4.5
	motes.preprocess = 2.5
	motes.mesh = dust_quad
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(0.62, 0.72, 0.55)
	motes.direction = Vector3(-0.3, -0.4, 0.2)
	motes.spread = 45.0
	motes.gravity = Vector3(0.0, -0.02, 0.0)
	motes.initial_velocity_min = 0.03
	motes.initial_velocity_max = 0.09
	win.add_child(motes)


func _build_bed_and_floor_papers() -> void:
	var left_props: Node3D = Node3D.new()
	left_props.name = "BedAndFloorPapers"
	add_child(left_props)

	var wood_tex: ImageTexture = _make_plank_wood_texture()
	var mat_bed_wood: Material = _make_psx_mat(Color(0.28, 0.18, 0.11), wood_tex, Vector2(1.0, 1.0))
	var mat_sheet: Material = _make_psx_mat(Color(0.34, 0.33, 0.26))
	var mat_pillow: Material = _make_psx_mat(Color(0.42, 0.40, 0.34))
	var mat_paper: Material = _make_psx_mat(Color(0.68, 0.64, 0.52))

	# Cama na penumbra à esquerda (atrás da lista de botões do menu)
	_add_mesh_box(left_props, "BedFrame", Vector3(1.05, 0.28, 2.1), Vector3(-1.68, 0.22, -0.75), mat_bed_wood)
	_add_mesh_box(left_props, "BedHeadboard", Vector3(1.05, 0.78, 0.10), Vector3(-1.68, 0.52, -1.76), mat_bed_wood)
	_add_mesh_box(left_props, "BedFootboard", Vector3(1.05, 0.52, 0.10), Vector3(-1.68, 0.36, 0.28), mat_bed_wood)
	_add_mesh_box(left_props, "BedMattress", Vector3(0.98, 0.22, 1.92), Vector3(-1.65, 0.42, -0.75), mat_sheet)
	_add_mesh_box(left_props, "BedBlanketDrape", Vector3(0.18, 0.38, 1.15), Vector3(-1.14, 0.32, -0.55), mat_sheet, Vector3(0.0, 0.0, -14.0))
	_add_mesh_box(left_props, "BedPillow", Vector3(0.58, 0.12, 0.34), Vector3(-1.62, 0.56, -1.48), mat_pillow, Vector3(8.0, 6.0, 0.0))

	# Folhas de papel espalhadas no chão escuro recebendo a luz da janela
	var floor_papers: Array[Dictionary] = [
		{"pos": Vector3(-0.78, 0.015, 0.62), "rot": 18.0, "sz": Vector3(0.30, 0.01, 0.22)},
		{"pos": Vector3(-0.56, 0.015, 0.05), "rot": -24.0, "sz": Vector3(0.28, 0.01, 0.21)},
		{"pos": Vector3(-0.34, 0.015, -0.42), "rot": 12.0, "sz": Vector3(0.26, 0.01, 0.20)},
		{"pos": Vector3(-0.18, 0.015, -0.82), "rot": -16.0, "sz": Vector3(0.25, 0.01, 0.19)},
		{"pos": Vector3(-0.62, 0.015, 1.05), "rot": 32.0, "sz": Vector3(0.32, 0.01, 0.24)},
	]
	for p_idx: int in range(floor_papers.size()):
		var fp: Dictionary = floor_papers[p_idx]
		_add_mesh_box(left_props, "FloorPaper_%d" % p_idx, fp["sz"] as Vector3, fp["pos"] as Vector3, mat_paper, Vector3(0.0, float(fp["rot"]), 0.0))


func _build_foreground_desk_and_props() -> void:
	var desk: Node3D = Node3D.new()
	desk.name = "ForegroundDesk"
	desk.position = Vector3(0.38, 0.0, 0.82)
	desk.rotation_degrees = Vector3(0.0, -16.0, 0.0)
	add_child(desk)

	var desk_tex: ImageTexture = _make_plank_wood_texture()
	var mat_desk: Material = _make_psx_mat(Color(0.50, 0.33, 0.18), desk_tex, Vector2(2.5, 2.0))
	var mat_desk_dark: Material = _make_psx_mat(Color(0.28, 0.18, 0.10), desk_tex, Vector2(1.5, 1.0))

	# Tampo de tábuas de madeira e estrutura da mesa no canto inferior direito
	_add_mesh_box(desk, "TableTop", Vector3(1.42, 0.07, 1.05), Vector3(0.0, 0.74, 0.0), mat_desk)
	_add_mesh_box(desk, "TableApron", Vector3(1.32, 0.12, 0.96), Vector3(0.0, 0.65, 0.0), mat_desk_dark)
	for lx: float in [-0.58, 0.58]:
		for lz: float in [-0.40, 0.40]:
			_add_mesh_box(desk, "TableLeg", Vector3(0.09, 0.70, 0.09), Vector3(lx, 0.35, lz), mat_desk_dark)

	# 1. Mapa Rabiscado da Cidade com rotas em amarelo (canto inferior direito da mesa)
	var map_tex: ImageTexture = _make_scribbled_map_texture()
	var mat_map: Material = _make_psx_mat(Color(1.0, 1.0, 1.0), map_tex, Vector2(1.0, 1.0))
	_add_mesh_box(desk, "ScribbledCityMap", Vector3(0.62, 0.008, 0.46), Vector3(0.22, 0.780, 0.20), mat_map, Vector3(0.0, -7.0, 0.0))

	# 2. Fotografia Impressa do Leo sobre a mesa (centro-esquerda da mesa, igual à Imagem 1)
	var leo_tex: ImageTexture = _make_leo_portrait_texture()
	var mat_photo: Material = _make_psx_mat(Color(1.0, 1.0, 1.0), leo_tex, Vector2(1.0, 1.0))
	_add_mesh_box(desk, "LeoPhotograph", Vector3(0.38, 0.010, 0.42), Vector3(-0.22, 0.785, 0.12), mat_photo, Vector3(1.5, 11.0, -1.2))

	# 3. Lampião a Óleo 3D Detalhado (direita da mesa)
	_build_desk_lantern(desk, Vector3(0.42, 0.775, -0.08))


func _build_desk_lantern(parent_node: Node3D, pos: Vector3) -> void:
	var l_root: Node3D = Node3D.new()
	l_root.name = "DeskLantern3D"
	l_root.position = pos
	l_root.rotation_degrees = Vector3(0.0, 14.0, 0.0)
	parent_node.add_child(l_root)

	var metal_mat: StandardMaterial3D = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.36, 0.24, 0.13)
	metal_mat.metallic = 0.65
	metal_mat.roughness = 0.45

	var dark_iron: StandardMaterial3D = StandardMaterial3D.new()
	dark_iron.albedo_color = Color(0.16, 0.11, 0.07)
	dark_iron.metallic = 0.7
	dark_iron.roughness = 0.5

	var glass_mat: StandardMaterial3D = StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(1.0, 0.78, 0.36, 0.48)
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(1.0, 0.62, 0.18)
	glass_mat.emission_energy_multiplier = 1.4

	# Base escalonada do reservatório de óleo
	_add_cyl(l_root, "BaseFoot", 0.135, 0.145, 0.025, 12, Vector3(0.0, 0.012, 0.0), dark_iron)
	_add_cyl(l_root, "OilTank", 0.115, 0.132, 0.075, 12, Vector3(0.0, 0.060, 0.0), metal_mat)
	_add_cyl(l_root, "BurnerCollar", 0.075, 0.095, 0.030, 10, Vector3(0.0, 0.110, 0.0), dark_iron)
	_add_cyl(l_root, "FillerCap", 0.022, 0.022, 0.022, 8, Vector3(-0.045, 0.098, 0.075), dark_iron)

	# Globo de vidro âmbar abaulado
	_add_cyl(l_root, "GlassBottom", 0.098, 0.072, 0.085, 12, Vector3(0.0, 0.165, 0.0), glass_mat)
	_add_cyl(l_root, "GlassTop", 0.068, 0.098, 0.095, 12, Vector3(0.0, 0.255, 0.0), glass_mat)

	# Chama interna e externa animadas
	var flame_inner_mat: StandardMaterial3D = StandardMaterial3D.new()
	flame_inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_inner_mat.albedo_color = Color(1.0, 0.96, 0.75)
	_flame_inner = _add_cyl(l_root, "FlameCore", 0.004, 0.024, 0.075, 8, Vector3(0.0, 0.175, 0.0), flame_inner_mat)

	var flame_outer_mat: StandardMaterial3D = StandardMaterial3D.new()
	flame_outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_outer_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_outer_mat.albedo_color = Color(1.0, 0.62, 0.16, 0.75)
	_flame_outer = _add_cyl(l_root, "FlameHalo", 0.008, 0.040, 0.105, 8, Vector3(0.0, 0.185, 0.0), flame_outer_mat)

	# Chapéu da chaminé e alça superior
	_add_cyl(l_root, "ChimneyNeck", 0.065, 0.068, 0.045, 10, Vector3(0.0, 0.320, 0.0), dark_iron)
	_add_cyl(l_root, "ChimneyBrim", 0.105, 0.115, 0.018, 12, Vector3(0.0, 0.345, 0.0), metal_mat)
	_add_cyl(l_root, "ChimneyCrown", 0.055, 0.078, 0.032, 10, Vector3(0.0, 0.368, 0.0), dark_iron)

	# Hastes laterais e arames de proteção do vidro
	for side_s: float in [-1.0, 1.0]:
		_add_mesh_box(l_root, "SideTube", Vector3(0.018, 0.27, 0.018), Vector3(side_s * 0.118, 0.21, 0.0), metal_mat)
		_add_mesh_box(l_root, "BailWire", Vector3(0.010, 0.16, 0.010), Vector3(side_s * 0.115, 0.42, 0.0), dark_iron, Vector3(0.0, 0.0, -side_s * 14.0))
	_add_mesh_box(l_root, "BailTopArc", Vector3(0.18, 0.012, 0.012), Vector3(0.0, 0.495, 0.0), dark_iron)
	_add_cyl(l_root, "WireGuardMid", 0.108, 0.108, 0.008, 12, Vector3(0.0, 0.21, 0.0), dark_iron)

	# Luz quente do lampião iluminando a foto do Leo, o mapa e a parede direita
	_lantern_light = OmniLight3D.new()
	_lantern_light.name = "DeskLanternOmni"
	_lantern_light.position = Vector3(-0.08, 0.24, 0.08)
	_lantern_light.light_color = Color(1.0, 0.64, 0.22)
	_lantern_light.light_energy = 1.65
	_lantern_light.omni_range = 3.6
	_lantern_light.shadow_enabled = true
	l_root.add_child(_lantern_light)


func _add_mesh_box(parent_node: Node3D, n: String, sz: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	bm.subdivide_width = clampi(int(sz.x * 2.0), 0, 6)
	bm.subdivide_depth = clampi(int(sz.z * 2.0), 0, 6)
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent_node.add_child(mi)
	return mi


func _add_cyl(parent_node: Node3D, n: String, top_r: float, bot_r: float, h: float, segs: int, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	parent_node.add_child(mi)
	return mi


func _make_psx_mat(color: Color, tex: Texture2D = null, uv_scale: Vector2 = Vector2(1.0, 1.0)) -> Material:
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
	if tex != null:
		std.albedo_texture = tex
		std.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return std


func _make_grimy_wall_texture(with_right_blotch: bool) -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9201 if with_right_blotch else 9202
	for y: int in range(64):
		var top_dark: float = clampf(float(y) / 18.0, 0.25, 1.0)
		for x: int in range(64):
			var v: float = clampf(0.76 + rng.randf_range(-0.10, 0.08), 0.32, 0.95) * top_dark
			if with_right_blotch:
				var dx: float = float(x - 36)
				var dy: float = float(y - 26)
				var blotch_d: float = sqrt(dx * dx + dy * dy) + sin(float(x) * 0.45) * 4.5 + cos(float(y) * 0.5) * 4.0
				if blotch_d < 15.5:
					v *= 0.22
			img.set_pixel(x, y, Color(v, v * 0.94, v * 0.84, 1.0))
	return ImageTexture.create_from_image(img)


func _make_dark_floor_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9203
	for y: int in range(64):
		for x: int in range(64):
			var v: float = clampf(0.58 + rng.randf_range(-0.14, 0.12), 0.24, 0.85)
			if (x + y * 2) % 19 == 0:
				v *= 0.65
			img.set_pixel(x, y, Color(v, v * 0.96, v * 0.88, 1.0))
	return ImageTexture.create_from_image(img)


func _make_plank_wood_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9204
	for y: int in range(64):
		for x: int in range(64):
			var seam: bool = (x % 12 == 0)
			var grain: float = sin(float(y) * 0.28 + float(x / 12) * 1.7) * 0.06
			var v: float = 0.36 if seam else clampf(0.84 + grain + rng.randf_range(-0.07, 0.07), 0.45, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.88, v * 0.72, 1.0))
	return ImageTexture.create_from_image(img)


func _make_sunbeam_gradient_texture() -> ImageTexture:
	var img: Image = Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y: int in range(64):
		var vy: float = 1.0 - float(y) / 63.0
		var fade_y: float = pow(clampf(vy, 0.0, 1.0), 1.25) * clampf(float(y) / 7.0, 0.0, 1.0)
		for x: int in range(32):
			var nx: float = absf(float(x) - 15.5) / 15.5
			var fade_x: float = pow(clampf(1.0 - nx, 0.0, 1.0), 1.6)
			img.set_pixel(x, y, Color(1.0, 0.92, 0.55, fade_x * fade_y))
	return ImageTexture.create_from_image(img)


func _make_leo_portrait_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y: int in range(64):
		for x: int in range(64):
			# Borda de papel fotográfico antigo
			if x < 4 or x >= 60 or y < 4 or y >= 60:
				img.set_pixel(x, y, Color(0.86, 0.80, 0.68, 1.0))
				continue
			# Fundo sépia/acinzentado manchado da foto
			var bg_v: float = 0.58 - 0.14 * (absf(float(x - 32)) / 30.0)
			var col: Color = Color(bg_v * 1.02, bg_v * 0.94, bg_v * 0.80, 1.0)

			var dx: float = float(x - 32)
			var dy: float = float(y - 27)

			# Casaco/moletom cinza escuro nos ombros (y >= 42)
			if y >= 42 and absf(dx) <= 18.0 + float(y - 42) * 0.55:
				col = Color(0.24, 0.25, 0.26, 1.0)
				if absf(dx) <= 6.5 and y < 51:
					col = Color(0.14, 0.13, 0.12, 1.0)
				elif absf(absf(dx) - 8.5) <= 1.2:
					col = Color(0.32, 0.33, 0.34, 1.0)

			# Pescoço
			if y >= 37 and y <= 44 and absf(dx) <= 5.2:
				col = Color(0.68, 0.50, 0.36, 1.0)

			# Rosto oval sombreado (Leo)
			var face_rx: float = 10.5
			var face_ry: float = 12.5
			var face_d: float = (dx * dx) / (face_rx * face_rx) + (dy * dy) / (face_ry * face_ry)
			if face_d <= 1.0:
				var shade: float = 0.94 - maxf(0.0, dx) * 0.018 - maxf(0.0, absf(dx) - 6.0) * 0.03
				col = Color(0.84 * shade, 0.64 * shade, 0.46 * shade, 1.0)
				# Sobrancelhas e olhos escuros
				if y >= 24 and y <= 25 and absf(absf(dx) - 4.4) <= 2.4:
					col = Color(0.22, 0.14, 0.09, 1.0)
				elif y >= 26 and y <= 28 and absf(absf(dx) - 4.2) <= 1.6:
					col = Color(0.12, 0.08, 0.06, 1.0)
				# Sombra do nariz e boca séria
				elif y >= 29 and y <= 32 and absf(dx - 0.5) <= 1.0:
					col = Color(0.66, 0.48, 0.34, 1.0)
				elif y == 35 and absf(dx) <= 3.2:
					col = Color(0.48, 0.30, 0.22, 1.0)

			# Cabelo castanho repartido na testa (y: 12..24)
			var hair_d: float = (dx * dx) / (11.8 * 11.8) + ((float(y - 23)) * (float(y - 23))) / (10.5 * 10.5)
			if hair_d <= 1.0 and (y <= 21 or absf(dx) >= 8.2 or (dx < -1.0 and y <= 23)):
				var h_shade: float = 0.85 + sin(float(x) * 0.7) * 0.12
				col = Color(0.28 * h_shade, 0.18 * h_shade, 0.11 * h_shade, 1.0)

			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _make_scribbled_map_texture() -> ImageTexture:
	var img: Image = Image.create(96, 72, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9205
	for y: int in range(72):
		for x: int in range(96):
			var v: float = clampf(0.76 + rng.randf_range(-0.06, 0.06), 0.58, 0.88)
			var col: Color = Color(v, v * 0.95, v * 0.84, 1.0)
			# Grade de quarteirões e becos em tinta preta/cinza
			var grid_line: bool = (x % 18 == 0) or (y % 16 == 0) or (x % 9 == 0 and y > 18 and y < 54)
			if grid_line and x > 5 and x < 90 and y > 5 and y < 66:
				col = Color(0.18, 0.17, 0.16, 1.0)
			img.set_pixel(x, y, col)

	# Rotas rabiscadas em amarelo vivo sobre o mapa (igual à Imagem 1)
	var yellow_ink: Color = Color(0.96, 0.86, 0.12, 1.0)
	for t: int in range(180):
		var u: float = float(t) / 179.0
		var px1: int = clampi(int(12.0 + u * 72.0 + sin(u * 9.0) * 8.0), 4, 91)
		var py1: int = clampi(int(16.0 + cos(u * 6.5) * 18.0 + u * 26.0), 4, 67)
		img.set_pixel(px1, py1, yellow_ink)
		img.set_pixel(clampi(px1 + 1, 0, 95), py1, yellow_ink)
		img.set_pixel(px1, clampi(py1 + 1, 0, 71), yellow_ink)
	return ImageTexture.create_from_image(img)
