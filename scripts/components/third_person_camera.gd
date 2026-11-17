extends Node3D

## Mouse-look pivot. Yaw is on this node, pitch is on PitchPivot, distance is the spring arm length.

@export var distance := 4.5
@export var mouse_sensitivity := 0.0025
@export_range(-1.2, -0.05) var min_pitch := -0.55
@export_range(0.05, 1.3) var max_pitch := 0.7

@onready var _pitch: Node3D = $PitchPivot
@onready var _spring_arm: SpringArm3D = $PitchPivot/SpringArm


func _ready() -> void:
	_spring_arm.spring_length = distance


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is not InputEventMouseMotion:
		return
	apply_look(event.relative)


func apply_look(relative: Vector2) -> void:
	rotation.y -= relative.x * mouse_sensitivity
	_pitch.rotation.x = clampf(
		_pitch.rotation.x - relative.y * mouse_sensitivity,
		min_pitch,
		max_pitch
	)
