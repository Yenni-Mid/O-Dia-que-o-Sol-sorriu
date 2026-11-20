extends Node
## Diretor de Alucinações da "Epidemia da Verdade".
## Abaixo de 50% de sanidade gera vultos falsos, sussurros 3D atrás do jogador e portas se fechando sozinhas.

const APPARITION_WHISPERS: Array[String] = [
	"[Voz atrás de você]: \"Pai... por que você apagou a luz?\"",
	"[Voz no andar de cima]: \"Pai, eu ainda estou esperando aqui...\"",
	"[Murmúrio na escuridão]: \"Você não deveria ter saído da sala.\"",
]

var _sanity_ratio: float = 1.0
var _next_event_timer: float = 14.0
var _active_apparition: Node3D = null
var _apparition_timer: float = 0.0


func _ready() -> void:
	GameEvents.sanity_changed.connect(_on_sanity_changed)


func _on_sanity_changed(current: float, max_val: float) -> void:
	_sanity_ratio = current / maxf(max_val, 0.001)


func _process(delta: float) -> void:
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if player == null or player.is_hidden:
		if _active_apparition != null:
			_clear_apparition(false)
		return

	if _active_apparition != null and is_instance_valid(_active_apparition):
		_apparition_timer -= delta
		var dist: float = _active_apparition.global_position.distance_to(player.global_position)
		var lit_close: bool = player.lantern_system != null and player.lantern_system.is_lit and dist <= 8.5
		if dist <= 4.5 or lit_close or _apparition_timer <= 0.0:
			_clear_apparition(true)
		return

	if _sanity_ratio >= 0.50:
		return

	_next_event_timer -= delta
	if _next_event_timer <= 0.0:
		_next_event_timer = randf_range(6.0, 12.0) if _sanity_ratio < 0.25 else randf_range(12.0, 22.0)
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
	var desired_dist: float = randf_range(7.0, 11.0)
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
		if spawn_dist < 4.8:
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
	black_mat.albedo_color = Color(0.02, 0.02, 0.03)

	var mask_mat: StandardMaterial3D = StandardMaterial3D.new()
	mask_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mask_mat.albedo_color = Color(0.75, 0.72, 0.65)

	var body: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.5, 1.75, 0.3)
	body.mesh = bm
	body.position = Vector3(0.0, 0.88, 0.0)
	body.material_override = black_mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.add_child(body)

	var mask: MeshInstance3D = MeshInstance3D.new()
	var mm: BoxMesh = BoxMesh.new()
	mm.size = Vector3(0.36, 0.4, 0.04)
	mask.mesh = mm
	mask.position = Vector3(0.0, 1.58, -0.17)
	mask.material_override = mask_mat
	mask.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.add_child(mask)

	_active_apparition = ghost
	_apparition_timer = 3.5
	return true


func _clear_apparition(with_scare: bool) -> void:
	if _active_apparition != null and is_instance_valid(_active_apparition):
		if with_scare:
			_spawn_oneshot_whisper(_active_apparition.global_position + Vector3(0.0, 1.4, 0.0))
			GameEvents.camera_shake_requested.emit(0.22)
		_active_apparition.queue_free()
	_active_apparition = null


func _trigger_directional_whisper(player: PlayerController) -> void:
	var backward: Vector3 = player.global_transform.basis.z
	backward.y = 0.0
	backward = backward.normalized() if backward.length_squared() > 0.01 else Vector3.BACK
	var offset_pos: Vector3 = player.global_position + backward.rotated(Vector3.UP, randf_range(-0.6, 0.6)) * randf_range(4.5, 7.0)
	_spawn_oneshot_whisper(offset_pos + Vector3(0.0, 1.5, 0.0))
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
