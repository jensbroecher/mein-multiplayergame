extends SceneTree
## Yoshino Rapids' koi taking fright (KoiFish.gd): takes the level's GardenKoi out of the saved level on its own, puts a
## stand-in cart (a Node3D in the "player_carts" group) into the water and drives it at `speed` m/s across one fish's
## place, then prints how far each fish near it darted, how frightened it got and how it settled back. Windowed (the
## fish are still on a headless renderer):
##   Godot --path . -s res://scratch/koi_scare_probe.gd -- [level=res://levels/YoshinoRapidsLevel.tscn] [fish=8] [speed=8]

var fish_i := 8
var speed := 8.0
var koi: MultiMeshInstance3D
var cart: Node3D
var t := 0.0
var path_a: Vector3
var path_b: Vector3
var peak := {}
var log_at := 0.0


func _init() -> void:
	var level_path := "res://levels/YoshinoRapidsLevel.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("fish="): fish_i = int(a.substr(5))
		elif a.begins_with("speed="): speed = float(a.substr(6))
	var level: Node = (load(level_path) as PackedScene).instantiate()
	koi = level.find_child("GardenKoi", true, false) as MultiMeshInstance3D
	if koi == null:
		print("no GardenKoi")
		quit()
		return
	var xf := Transform3D.IDENTITY
	var p: Node = koi
	while p != null and p != level:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	koi.get_parent().remove_child(koi)
	koi.owner = null
	level.free()
	koi.transform = xf
	root.add_child(koi)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(koi.centre + Vector3(0, 8, 8), koi.centre)
	cart = Node3D.new()
	cart.add_to_group("player_carts")
	root.add_child(cart)
	var n: int = koi.kinds.size()
	fish_i = clampi(fish_i, 0, n - 1)
	var f_at: Vector3 = koi.transform * koi.pose_at(fish_i, fposmod(Time.get_unix_time_from_system(), 86400.0)).origin
	# Across the fish's water at right angles to its stream (or straight through a pool fish), 0.6m over the water.
	var ax := Vector3(1, 0, 0)
	if koi.kinds[fish_i] == 1:
		ax = (koi.b_pts[fish_i] - koi.a_pts[fish_i])
		ax.y = 0.0
		ax = Vector3(-ax.z, 0, ax.x).normalized()
	path_a = f_at - ax * 12.0 + Vector3(0, 0.6, 0)
	path_b = f_at + ax * 12.0 + Vector3(0, 0.6, 0)
	cart.position = Vector3(0, -500, 0)
	print("%d fish; fish %d (kind %d) at %s; cart from %s to %s at %.0f m/s" % [n, fish_i, koi.kinds[fish_i], str(f_at.snapped(Vector3.ONE * 0.1)), str(path_a.snapped(Vector3.ONE * 0.1)), str(path_b.snapped(Vector3.ONE * 0.1)), speed])
	process_frame.connect(_tick)


func _tick() -> void:
	var dt: float = 1.0 / 60.0
	t += dt
	var run: float = path_a.distance_to(path_b) / speed
	if t > 0.5 and t < 0.5 + run:
		cart.position = path_a.lerp(path_b, (t - 0.5) / run)
	elif t >= 0.5 + run:
		cart.position = Vector3(0, -500, 0)
	var offs: Array = koi.get("_off")
	var fears: PackedFloat32Array = koi.get("_fear")
	for i in range(offs.size()):
		var o: float = (offs[i] as Vector3).length()
		if o > float(peak.get(i, [0.0, 0.0, 0.0])[0]):
			peak[i] = [o, fears[i], t]
	if t >= log_at and offs.size() > fish_i:
		log_at += 0.5
		print("t %.1f  cart %s  fish %d off %.2fm fear %.2f" % [t, str(cart.position.snapped(Vector3.ONE * 0.1)), fish_i, (offs[fish_i] as Vector3).length(), fears[fish_i]])
	if t > 0.5 + run + 8.0:
		for i in peak:
			if float(peak[i][0]) > 0.05:
				print("fish %d darted %.2fm (fear %.2f, at %.1fs), now %.2fm off" % [i, peak[i][0], peak[i][1], peak[i][2], (offs[i] as Vector3).length()])
		quit()
