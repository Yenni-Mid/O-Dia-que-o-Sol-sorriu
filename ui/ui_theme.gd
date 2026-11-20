extends RefCounted
## Tema retrô unificado (PS1 / horror) para toda a UI. Construído em código e cacheado.
## Uso: `const UiTheme := preload("res://ui/ui_theme.gd")` e `theme = UiTheme.get_theme()`.

const INK: Color = Color(0.93, 0.89, 0.80)
const AMBER: Color = Color(1.0, 0.76, 0.32)
const AMBER_DIM: Color = Color(0.42, 0.32, 0.18)
const BG: Color = Color(0.05, 0.045, 0.04, 0.94)

static var _cached: Theme = null


static func get_theme() -> Theme:
	if _cached != null:
		return _cached
	var t: Theme = Theme.new()
	t.default_font_size = 16

	# Botões
	t.set_stylebox("normal", "Button", make_box(Color(0.08, 0.07, 0.06, 0.88), Color(0.32, 0.25, 0.16), 2, 10))
	t.set_stylebox("hover", "Button", make_box(Color(0.17, 0.11, 0.05, 0.95), AMBER, 2, 10))
	t.set_stylebox("pressed", "Button", make_box(Color(0.28, 0.15, 0.05, 1.0), Color(1.0, 0.85, 0.45), 2, 10))
	t.set_stylebox("disabled", "Button", make_box(Color(0.05, 0.05, 0.05, 0.6), Color(0.2, 0.2, 0.2), 1, 10))
	var focus: StyleBoxFlat = make_box(Color(0, 0, 0, 0), Color(1.0, 0.8, 0.35, 0.9), 1, 10)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", AMBER)
	t.set_color("font_focus_color", "Button", AMBER)
	t.set_color("font_pressed_color", "Button", Color(1.0, 0.92, 0.7))

	# Textos com contorno escuro forte (legíveis sobre a cena 3D)
	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.94))
	t.set_constant("outline_size", "Label", 5)

	# Painéis
	t.set_stylebox("panel", "Panel", make_box(BG, AMBER_DIM, 2, 14))
	t.set_stylebox("panel", "PanelContainer", make_box(BG, AMBER_DIM, 2, 14))

	# Barras
	t.set_stylebox("background", "ProgressBar", make_box(Color(0, 0, 0, 0.6), Color(0.3, 0.26, 0.2, 0.9), 1, 0))
	t.set_stylebox("fill", "ProgressBar", make_box(INK, Color(0, 0, 0, 0), 0, 0))

	# Slider
	t.set_stylebox("slider", "HSlider", make_box(Color(0.12, 0.1, 0.08), AMBER_DIM, 1, 3))
	t.set_stylebox("grabber_area", "HSlider", make_box(Color(0.75, 0.5, 0.18), Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", make_box(AMBER, Color(0, 0, 0, 0), 0, 3))

	_cached = t
	return t


static func make_box(bg: Color, border: Color, border_w: int, margin: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(0)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin * 0.6
	box.content_margin_bottom = margin * 0.6
	return box
