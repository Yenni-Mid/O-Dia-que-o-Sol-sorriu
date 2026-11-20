extends CharacterBody3D
## Inimigo noturno: Cultista do Lampião — patrulha varrendo a rua com holofote SpotLight3D e caça intrusos à noite.

const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

enum State { PATROL, INVESTIGATE, CHASE }

@export var patrol_speed: float = 2.05
@export var chase_speed: float = 4.15
@export var dark_vision_range: float = 8.5
@export var lit_vision_range: float = 24.0
@export var spotlight_detect_range: float = 13.5
@export var attack_range: float = 1.65
@export var attack_damage: float = 22.0
@export var attack_cooldown: float = 1.35

var _state: State = State.PATROL
var _is_night_active: bool = false
var _spawn_pos: Vector3 = Vector3.ZERO
var _waypoints: Array[Vector3] = []
var _wp_index: int = 0
var _wp_stall: float = 0.0
var _investigate_target: Vector3 = Vector3.ZERO
var _investigate_timer: float = 0.0
var _lost_timer: float = 0.0
var _attack_timer: float = 0.0
var _stun_timer: float = 0.0
var _vision_next_ms: int = 0
var _cached_sees: bool = false
var _walk_phase: float = 0.0
var _step_triggered: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float

var _vision_ray: RayCast3D
var _nav_agent: NavigationAgent3D
var _lantern_arm: Node3D
var _spot_light: SpotLight3D
var _step_audio: AudioStreamPlayer3D
var _alert_audio: AudioStreamPlayer3D
var _whisper_audio: AudioStreamPlayer3D


func _ready() -> void:
	_spawn_pos = global_position
	add_to_group("night_enemy")
	add_to_group("enemies")
	collision_mask = 3

	_ensure_nodes()
	_build_visual()
	_setup_audio()
	_resolve_waypoints()

	GameEvents.night_started.connect(_on_night_started)
	GameEvents.day_started.connect(_on_day_started)
	GameEvents.player_noise_emitted.connect(_on_noise_or_alarm)
	GameEvents.alarm_triggered.connect(_on_alarm_triggered)
	call_deferred("_sync_day_night")


func _sync_day_night() -> void:
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn != null and dn.has_method("is_nighttime"):
		_set_active(bool(dn.call("is_nighttime")))
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
	if _spot_light != null:
		_spot_light.visible = active
	if active:
		global_position = _spawn_pos
		velocity = Vector3.ZERO
		_state = State.PATROL
		_lost_timer = 0.0
	else:
		velocity = Vector3.ZERO


func stun_from_flash(duration: float) -> void:
	_stun_timer = maxf(_stun_timer, duration)
	_play_alert()


func _physics_process(delta: float) -> void:
	if not _is_night_active:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _stun_timer > 0.0:
		_stun_timer = maxf(0.0, _stun_timer - delta)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	var sees: bool = _check_vision_cached(player)

	if sees and player != null:
		if _state != State.CHASE:
			_play_alert()
		_state = State.CHASE
		_investigate_target = player.global_position
		_lost_timer = 0.0
	elif _state == State.CHASE:
		_lost_timer += delta
		if _lost_timer >= 4.0:
			_state = State.INVESTIGATE
			_investigate_timer = 5.0

	if _state == State.PATROL and player != null and not player.is_hidden:
		if player.lantern_system != null and player.lantern_system.is_lit:
			if global_position.distance_to(player.global_position) <= 22.0:
				_state = State.INVESTIGATE
				_investigate_target = player.global_position
				_investigate_timer = 4.5

	match _state:
		State.CHASE:
			_do_chase(delta, player, sees)
		State.INVESTIGATE:
			_do_investigate(delta)
		State.PATROL:
			_do_patrol(delta)

	_animate_lantern(delta)
	move_and_slide()


func _do_chase(delta: float, player: PlayerController, sees: bool) -> void:
	if player == null:
		_state = State.PATROL
		return
	var dist: float = global_position.distance_to(player.global_position)
	if sees and dist <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			var health: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
			if health != null:
				health.take_damage(attack_damage)
		return
	_move_toward_target(_investigate_target, chase_speed, delta)


func _do_investigate(delta: float) -> void:
	_investigate_timer -= delta
	var flat_dist: float = Vector2(global_position.x, global_position.z).distance_to(Vector2(_investigate_target.x, _investigate_target.z))
	if flat_dist <= 1.2 or _investigate_timer <= 0.0:
		_state = State.PATROL
		return
	_move_toward_target(_investigate_target, patrol_speed * 1.3, delta)


func _do_patrol(delta: float) -> void:
	if _waypoints.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var target: Vector3 = _waypoints[_wp_index]
	_wp_stall += delta
	var flat_dist: float = Vector2(global_position.x, global_position.z).distance_to(Vector2(target.x, target.z))
	if flat_dist <= 1.0 or _wp_stall >= 12.0:
		_wp_index = (_wp_index + 1) % _waypoints.size()
		_wp_stall = 0.0
		target = _waypoints[_wp_index]
	_move_toward_target(target, patrol_speed, delta)


func _move_toward_target(target_pos: Vector3, speed: float, delta: float) -> void:
	var dir: Vector3 = target_pos - global_position
	if _nav_agent != null:
		_nav_agent.target_position = target_pos
		if not _nav_agent.is_navigation_finished():
			dir = _nav_agent.get_next_path_position() - global_position
	dir.y = 0.0
	if dir.length_squared() <= 0.0025:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, 6.5 * delta))

	_walk_phase += delta * speed * 2.6
	if absf(sin(_walk_phase)) > 0.9:
		if not _step_triggered:
			_step_triggered = true
			if _step_audio != null and _step_audio.stream != null:
				_step_audio.pitch_scale = randf_range(0.82, 1.04)
				_step_audio.play()
	else:
		_step_triggered = false


func _animate_lantern(delta: float) -> void:
	if _lantern_arm == null:
		return
	var t: float = Time.get_ticks_msec() * 0.0022
	if _state == State.PATROL:
		_lantern_arm.rotation.y = sin(t) * 0.45
		_lantern_arm.rotation.x = lerpf(_lantern_arm.rotation.x, -0.35, minf(1.0, 5.0 * delta))
	elif _state == State.CHASE:
		_lantern_arm.rotation.y = sin(t * 2.8) * 0.25
		_lantern_arm.rotation.x = lerpf(_lantern_arm.rotation.x, -0.65, minf(1.0, 7.0 * delta))
	else:
		_lantern_arm.rotation.y = sin(t * 1.4) * 0.55
		_lantern_arm.rotation.x = lerpf(_lantern_arm.rotation.x, -0.45, minf(1.0, 5.0 * delta))


func _check_vision_cached(player: PlayerController) -> bool:
	if player == null or player.is_hidden:
		_cached_sees = false
		return false
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _vision_next_ms:
		return _cached_sees
	_vision_next_ms = now_ms + 130
	_cached_sees = _can_see_player(player)
	return _cached_sees


func _can_see_player(player: PlayerController) -> bool:
	var to_p: Vector3 = player.global_position - global_position
	var dist: float = to_p.length()
	var effective_range: float = player.get_detection_distance(dark_vision_range, lit_vision_range)
	# Feixe do próprio holofote amplia detecção frontal
	if _spot_light != null and dist <= spotlight_detect_range:
		var beam_fwd: Vector3 = -_spot_light.global_transform.basis.z
		if beam_fwd.dot(to_p.normalized()) >= 0.80:
			effective_range = maxf(effective_range, spotlight_detect_range)
	if dist > effective_range:
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


func _on_noise_or_alarm(origin: Vector3, radius: float) -> void:
	if not _is_night_active:
		return
	if global_position.distance_to(origin) <= maxf(radius, 18.0) and _state != State.CHASE:
		_state = State.INVESTIGATE
		_investigate_target = origin
		_investigate_timer = 5.5


func _on_alarm_triggered(origin: Vector3) -> void:
	if not _is_night_active:
		return
	if _state != State.CHASE:
		_state = State.INVESTIGATE
		_investigate_target = origin
		_investigate_timer = 7.0


func _play_alert() -> void:
	if _alert_audio != null and _alert_audio.stream != null:
		_alert_audio.pitch_scale = randf_range(0.92, 1.08)
		_alert_audio.play()
	else:
		AudioManager.play_enemy_alert()


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
		_waypoints = [_spawn_pos + Vector3(-4.0, 0.0, 0.0), _spawn_pos + Vector3(4.0, 0.0, 0.0)]


func _ensure_nodes() -> void:
	if get_node_or_null("CollisionShape3D") == null:
		var col: CollisionShape3D = CollisionShape3D.new()
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = 0.40
		cap.height = 1.80
		col.shape = cap
		col.position = Vector3(0.0, 0.90, 0.0)
		add_child(col)

	_vision_ray = get_node_or_null("VisionRay") as RayCast3D
	if _vision_ray == null:
		_vision_ray = RayCast3D.new()
		_vision_ray.name = "VisionRay"
		_vision_ray.position = Vector3(0.0, 1.5, 0.0)
		_vision_ray.collision_mask = 3
		add_child(_vision_ray)

	_nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if _nav_agent == null:
		_nav_agent = NavigationAgent3D.new()
		_nav_agent.name = "NavigationAgent3D"
		_nav_agent.path_desired_distance = 0.65
		_nav_agent.target_desired_distance = 0.85
		add_child(_nav_agent)


func _setup_audio() -> void:
	_step_audio = AudioStreamPlayer3D.new()
	_step_audio.stream = AudioManager.get_lunatic_step_stream()
	_step_audio.max_distance = 16.0
	_step_audio.volume_db = -6.0
	add_child(_step_audio)

	_alert_audio = AudioStreamPlayer3D.new()
	_alert_audio.stream = AudioManager.get_alert_stream()
	_alert_audio.max_distance = 24.0
	_alert_audio.volume_db = -3.0
	add_child(_alert_audio)

	_whisper_audio = AudioStreamPlayer3D.new()
	_whisper_audio.stream = AudioManager.get_whisper_stream()
	_whisper_audio.max_distance = 12.0
	_whisper_audio.volume_db = -11.0
	add_child(_whisper_audio)


func _make_mat(color: Color, emissive: bool = false) -> Material:
	if emissive:
		var std: StandardMaterial3D = StandardMaterial3D.new()
		std.albedo_color = color
		std.emission_enabled = true
		std.emission = color
		std.emission_energy_multiplier = 2.0
		return std
	var smat: ShaderMaterial = ShaderMaterial.new()
	smat.shader = PSX_LIT_SHADER
	smat.set_shader_parameter("modulate_color", color)
	smat.set_shader_parameter("snap_resolution", Vector2(320.0, 180.0))
	return smat


func _add_part(parent_n: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.material_override = mat
	parent_n.add_child(m)


func _build_visual() -> void:
	var vis: Node3D = Node3D.new()
	vis.name = "CultistVisual"
	add_child(vis)

	var cloak: Material = _make_mat(Color(0.24, 0.08, 0.08))
	var hood: Material = _make_mat(Color(0.16, 0.05, 0.06))
	var mask: Material = _make_mat(Color(0.92, 0.78, 0.34))
	var iron: Material = _make_mat(Color(0.18, 0.19, 0.22))
	var glow: Material = _make_mat(Color(1.0, 0.72, 0.25), true)

	_add_part(vis, Vector3(0.56, 0.90, 0.38), Vector3(0.0, 0.45, 0.0), cloak)
	_add_part(vis, Vector3(0.50, 0.64, 0.32), Vector3(0.0, 1.22, 0.0), cloak)
	_add_part(vis, Vector3(0.36, 0.40, 0.34), Vector3(0.0, 1.66, 0.03), hood)
	_add_part(vis, Vector3(0.32, 0.36, 0.04), Vector3(0.0, 1.66, -0.15), mask)

	_lantern_arm = Node3D.new()
	_lantern_arm.name = "LanternArm"
	_lantern_arm.position = Vector3(0.32, 1.32, -0.05)
	vis.add_child(_lantern_arm)
	_add_part(_lantern_arm, Vector3(0.12, 0.44, 0.12), Vector3(0.0, -0.22, -0.16), cloak)
	_add_part(_lantern_arm, Vector3(0.16, 0.24, 0.16), Vector3(0.0, -0.46, -0.34), iron)
	_add_part(_lantern_arm, Vector3(0.10, 0.14, 0.10), Vector3(0.0, -0.46, -0.34), glow)

	_spot_light = SpotLight3D.new()
	_spot_light.name = "CultistSpotLight"
	_spot_light.position = Vector3(0.0, -0.46, -0.42)
	_spot_light.light_color = Color(1.0, 0.74, 0.32)
	_spot_light.light_energy = 2.6
	_spot_light.spot_range = 15.0
	_spot_light.spot_angle = 32.0
	_spot_light.shadow_enabled = false
	_spot_light.distance_fade_enabled = true
	_spot_light.distance_fade_begin = 26.0
	_spot_light.distance_fade_length = 8.0
	_lantern_arm.add_child(_spot_light)
