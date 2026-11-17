extends SceneTree

var _failures: PackedStringArray = PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(AppearancePersistence.SAVE_PATH):
		DirAccess.remove_absolute(AppearancePersistence.SAVE_PATH)
	var catalogue := AppearanceCatalogue.new()
	catalogue.load_from_project()
	_expect(catalogue.invalid_reasons.is_empty(), "shipped catalogue invalid: %s" % str(catalogue.invalid_reasons))
	var rig: AdultRig = load("res://characters/rig/adult/humanoid_adult_1.tscn").instantiate()
	root.add_child(rig)
	await process_frame
	_clothing(rig, catalogue)
	_saves(rig)
	await _bones(rig)
	for path in [
		"user://the_midwifes_world/phase11_string_clothing.json",
		"user://the_midwifes_world/phase11_array_proportions.json",
		"user://the_midwifes_world/phase11_bad_proportion.json",
		"user://the_midwifes_world/phase11_partial.json",
		"user://the_midwifes_world/phase11_unknown.json",
		"user://the_midwifes_world/phase11_accessories.json",
		"user://the_midwifes_world/phase11_bad_record.json",
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if _failures.is_empty():
		print("PHASE11_OK")
		quit(0)
		return
	print("PHASE11_FAILED %s" % " | ".join(_failures))
	quit(1)


func _clothing(rig: AdultRig, catalogue: AppearanceCatalogue) -> void:
	var layered: Dictionary = rig.set_clothing({
		"base": "placeholder_base_layer",
		"dress": "placeholder_dress",
		"outer": "placeholder_apron",
		"uniform_lower": "placeholder_scrub_trousers",
	})
	_expect(_level(layered, "placeholder_dress") == "compatible", "apron over dress")
	_expect(_level(layered, "placeholder_apron") == "compatible", "apron with dress")
	_expect(_level(layered, "placeholder_scrub_trousers") == "incompatible", "dress blocks trousers")
	_expect(str(_entry(layered, "placeholder_scrub_trousers").get("reason", "")).contains("occupies"), "trousers reason")
	_expect(not rig.region_visible("placeholder_base_layer", "torso"), "dress covers base torso")
	_expect(not rig.region_visible("placeholder_base_layer", "leg_left"), "dress covers base leg")
	_expect(rig.region_visible("placeholder_base_layer", "sleeve_left"), "base sleeve stays exposed")
	_expect(rig.region_visible("placeholder_base_layer", "sleeve_right"), "base right sleeve stays exposed")
	_expect(not rig.region_visible("placeholder_dress", "torso"), "apron covers dress torso")
	_expect(rig.region_visible("placeholder_dress", "legs"), "dress skirt stays exposed")
	_expect(rig.garment_visible("placeholder_apron"), "apron mesh")
	_expect(not rig.garment_visible("placeholder_scrub_trousers"), "blocked trousers hidden")
	var scrubs: Dictionary = rig.set_clothing({
		"base": "placeholder_base_layer",
		"uniform_upper": "placeholder_scrub_top",
		"uniform_lower": "placeholder_scrub_trousers",
		"outer": "placeholder_apron",
	})
	_expect(_level(scrubs, "placeholder_apron") == "compatible", "apron over scrubs")
	_expect(_level(scrubs, "placeholder_scrub_top") == "compatible", "scrub top under apron")
	_expect(_level(scrubs, "placeholder_scrub_trousers") == "compatible", "scrub trousers under apron")
	_expect(not rig.region_visible("placeholder_scrub_top", "torso"), "apron covers scrub torso")
	_expect(rig.garment_visible("placeholder_scrub_trousers"), "scrub trousers remain")
	_expect(rig.region_visible("placeholder_base_layer", "sleeve_left"), "sleeves exposed under scrubs")
	_expect(not rig.region_visible("placeholder_base_layer", "torso"), "scrub top covers base torso")
	var worn: Dictionary = rig.set_clothing({
		"accessories": ["placeholder_wrist_band", "placeholder_name_badge"],
	})
	_expect(_level(worn, "placeholder_name_badge") == "compatible", "chest accessory")
	_expect(_level(worn, "placeholder_wrist_band") == "compatible", "wrist accessory")
	_expect(rig.garment_visible("placeholder_name_badge") and rig.garment_visible("placeholder_wrist_band"), "both accessories visible")
	var rival := _valid_accessory("placeholder_second_badge", "chest")
	var badge: GarmentDefinition = catalogue.garments["placeholder_name_badge"]
	var contested: Dictionary = ClothingResolver.resolve(
		{"accessories": ["placeholder_second_badge", "placeholder_name_badge"]},
		{"placeholder_name_badge": badge, "placeholder_second_badge": rival},
		1.72, 1.0, 1.0
	)
	var contested_again: Dictionary = ClothingResolver.resolve(
		{"accessories": ["placeholder_second_badge", "placeholder_name_badge"]},
		{"placeholder_name_badge": badge, "placeholder_second_badge": rival},
		1.72, 1.0, 1.0
	)
	_expect(_level(contested, "placeholder_name_badge") == "compatible", "smaller id keeps the chest socket")
	_expect(_level(contested, "placeholder_second_badge") == "incompatible", "same socket rejected")
	_expect(str(_entry(contested, "placeholder_second_badge").get("reason", "")).contains("Socket chest"), "socket reason")
	_expect(contested["results"] == contested_again["results"], "socket result is repeatable")
	var missing_occupies := catalogue.classify_entry("bare_dress", {
		"id": "bare_dress",
		"slot": "dress",
		"content_version": "phase1.adult.1.1",
	})
	_expect(not missing_occupies["valid"], "dress without occupies is invalid")
	_expect(_joined(missing_occupies["errors"]).contains("missing occupies"), "occupies diagnostic")
	var bare: GarmentDefinition = missing_occupies["garment"]
	var trousers: GarmentDefinition = catalogue.garments["placeholder_scrub_trousers"]
	var unresolved: Dictionary = ClothingResolver.resolve(
		{"dress": "bare_dress", "uniform_lower": "placeholder_scrub_trousers"},
		{"bare_dress": bare, "placeholder_scrub_trousers": trousers},
		1.72, 1.0, 1.0
	)
	_expect(_level(unresolved, "bare_dress") == "invalid_content", "missing occupies is not a body conflict")
	_expect(_level(unresolved, "placeholder_scrub_trousers") == "compatible", "valid trousers stay available")
	_expect(not str(_entry(unresolved, "bare_dress").get("reason", "")).contains("Body is outside"), "invalid content is not described as body fit")
	var reversed := catalogue.classify_entry("reversed_coat", {
		"id": "reversed_coat",
		"slot": "outer",
		"content_version": "phase1.adult.1.1",
		"stature_full": [1.85, 1.6],
		"stature_limited": [1.95, 1.5],
	})
	_expect(not reversed["valid"], "reversed ranges are invalid")
	var reversed_resolve: Dictionary = ClothingResolver.resolve(
		{"outer": "reversed_coat"},
		{"reversed_coat": reversed["garment"]},
		1.72, 1.0, 1.0
	)
	_expect(_level(reversed_resolve, "reversed_coat") == "invalid_content", "reversed range level")
	_expect(str(_entry(reversed_resolve, "reversed_coat").get("reason", "")).contains("reversed"), "reversed range reason")
	var nameless := catalogue.classify_entry("nameless_record", {"slot": "belt", "content_version": "phase1.adult.1.1"})
	_expect(_joined(nameless["errors"]).contains("missing content id"), "missing content id")
	var nameless_resolve: Dictionary = ClothingResolver.resolve(
		{"belt": "nameless_record", "footwear": "placeholder_footwear"},
		{"nameless_record": nameless["garment"], "placeholder_footwear": catalogue.garments["placeholder_footwear"]},
		1.72, 1.0, 1.0
	)
	_expect(_level(nameless_resolve, "nameless_record") == "invalid_content", "missing id level")
	_expect(_level(nameless_resolve, "placeholder_footwear") == "compatible", "missing id did not replace footwear")


func _saves(rig: AdultRig) -> void:
	rig.select_identity("adult_b")
	rig.set_clothing({"dress": "placeholder_dress", "outer": "placeholder_apron"})
	var before_identity := rig.profile.identity_id
	var before_dress := str(rig.profile.clothing.get("dress", ""))
	_write("user://the_midwifes_world/phase11_string_clothing.json", JSON.stringify({
		"schema_version": 1,
		"rig_family": "humanoid_adult_1",
		"clothing": "placeholder_dress",
	}))
	var string_clothing: Dictionary = rig.load_appearance("user://the_midwifes_world/phase11_string_clothing.json")
	_expect(str(string_clothing.get("error", "")) == "malformed_clothing", "string clothing rejected")
	_expect(_joined(string_clothing.get("diagnostics", PackedStringArray())).contains("clothing must be an object"), "string clothing diagnostic")
	_expect(rig.profile.identity_id == before_identity and str(rig.profile.clothing.get("dress", "")) == before_dress, "string clothing preserved appearance")
	_write("user://the_midwifes_world/phase11_array_proportions.json", JSON.stringify({
		"schema_version": 1,
		"rig_family": "humanoid_adult_1",
		"proportions": ["tall"],
	}))
	var array_proportions: Dictionary = rig.load_appearance("user://the_midwifes_world/phase11_array_proportions.json")
	_expect(str(array_proportions.get("error", "")) == "malformed_proportions", "array proportions rejected")
	_expect(rig.profile.identity_id == before_identity, "array proportions preserved appearance")
	_write("user://the_midwifes_world/phase11_bad_proportion.json", JSON.stringify({
		"schema_version": 1,
		"rig_family": "humanoid_adult_1",
		"proportions": {"stature_m": "tall", "shoulder_scale": 1.0},
	}))
	var bad_type: Dictionary = rig.load_appearance("user://the_midwifes_world/phase11_bad_proportion.json")
	_expect(str(bad_type.get("error", "")) == "invalid_proportion_type", "text stature rejected")
	_expect(_joined(bad_type.get("diagnostics", PackedStringArray())).contains("stature_m"), "text stature diagnostic")
	_expect(rig.profile.identity_id == before_identity, "text stature preserved appearance")
	_write("user://the_midwifes_world/phase11_bad_record.json", JSON.stringify({
		"schema_version": 1,
		"rig_family": "humanoid_adult_1",
		"clothing": {"dress": 12},
	}))
	var bad_record: Dictionary = rig.load_appearance("user://the_midwifes_world/phase11_bad_record.json")
	_expect(str(bad_record.get("error", "")) == "malformed_clothing", "numeric garment id rejected")
	_expect(rig.profile.identity_id == before_identity, "numeric garment id preserved appearance")
	_write("user://the_midwifes_world/phase11_partial.json", JSON.stringify({
		"schema_version": 1,
		"rig_family": "humanoid_adult_1",
		"content_version": "phase1.adult.1.1",
		"skeleton_version": "1.0.0",
		"identity_id": "adult_a",
		"proportions": {"stature_m": 1.81},
		"clothing": {"footwear": "placeholder_footwear"},
	}))
	var partial: Dictionary = rig.load_appearance("user://the_midwifes_world/phase11_partial.json")
	_expect(bool(partial.get("ok", false)), "partial proportions load")
	_expect(is_equal_approx(rig.profile.stature_m, 1.81), "supplied stature kept")
	_expect(is_equal_approx(rig.profile.shoulder_scale, 1.0), "missing shoulder uses default")
	_expect(rig.profile.warnings.has("proportion_key_missing:shoulder_scale"), "missing shoulder diagnostic")
	_expect(rig.garment_visible("placeholder_footwear"), "partial footwear equipped")
	_expect(not rig.garment_visible("placeholder_dress"), "partial load did not keep the previous dress")
	_write("user://the_midwifes_world/phase11_unknown.json", JSON.stringify({
		"schema_version": 1,
		"rig_family": "humanoid_adult_1",
		"content_version": "phase1.adult.1.1",
		"skeleton_version": "1.0.0",
		"identity_id": "retired_person",
		"skin_set_id": "retired_skin",
		"hair_id": "retired_hair",
		"proportions": {"stature_m": 1.7, "shoulder_scale": 1.0, "hip_scale": 1.0, "leg_scale": 1.0, "torso_scale": 1.0},
		"clothing": {"dress": "placeholder_dress", "outer": "retired_apron"},
	}))
	var unknown: Dictionary = rig.load_appearance("user://the_midwifes_world/phase11_unknown.json")
	_expect(bool(unknown.get("ok", false)), "unknown ids load")
	_expect(rig.profile.hair_id == "retired_hair", "unknown hair kept")
	_expect(rig.profile.identity_id == "retired_person", "unknown identity kept")
	_expect(rig.profile.clothing.get("outer", "") == "retired_apron", "unknown garment id kept")
	_expect(rig.garment_visible("placeholder_dress"), "known dress equipped")
	_expect(not rig.garment_visible("placeholder_apron"), "unknown apron was not replaced")
	_expect(rig.profile.missing_ids.has("retired_apron"), "unknown apron reported missing")
	_expect(rig.skin_is_neutral_fallback, "unknown skin stays neutral")
	rig.set_clothing({"accessories": ["placeholder_wrist_band", "placeholder_name_badge"]})
	_expect(rig.save_appearance("user://the_midwifes_world/phase11_accessories.json"), "accessory save")
	rig.set_clothing({"accessory": "placeholder_name_badge"})
	var loaded: Dictionary = rig.load_appearance("user://the_midwifes_world/phase11_accessories.json")
	_expect(bool(loaded.get("ok", false)), "accessory load")
	var restored: Array = rig.profile.clothing["accessories"]
	_expect(restored.has("placeholder_name_badge") and restored.has("placeholder_wrist_band"), "both accessory ids restored")
	_expect(rig.garment_visible("placeholder_name_badge") and rig.garment_visible("placeholder_wrist_band"), "both accessories shown after load")


func _bones(rig: AdultRig) -> void:
	var upper_leg := rig.find_child("UpperLegL", true, false) as MeshInstance3D
	var lower_leg := rig.find_child("LowerLegL", true, false) as MeshInstance3D
	var arm := rig.find_child("UpperArmL", true, false) as MeshInstance3D
	var chest := rig.find_child("ChestBody", true, false) as MeshInstance3D
	_expect(upper_leg.get_parent() is BoneAttachment3D, "upper leg parent is a bone attachment")
	_expect(lower_leg.get_parent() is BoneAttachment3D, "lower leg parent is a bone attachment")
	_expect(arm.get_parent() is BoneAttachment3D, "arm parent is a bone attachment")
	_expect(chest.get_parent() is BoneAttachment3D, "chest parent is a bone attachment")
	_expect(upper_leg.skin == null and arm.skin == null, "primitive meshes have no skin")
	var animation := rig.get_node("AnimationPlayer") as AnimationPlayer
	animation.play("Idle")
	animation.seek(0.0, true)
	await process_frame
	var rest_leg := _marker(upper_leg)
	var rest_knee := _marker(lower_leg)
	var rest_arm := _marker(arm)
	var rest_chest := _marker(chest)
	animation.play("Walk")
	animation.seek(0.4, true)
	await process_frame
	var walk_leg_delta := _marker(upper_leg).distance_to(rest_leg)
	var walk_knee_delta := _marker(lower_leg).distance_to(rest_knee)
	var walk_arm_delta := _marker(arm).distance_to(rest_arm)
	var walk_chest_delta := _marker(chest).distance_to(rest_chest)
	_expect(walk_leg_delta > 0.02, "upper leg follows the walk bone")
	_expect(walk_knee_delta > 0.02, "lower leg follows the walk bone")
	_expect(walk_arm_delta > 0.02, "arm follows the walk bone")
	_expect(walk_chest_delta > 0.005, "chest follows the spine posture")
	print("BONE_DELTAS leg %.4f knee %.4f arm %.4f chest %.4f" % [walk_leg_delta, walk_knee_delta, walk_arm_delta, walk_chest_delta])
	var walk_leg := _marker(upper_leg)
	animation.play("Jump")
	animation.seek(0.17, true)
	await process_frame
	_expect(_marker(upper_leg).distance_to(rest_leg) > 0.02, "jump moves the upper leg")
	animation.play("Idle")
	animation.seek(0.0, true)
	await process_frame
	_expect(_marker(upper_leg).distance_to(rest_leg) < 0.01, "idle returns the upper leg")
	_expect(_marker(upper_leg).distance_to(walk_leg) > 0.02, "idle is distinct from the walk pose")
	print("BONE_IDLE_RETURN %.4f" % _marker(upper_leg).distance_to(rest_leg))


func _marker(mesh: MeshInstance3D) -> Vector3:
	return mesh.to_global(Vector3(0.0, 0.16, 0.04))


func _valid_accessory(garment_id: String, socket: String) -> GarmentDefinition:
	var garment := GarmentDefinition.new()
	garment.garment_id = garment_id
	garment.slot = "accessory"
	garment.socket = socket
	garment.content_version = "phase1.adult.1.1"
	return garment


func _level(resolved: Dictionary, garment_id: String) -> String:
	return str(_entry(resolved, garment_id).get("level", ""))


func _entry(resolved: Dictionary, garment_id: String) -> Dictionary:
	for entry in resolved["results"]:
		if str(entry.get("garment_id", "")) == garment_id:
			return entry
	return {}


func _joined(values: PackedStringArray) -> String:
	return "; ".join(values)


func _write(path: String, text: String) -> void:
	var directory := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failures.append(label)
	push_error("FAIL %s" % label)
