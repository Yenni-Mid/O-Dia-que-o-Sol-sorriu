class_name EchoReaderUI
extends Control
## Interface de leitura dos diários "Ecos" encontrados nas sombras.

@onready var title_label: Label = get_node_or_null("Panel/VBoxContainer/TitleLabel") as Label
@onready var body_label: Label = get_node_or_null("Panel/VBoxContainer/BodyLabel") as Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameEvents.echo_opened.connect(_on_echo_opened)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close_reader()
		get_viewport().set_input_as_handled()


func close_reader() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameEvents.echo_closed.emit()


func _on_echo_opened(data: EchoData) -> void:
	if data == null:
		return
	if title_label != null:
		title_label.text = "%s — %s" % [data.author_name, data.date_written]
	if body_label != null:
		body_label.text = data.confession_text
	visible = true
	if data.audio_voiceover != null:
		AudioManager.play_sfx(data.audio_voiceover)
