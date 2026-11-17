class_name ClothingResolver
extends RefCounted

## Resolves a requested clothing map. Invalid records and body conflicts use different levels.

const SINGLE_SLOTS: PackedStringArray = [
	"base", "uniform_upper", "uniform_lower", "dress", "outer", "belt", "footwear",
]


static func resolve(requested: Dictionary, garments: Dictionary, stature_m: float, shoulder_scale: float, hip_scale: float, invalid_reasons: Dictionary = {}) -> Dictionary:
	var passed: Dictionary = {}
	var results: Array = []
	var missing: PackedStringArray = PackedStringArray()
	for slot in SINGLE_SLOTS:
		if not requested.has(slot):
			continue
		var garment_id := str(requested[slot])
		if garment_id.is_empty():
			continue
		var outcome := _consider(garment_id, slot, garments, invalid_reasons, stature_m, shoulder_scale, hip_scale)
		results.append(outcome["result"])
		if outcome["missing"]:
			missing.append(garment_id)
		if outcome["garment"] != null:
			passed[slot] = outcome["garment"]
	_apply_occupancy(passed, results)
	_apply_requirements(passed, results)
	var accessories := _accessory_ids(requested)
	var sockets: Dictionary = {}
	for garment_id in accessories:
		var outcome := _consider(garment_id, "accessory", garments, invalid_reasons, stature_m, shoulder_scale, hip_scale)
		var result: Dictionary = outcome["result"]
		if outcome["missing"]:
			missing.append(garment_id)
		var garment: GarmentDefinition = outcome["garment"]
		if garment != null and sockets.has(garment.socket):
			var holder: String = sockets[garment.socket]
			result["level"] = "incompatible"
			result["reason"] = "Socket %s already holds %s, so %s stays off. It was not replaced with a different accessory." % [garment.socket, holder, garment_id]
			garment = null
		elif garment != null:
			sockets[garment.socket] = garment_id
		results.append(result)
	var equipped := {}
	var equipped_accessories: Array[String] = []
	for slot in SINGLE_SLOTS:
		if passed.has(slot):
			equipped[slot] = passed[slot].garment_id
	for socket in _sorted_keys(sockets):
		equipped_accessories.append(str(sockets[socket]))
	if not equipped_accessories.is_empty():
		equipped["accessories"] = equipped_accessories
	return {"equipped": equipped, "results": results, "missing_ids": missing}


static func _accessory_ids(requested: Dictionary) -> PackedStringArray:
	var ids := PackedStringArray()
	if requested.has("accessory") and typeof(requested["accessory"]) == TYPE_STRING and not str(requested["accessory"]).is_empty():
		ids.append(str(requested["accessory"]))
	if requested.has("accessories") and requested["accessories"] is Array:
		for value in requested["accessories"]:
			var garment_id := str(value)
			if not garment_id.is_empty() and not ids.has(garment_id):
				ids.append(garment_id)
	ids.sort()
	return ids


static func _consider(garment_id: String, slot: String, garments: Dictionary, invalid_reasons: Dictionary, stature_m: float, shoulder_scale: float, hip_scale: float) -> Dictionary:
	if invalid_reasons.has(garment_id):
		var listed: PackedStringArray = PackedStringArray(invalid_reasons[garment_id])
		return {
			"garment": null,
			"missing": false,
			"result": _result(garment_id, slot, "invalid_content", "Invalid catalogue content for %s: %s" % [garment_id, "; ".join(listed)], "", ""),
		}
	var garment: GarmentDefinition = garments.get(garment_id)
	if garment == null:
		return {
			"garment": null,
			"missing": true,
			"result": _result(garment_id, slot, "incompatible", "missing_content: %s is not in the installed catalogue and was not replaced." % garment_id, "", ""),
		}
	var errors := garment.validation_errors()
	if not errors.is_empty():
		return {
			"garment": null,
			"missing": false,
			"result": _result(garment_id, slot, "invalid_content", "Invalid catalogue content for %s: %s" % [garment_id, "; ".join(errors)], garment.content_version, garment.evidence_status),
		}
	if garment.slot != slot:
		return {
			"garment": null,
			"missing": false,
			"result": _result(garment_id, slot, "incompatible", "%s belongs in slot %s and was requested in %s. It was not moved to another slot." % [garment_id, garment.slot, slot], garment.content_version, garment.evidence_status),
		}
	var fit := garment.fit_against(stature_m, shoulder_scale, hip_scale)
	if str(fit["level"]) == "incompatible":
		return {
			"garment": null,
			"missing": false,
			"result": _result(garment_id, slot, "incompatible", str(fit["reason"]), garment.content_version, garment.evidence_status),
		}
	return {
		"garment": garment,
		"missing": false,
		"result": _result(garment_id, slot, str(fit["level"]), str(fit["reason"]), garment.content_version, garment.evidence_status),
	}


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


static func _sorted_keys(values: Dictionary) -> PackedStringArray:
	var keys := PackedStringArray()
	for key in values.keys():
		keys.append(str(key))
	keys.sort()
	return keys
