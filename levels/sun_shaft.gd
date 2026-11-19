extends Node3D
## Feixe de sol falso que se alinha automaticamente à direção do DirectionalLight3D (grupo "sun_light").
## Coloque o nó na abertura por onde a luz entra (buraco no teto, janela); o feixe desce a partir dele.

const LIGHT_SHAFT_SHADER: Shader = preload("res://shaders/light_shaft.gdshader")

@export var length: float = 6.0
@export var top_radius: float = 1.3
@export var bottom_radius: float = 1.8
@export var intensity: float = 0.22
@export var shaft_color: Color = Color(1.0, 0.86, 0.52)

var _mesh_instance: MeshInstance3D


func _ready() -> void:
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = top_radius
	cyl.bottom_radius = bottom_radius
	cyl.height = length
	cyl.radial_segments = 10
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = LIGHT_SHAFT_SHADER
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("shaft_color", shaft_color)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "ShaftMesh"
	_mesh_instance.mesh = cyl
	_mesh_instance.material_override = mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.position = Vector3(0.0, -length * 0.5, 0.0)
	add_child(_mesh_instance)

	call_deferred("_align_to_sun")


func _align_to_sun() -> void:
	var light: DirectionalLight3D = get_tree().get_first_node_in_group("sun_light") as DirectionalLight3D
	if light == null:
		return
	var travel: Vector3 = (-light.global_transform.basis.z).normalized()
	var y_axis: Vector3 = -travel
	var ref: Vector3 = Vector3.FORWARD if absf(y_axis.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x_axis: Vector3 = ref.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	var keep_origin: Vector3 = global_position
	global_transform = Transform3D(Basis(x_axis, y_axis, z_axis), keep_origin)
