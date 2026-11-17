class_name AppearanceCatalogue
extends RefCounted

const CATALOGUE_PATH := "res://data/appearance/catalogue.json"

var garments: Dictionary = {}
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
	garments = _garments(data.get("garments", {}))
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


func _garments(raw: Dictionary) -> Dictionary:
	var built := {}
	for key in raw.keys():
		var entry: Dictionary = raw[key]
		var garment := GarmentDefinition.new()
		garment.garment_id = str(entry.get("id", key))
		garment.display_name = str(entry.get("display_name", garment.garment_id))
		garment.slot = str(entry.get("slot", ""))
		garment.occupies = _strings(entry.get("occupies", []))
		garment.covers = _strings(entry.get("covers", []))
		garment.requires_any_of = _strings(entry.get("requires_any_of", []))
		garment.stature_full = _span(entry.get("stature_full", [1.6, 1.85]))
		garment.stature_limited = _span(entry.get("stature_limited", [1.5, 1.95]))
		garment.shoulder_full = _span(entry.get("shoulder_full", [0.92, 1.08]))
		garment.shoulder_limited = _span(entry.get("shoulder_limited", [0.85, 1.2]))
		garment.hip_full = _span(entry.get("hip_full", [0.92, 1.08]))
		garment.hip_limited = _span(entry.get("hip_limited", [0.85, 1.2]))
		garment.limitation = str(entry.get("limitation", ""))
		garment.content_version = str(entry.get("content_version", AppearanceProfile.CONTENT_VERSION))
		garment.evidence_status = str(entry.get("evidence_status", "placeholder"))
		garment.note = str(entry.get("note", garment.note))
		garment.mesh_kind = str(entry.get("mesh_kind", "box"))
		garment.albedo = _color(entry.get("albedo", [0.75, 0.75, 0.75]))
		built[garment.garment_id] = garment
	return built


func _strings(values: Variant) -> PackedStringArray:
	var packed := PackedStringArray()
	if values is Array:
		for value in values:
			packed.append(str(value))
	return packed


func _span(values: Variant) -> Vector2:
	if values is Array and values.size() >= 2:
		return Vector2(float(values[0]), float(values[1]))
	return Vector2.ZERO


func _color(values: Variant) -> Color:
	if values is Array and values.size() >= 3:
		return Color(float(values[0]), float(values[1]), float(values[2]), 1.0)
	return Color(0.75, 0.75, 0.75, 1.0)
