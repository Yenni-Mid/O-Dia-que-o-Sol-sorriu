class_name ShortcutGate
extends Node3D
## Portão metálico destravável em mão única pelos becos/pátio (Layer 1 + Layer 4).
## Destravado apenas pelo lado do ferrolho (unlock_side_local); depois funciona como porta de fuga rápida.

const LAYER_ENV_AND_INTERACT: int = (1 << 0) | (1 << 3)
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

@export var shortcut_id: String = "shortcut_gate"
@export var gate_name: String = "Portão de Atalho"
@export var gate_width: float = 2.2
@export var gate_height: float = 2.6
@export var unlock_side_local: Vector3 = Vector3(0.0, 0.0, -1.0)
@export var locked_hint_text: String = "Ferrolho trancado pelo outro lado."
@export var open_angle_deg: float = 95.0

var is_unlocked: bool = false
var is_open: bool = false
var _closed_yaw: float = 0.0
var _target_yaw: float = 0.0
var _leaf_body: StaticBody3D
var _latch_mesh: MeshInstance3D
var _latch_mat: StandardMaterial3D
var _audio_3d: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("shortcut_gate")
	_closed_yaw = rotation_degrees.y
	if not shortcut_id.is_empty() and SaveManager.is_shortcut_unlocked(shortcut_id):
		is_unlocked = true
		is_open = true
	_target_yaw = _closed_yaw + (open_angle_deg if is_open else 0.0)
	if is_open:
		rotation_degrees.y = _target_yaw
	set_physics_process(false)

	_build_visual()
	_setup_audio()


func _exit_tree() -> void:
	if _audio_3d != null:
		_audio_3d.stop()
		_audio_3d.stream = null
	_latch_mat = null
	_latch_mesh = null
	_leaf_body = null
	_audio_3d = null


func _physics_process(delta: float) -> void:
	rotation_degrees.y = lerpf(rotation_degrees.y, _target_yaw, clampf(6.5 * delta, 0.0, 1.0))
	if absf(rotation_degrees.y - _target_yaw) <= 0.15:
		rotation_degrees.y = _target_yaw
		set_physics_process(false)


func interact() -> void:
	if not is_unlocked:
		if _is_player_on_unlock_side():
			is_unlocked = true
			is_open = true
			if not shortcut_id.is_empty():
				SaveManager.mark_shortcut_unlocked(shortcut_id)
			_update_latch_visual()
			_target_yaw = _closed_yaw + open_angle_deg
			set_physics_process(true)
			AudioManager.play_unlock()
			_play_gate_sound()
			GameEvents.status_message_requested.emit("Atalho destravado: %s!" % gate_name)
		else:
			AudioManager.play_locked()
			GameEvents.status_message_requested.emit(locked_hint_text)
		return

	is_open = not is_open
	_target_yaw = _closed_yaw + (open_angle_deg if is_open else 0.0)
	set_physics_process(true)
	_play_gate_sound()


func get_interaction_prompt() -> String:
	if not is_unlocked:
		if _is_player_on_unlock_side():
			return "[E] Destravar Ferrolho (%s)" % gate_name
		return "[Trancado pelo outro lado — %s]" % gate_name
	return "[E] Fechar %s" % gate_name if is_open else "[E] Abrir %s" % gate_name


func _is_player_on_unlock_side() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false
	var center: Vector3 = global_position + (global_transform.basis * Vector3(gate_width * 0.5, 0.0, 0.0))
	var to_player: Vector3 = player.global_position - center
	to_player.y = 0.0
	var unlock_dir: Vector3 = global_transform.basis * unlock_side_local
	unlock_dir.y = 0.0
	if to_player.length_squared() < 0.001 or unlock_dir.length_squared() < 0.001:
		return false
	return to_player.normalized().dot(unlock_dir.normalized()) > 0.0


func _update_latch_visual() -> void:
	if _latch_mat != null:
		_latch_mat.albedo_color = Color(0.24, 0.72, 0.30) if is_unlocked else Color(0.78, 0.22, 0.16)


func _play_gate_sound() -> void:
	if _audio_3d != null and _audio_3d.stream != null:
		_audio_3d.pitch_scale = randf_range(0.84, 1.04)
		_audio_3d.play()
	else:
		AudioManager.play_door_creak()


func _setup_audio() -> void:
	_audio_3d = AudioStreamPlayer3D.new()
	_audio_3d.name = "GateAudio3D"
	_audio_3d.stream = AudioManager.get_door_stream()
	_audio_3d.max_distance = 14.0
	_audio_3d.volume_db = -3.0
	add_child(_audio_3d)


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


func _add_bar(parent_n: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.material_override = mat
	parent_n.add_child(m)
	return m


func _build_visual() -> void:
	_leaf_body = StaticBody3D.new()
	_leaf_body.name = "GateLeaf"
	_leaf_body.collision_layer = LAYER_ENV_AND_INTERACT
	_leaf_body.collision_mask = 0
	_leaf_body.position = Vector3(gate_width * 0.5, gate_height * 0.5, 0.0)
	_leaf_body.add_to_group("door_leaf")
	add_child(_leaf_body)

	var col: CollisionShape3D = CollisionShape3D.new()
	var cs: BoxShape3D = BoxShape3D.new()
	cs.size = Vector3(gate_width - 0.06, gate_height - 0.04, 0.14)
	col.shape = cs
	_leaf_body.add_child(col)

	var iron_mat: Material = _make_psx_mat(Color(0.22, 0.24, 0.27))
	var rust_mat: Material = _make_psx_mat(Color(0.42, 0.24, 0.15))

	# Travessas horizontais e verticais da grade metálica
	_add_bar(_leaf_body, Vector3(gate_width - 0.06, 0.10, 0.10), Vector3(0.0, gate_height * 0.44, 0.0), iron_mat)
	_add_bar(_leaf_body, Vector3(gate_width - 0.06, 0.10, 0.10), Vector3(0.0, -gate_height * 0.42, 0.0), iron_mat)
	_add_bar(_leaf_body, Vector3(gate_width - 0.08, 0.09, 0.10), Vector3(0.0, 0.0, 0.0), rust_mat)

	var bar_count: int = maxi(4, int(round(gate_width / 0.36)))
	for i: int in range(bar_count):
		var frac: float = float(i) / float(maxi(1, bar_count - 1))
		var bx: float = lerpf(-gate_width * 0.45, gate_width * 0.45, frac)
		_add_bar(_leaf_body, Vector3(0.06, gate_height - 0.06, 0.06), Vector3(bx, 0.0, 0.0), iron_mat)

	# Ferrolho colorido montado no lado destravável (unlock_side_local)
	_latch_mat = StandardMaterial3D.new()
	_latch_mat.roughness = 0.55
	var dir_n: Vector3 = unlock_side_local.normalized() if unlock_side_local.length_squared() > 0.01 else Vector3(0.0, 0.0, -1.0)
	_latch_mesh = _add_bar(
		_leaf_body,
		Vector3(0.26, 0.12, 0.12),
		Vector3(gate_width * 0.34, -0.15, 0.0) + dir_n * 0.09,
		_latch_mat
	)
	_update_latch_visual()
