class_name EchoReaderUI
extends Control
## Interface de leitura dos diários "Ecos": papel envelhecido, texto datilografado e jogo pausado durante a leitura.

const UiTheme := preload("res://ui/ui_theme.gd")
const CHARS_PER_SECOND: float = 70.0

var _reveal_tween: Tween

@onready var panel: Panel = get_node_or_null("Panel") as Panel
@onready var title_label: Label = get_node_or_null("Panel/VBoxContainer/TitleLabel") as Label
@onready var body_label: Label = get_node_or_null("Panel/VBoxContainer/BodyLabel") as Label
@onready var hint_label: Label = get_node_or_null("Panel/VBoxContainer/HintLabel") as Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	_apply_paper_style()
	GameEvents.echo_opened.connect(_on_echo_opened)


func _apply_paper_style() -> void:
	var ink: Color = Color(0.16, 0.1, 0.06)
	if panel != null:
		var paper: StyleBoxFlat = UiTheme.make_box(Color(0.82, 0.76, 0.62, 0.98), Color(0.36, 0.25, 0.14), 3, 18)
		paper.shadow_color = Color(0, 0, 0, 0.6)
		paper.shadow_size = 10
		panel.add_theme_stylebox_override("panel", paper)
		panel.rotation_degrees = -0.8
	for lbl: Label in [title_label, body_label, hint_label]:
		if lbl == null:
			continue
		lbl.add_theme_color_override("font_color", ink)
		lbl.add_theme_constant_override("outline_size", 0)
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", 18)
	if body_label != null:
		body_label.add_theme_font_size_override("font_size", 16)
	if hint_label != null:
		hint_label.add_theme_font_size_override("font_size", 12)
		hint_label.add_theme_color_override("font_color", Color(0.35, 0.24, 0.14))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		# Primeiro toque completa o texto; segundo fecha.
		if body_label != null and body_label.visible_ratio < 1.0:
			if _reveal_tween != null and _reveal_tween.is_valid():
				_reveal_tween.kill()
			body_label.visible_ratio = 1.0
		else:
			close_reader()
		get_viewport().set_input_as_handled()


func close_reader() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	AudioManager.play_paper()
	GameEvents.echo_closed.emit()


func _on_echo_opened(data: EchoData) -> void:
	if data == null:
		return
	if title_label != null:
		title_label.text = "%s — %s" % [data.author_name, data.date_written]
	if body_label != null:
		body_label.text = data.confession_text
		body_label.visible_ratio = 0.0
		if _reveal_tween != null and _reveal_tween.is_valid():
			_reveal_tween.kill()
		_reveal_tween = create_tween()
		_reveal_tween.tween_property(body_label, "visible_ratio", 1.0, maxf(0.4, float(data.confession_text.length()) / CHARS_PER_SECOND))
	visible = true
	get_tree().paused = true
	if data.audio_voiceover != null:
		AudioManager.play_sfx(data.audio_voiceover)
