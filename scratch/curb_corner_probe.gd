extends Node

# Where a level's saved curbs are striped red and white (curb_stripes.gdshader reads the corner weight from
# the vertex colour's red, per 3m stripe pair along UV.y), against how the lap bends there. Prints each
# striped run (where along the lap, how far the lap turns over it, its tightest radius) and each real corner
# (a turn of `turn` degrees or more within 60m) with how much of it is striped. Run headless:
#   Godot --headless --path . res://scratch/curb_corner_probe.tscn -- [level=res://levels/X.tscn ...] [turn=35]

const LEVELS := [
	"res://levels/LakesideLevel.tscn",
	"res://levels/MountainLevel.tscn",
	"res://levels/BloombayDunesLevel.tscn",
	"res://levels/PinecrestRidgeLevel.tscn",
	"res://levels/FrostpeakCreekLevel.tscn",
]


func _ready() -> void:
	var levels: Array = []
	var turn_min := 35.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			levels.append(a.substr(6))
		elif a.begins_with("turn="):
			turn_min = float(a.substr(5))
	if levels.is_empty():
		levels = LEVELS
	for path in levels:
		var level: Node = (load(path) as PackedScene).instantiate()
		var tg: Node = level.get_node_or_null("TerrainGenerator")
		var curbs: MeshInstance3D = tg.get_node_or_null("Visual_Curbs") if tg else null
		if curbs == null:
			print("%s: no curbs" % path)
			level.free()
			continue
		add_child(level)
		var curve: Curve3D = tg._get_world_curve()
		var length := curve.get_baked_length()
		var arrays: Array = (curbs.mesh as ArrayMesh).surface_get_arrays(0)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var cols = arrays[Mesh.ARRAY_COLOR]
		var n := int(length) + 1
		var striped := PackedByteArray()
		striped.resize(n)
		var seen := PackedByteArray()
		seen.resize(n)
		# Each side apart (TerrainGenerator stripes the inside through a corner and the outside from its apex on):
		# left of travel is UV.x under the middle.
		var sides := [PackedByteArray(), PackedByteArray()]
		sides[0].resize(n)
		sides[1].resize(n)
		var u_lo := INF
		var u_hi := -INF
		for uv in uvs:
			u_lo = minf(u_lo, uv.x)
			u_hi = maxf(u_hi, uv.x)
		if cols == null or (cols as PackedColorArray).is_empty():
			print("%s: curbs have NO corner weights (all striped)" % path)
		else:
			for vi in range(uvs.size()):
				var i := clampi(int(uvs[vi].y), 0, n - 1)
				seen[i] = 1
				if (cols as PackedColorArray)[vi].r > 0.5:
					striped[i] = 1
					sides[1 if uvs[vi].x > (u_lo + u_hi) * 0.5 else 0][i] = 1
		# Fill the metres between mesh slices from the slice before.
		for i in range(1, n):
			if seen[i] == 0:
				striped[i] = striped[i - 1]
				sides[0][i] = sides[0][i - 1]
				sides[1][i] = sides[1][i - 1]
		var heading := PackedFloat32Array()
		heading.resize(n)
		for i in range(n):
			var a: Vector3 = curve.sample_baked(fposmod(float(i) - 1.0, length))
			var b: Vector3 = curve.sample_baked(fposmod(float(i) + 1.0, length))
			heading[i] = atan2(b.z - a.z, b.x - a.x)
		var count := 0
		for v in striped:
			count += v
		print("%s: lap %.0fm, %.0f%% striped" % [path, length, 100.0 * float(count) / float(n)])
		for sd in range(2):
			var k0 := 0
			while k0 < n:
				if sides[sd][k0] == 0:
					k0 += 1
					continue
				var k1 := k0
				while k1 + 1 < n and sides[sd][k1 + 1] == 1:
					k1 += 1
				# Which way the lap turns round this stretch (+-30m): a right-hander turns the heading up.
				var t := _turn(heading, maxi(k0 - 30, 0), mini(k1 + 30, n - 1))
				var inside: bool = (t > 0.0) == (sd == 1)
				print("  %s kerb %5d-%5dm (%3dm): %s of a %4.0f deg %s" % ["left " if sd == 0 else "right", k0, k1,
					k1 - k0 + 1, "INSIDE " if inside else "outside", rad_to_deg(absf(t)), "right-hander" if t > 0.0 else "left-hander"])
				k0 = k1 + 1
		var i := 0
		while i < n:
			if striped[i] == 0:
				i += 1
				continue
			var j := i
			while j + 1 < n and striped[j + 1] == 1:
				j += 1
			print("  striped %5d-%5dm (%3dm): turns %4.0f deg, tightest radius %s" % [i, j, j - i + 1,
				rad_to_deg(_turn(heading, i, j)), _tightest(heading, i, j)])
			i = j + 1
		# Real corners: a turn of turn_min degrees within 60m.
		var s := 0
		while s < n - 60:
			var t := absf(rad_to_deg(_turn(heading, s, s + 60)))
			if t >= turn_min:
				# Grow to the whole corner: while the next 20m still turn 8 degrees or more.
				var e := s + 60
				while e + 20 < n and absf(rad_to_deg(_turn(heading, e, e + 20))) >= 8.0:
					e += 20
				var cover := 0
				var present := 0
				for k in range(s, e + 1):
					cover += striped[k]
					present += seen[k]
				print("  CORNER %5d-%5dm: turns %4.0f deg, tightest %s, %3.0f%% striped (curbs on %.0f%% of it)" % [s, e,
					rad_to_deg(_turn(heading, s, e)), _tightest(heading, s, e), 100.0 * float(cover) / float(e - s + 1),
					100.0 * float(present) / float(e - s + 1)])
				s = e + 1
			else:
				s += 5
		remove_child(level)
		level.free()
	get_tree().quit()


func _turn(heading: PackedFloat32Array, i: int, j: int) -> float:
	var t := 0.0
	for k in range(i + 1, j + 1):
		t += wrapf(heading[k] - heading[k - 1], -PI, PI)
	return t


## The tightest radius over i..j, from the heading change across 10m.
func _tightest(heading: PackedFloat32Array, i: int, j: int) -> String:
	var best := INF
	for k in range(i, maxi(j - 9, i + 1)):
		var a := absf(_turn(heading, k, mini(k + 10, heading.size() - 1)))
		if a > 1e-4:
			best = minf(best, 10.0 / a)
	return "%.0fm" % best if best < 10000.0 else "straight"
