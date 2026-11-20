extends Node
## Diretor de Alucinações da "Epidemia da Verdade".
## Abaixo de 45% de sanidade gera vultos imóveis nos becos (que se desfazem ao receber luz do lampião),
## sussurros 3D atrás do jogador e portas se fechando sozinhas.

const APPARITION_WHISPERS: Array[String] = [
	"[Atrás de você]: \"NÃO OLHE PRA TRÁS.\"",
	"[Sussurro no ouvido]: \"O SOL TE VÊ mesmo no escuro.\"",
	"[Voz atrás de você]: \"Pai... por que você apagou a luz?\"",
	"[Murmúrio no beco]: \"Ele está logo acima dos telhados...\"",
	"[Sussurro seco]: \"Você não deveria ter saído da sala.\"",
]

var _sanity_ratio: float = 1.0
var _next_event_timer: float = 14.0
var _active_apparition: Node3D = null
var _apparition_timer: float = 0.0
var _vanish_timer: float = -1.0


func _ready() -> void:
	GameEvents.sanity_changed.connect(_on_sanity_changed)


func _exit_tree() -> void:
	if _active_apparition != null and is_instance_valid(_active_apparition):
		_active_apparition.queue_free()
	_active_apparition = null


func _on_sanity_changed(current: float, max_val: float) -> void:
	_sanity_ratio = current / maxf(max_val, 0.001)


func _process(delta: float) -> void:
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if player == null or player.is_hidden:
		if _active_apparition != null:
			_clear_apparition(false)
		return

	if _active_apparition != null and is_instance_valid(_active_apparition):
		if _vanish_timer >= 0.0:
			_vanish_timer -= delta
			_active_apparition.rotation.z = sin(Time.get_ticks_msec() * 0.06) * 0.14
			_active_apparition.scale.y = maxf(0.1, _vanish_timer / 0.20)
			if _vanish_timer <= 0.0:
				_clear_apparition(true)
			return

		_apparition_timer -= delta
		var to_app: Vector3 = _active_apparition.global_position - player.global_position
		var dist: float = to_app.length()
		var lit_beam: bool = false
		if player.lantern_system != null and player.lantern_system.is_lit and dist <= 11.5 and dist > 0.05:
			var cam_fwd: Vector3 = -player.camera.global_transform.basis.z if player.camera != null else -player.global_transform.basis.z
			cam_fwd.y = 0.0
			var flat_dir: Vector3 = Vector3(to_app.x, 0.0, to_app.z).normalized()
			if cam_fwd.length_squared() > 0.01 and cam_fwd.normalized().dot(flat_dir) >= 0.72:
				lit_beam = true

		if dist <= 3.8 or lit_beam or _apparition_timer <= 0.0:
			if dist <= 3.8 or lit_beam:
				_vanish_timer = 0.20
			else:
				_clear_apparition(false)
		return

	if _sanity_ratio >= 0.45:
		return

	_next_event_timer -= delta
	if _next_event_timer <= 0.0:
		_next_event_timer = randf_range(5.5, 11.0) if _sanity_ratio < 0.25 else randf_range(11.0, 20.0)
		_trigger_random_hallucination(player)


func _trigger_random_hallucination(player: PlayerController) -> void:
	var roll: int = randi() % 3
	if roll == 0:
		if not _spawn_apparition(player):
			_trigger_directional_whisper(player)
	elif roll == 1:
		_trigger_directional_whisper(player)
	else:
		if not _trigger_haunted_door(player):
			_trigger_directional_whisper(player)


func _spawn_apparition(player: PlayerController) -> bool:
	var world_3d: World3D = player.get_world_3d()
	if world_3d == null or world_3d.direct_space_state == null:
		return false

	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.01:
		return false
	forward = forward.normalized()

	var angle_offset: float = deg_to_rad(randf_range(-42.0, 42.0))
	var ray_dir: Vector3 = forward.rotated(Vector3.UP, angle_offset)
	var desired_dist: float = randf_range(6.5, 11.5)
	var start: Vector3 = player.global_position + Vector3(0.0, 1.0, 0.0)

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		start,
		start + ray_dir * desired_dist,
		1,
		[player.get_rid()]
	)
	var hit: Dictionary = world_3d.direct_space_state.intersect_ray(query)
	var spawn_dist: float = desired_dist
	if not hit.is_empty():
		var hit_pos: Vector3 = hit.get("position", start) as Vector3
		spawn_dist = hit_pos.distance_to(start) - 1.0
		if spawn_dist < 4.5:
			return false

	var spawn_pos: Vector3 = player.global_position + ray_dir * spawn_dist
	spawn_pos.y = player.global_position.y

	var ghost: Node3D = Node3D.new()
	ghost.name = "HallucinationApparition"
	var parent_3d: Node = get_parent() if get_parent() != null else get_tree().current_scene
	parent_3d.add_child(ghost)
	ghost.global_position = spawn_pos

	var to_player: Vector3 = player.global_position - spawn_pos
	to_player.y = 0.0
	if to_player.length_squared() > 0.05:
		ghost.rotation.y = atan2(-to_player.x, -to_player.z)

	var black_mat: StandardMaterial3D = StandardMaterial3D.new()
	black_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black_mat.albedo_color = Color(0.015, 0.015, 0.025)

	var mask_mat: StandardMaterial3D = StandardMaterial3D.new()
	mask_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mask_mat.albedo_color = Color(0.82, 0.78, 0.68)

	var eye_mat: StandardMaterial3D = StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(0.05, 0.01, 0.01)

	# Silhueta alta de sobretudo escuro, braços caídos e máscara pálida inclinada
	var body: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.48, 1.56, 0.28)
	body.mesh = bm
	body.position = Vector3(0.0, 0.78, 0.0)
	body.material_override = black_mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.add_child(body)

	for arm_x: float in [-0.30, 0.30]:
		var arm: MeshInstance3D = MeshInstance3D.new()
		var am: BoxMesh = BoxMesh.new()
		am.size = Vector3(0.11, 0.72, 0.12)
		arm.mesh = am
		arm.position = Vector3(arm_x, 1.05, -0.02)
		arm.rotation_degrees = Vector3(8.0, 0.0, 5.0 if arm_x < 0.0 else -5.0)
		arm.material_override = black_mat
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(arm)

	var head: MeshInstance3D = MeshInstance3D.new()
	var hm: BoxMesh = BoxMesh.new()
	hm.size = Vector3(0.28, 0.34, 0.26)
	head.mesh = hm
	head.position = Vector3(0.0, 1.72, 0.0)
	head.material_override = black_mat
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.add_child(head)

	var mask: MeshInstance3D = MeshInstance3D.new()
	var mm: BoxMesh = BoxMesh.new()
	mm.size = Vector3(0.32, 0.38, 0.04)
	mask.mesh = mm
	mask.position = Vector3(0.0, 1.72, -0.14)
	mask.rotation_degrees = Vector3(0.0, 0.0, 7.0)
	mask.material_override = mask_mat
	mask.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.add_child(mask)

	for ex: float in [-0.07, 0.07]:
		var eye: MeshInstance3D = MeshInstance3D.new()
		var em: BoxMesh = BoxMesh.new()
		em.size = Vector3(0.06, 0.08, 0.02)
		eye.mesh = em
		eye.position = Vector3(ex, 0.05, -0.025)
		eye.material_override = eye_mat
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mask.add_child(eye)

	var smile: MeshInstance3D = MeshInstance3D.new()
	var sm: BoxMesh = BoxMesh.new()
	sm.size = Vector3(0.18, 0.04, 0.02)
	smile.mesh = sm
	smile.position = Vector3(0.0, -0.07, -0.025)
	smile.material_override = eye_mat
	smile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mask.add_child(smile)

	_active_apparition = ghost
	_apparition_timer = 4.5
	_vanish_timer = -1.0
	return true


func _clear_apparition(with_scare: bool) -> void:
	if _active_apparition != null and is_instance_valid(_active_apparition):
		if with_scare:
			_spawn_oneshot_whisper(_active_apparition.global_position + Vector3(0.0, 1.4, 0.0))
			GameEvents.camera_shake_requested.emit(0.26)
		_active_apparition.queue_free()
	_active_apparition = null
	_vanish_timer = -1.0


func _trigger_directional_whisper(player: PlayerController) -> void:
	var backward: Vector3 = player.global_transform.basis.z
	backward.y = 0.0
	backward = backward.normalized() if backward.length_squared() > 0.01 else Vector3.BACK
	var offset_pos: Vector3 = player.global_position + backward.rotated(Vector3.UP, randf_range(-0.55, 0.55)) * randf_range(2.2, 4.5)
	_spawn_oneshot_whisper(offset_pos + Vector3(0.0, 1.55, 0.0))
	var line: String = APPARITION_WHISPERS[randi() % APPARITION_WHISPERS.size()]
	GameEvents.confession_triggered.emit(line)


func _spawn_oneshot_whisper(world_pos: Vector3) -> void:
	var stream: AudioStream = AudioManager.get_whisper_stream()
	if stream == null:
		return
	var p3d: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p3d.stream = stream
	p3d.max_distance = 16.0
	p3d.volume_db = -7.0
	p3d.pitch_scale = randf_range(0.75, 1.05)
	var parent_3d: Node = get_parent() if get_parent() != null else get_tree().current_scene
	parent_3d.add_child(p3d)
	p3d.global_position = world_pos
	p3d.finished.connect(p3d.queue_free)
	p3d.play()


func _trigger_haunted_door(player: PlayerController) -> bool:
	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	for node: Node in get_tree().get_nodes_in_group("door_interactable"):
		var door: Node3D = node as Node3D
		if door == null or not bool(door.get("is_open")):
			continue
		var to_door: Vector3 = door.global_position - player.global_position
		var dist: float = to_door.length()
		if dist >= 4.5 and dist <= 13.0 and forward.dot(to_door.normalized()) < 0.15:
			if door.has_method("close_by_haunt"):
				door.call("close_by_haunt")
				return true
	return false
