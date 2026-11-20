extends StaticBody3D
## Ponto de descanso seguro dentro da Casa Principal (1º andar):
## Salva retorno à noite e, quando começa a clarear (05:00+) ou de dia, permite descansar com segurança até a próxima noite (19:15).

const LAYER_ENV_AND_INTERACT: int = (1 << 0) | (1 << 3)
const PSX_LIT_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")


func _ready() -> void:
	collision_layer = LAYER_ENV_AND_INTERACT
	collision_mask = 0
	_build_visual()


func interact() -> void:
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController

	var can_sleep_day: bool = false
	if dn != null and dn.has_method("get_hour"):
		var hour: float = float(dn.call("get_hour"))
		if hour >= 5.0 and hour < 19.0:
			can_sleep_day = true

	if can_sleep_day and dn != null and dn.has_method("shelter_at_home_until_next_night"):
		dn.call("shelter_at_home_until_next_night")
		return

	if player != null and player.sanity_component != null:
		player.sanity_component.modify_sanity(15.0)
	SaveManager.set_checkpoint(Vector3(0.0, 0.15, 4.2))
	AudioManager.play_lantern_ignite()
	GameEvents.status_message_requested.emit("Refúgio salvo em casa! Explore à noite e volte antes de clarear (05:00).")


func get_interaction_prompt() -> String:
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn != null and dn.has_method("get_hour"):
		var hour: float = float(dn.call("get_hour"))
		if hour >= 5.0 and hour < 19.0:
			return "[E] Aguardar em Casa até Anoitecer (19:15)"
	return "[E] Salvar Refúgio em Casa"


func _build_visual() -> void:
	var col: CollisionShape3D = CollisionShape3D.new()
	var box_s: BoxShape3D = BoxShape3D.new()
	box_s.size = Vector3(0.95, 1.0, 0.75)
	col.shape = box_s
	col.position = Vector3(0.0, 0.5, 0.0)
	add_child(col)

	var wood_mat: ShaderMaterial = ShaderMaterial.new()
	wood_mat.shader = PSX_LIT_SHADER
	wood_mat.set_shader_parameter("modulate_color", Color(0.36, 0.24, 0.14))
	wood_mat.set_shader_parameter("snap_resolution", Vector2(320.0, 180.0))

	var brass_mat: ShaderMaterial = ShaderMaterial.new()
	brass_mat.shader = PSX_LIT_SHADER
	brass_mat.set_shader_parameter("modulate_color", Color(0.68, 0.54, 0.22))
	brass_mat.set_shader_parameter("snap_resolution", Vector2(320.0, 180.0))

	var glow_mat: StandardMaterial3D = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.76, 0.34)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.62, 0.18)
	glow_mat.emission_energy_multiplier = 1.6

	var stool: MeshInstance3D = MeshInstance3D.new()
	var sb: BoxMesh = BoxMesh.new()
	sb.size = Vector3(0.85, 0.52, 0.65)
	stool.mesh = sb
	stool.position = Vector3(0.0, 0.26, 0.0)
	stool.material_override = wood_mat
	add_child(stool)

	var base_l: MeshInstance3D = MeshInstance3D.new()
	var lb: BoxMesh = BoxMesh.new()
	lb.size = Vector3(0.24, 0.34, 0.24)
	base_l.mesh = lb
	base_l.position = Vector3(0.0, 0.69, 0.0)
	base_l.material_override = brass_mat
	add_child(base_l)

	var flame: MeshInstance3D = MeshInstance3D.new()
	var fb: BoxMesh = BoxMesh.new()
	fb.size = Vector3(0.14, 0.18, 0.14)
	flame.mesh = fb
	flame.position = Vector3(0.0, 0.69, 0.0)
	flame.material_override = glow_mat
	add_child(flame)

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.68, 0.30)
	light.light_energy = 1.15
	light.omni_range = 5.5
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 14.0
	light.position = Vector3(0.0, 0.95, 0.0)
	add_child(light)
