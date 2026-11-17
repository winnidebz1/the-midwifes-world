class_name ClothingResolver
extends RefCounted

## Resolves a requested slot map against garment records and a proportion snapshot.


static func resolve(requested: Dictionary, garments: Dictionary, stature_m: float, shoulder_scale: float, hip_scale: float) -> Dictionary:
	var passed: Dictionary = {}
	var results: Array = []
	var missing: PackedStringArray = PackedStringArray()
	for slot_value in requested.keys():
		var slot := str(slot_value)
		var garment_id := str(requested[slot_value])
		if garment_id.is_empty():
			continue
		var garment: GarmentDefinition = garments.get(garment_id)
		if garment == null:
			missing.append(garment_id)
			results.append(_result(garment_id, slot, "incompatible", "missing_content: %s is not in the installed catalogue and was not replaced." % garment_id, "", ""))
			continue
		if garment.slot != slot:
			results.append(_result(garment_id, slot, "incompatible", "%s belongs in slot %s and was requested in %s. It was not moved to another slot." % [garment_id, garment.slot, slot], garment.content_version, garment.evidence_status))
			continue
		var fit := garment.fit_against(stature_m, shoulder_scale, hip_scale)
		results.append(_result(garment_id, slot, str(fit["level"]), str(fit["reason"]), garment.content_version, garment.evidence_status))
		if str(fit["level"]) != "incompatible":
			passed[slot] = garment
	_apply_occupancy(passed, results)
	_apply_requirements(passed, results)
	var equipped := {}
	for slot in passed.keys():
		equipped[slot] = passed[slot].garment_id
	return {"equipped": equipped, "results": results, "missing_ids": missing}


static func _apply_occupancy(passed: Dictionary, results: Array) -> void:
	var blocked: Dictionary = {}
	for slot in passed.keys():
		var garment: GarmentDefinition = passed[slot]
		for occupied in garment.occupies:
			var other: GarmentDefinition = passed.get(str(occupied))
			if other == null:
				continue
			blocked[str(occupied)] = "%s occupies %s, so %s stays off. It was not replaced with a different garment." % [garment.garment_id, str(occupied), other.garment_id]
	for slot in blocked.keys():
		var garment: GarmentDefinition = passed[slot]
		passed.erase(slot)
		_replace_result(results, garment.garment_id, "incompatible", str(blocked[slot]))


static func _apply_requirements(passed: Dictionary, results: Array) -> void:
	for slot in passed.keys():
		var garment: GarmentDefinition = passed[slot]
		if garment.requires_any_of.is_empty():
			continue
		var found := false
		for required_slot in garment.requires_any_of:
			if passed.has(str(required_slot)):
				found = true
				break
		if found:
			continue
		var reason := "%s is attached without %s underneath. That gap is a documented limitation of this placeholder." % [garment.garment_id, ", ".join(garment.requires_any_of)]
		_replace_result(results, garment.garment_id, "compatible_with_limitations", reason)


static func _replace_result(results: Array, garment_id: String, level: String, reason: String) -> void:
	for index in results.size():
		var entry: Dictionary = results[index]
		if str(entry.get("garment_id", "")) != garment_id:
			continue
		entry["level"] = level
		entry["reason"] = reason
		results[index] = entry
		return


static func _result(garment_id: String, slot: String, level: String, reason: String, content_version: String, evidence_status: String) -> Dictionary:
	return {
		"garment_id": garment_id,
		"slot": slot,
		"level": level,
		"reason": reason,
		"content_version": content_version,
		"evidence_status": evidence_status,
	}
