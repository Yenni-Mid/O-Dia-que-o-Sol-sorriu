extends Node
## Nó raiz da arquitetura PSX (320x240 SubViewport + CanvasLayer_UI).

@onready var sub_viewport: SubViewport = get_node_or_null("SubViewportContainer/SubViewport") as SubViewport


func _unhandled_input(event: InputEvent) -> void:
	if sub_viewport != null:
		sub_viewport.push_input(event)
