extends Node3D
## Partículas de poeira flutuando no ar (iluminadas pela luz da cena). Leve: ~40 quads por emissor.

@export var extents: Vector3 = Vector3(2.5, 1.2, 2.5)
@export var amount: int = 40
@export var mote_color: Color = Color(1.0, 0.93, 0.78, 0.55)
@export var mote_size: float = 0.03


func _ready() -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Motes"
	particles.amount = amount
	particles.lifetime = 9.0
	particles.preprocess = 9.0
	particles.randomness = 0.6
	particles.visibility_aabb = AABB(-extents - Vector3.ONE, (extents + Vector3.ONE) * 2.0)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 180.0
	process.initial_velocity_min = 0.02
	process.initial_velocity_max = 0.09
	process.gravity = Vector3(0.0, -0.012, 0.0)
	process.scale_min = 0.6
	process.scale_max = 1.4

	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.25, Color(1, 1, 1, 1))
	ramp.add_point(0.75, Color(1, 1, 1, 1))
	var ramp_tex: GradientTexture1D = GradientTexture1D.new()
	ramp_tex.gradient = ramp
	process.color_ramp = ramp_tex
	particles.process_material = process

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(mote_size, mote_size)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = mote_color
	quad.material = mat
	particles.draw_pass_1 = quad

	add_child(particles)
