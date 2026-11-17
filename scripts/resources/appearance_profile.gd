class_name AppearanceProfile
extends Resource

## Saved adult appearance. Ids are kept even when the catalogue no longer contains them.

const SCHEMA_VERSION := 1
const RIG_FAMILY := "humanoid_adult_1"
const SKELETON_VERSION := "1.0.0"
const CONTENT_VERSION := "phase1.adult.1"

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
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		return {"ok": false, "error": "unsupported_schema", "schema_version": data.get("schema_version", null)}
	if str(data.get("rig_family", "")) != RIG_FAMILY:
		return {"ok": false, "error": "rig_family_mismatch", "rig_family": data.get("rig_family", "")}
	var profile := AppearanceProfile.new()
	profile.schema_version = SCHEMA_VERSION
	profile.content_version = str(data.get("content_version", ""))
	profile.rig_family = RIG_FAMILY
	profile.skeleton_version = str(data.get("skeleton_version", ""))
	profile.body_state = str(data.get("body_state", "none"))
	profile.identity_id = str(data.get("identity_id", ""))
	profile.skin_set_id = str(data.get("skin_set_id", ""))
	profile.hair_id = str(data.get("hair_id", ""))
	profile.facial_id = str(data.get("facial_id", ""))
	profile.proportion_id = str(data.get("proportion_id", ""))
	var proportions: Dictionary = data.get("proportions", {})
	if proportions.is_empty():
		profile.warnings = PackedStringArray(["proportions_missing"])
	else:
		profile.stature_m = float(proportions.get("stature_m", profile.stature_m))
		profile.shoulder_scale = float(proportions.get("shoulder_scale", profile.shoulder_scale))
		profile.hip_scale = float(proportions.get("hip_scale", profile.hip_scale))
		profile.leg_scale = float(proportions.get("leg_scale", profile.leg_scale))
		profile.torso_scale = float(proportions.get("torso_scale", profile.torso_scale))
		for key in ["stature_m", "shoulder_scale", "hip_scale", "leg_scale", "torso_scale"]:
			if not proportions.has(key):
				profile.warnings = _append_warning(profile.warnings, "proportion_key_missing:%s" % key)
	if profile.skeleton_version != SKELETON_VERSION:
		profile.warnings = _append_warning(profile.warnings, "skeleton_version_differs")
	if profile.content_version != CONTENT_VERSION:
		profile.warnings = _append_warning(profile.warnings, "content_version_differs")
	var clothing: Dictionary = data.get("clothing", {})
	for slot in clothing.keys():
		profile.clothing[str(slot)] = str(clothing[slot])
	var saved_results: Array = data.get("compatibility", [])
	profile.compatibility = saved_results.duplicate(true)
	return {"ok": true, "profile": profile}


static func _append_warning(warnings: PackedStringArray, warning: String) -> PackedStringArray:
	var next := warnings.duplicate()
	next.append(warning)
	return next
