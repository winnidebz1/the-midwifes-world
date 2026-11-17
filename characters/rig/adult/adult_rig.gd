class_name AdultRig
extends Node3D

## Versioned adult visual. It does not move the CharacterBody3D or the camera.

const RIG_FAMILY := "humanoid_adult_1"
const SKELETON_VERSION := "1.0.0"
const REFERENCE_STATURE := 1.72

var profile: AppearanceProfile
var last_load: Dictionary = {}
var skin_is_neutral_fallback := false
var identity_label := ""

var _catalogue := AppearanceCatalogue.new()
var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _skin_material: StandardMaterial3D
var _bones: Dictionary = {}
var _attachments: Dictionary = {}
var _garment_nodes: Dictionary = {}
var _garment_materials: Dictionary = {}
var _clothing_surfaces: Array[Dictionary] = []
var _hair_nodes: Dictionary = {}
var _brow: MeshInstance3D
var _jaw: MeshInstance3D
var _nose: MeshInstance3D


func _ready() -> void:
	_catalogue.load_from_project()
	_build_skeleton()
	_build_body()
	_build_face_and_hair()
	_build_garment_meshes()
	_build_animations()
	last_load = AppearancePersistence.load_profile()
	if bool(last_load.get("ok", false)):
		apply_profile(last_load["profile"])
	else:
		apply_profile(_catalogue.make_default_profile())


func apply_profile(next: AppearanceProfile) -> Dictionary:
	profile = next
	if profile.body_state != "none" and profile.body_state != "unspecified":
		profile.warnings = _with_warning(profile.warnings, "body_state_ignored")
	_apply_proportions()
	_apply_skin()
	_apply_hair()
	_apply_face()
	_apply_identity()
	var resolved := ClothingResolver.resolve(
		profile.clothing,
		_catalogue.garments,
		profile.stature_m,
		profile.shoulder_scale,
		profile.hip_scale,
		_catalogue.invalid_reasons
	)
	_show_equipped(resolved["equipped"])
	profile.compatibility = resolved["results"]
	profile.missing_ids = _appearance_missing(resolved["missing_ids"])
	_skeleton.force_update_all_bone_transforms()
	return resolved


func save_appearance(path: String = AppearancePersistence.SAVE_PATH) -> bool:
	if profile == null:
		return false
	return AppearancePersistence.save_profile(profile, path)


func load_appearance(path: String = AppearancePersistence.SAVE_PATH) -> Dictionary:
	last_load = AppearancePersistence.load_profile(path)
	if not bool(last_load.get("ok", false)):
		return last_load
	apply_profile(last_load["profile"])
	return last_load


func select_identity(next_identity_id: String) -> void:
	profile.identity_id = next_identity_id
	apply_profile(profile)


func set_skin(skin_set_id: String) -> void:
	profile.skin_set_id = skin_set_id
	apply_profile(profile)


func set_hair(hair_id: String) -> void:
	profile.hair_id = hair_id
	apply_profile(profile)


func set_face(facial_id: String) -> void:
	profile.facial_id = facial_id
	apply_profile(profile)


func set_proportions(proportion_id: String, stature_m: float, shoulder_scale: float, hip_scale: float, leg_scale: float, torso_scale: float) -> void:
	profile.proportion_id = proportion_id
	profile.stature_m = stature_m
	profile.shoulder_scale = shoulder_scale
	profile.hip_scale = hip_scale
	profile.leg_scale = leg_scale
	profile.torso_scale = torso_scale
	apply_profile(profile)


func set_clothing(clothing: Dictionary) -> Dictionary:
	profile.clothing = clothing.duplicate(true)
	return apply_profile(profile)


func head_height() -> float:
	return _skeleton.get_bone_global_pose(_bones["Head"]).origin.y


func garment_visible(garment_id: String) -> bool:
	if not _garment_nodes.has(garment_id):
		return false
	for node in _garment_nodes[garment_id]:
		if (node as MeshInstance3D).visible:
			return true
	return false


func region_visible(garment_id: String, region: String) -> bool:
	for surface in _clothing_surfaces:
		if str(surface["garment_id"]) == garment_id and str(surface["region"]) == region:
			return (surface["node"] as MeshInstance3D).visible
	return false


func active_component_ids() -> PackedStringArray:
	var ids := PackedStringArray(["component_body"])
	var hair: Dictionary = _catalogue.hair_sets.get(profile.hair_id, {})
	if not str(hair.get("component_id", "")).is_empty() and not skin_missing(profile.hair_id, _catalogue.hair_sets):
		ids.append(str(hair["component_id"]))
	var face: Dictionary = _catalogue.faces.get(profile.facial_id, {})
	if not str(face.get("component_id", "")).is_empty() and _catalogue.faces.has(profile.facial_id):
		ids.append(str(face["component_id"]))
	return ids


func mesh_counts() -> Dictionary:
	var total := 0
	var visible := 0
	for node in find_children("*", "MeshInstance3D", true, false):
		total += 1
		if node.visible:
			visible += 1
	return {"total": total, "visible": visible}


func material_count() -> int:
	var seen: Dictionary = {}
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if not mesh_node.visible or mesh_node.material_override == null:
			continue
		seen[mesh_node.material_override.get_instance_id()] = true
	return seen.size()


func skin_missing(record_id: String, table: Dictionary) -> bool:
	return not record_id.is_empty() and not table.has(record_id)


func _apply_identity() -> void:
	var record: Dictionary = _catalogue.identities.get(profile.identity_id, {})
	identity_label = str(record.get("label", ""))


func _apply_skin() -> void:
	var record: Dictionary = _catalogue.skin_sets.get(profile.skin_set_id, {})
	if record.is_empty():
		skin_is_neutral_fallback = not profile.skin_set_id.is_empty()
		_skin_material.albedo_color = Color(0.5, 0.5, 0.5, 1)
		_skin_material.roughness = 1.0
		_skin_material.albedo_texture = null
		_skin_material.normal_texture = null
		_skin_material.roughness_texture = null
		return
	skin_is_neutral_fallback = false
	var albedo: Array = record.get("placeholder_albedo", [0.5, 0.5, 0.5])
	_skin_material.albedo_color = Color(float(albedo[0]), float(albedo[1]), float(albedo[2]), 1)
	_skin_material.roughness = float(record.get("roughness", 1.0))
	_skin_material.albedo_texture = _load_texture(str(record.get("albedo_texture", "")))
	_skin_material.normal_texture = _load_texture(str(record.get("normal_texture", "")))
	_skin_material.roughness_texture = _load_texture(str(record.get("roughness_texture", "")))


func _apply_hair() -> void:
	for mesh_name in _hair_nodes.keys():
		(_hair_nodes[mesh_name] as MeshInstance3D).visible = false
	var record: Dictionary = _catalogue.hair_sets.get(profile.hair_id, {})
	if record.is_empty():
		return
	var mesh_name := str(record.get("mesh", ""))
	if _hair_nodes.has(mesh_name):
		(_hair_nodes[mesh_name] as MeshInstance3D).visible = true


func _apply_face() -> void:
	_brow.position = Vector3(0, 0.08, -0.1)
	_jaw.scale = Vector3.ONE
	_nose.position = Vector3(0, -0.02, -0.1)
	var record: Dictionary = _catalogue.faces.get(profile.facial_id, {})
	if record.is_empty():
		return
	_brow.position.y = 0.04 + float(record.get("brow_height", 0.0))
	_jaw.scale.x = float(record.get("jaw_width", 1.0))
	_nose.position.z = -float(record.get("nose_length", 0.08))


func _apply_proportions() -> void:
	var stature_ratio := profile.stature_m / REFERENCE_STATURE
	for bone_name in _bones.keys():
		var index: int = _bones[bone_name]
		var rest := _skeleton.get_bone_rest(index).origin
		var scale := Vector3.ONE
		var position := rest
		match bone_name:
			"Spine", "Neck", "Head":
				position.y = rest.y * stature_ratio * profile.torso_scale
			"Chest":
				position.y = rest.y * stature_ratio * profile.torso_scale
				scale = Vector3(profile.shoulder_scale, profile.torso_scale, 1.0)
			"ShoulderL", "ShoulderR":
				position.x = rest.x * profile.shoulder_scale
				position.y = rest.y * stature_ratio * profile.torso_scale
			"UpperLegL", "UpperLegR":
				position.x = rest.x * profile.hip_scale
				position.y = rest.y * stature_ratio * profile.leg_scale
				scale.x = profile.hip_scale
			"LowerLegL", "LowerLegR":
				position.y = rest.y * stature_ratio * profile.leg_scale
			"Pelvis":
				position.y = rest.y * stature_ratio
				scale = Vector3(profile.hip_scale, 1.0, 1.0)
		_skeleton.set_bone_pose_position(index, position)
		_skeleton.set_bone_pose_rotation(index, Quaternion.IDENTITY)
		_skeleton.set_bone_pose_scale(index, scale)


func _show_equipped(equipped: Dictionary) -> void:
	var shown: Dictionary = {}
	for slot in equipped.keys():
		if str(slot) == "accessories":
			for garment_id in equipped[slot]:
				shown[str(garment_id)] = true
		else:
			shown[str(equipped[slot])] = true
	for surface in _clothing_surfaces:
		(surface["node"] as MeshInstance3D).visible = shown.has(str(surface["garment_id"]))
	for surface in _clothing_surfaces:
		var mesh_node := surface["node"] as MeshInstance3D
		if not mesh_node.visible:
			continue
		if _surface_is_covered(surface, shown):
			mesh_node.visible = false


func _surface_is_covered(surface: Dictionary, shown: Dictionary) -> bool:
	for other_id in shown.keys():
		if str(other_id) == str(surface["garment_id"]):
			continue
		var other: GarmentDefinition = _catalogue.garments.get(str(other_id))
		if other == null:
			continue
		if not other.covers.has(str(surface["slot"])):
			continue
		if other.covered_regions.has(str(surface["region"])):
			return true
	return false


func _appearance_missing(clothing_missing: PackedStringArray) -> PackedStringArray:
	var missing := clothing_missing.duplicate()
	if skin_missing(profile.identity_id, _catalogue.identities):
		missing.append(profile.identity_id)
	if skin_missing(profile.skin_set_id, _catalogue.skin_sets):
		missing.append(profile.skin_set_id)
	if skin_missing(profile.hair_id, _catalogue.hair_sets):
		missing.append(profile.hair_id)
	if skin_missing(profile.facial_id, _catalogue.faces):
		missing.append(profile.facial_id)
	if not profile.proportion_id.is_empty() and not profile.proportion_id.begins_with("custom") and not _catalogue.proportions.has(profile.proportion_id):
		missing.append(profile.proportion_id)
	return missing


func _build_skeleton() -> void:
	_skeleton = Skeleton3D.new()
	_skeleton.name = "Skeleton"
	add_child(_skeleton)
	var root := _add_bone("Root", -1, Vector3.ZERO)
	var pelvis := _add_bone("Pelvis", root, Vector3(0, 0.92, 0))
	var spine := _add_bone("Spine", pelvis, Vector3(0, 0.16, 0))
	var chest := _add_bone("Chest", spine, Vector3(0, 0.2, 0))
	var neck := _add_bone("Neck", chest, Vector3(0, 0.18, 0))
	_add_bone("Head", neck, Vector3(0, 0.12, 0))
	var shoulder_l := _add_bone("ShoulderL", chest, Vector3(-0.2, 0.12, 0))
	var upper_arm_l := _add_bone("UpperArmL", shoulder_l, Vector3(0, -0.22, 0))
	_add_bone("LowerArmL", upper_arm_l, Vector3(0, -0.24, 0))
	var shoulder_r := _add_bone("ShoulderR", chest, Vector3(0.2, 0.12, 0))
	var upper_arm_r := _add_bone("UpperArmR", shoulder_r, Vector3(0, -0.22, 0))
	_add_bone("LowerArmR", upper_arm_r, Vector3(0, -0.24, 0))
	var upper_leg_l := _add_bone("UpperLegL", pelvis, Vector3(-0.1, -0.08, 0))
	_add_bone("LowerLegL", upper_leg_l, Vector3(0, -0.42, 0))
	var upper_leg_r := _add_bone("UpperLegR", pelvis, Vector3(0.1, -0.08, 0))
	_add_bone("LowerLegR", upper_leg_r, Vector3(0, -0.42, 0))


func _build_body() -> void:
	_skin_material = StandardMaterial3D.new()
	_skin_material.roughness = 1.0
	_add_body("Pelvis", "PelvisBody", _box(0.28, 0.16, 0.16), Transform3D.IDENTITY)
	_add_body("Chest", "ChestBody", _box(0.32, 0.28, 0.16), Transform3D.IDENTITY)
	_add_body("Head", "HeadBody", _sphere(0.11), Transform3D.IDENTITY)
	_add_body("UpperArmL", "UpperArmL", _box(0.07, 0.22, 0.07), Transform3D.IDENTITY)
	_add_body("LowerArmL", "LowerArmL", _box(0.06, 0.22, 0.06), Transform3D.IDENTITY)
	_add_body("UpperArmR", "UpperArmR", _box(0.07, 0.22, 0.07), Transform3D.IDENTITY)
	_add_body("LowerArmR", "LowerArmR", _box(0.06, 0.22, 0.06), Transform3D.IDENTITY)
	_add_body("UpperLegL", "UpperLegL", _box(0.09, 0.4, 0.09), Transform3D.IDENTITY)
	_add_body("LowerLegL", "LowerLegL", _box(0.08, 0.4, 0.08), Transform3D.IDENTITY)
	_add_body("UpperLegR", "UpperLegR", _box(0.09, 0.4, 0.09), Transform3D.IDENTITY)
	_add_body("LowerLegR", "LowerLegR", _box(0.08, 0.4, 0.08), Transform3D.IDENTITY)


func _build_face_and_hair() -> void:
	_brow = _add_body("Head", "Brow", _box(0.08, 0.015, 0.02), Transform3D(Basis.IDENTITY, Vector3(0, 0.08, -0.1)))
	_jaw = _add_body("Head", "Jaw", _box(0.08, 0.03, 0.06), Transform3D(Basis.IDENTITY, Vector3(0, -0.06, -0.04)))
	_nose = _add_body("Head", "Nose", _box(0.025, 0.03, 0.04), Transform3D(Basis.IDENTITY, Vector3(0, -0.02, -0.1)))
	_hair_nodes["short"] = _add_plain("Head", "HairShort", _box(0.2, 0.08, 0.18), Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)), Color(0.15, 0.12, 0.1))
	_hair_nodes["tied"] = _add_plain("Head", "HairTied", _box(0.08, 0.16, 0.08), Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 0.12)), Color(0.12, 0.1, 0.08))


func _build_garment_meshes() -> void:
	for garment_id in _catalogue.garments.keys():
		var garment: GarmentDefinition = _catalogue.garments[garment_id]
		match garment.mesh_kind:
			"base":
				_register(garment, "Chest", _box(0.28, 0.28, 0.14), Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0)), "torso")
				_register(garment, "UpperArmL", _box(0.08, 0.2, 0.08), Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0)), "sleeve_left")
				_register(garment, "UpperArmR", _box(0.08, 0.2, 0.08), Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0)), "sleeve_right")
				_register(garment, "UpperLegL", _box(0.1, 0.36, 0.1), Transform3D(Basis.IDENTITY, Vector3(0, -0.16, 0)), "leg_left")
				_register(garment, "UpperLegR", _box(0.1, 0.36, 0.1), Transform3D(Basis.IDENTITY, Vector3(0, -0.16, 0)), "leg_right")
			"scrub_top":
				_register(garment, "Chest", _box(0.36, 0.42, 0.2), Transform3D(Basis.IDENTITY, Vector3(0, -0.06, 0)), "torso")
			"scrub_trousers":
				_register(garment, "UpperLegL", _box(0.11, 0.72, 0.12), Transform3D(Basis.IDENTITY, Vector3(0, -0.36, 0)), "leg_left")
				_register(garment, "UpperLegR", _box(0.11, 0.72, 0.12), Transform3D(Basis.IDENTITY, Vector3(0, -0.36, 0)), "leg_right")
			"dress":
				_register(garment, "Chest", _box(0.38, 0.4, 0.22), Transform3D(Basis.IDENTITY, Vector3(0, -0.04, 0)), "torso")
				_register(garment, "Pelvis", _box(0.4, 0.7, 0.24), Transform3D(Basis.IDENTITY, Vector3(0, -0.42, 0)), "legs")
			"apron":
				_register(garment, "Chest", _box(0.28, 0.72, 0.02), Transform3D(Basis.IDENTITY, Vector3(0, -0.28, -0.14)), "torso")
			"belt":
				_register(garment, "Pelvis", _box(0.34, 0.05, 0.2), Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 0)), "waist")
			"footwear":
				_register(garment, "LowerLegL", _box(0.1, 0.06, 0.16), Transform3D(Basis.IDENTITY, Vector3(0, -0.38, -0.03)), "foot_left")
				_register(garment, "LowerLegR", _box(0.1, 0.06, 0.16), Transform3D(Basis.IDENTITY, Vector3(0, -0.38, -0.03)), "foot_right")
			"badge":
				_register(garment, "Chest", _box(0.06, 0.04, 0.01), Transform3D(Basis.IDENTITY, Vector3(-0.1, 0.06, -0.11)), "chest")
			"wrist":
				_register(garment, "LowerArmL", _box(0.07, 0.04, 0.07), Transform3D(Basis.IDENTITY, Vector3(0, -0.16, 0)), "wrist")


func _build_animations() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	var library := AnimationLibrary.new()
	library.add_animation("Idle", _clip(1.2, true, 0.05, 0.05))
	library.add_animation("Walk", _clip(0.8, true, 0.45, -0.45))
	library.add_animation("Run", _clip(0.45, true, 0.7, -0.7))
	library.add_animation("Jump", _clip(0.35, false, 0.5, 0.2))
	_animation_player.add_animation_library("", library)


func _clip(length: float, looping: bool, left_swing: float, right_swing: float) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	_rotation_track(animation, "Skeleton:UpperLegL", length, left_swing)
	_rotation_track(animation, "Skeleton:UpperLegR", length, right_swing)
	_rotation_track(animation, "Skeleton:LowerLegL", length, -left_swing * 0.55)
	_rotation_track(animation, "Skeleton:LowerLegR", length, -right_swing * 0.55)
	_rotation_track(animation, "Skeleton:UpperArmL", length, -left_swing * 0.7)
	_rotation_track(animation, "Skeleton:UpperArmR", length, -right_swing * 0.7)
	_rotation_track(animation, "Skeleton:Spine", length, left_swing * 0.2)
	return animation


func _rotation_track(animation: Animation, path: String, length: float, swing: float) -> void:
	var track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track, NodePath(path))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	animation.rotation_track_insert_key(track, 0.0, Quaternion.IDENTITY)
	animation.rotation_track_insert_key(track, length * 0.5, Quaternion(Vector3.RIGHT, swing))
	animation.rotation_track_insert_key(track, length, Quaternion.IDENTITY)


func _add_bone(bone_name: String, parent: int, origin: Vector3) -> int:
	var index := _skeleton.add_bone(bone_name)
	if parent >= 0:
		_skeleton.set_bone_parent(index, parent)
	_skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, origin))
	_bones[bone_name] = index
	return index


func _add_body(bone_name: String, part_name: String, mesh: Mesh, local: Transform3D) -> MeshInstance3D:
	var instance := _add_mesh(bone_name, part_name, mesh, local, _skin_material)
	return instance


func _add_plain(bone_name: String, part_name: String, mesh: Mesh, local: Transform3D, color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	var instance := _add_mesh(bone_name, part_name, mesh, local, material)
	instance.visible = false
	return instance


func _register(garment: GarmentDefinition, bone_name: String, mesh: Mesh, local: Transform3D, region: String) -> void:
	if not _garment_materials.has(garment.garment_id):
		var material := StandardMaterial3D.new()
		material.albedo_color = garment.albedo
		material.roughness = 0.75
		_garment_materials[garment.garment_id] = material
	var instance := _add_mesh(bone_name, "%s_%s" % [garment.garment_id, region], mesh, local, _garment_materials[garment.garment_id])
	instance.visible = false
	if not _garment_nodes.has(garment.garment_id):
		_garment_nodes[garment.garment_id] = []
	_garment_nodes[garment.garment_id].append(instance)
	_clothing_surfaces.append({
		"node": instance,
		"garment_id": garment.garment_id,
		"slot": garment.slot,
		"region": region,
		"bone": bone_name,
	})


func _add_mesh(bone_name: String, part_name: String, mesh: Mesh, local: Transform3D, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.transform = local
	instance.material_override = material
	_attachment(bone_name).add_child(instance)
	return instance


func _attachment(bone_name: String) -> BoneAttachment3D:
	if _attachments.has(bone_name):
		return _attachments[bone_name]
	var attachment := BoneAttachment3D.new()
	attachment.name = bone_name + "Attachment"
	attachment.bone_name = bone_name
	_skeleton.add_child(attachment)
	attachment.bone_idx = _bones[bone_name]
	_attachments[bone_name] = attachment
	return attachment


func _box(width: float, height: float, depth: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, depth)
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _with_warning(warnings: PackedStringArray, warning: String) -> PackedStringArray:
	if warnings.has(warning):
		return warnings
	var next := warnings.duplicate()
	next.append(warning)
	return next
