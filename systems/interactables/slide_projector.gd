extends StaticBody3D
## Projetor de Slides Escolar interativo no 2º andar da Escola Municipal "Aurora Solar".
## Ao interagir [E], avança entre 3 slides históricos sobre o fenômeno do Sol Sorridente.

var _slide_index: int = -1
var _screen_mat: StandardMaterial3D
var _beam_light: SpotLight3D
var _slide_textures: Array[ImageTexture] = []

const SLIDE_CAPTIONS: Array[String] = [
	"Slide #01 (14:09) — 'O disco solar parou no zênite. Nenhum relógio da escola avançou depois disso.'",
	"Slide #02 (14:12) — 'Quem olhou para o céu no pátio começou a sorrir em silêncio e caminhar para a praça.'",
	"Slide #03 (17/10) — 'O Diretor trancou a chave da Capela no cofre (1710) antes que levassem as crianças à Torre.'",
]


func _ready() -> void:
	collision_layer = (1 << 0) | (1 << 3)
	collision_mask = 0
	_build_slide_textures()
	_build_projector_and_screen()


func get_interaction_prompt() -> String:
	if _slide_index < 0:
		return "[E] Ligar Projetor de Slides"
	return "[E] Passar Slide (%d/3)" % (_slide_index + 1)


func interact(_player: Node = null) -> void:
	_slide_index = (_slide_index + 1) % 3
	AudioManager.play_ui_click()
	if _beam_light != null:
		_beam_light.visible = true
	if _screen_mat != null and _slide_index < _slide_textures.size():
		_screen_mat.albedo_texture = _slide_textures[_slide_index]
		_screen_mat.emission_enabled = true
		_screen_mat.emission_texture = _slide_textures[_slide_index]
		_screen_mat.emission_energy_multiplier = 1.35
	GameEvents.confession_triggered.emit(SLIDE_CAPTIONS[_slide_index])


func _build_slide_textures() -> void:
	_slide_textures.clear()
	for s_idx: int in range(3):
		var img: Image = Image.create(64, 48, false, Image.FORMAT_RGBA8)
		for y: int in range(48):
			for x: int in range(64):
				var border: bool = x < 3 or x >= 61 or y < 3 or y >= 45
				if border:
					img.set_pixel(x, y, Color(0.10, 0.08, 0.06, 1.0))
					continue
				var bg: Color = Color(0.76, 0.62, 0.34, 1.0) if s_idx == 0 else (Color(0.68, 0.42, 0.24, 1.0) if s_idx == 1 else Color(0.45, 0.22, 0.18, 1.0))
				var dx: float = float(x - 32)
				var dy: float = float(y - 18)
				var dist: float = sqrt(dx * dx + dy * dy)
				if s_idx == 0 and dist < 11.0:
					bg = Color(0.98, 0.88, 0.42, 1.0) if dist > 8.5 else Color(0.16, 0.08, 0.06, 1.0)
				elif s_idx == 1 and absf(dist - 10.0) < 2.2:
					bg = Color(0.96, 0.72, 0.22, 1.0)
				elif s_idx == 2 and absf(dx) < 5.0 and y > 10:
					bg = Color(0.12, 0.08, 0.08, 1.0)
				img.set_pixel(x, y, bg)
		_slide_textures.append(ImageTexture.create_from_image(img))


func _build_projector_and_screen() -> void:
	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.24, 0.25, 0.27)

	var stand: MeshInstance3D = MeshInstance3D.new()
	var sm: BoxMesh = BoxMesh.new()
	sm.size = Vector3(0.75, 0.85, 0.75)
	stand.mesh = sm
	stand.position = Vector3(0.0, 0.425, 0.0)
	stand.material_override = body_mat
	add_child(stand)

	var proj_box: MeshInstance3D = MeshInstance3D.new()
	var pm: BoxMesh = BoxMesh.new()
	pm.size = Vector3(0.48, 0.34, 0.42)
	proj_box.mesh = pm
	proj_box.position = Vector3(0.0, 1.02, 0.0)
	proj_box.material_override = body_mat
	add_child(proj_box)

	var col: CollisionShape3D = CollisionShape3D.new()
	var cs: BoxShape3D = BoxShape3D.new()
	cs.size = Vector3(0.85, 1.25, 0.85)
	col.shape = cs
	col.position = Vector3(0.0, 0.625, 0.0)
	add_child(col)

	_screen_mat = StandardMaterial3D.new()
	_screen_mat.albedo_color = Color(0.86, 0.84, 0.78)
	_screen_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var screen: MeshInstance3D = MeshInstance3D.new()
	screen.name = "ProjectionScreen"
	var scm: BoxMesh = BoxMesh.new()
	scm.size = Vector3(0.08, 2.2, 3.2)
	screen.mesh = scm
	screen.position = Vector3(4.9, 1.65, 0.0)
	screen.material_override = _screen_mat
	add_child(screen)

	_beam_light = SpotLight3D.new()
	_beam_light.name = "ProjectorBeam"
	_beam_light.position = Vector3(0.28, 1.05, 0.0)
	_beam_light.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	_beam_light.light_color = Color(1.0, 0.82, 0.48)
	_beam_light.light_energy = 2.2
	_beam_light.spot_range = 7.0
	_beam_light.spot_angle = 26.0
	_beam_light.visible = false
	add_child(_beam_light)
