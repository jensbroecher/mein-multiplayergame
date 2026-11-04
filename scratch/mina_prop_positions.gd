extends SceneTree
## Lists where Mina del Viento's signs, gate, guard house, trucks, drills and light towers stand in the saved level
## (position, yaw), to aim cameras and probes at them.
##   Godot --headless --path . -s res://scratch/mina_prop_positions.gd -- [match=Sign]

func _init() -> void:
	var m := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("match="):
			m = a.substr(6)
	var level: Node = (load("res://levels/MinaLevel.tscn") as PackedScene).instantiate()
	for n in level.find_children("*", "Node3D", true, false):
		var nm := String(n.name)
		if not (nm.begins_with("Sign_") or nm in ["Gate", "GuardHouse", "PlateauJump"] or nm.begins_with("PitTruck") \
				or nm.begins_with("DrillRig") or nm.begins_with("LightTower")):
			continue
		if m != "" and not nm.contains(m):
			continue
		var t: Transform3D = (n as Node3D).transform
		var p: Node = n.get_parent()
		while p != level and p is Node3D:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		print("%-14s %s yaw %.0f" % [nm, str(t.origin), rad_to_deg(t.basis.get_euler().y)])
	level.free()
	quit(0)
