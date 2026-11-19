extends RigidBody3D
## Garrafa arremessável que se estilhaça ao atingir superfícies ou inimigos, emitindo ruído alto (18m) para distrair Cultistas.

const DISTRACTION_NOISE_RADIUS: float = 18.0
const MAX_LIFETIME: float = 6.0

var _shattered: bool = false
var _life_timer: float = MAX_LIFETIME


func _ready() -> void:
	collision_layer = 0
	collision_mask = (1 << 0) | (1 << 2)
	contact_monitor = true
	max_contacts_reported = 2
	continuous_cd = true
	body_entered.connect(_on_body_entered)

	var col: CollisionShape3D = CollisionShape3D.new()
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = 0.14
	col.shape = sph
	add_child(col)

	var body_mesh: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.055
	cyl.bottom_radius = 0.065
	cyl.height = 0.24
	cyl.radial_segments = 6
	body_mesh.mesh = cyl
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.42, 0.22)
	mat.roughness = 0.35
	body_mesh.material_override = mat
	add_child(body_mesh)


func _physics_process(delta: float) -> void:
	rotate_x(6.0 * delta)
	rotate_z(4.0 * delta)
	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()


func _on_body_entered(_body: Node) -> void:
	if _shattered:
		return
	_shattered = true
	AudioManager.play_glass_break()
	GameEvents.player_noise_emitted.emit(global_position, DISTRACTION_NOISE_RADIUS)
	queue_free()
