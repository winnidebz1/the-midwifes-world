extends Node

## Plays Idle, Walk, Run, and Jump when a model under Visual provides those clips.

@export var blend_time := 0.18

var active_clip := ""

var _body: PlayerCharacter
var _animation_player: AnimationPlayer

const _CLIPS: Dictionary = {
	PlayerCharacter.MovementState.IDLE: &"Idle",
	PlayerCharacter.MovementState.WALK: &"Walk",
	PlayerCharacter.MovementState.RUN: &"Run",
	PlayerCharacter.MovementState.JUMP: &"Jump",
}


func _ready() -> void:
	_body = get_parent() as PlayerCharacter
	_animation_player = _find_animation_player()
	_body.movement_state_changed.connect(_on_movement_state_changed)
	_apply_clip(_body.movement_state)


func _on_movement_state_changed(state: PlayerCharacter.MovementState) -> void:
	_apply_clip(state)


func _apply_clip(state: PlayerCharacter.MovementState) -> void:
	active_clip = String(_CLIPS.get(state, &"Idle"))
	if _animation_player == null:
		_animation_player = _find_animation_player()
	if _animation_player == null or not _animation_player.has_animation(active_clip):
		return
	if _animation_player.current_animation == active_clip:
		return
	if _animation_player.current_animation.is_empty():
		_animation_player.play(active_clip)
	else:
		_animation_player.play(active_clip, blend_time)


func _find_animation_player() -> AnimationPlayer:
	var visual := _body.get_node_or_null("Visual")
	if visual == null:
		return null
	return visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
