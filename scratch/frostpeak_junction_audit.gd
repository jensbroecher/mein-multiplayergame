# scratch/frostpeak_junction_audit.gd
# Measures how the two Frostpeak Creek alternative routes meet the main trunk road:
# lateral offset, tangent mismatch, vertical step and min turn radius at each junction.
# Run: godot --headless --path <project> --script scratch/frostpeak_junction_audit.gd
extends SceneTree

const LEVEL := "res://levels/FrostpeakCreekLevel.tscn"
const MAIN_HALF_W := 7.5      # asphalt half width  (road_width 15)
const CURB_HALF_W := 8.5      # curb outer half width (curb_outer_width 17)

var _level: Node3D
var _alt_curves: Array = []
var _main: Curve3D
var _frames := 0

func _initialize() -> void:
	# Root is named "regenerate_*" so Level.gd._ready() bails out and does no race setup.
	var holder := Node3D.new()
	holder.name = "regenerate_junction_audit"
	root.add_child(holder)

	_level = (load(LEVEL) as PackedScene).instantiate()
	holder.add_child(_level)

	_main = (_level.get_node("TrackPath") as Path3D).curve
	print("main track length: %.2f m, %d control points" % [_main.get_baked_length(), _main.point_count])

	var alt_container: Node3D = _level.get_node("AlternativePaths")
	for child in alt_container.get_children():
		_alt_curves.append([child.name, (child as Path3D).curve])


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	for entry in _alt_curves:
		print("\n================ %s ================" % entry[0])
		_audit(entry[1], _main)
	print("\n--- creek / terrain probes along Z at X=0 ---")
	for z in [-400.0, -370.0, -305.0, -175.0, 0.0, 150.0, 175.0, 190.0, 204.0, 220.0, 245.0]:
		print("  z=%7.1f  surface Y=%8.2f" % [z, _ground_y(Vector2(0.0, z))])
	print("\n--- creek centre X along Z (sin(z*0.018)*14) ---")
	for z in [-400.0, -305.0, -175.0, 0.0, 150.0, 175.0, 204.0, 245.0]:
		print("  z=%7.1f  creek_x=%7.2f" % [z, sin(z * 0.018) * 14.0])
	return true


func _audit(alt: Curve3D, mc: Curve3D) -> void:
	var alen: float = alt.get_baked_length()
	print("alt length: %.2f m" % alen)
	print("  control points (index: pos | in-handle | out-handle):")
	for i in range(alt.point_count):
		var p: Vector3 = alt.get_point_position(i)
		var lo: float = alt.get_closest_offset(p)
		print("    %d: %s  lat %+.2f  trunk_off %.1f" % [i, p, _lat(mc, p), lo])
	print("  start %s" % alt.sample_baked(0.0))
	print("  end   %s" % alt.sample_baked(alen))

	_junction_report("entry (start)", alt.sample_baked(0.0), alt, mc)
	_junction_report("exit  (end)  ", alt.sample_baked(alen), alt, mc)

	# Does the ramp dive inside the trunk deck anywhere?
	var worst_lat: float = 1e9
	var worst_at: float = 0.0
	var steps: int = int(alen)
	for i in range(steps + 1):
		var t: float = float(i)
		var lat: float = _lat(mc, alt.sample_baked(t))
		if absf(lat) < absf(worst_lat):
			worst_lat = lat
			worst_at = t
	print("  closest approach to trunk centreline: %+.2f m at %.0fm" % [worst_lat, worst_at])

	# Min turn radius vs deck half width, plus every place it gets uncomfortably tight.
	var win: float = 8.0
	var worst_r: float = 1e9
	var worst_r_at: float = 0.0
	var tight: Array = []
	for i in range(int(alen) + 1):
		var d: float = float(i)
		var a: Vector3 = alt.sample_baked(maxf(0.0, d - win))
		var b: Vector3 = alt.sample_baked(d)
		var c: Vector3 = alt.sample_baked(minf(alen, d + win))
		var v1: Vector3 = b - a
		var v2: Vector3 = c - b
		var area2: float = v1.cross(v2).length()
		if area2 < 1e-6 or v1.length() < 0.01 or v2.length() < 0.01:
			continue
		var r: float = (v1.length() * v2.length() * (v1 + v2).length()) / (2.0 * area2)
		if r < worst_r:
			worst_r = r
			worst_r_at = d
		if r < 30.0:
			tight.append(Vector2(d, r))
	print("  min turn radius: %.2f m at %.0fm (deck inner edge %.2f m)" % [worst_r, worst_r_at, worst_r - CURB_HALF_W])
	# Collapse the tight samples into runs so the report reads as "here, here and here".
	var runs: Array = []
	for t in tight:
		if runs.is_empty() or t.x - runs[runs.size() - 1].y > 4.0:
			runs.append(Vector2(t.x, t.x))
		else:
			runs[runs.size() - 1].y = t.x
	for r in runs:
		var lo: Vector3 = alt.sample_baked(r.x)
		print("    tight R<30m from %.0fm to %.0fm  near %s" % [r.x, r.y, lo])


func _junction_report(label: String, p: Vector3, alt: Curve3D, mc: Curve3D) -> void:
	var moff: float = mc.get_closest_offset(p)
	var mpos: Vector3 = mc.sample_baked(moff)
	var mfwd: Vector3 = _fwd_at(mc, moff)
	var mright := Vector3(-mfwd.z, 0.0, mfwd.x).normalized()
	var lat: float = (p - mpos).dot(mright)

	var alen: float = alt.get_baked_length()
	var ramp_fwd: Vector3 = _fwd_at(alt, 1.0) if label.begins_with("entry") else _fwd_at(alt, alen - 1.0)
	var heading_err: float = rad_to_deg(ramp_fwd.angle_to(mfwd))

	# How far the ramp nose sits off the trunk's extended tangent line.
	var along: float = (p - mpos).dot(mfwd)
	var nose_err: float = ((p - mpos) - mfwd * along).length()

	var deck_y: float = p.y + 0.05
	var ground_y: float = _ground_y(Vector2(p.x, p.z))

	print("  %s" % label)
	print("    trunk offset      : %.1f m  (trunk pos %s)" % [moff, mpos])
	print("    lateral offset    : %+.2f m   (asphalt edge %.1f, curb edge %.1f)" % [lat, MAIN_HALF_W, CURB_HALF_W])
	print("    nose off tangent  : %.2f m" % nose_err)
	print("    heading mismatch  : %.1f deg" % heading_err)
	print("    ramp deck Y       : %.2f   surface below %.2f  -> step %+.2f m" % [deck_y, ground_y, deck_y - ground_y])


func _lat(curve: Curve3D, p: Vector3) -> float:
	var off: float = curve.get_closest_offset(p)
	var c: Vector3 = curve.sample_baked(off)
	var f: Vector3 = _fwd_at(curve, off)
	return (p - c).dot(Vector3(-f.z, 0.0, f.x).normalized())


func _fwd_at(curve: Curve3D, off: float) -> Vector3:
	var length: float = curve.get_baked_length()
	off = clampf(off, 0.0, length)
	var p: Vector3 = curve.sample_baked(off)
	var n: Vector3 = curve.sample_baked(minf(length, off + 1.0))
	var v: Vector3 = n - p
	return v.normalized() if v.length() > 1e-5 else Vector3.FORWARD


func _ground_y(xz: Vector2) -> float:
	var space := root.get_world_3d().direct_space_state
	if space == null:
		return NAN
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 90.0, xz.y), Vector3(xz.x, -60.0, xz.y))
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return NAN
	return (hit["position"] as Vector3).y