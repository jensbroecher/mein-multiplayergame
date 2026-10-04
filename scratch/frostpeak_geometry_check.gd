# scratch/frostpeak_geometry_check.gd
# Dumps every bridge piece in world space and flags the ones that do not belong: anything reaching
# past the ends of the deck, floating clear of it, or absurdly oversized. This is how the "messed
# up geometry" gets pinned to specific nodes instead of guessed at from a screenshot.
extends SceneTree

var _level: Node3D
var _frames := 0

func _initialize() -> void:
	var holder := Node3D.new()
	holder.name = "regenerate_geometry_check"
	root.add_child(holder)
	_level = (load("res://levels/FrostpeakCreekLevel.tscn") as PackedScene).instantiate()
	holder.add_child(_level)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false

	for name in ["GladeTimberBridge", "AlpineTimberBridge"]:
		var b: Node3D = _level.get_node(name)
		var deck := b.get_node_or_null("BridgeDeck")
		var box: BoxShape3D = null
		for c in deck.get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
				box = (c as CollisionShape3D).shape as BoxShape3D
		var half: float = box.size.x * 0.5
		var width: float = box.size.z
		var deck_top: float = b.position.y + box.size.y * 0.5
		print("\n=== %s ===" % name)
		print("  deck %.1f x %.1f, half-length %.2f, top Y=%.2f" % [box.size.x, width, half, deck_top])

		var problems := 0
		for n in b.get_children():
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var local_x: float = mi.position.x
			var aabb: AABB = mi.mesh.get_aabb()
			# World extent of this piece along the bridge axis.
			var x0: float = local_x + aabb.position.x
			var x1: float = local_x + aabb.position.x + aabb.size.x
			var z0: float = mi.position.z + aabb.position.z
			var z1: float = mi.position.z + aabb.position.z + aabb.size.z
			var y0: float = b.position.y + mi.position.y + aabb.position.y
			var y1: float = b.position.y + mi.position.y + aabb.position.y + aabb.size.y
			var flags: Array = []
			if x0 < -half - 0.6 or x1 > half + 0.6:
				flags.append("PAST DECK END")
			if y1 > deck_top + 0.05 and n.name.begins_with("SnowDrift"):
				flags.append("drift above deck")
			if y0 > deck_top - 0.1 and not n.name.begins_with("Post") \
					and not n.name.begins_with("Baluster") and not n.name.begins_with("Snow") \
					and not n.name.begins_with("TopRail") and not n.name.begins_with("MidRail") \
					and not n.name.begins_with("XBrace") and not n.name.begins_with("WheelGuard"):
				flags.append("not tied to the deck")
			if flags.is_empty():
				continue
			problems += 1
			print("  %-24s x[%7.2f,%7.2f] z[%7.2f,%7.2f] y[%7.2f,%7.2f]  %s" % [
				n.name, x0, x1, z0, z1, y0, y1, ", ".join(flags)])
		print("  flagged: %d" % problems)
	return true
