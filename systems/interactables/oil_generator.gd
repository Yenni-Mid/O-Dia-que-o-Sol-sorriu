extends StaticBody3D
## Gerador de Emergência a Óleo na Câmara da Cisterna do Esgoto.
## Ao transferir 15% de óleo do lampião [E], ilumina o tronco principal do esgoto,
## dissipa as Sombras Vivas da galeria norte/central e abre a grade de suprimentos da cisterna.

var is_running: bool = false
var _piston_mesh: MeshInstance3D
var _status_lamp_mat: StandardMaterial3D
var _supply_gate: Node3D
var _floodlights: Array[OmniLight3D] = []
var _run_time: float = 0.0


func _ready() -> void:
	collision_layer = (1 << 0) | (1 << 3)
	collision_mask = 0
	_build_generator_and_gate()


func _exit_tree() -> void:
	_floodlights.clear()
	_status_lamp_mat = null
	_piston_mesh = null
	_supply_gate = null


func _process(delta: float) -> void:
	if not is_running:
		return
	_run_time += delta
	if _piston_mesh != null:
		_piston_mesh.position.y = 0.92 + sin(_run_time * 38.0) * 0.03
	if _supply_gate != null:
		_supply_gate.position.y = move_toward(_supply_gate.position.y, 2.35, 1.8 * delta)


func get_interaction_prompt() -> String:
	if is_running:
		return "Gerador de Emergência [EM OPERAÇÃO]"
	return "[E] Abastecer Gerador (15% Óleo do Lampião)"


func interact(player: Node = null) -> void:
	if is_running:
		GameEvents.status_message_requested.emit("O gerador já está alimentando as luzes do esgoto.")
		return
	var lantern: Node = null
	if player != null:
		lantern = player.get("lantern_system") as Node
	if lantern == null:
		lantern = get_tree().get_first_node_in_group("lantern")
	if lantern == null or not lantern.has_method("consume_oil_amount"):
		return
	if not bool(lantern.call("consume_oil_amount", 15.0)):
		AudioManager.play_locked()
		GameEvents.status_message_requested.emit("Óleo insuficiente no lampião (requer 15%).")
		return

	is_running = true
	AudioManager.play_lantern_ignite()
	GameEvents.camera_shake_requested.emit(0.16)
	if _status_lamp_mat != null:
		_status_lamp_mat.albedo_color = Color(0.25, 0.95, 0.35)
		_status_lamp_mat.emission = Color(0.20, 0.90, 0.30)

	for fl: OmniLight3D in _floodlights:
		if fl != null:
			fl.visible = true

	for sh_node: Node in get_tree().get_nodes_in_group("shadow_hazard"):
		if sh_node is Node3D and sh_node.has_method("set_permanent_suppression"):
			var sh3: Node3D = sh_node as Node3D
			if sh3.global_position.y < -1.5 and sh3.global_position.x < -40.0:
				sh3.call("set_permanent_suppression", true)

	GameEvents.status_message_requested.emit("Gerador ligado! Galeria do esgoto iluminada e grade da cisterna aberta.")


func _build_generator_and_gate() -> void:
	var rust_mat: StandardMaterial3D = StandardMaterial3D.new()
	rust_mat.albedo_color = Color(0.42, 0.28, 0.18)
	var dark_mat: StandardMaterial3D = StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.20, 0.22, 0.24)

	var base_mesh: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(1.25, 0.82, 0.85)
	base_mesh.mesh = bm
	base_mesh.position = Vector3(0.0, 0.41, 0.0)
	base_mesh.material_override = rust_mat
	add_child(base_mesh)

	_piston_mesh = MeshInstance3D.new()
	var pm: BoxMesh = BoxMesh.new()
	pm.size = Vector3(0.65, 0.28, 0.55)
	_piston_mesh.mesh = pm
	_piston_mesh.position = Vector3(0.0, 0.92, 0.0)
	_piston_mesh.material_override = dark_mat
	add_child(_piston_mesh)

	_status_lamp_mat = StandardMaterial3D.new()
	_status_lamp_mat.albedo_color = Color(0.85, 0.18, 0.14)
	_status_lamp_mat.emission_enabled = true
	_status_lamp_mat.emission = Color(0.80, 0.12, 0.10)
	_status_lamp_mat.emission_energy_multiplier = 1.6

	var lamp: MeshInstance3D = MeshInstance3D.new()
	var lm: BoxMesh = BoxMesh.new()
	lm.size = Vector3(0.16, 0.16, 0.16)
	lamp.mesh = lm
	lamp.position = Vector3(0.45, 0.95, 0.25)
	lamp.material_override = _status_lamp_mat
	add_child(lamp)

	var col: CollisionShape3D = CollisionShape3D.new()
	var cs: BoxShape3D = BoxShape3D.new()
	cs.size = Vector3(1.3, 1.1, 0.9)
	col.shape = cs
	col.position = Vector3(0.0, 0.55, 0.0)
	add_child(col)

	# Grade elétrica na Cisterna (fecha o nicho noroeste X:-53.5..-51.0, Z:-28.8..-26.8 até o gerador ser ligado)
	var gate_body: StaticBody3D = StaticBody3D.new()
	gate_body.name = "SewerSupplyGate"
	gate_body.position = Vector3(0.8, 0.0, -2.5)
	gate_body.collision_layer = 1
	gate_body.collision_mask = 0
	add_child(gate_body)
	_supply_gate = gate_body

	var gm: MeshInstance3D = MeshInstance3D.new()
	var gbox: BoxMesh = BoxMesh.new()
	gbox.size = Vector3(2.4, 2.5, 0.14)
	gm.mesh = gbox
	gm.position = Vector3(0.0, 1.25, 0.0)
	gm.material_override = dark_mat
	gate_body.add_child(gm)

	var gc: CollisionShape3D = CollisionShape3D.new()
	var gshape: BoxShape3D = BoxShape3D.new()
	gshape.size = Vector3(2.4, 2.5, 0.16)
	gc.shape = gshape
	gc.position = Vector3(0.0, 1.25, 0.0)
	gate_body.add_child(gc)

	# 3 Refletores industriais no tronco do esgoto (em coordenadas locais relativas a (-52.2, -3.2, -24.2))
	var world_targets: Array[Vector3] = [
		Vector3(-50.6, -0.7, -26.0),
		Vector3(-46.0, -0.7, -20.0),
		Vector3(-46.0, -0.7, -39.0),
	]
	for idx: int in range(world_targets.size()):
		var fl: OmniLight3D = OmniLight3D.new()
		fl.name = "SewerFloodlight_%d" % idx
		fl.position = world_targets[idx] - Vector3(-52.2, -3.2, -24.2)
		fl.light_color = Color(1.0, 0.84, 0.52)
		fl.light_energy = 1.65
		fl.omni_range = 11.5
		fl.shadow_enabled = false
		fl.visible = false
		add_child(fl)
		_floodlights.append(fl)
