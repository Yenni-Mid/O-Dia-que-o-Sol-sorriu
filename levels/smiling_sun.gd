class_name SmilingSun
extends Node3D
## Astro macabro do Sol Sorridente posicionado no céu na direção da luz solar.


func _ready() -> void:
	_build_sun_geometry()


func _build_sun_geometry() -> void:
	var disc_mat: StandardMaterial3D = StandardMaterial3D.new()
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.albedo_color = Color(1.0, 0.86, 0.28, 1.0)

	var dark_mat: StandardMaterial3D = StandardMaterial3D.new()
	dark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark_mat.albedo_color = Color(0.08, 0.03, 0.02, 1.0)

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
	add_child(disc)

	# Olhos escuros vazios (voltados para -Z, em direção ao jogador)
	for side: float in [-1.0, 1.0]:
		var eye: MeshInstance3D = MeshInstance3D.new()
		var eye_mesh: BoxMesh = BoxMesh.new()
		eye_mesh.size = Vector3(1.8, 2.6, 0.6)
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 3.0, 2.2, -0.35)
		eye.material_override = dark_mat
		add_child(eye)

	# Sorriso macabro estático (segmentos em arco)
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
		add_child(seg)
