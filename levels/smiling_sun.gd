class_name SmilingSun
extends Node3D
## Astro macabro do Sol Sorridente no horizonte distante, sempre alinhado à DirectionalLight3D.
## Segue a posição da câmera no infinito para não sofrer paralaxe ao caminhar.

const SUN_DISTANCE: float = 130.0

var _face: Node3D
var _halo: MeshInstance3D
var _time: float = 0.0
var _sun_light: DirectionalLight3D


func _ready() -> void:
	add_to_group("smiling_sun")
	scale = Vector3.ONE * 1.45
	_build_sun_geometry()


func _process(delta: float) -> void:
	_time += delta
	if _face != null:
		var breath: float = 1.0 + sin(_time * 0.45) * 0.025
		_face.scale = Vector3(breath, breath, 1.0)
		_face.rotation.z = sin(_time * 0.21) * 0.035
	if _halo != null:
		var h: float = 1.0 + sin(_time * 0.8) * 0.06
		_halo.scale = Vector3(h, h, 1.0)

	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var cam: Camera3D = vp.get_camera_3d()
	if cam == null:
		return
	if _sun_light == null:
		_sun_light = get_tree().get_first_node_in_group("sun_light") as DirectionalLight3D
	var sun_dir: Vector3 = Vector3(0.30, 0.71, 0.64).normalized()
	if _sun_light != null:
		sun_dir = _sun_light.global_transform.basis.z.normalized()

	global_position = cam.global_position + sun_dir * SUN_DISTANCE
	if absf(sun_dir.dot(Vector3.UP)) < 0.99:
		look_at(cam.global_position, Vector3.UP)


func _build_sun_geometry() -> void:
	var disc_mat: StandardMaterial3D = StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.0, 0.0, 0.0)
	disc_mat.emission_enabled = true
	disc_mat.emission = Color(1.0, 0.84, 0.32)
	disc_mat.emission_energy_multiplier = 2.6
	disc_mat.disable_fog = true

	var dark_mat: StandardMaterial3D = StandardMaterial3D.new()
	dark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark_mat.albedo_color = Color(0.08, 0.03, 0.02, 1.0)
	dark_mat.disable_fog = true

	_face = Node3D.new()
	_face.name = "Face"
	add_child(_face)

	var disc: MeshInstance3D = MeshInstance3D.new()
	disc.name = "SunDisc"
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 9.0
	cyl.bottom_radius = 9.0
	cyl.height = 0.4
	cyl.radial_segments = 16
	disc.mesh = cyl
	disc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	disc.material_override = disc_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_face.add_child(disc)

	var eye_sizes: Array[Vector3] = [Vector3(1.8, 2.8, 0.6), Vector3(2.1, 2.2, 0.6)]
	var eye_pos: Array[Vector3] = [Vector3(-3.0, 2.3, -0.35), Vector3(3.1, 2.0, -0.35)]
	for i: int in range(2):
		var eye: MeshInstance3D = MeshInstance3D.new()
		var eye_mesh: BoxMesh = BoxMesh.new()
		eye_mesh.size = eye_sizes[i]
		eye.mesh = eye_mesh
		eye.position = eye_pos[i]
		eye.material_override = dark_mat
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_face.add_child(eye)

	var smile_points: Array[Vector3] = [
		Vector3(-4.8, 0.2, -0.35),
		Vector3(-3.3, -1.6, -0.35),
		Vector3(-1.6, -2.8, -0.35),
		Vector3(0.0, -3.2, -0.35),
		Vector3(1.6, -2.8, -0.35),
		Vector3(3.3, -1.6, -0.35),
		Vector3(4.8, 0.2, -0.35),
	]
	for idx: int in range(smile_points.size()):
		var seg: MeshInstance3D = MeshInstance3D.new()
		var seg_mesh: BoxMesh = BoxMesh.new()
		seg_mesh.size = Vector3(1.85, 0.95, 0.65)
		seg.mesh = seg_mesh
		seg.position = smile_points[idx]
		seg.material_override = dark_mat
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_face.add_child(seg)

	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 0.8, 0.35, 0.55))
	grad.set_color(1, Color(1.0, 0.6, 0.2, 0.0))
	var grad_tex: GradientTexture2D = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)
	grad_tex.width = 64
	grad_tex.height = 64

	var halo_mat: StandardMaterial3D = StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.albedo_texture = grad_tex
	halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	halo_mat.disable_fog = true

	_halo = MeshInstance3D.new()
	_halo.name = "Halo"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(46.0, 46.0)
	_halo.mesh = quad
	_halo.position = Vector3(0.0, 0.0, 0.6)
	_halo.material_override = halo_mat
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
