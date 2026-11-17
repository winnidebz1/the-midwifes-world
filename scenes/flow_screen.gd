extends Control

## Title and placeholder screens. Gameplay scenes do not use this script.

@export_file("*.tscn") var next_scene_path := ""
@export var continue_action := "advance"


func _unhandled_input(event: InputEvent) -> void:
	if next_scene_path.is_empty():
		return
	if not event.is_action_pressed(continue_action):
		return
	get_viewport().set_input_as_handled()
	GameFlow.change_scene(next_scene_path)
