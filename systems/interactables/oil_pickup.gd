class_name OilPickup
extends Area3D
## Refil de óleo interagível (Layer 4) que reabastece o lampião do jogador.
## Flutua levemente e emite um brilho âmbar fraco para ser encontrado no escuro.

const LAYER_INTERACTABLES: int = 1 << 3 # Layer 4

@export var oil_amount: float = 35.0
@export var glow_color: Color = Color(1.0, 0.62, 0.22)

var _visual: Node3D
var _base_y: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	collision_layer = LAYER_INTERACTABLES
	collision_mask = 0
	monitorable = true
	monitoring = false
	_visual = get_node_or_null("MeshInstance3D") as Node3D
	if _visual != null:
		_base_y = _visual.position.y
	_phase = randf() * TAU
	var glow: OmniLight3D = OmniLight3D.new()
	glow.name = "PickupGlow"
	glow.light_color = glow_color
	glow.light_energy = 0.55
	glow.omni_range = 1.8
	glow.omni_attenuation = 1.6
	glow.shadow_enabled = false
	glow.distance_fade_enabled = true
	glow.distance_fade_begin = 10.0
	glow.distance_fade_length = 4.0
	glow.position = Vector3(0.0, 0.3, 0.0)
	add_child(glow)


func _process(delta: float) -> void:
	if _visual == null:
		return
	_phase += delta
	_visual.position.y = _base_y + sin(_phase * 2.0) * 0.05
	_visual.rotation.y += delta * 0.9


func interact() -> void:
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if player == null or player.lantern_system == null:
		return
	player.lantern_system.add_oil(oil_amount)
	AudioManager.play_pickup()
	queue_free()


func get_interaction_prompt() -> String:
	return "[E] Pegar Óleo (+%d)" % int(oil_amount)
