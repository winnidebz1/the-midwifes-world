extends Node

## Changes the running scene and reports the new path after it is current.

signal scene_changed(scene_path: String)

var _changing := false


func change_scene(scene_path: String) -> void:
	if _changing:
		return
	_changing = true
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		_changing = false
		push_error("GameFlow could not open %s (%s)." % [scene_path, error_string(error)])
		return
	await get_tree().process_frame
	_changing = false
	scene_changed.emit(scene_path)


func change_scene_to_packed(packed_scene: PackedScene) -> void:
	if packed_scene == null:
		push_error("GameFlow received an empty packed scene.")
		return
	if _changing:
		return
	_changing = true
	var error := get_tree().change_scene_to_packed(packed_scene)
	if error != OK:
		_changing = false
		push_error("GameFlow could not open a packed scene (%s)." % error_string(error))
		return
	await get_tree().process_frame
	_changing = false
	scene_changed.emit(packed_scene.resource_path)
