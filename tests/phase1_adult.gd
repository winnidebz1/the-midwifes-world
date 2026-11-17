extends SceneTree

var _failures: PackedStringArray = PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_delete_default_save()
	await process_frame
	var boot_error := change_scene_to_file("res://scenes/boot.tscn")
	for _frame in 4:
		await process_frame
	if boot_error != OK or current_scene == null or current_scene.name != "Boot":
		_fail("boot scene did not open")
	else:
		print("BOOT_OK")
	_send_action("advance")
	for _frame in 8:
		await process_frame
	var shell := current_scene
	if shell == null or shell.name != "Prototype":
		_fail("prototype did not open from boot")
		_finish()
		return
	print("PROTOTYPE_OK")
	var player := shell.get_node("Player") as PlayerCharacter
	var rig: AdultRig = player.find_child("HumanoidAdult1", true, false)
	if rig == null:
		_fail("adult rig missing")
		_finish()
		return
	if player.get_node("CollisionShape3D").shape is CapsuleShape3D:
		print("COLLISION_CAPSULE_OK")
	else:
		_fail("player collision is no longer a capsule")
	_expect(rig.RIG_FAMILY == "humanoid_adult_1", "rig family")
	_expect(rig.SKELETON_VERSION == "1.0.0", "skeleton version")
	_expect(rig.profile.identity_id == "adult_a", "default identity")
	_expect(rig.profile.skin_set_id == "skin_warm", "default skin")
	_expect(rig.garment_visible("placeholder_scrub_top"), "default scrub top visible")
	_expect(rig.garment_visible("placeholder_scrub_trousers"), "default scrub trousers visible")
	_expect(not rig.garment_visible("placeholder_dress"), "dress hidden on the default outfit")
	_expect(_level(rig, "placeholder_scrub_top") == "compatible", "scrub top compatible")
	_expect(_level(rig, "placeholder_scrub_trousers") == "compatible", "scrub trousers compatible")
	await _movement(player, rig)
	await _appearance(rig)
	var catalogue := AppearanceCatalogue.new()
	catalogue.load_from_project()
	rig.apply_profile(catalogue.make_default_profile())
	var default_counts: Dictionary = rig.mesh_counts()
	print("DEFAULT_MESH_TOTAL %s" % default_counts["total"])
	print("DEFAULT_MESH_VISIBLE %s" % default_counts["visible"])
	print("DEFAULT_MATERIAL_VISIBLE %s" % rig.material_count())
	await _leave(shell)
	_finish()


func _movement(player: PlayerCharacter, rig: AdultRig) -> void:
	var camera := player.get_node("CameraPivot")
	_expect(is_equal_approx(camera.distance, 4.5), "camera distance")
	var yaw_before: float = camera.rotation.y
	var pitch_before: float = camera.get_node("PitchPivot").rotation.x
	camera.apply_look(Vector2(12, -8))
	_expect(not is_equal_approx(camera.rotation.y, yaw_before), "camera yaw")
	_expect(not is_equal_approx(camera.get_node("PitchPivot").rotation.x, pitch_before), "camera pitch")
	camera.rotation.y = 0.0
	camera.get_node("PitchPivot").rotation.x = 0.0
	Input.action_press("move_forward")
	for _frame in 30:
		await physics_frame
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	_expect(player.movement_state == PlayerCharacter.MovementState.WALK, "walk state")
	_expect(speed > 2.4 and speed < 2.8, "walk speed %s" % speed)
	_expect(absf(player.get_node("Visual").rotation.y) < 0.15, "forward yaw")
	var animation := player.get_node("CharacterAnimation")
	var player_anim: AnimationPlayer = rig.get_node("AnimationPlayer")
	_expect(animation.active_clip == "Walk", "walk clip name")
	_expect(player_anim.current_animation == "Walk", "walk animation playing")
	Input.action_press("move_right")
	Input.action_release("move_forward")
	for _frame in 20:
		await physics_frame
	_expect(player.get_node("Visual").rotation.y < -1.2, "strafe yaw")
	Input.action_release("move_right")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for _frame in 45:
		await physics_frame
	var run_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_expect(player.movement_state == PlayerCharacter.MovementState.RUN, "run state")
	_expect(run_speed > 5.0 and run_speed < 5.4, "run speed %s" % run_speed)
	_expect(animation.active_clip == "Run", "run clip")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	for _frame in 40:
		await physics_frame
		if player.is_on_floor() and Vector2(player.velocity.x, player.velocity.z).length() < 0.2:
			break
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame
	_expect(player.movement_state == PlayerCharacter.MovementState.JUMP, "jump state")
	_expect(player.velocity.y > 0.2 or player.position.y > 0.1, "jump height")
	_expect(animation.active_clip == "Jump", "jump clip")
	for _frame in 40:
		await physics_frame
		if player.is_on_floor():
			break
	print("MOVEMENT_OK")


func _appearance(rig: AdultRig) -> void:
	var clothing_before: Dictionary = rig.profile.clothing.duplicate()
	var skin_before := rig.profile.skin_set_id
	rig.select_identity("adult_b")
	_expect(rig.identity_label == "Placeholder Adult B", "identity label")
	_expect(rig.profile.clothing["uniform_upper"] == clothing_before["uniform_upper"], "identity leaves clothing")
	_expect(rig.profile.skin_set_id == skin_before, "identity leaves skin")
	rig.set_skin("skin_deep")
	_expect(is_equal_approx(rig._skin_material.roughness, 0.82), "skin roughness")
	_expect(rig.profile.clothing["uniform_lower"] == clothing_before["uniform_lower"], "skin leaves clothing")
	rig.set_hair("hair_tied")
	_expect(rig._hair_nodes["tied"].visible, "tied hair shown")
	_expect(not rig._hair_nodes["short"].visible, "short hair hidden")
	_expect(rig.active_component_ids().has("component_hair_tied"), "hair component")
	var narrow_brow: float = rig._brow.position.y
	rig.set_face("face_broad")
	_expect(rig._brow.position.y > narrow_brow + 0.02, "brow moved")
	_expect(rig._jaw.scale.x > 1.05, "jaw widened")
	var short_height := rig.head_height()
	rig.set_proportions("custom_tall", 1.9, 1.15, 1.0, 1.08, 1.05)
	_expect(rig.head_height() > short_height + 0.08, "taller stature")
	rig.set_proportions("proportion_average", 1.72, 1.0, 1.0, 1.0, 1.0)
	var layered: Dictionary = rig.set_clothing({
		"base": "placeholder_base_layer",
		"dress": "placeholder_dress",
		"outer": "placeholder_apron",
		"uniform_lower": "placeholder_scrub_trousers",
		"belt": "placeholder_belt",
		"footwear": "placeholder_footwear",
	})
	_expect(_level_in(layered, "placeholder_dress") == "compatible", "apron over dress: dress")
	_expect(_level_in(layered, "placeholder_apron") == "compatible", "apron over dress: apron")
	_expect(_level_in(layered, "placeholder_scrub_trousers") == "incompatible", "dress blocks trousers")
	_expect(rig.garment_visible("placeholder_dress"), "dress mesh")
	_expect(rig.garment_visible("placeholder_apron"), "apron mesh")
	_expect(not rig.garment_visible("placeholder_scrub_trousers"), "trousers hidden")
	_expect(rig.profile.clothing["uniform_lower"] == "placeholder_scrub_trousers", "rejected trousers kept")
	var scrubs: Dictionary = rig.set_clothing({
		"base": "placeholder_base_layer",
		"uniform_upper": "placeholder_scrub_top",
		"uniform_lower": "placeholder_scrub_trousers",
		"footwear": "placeholder_footwear",
	})
	_expect(_level_in(scrubs, "placeholder_scrub_top") == "compatible", "scrubs top")
	_expect(_level_in(scrubs, "placeholder_scrub_trousers") == "compatible", "scrubs trousers")
	_expect(rig.garment_visible("placeholder_scrub_top"), "scrubs top mesh")
	_expect(not rig.garment_visible("placeholder_apron"), "apron removed with scrubs")
	var apron_over_scrubs: Dictionary = rig.set_clothing({
		"uniform_upper": "placeholder_scrub_top",
		"uniform_lower": "placeholder_scrub_trousers",
		"outer": "placeholder_apron",
	})
	_expect(_level_in(apron_over_scrubs, "placeholder_apron") == "compatible", "apron over scrubs")
	_expect(_level_in(apron_over_scrubs, "placeholder_scrub_top") == "compatible", "scrubs top under apron")
	_expect(_level_in(apron_over_scrubs, "placeholder_scrub_trousers") == "compatible", "scrubs trousers under apron")
	_expect(rig.garment_visible("placeholder_apron"), "apron shown over scrubs")
	_expect(not rig.region_visible("placeholder_scrub_top", "torso"), "apron covers the scrub torso")
	_expect(rig.garment_visible("placeholder_scrub_trousers"), "scrub trousers remain under the apron")
	_expect(_reason_in(layered, "placeholder_scrub_trousers").contains("occupies"), "trousers rejection reason")
	rig.set_proportions("custom_limited", 1.55, 1.0, 1.0, 1.0, 1.0)
	var limited: Dictionary = rig.set_clothing({"uniform_upper": "placeholder_scrub_top"})
	_expect(_level_in(limited, "placeholder_scrub_top") == "compatible_with_limitations", "limited stature")
	_expect(rig.garment_visible("placeholder_scrub_top"), "limited garment still shown")
	rig.set_proportions("custom_outside", 2.2, 1.0, 1.0, 1.0, 1.0)
	var outside: Dictionary = rig.set_clothing({"uniform_upper": "placeholder_scrub_top"})
	_expect(_level_in(outside, "placeholder_scrub_top") == "incompatible", "outside range")
	_expect(not rig.garment_visible("placeholder_scrub_top"), "outside garment hidden")
	rig.set_proportions("proportion_average", 1.72, 1.0, 1.0, 1.0, 1.0)
	rig.profile.identity_id = "adult_b"
	rig.profile.skin_set_id = "missing_skin"
	rig.profile.hair_id = "missing_hair"
	rig.profile.facial_id = "face_narrow"
	rig.profile.clothing = {
		"dress": "placeholder_dress",
		"uniform_upper": "missing_top",
	}
	var missing: Dictionary = rig.apply_profile(rig.profile)
	_expect(_level_in(missing, "missing_top") == "incompatible", "missing garment incompatible")
	_expect(rig.profile.missing_ids.has("missing_skin"), "missing skin kept")
	_expect(rig.profile.missing_ids.has("missing_hair"), "missing hair kept")
	_expect(rig.profile.missing_ids.has("missing_top"), "missing top kept")
	_expect(rig.garment_visible("placeholder_dress"), "known dress kept")
	_expect(not rig.garment_visible("placeholder_scrub_top"), "missing top was not replaced")
	_expect(rig.skin_is_neutral_fallback, "neutral skin fallback")
	_expect(not rig._hair_nodes["short"].visible and not rig._hair_nodes["tied"].visible, "missing hair hidden")
	var round_path := "user://the_midwifes_world/phase1_roundtrip.json"
	rig.select_identity("adult_b")
	rig.set_skin("skin_deep")
	rig.set_hair("hair_tied")
	rig.set_face("face_broad")
	rig.set_proportions("custom_saved", 1.68, 0.98, 1.02, 0.97, 1.01)
	rig.set_clothing({
		"dress": "placeholder_dress",
		"outer": "placeholder_apron",
		"footwear": "placeholder_footwear",
	})
	_expect(rig.save_appearance(round_path), "save wrote")
	rig.select_identity("adult_a")
	rig.set_skin("skin_warm")
	rig.set_hair("hair_short")
	rig.set_clothing({"uniform_upper": "placeholder_scrub_top"})
	var loaded: Dictionary = rig.load_appearance(round_path)
	_expect(bool(loaded.get("ok", false)), "load ok")
	_expect(rig.profile.identity_id == "adult_b", "loaded identity")
	_expect(rig.profile.skin_set_id == "skin_deep", "loaded skin")
	_expect(rig.profile.hair_id == "hair_tied", "loaded hair")
	_expect(rig.profile.facial_id == "face_broad", "loaded face")
	_expect(is_equal_approx(rig.profile.stature_m, 1.68), "loaded stature")
	_expect(rig.profile.clothing["dress"] == "placeholder_dress", "loaded dress")
	_expect(rig.profile.clothing["outer"] == "placeholder_apron", "loaded apron")
	_expect(_level(rig, "placeholder_apron") == "compatible", "loaded apron compatible")
	_expect(rig.garment_visible("placeholder_dress"), "loaded dress visible")
	_expect(not rig.garment_visible("placeholder_scrub_top"), "load did not keep the temporary top")
	var bad_path := "user://the_midwifes_world/phase1_bad_schema.json"
	var bad := FileAccess.open(bad_path, FileAccess.WRITE)
	bad.store_string("{\"schema_version\":99,\"rig_family\":\"humanoid_adult_1\"}")
	bad.close()
	var rejected: Dictionary = rig.load_appearance(bad_path)
	_expect(str(rejected.get("error", "")) == "unsupported_schema", "old schema rejected")
	_expect(rig.profile.identity_id == "adult_b", "rejected load left the current appearance")
	var partial_path := "user://the_midwifes_world/phase1_partial.json"
	var partial := {
		"schema_version": 1,
		"content_version": "phase1.adult.0",
		"rig_family": "humanoid_adult_1",
		"skeleton_version": "0.9.0",
		"body_state": "none",
		"identity_id": "adult_a",
		"skin_set_id": "skin_warm",
		"hair_id": "retired_hair",
		"facial_id": "face_narrow",
		"proportion_id": "retired_proportion",
		"proportions": {"stature_m": 1.7, "shoulder_scale": 1.0, "hip_scale": 1.0, "leg_scale": 1.0, "torso_scale": 1.0},
		"clothing": {"dress": "placeholder_dress"},
		"compatibility": [],
	}
	var partial_file := FileAccess.open(partial_path, FileAccess.WRITE)
	partial_file.store_string(JSON.stringify(partial))
	partial_file.close()
	var partial_load: Dictionary = rig.load_appearance(partial_path)
	_expect(bool(partial_load.get("ok", false)), "partial load")
	_expect(rig.profile.missing_ids.has("retired_hair"), "retired hair kept")
	_expect(rig.profile.missing_ids.has("retired_proportion"), "retired proportion id kept")
	_expect(rig.profile.hair_id == "retired_hair", "retired hair not replaced")
	_expect(not rig._hair_nodes["short"].visible, "retired hair did not become short hair")
	_expect(rig.garment_visible("placeholder_dress"), "partial dress equipped")
	_expect(not rig.garment_visible("placeholder_scrub_top"), "partial file did not gain a top")
	_expect(rig.profile.warnings.has("content_version_differs"), "content version warning")
	_expect(rig.profile.warnings.has("skeleton_version_differs"), "skeleton version warning")
	var counts := rig.mesh_counts()
	print("PARTIAL_MESH_TOTAL %s" % counts["total"])
	print("PARTIAL_MESH_VISIBLE %s" % counts["visible"])
	print("PARTIAL_MATERIAL_VISIBLE %s" % rig.material_count())
	print("APPEARANCE_OK")


func _leave(shell: Node) -> void:
	_send_action("back")
	for _frame in 4:
		await process_frame
	_expect(shell.get("_cursor_captured") == false, "first escape releases the cursor")
	_expect(current_scene.name == "Prototype", "first escape stays in the yard")
	_send_action("back")
	for _frame in 8:
		await process_frame
	_expect(current_scene != null and current_scene.name == "Boot", "second escape returns to boot")
	print("FLOW_OK")


func _level(rig: AdultRig, garment_id: String) -> String:
	for entry in rig.profile.compatibility:
		if str(entry.get("garment_id", "")) == garment_id:
			return str(entry.get("level", ""))
	return ""


func _level_in(resolved: Dictionary, garment_id: String) -> String:
	return str(_entry(resolved, garment_id).get("level", ""))


func _reason_in(resolved: Dictionary, garment_id: String) -> String:
	return str(_entry(resolved, garment_id).get("reason", ""))


func _entry(resolved: Dictionary, garment_id: String) -> Dictionary:
	for entry in resolved["results"]:
		if str(entry.get("garment_id", "")) == garment_id:
			return entry
	return {}


func _send_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


func _delete_default_save() -> void:
	var path := AppearancePersistence.SAVE_PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	push_error("FAIL %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("PHASE1_OK")
		quit(0)
		return
	print("PHASE1_FAILED %s" % " | ".join(_failures))
	quit(1)
