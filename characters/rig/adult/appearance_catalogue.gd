class_name AppearanceCatalogue
extends RefCounted

const CATALOGUE_PATH := "res://data/appearance/catalogue.json"

var garments: Dictionary = {}
var invalid_reasons: Dictionary = {}
var identities: Dictionary = {}
var skin_sets: Dictionary = {}
var hair_sets: Dictionary = {}
var faces: Dictionary = {}
var proportions: Dictionary = {}
var components: Dictionary = {}
var default_appearance: Dictionary = {}


func load_from_project() -> void:
	var text := FileAccess.get_file_as_string(CATALOGUE_PATH)
	if text.is_empty():
		push_error("Appearance catalogue is missing at %s" % CATALOGUE_PATH)
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Appearance catalogue did not parse.")
		return
	var data: Dictionary = parsed
	var parsed_garments := _garments(data.get("garments", {}))
	garments = parsed_garments["valid"]
	invalid_reasons = parsed_garments["invalid"]
	identities = data.get("identities", {})
	skin_sets = data.get("skin_sets", {})
	hair_sets = data.get("hair", {})
	faces = data.get("faces", {})
	proportions = data.get("proportions", {})
	components = data.get("components", {})
	default_appearance = data.get("default_appearance", {})


func make_default_profile() -> AppearanceProfile:
	var profile := AppearanceProfile.new()
	profile.identity_id = str(default_appearance.get("identity_id", ""))
	profile.skin_set_id = str(default_appearance.get("skin_set_id", ""))
	profile.hair_id = str(default_appearance.get("hair_id", ""))
	profile.facial_id = str(default_appearance.get("facial_id", ""))
	profile.proportion_id = str(default_appearance.get("proportion_id", ""))
	var preset: Dictionary = proportions.get(profile.proportion_id, {})
	profile.stature_m = float(preset.get("stature_m", profile.stature_m))
	profile.shoulder_scale = float(preset.get("shoulder_scale", profile.shoulder_scale))
	profile.hip_scale = float(preset.get("hip_scale", profile.hip_scale))
	profile.leg_scale = float(preset.get("leg_scale", profile.leg_scale))
	profile.torso_scale = float(preset.get("torso_scale", profile.torso_scale))
	var clothing: Dictionary = default_appearance.get("clothing", {})
	for slot in clothing.keys():
		profile.clothing[str(slot)] = str(clothing[slot])
	return profile


func classify_entry(record_key: String, entry: Dictionary) -> Dictionary:
	var garment := _fill_garment(record_key, entry)
	var errors := garment.validation_errors()
	return {"garment": garment, "errors": errors, "valid": errors.is_empty()}


func _garments(raw: Dictionary) -> Dictionary:
	var valid := {}
	var invalid := {}
	for key in raw.keys():
		if typeof(raw[key]) != TYPE_DICTIONARY:
			invalid[str(key)] = PackedStringArray(["garment record must be an object"])
			continue
		var classified := classify_entry(str(key), raw[key])
		var garment: GarmentDefinition = classified["garment"]
		var errors: PackedStringArray = classified["errors"]
		var storage_id := garment.garment_id if not garment.garment_id.is_empty() else str(key)
		if errors.is_empty():
			valid[garment.garment_id] = garment
		else:
			invalid[storage_id] = errors
	return {"valid": valid, "invalid": invalid}


func _fill_garment(record_key: String, entry: Dictionary) -> GarmentDefinition:
	var garment := GarmentDefinition.new()
	var notes := PackedStringArray()
	if entry.has("id") and typeof(entry["id"]) == TYPE_STRING:
		garment.garment_id = str(entry["id"])
	garment.display_name = str(entry.get("display_name", garment.garment_id if not garment.garment_id.is_empty() else record_key))
	garment.slot = str(entry["slot"]) if entry.has("slot") and typeof(entry["slot"]) == TYPE_STRING else ""
	garment.socket = str(entry["socket"]) if entry.has("socket") and typeof(entry["socket"]) == TYPE_STRING else ""
	garment.occupies = _string_list(entry, "occupies", notes)
	garment.covers = _string_list(entry, "covers", notes)
	garment.covered_regions = _string_list(entry, "covered_regions", notes)
	garment.requires_any_of = _string_list(entry, "requires_any_of", notes)
	garment.stature_full = _range_field(entry, "stature_full", GarmentDefinition.DEFAULT_STATURE_FULL, notes)
	garment.stature_limited = _range_field(entry, "stature_limited", GarmentDefinition.DEFAULT_STATURE_LIMITED, notes)
	garment.shoulder_full = _range_field(entry, "shoulder_full", GarmentDefinition.DEFAULT_SHOULDER_FULL, notes)
	garment.shoulder_limited = _range_field(entry, "shoulder_limited", GarmentDefinition.DEFAULT_SHOULDER_LIMITED, notes)
	garment.hip_full = _range_field(entry, "hip_full", GarmentDefinition.DEFAULT_HIP_FULL, notes)
	garment.hip_limited = _range_field(entry, "hip_limited", GarmentDefinition.DEFAULT_HIP_LIMITED, notes)
	garment.limitation = str(entry.get("limitation", ""))
	garment.content_version = str(entry["content_version"]) if entry.has("content_version") and typeof(entry["content_version"]) == TYPE_STRING else ""
	if garment.content_version.is_empty() and not entry.has("content_version"):
		garment.content_version = AppearanceProfile.CONTENT_VERSION
	garment.evidence_status = str(entry.get("evidence_status", "placeholder"))
	garment.note = str(entry.get("note", garment.note))
	garment.mesh_kind = str(entry.get("mesh_kind", "box"))
	garment.albedo = _color(entry.get("albedo", [0.75, 0.75, 0.75]))
	garment.metadata_errors = notes
	return garment


func _string_list(entry: Dictionary, key: String, notes: PackedStringArray) -> PackedStringArray:
	var packed := PackedStringArray()
	if not entry.has(key):
		return packed
	if typeof(entry[key]) != TYPE_ARRAY:
		notes.append("%s must be an array of strings" % key)
		return packed
	for value in entry[key]:
		if typeof(value) != TYPE_STRING:
			notes.append("%s contains a non-string value" % key)
			continue
		packed.append(str(value))
	return packed


func _range_field(entry: Dictionary, key: String, fallback: Vector2, notes: PackedStringArray) -> Vector2:
	if not entry.has(key):
		return fallback
	var values: Variant = entry[key]
	if typeof(values) != TYPE_ARRAY or values.size() < 2 or not _is_number(values[0]) or not _is_number(values[1]):
		notes.append("%s must be a min,max number pair" % key)
		return Vector2(1, 1)
	return Vector2(float(values[0]), float(values[1]))


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _color(values: Variant) -> Color:
	if values is Array and values.size() >= 3:
		return Color(float(values[0]), float(values[1]), float(values[2]), 1.0)
	return Color(0.75, 0.75, 0.75, 1.0)
