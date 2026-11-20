extends Node3D
## Feixe de sol falso que acompanha a direção/cor do sol e apaga totalmente à noite.

const LIGHT_SHAFT_SHADER: Shader = preload("res://shaders/light_shaft.gdshader")

@export var length: float = 6.0
@export var top_radius: float = 1.3
@export var bottom_radius: float = 1.8
@export var intensity: float = 0.22
@export var shaft_color: Color = Color(1.0, 0.86, 0.52)

var _mesh_instance: MeshInstance3D
var _mat: ShaderMaterial
var _current_intensity: float = 0.0


func _ready() -> void:
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = top_radius
	cyl.bottom_radius = bottom_radius
	cyl.height = length
	cyl.radial_segments = 10
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false

	_mat = ShaderMaterial.new()
	_mat.shader = LIGHT_SHAFT_SHADER
	_mat.set_shader_parameter("intensity", 0.0)
	_mat.set_shader_parameter("shaft_color", shaft_color)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "ShaftMesh"
	_mesh_instance.mesh = cyl
	_mesh_instance.material_override = _mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.position = Vector3(0.0, -length * 0.5, 0.0)
	_mesh_instance.visible = false
	add_child(_mesh_instance)

	call_deferred("_update_shaft", 10.0)


func _process(delta: float) -> void:
	_update_shaft(delta)


func _update_shaft(delta: float) -> void:
	if _mesh_instance == null or _mat == null or not is_inside_tree():
		return

	var day_night: Node = get_tree().get_first_node_in_group("day_night")
	var light: DirectionalLight3D = get_tree().get_first_node_in_group("sun_light") as DirectionalLight3D

	var target_intensity: float = intensity
	var target_color: Color = shaft_color

	if day_night != null and day_night.has_method("is_nighttime"):
		var night_now: bool = bool(day_night.call("is_nighttime"))
		var h: float = float(day_night.call("get_hour")) if day_night.has_method("get_hour") else 12.0
		if night_now:
			if h >= 5.25 and h < 6.0:
				var pre_t: float = clampf((h - 5.25) / 0.75, 0.0, 1.0)
				target_intensity = intensity * 0.28 * pre_t
			else:
				target_intensity = 0.0
		else:
			var dawn_fade: float = lerpf(0.28, 1.0, clampf((h - 6.0) / 1.0, 0.0, 1.0))
			var dusk_fade: float = clampf((19.0 - h) / 1.0, 0.0, 1.0)
			target_intensity = intensity * clampf(minf(dawn_fade, dusk_fade), 0.0, 1.0)

	if light != null:
		if not light.visible or light.light_energy <= 0.22:
			target_intensity = 0.0
		else:
			var energy_factor: float = clampf((light.light_energy - 0.22) / 1.13, 0.25, 1.0)
			target_intensity *= energy_factor
			target_color = shaft_color.lerp(light.light_color, 0.5)
			if target_intensity > 0.005:
				_align_to_light(light)

	if delta >= 1.0:
		_current_intensity = target_intensity
	else:
		_current_intensity = move_toward(_current_intensity, target_intensity, delta * 0.35)

	_mat.set_shader_parameter("intensity", _current_intensity)
	_mat.set_shader_parameter("shaft_color", target_color)
	_mesh_instance.visible = (_current_intensity > 0.003)


func _align_to_light(light: DirectionalLight3D) -> void:
	var travel: Vector3 = (-light.global_transform.basis.z).normalized()
	var y_axis: Vector3 = -travel
	var ref: Vector3 = Vector3.FORWARD if absf(y_axis.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x_axis: Vector3 = ref.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	var keep_origin: Vector3 = global_position
	global_transform = Transform3D(Basis(x_axis, y_axis, z_axis), keep_origin)
