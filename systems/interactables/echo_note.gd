class_name EchoNote
extends Area3D
## Diário "Eco" deixado nas sombras por sobreviventes (Layer 4).
## Brilha num tom pálido até ser lido; depois o brilho some (feedback de "já coletado").

const LAYER_INTERACTABLES: int = 1 << 3 # Layer 4

@export var echo_data: EchoData
@export var fallback_id: String = "echo_01"
@export var fallback_author: String = "Sobrevivente Anônimo"
@export var fallback_date: String = "Dia 14 após o Sorriso"
@export_multiline var fallback_text: String = "Não olhe para cima quando o céu ficar amarelo. A luz faz você confessar tudo o que escondeu a vida inteira. Mantenha o lampião aceso nas sombras."

var is_read: bool = false
var _glow: OmniLight3D
var _visual: Node3D
var _base_y: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	add_to_group("echo_note")
	collision_layer = LAYER_INTERACTABLES
	collision_mask = 0
	monitorable = true
	monitoring = false
	if echo_data == null:
		echo_data = EchoData.new()
		echo_data.echo_id = fallback_id
		echo_data.author_name = fallback_author
		echo_data.date_written = fallback_date
		echo_data.confession_text = fallback_text

	_visual = get_node_or_null("MeshInstance3D") as Node3D
	if _visual != null:
		_base_y = _visual.position.y
	_phase = randf() * TAU

	_glow = OmniLight3D.new()
	_glow.name = "EchoGlow"
	_glow.light_color = Color(0.78, 0.86, 1.0)
	_glow.light_energy = 0.45
	_glow.omni_range = 1.5
	_glow.omni_attenuation = 1.8
	_glow.shadow_enabled = false
	_glow.distance_fade_enabled = true
	_glow.distance_fade_begin = 10.0
	_glow.distance_fade_length = 4.0
	_glow.position = Vector3(0.0, 0.25, 0.0)
	add_child(_glow)


func _process(delta: float) -> void:
	if is_read or _visual == null:
		return
	_phase += delta
	_visual.position.y = _base_y + sin(_phase * 1.6) * 0.03
	if _glow != null:
		_glow.light_energy = 0.35 + 0.15 * sin(_phase * 2.2)


func interact() -> void:
	if echo_data == null:
		return
	if not is_read:
		is_read = true
		if _glow != null:
			_glow.visible = false
		if _visual != null:
			_visual.position.y = _base_y
	AudioManager.play_paper()
	GameEvents.echo_opened.emit(echo_data)


func get_interaction_prompt() -> String:
	var verb: String = "Reler" if is_read else "Ler"
	if echo_data != null and not echo_data.author_name.is_empty():
		return "[E] %s Eco: %s" % [verb, echo_data.author_name]
	return "[E] %s Eco" % verb
