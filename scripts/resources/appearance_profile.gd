class_name AppearanceProfile
extends Resource

## Saved adult appearance. Ids are kept even when the catalogue no longer contains them.

const SCHEMA_VERSION := 1
const RIG_FAMILY := "humanoid_adult_1"
const SKELETON_VERSION := "1.0.0"
const CONTENT_VERSION := "phase1.adult.1.1"
const DEFAULT_STATURE_M := 1.72
const DEFAULT_SHOULDER_SCALE := 1.0
const DEFAULT_HIP_SCALE := 1.0
const DEFAULT_LEG_SCALE := 1.0
const DEFAULT_TORSO_SCALE := 1.0

@export var schema_version := SCHEMA_VERSION
@export var content_version := CONTENT_VERSION
@export var rig_family := RIG_FAMILY
@export var skeleton_version := SKELETON_VERSION
## Reserved so a later body state is not stored as a proportion. Phase 1 does not simulate it.
@export var body_state := "none"
@export var identity_id := ""
@export var skin_set_id := ""
@export var hair_id := ""
@export var facial_id := ""
@export var proportion_id := ""
@export var stature_m := 1.72
@export var shoulder_scale := 1.0
@export var hip_scale := 1.0
@export var leg_scale := 1.0
@export var torso_scale := 1.0
@export var clothing: Dictionary = {}
@export var compatibility: Array = []
@export var missing_ids: PackedStringArray = PackedStringArray()
@export var warnings: PackedStringArray = PackedStringArray()


func to_save_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"content_version": content_version,
		"rig_family": rig_family,
		"skeleton_version": skeleton_version,
		"body_state": body_state,
		"identity_id": identity_id,
		"skin_set_id": skin_set_id,
		"hair_id": hair_id,
		"facial_id": facial_id,
		"proportion_id": proportion_id,
		"proportions": {
			"stature_m": stature_m,
			"shoulder_scale": shoulder_scale,
			"hip_scale": hip_scale,
			"leg_scale": leg_scale,
			"torso_scale": torso_scale,
		},
		"clothing": clothing.duplicate(true),
		"compatibility": compatibility.duplicate(true),
		"missing_ids": Array(missing_ids),
		"warnings": Array(warnings),
	}


static func from_save_dictionary(data: Dictionary) -> Dictionary:
	var diagnostics := PackedStringArray()
	if not data.has("schema_version") or not _is_number(data["schema_version"]):
		diagnostics.append("schema_version must be the number 1")
		return _failure("malformed_schema", diagnostics, data.get("schema_version", null))
	if int(data["schema_version"]) != SCHEMA_VERSION:
		diagnostics.append("schema_version %s is not supported" % str(data["schema_version"]))
		return _failure("unsupported_schema", diagnostics, data.get("schema_version", null))
	if not data.has("rig_family") or typeof(data["rig_family"]) != TYPE_STRING:
		diagnostics.append("rig_family must be the string %s" % RIG_FAMILY)
		return _failure("malformed_rig_family", diagnostics, data.get("rig_family", null))
	if str(data["rig_family"]) != RIG_FAMILY:
		diagnostics.append("rig_family %s cannot be applied to %s" % [str(data["rig_family"]), RIG_FAMILY])
		return _failure("rig_family_mismatch", diagnostics, data.get("rig_family", ""))
	if data.has("clothing") and typeof(data["clothing"]) != TYPE_DICTIONARY:
		diagnostics.append("clothing must be an object of slot ids, received %s" % type_string(typeof(data["clothing"])))
		return _failure("malformed_clothing", diagnostics, null)
	if data.has("proportions") and typeof(data["proportions"]) != TYPE_DICTIONARY:
		diagnostics.append("proportions must be an object of numbers, received %s" % type_string(typeof(data["proportions"])))
		return _failure("malformed_proportions", diagnostics, null)
	var clothing_value: Dictionary = data["clothing"] if data.has("clothing") else {}
	var clothing_error := _validate_clothing(clothing_value, diagnostics)
	if not clothing_error.is_empty():
		return _failure(clothing_error, diagnostics, null)
	var proportion_value: Dictionary = data["proportions"] if data.has("proportions") else {}
	var proportion_error := _validate_proportion_types(proportion_value, diagnostics)
	if not proportion_error.is_empty():
		return _failure(proportion_error, diagnostics, null)
	var profile := AppearanceProfile.new()
	profile.schema_version = SCHEMA_VERSION
	profile.content_version = str(data["content_version"]) if data.has("content_version") and typeof(data["content_version"]) == TYPE_STRING else ""
	profile.rig_family = RIG_FAMILY
	profile.skeleton_version = str(data["skeleton_version"]) if data.has("skeleton_version") and typeof(data["skeleton_version"]) == TYPE_STRING else ""
	profile.body_state = str(data["body_state"]) if data.has("body_state") and typeof(data["body_state"]) == TYPE_STRING else "none"
	profile.identity_id = _optional_string(data, "identity_id")
	profile.skin_set_id = _optional_string(data, "skin_set_id")
	profile.hair_id = _optional_string(data, "hair_id")
	profile.facial_id = _optional_string(data, "facial_id")
	profile.proportion_id = _optional_string(data, "proportion_id")
	if proportion_value.is_empty():
		profile.warnings = _append_warning(profile.warnings, "proportions_missing")
		diagnostics.append("proportions object is missing; documented defaults were used")
	profile.stature_m = _optional_proportion(proportion_value, "stature_m", DEFAULT_STATURE_M, profile, diagnostics)
	profile.shoulder_scale = _optional_proportion(proportion_value, "shoulder_scale", DEFAULT_SHOULDER_SCALE, profile, diagnostics)
	profile.hip_scale = _optional_proportion(proportion_value, "hip_scale", DEFAULT_HIP_SCALE, profile, diagnostics)
	profile.leg_scale = _optional_proportion(proportion_value, "leg_scale", DEFAULT_LEG_SCALE, profile, diagnostics)
	profile.torso_scale = _optional_proportion(proportion_value, "torso_scale", DEFAULT_TORSO_SCALE, profile, diagnostics)
	if profile.skeleton_version != SKELETON_VERSION:
		profile.warnings = _append_warning(profile.warnings, "skeleton_version_differs")
		diagnostics.append("skeleton_version %s differs from %s" % [profile.skeleton_version, SKELETON_VERSION])
	if profile.content_version != CONTENT_VERSION:
		profile.warnings = _append_warning(profile.warnings, "content_version_differs")
		diagnostics.append("content_version %s differs from %s" % [profile.content_version, CONTENT_VERSION])
	for slot in clothing_value.keys():
		profile.clothing[str(slot)] = _copy_clothing_value(clothing_value[slot])
	if data.has("compatibility") and data["compatibility"] is Array:
		profile.compatibility = data["compatibility"].duplicate(true)
	return {"ok": true, "profile": profile, "diagnostics": diagnostics}


static func _validate_clothing(clothing: Dictionary, diagnostics: PackedStringArray) -> String:
	for slot in clothing.keys():
		var value: Variant = clothing[slot]
		if str(slot) == "accessories":
			if not value is Array:
				diagnostics.append("accessories must be an array of garment ids")
				return "malformed_clothing"
			for item in value:
				if typeof(item) != TYPE_STRING or str(item).is_empty():
					diagnostics.append("accessories contains an id that is not a non-empty string")
					return "malformed_clothing"
			continue
		if typeof(value) != TYPE_STRING:
			diagnostics.append("clothing slot %s must be a garment id string, received %s" % [str(slot), type_string(typeof(value))])
			return "malformed_clothing"
	return ""


static func _validate_proportion_types(proportions: Dictionary, diagnostics: PackedStringArray) -> String:
	for key in ["stature_m", "shoulder_scale", "hip_scale", "leg_scale", "torso_scale"]:
		if not proportions.has(key):
			continue
		if not _is_number(proportions[key]):
			diagnostics.append("proportion %s must be a number, received %s" % [key, type_string(typeof(proportions[key]))])
			return "invalid_proportion_type"
	return ""


static func _optional_proportion(proportions: Dictionary, key: String, fallback: float, profile: AppearanceProfile, diagnostics: PackedStringArray) -> float:
	if not proportions.has(key):
		profile.warnings = _append_warning(profile.warnings, "proportion_key_missing:%s" % key)
		diagnostics.append("optional proportion %s is missing; default %.2f was used" % [key, fallback])
		return fallback
	return float(proportions[key])


static func _optional_string(data: Dictionary, key: String) -> String:
	if data.has(key) and typeof(data[key]) == TYPE_STRING:
		return str(data[key])
	return ""


static func _copy_clothing_value(value: Variant) -> Variant:
	if value is Array:
		var copied: Array[String] = []
		for item in value:
			copied.append(str(item))
		return copied
	return str(value)


static func _failure(error: String, diagnostics: PackedStringArray, detail: Variant) -> Dictionary:
	var result := {"ok": false, "error": error, "diagnostics": diagnostics}
	if detail != null:
		result["detail"] = detail
	return result


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _append_warning(warnings: PackedStringArray, warning: String) -> PackedStringArray:
	var next := warnings.duplicate()
	next.append(warning)
	return next
