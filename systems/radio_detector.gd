extends Node
## Rádio portátil estilo Silent Hill: emite estática crescente quando há inimigos próximos após o jogador coletar o rádio.

const SAFE_DISTANCE: float = 28.0
const PANIC_DISTANCE: float = 4.0
const SILENT_DB: float = -52.0

var _audio: AudioStreamPlayer
var _has_radio: bool = false
var _last_emitted_level: float = -1.0
var _emit_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_audio = AudioStreamPlayer.new()
	_audio.name = "RadioStaticPlayer"
	_audio.stream = AudioManager.get_radio_static_stream()
	_audio.volume_db = SILENT_DB
	add_child(_audio)

	GameEvents.tools_changed.connect(_on_tools_changed)
	call_deferred("_sync_radio_ownership")


func _sync_radio_ownership() -> void:
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if inv != null and inv.has_method("has_tool"):
		_has_radio = bool(inv.call("has_tool", "radio"))


func _on_tools_changed(tools: Array) -> void:
	_has_radio = tools.has("radio")


func _process(delta: float) -> void:
	if not _has_radio or get_tree().paused:
		_stop_static()
		_push_level(0.0, delta, true)
		return

	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		_stop_static()
		_push_level(0.0, delta, true)
		return

	var min_dist: float = SAFE_DISTANCE + 5.0
	var candidates: Array[Node] = []
	candidates.append_array(get_tree().get_nodes_in_group("night_enemy"))
	candidates.append_array(get_tree().get_nodes_in_group("enemies"))

	for n: Node in candidates:
		if not (n is Node3D):
			continue
		var enemy: Node3D = n as Node3D
		if not enemy.visible or not enemy.is_inside_tree():
			continue
		var d: float = player.global_position.distance_to(enemy.global_position)
		if d < min_dist:
			min_dist = d

	var level: float = clampf(1.0 - ((min_dist - PANIC_DISTANCE) / (SAFE_DISTANCE - PANIC_DISTANCE)), 0.0, 1.0)
	if min_dist >= SAFE_DISTANCE:
		level = 0.0

	if level > 0.03:
		if _audio != null and _audio.stream != null:
			if not _audio.playing:
				_audio.play()
			_audio.volume_db = lerpf(-34.0, -9.0, level)
			_audio.pitch_scale = lerpf(0.88, 1.32, level)
	else:
		_stop_static()

	_push_level(level, delta, false)


func _stop_static() -> void:
	if _audio != null and _audio.playing:
		_audio.stop()


func _push_level(level: float, delta: float, force_zero: bool) -> void:
	_emit_timer += delta
	if force_zero and _last_emitted_level != 0.0:
		_last_emitted_level = 0.0
		GameEvents.radio_interference_changed.emit(0.0)
		return
	if _emit_timer >= 0.1 or absf(level - _last_emitted_level) >= 0.08:
		_emit_timer = 0.0
		if absf(level - _last_emitted_level) >= 0.015:
			_last_emitted_level = level
			GameEvents.radio_interference_changed.emit(level)
