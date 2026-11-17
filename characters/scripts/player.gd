class_name PlayerCharacter
extends CharacterBody3D

## Camera-relative movement with idle, walk, run, and jump states.

enum MovementState { IDLE, WALK, RUN, JUMP }

signal movement_state_changed(state: MovementState)

@export var walk_speed := 2.6
@export var run_speed := 5.2
@export var jump_velocity := 4.8
@export var acceleration := 14.0
@export var deceleration := 18.0
@export var turn_rate := 12.0
@export var blend_rate := 6.0

var movement_state := MovementState.IDLE
## Smoothed locomotion for a future blend space: 0 idle, 1 walk, 2 run.
var locomotion_blend := 0.0

@onready var _visual: Node3D = $Visual
@onready var _camera_pivot: Node3D = $CameraPivot


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative_direction(input_dir)
	var has_move := direction.length_squared() > 0.0001
	var sprinting := has_move and Input.is_action_pressed("sprint")
	var target_speed := run_speed if sprinting else (walk_speed if has_move else 0.0)
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var target := direction * target_speed
	var rate := acceleration if target.length_squared() > planar.length_squared() else deceleration
	planar = planar.move_toward(target, rate * delta)
	velocity.x = planar.x
	velocity.z = planar.z

	if has_move:
		var target_yaw := atan2(-direction.x, -direction.z)
		_visual.rotation.y = lerp_angle(
			_visual.rotation.y,
			target_yaw,
			1.0 - exp(-turn_rate * delta)
		)

	move_and_slide()
	_set_state(_state_after_move(has_move, sprinting))
	_update_blend(delta)


func _state_after_move(has_move: bool, sprinting: bool) -> MovementState:
	if not is_on_floor():
		return MovementState.JUMP
	var speed := Vector2(velocity.x, velocity.z).length()
	if sprinting:
		return MovementState.RUN
	if has_move or speed > 0.3:
		return MovementState.WALK
	return MovementState.IDLE


func _set_state(next: MovementState) -> void:
	if next == movement_state:
		return
	movement_state = next
	movement_state_changed.emit(next)


func _update_blend(delta: float) -> void:
	if movement_state == MovementState.JUMP:
		return
	var target := 0.0
	if movement_state == MovementState.WALK:
		target = 1.0
	elif movement_state == MovementState.RUN:
		target = 2.0
	locomotion_blend = move_toward(locomotion_blend, target, blend_rate * delta)


func _camera_relative_direction(input_dir: Vector2) -> Vector3:
	var forward := -_camera_pivot.global_basis.z
	forward.y = 0.0
	var right := _camera_pivot.global_basis.x
	right.y = 0.0
	if forward.length_squared() < 0.0001 or right.length_squared() < 0.0001:
		return Vector3.ZERO
	return right.normalized() * input_dir.x + forward.normalized() * -input_dir.y
