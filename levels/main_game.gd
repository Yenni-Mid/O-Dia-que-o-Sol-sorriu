extends Node
## Nó raiz da arquitetura PSX (SubViewport em baixa resolução + CanvasLayer_UI).

@onready var sub_viewport_container: SubViewportContainer = get_node_or_null("SubViewportContainer") as SubViewportContainer
@onready var psx_post_process: ColorRect = get_node_or_null("CanvasLayer_UI/PSXPostProcess") as ColorRect


func _ready() -> void:
	get_tree().paused = false
	AudioManager.stop_all_tension()
	AudioManager.set_wind_active(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var scale_val: int = clampi(SaveManager.psx_scale, 2, 4)
	if sub_viewport_container != null:
		sub_viewport_container.stretch_shrink = scale_val
	if psx_post_process != null:
		var mat: ShaderMaterial = psx_post_process.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("pixel_scale", float(scale_val))

	if SaveManager.has_checkpoint:
		var player: Node3D = get_node_or_null("SubViewportContainer/SubViewport/World3D/Player") as Node3D
		if player != null:
			player.global_position = SaveManager.checkpoint_position
			GameEvents.status_message_requested.emit("Retornando ao último Tambor-Fogueira aceso.")
