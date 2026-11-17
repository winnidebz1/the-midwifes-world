extends Node

## Session facts that must survive a scene change.

signal state_changed

var location_id := "":
	set(value):
		if location_id == value:
			return
		location_id = value
		state_changed.emit()


func snapshot() -> Dictionary:
	return {"location_id": location_id}
