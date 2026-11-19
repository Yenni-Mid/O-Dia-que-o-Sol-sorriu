extends Control
## Interface de reprodução das Fitas VHS encontradas nos gravadores do quarteirão.

const UiTheme := preload("res://ui/ui_theme.gd")
const LINE_DURATION: float = 3.6

var _lines: Array[String] = []
var _line_idx: int = 0
var _line_timer: float = 0.0
var _elapsed: float = 0.0
var _static_player: AudioStreamPlayer

@onready var panel: PanelContainer = get_node_or_null("Panel") as PanelContainer
@onready var title_label: Label = get_node_or_null("Panel/VBox/Header/TitleLabel") as Label
@onready var counter_label: Label = get_node_or_null("Panel/VBox/Header/CounterLabel") as Label
@onready var preview_rect: TextureRect = get_node_or_null("Panel/VBox/FrameBox/PreviewRect") as TextureRect
@onready var subtitle_label: Label = get_node_or_null("Panel/VBox/FrameBox/SubtitleLabel") as Label
@onready var hint_label: Label = get_node_or_null("Panel/VBox/HintLabel") as Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	theme = UiTheme.get_theme()
	_static_player = AudioStreamPlayer.new()
	_static_player.name = "VHSStaticPlayer"
	_static_player.stream = AudioManager.get_vhs_static_stream()
	_static_player.volume_db = -17.0
	add_child(_static_player)
	GameEvents.vhs_tape_requested.connect(_on_vhs_tape_requested)


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if counter_label != null:
		var secs: int = int(_elapsed)
		var blink: String = "PLAY ▶" if int(_elapsed * 2.0) % 2 == 0 else "PLAY  "
		counter_label.text = "%s  SP 00:0%d:%02d" % [blink, secs / 60, secs % 60]
	if preview_rect != null:
		preview_rect.position = Vector2(sin(_elapsed * 27.0) * 2.0, cos(_elapsed * 33.0) * 1.5)

	_line_timer -= delta
	if _line_timer <= 0.0:
		_advance_line()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_tape()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_advance_line()
		get_viewport().set_input_as_handled()


func _on_vhs_tape_requested(tape_id: String, title: String, lines: Array) -> void:
	_lines.clear()
	for entry: Variant in lines:
		_lines.append(str(entry))
	if _lines.is_empty():
		_lines.append("[Fita danificada — apenas estática.]")

	_line_idx = 0
	_line_timer = LINE_DURATION
	_elapsed = 0.0

	if title_label != null:
		title_label.text = title
	if subtitle_label != null:
		subtitle_label.text = _lines[0]
	if preview_rect != null:
		preview_rect.texture = _build_tape_thumbnail(tape_id)

	visible = true
	get_tree().paused = true
	if _static_player != null and _static_player.stream != null:
		_static_player.play()


func _advance_line() -> void:
	_line_idx += 1
	if _line_idx >= _lines.size():
		close_tape()
		return
	_line_timer = LINE_DURATION
	if subtitle_label != null:
		subtitle_label.text = _lines[_line_idx]


func close_tape() -> void:
	visible = false
	if _static_player != null and _static_player.playing:
		_static_player.stop()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_tape_thumbnail(tape_id: String) -> ImageTexture:
	var w: int = 96
	var h: int = 64
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = tape_id.hash()

	for y: int in range(h):
		var scan: float = 0.88 if (y % 2) == 0 else 1.0
		for x: int in range(w):
			var noise: float = rng.randf_range(-0.07, 0.07)
			var col: Color = Color(0.14, 0.13, 0.11)
			if tape_id == "tape_market":
				col = Color(0.10, 0.16, 0.13)
				if y > 40:
					col = Color(0.18, 0.22, 0.18)
				if absf(float(x) - 52.0) < 6.0 and y > 24 and y < 52:
					col = Color(0.75, 0.72, 0.65)
			elif tape_id == "tape_plaza":
				col = Color(0.18, 0.10, 0.12)
				var d: float = Vector2(float(x) - 48.0, float(y) - 24.0).length()
				if d < 12.0:
					col = Color(0.95, 0.78, 0.28)
				if y > 42:
					col = Color(0.08, 0.05, 0.06)
			else:
				col = Color(0.22, 0.18, 0.10)
				if absf(float(x) - 48.0) < 28.0 and y > 10 and y < 48:
					col = Color(0.75, 0.62, 0.25) if (y < 32) else Color(0.12, 0.12, 0.14)
			img.set_pixel(x, y, Color(
				clampf(col.r * scan + noise, 0.0, 1.0),
				clampf(col.g * scan + noise, 0.0, 1.0),
				clampf(col.b * scan + noise, 0.0, 1.0),
				1.0
			))
	return ImageTexture.create_from_image(img)
