class_name LanternSystem
extends Node3D
## Sistema do lampião a óleo (Fogo Humano) que ilumina o ambiente, repele Sombras Vivas e afeta furtividade.

const VISIBILITY_BONUS_LIT: float = 15.0
const MIN_FLICKER_ENERGY: float = 1.2
const MAX_FLICKER_ENERGY: float = 1.5
const LAYER_LANTERN_LIGHT: int = 1 << 4 # Layer 5
const MASK_ENEMIES_AND_SHADOWS: int = (1 << 2) | (1 << 5) # Layers 3 e 6

@export var max_oil: float = 100.0
@export var burn_rate: float = 1.2
@export var flicker_speed: float = 8.0
@export var extinguish_audio: AudioStreamPlayer3D

var current_oil: float = 100.0
var is_lit: bool = false
var visibility_bonus: float = 0.0

var _noise: FastNoiseLite = FastNoiseLite.new()
var _noise_time: float = 0.0
var _glass_mat: StandardMaterial3D
var _flame_mesh: MeshInstance3D

@onready var lantern_mesh: MeshInstance3D = get_node_or_null("LanternMesh") as MeshInstance3D
@onready var omni_light: OmniLight3D = get_node_or_null("OmniLight3D") as OmniLight3D
@onready var safe_zone_area: Area3D = get_node_or_null("SafeZoneArea") as Area3D


func _ready() -> void:
	_ensure_input_actions()
	_configure_noise()
	_configure_nodes()
	current_oil = clampf(current_oil, 0.0, max_oil)
	_apply_lantern_state()
	GameEvents.oil_changed.emit(current_oil, max_oil)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_lantern"):
		toggle_lantern()


func _process(delta: float) -> void:
	if not is_lit:
		return

	current_oil = maxf(0.0, current_oil - burn_rate * delta)
	GameEvents.oil_changed.emit(current_oil, max_oil)

	_noise_time += delta
	if omni_light != null:
		var noise_sample: float = (_noise.get_noise_1d(_noise_time * flicker_speed) + 1.0) * 0.5
		omni_light.light_energy = lerpf(MIN_FLICKER_ENERGY, MAX_FLICKER_ENERGY, clampf(noise_sample, 0.0, 1.0))

	if current_oil <= 0.0:
		current_oil = 0.0
		set_lantern_lit(false)
		if extinguish_audio != null:
			extinguish_audio.play()
		GameEvents.lantern_depleted.emit()


func toggle_lantern() -> void:
	if is_lit:
		set_lantern_lit(false)
	elif current_oil > 0.0:
		set_lantern_lit(true)


func set_lantern_lit(lit: bool) -> void:
	var next_state: bool = lit and current_oil > 0.0
	if is_lit == next_state:
		_apply_lantern_state()
		return
	is_lit = next_state
	_apply_lantern_state()
	if is_lit:
		AudioManager.play_lantern_ignite()
	else:
		AudioManager.play_lantern_extinguish()
	GameEvents.lantern_toggled.emit(is_lit)


func add_oil(amount: float) -> void:
	if amount <= 0.0:
		return
	current_oil = clampf(current_oil + amount, 0.0, max_oil)
	GameEvents.oil_changed.emit(current_oil, max_oil)


func get_visibility_bonus() -> float:
	return visibility_bonus


func _apply_lantern_state() -> void:
	visibility_bonus = VISIBILITY_BONUS_LIT if is_lit else 0.0
	if omni_light != null:
		omni_light.visible = is_lit
		if not is_lit:
			omni_light.light_energy = MIN_FLICKER_ENERGY
	if _glass_mat != null:
		_glass_mat.emission_enabled = is_lit
		_glass_mat.albedo_color = Color(1.0, 0.85, 0.55, 0.72) if is_lit else Color(0.32, 0.34, 0.34, 0.55)
	if _flame_mesh != null:
		_flame_mesh.visible = is_lit
	if safe_zone_area != null:
		safe_zone_area.monitoring = is_lit
		safe_zone_area.monitorable = is_lit


func _configure_noise() -> void:
	_noise.seed = int(Time.get_ticks_usec() & 0x7FFFFFFF)
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 0.35


func _configure_nodes() -> void:
	if omni_light != null:
		omni_light.light_color = Color("#ff9d3b")
		omni_light.omni_range = 6.5
		omni_light.omni_attenuation = 1.5
		omni_light.shadow_enabled = true
	if safe_zone_area != null:
		safe_zone_area.collision_layer = LAYER_LANTERN_LIGHT
		safe_zone_area.collision_mask = MASK_ENEMIES_AND_SHADOWS
	if lantern_mesh != null:
		_build_lantern_model()


func _build_lantern_model() -> void:
	for child: Node in lantern_mesh.get_children():
		child.queue_free()

	lantern_mesh.position = Vector3(0.0, 0.04, 0.0)
	lantern_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var glass_cyl: CylinderMesh = CylinderMesh.new()
	glass_cyl.top_radius = 0.048
	glass_cyl.bottom_radius = 0.052
	glass_cyl.height = 0.12
	glass_cyl.radial_segments = 8
	glass_cyl.rings = 1
	lantern_mesh.mesh = glass_cyl

	_glass_mat = StandardMaterial3D.new()
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.albedo_color = Color(0.32, 0.34, 0.34, 0.55)
	_glass_mat.emission = Color(1.0, 0.62, 0.18)
	_glass_mat.emission_energy_multiplier = 1.4
	_glass_mat.emission_enabled = false
	lantern_mesh.material_override = _glass_mat

	var metal_mat: StandardMaterial3D = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.24, 0.18, 0.14)
	metal_mat.roughness = 0.75

	var brass_mat: StandardMaterial3D = StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.45, 0.32, 0.16)
	brass_mat.roughness = 0.65

	var tank_mesh: CylinderMesh = CylinderMesh.new()
	tank_mesh.top_radius = 0.068
	tank_mesh.bottom_radius = 0.076
	tank_mesh.height = 0.065
	tank_mesh.radial_segments = 8
	_add_lantern_part("TankBase", tank_mesh, Vector3(0.0, -0.09, 0.0), brass_mat)

	var rim_mesh: CylinderMesh = CylinderMesh.new()
	rim_mesh.top_radius = 0.062
	rim_mesh.bottom_radius = 0.066
	rim_mesh.height = 0.02
	rim_mesh.radial_segments = 8
	_add_lantern_part("RimTop", rim_mesh, Vector3(0.0, 0.07, 0.0), metal_mat)

	var cap_mesh: CylinderMesh = CylinderMesh.new()
	cap_mesh.top_radius = 0.022
	cap_mesh.bottom_radius = 0.070
	cap_mesh.height = 0.048
	cap_mesh.radial_segments = 8
	_add_lantern_part("CapCone", cap_mesh, Vector3(0.0, 0.105, 0.0), metal_mat)

	var strut_mesh: BoxMesh = BoxMesh.new()
	strut_mesh.size = Vector3(0.011, 0.15, 0.012)
	_add_lantern_part("StrutLeft", strut_mesh, Vector3(-0.060, -0.005, 0.0), metal_mat)
	_add_lantern_part("StrutRight", strut_mesh, Vector3(0.060, -0.005, 0.0), metal_mat)

	var handle_top: BoxMesh = BoxMesh.new()
	handle_top.size = Vector3(0.11, 0.012, 0.012)
	_add_lantern_part("HandleTop", handle_top, Vector3(0.0, 0.145, 0.0), brass_mat)

	var flame_box: BoxMesh = BoxMesh.new()
	flame_box.size = Vector3(0.022, 0.042, 0.022)
	var flame_mat: StandardMaterial3D = StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(1.0, 0.78, 0.25)
	_flame_mesh = _add_lantern_part("FlameCore", flame_box, Vector3(0.0, -0.008, 0.0), flame_mat)
	_flame_mesh.visible = false


func _add_lantern_part(part_name: String, mesh_res: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh_res
	part.position = pos
	part.material_override = mat
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lantern_mesh.add_child(part)
	return part


func _ensure_input_actions() -> void:
	if InputMap.has_action("toggle_lantern"):
		return
	InputMap.add_action("toggle_lantern")
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = KEY_F
	InputMap.action_add_event("toggle_lantern", key_event)

	var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("toggle_lantern", mouse_event)
