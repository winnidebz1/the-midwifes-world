extends SceneTree

var _one_deltas: Array[float] = []
var _group_deltas: Array[float] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(AppearancePersistence.SAVE_PATH):
		DirAccess.remove_absolute(AppearancePersistence.SAVE_PATH)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var yard: Node = load("res://environments/scenes/test_yard.tscn").instantiate()
	root.add_child(yard)
	var player: Node = load("res://characters/scenes/player.tscn").instantiate()
	player.position = Vector3(0, 0.05, 0)
	root.add_child(player)
	for _frame in 20:
		await process_frame
	for _frame in 60:
		var started := Time.get_ticks_usec()
		await process_frame
		_one_deltas.append(float(Time.get_ticks_usec() - started) / 1000.0)
	_sample("one", player)
	for index in 3:
		var extra: Node3D = load("res://characters/rig/adult/humanoid_adult_1.tscn").instantiate()
		extra.position = Vector3((index + 1) * 1.6, 0, 0)
		root.add_child(extra)
	for _frame in 20:
		await process_frame
	for _frame in 60:
		var started := Time.get_ticks_usec()
		await process_frame
		_group_deltas.append(float(Time.get_ticks_usec() - started) / 1000.0)
	_sample("group4", player)
	print("ADAPTER %s" % RenderingServer.get_video_adapter_name())
	print("VENDOR %s" % RenderingServer.get_video_adapter_vendor())
	print("DRIVER %s" % " | ".join(OS.get_video_adapter_driver_info()))
	print("RENDERER %s" % ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	quit(0)


func _sample(label: String, player: Node) -> void:
	var deltas: Array[float] = _one_deltas if label == "one" else _group_deltas
	var total := 0.0
	for value in deltas:
		total += value
	var average := total / float(deltas.size())
	var rig: Node = player.find_child("HumanoidAdult1", true, false)
	var counts: Dictionary = rig.mesh_counts()
	print("PERF_%s fps %.2f frame_ms %.3f draw_calls %s texture_mem %s video_mem %s player_mesh_visible %s player_mesh_total %s player_materials %s" % [
		label,
		1000.0 / average,
		average,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
		counts["visible"],
		counts["total"],
		rig.material_count(),
	])
