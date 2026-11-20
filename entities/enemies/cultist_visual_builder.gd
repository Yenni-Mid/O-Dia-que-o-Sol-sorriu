class_name CultistVisualBuilder
extends RefCounted
## Construtor compartilhado do visual PS1 de cultistas encapuzados (capuz em camadas, xale esfarrapado,
## túnica com cinto, máscara inclinada com lágrimas negras, sorriso rasgado e leve brilho ocular no breu).

const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")


static func make_robe_texture(seed_val: int = 710) -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	for y: int in range(64):
		var fold_base: float = sin(float(y) * 0.12) * 0.04
		var hem_grime: float = clampf(float(y - 44) / 20.0, 0.0, 1.0) * 0.34
		for x: int in range(64):
			var vert_fold: float = sin(float(x) * 0.55) * 0.11 + cos(float(x) * 1.15) * 0.05
			var weave: float = -0.05 if ((x + y) % 4 == 0) else 0.03
			var tear_notch: bool = (y >= 54 and ((x * 5 + y) % 13 < 4))
			var v: float = clampf(0.84 + vert_fold + fold_base + weave + rng.randf_range(-0.07, 0.07) - hem_grime, 0.28, 1.0)
			if tear_notch:
				v *= 0.48
			img.set_pixel(x, y, Color(v, v * 0.96, v * 0.90, 1.0))
	return ImageTexture.create_from_image(img)


static func make_mask_texture(base_col: Color, smile_col: Color) -> ImageTexture:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1710
	for y: int in range(32):
		for x: int in range(32):
			var dx: float = float(x) - 15.5
			var dy: float = float(y) - 15.5
			var edge_shade: float = clampf(1.0 - (absf(dx) / 16.0) * 0.32 - (absf(dy) / 16.0) * 0.22, 0.55, 1.0)
			var grime: float = rng.randf_range(-0.06, 0.05)
			var c: Color = Color(
				clampf(base_col.r * edge_shade + grime, 0.0, 1.0),
				clampf(base_col.g * edge_shade + grime, 0.0, 1.0),
				clampf(base_col.b * edge_shade + grime, 0.0, 1.0),
				1.0
			)

			# Risco central do nariz/sombra vertical sutil
			if absf(dx) <= 1.1 and y >= 12 and y <= 18:
				c = c.darkened(0.22)

			# Órbitas pretas fundas + lágrimas negras escorrendo pelas bochechas
			var left_eye_d: float = Vector2((dx + 5.2) / 2.6, (dy + 2.8) / 3.2).length()
			var right_eye_d: float = Vector2((dx - 5.2) / 2.6, (dy + 2.8) / 3.2).length()
			if left_eye_d <= 1.0 or right_eye_d <= 1.0:
				c = Color(0.03, 0.02, 0.02, 1.0)
			elif y >= 15 and y <= 24:
				var streak_l: float = absf(dx + 5.2 - sin(float(y) * 0.6) * 0.5)
				var streak_r: float = absf(dx - 5.2 + cos(float(y) * 0.5) * 0.5)
				if (streak_l <= 0.85 and y <= 23) or (streak_r <= 0.85 and y <= 22):
					var fade_t: float = clampf(1.0 - float(y - 15) / 10.0, 0.25, 0.95)
					c = c.lerp(Color(0.05, 0.03, 0.03, 1.0), fade_t)

			# Sorriso vermelho rasgado subindo até as têmporas
			var smile_y: float = 7.4 - (dx * dx) * 0.052
			if absf(dx) <= 10.6 and absf(dy - smile_y) <= 1.45:
				c = smile_col
			elif absf(dx) <= 10.8 and absf(dy - (smile_y - 1.5)) <= 0.65 and (int(absf(dx)) % 3 == 0):
				c = Color(0.14, 0.04, 0.04, 1.0)

			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func make_psx_mat(color: Color, tex: Texture2D = null, uv_scale: Vector2 = Vector2(1.0, 1.0)) -> Material:
	if PSX_LIT_SHADER != null:
		var smat: ShaderMaterial = ShaderMaterial.new()
		smat.shader = PSX_LIT_SHADER
		smat.set_shader_parameter("modulate_color", color)
		smat.set_shader_parameter("uv_scale", uv_scale)
		smat.set_shader_parameter("jitter_intensity", 0.55)
		smat.set_shader_parameter("snap_resolution", Vector2(320.0, 180.0))
		if tex != null:
			smat.set_shader_parameter("albedo_texture", tex)
		return smat
	var std: StandardMaterial3D = StandardMaterial3D.new()
	std.albedo_color = color
	if tex != null:
		std.albedo_texture = tex
	return std


static func add_box(parent_n: Node3D, p_name: String, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.name = p_name
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.rotation_degrees = rot_deg
	m.material_override = mat
	parent_n.add_child(m)
	return m


static func attach_hood_and_mask(
	head_parent: Node3D,
	head_y: float,
	hood_mat: Material,
	mask_mat: Material,
	glint_color: Color = Color(0.90, 0.80, 0.52),
	tall_peak: bool = false
) -> void:
	# Capuz em camadas envolvendo a cabeça na sombra
	add_box(head_parent, "HoodBack", Vector3(0.42, 0.44, 0.34), Vector3(0.0, head_y, 0.04), hood_mat)
	add_box(head_parent, "HoodTop", Vector3(0.44, 0.14, 0.42), Vector3(0.0, head_y + 0.22, 0.0), hood_mat, Vector3(-6.0, 0.0, 0.0))
	add_box(head_parent, "HoodSideL", Vector3(0.08, 0.40, 0.36), Vector3(-0.20, head_y - 0.01, -0.02), hood_mat)
	add_box(head_parent, "HoodSideR", Vector3(0.08, 0.40, 0.36), Vector3(0.20, head_y - 0.01, -0.02), hood_mat)
	if tall_peak:
		add_box(head_parent, "HoodPeak", Vector3(0.28, 0.24, 0.28), Vector3(0.0, head_y + 0.34, 0.05), hood_mat, Vector3(-14.0, 0.0, 0.0))

	# Máscara inclinada com textura detalhada + dois pontinhos de brilho ocular no breu
	var mask_plate: MeshInstance3D = add_box(
		head_parent,
		"CardboardMask",
		Vector3(0.36, 0.40, 0.045),
		Vector3(0.0, head_y - 0.01, -0.155),
		mask_mat,
		Vector3(2.0, 0.0, -5.5)
	)
	var glint_mat: StandardMaterial3D = StandardMaterial3D.new()
	glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glint_mat.albedo_color = glint_color
	add_box(mask_plate, "EyeGlintL", Vector3(0.024, 0.024, 0.012), Vector3(-0.06, 0.036, -0.024), glint_mat)
	add_box(mask_plate, "EyeGlintR", Vector3(0.024, 0.024, 0.012), Vector3(0.06, 0.036, -0.024), glint_mat)


static func attach_shawl_and_belt(
	torso_parent: Node3D,
	torso_center_y: float,
	shawl_mat: Material,
	belt_mat: Material
) -> void:
	# Xale/capa irregular sobre ombros e peito (pontas rasgadas)
	add_box(torso_parent, "ShawlMain", Vector3(0.60, 0.20, 0.36), Vector3(0.0, torso_center_y + 0.24, 0.0), shawl_mat)
	add_box(torso_parent, "ShawlTatterL", Vector3(0.18, 0.18, 0.06), Vector3(-0.19, torso_center_y + 0.12, -0.165), shawl_mat, Vector3(0.0, 0.0, 12.0))
	add_box(torso_parent, "ShawlTatterM", Vector3(0.18, 0.22, 0.06), Vector3(0.0, torso_center_y + 0.10, -0.170), shawl_mat, Vector3(0.0, 0.0, -6.0))
	add_box(torso_parent, "ShawlTatterR", Vector3(0.18, 0.17, 0.06), Vector3(0.19, torso_center_y + 0.13, -0.165), shawl_mat, Vector3(0.0, 0.0, -14.0))
	# Cinto de pano/corda na cintura
	add_box(torso_parent, "RopeBelt", Vector3(0.56, 0.09, 0.34), Vector3(0.0, torso_center_y - 0.28, 0.0), belt_mat)
