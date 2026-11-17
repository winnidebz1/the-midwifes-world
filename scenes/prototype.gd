extends Node3D

const BOOT_SCENE := "res://scenes/boot.tscn"
const LOCATION_ID := "test_yard"

var _cursor_captured := false


func _ready() -> void:
	GameState.location_id = LOCATION_ID
	_capture_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		if _cursor_captured:
			_release_cursor()
			return
		GameFlow.change_scene(BOOT_SCENE)
		return
	if _cursor_captured:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_capture_cursor()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_cursor()


func _exit_tree() -> void:
	var rig := find_child("HumanoidAdult1", true, false)
	if rig != null and rig.has_method("save_appearance"):
		rig.save_appearance()
	_release_cursor()


func _capture_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_cursor_captured = true


func _release_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cursor_captured = false
