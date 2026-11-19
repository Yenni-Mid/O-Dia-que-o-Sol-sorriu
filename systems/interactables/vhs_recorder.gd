extends Area3D
## Gravador/Fita VHS interativa (Layer 4) que reproduz fragmentos encontrados no quarteirão.

const LAYER_INTERACTABLES: int = 1 << 3

@export var tape_id: String = "tape_tv"
@export var tape_title: String = "Fita #01 — Último Boletim"
@export var tape_lines: PackedStringArray = PackedStringArray([
	"[Transmissão cortada]: ...não tentem restaurar os geradores...",
	"[Locutor trêmulo]: Fechem todas as cortinas. O céu mudou de cor às 14h...",
	"[Voz gravada por cima]: Se você estiver ouvindo isso em casa... olhe pelo beco oeste."
])

var _played: bool = false
var _led_mat: StandardMaterial3D
var _blink_time: float = 0.0


func _ready() -> void:
	collision_layer = LAYER_INTERACTABLES
	collision_mask = 0
	monitorable = true
	monitoring = false

	var col: CollisionShape3D = CollisionShape3D.new()
	var box_s: BoxShape3D = BoxShape3D.new()
	box_s.size = Vector3(0.42, 0.24, 0.34)
	col.shape = box_s
	col.position = Vector3(0.0, 0.08, 0.0)
	add_child(col)

	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.14, 0.14, 0.16)

	var deck: MeshInstance3D = MeshInstance3D.new()
	var dm: BoxMesh = BoxMesh.new()
	dm.size = Vector3(0.36, 0.11, 0.24)
	deck.mesh = dm
	deck.position = Vector3(0.0, 0.055, 0.0)
	deck.material_override = body_mat
	add_child(deck)

	_led_mat = StandardMaterial3D.new()
	_led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_led_mat.albedo_color = Color(1.0, 0.18, 0.12)

	var led: MeshInstance3D = MeshInstance3D.new()
	var lm: BoxMesh = BoxMesh.new()
	lm.size = Vector3(0.03, 0.025, 0.02)
	led.mesh = lm
	led.position = Vector3(0.13, 0.06, 0.125)
	led.material_override = _led_mat
	add_child(led)


func _process(delta: float) -> void:
	_blink_time += delta
	if _led_mat != null:
		var on: bool = int(_blink_time * 2.2) % 2 == 0
		_led_mat.albedo_color = Color(1.0, 0.2, 0.12) if on else Color(0.35, 0.05, 0.04)


func interact() -> void:
	_played = true
	AudioManager.play_ui_click()
	var lines_arr: Array = Array(tape_lines)
	GameEvents.vhs_tape_requested.emit(tape_id, tape_title, lines_arr)


func get_interaction_prompt() -> String:
	var verb: String = "Rever" if _played else "Reproduzir"
	return "[E] %s %s" % [verb, tape_title]
