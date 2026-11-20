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
var _flame_outer_mesh: MeshInstance3D
var _last_emitted_oil: float = -1.0

@onready var lantern_mesh: MeshInstance3D = get_node_or_null("LanternMesh") as MeshInstance3D
@onready var omni_light: OmniLight3D = get_node_or_null("OmniLight3D") as OmniLight3D
@onready var safe_zone_area: Area3D = get_node_or_null("SafeZoneArea") as Area3D


func _ready() -> void:
	add_to_group("lantern")
	_ensure_input_actions()
	_configure_noise()
	_configure_nodes()
	current_oil = clampf(current_oil, 0.0, max_oil)
	_apply_lantern_state()
	_emit_oil()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_lantern"):
		toggle_lantern()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Animação tátil de erguer/abaixar o lampião
	var target_y: float = 0.0 if is_lit else -0.08
	var target_tilt: float = 0.04 if is_lit else -0.14
	position.y = lerpf(position.y, target_y, clampf(10.0 * delta, 0.0, 1.0))
	rotation.x = lerpf(rotation.x, target_tilt, clampf(10.0 * delta, 0.0, 1.0))

	if not is_lit:
		return

	current_oil = maxf(0.0, current_oil - burn_rate * delta)
	# Emite a mudança de óleo só quando ela é perceptível (evita sinal + redraw da HUD a cada frame).
	if absf(current_oil - _last_emitted_oil) >= 0.25 or current_oil <= 0.0:
		_emit_oil()

	_noise_time += delta
	var noise_sample: float = clampf((_noise.get_noise_1d(_noise_time * flicker_speed) + 1.0) * 0.5, 0.0, 1.0)
	if omni_light != null:
		# Abaixo de 20% de óleo a chama fica instável e mais fraca.
		var oil_ratio: float = current_oil / maxf(max_oil, 0.001)
		var starving: float = clampf((0.2 - oil_ratio) / 0.2, 0.0, 1.0)
		var energy: float = lerpf(MIN_FLICKER_ENERGY, MAX_FLICKER_ENERGY, noise_sample)
		energy *= lerpf(1.0, 0.55 + 0.45 * noise_sample, starving)
		omni_light.light_energy = energy
	if _flame_mesh != null:
		var flame_scale: float = 0.8 + noise_sample * 0.45
		_flame_mesh.scale = Vector3(1.0, flame_scale, 1.0)
	if _flame_outer_mesh != null:
		var outer_scale: float = 0.85 + noise_sample * 0.35
		_flame_outer_mesh.scale = Vector3(1.0, outer_scale, 1.0)

	if current_oil <= 0.0:
		current_oil = 0.0
		set_lantern_lit(false)
		if extinguish_audio != null:
			extinguish_audio.play()
		GameEvents.lantern_depleted.emit()


func _emit_oil() -> void:
	_last_emitted_oil = current_oil
	GameEvents.oil_changed.emit(current_oil, max_oil)


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
	if is_zero_approx(amount):
		return
	current_oil = clampf(current_oil + amount, 0.0, max_oil)
	_emit_oil()


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
	if _flame_outer_mesh != null:
		_flame_outer_mesh.visible = is_lit
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
	metal_mat.albedo_color = Color(0.28, 0.21, 0.16)
	metal_mat.roughness = 0.72

	var brass_mat: StandardMaterial3D = StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.58, 0.40, 0.19)
	brass_mat.roughness = 0.60

	var skin_mat: StandardMaterial3D = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.72, 0.56, 0.44)
	skin_mat.roughness = 0.85

	var sleeve_mat: StandardMaterial3D = StandardMaterial3D.new()
	sleeve_mat.albedo_color = Color(0.24, 0.21, 0.16)
	sleeve_mat.roughness = 0.9

	var tank_mesh: CylinderMesh = CylinderMesh.new()
	tank_mesh.top_radius = 0.070
	tank_mesh.bottom_radius = 0.078
	tank_mesh.height = 0.068
	tank_mesh.radial_segments = 8
	_add_lantern_part("TankBase", tank_mesh, Vector3(0.0, -0.09, 0.0), brass_mat)

	var rim_mesh: CylinderMesh = CylinderMesh.new()
	rim_mesh.top_radius = 0.066
	rim_mesh.bottom_radius = 0.070
	rim_mesh.height = 0.022
	rim_mesh.radial_segments = 8
	_add_lantern_part("RimTop", rim_mesh, Vector3(0.0, 0.072, 0.0), metal_mat)

	var mid_ring: CylinderMesh = CylinderMesh.new()
	mid_ring.top_radius = 0.058
	mid_ring.bottom_radius = 0.058
	mid_ring.height = 0.012
	mid_ring.radial_segments = 8
	_add_lantern_part("GuardRingMid", mid_ring, Vector3(0.0, 0.0, 0.0), brass_mat)

	var cap_mesh: CylinderMesh = CylinderMesh.new()
	cap_mesh.top_radius = 0.026
	cap_mesh.bottom_radius = 0.074
	cap_mesh.height = 0.052
	cap_mesh.radial_segments = 8
	_add_lantern_part("CapCone", cap_mesh, Vector3(0.0, 0.108, 0.0), brass_mat)

	var chimney_mesh: CylinderMesh = CylinderMesh.new()
	chimney_mesh.top_radius = 0.032
	chimney_mesh.bottom_radius = 0.024
	chimney_mesh.height = 0.024
	chimney_mesh.radial_segments = 8
	_add_lantern_part("ChimneyCap", chimney_mesh, Vector3(0.0, 0.140, 0.0), metal_mat)

	var strut_mesh: BoxMesh = BoxMesh.new()
	strut_mesh.size = Vector3(0.012, 0.155, 0.012)
	_add_lantern_part("StrutLeft", strut_mesh, Vector3(-0.062, -0.005, 0.0), metal_mat)
	_add_lantern_part("StrutRight", strut_mesh, Vector3(0.062, -0.005, 0.0), metal_mat)
	_add_lantern_part("StrutFront", strut_mesh, Vector3(0.0, -0.005, -0.062), metal_mat)
	_add_lantern_part("StrutBack", strut_mesh, Vector3(0.0, -0.005, 0.062), metal_mat)

	var handle_top: BoxMesh = BoxMesh.new()
	handle_top.size = Vector3(0.115, 0.012, 0.012)
	_add_lantern_part("HandleTop", handle_top, Vector3(0.0, 0.158, 0.0), brass_mat)

	# Mão e manga segurando a alça superior em 1ª pessoa (estilo PS1)
	var hand_group: Node3D = Node3D.new()
	hand_group.name = "HandGroup"
	hand_group.position = Vector3(0.035, 0.178, 0.035)
	hand_group.rotation_degrees = Vector3(-16.0, -18.0, -14.0)
	lantern_mesh.add_child(hand_group)

	var palm_b: BoxMesh = BoxMesh.new()
	palm_b.size = Vector3(0.088, 0.044, 0.072)
	_add_part_to(hand_group, "HandPalm", palm_b, Vector3(0.0, 0.0, 0.012), skin_mat)

	var finger_b: BoxMesh = BoxMesh.new()
	finger_b.size = Vector3(0.082, 0.026, 0.038)
	_add_part_to(hand_group, "FingerGrip", finger_b, Vector3(-0.01, -0.026, -0.018), skin_mat)

	var thumb_b: BoxMesh = BoxMesh.new()
	thumb_b.size = Vector3(0.032, 0.024, 0.048)
	_add_part_to(hand_group, "ThumbGrip", thumb_b, Vector3(-0.042, -0.010, 0.008), skin_mat)

	var sleeve_b: BoxMesh = BoxMesh.new()
	sleeve_b.size = Vector3(0.095, 0.082, 0.19)
	_add_part_to(hand_group, "CoatSleeve", sleeve_b, Vector3(0.045, 0.005, 0.125), sleeve_mat)

	# Chama em duas camadas (halo âmbar + núcleo brilhante)
	var flame_outer_box: BoxMesh = BoxMesh.new()
	flame_outer_box.size = Vector3(0.036, 0.056, 0.036)
	var flame_outer_mat: StandardMaterial3D = StandardMaterial3D.new()
	flame_outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_outer_mat.albedo_color = Color(1.0, 0.56, 0.14)
	_flame_outer_mesh = _add_lantern_part("FlameOuter", flame_outer_box, Vector3(0.0, -0.005, 0.0), flame_outer_mat)
	_flame_outer_mesh.visible = false

	var flame_box: BoxMesh = BoxMesh.new()
	flame_box.size = Vector3(0.020, 0.038, 0.020)
	var flame_mat: StandardMaterial3D = StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(1.0, 0.92, 0.52)
	_flame_mesh = _add_lantern_part("FlameCore", flame_box, Vector3(0.0, -0.010, 0.0), flame_mat)
	_flame_mesh.visible = false


func _add_part_to(parent_n: Node3D, part_name: String, mesh_res: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh_res
	part.position = pos
	part.material_override = mat
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent_n.add_child(part)
	return part


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
