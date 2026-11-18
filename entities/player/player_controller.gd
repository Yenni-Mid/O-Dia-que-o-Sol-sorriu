class_name PlayerController
extends CharacterBody3D
## Controlador em 1ª pessoa com estados de furtividade (agachar, andar, correr), head bobbing e integração com Lampião/Sanidade.

enum MovementState {
	CROUCHING = 0,
	WALKING = 1,
	SPRINTING = 2,
}

const CROUCH_SPEED: float = 1.8
const WALK_SPEED: float = 3.5
const SPRINT_SPEED: float = 6.0

const CROUCH_NOISE_RADIUS: float = 1.5
const WALK_NOISE_RADIUS: float = 5.0
const SPRINT_NOISE_RADIUS: float = 12.0

const CROUCH_VISIBILITY_MULTIPLIER: float = 0.5
const WALK_VISIBILITY_MULTIPLIER: float = 1.0
const SPRINT_VISIBILITY_MULTIPLIER: float = 1.5

@export var mouse_sensitivity: float = 0.0022
@export var acceleration: float = 14.0
@export var friction: float = 16.0
@export var bob_freq: float = 2.4
@export var bob_amp: float = 0.045
@export var standing_head_height: float = 1.6
@export var crouching_head_height: float = 0.95
@export var crouch_transition_speed: float = 10.0
@export var hand_sway_amount: float = 0.0018
@export var hand_sway_smoothing: float = 12.0

var current_state: MovementState = MovementState.WALKING
var current_speed: float = WALK_SPEED
var noise_radius: float = WALK_NOISE_RADIUS
var visibility_multiplier: float = WALK_VISIBILITY_MULTIPLIER
var external_speed_multiplier: float = 1.0
var is_hidden: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _bob_time: float = 0.0
var _step_triggered: bool = false
var _hand_sway_target: Vector3 = Vector3.ZERO
var _hand_default_pos: Vector3 = Vector3.ZERO

@onready var standing_collision: CollisionShape3D = get_node_or_null("StandingCollision") as CollisionShape3D
@onready var crouching_collision: CollisionShape3D = get_node_or_null("CrouchingCollision") as CollisionShape3D
@onready var ceiling_check: RayCast3D = get_node_or_null("CeilingCheck") as RayCast3D
@onready var sun_exposure_ray: RayCast3D = get_node_or_null("SunExposureRay") as RayCast3D
@onready var head_pivot: Node3D = get_node_or_null("HeadPivot") as Node3D
@onready var camera: Camera3D = get_node_or_null("HeadPivot/Camera3D") as Camera3D
@onready var interaction_ray: RayCast3D = get_node_or_null("HeadPivot/Camera3D/InteractionRay") as RayCast3D
@onready var hand_pivot: Node3D = get_node_or_null("HeadPivot/HandPivot") as Node3D
@onready var lantern_system: LanternSystem = get_node_or_null("HeadPivot/HandPivot/LanternSystem") as LanternSystem
@onready var sanity_component: SanityComponent = get_node_or_null("SanityComponent") as SanityComponent


func _ready() -> void:
	_ensure_input_actions()
	if hand_pivot != null:
		_hand_default_pos = hand_pivot.position
	_apply_movement_state(MovementState.WALKING, true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_Event: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_y(-mouse_Event.relative.x * mouse_sensitivity)
		if head_pivot != null:
			head_pivot.rotate_x(-mouse_Event.relative.y * mouse_sensitivity)
			head_pivot.rotation.x = clampf(head_pivot.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
		_hand_sway_target.x = clampf(-mouse_Event.relative.x * hand_sway_amount, -0.06, 0.06)
		_hand_sway_target.y = clampf(mouse_Event.relative.y * hand_sway_amount, -0.06, 0.06)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if is_hidden:
		velocity = Vector3.ZERO
		_update_hand_sway(delta)
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_direction: Vector3 = (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	_update_movement_state(move_direction != Vector3.ZERO)

	var target_speed: float = current_speed * external_speed_multiplier
	if move_direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, move_direction.x * target_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_direction.z * target_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	move_and_slide()

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	_update_crouch_And_head_bob(delta, horizontal_speed)
	_update_hand_sway(delta)

	if horizontal_speed > 0.25 and is_on_floor():
		GameEvents.player_noise_emitted.emit(global_position, noise_radius)


func set_speed_modifier(multiplier: float) -> void:
	external_speed_multiplier = clampf(multiplier, 0.1, 2.0)


func reset_speed_modifier() -> void:
	external_speed_multiplier = 1.0


func get_effective_noise_radius() -> float:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed <= 0.15 or not is_on_floor():
		return 0.0
	return noise_radius


func get_detection_distance(base_dark_vision_range: float = 8.0, lit_vision_range: float = 22.0) -> float:
	if is_hidden:
		return 0.0
	var exposed_to_light: bool = false
	if lantern_system != null and lantern_system.is_lit:
		exposed_to_light = true
	if sanity_component != null and sanity_component.in_sunlight:
		exposed_to_light = true
	if exposed_to_light:
		return lit_vision_range * visibility_multiplier
	return base_dark_vision_range * visibility_multiplier


func enter_hiding_spot(hide_pos: Vector3) -> void:
	is_hidden = true
	velocity = Vector3.ZERO
	if lantern_system != null:
		lantern_system.set_lantern_lit(false)
	if standing_collision != null:
		standing_collision.disabled = true
	if crouching_collision != null:
		crouching_collision.disabled = true
	global_position = hide_pos
	GameEvents.player_hidden_changed.emit(true)


func exit_hiding_spot(exit_pos: Vector3) -> void:
	is_hidden = false
	global_position = exit_pos
	_apply_movement_state(MovementState.WALKING, true)
	GameEvents.player_hidden_changed.emit(false)


func _update_movement_state(is_moving: bool) -> void:
	var wants_crouch: bool = Input.is_action_pressed("crouch")
	var blocked_above: bool = current_state == MovementState.CROUCHING and _is_ceiling_blocked()

	var next_state: MovementState = MovementState.WALKING
	if wants_crouch or blocked_above:
		next_state = MovementState.CROUCHING
	elif is_moving and Input.is_action_pressed("sprint"):
		next_state = MovementState.SPRINTING

	_apply_movement_state(next_state, false)


func _apply_movement_state(next_state: MovementState, force: bool) -> void:
	if not force and current_state == next_state:
		return
	current_state = next_state

	match current_state:
		MovementState.CROUCHING:
			current_speed = CROUCH_SPEED
			noise_radius = CROUCH_NOISE_RADIUS
			visibility_multiplier = CROUCH_VISIBILITY_MULTIPLIER
		MovementState.WALKING:
			current_speed = WALK_SPEED
			noise_radius = WALK_NOISE_RADIUS
			visibility_multiplier = WALK_VISIBILITY_MULTIPLIER
		MovementState.SPRINTING:
			current_speed = SPRINT_SPEED
			noise_radius = SPRINT_NOISE_RADIUS
			visibility_multiplier = SPRINT_VISIBILITY_MULTIPLIER

	var is_crouching: bool = current_state == MovementState.CROUCHING
	if standing_collision != null:
		standing_collision.disabled = is_crouching
	if crouching_collision != null:
		crouching_collision.disabled = not is_crouching

	GameEvents.player_movement_state_changed.emit(int(current_state), noise_radius, visibility_multiplier)


func _is_ceiling_blocked() -> bool:
	if ceiling_check == null:
		return false
	ceiling_check.force_raycast_update()
	return ceiling_check.is_colliding()


func _update_crouch_And_head_bob(delta: float, horizontal_speed: float) -> void:
	if head_pivot != null:
		var target_head_y: float = crouching_head_height if current_state == MovementState.CROUCHING else standing_head_height
		head_pivot.position.y = lerpf(head_pivot.position.y, target_head_y, clampf(crouch_transition_speed * delta, 0.0, 1.0))

	if camera != null:
		if is_on_floor() and horizontal_speed > 0.15:
			_bob_time += delta * horizontal_speed
			var speed_factor: float = clampf(horizontal_speed / WALK_SPEED, 0.0, 1.8)
			var bob_wave: float = sin(_bob_time * bob_freq)
			var bob_offset_y: float = bob_wave * bob_amp * speed_factor
			var bob_offset_x: float = cos(_bob_time * bob_freq * 0.5) * (bob_amp * 0.5) * speed_factor
			camera.position.y = lerpf(camera.position.y, bob_offset_y, clampf(12.0 * delta, 0.0, 1.0))
			camera.position.x = lerpf(camera.position.x, bob_offset_x, clampf(12.0 * delta, 0.0, 1.0))
			if bob_wave < -0.85:
				if not _step_triggered:
					_step_triggered = true
					var step_db: float = -18.0 if current_state == MovementState.CROUCHING else (-6.0 if current_state == MovementState.SPRINTING else -11.0)
					var step_pitch: float = 0.85 if current_state == MovementState.CROUCHING else (1.15 if current_state == MovementState.SPRINTING else 1.0)
					AudioManager.play_footstep(step_db, step_pitch)
			else:
				_step_triggered = false
		else:
			_bob_time = 0.0
			_step_triggered = false
			camera.position.y = lerpf(camera.position.y, 0.0, clampf(10.0 * delta, 0.0, 1.0))
			camera.position.x = lerpf(camera.position.x, 0.0, clampf(10.0 * delta, 0.0, 1.0))


func _update_hand_sway(delta: float) -> void:
	if hand_pivot == null:
		return
	var target_pos: Vector3 = _hand_default_pos + _hand_sway_target
	hand_pivot.position = hand_pivot.position.lerp(target_pos, clampf(hand_sway_smoothing * delta, 0.0, 1.0))
	_hand_sway_target = _hand_sway_target.lerp(Vector3.ZERO, clampf(hand_sway_smoothing * delta, 0.0, 1.0))


func _ensure_input_actions() -> void:
	var bindings: Dictionary = {
		"move_forward": KEY_W,
		"move_backward": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"sprint": KEY_SHIFT,
		"crouch": KEY_CTRL,
	}
	for action_name: String in bindings:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		var key_event: InputEventKey = InputEventKey.new()
		key_event.physical_keycode = bindings[action_name] as Key
		InputMap.action_add_event(action_name, key_event)
