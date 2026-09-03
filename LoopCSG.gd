@tool
class_name LoopCSG
extends Node3D

## Large driveable CSG stunt looping.
## A self-contained, freely moveable 3D object for level placement.
##
## Features:
## - Full 360-degree vertical stunt loop with helical lateral offset
## - Extruded CSG track with driveable asphalt and tall safety curbs
## - Integrated launch boost pads on entry ramp and run-out boost on exit
## - CSG support pylons grounding the high arch
## - Instant editor preview and freely moveable/rotatable via editor transform gizmo

@export_group("Dimensions")
## Radius of the loop (apex height will be 2 * loop_radius)
@export_range(8.0, 40.0, 0.5) var loop_radius: float = 16.0:
	set(v):
		loop_radius = maxf(v, 6.0)
		_maybe_rebuild()

## Width of the drivable road inside the loop
@export_range(6.0, 25.0, 0.5) var track_width: float = 11.0:
	set(v):
		track_width = maxf(v, 4.0)
		_maybe_rebuild()

## Height of the outer containment walls/curbs
@export_range(0.5, 5.0, 0.1) var wall_height: float = 2.6:
	set(v):
		wall_height = maxf(v, 0.3)
		_maybe_rebuild()

## Thickness of the outer containment walls
@export_range(0.1, 3.0, 0.05) var wall_thickness: float = 0.8:
	set(v):
		wall_thickness = maxf(v, 0.1)
		_maybe_rebuild()

## Road bed slab thickness
@export_range(0.2, 3.0, 0.05) var road_thickness: float = 1.6:
	set(v):
		road_thickness = maxf(v, 0.15)
		_maybe_rebuild()

## Lateral separation between entry and exit lanes to prevent collisions
@export_range(2.0, 20.0, 0.5) var spiral_offset: float = 6.5:
	set(v):
		spiral_offset = maxf(v, 1.0)
		_maybe_rebuild()

## Length of the ground approach and exit ramps
@export_range(10.0, 60.0, 1.0) var approach_length: float = 24.0:
	set(v):
		approach_length = maxf(v, 6.0)
		_maybe_rebuild()

## Height of the lead-in and lead-out incline ramp
@export_range(0.0, 3.0, 0.05) var ramp_height: float = 0.65:
	set(v):
		ramp_height = maxf(v, 0.0)
		_maybe_rebuild()

@export_group("Features")
## Whether to place speed boost pads on the entry and exit ramps
@export var add_boost_pads: bool = true:
	set(v):
		add_boost_pads = v
		_maybe_rebuild()

## Whether to generate structural support pillars under the high points of the loop
@export var add_supports: bool = true:
	set(v):
		add_supports = v
		_maybe_rebuild()

## Number of subdivision segments around the circular loop
@export_range(24, 96, 4) var curve_segments: int = 48:
	set(v):
		curve_segments = clampi(v, 24, 96)
		_maybe_rebuild()

@export_group("Visuals")
@export var asphalt_color: Color = Color(0.20, 0.21, 0.24, 1.0)
@export var wall_color: Color = Color(0.88, 0.28, 0.12, 1.0)
@export var support_color: Color = Color(0.28, 0.30, 0.35, 1.0)

@export_group("Actions")
@export var rebuild_now: bool = false:
	set(v):
		if v:
			rebuild_now = false
			_rebuild()

const BOOST_PAD_SCENE = preload("res://BoostPad.tscn")

var _building: bool = false


func _enter_tree() -> void:
	add_to_group("loop_track")
	add_to_group("collision_trimesh")


func _ready() -> void:
	add_to_group("loop_track")
	add_to_group("collision_trimesh")
	if get_child_count() == 0:
		_rebuild()


func _maybe_rebuild() -> void:
	if Engine.is_editor_hint() and is_inside_tree() and not _building:
		call_deferred("_rebuild")


func _rebuild() -> void:
	if _building or not is_inside_tree():
		return
	_building = true

	# Clear previous generated children immediately to prevent duplicate node warnings
	for child in get_children():
		remove_child(child)
		child.free()

	# 1. Build the Path3D with smooth corkscrew curve
	var path_node := Path3D.new()
	path_node.name = "Path3D"
	path_node.curve = _create_loop_curve()
	add_child(path_node)

	# 2. Main CSG Combiner for track & structural supports
	var combiner := CSGCombiner3D.new()
	combiner.name = "LoopCSGCombiner"
	combiner.use_collision = true
	combiner.collision_layer = 1
	combiner.add_to_group("loop_track")
	combiner.add_to_group("collision_trimesh")
	add_child(combiner)

	# 3. CSGPolygon3D extruded along the Path3D
	var csg_track := CSGPolygon3D.new()
	csg_track.name = "LoopTrack"
	csg_track.mode = CSGPolygon3D.MODE_PATH
	csg_track.path_node = NodePath("../../Path3D")
	csg_track.path_interval = 0.35
	csg_track.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	csg_track.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
	csg_track.path_rotation_accurate = true
	csg_track.path_local = true
	csg_track.use_collision = true
	csg_track.polygon = _create_road_profile()
	csg_track.material = _create_asphalt_material()
	csg_track.add_to_group("loop_track")
	csg_track.add_to_group("collision_trimesh")
	combiner.add_child(csg_track)

	# 4. CSG Support Pylons (if enabled)
	if add_supports:
		_add_support_pylons(combiner)

	# 5. Entry Safety Divider (separates climb lane from descent track)
	_add_entry_divider(combiner)

	# 6. Boost Pads (if enabled)
	if add_boost_pads and BOOST_PAD_SCENE:
		_add_boost_pads()

	# Only set owner if we are editing LoopCSG.tscn directly (never when instanced in a level)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root == self:
		_set_owner_recursive(self, self)

	_building = false


## Returns the world-space entry position where cars start climbing into the loop
func get_entry_position() -> Vector3:
	var path_node: Path3D = get_node_or_null("Path3D")
	if path_node and path_node.curve and path_node.curve.point_count > 0:
		return path_node.to_global(path_node.curve.get_point_position(0))
	return global_position


## Returns the world-space entry tangent direction
func get_entry_direction() -> Vector3:
	var path_node: Path3D = get_node_or_null("Path3D")
	if path_node and path_node.curve and path_node.curve.point_count > 1:
		var p0 = path_node.to_global(path_node.curve.get_point_position(0))
		var p1 = path_node.to_global(path_node.curve.get_point_position(1))
		return (p1 - p0).normalized()
	return -global_transform.basis.z


## Angled center safety divider separating entry climbing ramp and exit descending road
func _add_entry_divider(combiner: CSGCombiner3D) -> void:
	var z_center := -5.0
	var z_entry_start := z_center - approach_length
	var divider_len := approach_length * 0.8
	var divider := CSGBox3D.new()
	divider.name = "EntryDivider"
	divider.size = Vector3(0.55, 1.4, divider_len)
	# Position along the seam between entry (-half_shift) and exit (+half_shift) at X = 0.0
	divider.position = Vector3(0.0, 0.7, z_entry_start + divider_len * 0.5 + 3.0)
	divider.material = _create_asphalt_material()
	divider.use_collision = true
	divider.collision_layer = 1
	combiner.add_child(divider)


## Generates the 3D stunt loop curve:
## Approach ramp from -Z -> 360 degree climbing and descending loop -> Exit ramp to +Z
func _create_loop_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.25

	var r := loop_radius
	var half_shift := spiral_offset * 0.5
	var z_center := -5.0

	# Entry approach ramp leading into the loop:
	# Starts sunken below ground (Y = -0.25) so it emerges seamlessly from the road surface
	# Then elevates smoothly up to ramp_height before entering the vertical loop
	var z_entry_start := z_center - approach_length
	curve.add_point(Vector3(-half_shift, -0.25, z_entry_start))
	curve.add_point(Vector3(-half_shift, 0.0, z_entry_start + 3.0))
	curve.add_point(Vector3(-half_shift, ramp_height * 0.5, z_entry_start + 10.0))
	curve.add_point(Vector3(-half_shift, ramp_height, z_center - 4.0))
	curve.add_point(Vector3(-half_shift, ramp_height, z_center))

	# Helix roll compensation:
	# A 3D helical path has non-zero torsion that accumulates rotation along the tangent.
	# Applying tilt compensation along the spiral cancels the accumulated roll,
	# ensuring the road bed stays level with the ground at the entrance and exit,
	# and oriented straight towards the loop center during vertical climb and descent.
	var total_roll_deg: float = 0.0
	if r > 0.001:
		total_roll_deg = -rad_to_deg((half_shift * 2.0) / r)

	# Full 360 degree vertical loop with smooth S-curve lateral shift
	for i in range(1, curve_segments + 1):
		var t := float(i) / float(curve_segments)
		var a := t * TAU
		var s_factor := smoothstep(0.0, 1.0, t)
		var x := lerpf(-half_shift, half_shift, s_factor)
		var y := ramp_height + r * (1.0 - cos(a))
		var z := z_center + r * sin(a)
		var pt_idx := curve.point_count
		curve.add_point(Vector3(x, y, z))
		curve.set_point_tilt(pt_idx, deg_to_rad(total_roll_deg * s_factor))

	# Exit ramp: descends from ramp_height back down into the road surface (Y = -0.25)
	var exit_idx1 := curve.point_count
	curve.add_point(Vector3(half_shift, ramp_height, z_center + 4.0))
	curve.set_point_tilt(exit_idx1, deg_to_rad(total_roll_deg))

	var exit_idx2 := curve.point_count
	curve.add_point(Vector3(half_shift, ramp_height * 0.5, z_center + approach_length - 10.0))
	curve.set_point_tilt(exit_idx2, deg_to_rad(total_roll_deg))

	var exit_idx3 := curve.point_count
	curve.add_point(Vector3(half_shift, 0.0, z_center + approach_length - 3.0))
	curve.set_point_tilt(exit_idx3, deg_to_rad(total_roll_deg))

	var exit_idx4 := curve.point_count
	curve.add_point(Vector3(half_shift, -0.25, z_center + approach_length))
	curve.set_point_tilt(exit_idx4, deg_to_rad(total_roll_deg))

	return curve


## Generates a sturdy U-channel cross section: flat road floor with angled containment curbs
func _create_road_profile() -> PackedVector2Array:
	var hw := track_width * 0.5
	var wh := wall_height
	var wt := wall_thickness
	var th := road_thickness

	# Profile with inward containment overhang lip:
	# Solid thick foundation underneath (th = 1.6m) to prevent high-speed tunneling.
	# High side walls (wh = 2.6m) with inward safety hook to catch sliding cars.
	return PackedVector2Array([
		Vector2(-hw - wt, wh),                # 0: Left wall top outer
		Vector2(-hw + 0.45, wh + 0.25),       # 1: Left wall containment overhang lip (inward hook)
		Vector2(-hw, wh),                     # 2: Left wall inner upper
		Vector2(-hw + 0.35, 0.0),             # 3: Left wall base inner (smooth chamfer)
		Vector2(hw - 0.35, 0.0),              # 4: Right wall base inner (smooth chamfer)
		Vector2(hw, wh),                      # 5: Right wall inner upper
		Vector2(hw - 0.45, wh + 0.25),        # 6: Right wall containment overhang lip (inward hook)
		Vector2(hw + wt, wh),                 # 7: Right wall top outer
		Vector2(hw + wt, -th),                # 8: Right wall bottom outer (-th solid thick backing)
		Vector2(-hw - wt, -th),               # 9: Left wall bottom outer
	])


## Asphalt material with triplanar texturing for crisp scale across the loop
func _create_asphalt_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = asphalt_color
	mat.roughness = 0.85
	var tex = load("res://materials/asphalt.png")
	if tex:
		mat.albedo_texture = tex
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.1, 0.1, 0.1)
	return mat


## Support pillars grounding the high points of the loop to Y=0
func _add_support_pylons(combiner: CSGCombiner3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = support_color
	mat.metallic = 0.75
	mat.roughness = 0.35

	var r := loop_radius
	var z_center := -5.0
	var col_radius := 0.65
	var half_shift := spiral_offset * 0.5
	var hw := track_width * 0.5 + wall_thickness

	# Support 1: Ascent tower (under front climb at a = PI/2, y = r, z = z_center + r)
	# Positioned well outside the left wall and behind the road backing
	var s_climb := smoothstep(0.0, 1.0, 0.25)
	var x_climb := lerpf(-half_shift, half_shift, s_climb)
	var pylon_climb := CSGCylinder3D.new()
	pylon_climb.name = "Pylon_Ascent"
	pylon_climb.radius = col_radius
	pylon_climb.height = r + ramp_height
	pylon_climb.sides = 16
	pylon_climb.position = Vector3(x_climb - hw - 2.8, (r + ramp_height) * 0.5, z_center + r + road_thickness + 0.6)
	pylon_climb.material = mat
	pylon_climb.use_collision = true
	pylon_climb.collision_layer = 1
	combiner.add_child(pylon_climb)

	var pylon_climb_cross := CSGBox3D.new()
	pylon_climb_cross.name = "Strut_Ascent"
	pylon_climb_cross.size = Vector3(3.0, 0.6, 0.6)
	pylon_climb_cross.position = Vector3(x_climb - hw - 1.4, r + ramp_height - 0.5, z_center + r + road_thickness + 0.6)
	pylon_climb_cross.material = mat
	pylon_climb_cross.use_collision = true
	combiner.add_child(pylon_climb_cross)

	# Support 2: Apex overhead gantry (at a = PI, y = 2 * r + ramp_height, z = z_center)
	# Pylons stand completely outside the loop footprint:
	# At ground Z = z_center, the entrance road extends to -half_shift - hw and exit extends to +half_shift + hw.
	# We place the columns at lateral_span = half_shift + hw + 3.8 so they are 3.5m+ clear of ALL road surfaces!
	var apex_h := 2.0 * r + ramp_height
	var tower_h := apex_h + road_thickness + 1.2
	var lateral_span := half_shift + hw + 3.8
	for side in [-1.0, 1.0]:
		var pylon_apex := CSGCylinder3D.new()
		pylon_apex.name = "Pylon_Apex_" + ("L" if side < 0 else "R")
		pylon_apex.radius = col_radius * 1.15
		pylon_apex.height = tower_h
		pylon_apex.sides = 16
		pylon_apex.position = Vector3(side * lateral_span, tower_h * 0.5, z_center)
		pylon_apex.material = mat
		pylon_apex.use_collision = true
		pylon_apex.collision_layer = 1
		combiner.add_child(pylon_apex)

	# Overhead cross-gantry beam spanning across the roof (above the road, outside the loop)
	var strut_apex := CSGBox3D.new()
	strut_apex.name = "Strut_Apex_Overhead"
	strut_apex.size = Vector3(lateral_span * 2.0 + 1.0, 0.7, 0.7)
	strut_apex.position = Vector3(0.0, apex_h + road_thickness + 0.6, z_center)
	strut_apex.material = mat
	strut_apex.use_collision = true
	combiner.add_child(strut_apex)

	# Support 3: Descent tower (under rear drop at a = 3PI/2, y = r, z = z_center - r)
	# Positioned well outside the right wall and behind the road backing
	var s_desc := smoothstep(0.0, 1.0, 0.75)
	var x_desc := lerpf(-half_shift, half_shift, s_desc)
	var pylon_descent := CSGCylinder3D.new()
	pylon_descent.name = "Pylon_Descent"
	pylon_descent.radius = col_radius
	pylon_descent.height = r + ramp_height
	pylon_descent.sides = 16
	pylon_descent.position = Vector3(x_desc + hw + 2.8, (r + ramp_height) * 0.5, z_center - r - road_thickness - 0.6)
	pylon_descent.material = mat
	pylon_descent.use_collision = true
	pylon_descent.collision_layer = 1
	combiner.add_child(pylon_descent)

	var pylon_descent_cross := CSGBox3D.new()
	pylon_descent_cross.name = "Strut_Descent"
	pylon_descent_cross.size = Vector3(3.0, 0.6, 0.6)
	pylon_descent_cross.position = Vector3(x_desc + hw + 1.4, r + ramp_height - 0.5, z_center - r - road_thickness - 0.6)
	pylon_descent_cross.material = mat
	pylon_descent_cross.use_collision = true
	combiner.add_child(pylon_descent_cross)


## Instances speed boost pads on the entry and exit ramps
func _add_boost_pads() -> void:
	var pads_node := Node3D.new()
	pads_node.name = "BoostPads"
	add_child(pads_node)

	var path_node: Path3D = get_node_or_null("Path3D")
	var curve: Curve3D = path_node.curve if path_node else null
	var total_len: float = curve.get_baked_length() if curve else 140.0

	# Boost Pad 1: Along the entry ramp incline (launches car onto the ramp)
	var pad_entry_1 = BOOST_PAD_SCENE.instantiate()
	pad_entry_1.name = "BoostPad_Entry1"
	if "boost_strength" in pad_entry_1:
		pad_entry_1.boost_strength = 1.35
	if "boost_duration" in pad_entry_1:
		pad_entry_1.boost_duration = 2.5
	pads_node.add_child(pad_entry_1)
	_align_pad_to_curve(pad_entry_1, curve, 8.0)

	# Boost Pad 2: Near the loop launch base (guarantees climbing speed)
	var pad_entry_2 = BOOST_PAD_SCENE.instantiate()
	pad_entry_2.name = "BoostPad_Entry2"
	if "boost_strength" in pad_entry_2:
		pad_entry_2.boost_strength = 1.25
	if "boost_duration" in pad_entry_2:
		pad_entry_2.boost_duration = 2.0
	pads_node.add_child(pad_entry_2)
	_align_pad_to_curve(pad_entry_2, curve, 20.0)

	# Boost Pad on exit ramp (speed boost shooting out of the loop)
	var pad_exit = BOOST_PAD_SCENE.instantiate()
	pad_exit.name = "BoostPad_Exit"
	if "boost_strength" in pad_exit:
		pad_exit.boost_strength = 1.15
	if "boost_duration" in pad_exit:
		pad_exit.boost_duration = 1.8
	pads_node.add_child(pad_exit)
	_align_pad_to_curve(pad_exit, curve, maxf(total_len - 12.0, 30.0))


func _align_pad_to_curve(pad: Node3D, curve: Curve3D, offset: float) -> void:
	if not curve:
		return
	var tf := curve.sample_baked_with_rotation(offset, false, true)
	pad.transform = tf
	pad.position += tf.basis.y * 0.08


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if scene_root == null:
		return
	for c in node.get_children():
		c.owner = scene_root
		# Only recurse into procedural nodes; never into children of an instanced sub-scene
		if c.scene_file_path.is_empty():
			_set_owner_recursive(c, scene_root)
