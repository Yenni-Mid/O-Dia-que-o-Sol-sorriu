class_name PlayerController
extends CharacterBody3D
## Controlador em 1ª pessoa com furtividade (agachar, andar, correr), fôlego, head bobbing e guarda-roupa.

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
const THROWABLE_BOTTLE_SCRIPT := preload("res://systems/interactables/throwable_bottle.gd")

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
@export var base_fov: float = 75.0
@export var sprint_fov_bonus: float = 7.0
@export var strafe_roll_degrees: float = 1.6
@export var max_shake_degrees: float = 2.6
@export var noise_emit_interval: float = 0.2

@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 28.0
@export var stamina_recover_walk: float = 14.0
@export var stamina_recover_idle: float = 26.0
@export var exhausted_threshold: float = 25.0
@export var lean_distance: float = 0.42
@export var lean_roll_degrees: float = 10.0

var current_state: MovementState = MovementState.WALKING
var current_speed: float = WALK_SPEED
var noise_radius: float = WALK_NOISE_RADIUS
var visibility_multiplier: float = WALK_VISIBILITY_MULTIPLIER
var external_speed_multiplier: float = 1.0
var is_hidden: bool = false
var current_stamina: float = 100.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _bob_time: float = 0.0
var _step_triggered: bool = false
var _hand_sway_target: Vector3 = Vector3.ZERO
var _hand_default_pos: Vector3 = Vector3.ZERO
var _noise_timer: float = 0.0
var _trauma: float = 0.0
var _shake_time: float = 0.0
var _strafe_input: float = 0.0
var _shake_noise: FastNoiseLite = FastNoiseLite.new()

var _exhausted: bool = false
var _last_emitted_stamina: float = -1.0
var _hiding_exit_pos: Vector3 = Vector3.ZERO
var _hiding_wardrobe: Node = null
var _lean_factor: float = 0.0
var _lean_roll: float = 0.0

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
	add_to_group("player")
	_ensure_input_actions()
	mouse_sensitivity = SaveManager.mouse_sensitivity
	current_stamina = max_stamina
	_emit_stamina(true)
	_shake_noise.seed = 7
	_shake_noise.frequency = 0.9
	if hand_pivot != null:
		_hand_default_pos = hand_pivot.position
	if camera != null:
		camera.fov = base_fov
	_apply_movement_state(MovementState.WALKING, true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameEvents.camera_shake_requested.connect(add_trauma)


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func get_eye_position() -> Vector3:
	if head_pivot != null:
		return head_pivot.global_position
	var eye_y: float = crouching_head_height if current_state == MovementState.CROUCHING else standing_head_height
	return global_position + Vector3(0.0, eye_y, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if is_hidden and event.is_action_pressed("interact"):
		var wardrobe_ref: Node = _hiding_wardrobe
		exit_hiding_spot(_hiding_exit_pos)
		if wardrobe_ref != null and wardrobe_ref.has_method("clear_occupant"):
			wardrobe_ref.call("clear_occupant")
		AudioManager.play_door_creak()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_y(-mouse_event.relative.x * mouse_sensitivity)
		if head_pivot != null:
			head_pivot.rotate_x(-mouse_event.relative.y * mouse_sensitivity)
			head_pivot.rotation.x = clampf(head_pivot.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
		_hand_sway_target.x = clampf(-mouse_event.relative.x * hand_sway_amount, -0.06, 0.06)
		_hand_sway_target.y = clampf(mouse_event.relative.y * hand_sway_amount, -0.06, 0.06)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif not is_hidden and not get_tree().paused:
		if event.is_action_pressed("throw_bottle"):
			_try_throw_bottle()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("use_bandage"):
			_try_use_bandage()
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if is_hidden:
		velocity = Vector3.ZERO
		_recover_stamina(stamina_recover_idle * delta)
		_update_hand_sway(delta)
		_update_camera_feel(delta, 0.0)
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	_strafe_input = input_dir.x
	var move_direction: Vector3 = (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	_update_movement_state(move_direction != Vector3.ZERO)
	_update_stamina(delta, move_direction != Vector3.ZERO)

	var target_speed: float = current_speed * external_speed_multiplier
	if move_direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, move_direction.x * target_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_direction.z * target_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	move_and_slide()

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	_update_crouch_and_head_bob(delta, horizontal_speed)
	_update_hand_sway(delta)
	_update_camera_feel(delta, horizontal_speed)

	_noise_timer -= delta
	if horizontal_speed > 0.25 and is_on_floor() and _noise_timer <= 0.0:
		_noise_timer = noise_emit_interval
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


func enter_hiding_spot(hide_pos: Vector3, exit_pos: Vector3 = Vector3.ZERO, spot: Node = null) -> void:
	is_hidden = true
	velocity = Vector3.ZERO
	_lean_factor = 0.0
	_lean_roll = 0.0
	if head_pivot != null:
		head_pivot.position.x = 0.0
	_hiding_exit_pos = exit_pos if exit_pos != Vector3.ZERO else hide_pos + Vector3(0.0, 0.0, 1.2)
	_hiding_wardrobe = spot
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
	_hiding_wardrobe = null
	if exit_pos != Vector3.ZERO:
		global_position = exit_pos
	_apply_movement_state(MovementState.WALKING, true)
	GameEvents.player_hidden_changed.emit(false)


func _update_stamina(delta: float, is_moving: bool) -> void:
	if current_state == MovementState.SPRINTING and is_moving:
		current_stamina = maxf(0.0, current_stamina - stamina_drain_rate * delta)
		if current_stamina <= 0.0 and not _exhausted:
			_exhausted = true
			AudioManager.play_breath()
			_apply_movement_state(MovementState.WALKING, false)
	else:
		var rec_rate: float = stamina_recover_walk if is_moving else stamina_recover_idle
		_recover_stamina(rec_rate * delta)
		return
	_emit_stamina(false)


func _recover_stamina(gain: float) -> void:
	if current_stamina < max_stamina:
		current_stamina = minf(max_stamina, current_stamina + gain)
		if _exhausted and current_stamina >= exhausted_threshold:
			_exhausted = false
		_emit_stamina(false)


func _emit_stamina(force: bool) -> void:
	var at_bound: bool = current_stamina <= 0.0 or current_stamina >= max_stamina
	if force or absf(current_stamina - _last_emitted_stamina) >= 0.5 or (at_bound and not is_equal_approx(_last_emitted_stamina, current_stamina)):
		_last_emitted_stamina = current_stamina
		GameEvents.stamina_changed.emit(current_stamina, max_stamina)


func _update_movement_state(is_moving: bool) -> void:
	var wants_crouch: bool = Input.is_action_pressed("crouch")
	var blocked_above: bool = current_state == MovementState.CROUCHING and _is_ceiling_blocked()

	var next_state: MovementState = MovementState.WALKING
	if wants_crouch or blocked_above:
		next_state = MovementState.CROUCHING
	elif is_moving and Input.is_action_pressed("sprint") and not _exhausted and current_stamina > 1.0:
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


func _update_crouch_and_head_bob(delta: float, horizontal_speed: float) -> void:
	if head_pivot != null:
		var target_head_y: float = crouching_head_height if current_state == MovementState.CROUCHING else standing_head_height
		head_pivot.position.y = lerpf(head_pivot.position.y, target_head_y, clampf(crouch_transition_speed * delta, 0.0, 1.0))

		var want_lean: float = (-1.0 if Input.is_action_pressed("lean_left") else 0.0) + (1.0 if Input.is_action_pressed("lean_right") else 0.0)
		var target_lean_x: float = _compute_safe_lean_offset(want_lean)
		head_pivot.position.x = lerpf(head_pivot.position.x, target_lean_x, clampf(10.0 * delta, 0.0, 1.0))
		_lean_factor = head_pivot.position.x / maxf(lean_distance, 0.01)
		_lean_roll = deg_to_rad(-_lean_factor * lean_roll_degrees)

		if sun_exposure_ray != null:
			sun_exposure_ray.position.y = head_pivot.position.y
			sun_exposure_ray.position.x = head_pivot.position.x

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


func _update_camera_feel(delta: float, horizontal_speed: float) -> void:
	if camera == null:
		return
	var sprinting: bool = current_state == MovementState.SPRINTING and horizontal_speed > WALK_SPEED * 0.9
	var target_fov: float = base_fov + (sprint_fov_bonus if sprinting else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, clampf(6.0 * delta, 0.0, 1.0))

	var target_roll: float = deg_to_rad(-_strafe_input * strafe_roll_degrees) + _lean_roll
	_trauma = maxf(0.0, _trauma - delta * 1.4)
	_shake_time += delta * 30.0
	var shake: float = _trauma * _trauma
	var max_shake: float = deg_to_rad(max_shake_degrees)
	var shake_x: float = _shake_noise.get_noise_2d(_shake_time, 0.0) * max_shake * shake
	var shake_y: float = _shake_noise.get_noise_2d(0.0, _shake_time) * max_shake * shake
	var roll: float = lerpf(camera.rotation.z, target_roll, clampf(8.0 * delta, 0.0, 1.0))
	camera.rotation = Vector3(shake_x, shake_y, roll)


func _update_hand_sway(delta: float) -> void:
	if hand_pivot == null:
		return
	var target_pos: Vector3 = _hand_default_pos + _hand_sway_target
	hand_pivot.position = hand_pivot.position.lerp(target_pos, clampf(hand_sway_smoothing * delta, 0.0, 1.0))
	_hand_sway_target = _hand_sway_target.lerp(Vector3.ZERO, clampf(hand_sway_smoothing * delta, 0.0, 1.0))


func _compute_safe_lean_offset(want_lean: float) -> float:
	if is_zero_approx(want_lean):
		return 0.0
	var desired: float = want_lean * lean_distance
	var world_3d: World3D = get_world_3d()
	if world_3d == null or head_pivot == null:
		return desired
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if space_state == null:
		return desired
	var origin: Vector3 = global_position + Vector3(0.0, head_pivot.position.y, 0.0)
	var side_dir: Vector3 = global_transform.basis.x.normalized() * signf(want_lean)
	var margin: float = 0.16
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		origin + side_dir * (lean_distance + margin),
		1,
		[get_rid()]
	)
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return desired
	var hit_pos: Vector3 = hit.get("position", origin) as Vector3
	var allowed: float = maxf(0.0, hit_pos.distance_to(origin) - margin)
	return signf(want_lean) * minf(lean_distance, allowed)


func _try_throw_bottle() -> void:
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if inv == null or not inv.has_method("consume_bottle"):
		return
	if not bool(inv.call("consume_bottle")):
		AudioManager.play_locked()
		GameEvents.status_message_requested.emit("Sem garrafas para arremessar!")
		return
	var bottle: RigidBody3D = RigidBody3D.new()
	bottle.set_script(THROWABLE_BOTTLE_SCRIPT)
	var world_parent: Node = get_parent() if get_parent() != null else get_tree().current_scene
	world_parent.add_child(bottle)
	var throw_origin: Vector3 = get_eye_position()
	var throw_dir: Vector3 = -global_transform.basis.z
	if camera != null:
		throw_origin = camera.global_position
		throw_dir = -camera.global_transform.basis.z
	bottle.global_position = throw_origin + throw_dir * 0.85
	bottle.linear_velocity = throw_dir.normalized() * 13.5 + Vector3(0.0, 2.5, 0.0)
	AudioManager.play_footstep(-14.0, 1.35)


func _try_use_bandage() -> void:
	var health: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
	if health != null and health.current_health >= health.max_health:
		GameEvents.status_message_requested.emit("Sua vida já está cheia.")
		return
	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if inv == null or not inv.has_method("consume_bandage"):
		return
	if not bool(inv.call("consume_bandage")):
		AudioManager.play_locked()
		GameEvents.status_message_requested.emit("Sem bandagens no inventário!")
		return
	if health != null:
		health.heal(40.0)
	AudioManager.play_paper()
	GameEvents.status_message_requested.emit("Bandagem aplicada (+40 Vida)")


func _ensure_input_actions() -> void:
	var bindings: Dictionary = {
		"move_forward": KEY_W,
		"move_backward": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"sprint": KEY_SHIFT,
		"crouch": KEY_CTRL,
		"throw_bottle": KEY_G,
		"use_bandage": KEY_H,
		"lean_left": KEY_Q,
		"lean_right": KEY_C,
		"toggle_journal": KEY_TAB,
	}
	for action_name: String in bindings:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		var key_event: InputEventKey = InputEventKey.new()
		key_event.physical_keycode = bindings[action_name] as Key
		InputMap.action_add_event(action_name, key_event)
