class_name AppearancePersistence
extends RefCounted

const SAVE_PATH := "user://the_midwifes_world/adult_appearance.json"


static func save_profile(profile: AppearanceProfile, path: String = SAVE_PATH) -> bool:
	var directory := path.get_base_dir()
	if not directory.is_empty() and not DirAccess.dir_exists_absolute(directory):
		var made := DirAccess.make_dir_recursive_absolute(directory)
		if made != OK:
			push_error("Could not create appearance save directory %s" % directory)
			return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write appearance save %s" % path)
		return false
	file.store_string(JSON.stringify(profile.to_save_dictionary(), "\t"))
	return true


static func load_profile(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "missing_file"}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "unreadable"}
	return AppearanceProfile.from_save_dictionary(parsed)
