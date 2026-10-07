# scratch/frostpeak_bridge_audit.gd
# Enumerates every collision shape under the two timber bridges and sweeps horizontal rays
# through the channel beneath each deck to find invisible walls blocking the waterway.
extends SceneTree

var _level: Node3D
var _frames := 0

func _initialize() -> void:
	var holder := Node3D.new()
	holder.name = "bridge_audit"
	root.add_child(holder)
	_level = (load("res://levels/FrostpeakCreekLevel.tscn") as PackedScene).instantiate()
	holder.add_child(_level)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false

	for bname in ["GladeTimberBridge", "AlpineTimberBridge"]:
		var bridge := _level.get_node_or_null(bname) as Node3D
		if bridge == null:
			print("MISSING bridge %s" % bname)
			continue
		print("\n=== %s at %s yaw %.1f ===" % [bname, bridge.position, bridge.rotation_degrees.y])
		var bodies: Array = []
		_collect(bridge, bodies)
		for b in bodies:
			for c in b.get_children():
				if c is CollisionShape3D:
					var sh := (c as CollisionShape3D).shape
					if sh is BoxShape3D:
						var box := sh as BoxShape3D
						var cy: float = c.global_position.y - bridge.global_position.y
						print("  %-28s size %5.1f x %5.1f x %5.1f  local y %6.2f..%6.2f" % [
							b.name, box.size.x, box.size.y, box.size.z,
							cy - box.size.y * 0.5, cy + box.size.y * 0.5])

		# Sweep the channel: rays along the bridge's local Z (creek flow direction),
		# crossing the full local X range at heights from water up to the deck underside.
		var yaw := deg_to_rad(bridge.rotation_degrees.y)
		var axis_x := Vector3(cos(yaw), 0, -sin(yaw))
		var axis_z := Vector3(sin(yaw), 0, cos(yaw))
		var bc := bridge.position
		var half: float = 0.0
		var deck_w: float = 0.0
		var deck_body := bridge.get_node_or_null("BridgeDeck")
		if deck_body:
			for c in deck_body.get_children():
				if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
					var bm := (c as MeshInstance3D).mesh as BoxMesh
					half = bm.size.x * 0.5
					deck_w = bm.size.z
		var deck_under: float = bc.y - 0.32
		print("  deck span %.1f half, width %.1f, underside y=%.2f" % [half, deck_w, deck_under])

		var lx: float = -half
		while lx <= half:
			var base: Vector3 = bc + axis_x * lx
			var from: Vector3 = base + axis_z * (deck_w * 0.5 + 14.0)
			var to: Vector3 = base - axis_z * (deck_w * 0.5 + 14.0)
			for h in [0.6, 1.6, 2.6]:
				var y: float = bc.y - 4.0 + h
				var q := PhysicsRayQueryParameters3D.create(
					Vector3(from.x, y, from.z), Vector3(to.x, y, to.z))
				q.collide_with_areas = false
				var hit := root.get_world_3d().direct_space_state.intersect_ray(q)
				if hit.is_empty():
					continue
				var hp: Vector3 = hit["position"]
				var name := _cname(hit)
				if name in ["Unified_World_Collision", "TerrainCollision"]:
					continue
				var along: float = (hp - base).dot(axis_z)
				print("    lx=%6.1f y=%5.1f  HIT %-30s at along %6.2f  (local z in %5.1f..%5.1f)" % [
					lx, y, name, along, -deck_w * 0.5, deck_w * 0.5])
			lx += 0.5

		# Cross-channel sweep: rays along local X (across the creek) at water heights,
		# to catch any wall that cuts the channel (road embankments, stray collision).
		var excl: Array = []
		_collect_rids(bridge, excl)
		print("  -- cross-channel sweeps (bridge collision excluded) --")
		for lz in [-5.0, -2.5, 0.0, 2.5, 5.0]:
			for h in [1.0, 2.0]:
				var y: float = bc.y - 4.0 + h
				var last_name := ""
				var lx2: float = -half - 16.0
				while lx2 < half + 16.0:
					var seg: float = 1.0
					var a: Vector3 = bc + axis_z * lz + axis_x * lx2 + Vector3(0, y - bc.y, 0)
					var b: Vector3 = a + axis_x * seg
					var q := PhysicsRayQueryParameters3D.create(a, b)
					q.collide_with_areas = false
					q.exclude = excl
					var hit := root.get_world_3d().direct_space_state.intersect_ray(q)
					var nm := "-"
					if not hit.is_empty():
						nm = _cname(hit)
					if nm != last_name:
						print("    lz=%5.1f y=%4.1f  lx %7.2f.. -> %s" % [lz, y, lx2, nm])
						last_name = nm
					lx2 += seg

		# Bed contact: ray down at each bent's pile positions with bridge collision excluded.
		print("  -- pile bed contact (bridge collision excluded) --")
		var bents: Array = []
		_named(bridge, "TrestleBent", bents)
		for b2 in bents:
			var bx: float = b2.position.x
			for pz in [-2.5, 0.0, 2.5]:
				var sp: Vector3 = bc + axis_x * bx + axis_z * pz
				var q := PhysicsRayQueryParameters3D.create(
					Vector3(sp.x, bc.y, sp.z), Vector3(sp.x, -60.0, sp.z))
				q.collide_with_areas = false
				q.exclude = excl
				var hit := root.get_world_3d().direct_space_state.intersect_ray(q)
				if hit.is_empty():
					print("    bent lx=%6.1f pz=%5.1f  MISS (no bed!)" % [bx, pz])
				else:
					print("    bent lx=%6.1f pz=%5.1f  bed %7.2f  pile_bot(local) -8.70 -> global %7.2f  %s" % [
						bx, pz, hit["position"].y, bc.y - 8.7, _cname(hit)])
	return true

func _collect(n: Node, out: Array) -> void:
	if n is StaticBody3D or n is RigidBody3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)

func _collect_rids(n: Node, out: Array) -> void:
	if n is CollisionObject3D:
		out.append((n as CollisionObject3D).get_rid())
	for c in n.get_children():
		_collect_rids(c, out)

func _named(n: Node, prefix: String, out: Array) -> void:
	if (n.name as String).begins_with(prefix):
		out.append(n)
	for c in n.get_children():
		_named(c, prefix, out)

func _cname(hit: Dictionary) -> String:
	var o = hit["collider"]
	return o.name if o else "?"
