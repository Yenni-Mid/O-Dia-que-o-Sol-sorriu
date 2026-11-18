class_name FMVIntro
extends Control
## Fluxo da abertura FMV VHS: toca o vídeo de introdução (ou sequência VHS simulada do Leo), exibe "9 MESES DEPOIS..." e carrega main_game.tscn.

const MAIN_GAME_SCENE: String = "res://levels/main_game.tscn"
const INTRO_VIDEO_PATH: String = "res://assets/video/school_vhs_intro.ogv"
const SIMULATED_DURATION: float = 6.5

@export var card_duration: float = 2.2

var _transitioning: bool = false
var _sim_active: bool = false
var _sim_elapsed: float = 0.0

@onready var video_player: VideoStreamPlayer = get_node_or_null("VideoStreamPlayer") as VideoStreamPlayer
@onready var time_card_label: Label = get_node_or_null("TimeCardLabel") as Label
@onready var simulated_vhs: Control = get_node_or_null("SimulatedVHS") as Control
@onready var footage_frame: TextureRect = get_node_or_null("SimulatedVHS/FootageFrame") as TextureRect
@onready var rec_label: Label = get_node_or_null("SimulatedVHS/RecLabel") as Label
@onready var tape_header: Label = get_node_or_null("SimulatedVHS/TapeHeader") as Label
@onready var subtitle_label: Label = get_node_or_null("SimulatedVHS/SubtitleLabel") as Label


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if time_card_label != null:
		time_card_label.visible = false
	if video_player != null and ResourceLoader.exists(INTRO_VIDEO_PATH):
		video_player.stream = load(INTRO_VIDEO_PATH) as VideoStream
		video_player.finished.connect(_on_video_finished)
		video_player.play()
	else:
		_start_simulated_vhs()


func _process(delta: float) -> void:
	if not _sim_active or _transitioning:
		return

	_sim_elapsed += delta
	var t: float = clampf(_sim_elapsed / SIMULATED_DURATION, 0.0, 1.0)

	if rec_label != null:
		rec_label.visible = int(_sim_elapsed * 2.0) % 2 == 0

	if tape_header != null:
		var secs: int = 22 + int(_sim_elapsed)
		tape_header.text = "SP 00:14:%02d   OUT 1998 - COLÉGIO ESTADUAL [FITA DO LEO]" % secs

	if footage_frame != null:
		var shake_x: float = sin(_sim_elapsed * 29.0) * (2.5 + t * 5.0)
		var shake_y: float = cos(_sim_elapsed * 37.0) * (2.0 + t * 4.0)
		footage_frame.position = Vector2(shake_x, shake_y)
		footage_frame.scale = Vector2.ONE * (1.03 + t * 0.09)
		var sun_glare: float = 0.72 + t * 0.28
		footage_frame.modulate = Color(sun_glare, sun_glare * 0.94, lerpf(0.92, 0.65, t), 1.0)

	if subtitle_label != null:
		if _sim_elapsed < 2.2:
			subtitle_label.text = "[Leo]: Pai, se você achar essa fita... não olha pra cima!"
		elif _sim_elapsed < 4.4:
			subtitle_label.text = "[Leo]: O sol... ele tá sorrindo pra gente no pátio da escola..."
		else:
			subtitle_label.text = "[Vozes no corredor]: Olhem para a luz! Não tenham medo da verdade!"

	if _sim_elapsed >= SIMULATED_DURATION:
		_sim_active = false
		_start_nine_months_later_sequence()


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_sim_active = false
		if video_player != null and video_player.is_playing():
			video_player.stop()
		_start_nine_months_later_sequence()


func _start_simulated_vhs() -> void:
	_sim_active = true
	_sim_elapsed = 0.0
	if simulated_vhs != null:
		simulated_vhs.visible = true
	if footage_frame != null:
		footage_frame.pivot_offset = size * 0.5
		footage_frame.texture = _build_vhs_school_sun_texture()
	AudioManager.set_sun_drone_active(true)


func _build_vhs_school_sun_texture() -> ImageTexture:
	var w: int = 96
	var h: int = 72
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1998

	var sun_cx: float = 48.0
	var sun_cy: float = 25.0
	var sun_r: float = 14.5

	for y: int in range(h):
		var v_grad: float = float(y) / float(h)
		for x: int in range(w):
			var grain: float = rng.randf_range(-0.04, 0.04)
			var col: Color = Color(
				clampf(lerpf(0.32, 0.72, v_grad) + grain, 0.0, 1.0),
				clampf(lerpf(0.24, 0.56, v_grad) + grain, 0.0, 1.0),
				clampf(lerpf(0.08, 0.14, v_grad) + grain, 0.0, 1.0),
				1.0
			)

			# Disco solar sorridente no céu da escola
			var dx: float = float(x) - sun_cx
			var dy: float = float(y) - sun_cy
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist <= sun_r + 3.0:
				var glow: float = clampf(1.0 - maxf(0.0, dist - sun_r) / 3.0, 0.0, 1.0)
				if dist <= sun_r:
					col = Color(0.98, 0.88, 0.34, 1.0)
					# Olhos assimétricos
					var left_eye: bool = absf(dx + 4.5) <= 1.6 and absf(dy + 3.2) <= 2.2
					var right_eye: bool = absf(dx - 4.5) <= 2.0 and absf(dy + 2.4) <= 1.6
					# Sorriso largo curvado
					var smile_y: float = 4.6 - (dx * dx) * 0.055
					var is_smile: bool = absf(dx) <= 8.5 and absf(dy - smile_y) <= 1.25
					if left_eye or right_eye or is_smile:
						col = Color(0.14, 0.04, 0.03, 1.0)
				else:
					col = col.lerp(Color(0.96, 0.82, 0.28, 1.0), glow * 0.55)

			# Silhueta do telhado e janelas do colégio estadual na parte inferior
			var roof_line: int = 47 if (x >= 14 and x <= 82) else 54
			if x >= 42 and x <= 54:
				roof_line = 43
			if y >= roof_line:
				col = Color(0.07 + grain * 0.3, 0.06, 0.05, 1.0)
				# Janelas escuras / reflexo fraco do prédio escolar
				if y >= 51 and y <= 57 and (x % 8) >= 3 and (x % 8) <= 5 and x >= 18 and x <= 78:
					col = Color(0.24, 0.20, 0.09, 1.0)

			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


func _on_video_finished() -> void:
	_start_nine_months_later_sequence()


func _start_nine_months_later_sequence() -> void:
	if _transitioning:
		return
	_transitioning = true
	_sim_active = false
	AudioManager.set_sun_drone_active(false)
	AudioManager.play_lantern_ignite()
	if simulated_vhs != null:
		simulated_vhs.visible = false
	if time_card_label != null:
		time_card_label.text = "9 MESES DEPOIS..."
		time_card_label.visible = true
	await get_tree().create_timer(card_duration).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file(MAIN_GAME_SCENE)
