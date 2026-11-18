extends Node
## Barramento global de eventos (Event Bus) para desacoplamento entre Player, Inimigos e UI.

signal sanity_changed(current: float, max_val: float)
signal sanity_depleted()
signal lighting_zone_changed(zone: int)
signal confession_triggered(text: String)

signal oil_changed(current: float, max_val: float)
signal lantern_toggled(is_lit: bool)
signal lantern_depleted()

signal player_noise_emitted(origin: Vector3, radius: float)
signal player_movement_state_changed(state: int, noise_radius: float, visibility_multiplier: float)
signal player_hidden_changed(is_hidden: bool)

signal health_changed(current: float, max_val: float)
signal player_died()

signal echo_opened(data: EchoData)
signal echo_closed()
signal interaction_prompt_changed(prompt_text: String)
