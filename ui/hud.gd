class_name GameHUD
extends Control
## HUD discreta com barras diegéticas/retrô de Óleo, Sanidade, Vida, Zona de Iluminação, Confissões e Prompt de Interação.

var _confession_timer: float = 0.0

@onready var oil_bar: ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/OilBar") as ProgressBar
@onready var sanity_bar: ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/SanityBar") as ProgressBar
@onready var health_bar: ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/HealthBar") as ProgressBar
@onready var zone_label: Label = get_node_or_null("MarginContainer/VBoxContainer/ZoneLabel") as Label
@onready var prompt_label: Label = get_node_or_null("InteractionPrompt") as Label
@onready var confession_label: Label = get_node_or_null("ConfessionLabel") as Label
@onready var sun_vignette: ColorRect = get_node_or_null("SunVignette") as ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if prompt_label != null:
		prompt_label.text = ""
	if confession_label != null:
		confession_label.text = ""
		confession_label.visible = false
	GameEvents.oil_changed.connect(_on_oil_changed)
	GameEvents.sanity_changed.connect(_on_sanity_changed)
	GameEvents.health_changed.connect(_on_health_changed)
	GameEvents.lighting_zone_changed.connect(_on_lighting_zone_changed)
	GameEvents.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	GameEvents.confession_triggered.connect(_on_confession_triggered)
	GameEvents.player_hidden_changed.connect(_on_player_hidden_changed)


func _process(delta: float) -> void:
	if _confession_timer > 0.0:
		_confession_timer -= delta
		if _confession_timer <= 0.0 and confession_label != null:
			confession_label.visible = false


func _on_oil_changed(current: float, max_val: float) -> void:
	if oil_bar != null:
		oil_bar.max_value = max_val
		oil_bar.value = current


func _on_sanity_changed(current: float, max_val: float) -> void:
	if sanity_bar != null:
		sanity_bar.max_value = max_val
		sanity_bar.value = current


func _on_health_changed(current: float, max_val: float) -> void:
	if health_bar != null:
		health_bar.max_value = max_val
		health_bar.value = current


func _on_lighting_zone_changed(zone: int) -> void:
	if zone_label != null:
		match zone:
			0:
				zone_label.text = "ZONA: EXPOSTO AO SOL SORRIDENTE (-Sanidade)"
			1:
				zone_label.text = "ZONA: ESCURIDÃO ABSOLUTA (Vulnerável às Sombras)"
			2:
				zone_label.text = "ZONA: PROTEGIDO PELO FOGO HUMANO (+Sanidade)"
	if sun_vignette != null:
		sun_vignette.visible = (zone == 0)


func _on_interaction_prompt_changed(prompt_text: String) -> void:
	if prompt_label != null:
		prompt_label.text = prompt_text


func _on_confession_triggered(text: String) -> void:
	if confession_label == null:
		return
	confession_label.text = text
	confession_label.visible = true
	_confession_timer = 4.0


func _on_player_hidden_changed(is_hidden: bool) -> void:
	if zone_label != null and is_hidden:
		zone_label.text = "ESCONDIDO NO GUARDA-ROUPA (Pressione [E] para sair)"
