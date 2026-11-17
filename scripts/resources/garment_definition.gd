class_name GarmentDefinition
extends Resource

## One interchangeable garment record. Placeholder records are not national standards.

const DEFAULT_STATURE_FULL := Vector2(1.6, 1.85)
const DEFAULT_STATURE_LIMITED := Vector2(1.5, 1.95)
const DEFAULT_SHOULDER_FULL := Vector2(0.92, 1.08)
const DEFAULT_SHOULDER_LIMITED := Vector2(0.85, 1.2)
const DEFAULT_HIP_FULL := Vector2(0.92, 1.08)
const DEFAULT_HIP_LIMITED := Vector2(0.85, 1.2)
const SLOTS: PackedStringArray = [
	"base", "uniform_upper", "uniform_lower", "dress", "outer", "belt", "footwear", "accessory",
]
const SOCKETS: PackedStringArray = ["chest", "wrist"]

@export var garment_id := ""
@export var display_name := ""
@export var slot := ""
@export var socket := ""
@export var occupies: PackedStringArray = PackedStringArray()
@export var covers: PackedStringArray = PackedStringArray()
@export var covered_regions: PackedStringArray = PackedStringArray()
@export var requires_any_of: PackedStringArray = PackedStringArray()
@export var stature_full := DEFAULT_STATURE_FULL
@export var stature_limited := DEFAULT_STATURE_LIMITED
@export var shoulder_full := DEFAULT_SHOULDER_FULL
@export var shoulder_limited := DEFAULT_SHOULDER_LIMITED
@export var hip_full := DEFAULT_HIP_FULL
@export var hip_limited := DEFAULT_HIP_LIMITED
@export var limitation := ""
@export var content_version := "phase1.adult.1.1"
@export var evidence_status := "placeholder"
@export var note := "Placeholder garment. Not a national or professional uniform standard."
@export var mesh_kind := "box"
@export var albedo := Color(0.75, 0.75, 0.75, 1)
@export var metadata_errors: PackedStringArray = PackedStringArray()


func validation_errors() -> PackedStringArray:
	var errors := metadata_errors.duplicate()
	if garment_id.is_empty():
		errors.append("missing content id")
	if not SLOTS.has(slot):
		errors.append("slot is missing or unknown")
	if content_version.is_empty():
		errors.append("content_version is required")
	_check_range(errors, "stature_full", stature_full)
	_check_range(errors, "stature_limited", stature_limited)
	_check_range(errors, "shoulder_full", shoulder_full)
	_check_range(errors, "shoulder_limited", shoulder_limited)
	_check_range(errors, "hip_full", hip_full)
	_check_range(errors, "hip_limited", hip_limited)
	_check_contains(errors, "stature", stature_limited, stature_full)
	_check_contains(errors, "shoulder", shoulder_limited, shoulder_full)
	_check_contains(errors, "hip", hip_limited, hip_full)
	if slot == "dress" and occupies.is_empty():
		errors.append("dress metadata is missing occupies")
	if slot == "accessory" and not SOCKETS.has(socket):
		errors.append("accessory metadata is missing an exclusive socket")
	if not covers.is_empty() and covered_regions.is_empty():
		errors.append("covers is set without covered_regions")
	return errors


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


func _check_range(errors: PackedStringArray, label: String, span: Vector2) -> void:
	if span.x < span.y:
		return
	errors.append("%s is reversed or empty (%.2f to %.2f). This is invalid catalogue content, not a body-fit result." % [label, span.x, span.y])


func _check_contains(errors: PackedStringArray, label: String, outer: Vector2, inner: Vector2) -> void:
	if outer.x < outer.y and inner.x < inner.y and outer.x <= inner.x and outer.y >= inner.y:
		return
	if outer.x >= outer.y or inner.x >= inner.y:
		return
	errors.append("%s limited range does not contain the full range" % label)


func _outside(value: float, span: Vector2) -> bool:
	return value < span.x or value > span.y
