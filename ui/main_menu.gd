extends Control
## Menu Principal retrô PS1/VHS de "O Dia Que O Sol Sorriu".

const FMV_INTRO_SCENE: String = "res://ui/fmv_intro.tscn"
const MAIN_GAME_SCENE: String = "res://levels/main_game.tscn"

@onready var new_game_button: Button = get_node_or_null("MenuContainer/ButtonList/NewGameButton") as Button
@onready var direct_demo_button: Button = get_node_or_null("MenuContainer/ButtonList/DirectDemoButton") as Button
@onready var controls_button: Button = get_node_or_null("MenuContainer/ButtonList/ControlsButton") as Button
@onready var quit_button: Button = get_node_or_null("MenuContainer/ButtonList/QuitButton") as Button
@onready var controls_panel: PanelContainer = get_node_or_null("ControlsPanel") as PanelContainer
@onready var sun_emblem: TextureRect = get_node_or_null("SunEmblem") as TextureRect


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	AudioManager.set_sun_drone_active(false)
	AudioManager.set_heartbeat_intensity(0.0)

	if controls_panel != null:
		controls_panel.visible = false
	if sun_emblem != null:
		sun_emblem.texture = _build_sun_emblem_texture()

	if new_game_button != null:
		new_game_button.pressed.connect(_on_new_game_pressed)
		new_game_button.grab_focus()
	if direct_demo_button != null:
		direct_demo_button.pressed.connect(_on_direct_demo_pressed)
	if controls_button != null:
		controls_button.pressed.connect(_on_controls_pressed)
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)


func _on_new_game_pressed() -> void:
	AudioManager.play_lantern_ignite()
	get_tree().change_scene_to_file(FMV_INTRO_SCENE)


func _on_direct_demo_pressed() -> void:
	AudioManager.play_door_creak()
	get_tree().change_scene_to_file(MAIN_GAME_SCENE)


func _on_controls_pressed() -> void:
	if controls_panel != null:
		controls_panel.visible = not controls_panel.visible


func _on_quit_pressed() -> void:
	get_tree().quit()


func _build_sun_emblem_texture() -> ImageTexture:
	var size_px: int = 48
	var img: Image = Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	var center: float = float(size_px) * 0.5
	var radius: float = 17.0

	for y: int in range(size_px):
		for x: int in range(size_px):
			var dx: float = float(x) - center
			var dy: float = float(y) - center
			var dist: float = sqrt(dx * dx + dy * dy)
			var col: Color = Color(0.0, 0.0, 0.0, 0.0)
			if dist <= radius + 4.0:
				if dist <= radius:
					col = Color(0.95, 0.80, 0.25, 0.92)
					var left_eye: bool = absf(dx + 5.2) <= 1.8 and absf(dy + 3.5) <= 2.4
					var right_eye: bool = absf(dx - 5.2) <= 2.2 and absf(dy + 2.8) <= 1.8
					var smile_y: float = 5.4 - (dx * dx) * 0.048
					var is_smile: bool = absf(dx) <= 9.5 and absf(dy - smile_y) <= 1.35
					if left_eye or right_eye or is_smile:
						col = Color(0.12, 0.04, 0.03, 1.0)
				else:
					var glow: float = 1.0 - (dist - radius) / 4.0
					col = Color(0.95, 0.72, 0.20, clampf(glow * 0.35, 0.0, 0.35))
			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)
