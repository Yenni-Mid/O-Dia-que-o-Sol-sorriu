extends CharacterBody3D
## Novo arquétipo de inimigo noturno: O Pregador / Vigia.
## Aparece somente à noite; ao avistar a luz do lampião ou ouvir barulhos, toca seu sino de bronze e alerta todos os Cultistas do quarteirão.

const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

@export var patrol_speed: float = 1.65
@export var dark_vision_range: float = 9.0
@export var lit_vision_range: float = 26.0
@export var alarm_cooldown: float = 10.0

var _is_night_active: bool = false
var _spawn_pos: Vector3 = Vector3.ZERO
var _waypoints: Array[Vector3] = []
var _wp_index: int = 0
var _wp_stall: float = 0.0

var _ring_timer: float = 0.0
var _alarm_cd: float = 0.0
var _vision_next_ms: int = 0
var _walk_phase: float = 0.0
var _step_triggered: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float

var _vision_ray: RayCast3D
var _bell_arm: Node3D
var _bell_audio: AudioStreamPlayer3D
var _step_audio: AudioStreamPlayer3D


func _ready() -> void:
	_spawn_pos = global_position
	add_to_group("night_enemy")
	collision_mask = 3
	_ensure_collision_and_ray()
	_build_preacher_visual()
	_setup_audio()
	_resolve_waypoints()

	GameEvents.night_started.connect(_on_night_started)
	GameEvents.day_started.connect(_on_day_started)
	GameEvents.player_noise_emitted.connect(_on_player_noise_emitted)
	call_deferred("_sync_day_night")


func _sync_day_night() -> void:
	var day_night: Node = get_tree().get_first_node_in_group("day_night")
	if day_night != null and day_night.has_method("is_nighttime"):
		_set_active(bool(day_night.call("is_nighttime")))
	else:
		_set_active(true)


func _on_night_started() -> void:
	_set_active(true)


func _on_day_started() -> void:
	_set_active(false)


func _set_active(active: bool) -> void:
	_is_night_active = active
	visible = active
	collision_layer = 4 if active else 0
	set_physics_process(active)
	if active:
		global_position = _spawn_pos
		velocity = Vector3.ZERO
		_ring_timer = 0.0
		_alarm_cd = 0.0
	else:
		velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not _is_night_active:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if _alarm_cd > 0.0:
		_alarm_cd -= delta

	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController

	if _ring_timer > 0.0:
		_ring_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if player != null:
			var to_p: Vector3 = player.global_position - global_position
			to_p.y = 0.0
			if to_p.length_squared() > 0.05:
				rotation.y = lerp_angle(rotation.y, atan2(-to_p.x, -to_p.z), minf(1.0, 8.0 * delta))
		if _bell_arm != null:
			_bell_arm.rotation.x = -0.9 + sin(Time.get_ticks_msec() * 0.03) * 0.55
		move_and_slide()
		return

	if _bell_arm != null:
		_bell_arm.rotation.x = lerpf(_bell_arm.rotation.x, -0.25, minf(1.0, 6.0 * delta))

	var now_ms: int = Time.get_ticks_msec()
	if player != null and now_ms >= _vision_next_ms:
		_vision_next_ms = now_ms + 140
		if _alarm_cd <= 0.0 and _can_see_player(player):
			_trigger_alarm(player.global_position)
			return

	if _waypoints.is_empty():
		move_and_slide()
		return

	var target_pos: Vector3 = _waypoints[_wp_index]
	_wp_stall += delta
	var flat_dist: float = Vector2(global_position.x, global_position.z).distance_to(Vector2(target_pos.x, target_pos.z))
	if flat_dist <= 0.9 or _wp_stall >= 12.0:
		_wp_index = (_wp_index + 1) % _waypoints.size()
		_wp_stall = 0.0
		target_pos = _waypoints[_wp_index]

	var dir: Vector3 = _compute_steered_dir(target_pos)
	if dir.length_squared() > 0.0025:
		velocity.x = dir.x * patrol_speed
		velocity.z = dir.z * patrol_speed
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, 5.0 * delta))
		_walk_phase += delta * patrol_speed * 2.5
		if absf(sin(_walk_phase)) > 0.9:
			if not _step_triggered:
				_step_triggered = true
				if _step_audio != null and _step_audio.stream != null:
					_step_audio.pitch_scale = randf_range(0.75, 0.92)
					_step_audio.play()
		else:
			_step_triggered = false
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_step_triggered = false

	move_and_slide()


func _trigger_alarm(alert_pos: Vector3) -> void:
	_ring_timer = 1.2
	_alarm_cd = alarm_cooldown
	if _bell_audio != null and _bell_audio.stream != null:
		_bell_audio.pitch_scale = randf_range(0.96, 1.05)
		_bell_audio.play()
	else:
		AudioManager.play_bell_alarm()
	GameEvents.alarm_triggered.emit(alert_pos)
	GameEvents.status_message_requested.emit("O PREGADOR TOCOU O SINO! Cultistas estão vindo!")


func _on_player_noise_emitted(origin: Vector3, radius: float) -> void:
	if not _is_night_active or _alarm_cd > 0.0 or _ring_timer > 0.0:
		return
	if global_position.distance_to(origin) <= minf(radius, 10.0):
		_trigger_alarm(origin)


func _can_see_player(player: PlayerController) -> bool:
	var to_p: Vector3 = player.global_position - global_position
	var dist: float = to_p.length()
	if dist > player.get_detection_distance(dark_vision_range, lit_vision_range):
		return false
	if dist > 2.6:
		var forward: Vector3 = -global_transform.basis.z
		var flat: Vector3 = Vector3(to_p.x, 0.0, to_p.z).normalized()
		if forward.dot(flat) < -0.1:
			return false
	if _vision_ray == null:
		return true
	var eye_target: Vector3 = player.get_eye_position() if player.has_method("get_eye_position") else (player.global_position + Vector3(0.0, 1.2, 0.0))
	_vision_ray.target_position = _vision_ray.global_transform.basis.inverse() * (eye_target - _vision_ray.global_position)
	_vision_ray.force_raycast_update()
	if not _vision_ray.is_colliding():
		return true
	return _vision_ray.get_collider() == player


func _compute_steered_dir(desired_target: Vector3) -> Vector3:
	var dir: Vector3 = desired_target - global_position
	dir.y = 0.0
	if dir.length_squared() <= 0.0025:
		return Vector3.ZERO
	dir = dir.normalized()
	var world_3d: World3D = get_world_3d()
	if world_3d == null or world_3d.direct_space_state == null:
		return dir
	var origin: Vector3 = global_position + Vector3(0.0, 0.9, 0.0)
	var exclude: Array[RID] = [get_rid()]
	for angle_deg: float in [0.0, 45.0, -45.0, 90.0, -90.0]:
		var test_dir: Vector3 = dir.rotated(Vector3.UP, deg_to_rad(angle_deg))
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + test_dir * 1.4, 1, exclude)
		if world_3d.direct_space_state.intersect_ray(q).is_empty():
			return test_dir
	return dir


func _resolve_waypoints() -> void:
	_waypoints.clear()
	var p: Node = get_parent()
	if p != null:
		var wp_node: Node = p.get_node_or_null(name + "_Waypoints")
		if wp_node != null:
			for child: Node in wp_node.get_children():
				if child is Marker3D:
					_waypoints.append((child as Marker3D).global_position)
	if _waypoints.is_empty():
		_waypoints = [_spawn_pos + Vector3(-3.5, 0.0, 0.0), _spawn_pos + Vector3(3.5, 0.0, 0.0)]


func _ensure_collision_and_ray() -> void:
	if get_node_or_null("CollisionShape3D") == null:
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = 0.42
		cap.height = 1.9
		col.shape = cap
		col.position = Vector3(0.0, 0.95, 0.0)
		add_child(col)

	_vision_ray = get_node_or_null("VisionRay") as RayCast3D
	if _vision_ray == null:
		_vision_ray = RayCast3D.new()
		_vision_ray.name = "VisionRay"
		_vision_ray.position = Vector3(0.0, 1.6, 0.0)
		_vision_ray.collision_mask = 3
		add_child(_vision_ray)


func _setup_audio() -> void:
	_bell_audio = AudioStreamPlayer3D.new()
	_bell_audio.name = "BellAudio3D"
	_bell_audio.stream = AudioManager.get_bell_alarm_stream()
	_bell_audio.max_distance = 38.0
	_bell_audio.volume_db = -1.0
	add_child(_bell_audio)

	_step_audio = AudioStreamPlayer3D.new()
	_step_audio.name = "StepAudio3D"
	_step_audio.stream = AudioManager.get_lunatic_step_stream()
	_step_audio.max_distance = 16.0
	_step_audio.volume_db = -8.0
	add_child(_step_audio)


func _make_psx_mat(color: Color) -> Material:
	if PSX_LIT_SHADER != null:
		var smat: ShaderMaterial = ShaderMaterial.new()
		smat.shader = PSX_LIT_SHADER
		smat.set_shader_parameter("modulate_color", color)
		smat.set_shader_parameter("snap_resolution", Vector2(320.0, 180.0))
		return smat
	var std: StandardMaterial3D = StandardMaterial3D.new()
	std.albedo_color = color
	return std


func _add_part(parent_n: Node3D, p_name: String, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.name = p_name
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.rotation_degrees = rot_deg
	m.material_override = mat
	parent_n.add_child(m)
	return m


func _build_preacher_visual() -> void:
	var vis: Node3D = Node3D.new()
	vis.name = "PreacherVisual"
	add_child(vis)

	var robe_mat: Material = _make_psx_mat(Color(0.14, 0.08, 0.16))
	var hood_mat: Material = _make_psx_mat(Color(0.10, 0.06, 0.12))
	var mask_mat: Material = _make_psx_mat(Color(0.95, 0.78, 0.25))
	var dark_mat: Material = _make_psx_mat(Color(0.05, 0.02, 0.02))
	var brass_mat: Material = _make_psx_mat(Color(0.76, 0.56, 0.20))

	_add_part(vis, "RobeSkirt", Vector3(0.64, 0.92, 0.42), Vector3(0.0, 0.46, 0.0), robe_mat)
	_add_part(vis, "RobeTorso", Vector3(0.56, 0.68, 0.34), Vector3(0.0, 1.24, 0.0), robe_mat)
	_add_part(vis, "HoodBack", Vector3(0.42, 0.46, 0.38), Vector3(0.0, 1.72, 0.04), hood_mat)
	_add_part(vis, "HoodPeak", Vector3(0.28, 0.22, 0.28), Vector3(0.0, 2.02, 0.08), hood_mat, Vector3(-12.0, 0.0, 0.0))

	# Máscara dourada solar
	var mask: MeshInstance3D = _add_part(vis, "SunMask", Vector3(0.38, 0.42, 0.04), Vector3(0.0, 1.70, -0.18), mask_mat)
	_add_part(mask, "EyeL", Vector3(0.06, 0.10, 0.02), Vector3(-0.08, 0.06, -0.02), dark_mat)
	_add_part(mask, "EyeR", Vector3(0.06, 0.10, 0.02), Vector3(0.08, 0.06, -0.02), dark_mat)
	_add_part(mask, "Smile", Vector3(0.20, 0.05, 0.02), Vector3(0.0, -0.08, -0.02), dark_mat)

	# Braço direito + Sino de bronze
	_bell_arm = Node3D.new()
	_bell_arm.name = "BellArm"
	_bell_arm.position = Vector3(0.38, 1.48, 0.0)
	_bell_arm.rotation.x = -0.25
	vis.add_child(_bell_arm)
	_add_part(_bell_arm, "Sleeve", Vector3(0.18, 0.56, 0.20), Vector3(0.0, -0.24, 0.0), robe_mat)
	_add_part(_bell_arm, "BellHandle", Vector3(0.04, 0.14, 0.04), Vector3(0.0, -0.55, -0.08), brass_mat, Vector3(70.0, 0.0, 0.0))
	_add_part(_bell_arm, "BellBody", Vector3(0.18, 0.22, 0.18), Vector3(0.0, -0.62, -0.16), brass_mat)
