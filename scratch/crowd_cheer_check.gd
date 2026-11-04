extends Node
# Lists, per stage, what StageAmbience.roar() plays: the stadium roar (2D, stages with a stadium crowd layer) and
# the grandstands' cheers (3D, from each "Grandstand" node's middle), and calls it once to catch errors. Headless:
#   Godot --headless --path . res://scratch/crowd_cheer_check.tscn [-- res://levels/X.tscn ...]
# The node's name holds "regenerate" so Level.gd skips its race setup.


func _ready() -> void:
	var levels: Array = OS.get_cmdline_user_args()
	if levels.is_empty():
		levels = ["res://levels/LakesideLevel.tscn", "res://levels/BloombayDunesLevel.tscn", "res://levels/MinaLevel.tscn",
			"res://levels/NyotaStadiumLevel.tscn", "res://levels/MtaaNightsLevel.tscn"]
	for l in levels:
		var level: Node3D = load(l).instantiate()
		add_child(level)
		await get_tree().process_frame
		var amb: Node = level.get_node_or_null("StageAmbience")
		if amb == null:
			amb = load("res://StageAmbience.gd").new()
			amb.setup(l)
			level.add_child(amb)
			await get_tree().process_frame
		amb.roar()
		var spots: Array = amb.cheer_spots().map(func(p: Vector3) -> String: return "(%.0f, %.0f, %.0f)" % [p.x, p.y, p.z])
		print("CHEER %s: stadium roar %s, grandstands %s" % [String(l).get_file(), "yes" if amb.get("_roar") != null else "no", ", ".join(spots) if not spots.is_empty() else "none"])
		level.queue_free()
		await get_tree().process_frame
	get_tree().quit()
