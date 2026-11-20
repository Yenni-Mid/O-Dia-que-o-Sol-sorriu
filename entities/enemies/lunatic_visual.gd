class_name LunaticVisual
extends CharacterBody3D
## Constrói o visual retro low-poly do Lunático (corpo de cultista, máscara de sorriso e indicador de alerta da FSM).

var _alert_badge: MeshInstance3D
var _mat_suspicious: StandardMaterial3D
var _mat_chase: StandardMaterial3D
var _mat_stun: StandardMaterial3D
var _fsm: EnemyStateMachine
var _last_state_name: String = ""

var _cultist_body: Node3D
var _torso_pivot: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _stun_particles: CPUParticles3D
var _walk_phase: float = 0.0
var _step_triggered: bool = false
var _whisper_timer: float = 4.0

var _step_3d: AudioStreamPlayer3D
var _alert_3d: AudioStreamPlayer3D
var _whisper_3d: AudioStreamPlayer3D


func _ready() -> void:
	_fsm = get_node_or_null("StateMachine") as EnemyStateMachine
	_build_mask_and_badge()
	_setup_stun_particles()
	_setup_audio_3d()
	_whisper_timer = randf_range(4.0, 9.0)


func _exit_tree() -> void:
	_mat_suspicious = null
	_mat_chase = null
	_mat_stun = null
	_stun_particles = null
	_alert_badge = null
	_fsm = null
	_cultist_body = null
	_torso_pivot = null
	_left_arm = null
	_right_arm = null
	_left_leg = null
	_right_leg = null


func stun_from_flash(duration: float) -> void:
	if _fsm != null and _fsm.has_method("apply_flash_stun"):
		_fsm.call("apply_flash_stun", duration)
	if _stun_particles != null:
		_stun_particles.restart()
		_stun_particles.emitting = true
	if _alert_3d != null and _alert_3d.stream != null:
		_alert_3d.pitch_scale = 1.32
		_alert_3d.play()
	if _whisper_3d != null and _whisper_3d.stream != null:
		_whisper_3d.pitch_scale = 1.25
		_whisper_3d.play()


func _setup_stun_particles() -> void:
	_stun_particles = CPUParticles3D.new()
	_stun_particles.name = "FlashStunSmoke"
	_stun_particles.position = Vector3(0.0, 1.65, -0.18)
	_stun_particles.one_shot = true
	_stun_particles.explosiveness = 0.92
	_stun_particles.emitting = false
	_stun_particles.amount = 14
	_stun_particles.lifetime = 0.55
	var pm: BoxMesh = BoxMesh.new()
	pm.size = Vector3(0.07, 0.07, 0.07)
	_stun_particles.mesh = pm
	var pmat: StandardMaterial3D = StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(0.95, 0.90, 0.78)
	_stun_particles.material_override = pmat
	_stun_particles.direction = Vector3(0.0, 0.6, -0.8)
	_stun_particles.spread = 65.0
	_stun_particles.gravity = Vector3(0.0, 1.2, 0.0)
	_stun_particles.initial_velocity_min = 1.6
	_stun_particles.initial_velocity_max = 3.2
	add_child(_stun_particles)


func _setup_audio_3d() -> void:
	_step_3d = AudioStreamPlayer3D.new()
	_step_3d.name = "StepAudio3D"
	_step_3d.stream = AudioManager.get_lunatic_step_stream()
	_step_3d.max_distance = 16.0
	_step_3d.volume_db = -6.0
	add_child(_step_3d)

	_alert_3d = AudioStreamPlayer3D.new()
	_alert_3d.name = "AlertAudio3D"
	_alert_3d.stream = AudioManager.get_alert_stream()
	_alert_3d.max_distance = 24.0
	_alert_3d.volume_db = -3.0
	add_child(_alert_3d)

	_whisper_3d = AudioStreamPlayer3D.new()
	_whisper_3d.name = "WhisperAudio3D"
	_whisper_3d.stream = AudioManager.get_whisper_stream()
	_whisper_3d.max_distance = 12.0
	_whisper_3d.volume_db = -10.0
	add_child(_whisper_3d)


func _process(delta: float) -> void:
	if not visible:
		return
	var st_name: String = ""
	if _fsm != null and _fsm.current_state != null:
		st_name = _fsm.current_state.name
		if st_name != _last_state_name:
			_last_state_name = st_name
			if st_name == "SuspiciousState" or st_name == "ChaseState":
				if _alert_3d != null and _alert_3d.stream != null:
					_alert_3d.pitch_scale = randf_range(0.92, 1.08)
					_alert_3d.play()
				else:
					AudioManager.play_enemy_alert()
		if _alert_badge != null:
			if st_name == "SuspiciousState":
				_alert_badge.visible = true
				_alert_badge.material_override = _mat_suspicious
			elif st_name == "ChaseState" or st_name == "AttackState":
				_alert_badge.visible = true
				_alert_badge.material_override = _mat_chase
			else:
				_alert_badge.visible = false

	if st_name == "PatrolState" or st_name == "SuspiciousState":
		_whisper_timer -= delta
		if _whisper_timer <= 0.0:
			_whisper_timer = randf_range(5.0, 11.0)
			if _whisper_3d != null and _whisper_3d.stream != null and not _whisper_3d.playing:
				_whisper_3d.pitch_scale = randf_range(0.75, 1.05)
				_whisper_3d.play()

	var is_stunned: bool = (_fsm != null and _fsm.is_stunned())
	if _alert_badge != null and is_stunned:
		_alert_badge.visible = true
		_alert_badge.material_override = _mat_stun if ((Time.get_ticks_msec() / 90) % 2 == 0) else _mat_suspicious

	_animate_limbs(delta, st_name, is_stunned)


func _animate_limbs(delta: float, state_name: String, is_stunned: bool = false) -> void:
	if _torso_pivot == null:
		return

	if is_stunned:
		_step_triggered = false
		_torso_pivot.rotation.x = lerpf(_torso_pivot.rotation.x, 0.28, minf(1.0, 14.0 * delta))
		_torso_pivot.rotation.z = sin(Time.get_ticks_msec() * 0.055) * 0.14
		if _left_arm != null:
			_left_arm.rotation.x = lerpf(_left_arm.rotation.x, 2.35, minf(1.0, 16.0 * delta))
			_left_arm.rotation.z = lerpf(_left_arm.rotation.z, 0.45, minf(1.0, 16.0 * delta))
		if _right_arm != null:
			_right_arm.rotation.x = lerpf(_right_arm.rotation.x, 2.35, minf(1.0, 16.0 * delta))
			_right_arm.rotation.z = lerpf(_right_arm.rotation.z, -0.45, minf(1.0, 16.0 * delta))
		return

	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	var is_chasing: bool = (state_name == "ChaseState" or state_name == "AttackState")

	var target_lean: float = -0.22 if is_chasing else (-0.06 if horiz_speed > 0.2 else 0.0)
	_torso_pivot.rotation.x = lerpf(_torso_pivot.rotation.x, target_lean, minf(1.0, 8.0 * delta))
	_torso_pivot.rotation.z = lerpf(_torso_pivot.rotation.z, 0.0, minf(1.0, 10.0 * delta))
	if _left_arm != null:
		_left_arm.rotation.z = lerpf(_left_arm.rotation.z, 0.0, minf(1.0, 10.0 * delta))
	if _right_arm != null:
		_right_arm.rotation.z = lerpf(_right_arm.rotation.z, 0.0, minf(1.0, 10.0 * delta))

	if horiz_speed > 0.2:
		_walk_phase += delta * horiz_speed * 2.8
		var sin_phase: float = sin(_walk_phase)
		var leg_swing: float = sin_phase * 0.55
		var arm_swing: float = sin_phase * 0.42
		if absf(sin_phase) > 0.88:
			if not _step_triggered:
				_step_triggered = true
				if _step_3d != null and _step_3d.stream != null:
					_step_3d.pitch_scale = randf_range(0.85, 1.1)
					_step_3d.play()
		else:
			_step_triggered = false
		if _left_leg != null:
			_left_leg.rotation.x = leg_swing
		if _right_leg != null:
			_right_leg.rotation.x = -leg_swing
		if _left_arm != null:
			_left_arm.rotation.x = (0.85 if is_chasing else 0.0) - arm_swing
		if _right_arm != null:
			_right_arm.rotation.x = (0.85 if is_chasing else 0.0) + arm_swing
	else:
		_step_triggered = false
		var idle_sway: float = sin(Time.get_ticks_msec() * 0.003) * 0.05
		if _left_leg != null:
			_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.0, minf(1.0, 8.0 * delta))
		if _right_leg != null:
			_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.0, minf(1.0, 8.0 * delta))
		if _left_arm != null:
			var target_arm_l: float = 0.75 + idle_sway if is_chasing else idle_sway
			_left_arm.rotation.x = lerpf(_left_arm.rotation.x, target_arm_l, minf(1.0, 8.0 * delta))
		if _right_arm != null:
			var target_arm_r: float = 0.75 - idle_sway if is_chasing else -idle_sway
			_right_arm.rotation.x = lerpf(_right_arm.rotation.x, target_arm_r, minf(1.0, 8.0 * delta))


func _make_psx_mat(color: Color) -> Material:
	var shader: Shader = load("res://shaders/psx_lit.gdshader") as Shader
	if shader != null:
		var smat: ShaderMaterial = ShaderMaterial.new()
		smat.shader = shader
		smat.set_shader_parameter("modulate_color", color)
		smat.set_shader_parameter("jitter_intensity", 0.55)
		return smat
	var std: StandardMaterial3D = StandardMaterial3D.new()
	std.albedo_color = color
	return std


func _create_box_part(parent_node: Node3D, part_name: String, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = part_name
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.position = pos
	mesh_inst.rotation_degrees = rot_deg
	mesh_inst.material_override = mat
	parent_node.add_child(mesh_inst)
	return mesh_inst


func _build_mask_and_badge() -> void:
	var base_capsule: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if base_capsule != null:
		base_capsule.visible = false

	var robe_tex: ImageTexture = CultistVisualBuilder.make_robe_texture(711)
	var mask_tex: ImageTexture = CultistVisualBuilder.make_mask_texture(Color(0.88, 0.78, 0.46), Color(0.68, 0.08, 0.07))

	var coat_mat: Material = CultistVisualBuilder.make_psx_mat(Color(0.48, 0.41, 0.32), robe_tex)
	var shawl_mat: Material = CultistVisualBuilder.make_psx_mat(Color(0.32, 0.28, 0.23), robe_tex)
	var hood_mat: Material = CultistVisualBuilder.make_psx_mat(Color(0.10, 0.09, 0.10), robe_tex)
	var belt_mat: Material = CultistVisualBuilder.make_psx_mat(Color(0.18, 0.13, 0.10))
	var pants_mat: Material = CultistVisualBuilder.make_psx_mat(Color(0.13, 0.12, 0.14))
	var skin_mat: Material = CultistVisualBuilder.make_psx_mat(Color(0.58, 0.50, 0.42))
	var mask_mat: Material = CultistVisualBuilder.make_psx_mat(Color(0.95, 0.92, 0.85), mask_tex)

	_mat_suspicious = StandardMaterial3D.new()
	_mat_suspicious.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_suspicious.albedo_color = Color(1.0, 0.85, 0.15)

	_mat_chase = StandardMaterial3D.new()
	_mat_chase.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_chase.albedo_color = Color(1.0, 0.15, 0.12)

	_mat_stun = StandardMaterial3D.new()
	_mat_stun.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_stun.albedo_color = Color(1.0, 0.98, 0.85)

	_cultist_body = Node3D.new()
	_cultist_body.name = "CultistBody"
	add_child(_cultist_body)

	# Pernas com barra de túnica esfarrapada em cima (pivô no quadril em y = 0.72)
	_left_leg = Node3D.new()
	_left_leg.name = "LeftLeg"
	_left_leg.position = Vector3(-0.14, 0.72, 0.0)
	_cultist_body.add_child(_left_leg)
	_create_box_part(_left_leg, "LegMesh", Vector3(0.19, 0.72, 0.21), Vector3(0.0, -0.36, 0.0), pants_mat)
	_create_box_part(_left_leg, "TunicFlapL", Vector3(0.24, 0.48, 0.26), Vector3(0.0, -0.22, 0.0), coat_mat, Vector3(0.0, 0.0, 3.0))

	_right_leg = Node3D.new()
	_right_leg.name = "RightLeg"
	_right_leg.position = Vector3(0.14, 0.72, 0.0)
	_cultist_body.add_child(_right_leg)
	_create_box_part(_right_leg, "LegMesh", Vector3(0.19, 0.72, 0.21), Vector3(0.0, -0.36, 0.0), pants_mat)
	_create_box_part(_right_leg, "TunicFlapR", Vector3(0.24, 0.46, 0.26), Vector3(0.0, -0.21, 0.0), coat_mat, Vector3(0.0, 0.0, -3.0))

	# Tronco + xale rasgado + capuz + máscara (pivô na cintura em y = 0.72)
	_torso_pivot = Node3D.new()
	_torso_pivot.name = "TorsoPivot"
	_torso_pivot.position = Vector3(0.0, 0.72, 0.0)
	_cultist_body.add_child(_torso_pivot)

	_create_box_part(_torso_pivot, "TorsoCoat", Vector3(0.54, 0.68, 0.31), Vector3(0.0, 0.34, 0.0), coat_mat)
	CultistVisualBuilder.attach_shawl_and_belt(_torso_pivot, 0.36, shawl_mat, belt_mat)
	CultistVisualBuilder.attach_hood_and_mask(_torso_pivot, 0.88, hood_mat, mask_mat, Color(0.92, 0.82, 0.50), false)

	# Mangas largas + mãos (pivô nos ombros)
	_left_arm = Node3D.new()
	_left_arm.name = "LeftArm"
	_left_arm.position = Vector3(-0.36, 0.62, 0.0)
	_torso_pivot.add_child(_left_arm)
	_create_box_part(_left_arm, "ArmMesh", Vector3(0.18, 0.56, 0.20), Vector3(0.0, -0.25, 0.0), coat_mat)
	_create_box_part(_left_arm, "HandMesh", Vector3(0.12, 0.14, 0.13), Vector3(0.0, -0.58, 0.0), skin_mat)

	_right_arm = Node3D.new()
	_right_arm.name = "RightArm"
	_right_arm.position = Vector3(0.36, 0.62, 0.0)
	_torso_pivot.add_child(_right_arm)
	_create_box_part(_right_arm, "ArmMesh", Vector3(0.18, 0.56, 0.20), Vector3(0.0, -0.25, 0.0), coat_mat)
	_create_box_part(_right_arm, "HandMesh", Vector3(0.12, 0.14, 0.13), Vector3(0.0, -0.58, 0.0), skin_mat)

	_alert_badge = MeshInstance3D.new()
	_alert_badge.name = "AlertBadge"
	var b_box: BoxMesh = BoxMesh.new()
	b_box.size = Vector3(0.12, 0.36, 0.12)
	_alert_badge.mesh = b_box
	_alert_badge.position = Vector3(0.0, 2.25, 0.0)
	_alert_badge.visible = false
	add_child(_alert_badge)
