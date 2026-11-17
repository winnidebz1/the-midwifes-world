class_name GarmentDefinition
extends Resource

## One interchangeable garment record. Placeholder records are not national standards.

@export var garment_id := ""
@export var display_name := ""
@export var slot := ""
@export var occupies: PackedStringArray = PackedStringArray()
@export var covers: PackedStringArray = PackedStringArray()
@export var requires_any_of: PackedStringArray = PackedStringArray()
@export var stature_full := Vector2(1.6, 1.85)
@export var stature_limited := Vector2(1.5, 1.95)
@export var shoulder_full := Vector2(0.92, 1.08)
@export var shoulder_limited := Vector2(0.85, 1.2)
@export var hip_full := Vector2(0.92, 1.08)
@export var hip_limited := Vector2(0.85, 1.2)
@export var limitation := ""
@export var content_version := "phase1.adult.1"
@export var evidence_status := "placeholder"
@export var note := "Placeholder garment. Not a national or professional uniform standard."
@export var mesh_kind := "box"
@export var albedo := Color(0.75, 0.75, 0.75, 1)


func fit_against(stature_m: float, shoulder_scale: float, hip_scale: float) -> Dictionary:
	var outside := _outside(stature_m, stature_limited) or _outside(shoulder_scale, shoulder_limited) or _outside(hip_scale, hip_limited)
	if outside:
		return {
			"level": "incompatible",
			"reason": "Body is outside the tested range for %s. Stature %.2f m (limited %.2f–%.2f), shoulder %.2f (limited %.2f–%.2f), hip %.2f (limited %.2f–%.2f)." % [
				garment_id, stature_m, stature_limited.x, stature_limited.y,
				shoulder_scale, shoulder_limited.x, shoulder_limited.y,
				hip_scale, hip_limited.x, hip_limited.y,
			],
		}
	var limited := _outside(stature_m, stature_full) or _outside(shoulder_scale, shoulder_full) or _outside(hip_scale, hip_full)
	if limited:
		return {
			"level": "compatible_with_limitations",
			"reason": limitation if not limitation.is_empty() else "Inside the limited range and outside the fully tested range. No corrective shapes are authored.",
		}
	return {"level": "compatible", "reason": ""}


func _outside(value: float, span: Vector2) -> bool:
	return value < span.x or value > span.y
