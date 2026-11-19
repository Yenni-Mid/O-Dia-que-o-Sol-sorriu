extends Control
## Teclado numérico de 4 dígitos para cofres do quarteirão.

const UiTheme := preload("res://ui/ui_theme.gd")

var _target_safe: Node
var _expected_code: String = ""
var _entered: String = ""

@onready var title_label: Label = get_node_or_null("Panel/VBox/TitleLabel") as Label
@onready var display_label: Label = get_node_or_null("Panel/VBox/DisplayPanel/DisplayLabel") as Label
@onready var status_label: Label = get_node_or_null("Panel/VBox/StatusLabel") as Label
@onready var grid: GridContainer = get_node_or_null("Panel/VBox/KeypadGrid") as GridContainer
@onready var close_btn: Button = get_node_or_null("Panel/VBox/CloseBtn") as Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	theme = UiTheme.get_theme()
	GameEvents.keypad_requested.connect(_on_keypad_requested)
	_wire_buttons()


func _wire_buttons() -> void:
	if grid != null:
		for child: Node in grid.get_children():
			if child is Button:
				var btn: Button = child as Button
				var txt: String = btn.text.strip_edges()
				if txt == "CLR" or txt == "C":
					btn.pressed.connect(_clear_digits)
				elif txt == "OK":
					btn.pressed.connect(_submit_code)
				elif txt.length() == 1 and txt.is_valid_int():
					btn.pressed.connect(_append_digit.bind(txt))
	if close_btn != null:
		close_btn.pressed.connect(close_keypad)


func _on_keypad_requested(safe_node: Node, title: String, expected_code: String) -> void:
	_target_safe = safe_node
	_expected_code = expected_code
	_entered = ""
	if title_label != null:
		title_label.text = title
	if status_label != null:
		status_label.text = "Digite 4 dígitos (teclado ou mouse)"
		status_label.modulate = Color(0.86, 0.80, 0.65)
	_refresh_display()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_keypad()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kev: InputEventKey = event as InputEventKey
		if kev.keycode == KEY_BACKSPACE:
			if not _entered.is_empty():
				_entered = _entered.substr(0, _entered.length() - 1)
				AudioManager.play_ui_click()
				_refresh_display()
			get_viewport().set_input_as_handled()
		elif kev.keycode == KEY_ENTER or kev.keycode == KEY_KP_ENTER:
			_submit_code()
			get_viewport().set_input_as_handled()
		elif kev.unicode >= 48 and kev.unicode <= 57:
			_append_digit(char(kev.unicode))
			get_viewport().set_input_as_handled()


func _append_digit(d: String) -> void:
	if _entered.length() >= 4:
		return
	_entered += d
	AudioManager.play_ui_click()
	_refresh_display()
	if _entered.length() == 4:
		_submit_code()


func _clear_digits() -> void:
	_entered = ""
	AudioManager.play_ui_click()
	if status_label != null:
		status_label.text = "Digite 4 dígitos"
		status_label.modulate = Color(0.86, 0.80, 0.65)
	_refresh_display()


func _submit_code() -> void:
	if _entered == _expected_code and not _expected_code.is_empty():
		AudioManager.play_unlock()
		if _target_safe != null and is_instance_valid(_target_safe) and _target_safe.has_method("on_code_accepted"):
			_target_safe.call("on_code_accepted")
		close_keypad()
	else:
		AudioManager.play_locked()
		if status_label != null:
			status_label.text = "CÓDIGO INCORRETO"
			status_label.modulate = Color(0.95, 0.34, 0.28)
		_entered = ""
		_refresh_display()


func _refresh_display() -> void:
	if display_label == null:
		return
	var slots: Array[String] = []
	for i: int in range(4):
		if i < _entered.length():
			slots.append(_entered.substr(i, 1))
		else:
			slots.append("_")
	display_label.text = " ".join(slots)


func close_keypad() -> void:
	visible = false
	_target_safe = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
