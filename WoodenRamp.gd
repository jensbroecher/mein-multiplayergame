@tool
class_name WoodenRamp
extends StaticBody3D
## A wooden jump ramp to place by hand on any level (WoodenRamp.tscn), like the boost pads. Its look
## and collision are built here from the exports, as internal children rebuilt on load, so a level file
## only stores the ramp's transform and shape: planks laid across a run that curves up from flush with
## the ground, on stringers, boarded sides on posts, a boarded back for a kicker, the toe and lip planks
## painted. `table_length` gives it a flat top after the lip, `tail_length` a run back down (a roller).
##
## The origin is the middle of the toe, on the ground; the ramp rises toward -z (the way a boost pad's
## chevrons point), so -z faces the way the carts come.
##
## At runtime (`settle_on_track`, on by default) the ramp drops onto whatever is under it once the
## level's collision exists and tilts with it; `face_lap` also turns it along the nearest lap path. The
## Snap To Ground button does the drop in the editor.
##
## The body is in the "ramps" group with `surface` wood, so PlayerCart drives on it as track whatever
## its name, and the AI doesn't steer round it: make it as wide as the road, or bots catch its sides.

const PropKit = preload("res://PropKit.gd")
const VenueKit = preload("res://VenueKit.gd")
const WOOD_SHADER := preload("res://hut_wood.gdshader")

const PLANK := 0.24          # a deck plank's width along the run
const PLANK_GAP := 0.012
const PLANK_T := 0.05
const STRINGER_W := 0.08     # the timbers under the planks' ends
const STRINGER_D := 0.18
const POST := 0.1
const POST_EVERY := 1.3
const SINK := 0.05           # how far the visuals reach under the ground
const FOOT := 0.25           # how far the collision reaches under it
const SETTLE_SINK := 0.01    # the toe sits this far under the surface, so no edge shows
## The planks never come lower than this over the ground: where the deck runs nearer (the toe, a roller's
## foot) they lie flat on the road instead. A plank top grazing the road z-fought with it all across the
## ramp (the mobile renderer can't part faces a centimetre apart). The collision keeps the true profile.
const PLANK_MIN_Y := PLANK_T

static var _materials := {}
static var _built := {}      # shape key -> [mesh, collision shape]

@export_group("Shape")
## Horizontal run from the toe to the lip (m).
@export_range(1.0, 40.0, 0.1) var length: float = 7.0:
	set(v):
		length = v
		_rebuild()
## The lip's height over the ground (m).
@export_range(0.2, 12.0, 0.05) var height: float = 1.4:
	set(v):
		height = v
		_rebuild()
## Across the run (m). The road is 15m between the curbs.
@export_range(1.0, 30.0, 0.1) var width: float = 6.0:
	set(v):
		width = v
		_rebuild()
## 0: a straight wedge. 1: a transition that leaves the ground flat and kicks up twice as steep at the
## lip. The lip's slope is height / length * (1 + curve).
@export_range(0.0, 1.0, 0.05) var curve: float = 0.6:
	set(v):
		curve = v
		_rebuild()
## A flat top after the lip (m): a table-top.
@export_range(0.0, 30.0, 0.1) var table_length: float = 0.0:
	set(v):
		table_length = v
		_rebuild()
## A run back down to the ground after the top (m), the rise mirrored: a roller. 0 cuts the ramp off
## square at the lip (a kicker).
@export_range(0.0, 40.0, 0.1) var tail_length: float = 0.0:
	set(v):
		tail_length = v
		_rebuild()

@export_group("Look")
@export var wood_color: Color = Color(0.66, 0.52, 0.36):
	set(v):
		wood_color = v
		_rebuild()
## The toe and lip planks' paint.
@export var trim_color: Color = Color(0.96, 0.46, 0.10):
	set(v):
		trim_color = v
		_rebuild()

@export_group("Editor Tools")
## Drop this ramp onto the surface under it (editor). Prefer the button; the checkbox is a backup.
@export_tool_button("Snap To Ground") var snap_to_ground_btn: Callable = _on_snap_button_pressed
@export var snap_to_ground: bool = false:
	get:
		return false
	set(val):
		if val:
			_on_snap_button_pressed()
		notify_property_list_changed()
## At runtime, once the level's collision exists: drop onto the surface under the ramp and tilt with it.
@export var settle_on_track: bool = true
## At runtime: turn the ramp about its toe so it runs along the nearest lap path (within 30m).
@export var face_lap: bool = true

var _visual: MeshInstance3D
var _shape: CollisionShape3D


func _enter_tree() -> void:
	add_to_group("ramps")


func _ready() -> void:
	set_meta(&"surface", "wood")
	_rebuild()
	if Engine.is_editor_hint():
		return
	if settle_on_track or face_lap:
		_settle()


# ======================================================================================
#  The profile
# ======================================================================================

## The deck's height `d` metres along the run from the toe.
func deck_y(d: float) -> float:
	if d <= length:
		var u := clampf(d / length, 0.0, 1.0)
		return height * ((1.0 - curve) * u + curve * u * u)
	if d <= length + table_length or tail_length <= 0.0:
		return height
	var w := 1.0 - clampf((d - length - table_length) / tail_length, 0.0, 1.0)
	return height * ((1.0 - curve) * w + curve * w * w)


func run() -> float:
	return length + table_length + tail_length


## The jump's lip (where the rise ends) for scratch/nyota_jump_test's TrackPath "jump_lips" meta:
## {name, lip (world), dir (world, along the deck there)}.
func lip_info() -> Dictionary:
	var slope := height / length * (1.0 + curve)
	var dir := global_transform.basis.orthonormalized() * Vector3(0.0, slope, -1.0).normalized()
	return {"name": String(name), "lip": global_transform * Vector3(0.0, height, -length), "dir": dir}


## The deck's top as points (d, y), split at the lip and the table's end so a plank meets each, and
## for each plank between two points what it is: 0 plain, 1 painted.
func _deck_points() -> Array:
	var spans: Array = [[0.0, length]]
	if table_length > 0.0:
		spans.append([length, length + table_length])
	if tail_length > 0.0:
		spans.append([length + table_length, run()])
	var pts: Array[Vector2] = [Vector2(0.0, 0.0)]
	var paint: Array[int] = []
	for si in range(spans.size()):
		var d0: float = spans[si][0]
		var d1: float = spans[si][1]
		# Equal planks by arc length: the span's arc from a fine walk along it.
		var fine: Array[Vector2] = []
		var arc: Array[float] = [0.0]
		var n_fine := maxi(8, ceili((d1 - d0) / 0.05))
		for k in range(n_fine + 1):
			var d := lerpf(d0, d1, float(k) / n_fine)
			fine.append(Vector2(d, deck_y(d)))
			if k > 0:
				arc.append(arc[k - 1] + fine[k].distance_to(fine[k - 1]))
		var total: float = arc[n_fine]
		var n := maxi(1, roundi(total / PLANK))
		var j := 0
		for p in range(1, n + 1):
			var target := total * p / n
			while j < n_fine - 1 and arc[j + 1] < target:
				j += 1
			var t := clampf((target - arc[j]) / maxf(arc[j + 1] - arc[j], 1e-6), 0.0, 1.0)
			pts.append(fine[j].lerp(fine[j + 1], t))
			# The toe's plank, the last before the lip (or the table's edge), and the tail's foot.
			var first := si == 0 and p == 1
			var edge := p == n and ((si == 0 and table_length <= 0.0) or (si == 1 and table_length > 0.0))
			var foot := si == spans.size() - 1 and tail_length > 0.0 and p == n
			paint.append(1 if first or edge or foot else 0)
	return [pts, paint]


# ======================================================================================
#  Building
# ======================================================================================

func _shape_key() -> String:
	return "%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%s|%s" % [length, height, width, curve, table_length, tail_length,
			wood_color.to_html(), trim_color.to_html()]


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var key := _shape_key()
	if not _built.has(key):
		_built[key] = [_build_mesh(), _build_shape()]
	if _visual == null:
		_visual = MeshInstance3D.new()
		_visual.name = "RampVisual"
		add_child(_visual, false, Node.INTERNAL_MODE_BACK)
		_shape = CollisionShape3D.new()
		_shape.name = "RampShape"
		add_child(_shape, false, Node.INTERNAL_MODE_BACK)
	_visual.mesh = _built[key][0]
	_shape.shape = _built[key][1]


## Local point `d` along the run, `y` up, `x` across.
static func _p(d: float, y: float, x := 0.0) -> Vector3:
	return Vector3(x, y, -d)


func _build_mesh() -> ArrayMesh:
	var kit := PropKit.new()
	kit.material_for = _material
	var venue := VenueKit.new(kit)
	var mk := {}
	var deck: Array = _deck_points()
	var pts: Array[Vector2] = deck[0]
	var paint: Array[int] = deck[1]
	for i in range(pts.size()):
		pts[i].y = maxf(pts[i].y, PLANK_MIN_Y)
	var hw := width * 0.5
	# Planks across the run, each its own timber (grain across) on the chord between two deck points.
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var t := (b - a).normalized()
		var nrm := Vector2(-t.y, t.x)
		var mid := (a + b) * 0.5 - nrm * (PLANK_T * 0.5)
		var along := _p(t.x, t.y) - _p(0.0, 0.0)
		var w := maxf(a.distance_to(b) - PLANK_GAP, 0.02)
		var tone := 0.88 + 0.24 * fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var col := trim_color if paint[i] == 1 else Color(wood_color.r * tone, wood_color.g * tone, wood_color.b * tone)
		venue.timber(mk, _p(mid.x, mid.y, -hw), _p(mid.x, mid.y, hw), w, PLANK_T, col, along, "painted" if paint[i] == 1 else "timber")
	# Stringers under the planks' ends, following the deck; boarded sides below them, posts outside.
	var frame_col := wood_color.darkened(0.22)
	var side_col := wood_color.darkened(0.1)
	var last := pts.size() - 1
	for side in [-1.0, 1.0]:
		# 1cm in from the planks' ends, or its face and theirs shared a plane along the side.
		var x: float = side * (hw - STRINGER_W * 0.5 - 0.01)
		for i in range(last):
			var a: Vector2 = pts[i] - Vector2(0.0, PLANK_T + STRINGER_D * 0.5)
			var b: Vector2 = pts[i + 1] - Vector2(0.0, PLANK_T + STRINGER_D * 0.5)
			if pts[i + 1].y < PLANK_T + STRINGER_D:
				continue
			venue.timber(mk, _p(a.x, a.y, x), _p(b.x, b.y, x), STRINGER_W, STRINGER_D, frame_col, Vector3.RIGHT)
			# The side's boards: from under the ground up to the stringer, upright boards along the run.
			var ya := pts[i].y - PLANK_T - STRINGER_D
			var yb := pts[i + 1].y - PLANK_T - STRINGER_D
			if ya <= 0.0 and yb <= 0.0:
				continue
			var out := Vector3(side, 0.0, 0.0)
			var q := [_p(pts[i].x, -SINK, x), _p(pts[i + 1].x, -SINK, x), _p(pts[i + 1].x, maxf(yb, 0.0), x), _p(pts[i].x, maxf(ya, 0.0), x)]
			kit.quad(mk, "battens", q, out, side_col, [Vector2(pts[i].x, -SINK), Vector2(pts[i + 1].x, -SINK),
					Vector2(pts[i + 1].x, maxf(yb, 0.0)), Vector2(pts[i].x, maxf(ya, 0.0))])
		# A sill along the ground and posts up to the stringer, where there is room for them.
		var xo: float = side * (hw - STRINGER_W * 0.5 + POST * 0.5 + 0.005)
		var d_from := _first_d_over(STRINGER_D + PLANK_T + 0.2)
		if d_from < run():
			var d_to := run() if tail_length <= 0.0 else _last_d_over(STRINGER_D + PLANK_T + 0.2)
			venue.timber(mk, _p(d_from, POST * 0.5 - SINK * 0.5, xo), _p(d_to, POST * 0.5 - SINK * 0.5, xo), POST + SINK, POST, frame_col, Vector3.UP)
			var n_posts := maxi(1, ceili((d_to - d_from) / POST_EVERY))
			for k in range(n_posts + 1):
				var d := lerpf(d_from, d_to, float(k) / n_posts)
				d = clampf(d, d_from + POST * 0.5, d_to - POST * 0.5)
				var top := deck_y(d) - PLANK_T - 0.01
				venue.timber(mk, _p(d, POST, xo), _p(d, top, xo), POST, POST, frame_col, Vector3.BACK)
	# A kicker's back: boards from the ground up to a header under the last plank. The header stands 1.5cm
	# proud of the boards and the stringers' ends, and the boards stop under it: flush, their faces shared a
	# plane along the top of the back and flickered.
	if tail_length <= 0.0:
		var d := run()
		var y := height - PLANK_T
		var yb := y - STRINGER_D
		kit.quad(mk, "battens", [_p(d, -SINK, -hw), _p(d, -SINK, hw), _p(d, yb, hw), _p(d, yb, -hw)], Vector3.FORWARD, side_col,
				[Vector2(-hw, -SINK), Vector2(hw, -SINK), Vector2(hw, yb), Vector2(-hw, yb)])
		var zh := d - STRINGER_W * 0.5 + 0.015
		venue.timber(mk, _p(zh, y - STRINGER_D * 0.5, -hw), _p(zh, y - STRINGER_D * 0.5, hw), STRINGER_W, STRINGER_D, frame_col, Vector3.FORWARD)
		for sx in [-1.0, 1.0]:
			var xc: float = sx * (hw - POST * 0.5)
			venue.timber(mk, _p(d - POST * 0.5 - 0.005, -SINK, xc), _p(d - POST * 0.5 - 0.005, y - STRINGER_D, xc), POST, POST, frame_col, Vector3.BACK)
	return kit.commit(mk)


## The first and last place along the run where the deck stands `h` over the ground.
func _first_d_over(h: float) -> float:
	var d := 0.0
	while d < run() and deck_y(d) < h:
		d += 0.05
	return d


func _last_d_over(h: float) -> float:
	var d := run()
	while d > 0.0 and deck_y(d) < h:
		d -= 0.05
	return d


## The deck's top (the planks' tops, which the chords are), the sides at the planks' ends and the back,
## all reaching FOOT under the ground.
func _build_shape() -> ConcavePolygonShape3D:
	var pts: Array[Vector2] = _deck_points()[0]
	var hw := width * 0.5
	var faces := PackedVector3Array()
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		faces.append_array([a, b, c, a, c, d])
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		quad.call(_p(a.x, a.y, -hw), _p(a.x, a.y, hw), _p(b.x, b.y, hw), _p(b.x, b.y, -hw))
		for sx in [-hw, hw]:
			quad.call(_p(a.x, -FOOT, sx), _p(b.x, -FOOT, sx), _p(b.x, b.y, sx), _p(a.x, a.y, sx))
	if tail_length <= 0.0:
		var d := run()
		quad.call(_p(d, -FOOT, -hw), _p(d, -FOOT, hw), _p(d, height, hw), _p(d, height, -hw))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	return shape


static func _material(key: String) -> Material:
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = WOOD_SHADER
		# hut_wood.gdshader's styles: 2 sawn timber (grain along UV.y), 0 upright boards, 3 painted boards.
		m.set_shader_parameter("style", {"timber": 2, "battens": 0, "painted": 3}.get(key, 2))
		m.set_shader_parameter("weathering", 0.45)
		_materials[key] = m
	return _materials[key]


# ======================================================================================
#  Dropping onto the ground
# ======================================================================================

## Lie on the surface under the ramp once the level's collision exists, tilted with it, and (`face_lap`)
## along the lap. Boost pads and checkpoint gates settle the same way.
func _settle() -> void:
	await get_tree().physics_frame
	var level: Node = get_parent()
	while level and not level.is_in_group("level"):
		level = level.get_parent()
	if level and level.has_method("wait_for_collisions"):
		await level.wait_for_collisions()
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var toe := global_position
	var fwd := -global_transform.basis.z
	if face_lap:
		var tangent := _lap_tangent(toe)
		if tangent.length_squared() > 1e-6:
			fwd = tangent
	var up := global_transform.basis.y.normalized()
	if settle_on_track:
		var g := ground_frame(func(at: Vector3) -> Dictionary: return _ground_under(space, at), toe, fwd)
		if not g.is_empty():
			toe = g["origin"]
			up = g["up"]
	fwd -= up * fwd.dot(up)
	if fwd.length_squared() < 1e-6:
		return
	global_transform = Transform3D(Basis.looking_at(fwd.normalized(), up).scaled(global_transform.basis.get_scale()), toe)


## Where the ramp lies on the ground under it, heading `fwd` from its toe at `toe`: {origin, up}, from
## rays (`ground` takes a world point, returns its {position, normal} or empty) at the toe's corners and
## the far end's; empty if there is nothing under the toe. Up is the plane through the corners (the
## ground's own normal under the toe if a corner missed; no steeper than 30 degrees), the origin the
## toe's hit, SETTLE_SINK under.
func ground_frame(ground: Callable, toe: Vector3, fwd: Vector3) -> Dictionary:
	fwd.y = 0.0
	if fwd.length_squared() < 1e-6:
		return {}
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var mid: Dictionary = ground.call(toe)
	if mid.is_empty():
		return {}
	var base: Vector3 = mid["position"]
	var up: Vector3 = mid["normal"]
	var corners: Array = []
	var reach := minf(width * 0.4, 5.0)
	for o in [[0.0, -reach], [0.0, reach], [run(), -reach], [run(), reach]]:
		var h: Dictionary = ground.call(toe + fwd * float(o[0]) + right * float(o[1]))
		if h.is_empty() or absf((h["position"] as Vector3).y - base.y) > 0.5 + run() * 0.3:
			corners.clear()
			break
		corners.append(h["position"])
	if corners.size() == 4:
		var along: Vector3 = (corners[2] + corners[3]) - (corners[0] + corners[1])
		var across: Vector3 = (corners[1] + corners[3]) - (corners[0] + corners[2])
		var n := across.cross(along).normalized()
		if n.y < 0.0:
			n = -n
		if n.length() > 0.5:
			up = n
	if up.y < cos(deg_to_rad(30.0)):
		up = Vector3.UP
	return {"origin": base - up * SETTLE_SINK, "up": up}


## The ground straight under `at` (not the ramp itself): its hit, or empty if nothing level is there.
func _ground_under(space: PhysicsDirectSpaceState3D, at: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at - Vector3.UP * 8.0, 1)
	q.exclude = [get_rid()]
	q.hit_back_faces = false
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.6:
		return {}
	return hit


## The way the lap runs at `at`: along the nearest lap path within 30m (BoostPad's), or zero.
func _lap_tangent(at: Vector3) -> Vector3:
	var level: Node = get_tree().get_first_node_in_group("level")
	if level == null:
		return Vector3.ZERO
	var candidates: Array = [level.get("track_path")]
	if level.get("alternative_paths") is Array:
		candidates.append_array(level.get("alternative_paths"))
	candidates.append_array(level.get_children())
	var best := 30.0
	var tangent := Vector3.ZERO
	var seen: Array = []
	for c in candidates:
		if not (c is Path3D) or seen.has(c) or not ("Path" in str(c.name)):
			continue
		seen.append(c)
		var path := c as Path3D
		if path.curve == null or path.curve.get_baked_length() <= 20.0:
			continue
		var off := path.curve.get_closest_offset(path.to_local(at))
		var d := path.to_global(path.curve.sample_baked(off)).distance_to(at)
		if d >= best:
			continue
		var a := path.to_global(path.curve.sample_baked(maxf(off - 2.0, 0.0)))
		var b := path.to_global(path.curve.sample_baked(minf(off + 2.0, path.curve.get_baked_length())))
		if a.distance_squared_to(b) < 0.01:
			continue
		best = d
		tangent = b - a
	return tangent


# ======================================================================================
#  Editor: Snap To Ground
# ======================================================================================

func _on_snap_button_pressed() -> void:
	if not is_inside_tree():
		return
	var fwd := -global_transform.basis.z
	var g := ground_frame(_editor_ground, global_position, fwd)
	if g.is_empty():
		push_warning("[WoodenRamp] Nothing under '%s' to snap to. Open the whole level, not WoodenRamp.tscn alone." % name)
		return
	var up: Vector3 = g["up"]
	fwd -= up * fwd.dot(up)
	global_transform = Transform3D(Basis.looking_at(fwd.normalized(), up).scaled(global_transform.basis.get_scale()), g["origin"])
	print("[WoodenRamp] Snapped '%s' to %s" % [name, global_position])


## The first surface under `at` in the editor (from 3m over it): the level's saved colliders, else the
## meshes there (not this ramp's own, nor water or grass).
func _editor_ground(at: Vector3) -> Dictionary:
	var from := at + Vector3.UP * 3.0
	var to := at - Vector3.UP * 60.0
	var world := get_world_3d()
	if world:
		if Engine.is_editor_hint() and world.space.is_valid():
			PhysicsServer3D.space_set_active(world.space, true)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [get_rid()]
		var hit := world.direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			return hit
	var root: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
	if root == null:
		return {}
	var best := {}
	var best_y := -INF
	var dir := Vector3.DOWN
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or is_ancestor_of(mi) or not mi.is_visible_in_tree():
			continue
		var nm := String(mi.name).to_lower()
		if nm.contains("water") or nm.contains("grass") or nm.contains("meadow") or nm.contains("sky"):
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		if at.x < box.position.x or at.x > box.end.x or at.z < box.position.z or at.z > box.end.z or box.position.y > from.y:
			continue
		var faces := mi.mesh.get_faces()
		if faces.size() > 1200000:
			continue
		var xf := mi.global_transform
		for i in range(0, faces.size() - 2, 3):
			var a: Vector3 = xf * faces[i]
			var b: Vector3 = xf * faces[i + 1]
			var c: Vector3 = xf * faces[i + 2]
			var p = Geometry3D.ray_intersects_triangle(from, dir, a, b, c)
			if p == null or (p as Vector3).y <= best_y or (p as Vector3).y < to.y:
				continue
			var n := (b - a).cross(c - a).normalized()
			best_y = (p as Vector3).y
			best = {"position": p, "normal": n if n.y >= 0.0 else -n}
	return best
