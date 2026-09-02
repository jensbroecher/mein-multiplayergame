@tool
extends Node3D

enum TrackLayoutType { DEFAULT, MOUNTAIN, CANYON }

## True when a baked curve sample sits in a jump gap (airborne / no road mesh).
## Hill jump is fully between the two large ramps; crossing only removes the high path
## so the lower road at the same XZ is untouched.
func _is_in_gap_pos(pos: Vector3) -> bool:
	if level_prefix != "canyon_chasm":
		return false
	# Gap 1 — hill jump between large ramp takeoff (~z -50) and landing (~z -120).
	# Keep a short solid lip past takeoff / before landing so the ramp ends aren't open.
	if absf(pos.x - 150.0) < 22.0 and pos.z < -56.0 and pos.z > -114.0 and pos.y > 28.0:
		return true
	# Gap 2 — elevated crossing over the lower track (y check keeps lower road solid)
	if absf(pos.x) < 28.0 and absf(pos.z + 100.0) < 20.0 and pos.y > 34.0:
		return true
	return false


## Skip a mesh strip if either end of the segment is in a gap (prevents one-segment
## "spikes" / glitchy bridges that only checked the start sample).
func _segment_in_gap(curve: Curve3D, length: float, point_count: int, i: int) -> bool:
	var o0 := (float(i) / float(point_count)) * length
	var o1 := (float(i + 1) / float(point_count)) * length
	return _is_in_gap_pos(curve.sample_baked(o0)) or _is_in_gap_pos(curve.sample_baked(o1))


## Stable sideways axis for a path tangent (avoids zero-length on steep ramps).
## Always horizontal so road/curb cross-sections stay level and don't fold on slopes.
func _path_right(tangent: Vector3) -> Vector3:
	var t := tangent
	t.y = 0.0
	if t.length_squared() < 1e-8:
		t = Vector3.FORWARD
	else:
		t = t.normalized()
	var right := t.cross(Vector3.UP)
	if right.length_squared() < 1e-6:
		right = Vector3.RIGHT
	return right.normalized()


## Banked right vector that cannot fold the road ribbon.
## Curve3D up-vectors flip on steep kickers when *any* point has tilt; clamp roll
## so only the intended NASCAR/outward banks lean (~0.42 rad) and hairpins stay flat.
func _stable_banked_right(tangent: Vector3, baked_up: Vector3) -> Vector3:
	var horiz := _path_right(tangent)
	if baked_up.length_squared() < 1e-6:
		return horiz
	var t := tangent
	if t.length_squared() < 1e-8:
		t = Vector3.FORWARD
	else:
		t = t.normalized()
	var banked := t.cross(baked_up.normalized())
	if banked.length_squared() < 1e-6:
		return horiz
	banked = banked.normalized()
	if banked.dot(horiz) < 0.0:
		banked = -banked
	# ~27 deg — covers Wadi outward-bank tilt 0.42, rejects 90-deg folds
	const MAX_RIGHT_Y := 0.46
	if absf(banked.y) <= MAX_RIGHT_Y:
		return banked
	var y: float = clampf(banked.y, -MAX_RIGHT_Y, MAX_RIGHT_Y)
	var xz := Vector3(banked.x, 0.0, banked.z)
	if xz.length_squared() < 1e-8:
		return horiz
	xz = xz.normalized() * sqrt(maxf(0.0, 1.0 - y * y))
	return Vector3(xz.x, y, xz.z)


func _curve_has_tilt(curve: Curve3D) -> bool:
	if not is_instance_valid(curve):
		return false
	for i in range(curve.point_count):
		if absf(curve.get_point_tilt(i)) > 0.001:
			return true
	return false


## Build per-slice path frames with flip-free smoothed right vectors and curve tilt support.
## Prevents curb/road mesh self-intersection on sharp hairpins and enables banked turns.
func _build_path_frames(curve: Curve3D, point_count: int) -> Array:
	var length: float = maxf(curve.get_baked_length(), 0.001)
	var has_tilt: bool = _curve_has_tilt(curve)
	var frames: Array = []
	for i in range(point_count + 1):
		var offset: float = (float(i) / float(point_count)) * length
		var pos: Vector3 = curve.sample_baked(offset)
		if is_loop and i == point_count:
			pos = curve.sample_baked(0.0)
		var tangent: Vector3
		if i == 0:
			if is_loop:
				tangent = curve.sample_baked(0.75) - curve.sample_baked(maxf(0.0, length - 0.75))
			else:
				tangent = curve.sample_baked(minf(length, 0.75)) - pos
		elif i == point_count:
			if is_loop:
				tangent = curve.sample_baked(0.75) - curve.sample_baked(maxf(0.0, length - 0.75))
			else:
				tangent = pos - curve.sample_baked(maxf(0.0, length - 0.75))
		else:
			var o0: float = maxf(0.0, offset - 0.75)
			var o1: float = minf(length, offset + 0.75)
			tangent = curve.sample_baked(o1) - curve.sample_baked(o0)

		if tangent.length_squared() < 1e-8:
			tangent = Vector3.FORWARD
		else:
			tangent = tangent.normalized()

		var right: Vector3
		var up_vec: Vector3
		if has_tilt:
			up_vec = curve.sample_baked_up_vector(offset, true)
			right = _stable_banked_right(tangent, up_vec)
			up_vec = right.cross(tangent).normalized()
			if up_vec.length_squared() < 1e-6:
				up_vec = Vector3.UP
		else:
			# Standard tracks: keep right vector strictly horizontal (no sideways roll on climbs!)
			right = _path_right(tangent)
			up_vec = right.cross(tangent).normalized()

		frames.append({"pos": pos, "tangent": tangent, "right": right, "up": up_vec, "offset": offset})

	# Forward-Backward 2-pass smooth to eliminate micro-jitter and step discontinuities completely
	for i in range(1, frames.size()):
		var prev_r: Vector3 = frames[i - 1]["right"]
		var r: Vector3 = frames[i]["right"]
		if r.dot(prev_r) < 0.0:
			r = -r
		r = (prev_r * 0.2 + r * 0.8).normalized()
		frames[i]["right"] = r
		var t: Vector3 = frames[i]["tangent"]
		frames[i]["up"] = r.cross(t).normalized()

	for i in range(frames.size() - 2, -1, -1):
		var next_r: Vector3 = frames[i + 1]["right"]
		var r: Vector3 = frames[i]["right"]
		if r.dot(next_r) < 0.0:
			r = -r
		r = (next_r * 0.2 + r * 0.8).normalized()
		frames[i]["right"] = r
		var t: Vector3 = frames[i]["tangent"]
		frames[i]["up"] = r.cross(t).normalized()

	if is_loop and frames.size() > 2:
		var r0: Vector3 = frames[0]["right"]
		var rN: Vector3 = frames[frames.size() - 1]["right"]
		if rN.dot(r0) < 0.0:
			frames[frames.size() - 1]["right"] = -rN
		var avg_r: Vector3 = (r0 + frames[frames.size() - 1]["right"]).normalized()
		frames[0]["right"] = avg_r
		frames[frames.size() - 1]["right"] = avg_r

	return frames


## Extra shoulder width allowed outside the asphalt on this slice (not the asphalt itself).
## Only trims the sand/curb flare on extreme hairpins — never gouges the road deck.
func _max_shoulder_extra_at(frames: Array, i: int, length: float, point_count: int) -> float:
	var i0: int = maxi(0, i - 1)
	var i1: int = mini(frames.size() - 1, i + 1)
	var r0: Vector3 = frames[i0]["right"]
	var r1: Vector3 = frames[i1]["right"]
	var ang: float = absf(r0.signed_angle_to(r1, Vector3.UP))
	var seg: float = length / float(maxi(point_count, 1))
	var radius: float = seg / maxf(ang, 0.001)
	# Allow normal shoulder (~1–2m) almost always; only shrink on very tight turns
	return maxf(radius * 0.35, 0.6)


## Emit road end-cap at a gap. `vert_base` = index of first vertex this call adds.
## Returns next free vertex index. pts = cross-section (left outer -> right outer).
func _emit_canyon_road_end_cap(st: SurfaceTool, pts: PackedVector3Array, tangent: Vector3, face_forward: bool, vert_base: int) -> int:
	if pts.size() < 3:
		return vert_base
	var n: Vector3 = tangent.normalized() if tangent.length_squared() > 1e-8 else Vector3.FORWARD
	if not face_forward:
		n = -n
	var profile_s: float = 0.0
	var added: int = 0
	for k in range(pts.size()):
		if k > 0:
			profile_s += pts[k].distance_to(pts[k - 1])
		# U across face (m from left outer), V along profile - no constant-V stretch.
		var u: float = pts[0].distance_to(pts[k])
		st.set_normal(n)
		st.set_uv(Vector2(u, profile_s))
		st.add_vertex(pts[k])
		added += 1
	var b: int = vert_base
	for k in range(1, added - 1):
		if face_forward:
			st.add_index(b); st.add_index(b + k); st.add_index(b + k + 1)
			st.add_index(b); st.add_index(b + k + 1); st.add_index(b + k)
		else:
			st.add_index(b); st.add_index(b + k + 1); st.add_index(b + k)
			st.add_index(b); st.add_index(b + k); st.add_index(b + k + 1)
	return vert_base + added


## Tall rock face sealing embankment at a jump gap.
## Single-sided only: opposite faces on the same verts make generate_normals()
## average to ~zero, which destroys triplanar rock mapping (looks massively stretched).
## Material uses cull_disabled so one face is visible from both sides.
func _emit_embankment_end_cap(
		st: SurfaceTool,
		top_l: Vector3, top_r: Vector3, bot_l: Vector3, bot_r: Vector3,
		tangent: Vector3, face_forward: bool, vert_base: int
) -> int:
	# Prefer geometric normal of the quad so it matches winding (triplanar needs this).
	var geo_n: Vector3 = (top_r - top_l).cross(bot_l - top_l)
	if geo_n.length_squared() < 1e-10:
		geo_n = (top_r - top_l).cross(bot_r - top_l)
	if geo_n.length_squared() < 1e-10:
		geo_n = tangent if tangent.length_squared() > 1e-8 else Vector3.FORWARD
	else:
		geo_n = geo_n.normalized()
	# Face into the gap: align with +/- path tangent when possible
	var want: Vector3 = tangent.normalized() if tangent.length_squared() > 1e-8 else geo_n
	if not face_forward:
		want = -want
	if geo_n.dot(want) < 0.0:
		geo_n = -geo_n
	var n: Vector3 = geo_n

	var width_m: float = top_l.distance_to(top_r)
	var height_m: float = 0.5 * (top_l.distance_to(bot_l) + top_r.distance_to(bot_r))
	if width_m < 0.01:
		width_m = 1.0
	if height_m < 0.01:
		height_m = 1.0
	# UV in meters (triplanar mainly uses world pos; UV is a solid fallback)
	var us: float = 0.15
	var vs: float = 0.15

	# Winding: when looking along -n (from outside/gap), want CCW front face.
	# If n was flipped above to match want, use order that produces +n.
	var flip_winding: bool = (top_r - top_l).cross(bot_l - top_l).dot(n) < 0.0

	st.set_normal(n)
	st.set_uv(Vector2(0.0, height_m * vs))
	st.add_vertex(top_l) # b+0
	st.set_normal(n)
	st.set_uv(Vector2(width_m * us, height_m * vs))
	st.add_vertex(top_r) # b+1
	st.set_normal(n)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(bot_l) # b+2
	st.set_normal(n)
	st.set_uv(Vector2(width_m * us, 0.0))
	st.add_vertex(bot_r) # b+3
	var b: int = vert_base
	if flip_winding:
		st.add_index(b + 0); st.add_index(b + 1); st.add_index(b + 2)
		st.add_index(b + 1); st.add_index(b + 3); st.add_index(b + 2)
	else:
		st.add_index(b + 0); st.add_index(b + 2); st.add_index(b + 1)
		st.add_index(b + 1); st.add_index(b + 2); st.add_index(b + 3)
	return vert_base + 4

func _build_track_spatial_mask(curve: Curve3D, grid_res: int, cell_size_x: float, cell_size_z: float, start_x: float, start_z: float, margin: float = 85.0) -> PackedByteArray:
	var mask = PackedByteArray()
	mask.resize(grid_res * grid_res)
	if not curve:
		return mask
	var length = curve.get_baked_length()
	var step_dist = 6.0
	var count = int(length / step_dist) + 1
	var cell_rad_x = int(ceil(margin / cell_size_x))
	var cell_rad_z = int(ceil(margin / cell_size_z))

	for i in range(count):
		var offset = float(i) * step_dist
		var pt = curve.sample_baked(offset)
		var cx = int((pt.x - start_x) / cell_size_x)
		var cz = int((pt.z - start_z) / cell_size_z)
		var min_x = clampi(cx - cell_rad_x, 0, grid_res - 1)
		var max_x = clampi(cx + cell_rad_x, 0, grid_res - 1)
		var min_z = clampi(cz - cell_rad_z, 0, grid_res - 1)
		var max_z = clampi(cz + cell_rad_z, 0, grid_res - 1)
		for gz in range(min_z, max_z + 1):
			var row_offset = gz * grid_res
			for gx in range(min_x, max_x + 1):
				mask[row_offset + gx] = 1
	return mask

func _get_terrain_height(px: float, pz: float, noise: FastNoiseLite, curve: Curve3D, for_collision: bool, is_near_track: bool = true) -> float:
	var h_noise: float = noise.get_noise_2d(px, pz) * hill_height

	# Harbor pier: flat seabed only. Never raise hills or pull terrain up to the racing line.
	if level_prefix == "harbor_pier":
		var harbor_h: float = HARBOR_SEABED_Y + h_noise * 0.18
		var max_radius: float = terrain_size.x * 0.5
		var dist_from_center_val: float = Vector2(px, pz).length()
		var falloff_start: float = max_radius * 0.88
		var falloff_end: float = max_radius * 0.98
		var edge_t: float = clampf((dist_from_center_val - falloff_start) / maxf(falloff_end - falloff_start, 0.001), 0.0, 1.0)
		var smooth_edge: float = edge_t * edge_t * (3.0 - 2.0 * edge_t)
		return lerpf(-40.0, harbor_h, 1.0 - smooth_edge)
	
	# --- Mountain base shape ---
	var radial_offset = 0.0
	if track_layout_type == TrackLayoutType.MOUNTAIN:
		var dist_from_center = Vector2(px, pz).length()
		var mountain_height = 145.0
		var mountain_base = 350.0
		var mountain_shape = clamp(1.0 - (dist_from_center / mountain_base), 0.0, 1.0)
		mountain_shape = mountain_shape * mountain_shape * (3.0 - 2.0 * mountain_shape)
		radial_offset = mountain_shape * mountain_height

	var base_terrain_height: float
	if track_layout_type == TrackLayoutType.MOUNTAIN:
		base_terrain_height = radial_offset + h_noise
		# Cap valley floor height near start gate area to prevent hills from blocking the bridge crossover
		if px > -110.0 and px < 60.0 and pz > -370.0 and pz < -230.0:
			base_terrain_height = min(base_terrain_height, 10.0)
	elif track_layout_type == TrackLayoutType.CANYON:
		# Canyon plateau: low flat ground with gentle noise ripples (lowered to 24.0 so camera doesn't clip/occlude in isometric mode)
		base_terrain_height = 24.0 + h_noise * 0.4
		if level_prefix == "canyon_chasm":
			# Deep chasm floor under the hill jump so nothing fills the gap between ramps
			if absf(px - 150.0) < 28.0 and pz < -40.0 and pz > -145.0:
				base_terrain_height = -12.0
	elif level_prefix == "desert_wadi":
		# Valley amphitheater: bowl center around lake (195, -208) where terrain is low,
		# surrounded on all sides by towering desert dunes/hills rising to 18-36m.
		var valley_c := Vector2(195.0, -208.0)
		var d_valley := Vector2(
				(px - valley_c.x) / 135.0,
				(pz - valley_c.y) / 110.0
		).length()
		var bowl_t: float = clampf(d_valley, 0.0, 1.0)
		var bowl_shape: float = bowl_t * bowl_t * (3.0 - 2.0 * bowl_t)
		var dune_ring: float = lerpf(0.6, 26.0, bowl_shape)
		var dune_noise: float = h_noise * lerpf(0.15, 1.0, bowl_shape)
		base_terrain_height = dune_ring + dune_noise
	elif level_prefix == "pinecrest_ridge":
		# Massive single-sided mountain hill on the north flank (rising from Z=80 to Z=-320 up to +90m)
		var hill_progress: float = clampf((-pz + 80.0) / 380.0, 0.0, 1.0)
		var hill_shape: float = hill_progress * hill_progress * (3.0 - 2.0 * hill_progress)
		var x_falloff: float = clampf(1.0 - (absf(px) / 380.0), 0.0, 1.0)
		x_falloff = x_falloff * x_falloff * (3.0 - 2.0 * x_falloff)
		var hill_elevation: float = hill_shape * x_falloff * 90.0
		var valley_noise: float = h_noise * (0.35 + 0.65 * hill_shape)
		base_terrain_height = hill_elevation + valley_noise
	else:
		base_terrain_height = h_noise

	# Lake basin in Lakeside Meadow and Pinecrest Ridge
	if not no_water:
		if level_prefix == "pinecrest_ridge":
			var lake_center = Vector2(-150.0, 140.0)
			var lake_radius = 90.0
			var dist_to_lake = Vector2(px, pz).distance_to(lake_center)
			if dist_to_lake < lake_radius:
				var depth = -8.0
				var lake_blend = clampf((lake_radius - dist_to_lake) / 25.0, 0.0, 1.0)
				lake_blend = lake_blend * lake_blend * (3.0 - 2.0 * lake_blend)
				base_terrain_height = lerpf(base_terrain_height, depth, lake_blend)
		else:
			var lake_center = Vector2(-450, -500)
			var lake_radius = 220.0
			var dist_to_lake = Vector2(px, pz).distance_to(lake_center)
			if dist_to_lake < lake_radius:
				var depth = -18.0
				var lake_blend = clampf((lake_radius - dist_to_lake) / 45.0, 0.0, 1.0)
				lake_blend = lake_blend * lake_blend * (3.0 - 2.0 * lake_blend)
				base_terrain_height = lerpf(base_terrain_height, depth, lake_blend)

	var height: float

	if not is_near_track:
		height = base_terrain_height
		if level_prefix == "desert_wadi":
			var river_t: float = _wadi_river_influence(px, pz)
			if river_t > 0.001:
				var bed_y: float = WADI_RIVER_BED_Y
				var target_bed: float = lerpf(bed_y, bed_y - 0.7, river_t * river_t * 0.5)
				height = lerp(height, target_bed, clampf(river_t, 0.0, 1.0))
	else:
		var query_y = -200.0 if (track_layout_type == TrackLayoutType.CANYON) else base_terrain_height
		var closest_pos = curve.get_closest_point(Vector3(px, query_y, pz))
		var dist = Vector2(px, pz).distance_to(Vector2(closest_pos.x, closest_pos.z))
		var road_h = closest_pos.y

		# Calculate lateral distance and account for curve banking/roll only if tilt is present
		if _curve_has_tilt(curve):
			var c_offset = curve.get_closest_offset(closest_pos)
			var c_length = maxf(curve.get_baked_length(), 0.001)
			var o0_c = maxf(0.0, c_offset - 0.5)
			var o1_c = minf(c_length, c_offset + 0.5)
			var c_tangent = (curve.sample_baked(o1_c) - curve.sample_baked(o0_c)).normalized()
			if c_tangent.length_squared() > 1e-6:
				var c_up = curve.sample_baked_up_vector(c_offset, true)
				var c_right = _stable_banked_right(c_tangent, c_up)
				var rel_p = Vector3(px - closest_pos.x, 0.0, pz - closest_pos.z)
				var lat_xz := Vector3(c_right.x, 0.0, c_right.z)
				if lat_xz.length_squared() > 1e-8:
					var lateral_d = rel_p.dot(lat_xz.normalized())
					road_h += lateral_d * c_right.y

		# Airborne jump curve must NOT pull terrain up into a glitchy ridge / fake structure.
		if level_prefix == "canyon_chasm" and _is_in_gap_pos(closest_pos):
			dist = 1.0e9
			road_h = base_terrain_height

		if track_layout_type == TrackLayoutType.CANYON:
			var sand_edge = sand_width / 2.0
			
			# Zone 1: Road surface — flat at road height
			var road_inner = sand_edge - 2.0
			# Zone 2: Canyon floor just beyond curb — stays low briefly
			var floor_edge = sand_edge + 5.0
			# Zone 3: Canyon wall rise — ramps gently up to low plateau
			var wall_top = sand_edge + 30.0
			
			if dist < road_inner:
				# On the road itself
				height = road_h
			elif dist < floor_edge:
				# Canyon floor (still at road level)
				var t = (dist - road_inner) / (floor_edge - road_inner)
				height = lerp(road_h, road_h + 1.0, t)
			elif dist < wall_top:
				# Steep canyon wall rising to plateau
				var t = (dist - floor_edge) / (wall_top - floor_edge)
				var smooth_t = t * t * (3.0 - 2.0 * t)  # smoothstep
				height = lerp(road_h + 1.0, base_terrain_height, smooth_t)
			else:
				# Canyon rim plateau with noise
				height = base_terrain_height
			
			# Basin recession under road for collision mesh
			var basin_blend = 1.0 - smoothstep(road_inner - 2.0, road_inner, dist)
			if for_collision:
				height = lerp(height, road_h - terrain_recession_collision, basin_blend)
			else:
				height = lerp(height, road_h - terrain_recession_visual, basin_blend)

			# Final hard carve under hill jump (keep carve inside the airborne gap only)
			if level_prefix == "canyon_chasm" and absf(px - 150.0) < 22.0 and pz < -56.0 and pz > -114.0:
				height = minf(height, -8.0)
		else:
			# Original blending for DEFAULT and MOUNTAIN
			var sand_edge = sand_width / 2.0
			var blend_dist = 45.0 if level_prefix == "pinecrest_ridge" else 60.0
			var clearing_blend = 1.0 - smoothstep(sand_edge - 2.0, sand_edge + blend_dist, dist)

			# Bridge detection: when road is elevated far above base terrain,
			# attenuate blending so terrain stays low (preserves bridge gap).
			# Ramps from 0 (normal road, <4m above ground) to 1 (bridge, >12m above ground).
			var elevation_diff = road_h - base_terrain_height
			var bridge_factor = 0.0
			if level_prefix != "pinecrest_ridge":
				bridge_factor = clampf((elevation_diff - 4.0) / 8.0, 0.0, 1.0)
			clearing_blend *= (1.0 - bridge_factor)

			height = lerp(base_terrain_height, road_h, clearing_blend)

			var basin_blend = 1.0 - smoothstep(sand_edge - 2.0, sand_edge, dist)
			basin_blend *= (1.0 - bridge_factor)
			if for_collision:
				height = lerp(height, road_h - terrain_recession_collision, basin_blend)
			else:
				height = lerp(height, road_h - terrain_recession_visual, basin_blend)

			# Desert Wadi: carve a shallow river corridor (banks dip below the water plane).
			# Road blend above still wins near the path so the ford stays driveable.
			if level_prefix == "desert_wadi":
				var river_t: float = _wadi_river_influence(px, pz)
				if river_t > 0.001:
					var bed_y: float = WADI_RIVER_BED_Y
					var away_from_road: float = smoothstep(sand_edge + 1.5, sand_edge + 22.0, dist)
					var carve: float = river_t * away_from_road
					var lake_center_boost: float = river_t * river_t * 0.5
					var target_bed: float = lerpf(bed_y, bed_y - 0.7, lake_center_boost)
					height = lerp(height, target_bed, clampf(carve, 0.0, 1.0))

	# Edge falloff (all track types — curves down smoothly to abyss / horizon outside all track envelopes)
	var max_radius: float = terrain_size.x * 0.5
	var dist_from_center_val: float = Vector2(px, pz).length()
	var r_noise: float = noise.get_noise_2d(px * 0.015, pz * 0.015) * (max_radius * 0.03)
	var effective_dist: float = dist_from_center_val + r_noise
	var falloff_start: float = max_radius * 0.88
	var falloff_end: float = max_radius * 0.98
	var edge_t: float = clampf((effective_dist - falloff_start) / maxf(falloff_end - falloff_start, 0.001), 0.0, 1.0)
	var smooth_edge: float = edge_t * edge_t * (3.0 - 2.0 * edge_t)
	var edge_falloff: float = 1.0 - smooth_edge
	var falloff_y: float = -70.0 if (track_layout_type == TrackLayoutType.MOUNTAIN or track_layout_type == TrackLayoutType.CANYON) else -40.0
	height = lerp(falloff_y, height, edge_falloff)

	return height



@export var generate_now: bool = false:
	set(val):
		if val:
			generate_now = false
			if Engine.is_editor_hint():
				generate_world()
			notify_property_list_changed()

@export var generate_grass_only: bool = false:
	set(val):
		if val:
			generate_grass_only = false
			if Engine.is_editor_hint():
				_generate_terrain_grass()
				_set_owner_recursive(self)
			notify_property_list_changed()

@export var track_path: Path3D
@export var terrain_size: Vector2 = Vector2(2000, 2000)
@export var terrain_resolution: int = 800 # Higher resolution for rounder, more organic hills
@export var noise_frequency: float = 0.008 # Detailed hills
@export var hill_height: float = 50.0 # Taller hills

@export_group("Layout")
@export var track_layout_type: TrackLayoutType = TrackLayoutType.DEFAULT
@export var road_width: float = 14.0
@export var sand_width: float = 16.0
@export var road_y_offset: float = 0.3
@export var curb_y_offset: float = 0.05
@export var curb_slope: float = 0.15
@export var grass_material: Material
@export var road_material: Material
@export var terrain_recession_visual: float = 0.4
@export var terrain_recession_collision: float = 0.0
@export var level_prefix: String = ""
@export var no_water: bool = false
@export var no_grass: bool = false
@export var generate_bridge_supports: bool = true
@export var is_loop: bool = true

@export_group("Vegetation")
@export var tree_count: int = 200
@export var tree_scenes: Array[PackedScene] = []
@export var plant_scenes: Array[PackedScene] = []
@export var terrain_grass_count: int = 500000
@export var terrain_grass_scenes: Array[PackedScene] = []
@export var grass_grid_size: int = 20
@export var grass_visibility_range: float = 350.0
@export var flower_blue_mesh: Mesh
@export var flower_white_mesh: Mesh
@export var flower_blue_material: Material
@export var flower_white_material: Material
@export var flowers_per_m2: float = 0.08
@export var flower_chunk_size: float = 200.0

@export_group("Visual Overlays")
@export var asphalt_material: Material
@export var curb_material: Material
@export var road_sides_material: Material
@export var curb_sides_material: Material
@export var save_to_files: bool = true

var _visual_heights: PackedFloat32Array = PackedFloat32Array()

func _sample_cached_height(px: float, pz: float) -> float:
	if _visual_heights.is_empty():
		var curve = _get_world_curve() if track_path else null
		if not curve:
			return 0.0
		var noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = noise_frequency
		noise.seed = 12345
		noise.fractal_octaves = 4
		return _get_terrain_height(px, pz, noise, curve, false, true)
	var res: int = terrain_resolution
	var stride = res + 1
	var step_x = terrain_size.x / float(res)
	var step_z = terrain_size.y / float(res)
	var start_x = -terrain_size.x / 2.0
	var start_z = -terrain_size.y / 2.0
	
	var gx = (px - start_x) / step_x
	var gz = (pz - start_z) / step_z
	var x0 = clampi(int(floor(gx)), 0, res - 1)
	var z0 = clampi(int(floor(gz)), 0, res - 1)
	var fx = clampf(gx - float(x0), 0.0, 1.0)
	var fz = clampf(gz - float(z0), 0.0, 1.0)
	var h00 = _visual_heights[z0 * stride + x0]
	var h10 = _visual_heights[z0 * stride + (x0 + 1)]
	var h01 = _visual_heights[(z0 + 1) * stride + x0]
	var h11 = _visual_heights[(z0 + 1) * stride + (x0 + 1)]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)



func _ready():
	if Engine.is_editor_hint():
		if get_child_count() == 0 and track_path:
			generate_world()
	else:
		if get_child_count() == 0 and track_path:
			generate_world()
	if level_prefix == "canyon_chasm":
		call_deferred("add_chasm_pit_water")
	elif level_prefix == "desert_wadi":
		call_deferred("add_wadi_river_water")
	elif level_prefix == "harbor_pier":
		if get_node_or_null("HarborWater") == null:
			call_deferred("add_harbor_water")

func generate_world():
	if not track_path:
		track_path = get_node_or_null("../TrackPath") as Path3D
		if not track_path and get_parent():
			track_path = get_parent().get_node_or_null("TrackPath") as Path3D
	if not track_path:
		push_error("TerrainGenerator: track_path is null, cannot generate world!")
		return
	
	# Keep high-resolution bake interval for exact curve sampling
	track_path.curve.bake_interval = 0.25

	# IMPORTANT: Use free() in editor for immediate cleanup to prevent 'ghost' nodes
	# queue_free() is too slow for tool scripts and causes scene-save bloat
	if level_prefix == "harbor_pier":
		_generate_harbor_world()
		if Engine.is_editor_hint():
			_set_owner_recursive(self)
		print("Procedural map generation complete! Layout: HARBOR_PIER")
		return

	for child in get_children():
		remove_child(child)
		child.free()

	# 1. Create Data Meshes
	# Both visual and collision MUST use identical terrain_resolution so collision triangles
	# align 1:1 with visual hills and valleys, preventing car sinking or hovering.
	var collision_mesh = _generate_mesh(true)  # Flat under road for smooth driving
	var visual_mesh = _generate_mesh(false)    # Recessed under road to prevent leaking
	var trimesh_shape = collision_mesh.create_trimesh_shape()

	# 2. Visual Terrain
	var terrain_instance = MeshInstance3D.new()
	terrain_instance.name = "Terrain_Visual"
	terrain_instance.mesh = _save_resource(visual_mesh, "terrain_visual")
	if grass_material:
		terrain_instance.material_override = grass_material
	else:
		var terrain_mat = StandardMaterial3D.new()
		# Desert-ish default if no material assigned
		if level_prefix == "desert_wadi" or track_layout_type == TrackLayoutType.MOUNTAIN:
			var sand_tex: Texture2D = load("res://materials/sand.png") as Texture2D
			var sand_norm: Texture2D = load("res://materials/sand_normal.png") as Texture2D
			if sand_tex:
				terrain_mat.albedo_texture = sand_tex
				# Near-white so the photo texture reads as real sand
				terrain_mat.albedo_color = Color(1.0, 0.97, 0.90)
				terrain_mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
				terrain_mat.uv1_triplanar = true
				if sand_norm:
					terrain_mat.normal_enabled = true
					terrain_mat.normal_texture = sand_norm
					terrain_mat.normal_scale = 0.85
			else:
				# Muted khaki sand (no texture)
				terrain_mat.albedo_color = Color(0.78, 0.70, 0.52)
		else:
			terrain_mat.albedo_color = Color(0.2, 0.6, 0.2)
		terrain_mat.roughness = 0.94
		terrain_mat.metallic = 0.0
		terrain_instance.material_override = terrain_mat
	terrain_instance.lod_bias = 10.0
	terrain_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(terrain_instance)


	# 3. Unified Collision
	var static_body = StaticBody3D.new()
	static_body.name = "Unified_World_Collision"
	add_child(static_body)
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = _save_resource(trimesh_shape, "terrain_collision_shape")
	static_body.add_child(collision_shape)

	# 4. Road & Sand Overlays
	_generate_road_and_sand()

	# 5. Water Surface
	if level_prefix == "canyon_chasm":
		add_chasm_pit_water()
	elif level_prefix == "desert_wadi":
		add_wadi_river_water()
	elif not no_water:
		_generate_water()

	# 6. Procedural Hill Grass
	if not no_grass:
		_generate_terrain_grass()

	# 7. Editor Ownership
	if Engine.is_editor_hint():
		_set_owner_recursive(self)

	print("Procedural map generation complete! Layout: ", TrackLayoutType.keys()[track_layout_type])


# Returns a Curve3D whose points are in TerrainGenerator-local space (= world space
# when TerrainGenerator is at the scene root with no transform offset).
# This corrects a mismatch that occurred when the Path3D node was moved in the
# scene: the raw curve points are relative to Path3D's own origin, so sampling
# them directly produced road/terrain geometry at the wrong world position.
#
# When is_loop is true, the first control point is also appended at the end so that
# get_closest_point() covers the closing segment (last → first) for terrain shaping.
func _get_world_curve() -> Curve3D:
	var src: Curve3D = track_path.curve
	var world_curve := Curve3D.new()
	world_curve.bake_interval = src.bake_interval
	world_curve.up_vector_enabled = true
	# The transform that maps Path3D-local positions into TerrainGenerator-local space
	var to_local: Transform3D = global_transform.affine_inverse() * track_path.global_transform
	for i in range(src.point_count):
		var pos   = to_local * src.get_point_position(i)
		var p_in  = to_local.basis * src.get_point_in(i)   # tangent handles are direction vectors
		var p_out = to_local.basis * src.get_point_out(i)
		world_curve.add_point(pos, p_in, p_out)
		world_curve.set_point_tilt(i, src.get_point_tilt(i))
	# For loops: append the first point at the end so the closing segment is
	# included in get_closest_point() queries (used by terrain height sampling).
	if is_loop and src.point_count > 1:
		var pos   = to_local * src.get_point_position(0)
		var p_in  = to_local.basis * src.get_point_in(0)
		var p_out = to_local.basis * src.get_point_out(0)
		world_curve.add_point(pos, p_in, p_out)
		world_curve.set_point_tilt(src.point_count, src.get_point_tilt(0))
	return world_curve


func _save_resource(res: Resource, res_name: String, sub_dir: String = "") -> Resource:
	if not save_to_files:
		return res

	var dir_path = "res://generated/"
	if sub_dir != "":
		dir_path += sub_dir + "/"

	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_absolute(dir_path)

	var extension = ".res"
	var actual_name = res_name
	if not level_prefix.is_empty():
		actual_name = level_prefix + "_" + res_name
	var file_path = dir_path + actual_name + extension
	
	# Crucial: take over the path in the resource cache so that the editor 
	# uses this new mesh immediately instead of serving the old cached one.
	res.take_over_path(file_path)
	ResourceSaver.save(res, file_path)
	
	return load(file_path)


func _clear_grass_directory():
	var dir_path = "res://generated/grass/"
	if DirAccess.dir_exists_absolute(dir_path):
		var dir = DirAccess.open(dir_path)
		if dir:
			var files_to_delete: Array[String] = []
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.begins_with("chunk_"):
					files_to_delete.append(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
			for f in files_to_delete:
				dir.remove(f)

func _set_owner_recursive(node: Node):

	if not Engine.is_editor_hint(): return
	var root = get_tree().edited_scene_root if is_inside_tree() else null
	if not root: return
	for child in node.get_children():
		child.owner = root
		_set_owner_recursive(child)

func _generate_mesh(for_collision: bool) -> ArrayMesh:
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_frequency
	noise.seed = 12345
	noise.fractal_octaves = 4

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0) 

	var res: int = terrain_resolution
	var step_x = terrain_size.x / res
	var step_y = terrain_size.y / res
	var start_x = -terrain_size.x / 2.0
	var start_y = -terrain_size.y / 2.0

	var max_radius: float = terrain_size.x * 0.5
	var max_radius_sq: float = max_radius * max_radius
	var outer_limit_sq: float = (max_radius + 30.0) * (max_radius + 30.0)
	var falloff_y_out: float = -70.0 if (track_layout_type == TrackLayoutType.MOUNTAIN or track_layout_type == TrackLayoutType.CANYON) else -40.0
	var curve = _get_world_curve()

	# Coarse spatial track mask (50x50 cells) for O(1) road influence checks:
	var mask_res: int = 50
	var cell_size_x: float = terrain_size.x / float(mask_res)
	var cell_size_z: float = terrain_size.y / float(mask_res)
	var track_mask: PackedByteArray = _build_track_spatial_mask(curve, mask_res, cell_size_x, cell_size_z, start_x, start_y, 85.0)

	var stride = res + 1
	var total_verts = stride * stride
	var heights = PackedFloat32Array()
	heights.resize(total_verts)

	# Pass 1: Compute heights once per grid point (5x faster than 5-tap per vertex)
	for y in range(res + 1):
		var pz = start_y + y * step_y
		var cz = clampi(int((pz - start_y) / cell_size_z), 0, mask_res - 1)
		var row_mask_offset = cz * mask_res

		for x in range(res + 1):
			var px = start_x + x * step_x
			var p_sq = px * px + pz * pz
			var idx = y * stride + x

			if p_sq > outer_limit_sq:
				heights[idx] = falloff_y_out
			else:
				var cx = clampi(int((px - start_x) / cell_size_x), 0, mask_res - 1)
				var is_near = (track_mask[row_mask_offset + cx] == 1)
				heights[idx] = _get_terrain_height(px, pz, noise, curve, for_collision, is_near)

	# Pass 2: Add vertices and analytical smooth normals from adjacent grid samples
	var span_x: float = step_x * 2.0
	var span_z: float = step_y * 2.0

	for y in range(res + 1):
		for x in range(res + 1):
			var px = start_x + x * step_x
			var pz = start_y + y * step_y
			var idx = y * stride + x
			var h = heights[idx]

			if for_collision or (px * px + pz * pz) > outer_limit_sq:
				st.set_normal(Vector3.UP)
			else:
				var x_prev = max(0, x - 1)
				var x_next = min(res, x + 1)
				var y_prev = max(0, y - 1)
				var y_next = min(res, y + 1)
				var h_L = heights[y * stride + x_prev]
				var h_R = heights[y * stride + x_next]
				var h_D = heights[y_prev * stride + x]
				var h_U = heights[y_next * stride + x]
				var dx_val = (x_next - x_prev) * step_x
				var dz_val = (y_next - y_prev) * step_y
				var normal = Vector3(h_L - h_R, dx_val, h_D - h_U).normalized()
				st.set_normal(normal)

			st.set_uv(Vector2(px, pz))
			st.add_vertex(Vector3(px, h, pz))

	# Winding Order (CCW - Facing UP) — Circular terrain disc
	for y in range(res):
		for x in range(res):
			var qx: float = start_x + (float(x) + 0.5) * step_x
			var qz: float = start_y + (float(y) + 0.5) * step_y
			if (qx * qx + qz * qz) > max_radius_sq:
				continue

			var i = y * (res + 1) + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + res + 1)
			
			st.add_index(i + 1)
			st.add_index(i + res + 2)
			st.add_index(i + res + 1)

	# IMPORTANT: We do NOT call st.generate_normals() because we manually calculated 
	# them above to eliminate the polygon/faceted look.
	if not for_collision:
		_visual_heights = heights
		st.generate_tangents()
	return st.commit()

func _configure_triplanar_pbr(mat: StandardMaterial3D, uv_scale: float, sharpness: float = 4.0) -> void:
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	mat.uv1_triplanar_sharpness = sharpness


func _make_concrete_pbr_material() -> StandardMaterial3D:
	var concrete_mat := StandardMaterial3D.new()
	concrete_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	concrete_mat.albedo_texture = load("res://materials/concrete.png")
	concrete_mat.roughness = 0.9
	concrete_mat.roughness_texture = load("res://materials/concrete_roughness.png")
	concrete_mat.normal_enabled = true
	concrete_mat.normal_texture = load("res://materials/concrete_normal.png")
	concrete_mat.normal_scale = 1.0
	_configure_triplanar_pbr(concrete_mat, 0.15, 4.0)
	return concrete_mat


func _generate_road_and_sand():
	if level_prefix == "harbor_pier":
		return
	# Desert Wadi is a sand wash: keep the carved trough in the terrain, but do
	# not emit asphalt, curbs, or a separate road collision slab.
	if level_prefix == "desert_wadi":
		return
	var curve = _get_world_curve()
	var length = curve.get_baked_length()
	var points_count = int(length / 0.2) # Even higher resolution (one segment every 20cm)

	# 1. Create a ShaderMaterial for the striped curbs (top surface)
	var curb_mat = ShaderMaterial.new()
	curb_mat.shader = load("res://curb_stripes.gdshader")
	curb_mat.set_shader_parameter("stripe_length", 1.5) # 1.5m per color step

	# 2. Create a Concrete Material for the vertical sides
	var concrete_mat = _make_concrete_pbr_material()

	# 3. Visual Overlays: Curbs and Road
	if track_layout_type != TrackLayoutType.CANYON:
		_create_path_visual(points_count, sand_width, curb_mat, concrete_mat, curb_y_offset, "Visual_Curbs")
		_create_path_visual(points_count, road_width, road_material, concrete_mat, road_y_offset, "Visual_Road")
	else:
		_create_path_visual(points_count, road_width, road_material, null, road_y_offset, "Visual_Road")

	# Create ONE unified collision surface for EVERYTHING (Road + Border)
	var col_width = road_width if track_layout_type == TrackLayoutType.CANYON else sand_width
	_create_track_collision(points_count, col_width, "Visual_Road")

func _create_path_visual(point_count: int, width: float, mat: Material, side_mat: Material, y_offset: float, node_name: String):
	var curve = _get_world_curve()
	var half_w = width / 2.0
	var length = curve.get_baked_length()
	
	var is_curb = node_name.contains("Curbs")
	var inner_w = road_width / 2.0
	var outer_w = half_w
	var curb_slope = 0.15

	# Ensure we have a high priority to avoid any conflict with terrain
	var mat_dup = mat.duplicate()
	if node_name.contains("Road"):
		if mat_dup is StandardMaterial3D:
			mat_dup.render_priority = 5 # Absolute top
	else:
		if mat_dup is ShaderMaterial or mat_dup is StandardMaterial3D:
			mat_dup.render_priority = 2 # Above terrain

	# --- CANYON ROAD: rounded driveable shoulders on both sides ---
	# Flat deck in the middle; edges curve DOWN and outward (no raised curb) so cars
	# can leave and climb back on. Wider multi-sample bevel = softer "round" feel.
	if track_layout_type == TrackLayoutType.CANYON and not is_curb:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

		# Wide soft shoulder (driveable). Quarter-circle profile: flat at deck, rolls down at lip.
		const BEVEL_W := 2.6
		const BEVEL_H := 0.75
		# 8 verts per slice: L outer → L flat → R flat → R outer (3 samples each shoulder + 2 flats)
		const SLICE_VERTS := 8

		# Per-slice positions + path tangent (for dedicated end-cap verts / normals).
		var slice_pts: Array = []
		var slice_tangents: Array = []

		for i in range(point_count + 1):
			var offset = (float(i) / point_count) * length
			var pos = curve.sample_baked(offset)

			var tangent: Vector3
			if i == 0:
				if is_loop:
					tangent = (curve.sample_baked(0.2) - curve.sample_baked(max(0.0, length - 0.2))).normalized()
				else:
					tangent = (curve.sample_baked(0.2) - pos).normalized()
			elif i == point_count:
				if is_loop:
					tangent = (curve.sample_baked(0.2) - curve.sample_baked(max(0.0, length - 0.2))).normalized()
				else:
					tangent = (pos - curve.sample_baked(max(0.0, length - 0.2))).normalized()
			else:
				tangent = (curve.sample_baked(min(length, offset + 0.2)) - pos).normalized()

			var right_dir = _path_right(tangent)

			var final_pos = pos
			if is_loop and i == point_count:
				final_pos = curve.sample_baked(0.0)

			# t=0 at flat deck edge, t=1 at outer lip. y drops with cos so the join is smooth (derivative 0).
			# lateral: flat at (half_w - BEVEL_W), outer at half_w
			var n_up: Vector3 = Vector3.UP
			var n_left: Vector3 = -right_dir
			var n_right: Vector3 = right_dir

			# Left shoulder: outer → flat (t 1 → 0). Right: flat → outer (t 0 → 1).
			var t_samples_l: Array = [1.0, 0.66, 0.33, 0.0]
			var t_samples_r: Array = [0.0, 0.33, 0.66, 1.0]
			var pts_this: PackedVector3Array = PackedVector3Array()
			for ti in range(4):
				var t: float = float(t_samples_l[ti])
				var lat: float = half_w - BEVEL_W * (1.0 - t)
				var drop: float = BEVEL_H * (1.0 - cos(t * PI * 0.5))
				var p: Vector3 = final_pos - right_dir * lat + Vector3(0, y_offset - drop, 0)
				# Normal rolls from outward (outer lip) to UP (deck)
				var n: Vector3 = (n_up * (1.0 - t) + n_left * t).normalized()
				if t < 0.05:
					n = n_up
				st.set_normal(n)
				# UV: 0 at left outer, increases toward center
				st.set_uv(Vector2(half_w - lat, offset))
				st.add_vertex(p)
				pts_this.append(p)

			for ti in range(4):
				var t2: float = float(t_samples_r[ti])
				var lat2: float = half_w - BEVEL_W * (1.0 - t2)
				var drop2: float = BEVEL_H * (1.0 - cos(t2 * PI * 0.5))
				var p2: Vector3 = final_pos + right_dir * lat2 + Vector3(0, y_offset - drop2, 0)
				var n2: Vector3 = (n_up * (1.0 - t2) + n_right * t2).normalized()
				if t2 < 0.05:
					n2 = n_up
				st.set_normal(n2)
				# UV continues across: half_w + lat (right flat ≈ width - BEVEL_W, outer = width)
				st.set_uv(Vector2(half_w + lat2, offset))
				st.add_vertex(p2)
				pts_this.append(p2)

			slice_pts.append(pts_this)
			slice_tangents.append(tangent.normalized() if tangent.length_squared() > 1e-8 else Vector3.FORWARD)

		# Index loop: 7 quads per slice
		for i in range(point_count):
			if _segment_in_gap(curve, length, point_count, i):
				continue
			var base = i * SLICE_VERTS
			var nxt  = (i + 1) * SLICE_VERTS
			for k in range(SLICE_VERTS - 1):
				var a = base + k;     var b = base + k + 1
				var c = nxt  + k;     var d = nxt  + k + 1
				st.add_index(a); st.add_index(c); st.add_index(b)
				st.add_index(b); st.add_index(c); st.add_index(d)
				# Underside (reverse winding)
				st.add_index(a); st.add_index(b); st.add_index(c)
				st.add_index(b); st.add_index(d); st.add_index(c)

		# Dedicated end-caps after strip verts so UVs/normals match the end face
		# (reusing strip verts shared path-U and up-normals stretched asphalt).
		var next_vert: int = (point_count + 1) * SLICE_VERTS
		for i in range(point_count):
			if _segment_in_gap(curve, length, point_count, i):
				continue
			var prev_gap2 := (
					(i == 0 and is_loop and _segment_in_gap(curve, length, point_count, point_count - 1))
					or (i > 0 and _segment_in_gap(curve, length, point_count, i - 1))
			)
			var next_gap2 := false
			if i + 1 < point_count:
				next_gap2 = _segment_in_gap(curve, length, point_count, i + 1)
			elif is_loop:
				next_gap2 = _segment_in_gap(curve, length, point_count, 0)
			if next_gap2:
				next_vert = _emit_canyon_road_end_cap(st, slice_pts[i + 1], slice_tangents[i + 1], true, next_vert)
			if prev_gap2:
				next_vert = _emit_canyon_road_end_cap(st, slice_pts[i], slice_tangents[i], false, next_vert)

		st.generate_tangents()
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = node_name
		mesh_instance.mesh = _save_resource(st.commit(), node_name)
		mesh_instance.material_override = mat_dup
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mesh_instance)
		# Canyon road sides (the deep rock walls below the bevel)
		_create_path_sides(point_count, width, side_mat if side_mat else mat_dup, y_offset, node_name + "_Sides")
		return

	# --- NON-CANYON (Default + Mountain) road: flat top, sharp edges ---
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frames: Array = _build_path_frames(curve, point_count)
	# Asphalt top height; curbs match this at the road edge (not raised above the road).
	var deck_y: float = road_y_offset
	var shoulder_drop: float = maxf(curb_slope, 0.12)

	# VERTEX LOOP — asphalt always full width (no curvature cuts into the deck)
	for i in range(point_count + 1):
		var final_pos: Vector3 = frames[i]["pos"]
		var right_dir: Vector3 = frames[i]["right"]
		var up_dir: Vector3 = frames[i]["up"] if frames[i].has("up") else Vector3.UP
		var offset: float = float(frames[i]["offset"])

		if is_curb:
			# Inner edge locked to full asphalt edge; only the outer flare may shrink on hairpins.
			var use_inner: float = inner_w
			var want_extra: float = maxf(outer_w - inner_w, 0.35)
			var max_extra: float = _max_shoulder_extra_at(frames, i, length, point_count)
			var use_outer: float = use_inner + minf(want_extra, max_extra)
			# Inner edge flush with road; outer edge drops slightly (drainage shoulder)
			var p_lo = final_pos - right_dir * use_outer + up_dir * (deck_y - shoulder_drop)
			var p_li = final_pos - right_dir * use_inner + up_dir * deck_y
			var p_ri = final_pos + right_dir * use_inner + up_dir * deck_y
			var p_ro = final_pos + right_dir * use_outer + up_dir * (deck_y - shoulder_drop)

			var span: float = maxf(use_outer - use_inner, 0.001)
			var left_normal = (right_dir * shoulder_drop + up_dir * span).normalized()
			var right_normal = (-right_dir * shoulder_drop + up_dir * span).normalized()

			st.set_normal(left_normal)
			st.set_uv(Vector2(0, offset))
			st.add_vertex(p_lo)

			st.set_normal(left_normal)
			st.set_uv(Vector2(0.25, offset))
			st.add_vertex(p_li)

			st.set_normal(right_normal)
			st.set_uv(Vector2(0.75, offset))
			st.add_vertex(p_ri)

			st.set_normal(right_normal)
			st.set_uv(Vector2(1.0, offset))
			st.add_vertex(p_ro)
		else:
			# Full constant road width every slice — prevents "deep cuts" on curves
			var right: Vector3 = right_dir * half_w
			st.set_normal(up_dir)
			st.set_uv(Vector2(0, offset))
			st.add_vertex(final_pos - right + up_dir * deck_y)

			st.set_normal(up_dir)
			st.set_uv(Vector2(width, offset))
			st.add_vertex(final_pos + right + up_dir * deck_y)

	# INDEX LOOP (CCW - Facing UP)
	for i in range(point_count):
		if _segment_in_gap(curve, length, point_count, i):
			continue

		if is_curb:
			var base = i * 4
			var nxt = (i + 1) * 4

			# Left slope
			st.add_index(base + 0); st.add_index(nxt + 0); st.add_index(base + 1)
			st.add_index(base + 1); st.add_index(nxt + 0); st.add_index(nxt + 1)

			# Right slope
			st.add_index(base + 2); st.add_index(nxt + 2); st.add_index(base + 3)
			st.add_index(base + 3); st.add_index(nxt + 2); st.add_index(nxt + 3)

			# --- UNDERSIDE ---
			st.add_index(base + 0); st.add_index(base + 1); st.add_index(nxt + 0)
			st.add_index(base + 1); st.add_index(nxt + 1); st.add_index(nxt + 0)
			st.add_index(base + 2); st.add_index(base + 3); st.add_index(nxt + 2)
			st.add_index(base + 3); st.add_index(nxt + 3); st.add_index(nxt + 2)
		else:
			var v0 = i * 2
			var v1 = v0 + 1
			var v2 = (i + 1) * 2
			var v3 = v2 + 1

			st.add_index(v0); st.add_index(v2); st.add_index(v1)
			st.add_index(v1); st.add_index(v2); st.add_index(v3)

			st.add_index(v0); st.add_index(v1); st.add_index(v2)
			st.add_index(v1); st.add_index(v3); st.add_index(v2)



	st.generate_tangents()
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = _save_resource(st.commit(), node_name)
	mesh_instance.material_override = mat_dup
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON # Enable shadows to prevent shadow leaking under bridges
	add_child(mesh_instance)


	# --- ADD DEPTH (Thickness) ---
	# For curbs, use the explicit concrete material. For road, duplicate its material.
	var final_side_mat = side_mat if side_mat else mat_dup
	_create_path_sides(point_count, width, final_side_mat, y_offset, node_name + "_Sides")

	# REMOVED: Separate collision shapes here as they cause sticking.
	# We now use the unified _create_track_collision call.


func _create_track_collision(point_count: int, width: float, node_name: String):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curve = _get_world_curve()
	var length = curve.get_baked_length()
	var half_w = width / 2.0
	var y_offset = road_y_offset # Match road height exactly
	var thickness = 5.0 # Increased thickness for better underground anchoring

	var inner_w = road_width / 2.0
	var outer_w = half_w
	var curb_slope = 0.15

	if track_layout_type == TrackLayoutType.CANYON:
		# Collision matches visual: rounded shoulders (8 top verts + 8 bottom).
		const BEVEL_W := 2.6
		const BEVEL_H := 0.75
		const SLICE_TOP := 8

		# Create Top and Bottom vertices for Canyon
		for i in range(point_count + 1):
			var offset = (float(i) / point_count) * length
			var pos = curve.sample_baked(offset)

			var tangent: Vector3
			if i == 0:
				if is_loop:
					var p_next = curve.sample_baked(0.2)
					var p_prev = curve.sample_baked(max(0.0, length - 0.2))
					tangent = (p_next - p_prev).normalized()
				else:
					tangent = (curve.sample_baked(0.2) - pos).normalized()
			elif i == point_count:
				if is_loop:
					var p_next = curve.sample_baked(0.2)
					var p_prev = curve.sample_baked(max(0.0, length - 0.2))
					tangent = (p_next - p_prev).normalized()
				else:
					tangent = (pos - curve.sample_baked(max(0.0, length - 0.2))).normalized()
			else:
				var next_pos = curve.sample_baked(min(offset + 0.5, length))
				tangent = (next_pos - pos).normalized()

			if tangent.length() < 0.01:
				tangent = (pos - curve.sample_baked(max(offset - 0.5, 0.0))).normalized()
			var right_dir = _path_right(tangent)

			var final_pos = pos
			if is_loop and i == point_count:
				final_pos = curve.sample_baked(0.0)

			var t_samples_l: Array = [1.0, 0.66, 0.33, 0.0]
			var t_samples_r: Array = [0.0, 0.33, 0.66, 1.0]
			var tops: Array[Vector3] = []
			for ti in range(4):
				var t: float = float(t_samples_l[ti])
				var lat: float = half_w - BEVEL_W * (1.0 - t)
				var drop: float = BEVEL_H * (1.0 - cos(t * PI * 0.5))
				tops.append(final_pos - right_dir * lat + Vector3(0, y_offset - drop, 0))
			for ti in range(4):
				var t2: float = float(t_samples_r[ti])
				var lat2: float = half_w - BEVEL_W * (1.0 - t2)
				var drop2: float = BEVEL_H * (1.0 - cos(t2 * PI * 0.5))
				tops.append(final_pos + right_dir * lat2 + Vector3(0, y_offset - drop2, 0))

			for v in tops:
				st.add_vertex(v)
			for v in tops:
				st.add_vertex(v - Vector3(0, thickness, 0))

		for i in range(point_count):
			if _segment_in_gap(curve, length, point_count, i):
				continue

			var base = i * (SLICE_TOP * 2)
			var nxt = (i + 1) * (SLICE_TOP * 2)

			# Top Faces: 7 quads
			for k in range(SLICE_TOP - 1):
				var a = base + k
				var b = base + k + 1
				var c = nxt + k
				var d = nxt + k + 1
				st.add_index(a); st.add_index(c); st.add_index(b)
				st.add_index(b); st.add_index(c); st.add_index(d)

			# Bottom Faces: 7 quads (reversed winding)
			for k in range(SLICE_TOP - 1):
				var ab = base + k + SLICE_TOP
				var bb = base + k + 1 + SLICE_TOP
				var cb = nxt + k + SLICE_TOP
				var db = nxt + k + 1 + SLICE_TOP
				st.add_index(ab); st.add_index(bb); st.add_index(cb)
				st.add_index(bb); st.add_index(db); st.add_index(cb)

			# Left outer wall (top0 / bot0)
			st.add_index(base + 0); st.add_index(base + SLICE_TOP); st.add_index(nxt + 0)
			st.add_index(base + SLICE_TOP); st.add_index(nxt + SLICE_TOP); st.add_index(nxt + 0)

			# Right outer wall (top7 / bot7)
			st.add_index(base + 7); st.add_index(nxt + 7); st.add_index(base + 7 + SLICE_TOP)
			st.add_index(base + 7 + SLICE_TOP); st.add_index(nxt + 7); st.add_index(nxt + 7 + SLICE_TOP)

	else:
		# Default / Mountain: FLAT collision deck across full sand width (no curb ramps).
		# Sloped collision shoulders launch cars on hairpins; visuals can still slope.
		var frames_col: Array = _build_path_frames(curve, point_count)
		# Match visual deck closely — large offsets left a gap at curb edges over recessed terrain
		var col_y: float = y_offset + 0.02
		# Align track collision deck with visual curb boundary
		var col_outer: float = outer_w + 0.05

		for i in range(point_count + 1):
			var final_pos: Vector3 = frames_col[i]["pos"]
			var right_dir: Vector3 = frames_col[i]["right"]
			var up_dir: Vector3 = frames_col[i]["up"] if frames_col[i].has("up") else Vector3.UP
			var use_outer: float = col_outer
			var use_inner: float = inner_w

			# Driveable sand + road matching banked up vector, with a subtle outer shoulder bevel
			var p_lo = final_pos - right_dir * use_outer + up_dir * (col_y - 0.12)
			var p_li = final_pos - right_dir * use_inner + up_dir * col_y
			var p_ri = final_pos + right_dir * use_inner + up_dir * col_y
			var p_ro = final_pos + right_dir * use_outer + up_dir * (col_y - 0.12)

			var p_lob = p_lo - up_dir * thickness
			var p_lib = p_li - up_dir * thickness
			var p_rib = p_ri - up_dir * thickness
			var p_rob = p_ro - up_dir * thickness

			st.add_vertex(p_lo)
			st.add_vertex(p_li)
			st.add_vertex(p_ri)
			st.add_vertex(p_ro)
			st.add_vertex(p_lob)
			st.add_vertex(p_lib)
			st.add_vertex(p_rib)
			st.add_vertex(p_rob)

		for i in range(point_count):
			if _segment_in_gap(curve, length, point_count, i):
				continue

			var base = i * 8
			var nxt = (i + 1) * 8

			# Top Faces (flat)
			st.add_index(base + 0); st.add_index(nxt + 0); st.add_index(base + 1)
			st.add_index(base + 1); st.add_index(nxt + 0); st.add_index(nxt + 1)
			st.add_index(base + 1); st.add_index(nxt + 1); st.add_index(base + 2)
			st.add_index(base + 2); st.add_index(nxt + 1); st.add_index(nxt + 2)
			st.add_index(base + 2); st.add_index(nxt + 2); st.add_index(base + 3)
			st.add_index(base + 3); st.add_index(nxt + 2); st.add_index(nxt + 3)

			# Bottom Faces
			st.add_index(base + 4); st.add_index(base + 5); st.add_index(nxt + 4)
			st.add_index(base + 5); st.add_index(nxt + 5); st.add_index(nxt + 4)
			st.add_index(base + 5); st.add_index(base + 6); st.add_index(nxt + 5)
			st.add_index(base + 6); st.add_index(nxt + 6); st.add_index(nxt + 5)
			st.add_index(base + 6); st.add_index(base + 7); st.add_index(nxt + 6)
			st.add_index(base + 7); st.add_index(nxt + 7); st.add_index(nxt + 6)

			# Side Walls
			st.add_index(base + 0); st.add_index(base + 4); st.add_index(nxt + 0)
			st.add_index(base + 4); st.add_index(nxt + 4); st.add_index(nxt + 0)
			st.add_index(base + 3); st.add_index(nxt + 3); st.add_index(base + 7)
			st.add_index(base + 7); st.add_index(nxt + 3); st.add_index(nxt + 7)


	var track_mesh = st.commit()
	var static_body = StaticBody3D.new()
	static_body.name = "Track_Collision"
	add_child(static_body)
	var col_shape = CollisionShape3D.new()
	var trimesh_shape = track_mesh.create_trimesh_shape()
	col_shape.shape = _save_resource(trimesh_shape, "track_collision_shape")
	static_body.add_child(col_shape)

	# Optional bridge pillars under elevated DEFAULT road stretches
	if node_name.contains("Road") and generate_bridge_supports:
		_generate_bridge_supports(point_count)

func _generate_bridge_supports(point_count: int):
	if not generate_bridge_supports:
		return
	if track_layout_type == TrackLayoutType.MOUNTAIN or track_layout_type == TrackLayoutType.CANYON:
		return

	var curve = _get_world_curve()
	var length = curve.get_baked_length()
	var step = 30.0 # Support every 30m

	var support_mat = _make_concrete_pbr_material()

	for d in range(0, int(length), int(step)):
		var pos = curve.sample_baked(d)
		# Only spawn if high above "ground" or in lake area
		if pos.y > 5.0 or Vector2(pos.x, pos.z).distance_to(Vector2(-450, -500)) < 220.0:
			var support = MeshInstance3D.new()
			support.name = "BridgeSupport_" + str(d)
			var box = BoxMesh.new()
			# Axis-aligned boxes poke through sloped/curved deck; keep a generous gap under the road.
			var pillar_top_y: float = pos.y + road_y_offset - 0.55
			var pillar_height: float = maxf(pillar_top_y + 30.0, 4.0)
			box.size = Vector3(3.2, pillar_height, 3.2)
			support.mesh = box
			support.position = Vector3(pos.x, pillar_top_y - pillar_height * 0.5, pos.z)
			support.material_override = support_mat
			add_child(support)

			# Add collision to the bridge supports
			var static_body = StaticBody3D.new()
			support.add_child(static_body)
			var collision_shape = CollisionShape3D.new()
			var shape = BoxShape3D.new()
			shape.size = box.size
			collision_shape.shape = shape
			static_body.add_child(collision_shape)

# (track rebuild functions removed — edit the Path3D curve directly in the scene editor,
#  then run the dedicated regenerate_*.tscn scene to rebuild terrain/road geometry)
func _create_path_sides(point_count: int, width: float, mat: Material, y_offset: float, node_name: String):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curve = _get_world_curve()
	var length = curve.get_baked_length()
	var half_w = width / 2.0
	var depth = 2.8 # Thickness of the road hull

	var side_y_offset = y_offset
	if node_name.contains("Curbs"):
		side_y_offset = y_offset - 0.15

	# Match canyon road outer lip (rounded shoulder drops BEVEL_H at full half_w).
	const SIDE_BEVEL_H := 0.75

	# Noise sampler for measuring terrain elevation under road sides
	var noise_terrain = FastNoiseLite.new()
	noise_terrain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_terrain.frequency = noise_frequency
	noise_terrain.seed = 12345
	noise_terrain.fractal_octaves = 4

	# Per-slice corners + tangents for dedicated end-cap faces (correct UVs/normals).
	var side_top_l: Array = []
	var side_top_r: Array = []
	var side_bot_l: Array = []
	var side_bot_r: Array = []
	var side_tangents: Array = []
	var frames_side: Array = _build_path_frames(curve, point_count)

	# 1. VERTEX GENERATION
	for i in range(point_count + 1):
		var offset: float = float(frames_side[i]["offset"])
		var final_pos: Vector3 = frames_side[i]["pos"]
		var right_dir: Vector3 = frames_side[i]["right"]
		var right: Vector3 = right_dir * half_w
		var tangent: Vector3 = Vector3.FORWARD
		if i < point_count:
			tangent = (frames_side[i + 1]["pos"] as Vector3) - final_pos
		elif point_count > 0:
			tangent = final_pos - (frames_side[i - 1]["pos"] as Vector3)
		if tangent.length_squared() < 1e-8:
			tangent = Vector3.FORWARD
		else:
			tangent = tangent.normalized()

		var up_dir: Vector3 = frames_side[i]["up"] if frames_side[i].has("up") else Vector3.UP
		var top_l = final_pos - right + up_dir * side_y_offset
		var top_r = final_pos + right + up_dir * side_y_offset
		var bot_l = top_l - up_dir * depth
		var bot_r = top_r - up_dir * depth

		if track_layout_type == TrackLayoutType.MOUNTAIN:
			# Mountain stage: drop embankment walls down into the terrain so the road is never hollow or floating!
			var h_l = _get_terrain_height(top_l.x, top_l.z, noise_terrain, curve, false)
			var h_r = _get_terrain_height(top_r.x, top_r.z, noise_terrain, curve, false)
			
			# Bridge overpass crossover check (upper road passes over lower road near x ≈ 0, z from -220 to -330)
			var is_crossing_span = absf(final_pos.x) < 45.0 and final_pos.z < -220.0 and final_pos.z > -330.0 and final_pos.y > 16.0
			var is_bridge_span = is_crossing_span or ((top_l.y - h_l > 8.0) and (top_r.y - h_r > 8.0))
			if is_bridge_span:
				# Clean elevated bridge deck with zero outward flare so it never cuts into roads beneath
				bot_l = top_l - up_dir * 2.2
				bot_r = top_r - up_dir * 2.2
			else:
				# Drop bottom into the mountain slope seamlessly
				bot_l = top_l - right_dir * 0.4
				bot_l.y = minf(top_l.y - 2.5, h_l - 1.5)
				bot_r = top_r + right_dir * 0.4
				bot_r.y = minf(top_r.y - 2.5, h_r - 1.5)
		elif track_layout_type == TrackLayoutType.CANYON:
			# Attach embankment at the rounded outer lip (road surface dropped by BEVEL_H).
			top_l = final_pos - right + Vector3(0, side_y_offset - SIDE_BEVEL_H, 0)
			top_r = final_pos + right + Vector3(0, side_y_offset - SIDE_BEVEL_H, 0)

			var drop = 60.0
			if level_prefix == "canyon_chasm":
				# Keep embankment deep under elevated ramps; only soften near the
				# figure-8 lower-road crossing so the two paths don't form a solid wall.
				var dist_to_crossing = Vector2(final_pos.x, final_pos.z).distance_to(Vector2(0.0, -100.0))
				if dist_to_crossing < 45.0 and final_pos.y < 28.0:
					# Lower road near crossing: shorter skirt so upper jump stays open
					var t = clampf(dist_to_crossing / 45.0, 0.0, 1.0)
					var smooth_t = t * t * (3.0 - 2.0 * t)
					var target_y = lerpf(top_l.y - 18.0, top_l.y - drop, smooth_t)
					var target_flare = lerpf(0.8, 2.0, smooth_t)
					bot_l = top_l - right_dir * target_flare
					bot_l.y = target_y
					bot_r = top_r + right_dir * target_flare
					bot_r.y = target_y
				else:
					# Full dam walls under ramps / normal track - closed solid embankment
					var flare := 2.0
					bot_l = top_l - right_dir * flare - Vector3(0, drop, 0)
					bot_r = top_r + right_dir * flare - Vector3(0, drop, 0)
					# Never let the skirt float above a low chasm floor under hill jump
					if absf(final_pos.x - 150.0) < 30.0 and final_pos.z < -40.0 and final_pos.z > -145.0:
						bot_l.y = minf(bot_l.y, -15.0)
						bot_r.y = minf(bot_r.y, -15.0)
			else:
				bot_l = top_l - right_dir * 1.5 - Vector3(0, drop, 0)
				bot_r = top_r + right_dir * 1.5 - Vector3(0, drop, 0)

		var uv_y = offset * 0.2

		# Side-wall UVs: U runs down the wall (meters), V along the path - no constant-V.
		var wall_h_l: float = top_l.distance_to(bot_l)
		var wall_h_r: float = top_r.distance_to(bot_r)
		st.set_uv(Vector2(0.0, uv_y))
		st.add_vertex(top_l) # 4*i + 0
		st.set_uv(Vector2(wall_h_l * 0.15, uv_y))
		st.add_vertex(bot_l) # 4*i + 1
		st.set_uv(Vector2(0.0, uv_y))
		st.add_vertex(top_r) # 4*i + 2
		st.set_uv(Vector2(wall_h_r * 0.15, uv_y))
		st.add_vertex(bot_r) # 4*i + 3

		side_top_l.append(top_l)
		side_top_r.append(top_r)
		side_bot_l.append(bot_l)
		side_bot_r.append(bot_r)
		side_tangents.append(tangent.normalized() if tangent.length_squared() > 1e-8 else Vector3.FORWARD)

	# 2. INDEX GENERATION
	for i in range(point_count):
		if _segment_in_gap(curve, length, point_count, i):
			continue

		var base = i * 4
		var nxt = (i + 1) * 4

		# Side walls must face OUTWARD (visible + collidable from outside the ramp).
		# Left wall: outward = -right_dir
		st.add_index(base + 0); st.add_index(nxt + 0); st.add_index(base + 1)
		st.add_index(base + 1); st.add_index(nxt + 0); st.add_index(nxt + 1)

		# Right wall: outward = +right_dir
		st.add_index(base + 2); st.add_index(base + 3); st.add_index(nxt + 2)
		st.add_index(base + 3); st.add_index(nxt + 3); st.add_index(nxt + 2)

		# Bottom - normal faces downward (seen from under the bridge/dam)
		st.add_index(base + 1); st.add_index(base + 3); st.add_index(nxt + 1)
		st.add_index(base + 3); st.add_index(nxt + 3); st.add_index(nxt + 1)

	# Finish side walls as their own mesh. Do NOT inject more verts after generate_normals
	# (that corrupted indexing and created a giant bogus wall).
	st.generate_normals()
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = _save_resource(st.commit(), node_name)

	var final_side_mat = mat.duplicate()
	if not node_name.contains("Curbs") and final_side_mat is StandardMaterial3D:
		final_side_mat.albedo_color = final_side_mat.albedo_color.darkened(0.3)
	if final_side_mat is StandardMaterial3D:
		(final_side_mat as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED

	if track_layout_type == TrackLayoutType.CANYON and not node_name.contains("Curbs"):
		var rock_mat = StandardMaterial3D.new()
		rock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		var rock_tex = load("res://materials/dark_canyon_rock.png")
		var rock_normal = load("res://materials/dark_canyon_rock_normal.png")
		if rock_tex:
			rock_mat.albedo_texture = rock_tex
		if rock_normal:
			rock_mat.roughness = 0.9
			rock_mat.normal_enabled = true
			rock_mat.normal_texture = rock_normal
			rock_mat.normal_scale = 1.5
		_configure_triplanar_pbr(rock_mat, 0.05, 8.0)
		rock_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		final_side_mat = rock_mat

		# Separate end-cap mesh (own verts + normals) so triplanar is not warped and
		# side-wall geometry stays intact.
		var cap_st := SurfaceTool.new()
		cap_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var cap_vert := 0
		for i in range(point_count):
			if _segment_in_gap(curve, length, point_count, i):
				continue
			var prev_gap := (
					(i == 0 and is_loop and _segment_in_gap(curve, length, point_count, point_count - 1))
					or (i > 0 and _segment_in_gap(curve, length, point_count, i - 1))
			)
			var next_gap := false
			if i + 1 < point_count:
				next_gap = _segment_in_gap(curve, length, point_count, i + 1)
			elif is_loop:
				next_gap = _segment_in_gap(curve, length, point_count, 0)
			if next_gap:
				cap_vert = _emit_embankment_end_cap(
						cap_st,
						side_top_l[i + 1], side_top_r[i + 1], side_bot_l[i + 1], side_bot_r[i + 1],
						side_tangents[i + 1], true, cap_vert)
			if prev_gap:
				cap_vert = _emit_embankment_end_cap(
						cap_st,
						side_top_l[i], side_top_r[i], side_bot_l[i], side_bot_r[i],
						side_tangents[i], false, cap_vert)
		if cap_vert > 0:
			var cap_mi := MeshInstance3D.new()
			cap_mi.name = node_name + "_EndCaps"
			cap_mi.mesh = _save_resource(cap_st.commit(), node_name + "_EndCaps")
			cap_mi.material_override = rock_mat
			mesh_instance.add_child(cap_mi)

	if track_layout_type == TrackLayoutType.MOUNTAIN or track_layout_type == TrackLayoutType.CANYON:
		var static_body = StaticBody3D.new()
		static_body.name = node_name + "_Collision"
		mesh_instance.add_child(static_body)

		var collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var trimesh_shape = mesh_instance.mesh.create_trimesh_shape()
		if trimesh_shape is ConcavePolygonShape3D:
			(trimesh_shape as ConcavePolygonShape3D).backface_collision = true
		collision_shape.shape = _save_resource(trimesh_shape, node_name + "_collision_shape")
		static_body.add_child(collision_shape)

		# Collision for end-cap seals (separate shape, same body)
		var cap_node2 = mesh_instance.get_node_or_null(node_name + "_EndCaps")
		if cap_node2 is MeshInstance3D and (cap_node2 as MeshInstance3D).mesh != null:
			var cap_col := CollisionShape3D.new()
			cap_col.name = "EndCapCollision"
			var cap_shape = (cap_node2 as MeshInstance3D).mesh.create_trimesh_shape()
			if cap_shape is ConcavePolygonShape3D:
				(cap_shape as ConcavePolygonShape3D).backface_collision = true
			cap_col.shape = _save_resource(cap_shape, node_name + "_endcap_collision_shape")
			static_body.add_child(cap_col)
	if track_layout_type == TrackLayoutType.CANYON and final_side_mat is ShaderMaterial:
		final_side_mat.set_shader_parameter("use_world_uv", false)
		final_side_mat.set_shader_parameter("uv_scale", 4.0)

	mesh_instance.material_override = final_side_mat
	add_child(mesh_instance)

func _generate_water():
	var water = MeshInstance3D.new()
	water.name = "Water_Surface"
	var plane = PlaneMesh.new()
	if level_prefix == "pinecrest_ridge":
		water.position = Vector3(0, -2.5, 0)
	else:
		water.position = Vector3(0, -10.0, 0) # Water level (below terrain base)

	# Create a high-quality water shader material
	var mat = ShaderMaterial.new()
	mat.shader = load("res://water.gdshader")

	# Create a FastNoiseLite texture for the waves
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.02
	var noise_tex = NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.as_normal_map = true
	noise_tex.noise = noise

	mat.set_shader_parameter("noise_tex", noise_tex)
	mat.set_shader_parameter("water_color", Color(0.1, 0.3, 0.6))
	mat.set_shader_parameter("shallow_color", Color(0.15, 0.45, 0.55))
	mat.set_shader_parameter("sky_tint", Color(0.55, 0.65, 0.75))
	mat.set_shader_parameter("sky_reflect", 0.45)
	mat.set_shader_parameter("transparency", 0.7)
	mat.set_shader_parameter("metallic", 0.55)
	mat.set_shader_parameter("roughness", 0.12)

	water.material_override = mat
	add_child(water)


## Surface Y of the chasm pit water (PlayerCart uses this for splash / drown).
const CHASM_PIT_WATER_Y := -1.8
const CHASM_PIT_CENTER := Vector3(150.0, CHASM_PIT_WATER_Y, -90.0)
const CHASM_PIT_HALF_EXTENTS := Vector2(45.0, 58.0) # XZ half-size of water volume, seamlessly filling the whole carved pond basin

## Desert Wadi — wide valley lake + river ford filling the whole valley basin.
const WADI_RIVER_WATER_Y := 1.70
const WADI_RIVER_BED_Y := -0.20
## River ribbon half-width for terrain carve + water shape.
const WADI_RIVER_HALF_WIDTH := 65.0
## Main river/ford channel through the low valley.
const WADI_RIVER_POLY: Array[Vector2] = [
	Vector2(70.0, -150.0),
	Vector2(110.0, -175.0),
	Vector2(160.0, -200.0),
	Vector2(205.0, -215.0),
	Vector2(250.0, -230.0),
	Vector2(295.0, -245.0),
	Vector2(330.0, -260.0),
]
## Wide valley lake basin filling the lowlands.
const WADI_LAKE_CENTER := Vector2(195.0, -208.0)
const WADI_LAKE_RADIUS := Vector2(130.0, 105.0) # X / Z ellipse radii extending into hills
## Influence threshold for water mesh cells.
const WADI_WATER_MESH_THRESH := 0.005


func _wadi_river_influence(px: float, pz: float) -> float:
	## 1 near river centerline / lake basin, 0 outside the banks.
	if level_prefix != "desert_wadi":
		return 0.0
	var p := Vector2(px, pz)
	var best_d := 1.0e9
	for i in range(WADI_RIVER_POLY.size() - 1):
		var a: Vector2 = WADI_RIVER_POLY[i]
		var b: Vector2 = WADI_RIVER_POLY[i + 1]
		var ab: Vector2 = b - a
		var len_sq: float = ab.length_squared()
		var t: float = 0.0 if len_sq < 1e-6 else clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
		var closest: Vector2 = a + ab * t
		best_d = minf(best_d, p.distance_to(closest))
	var ribbon: float = 0.0
	if best_d < WADI_RIVER_HALF_WIDTH:
		var u: float = 1.0 - (best_d / WADI_RIVER_HALF_WIDTH)
		ribbon = u * u * (3.0 - 2.0 * u)
	# Ellipse lake basin filling the low valley
	var d_lake := Vector2(
			(p.x - WADI_LAKE_CENTER.x) / WADI_LAKE_RADIUS.x,
			(p.y - WADI_LAKE_CENTER.y) / WADI_LAKE_RADIUS.y
	)
	var r2: float = d_lake.length_squared()
	var lake: float = 0.0
	if r2 < 1.0:
		var v: float = 1.0 - r2
		lake = v * v * (3.0 - 2.0 * v)
	return maxf(ribbon, lake)


## True when XZ is inside the visible wadi lake/river water shape.
func is_wadi_water_at(px: float, pz: float) -> bool:
	return _wadi_river_influence(px, pz) >= WADI_WATER_MESH_THRESH


func add_wadi_river_water() -> void:
	var existing = get_node_or_null("WadiRiverWater")
	if existing != null:
		existing.free()
	# Tight bounds around lake + river only (no huge map-wide rectangle)
	var min_x := WADI_LAKE_CENTER.x - WADI_LAKE_RADIUS.x
	var max_x := WADI_LAKE_CENTER.x + WADI_LAKE_RADIUS.x
	var min_z := WADI_LAKE_CENTER.y - WADI_LAKE_RADIUS.y
	var max_z := WADI_LAKE_CENTER.y + WADI_LAKE_RADIUS.y
	for p in WADI_RIVER_POLY:
		min_x = minf(min_x, p.x - WADI_RIVER_HALF_WIDTH)
		max_x = maxf(max_x, p.x + WADI_RIVER_HALF_WIDTH)
		min_z = minf(min_z, p.y - WADI_RIVER_HALF_WIDTH)
		max_z = maxf(max_z, p.y + WADI_RIVER_HALF_WIDTH)
	# Soft pad reaching well into the rising hill banks
	min_x -= 14.0
	max_x += 14.0
	min_z -= 14.0
	max_z += 14.0

	# Build a shaped water mesh: only quads where influence is above threshold
	# so water doesn't appear as a cut-off rectangle over hills.
	var res_x := 72
	var res_z := 56
	var wet: PackedFloat32Array = PackedFloat32Array()
	wet.resize((res_x + 1) * (res_z + 1))
	for iz in range(res_z + 1):
		var z: float = lerpf(min_z, max_z, float(iz) / float(res_z))
		for ix in range(res_x + 1):
			var x: float = lerpf(min_x, max_x, float(ix) / float(res_x))
			wet[iz * (res_x + 1) + ix] = _wadi_river_influence(x, z)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y: float = WADI_RIVER_WATER_Y
	for iz in range(res_z):
		for ix in range(res_x):
			var i00: int = iz * (res_x + 1) + ix
			var i10: int = i00 + 1
			var i01: int = i00 + (res_x + 1)
			var i11: int = i01 + 1
			# Cell is water if average influence is strong enough
			var avg: float = (wet[i00] + wet[i10] + wet[i01] + wet[i11]) * 0.25
			if avg < WADI_WATER_MESH_THRESH:
				continue
			var x0: float = lerpf(min_x, max_x, float(ix) / float(res_x))
			var x1: float = lerpf(min_x, max_x, float(ix + 1) / float(res_x))
			var z0: float = lerpf(min_z, max_z, float(iz) / float(res_z))
			var z1: float = lerpf(min_z, max_z, float(iz + 1) / float(res_z))
			var v00 := Vector3(x0, y, z0)
			var v10 := Vector3(x1, y, z0)
			var v01 := Vector3(x0, y, z1)
			var v11 := Vector3(x1, y, z1)
			# Two triangles, normal up
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0, 0)); st.add_vertex(v00)
			st.set_uv(Vector2(1, 0)); st.add_vertex(v10)
			st.set_uv(Vector2(0, 1)); st.add_vertex(v01)
			st.set_uv(Vector2(1, 0)); st.add_vertex(v10)
			st.set_uv(Vector2(1, 1)); st.add_vertex(v11)
			st.set_uv(Vector2(0, 1)); st.add_vertex(v01)

	var mesh: ArrayMesh = st.commit()
	if mesh.get_surface_count() == 0:
		push_warning("[Wadi] water mesh empty — check lake/river influence")
		return

	var water := MeshInstance3D.new()
	water.name = "WadiRiverWater"
	water.mesh = mesh
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Gameplay bounds: tight AABB of the lake/river shape
	var half := Vector2((max_x - min_x) * 0.5, (max_z - min_z) * 0.5)
	var cx: float = (min_x + max_x) * 0.5
	var cz: float = (min_z + max_z) * 0.5
	water.set_meta("water_surface_y", WADI_RIVER_WATER_Y)
	water.set_meta("water_half_xz", half)
	water.set_meta("water_center_xz", Vector2(cx, cz))
	# Explicit world AABB — do not derive from node.global_position (mesh is world-space verts).
	water.set_meta("water_bounds_min", Vector2(min_x, min_z))
	water.set_meta("water_bounds_max", Vector2(max_x, max_z))

	var mat := ShaderMaterial.new()
	mat.shader = load("res://water.gdshader")
	var noise := FastNoiseLite.new()
	noise.seed = 91
	noise.frequency = 0.022
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.1
	noise.fractal_gain = 0.45
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.as_normal_map = true
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.noise = noise
	mat.set_shader_parameter("noise_tex", noise_tex)
	mat.set_shader_parameter("water_color", Color(0.08, 0.18, 0.2))
	mat.set_shader_parameter("shallow_color", Color(0.32, 0.42, 0.28))
	mat.set_shader_parameter("sky_tint", Color(0.72, 0.8, 0.88))
	mat.set_shader_parameter("sky_reflect", 0.62)
	mat.set_shader_parameter("transparency", 0.32)
	mat.set_shader_parameter("metallic", 0.58)
	mat.set_shader_parameter("roughness", 0.1)
	mat.set_shader_parameter("wave_speed", 0.028)
	mat.set_shader_parameter("wave_strength", 0.48)
	mat.set_shader_parameter("wave_height", 0.38)
	mat.set_shader_parameter("wave_scale", 0.72)
	water.material_override = mat
	add_child(water)
	if Engine.is_editor_hint() and get_tree():
		var root = get_tree().edited_scene_root
		if root:
			water.owner = root
		noise_tex.changed.emit()


## Harbor pier — flat dock circuit over dark water. Used only when level_prefix == "harbor_pier".
const HARBOR_WATER_Y := 1.55
const HARBOR_SEABED_Y := -7.5
const HARBOR_DECK_Y := 3.55
const HARBOR_PIER_W := 16.0
const HARBOR_PIER_THICK := 2.55


## Murky green/brown water filling the first hill-jump pit on Canyon Chasm.
## Pit floor is carved near y=-8..-12; surface sits a few meters above that.
func add_chasm_pit_water() -> void:
	var existing = get_node_or_null("ChasmPitWater")
	if existing != null:
		existing.free()

	var water := MeshInstance3D.new()
	water.name = "ChasmPitWater"
	var plane := PlaneMesh.new()
	# Covers the jump gap between large ramp takeoff (~z -40) and landing (~z -140).
	plane.size = Vector2(CHASM_PIT_HALF_EXTENTS.x * 2.0, CHASM_PIT_HALF_EXTENTS.y * 2.0)
	# Dense mesh so large vertex waves read clearly
	plane.subdivide_width = 64
	plane.subdivide_depth = 80
	water.mesh = plane
	water.position = CHASM_PIT_CENTER
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Metadata for carts (splash / drown volume)
	water.set_meta("water_surface_y", CHASM_PIT_WATER_Y)
	water.set_meta("water_half_xz", CHASM_PIT_HALF_EXTENTS)
	water.set_meta("water_center_xz", Vector2(CHASM_PIT_CENTER.x, CHASM_PIT_CENTER.z))
	water.set_meta("water_bounds_min", Vector2(CHASM_PIT_CENTER.x - CHASM_PIT_HALF_EXTENTS.x, CHASM_PIT_CENTER.z - CHASM_PIT_HALF_EXTENTS.y))
	water.set_meta("water_bounds_max", Vector2(CHASM_PIT_CENTER.x + CHASM_PIT_HALF_EXTENTS.x, CHASM_PIT_CENTER.z + CHASM_PIT_HALF_EXTENTS.y))

	var mat := ShaderMaterial.new()
	mat.shader = load("res://water.gdshader")

	var noise := FastNoiseLite.new()
	noise.seed = 42
	noise.frequency = 0.018 # larger noise features → bigger waves
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.as_normal_map = true
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.noise = noise

	# Green/brown canyon water — mostly opaque so sky specular shows
	mat.set_shader_parameter("noise_tex", noise_tex)
	mat.set_shader_parameter("water_color", Color(0.06, 0.09, 0.04))
	mat.set_shader_parameter("shallow_color", Color(0.2, 0.26, 0.09))
	mat.set_shader_parameter("sky_tint", Color(0.62, 0.72, 0.78)) # bright sky mirror
	mat.set_shader_parameter("sky_reflect", 0.85)
	mat.set_shader_parameter("transparency", 0.18) # mostly solid
	mat.set_shader_parameter("metallic", 0.72)
	mat.set_shader_parameter("roughness", 0.05)
	mat.set_shader_parameter("wave_speed", 0.03)
	mat.set_shader_parameter("wave_strength", 0.85)
	mat.set_shader_parameter("wave_height", 1.15) # large visible swells
	mat.set_shader_parameter("wave_scale", 0.55) # lower = bigger world waves

	water.material_override = mat
	add_child(water)

	# Keep visible/savable in the editor scene tree
	if Engine.is_editor_hint() and get_tree():
		var root = get_tree().edited_scene_root
		if root:
			water.owner = root
		# NoiseTexture2D often needs a nudge before it shows in the editor viewport
		noise_tex.changed.emit()

func _create_grass_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var w := 0.75 # half width
	var h := 1.15 # height
	var base_y := -0.35 # Root firmly sunk into terrain so slopes never expose bottom

	# Plane 1 (along X-axis)
	var v0 := Vector3(-w, base_y, 0.0)
	var v1 := Vector3(w, base_y, 0.0)
	var v2 := Vector3(w, h + base_y, 0.0)
	var v3 := Vector3(-w, h + base_y, 0.0)

	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v0)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(v1)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v2)

	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v0)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v2)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(v3)

	# Plane 2 (Crossed along Z-axis)
	var z0 := Vector3(0.0, base_y, -w)
	var z1 := Vector3(0.0, base_y, w)
	var z2 := Vector3(0.0, h + base_y, w)
	var z3 := Vector3(0.0, h + base_y, -w)

	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(z0)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(z1)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(z2)

	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(z0)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(z2)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(z3)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()

## ------------------------------------------------------------------
## Fast grass helpers
## ------------------------------------------------------------------

# Pre-bake the track curve into a flat array of XZ positions (Vector2).
# Using a coarse sample interval is fine – we only need to approximate
# the nearest road distance, not follow the curve exactly.
func _bake_path_points(curve: Curve3D, sample_interval: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var length = curve.get_baked_length()
	var t := 0.0
	while t <= length:
		var p = curve.sample_baked(t)
		pts.append(Vector2(p.x, p.z))
		t += sample_interval
	return pts

# Squared distance from point P to the nearest sample in the baked array.
# Returns the squared distance so we can compare against (min_dist^2) cheaply.
func _sq_dist_to_path(px: float, pz: float, baked: PackedVector2Array) -> float:
	var best_sq := INF
	var p2 := Vector2(px, pz)
	for pt in baked:
		var d = p2.distance_squared_to(pt)
		if d < best_sq:
			best_sq = d
	return best_sq

func _generate_terrain_grass():
	var target_count: int = terrain_grass_count
	if target_count <= 0: return
	
	if not track_path:
		track_path = get_node_or_null("../TrackPath")
	if not track_path:
		track_path = get_node_or_null("TrackPath")
	if not track_path:
		push_error("TerrainGenerator: cannot generate grass without a valid track_path!")
		return
	
	var curve = _get_world_curve()
	
	# --- CRITICAL: Match noise settings exactly to the terrain mesh (seed 12345, octaves 4) ---
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_frequency
	noise.seed = 12345
	noise.fractal_octaves = 4
	
	var grass_mesh = _create_grass_mesh()
	var shader = load("res://grass_billboard.gdshader") as Shader
	if not shader:
		shader = Shader.new()
		shader.code = "shader_type spatial;\nrender_mode cull_disabled, diffuse_toon, specular_disabled, depth_draw_opaque;\n\nuniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;\nuniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);\nuniform float max_dist = 350.0;\nuniform float fade_r = 60.0;\n\nuniform vec3 player_positions[8];\nuniform int player_count = 0;\n\nvoid vertex() {\n\tvec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\tfloat dist = length(view_pos);\n\tif (dist > max_dist) {\n\t\tVERTEX = vec3(0.0);\n\t} else {\n\t\tif (dist > max_dist - fade_r) {\n\t\t\tfloat fade = (max_dist - dist) / fade_r;\n\t\t\tVERTEX *= fade;\n\t\t}\n\t\tfloat height_factor = clamp(1.0 - UV.y, 0.0, 1.0);\n\t\tif (player_count > 0 && height_factor > 0.05) {\n\t\t\tvec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\t\t\tvec3 total_push = vec3(0.0);\n\t\t\tfor (int i = 0; i < player_count; i++) {\n\t\t\t\tvec3 p_pos = player_positions[i];\n\t\t\t\tvec3 diff = world_pos - p_pos;\n\t\t\t\tfloat d_xz_sq = diff.x * diff.x + diff.z * diff.z;\n\t\t\t\tfloat radius = 2.4;\n\t\t\t\tif (d_xz_sq < radius * radius && abs(diff.y) < 2.0) {\n\t\t\t\t\tfloat d = sqrt(max(d_xz_sq, 0.0001));\n\t\t\t\t\tfloat push = (1.0 - d / radius);\n\t\t\t\t\tpush = push * push * height_factor;\n\t\t\t\t\tvec2 dir = diff.xz / d;\n\t\t\t\t\ttotal_push.x += dir.x * push * 1.6;\n\t\t\t\t\ttotal_push.z += dir.y * push * 1.6;\n\t\t\t\t\ttotal_push.y -= push * 0.45;\n\t\t\t\t}\n\t\t\t}\n\t\t\tif (dot(total_push, total_push) > 0.0001) {\n\t\t\t\tmat3 model_rot = mat3(MODEL_MATRIX);\n\t\t\t\tfloat sq_scale = max(dot(model_rot[0], model_rot[0]), 0.0001);\n\t\t\t\tvec3 local_delta = (total_push * model_rot) / sq_scale;\n\t\t\t\tVERTEX += local_delta;\n\t\t\t}\n\t\t}\n\t}\n}\n\nvoid fragment() {\n\tvec4 tex_color = texture(albedo_texture, UV);\n\tALBEDO = tex_color.rgb * albedo_tint.rgb;\n\tALPHA = tex_color.a;\n\tALPHA_SCISSOR_THRESHOLD = 0.4;\n\tROUGHNESS = 1.0;\n\tEMISSION = ALBEDO * 0.12;\n}"
	
	var mat_path = "res://generated/grass/grass_material.res"
	var saved_mat: Material
	if ResourceLoader.exists(mat_path):
		saved_mat = load(mat_path)
	if not saved_mat:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("max_dist", grass_visibility_range)
		mat.set_shader_parameter("fade_r", 60.0)
		var tex_path = "res://sprites/grass.png"
		if ResourceLoader.exists(tex_path):
			mat.set_shader_parameter("albedo_texture", load(tex_path))
		saved_mat = _save_resource(mat, "grass_material", "grass")
	else:
		if saved_mat is ShaderMaterial:
			saved_mat.set_shader_parameter("max_dist", grass_visibility_range)
			saved_mat.set_shader_parameter("fade_r", 60.0)
	
	var half_x := terrain_size.x * 0.5
	var half_z := terrain_size.y * 0.5
	var start_x := -half_x
	var start_z := -half_z

	# ---------------------------------------------------------------
	# Track spatial mask: MUST match _generate_mesh exactly (85.0m margin)
	# ---------------------------------------------------------------
	var mask_res: int = 50
	var cell_size_x: float = terrain_size.x / float(mask_res)
	var cell_size_z: float = terrain_size.y / float(mask_res)
	var track_mask: PackedByteArray = _build_track_spatial_mask(curve, mask_res, cell_size_x, cell_size_z, start_x, start_z, 85.0)

	# Tight road exclusion (road half width + 0.6m curb margin)
	var min_road_dist := road_width * 0.5 + 0.6
	
	# Precalculate visual height grid if running standalone without rebuilding whole mesh
	if _visual_heights.is_empty():
		print("Precomputing terrain height grid for grass placement...")
		var res: int = terrain_resolution
		var stride: int = res + 1
		_visual_heights.resize(stride * stride)
		var step_x: float = terrain_size.x / float(res)
		var step_z: float = terrain_size.y / float(res)
		for r in range(stride):
			var cz: float = start_z + r * step_z
			var mask_cz: int = clampi(int((cz - start_z) / cell_size_z), 0, mask_res - 1)
			var row_mask_offset: int = mask_cz * mask_res
			for c in range(stride):
				var cx: float = start_x + c * step_x
				var mask_cx: int = clampi(int((cx - start_x) / cell_size_x), 0, mask_res - 1)
				var is_near: bool = (track_mask[row_mask_offset + mask_cx] == 1)
				_visual_heights[r * stride + c] = _get_terrain_height(cx, cz, noise, curve, false, is_near)
	
	var num_chunks: int = grass_grid_size
	var chunk_w := terrain_size.x / float(num_chunks)
	var chunk_d := terrain_size.y / float(num_chunks)
	
	var chunk_transforms := []
	chunk_transforms.resize(num_chunks * num_chunks)
	for i in range(num_chunks * num_chunks):
		chunk_transforms[i] = []
	
	var attempts: int = int(target_count * 3.5)
	var placed := 0
	var edge_limit_x := half_x * 0.98
	var edge_limit_z := half_z * 0.98
	
	print("Generating grass placements: target %d..." % target_count)
	for _i in range(attempts):
		if placed >= target_count:
			break
		
		var px := randf_range(-edge_limit_x, edge_limit_x)
		var pz := randf_range(-edge_limit_z, edge_limit_z)
		
		# Instantaneous exact height match via bilinear sampling of the terrain mesh
		var height := _sample_cached_height(px, pz)
		
		# Precise road exclusion with vertical bridge clearance
		var closest_offset = curve.get_closest_offset(Vector3(px, height, pz))
		var track_pt = curve.sample_baked(closest_offset)
		var dist_to_road = Vector2(px - track_pt.x, pz - track_pt.z).length()
		if dist_to_road < min_road_dist:
			# If track is at ground level, exclude grass from road surface.
			# If track is an elevated bridge, allow grass on the hillside / under the span.
			if (track_pt.y - height) < 2.4:
				continue
		
		# Water, lake, and chasm pit exclusions
		if not no_water:
			# Lakeside lake basin at (-450, -500). Only skip water / wet beach —
			# hills around the large bridge must still get grass.
			var dist_to_lake = Vector2(px, pz).distance_to(Vector2(-450, -500))
			if height < -9.0:
				continue
			if dist_to_lake < 205.0 and height < 2.2:
				continue
		elif level_prefix == "canyon_chasm":
			if absf(px - 150.0) < 48.0 and pz > -150.0 and pz < -30.0:
				continue
			if height < -1.5:
				continue
		elif level_prefix == "desert_wadi":
			if is_wadi_water_at(px, pz) or height < 1.8:
				continue
		
		# Skip near-vertical cliffs (> 60 degrees)
		var h_px := _sample_cached_height(px + 1.5, pz)
		var h_pz := _sample_cached_height(px, pz + 1.5)
		if maxf(absf(h_px - height), absf(h_pz - height)) / 1.5 > 1.65:
			continue
		
		var pos := Vector3(px, height, pz)
		var rot := randf() * TAU
		var sh := randf_range(0.85, 1.45)
		var sw := randf_range(0.85, 1.25)
		var basis := Basis(Vector3.UP, rot).scaled(Vector3(sw, sh, sw))
		
		var col = clamp(int((px + half_x) / chunk_w), 0, num_chunks - 1)
		var row = clamp(int((pz + half_z) / chunk_d), 0, num_chunks - 1)
		var idx = row * num_chunks + col
		chunk_transforms[idx].append(Transform3D(basis, pos))
		placed += 1
	
	print("Grass placed: %d instances across %d chunks. Building multimeshes..." % [placed, num_chunks * num_chunks])
		
	# Clean up any existing GrassContainer and rebuild structure
	var old_container = get_node_or_null("GrassContainer")
	if old_container:
		remove_child(old_container)
		old_container.free()
		
	var grass_container = Node3D.new()
	grass_container.name = "GrassContainer"
	add_child(grass_container)
	
	if save_to_files:
		_clear_grass_directory()
	
	for r in range(num_chunks):
		for c in range(num_chunks):
			var idx = r * num_chunks + c
			var list = chunk_transforms[idx]
			if list.is_empty():
				continue
				
			var chunk_center_x = start_x + (c + 0.5) * chunk_w
			var chunk_center_z = start_z + (r + 0.5) * chunk_d
			var cc_cx = clampi(int((chunk_center_x - start_x) / cell_size_x), 0, mask_res - 1)
			var cc_cz = clampi(int((chunk_center_z - start_z) / cell_size_z), 0, mask_res - 1)
			var cc_is_near = (track_mask[cc_cz * mask_res + cc_cx] == 1)
			var center_height = _get_terrain_height(chunk_center_x, chunk_center_z, noise, curve, false, cc_is_near)
			var chunk_center = Vector3(chunk_center_x, center_height, chunk_center_z)
			
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "GrassChunk_%d_%d" % [c, r]
			mmi.position = chunk_center
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = grass_visibility_range
			mmi.visibility_range_end_margin = 50.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			grass_container.add_child(mmi)
			
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = false
			mm.use_custom_data = false
			mm.mesh = grass_mesh
			mm.instance_count = list.size()
			
			for i in range(list.size()):
				var t = list[i]
				t.origin -= chunk_center
				mm.set_instance_transform(i, t)
				
			mmi.multimesh = _save_resource(mm, "chunk_%d_%d" % [c, r], "grass")
			mmi.material_override = saved_mat
	
	print("Finished generating grass multimeshes.")


func _generate_harbor_world() -> void:
	# Only replace generated harbor nodes so hand-placed children on TerrainGenerator stay.
	for child_name in ["HarborSeabed", "HarborSeabedCollision", "HarborPiers", "HarborWater"]:
		var old = get_node_or_null(child_name)
		if old:
			remove_child(old)
			old.free()
	_add_harbor_seabed()
	add_harbor_water()
	_add_harbor_piers()


func add_harbor_water() -> void:
	if level_prefix != "harbor_pier":
		return
	var existing = get_node_or_null("HarborWater")
	if existing != null:
		existing.free()

	var water := MeshInstance3D.new()
	water.name = "HarborWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400.0, 1400.0)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	water.mesh = plane
	water.position = Vector3(0.0, HARBOR_WATER_Y, 0.0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta("water_surface_y", HARBOR_WATER_Y)
	water.set_meta("water_half_xz", Vector2(700.0, 700.0))
	water.set_meta("water_center_xz", Vector2.ZERO)
	water.set_meta("water_bounds_min", Vector2(-700.0, -700.0))
	water.set_meta("water_bounds_max", Vector2(700.0, 700.0))

	var mat := ShaderMaterial.new()
	mat.shader = load("res://water.gdshader")
	var noise := FastNoiseLite.new()
	noise.seed = 17
	noise.frequency = 0.016
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.as_normal_map = true
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.noise = noise
	mat.set_shader_parameter("noise_tex", noise_tex)
	# Dark, oily harbor water — low transparency so it reads almost black-green.
	mat.set_shader_parameter("water_color", Color(0.018, 0.03, 0.035))
	mat.set_shader_parameter("shallow_color", Color(0.05, 0.08, 0.075))
	mat.set_shader_parameter("deep_water_color", Color(0.008, 0.014, 0.018))
	mat.set_shader_parameter("sky_tint", Color(0.42, 0.48, 0.50))
	mat.set_shader_parameter("sky_reflect", 0.28)
	mat.set_shader_parameter("transparency", 0.10)
	mat.set_shader_parameter("metallic", 0.48)
	mat.set_shader_parameter("roughness", 0.22)
	mat.set_shader_parameter("wave_speed", 0.018)
	mat.set_shader_parameter("wave_strength", 0.42)
	mat.set_shader_parameter("wave_height", 0.22)
	mat.set_shader_parameter("wave_scale", 0.85)
	mat.set_shader_parameter("enable_water_edge_fade", true)
	mat.set_shader_parameter("water_fade_start", 520.0)
	mat.set_shader_parameter("water_fade_end", 780.0)
	water.material_override = mat
	add_child(water)
	if Engine.is_editor_hint() and get_tree():
		var root = get_tree().edited_scene_root
		if root:
			water.owner = root
		noise_tex.changed.emit()


func _add_harbor_seabed() -> void:
	var silt := StandardMaterial3D.new()
	silt.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	silt.albedo_color = Color(0.10, 0.11, 0.10)
	var silt_tex: Texture2D = load("res://materials/dirt.png") as Texture2D
	if silt_tex:
		silt.albedo_texture = silt_tex
		silt.uv1_scale = Vector3(0.04, 0.04, 0.04)
		silt.uv1_triplanar = true
	silt.roughness = 1.0
	silt.metallic = 0.0

	var bed := MeshInstance3D.new()
	bed.name = "HarborSeabed"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1600.0, 1600.0)
	bed.mesh = plane
	bed.position = Vector3(0.0, HARBOR_SEABED_Y, 0.0)
	bed.material_override = silt
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bed)

	var body := StaticBody3D.new()
	body.name = "HarborSeabedCollision"
	add_child(body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1600.0, 2.0, 1600.0)
	col.shape = shape
	col.position = Vector3(0.0, HARBOR_SEABED_Y - 1.0, 0.0)
	body.add_child(col)


func _harbor_deck_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.58, 0.50)
	var tex: Texture2D = load("res://materials/brick.png") as Texture2D
	if tex:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
		mat.uv1_triplanar = true
	mat.roughness = 0.92
	mat.metallic = 0.0
	return mat


func _harbor_side_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.36, 0.33)
	var tex: Texture2D = load("res://materials/brick.png") as Texture2D
	if tex:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(0.18, 0.18, 0.18)
		mat.uv1_triplanar = true
	mat.roughness = 0.96
	return mat


func _harbor_wood_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.30, 0.20)
	var tex: Texture2D = load("res://materials/dirt.png") as Texture2D
	if tex:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
		mat.uv1_triplanar = true
	mat.roughness = 0.88
	return mat


func _harbor_steel_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.30, 0.32)
	mat.metallic = 0.65
	mat.roughness = 0.40
	return mat


func _harbor_container_mat(albedo: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.metallic = 0.35
	mat.roughness = 0.55
	return mat


func _harbor_warehouse_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.38, 0.30)
	mat.roughness = 0.90
	return mat


func _harbor_add_box(parent: Node, box_name: String, center: Vector3, size: Vector3, yaw: float, mat: Material, group: String = "track_surface") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	if group != "":
		body.add_to_group(group)
	parent.add_child(body)
	body.position = center
	body.rotation.y = yaw
	var mesh_i := MeshInstance3D.new()
	mesh_i.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	mesh_i.mesh = box
	mesh_i.material_override = mat
	body.add_child(mesh_i)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body


func _harbor_add_sloped_box(parent: Node, box_name: String, p0: Vector3, p1: Vector3, width: float, thickness: float, mat: Material, group: String = "ramps") -> StaticBody3D:
	var mid: Vector3 = (p0 + p1) * 0.5
	var delta: Vector3 = p1 - p0
	var length: float = maxf(delta.length(), 0.2)
	var body := StaticBody3D.new()
	body.name = box_name
	if group != "":
		body.add_to_group(group)
	parent.add_child(body)
	body.transform = Transform3D(Basis.looking_at(delta / length, Vector3.UP), mid)
	var mesh_i := MeshInstance3D.new()
	mesh_i.name = "Mesh"
	var box := BoxMesh.new()
	box.size = Vector3(width, thickness, length)
	mesh_i.mesh = box
	mesh_i.material_override = mat
	body.add_child(mesh_i)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, thickness, length)
	col.shape = shape
	body.add_child(col)
	return body


func _harbor_add_piles(parent: Node, x0: float, x1: float, z0: float, z1: float, along_x: bool) -> void:
	var pile_mat := StandardMaterial3D.new()
	pile_mat.albedo_color = Color(0.22, 0.18, 0.14)
	pile_mat.roughness = 0.95
	var step := 11.0
	if along_x:
		var z_edges := [minf(z0, z1), maxf(z0, z1)]
		var xa := minf(x0, x1) + 2.0
		var xb := maxf(x0, x1) - 2.0
		var x: float = xa
		var idx := 0
		while x <= xb:
			for z_e in z_edges:
				var cyl := MeshInstance3D.new()
				cyl.name = parent.name + "_PileX_%d_%d" % [int(x), idx]
				idx += 1
				var mesh := CylinderMesh.new()
				mesh.top_radius = 0.28
				mesh.bottom_radius = 0.32
				mesh.height = HARBOR_DECK_Y - HARBOR_SEABED_Y + 0.4
				cyl.mesh = mesh
				cyl.material_override = pile_mat
				cyl.position = Vector3(x, (HARBOR_DECK_Y + HARBOR_SEABED_Y) * 0.5, z_e)
				parent.add_child(cyl)
			x += step
	else:
		var x_edges := [minf(x0, x1), maxf(x0, x1)]
		var za := minf(z0, z1) + 2.0
		var zb := maxf(z0, z1) - 2.0
		var z: float = za
		var idx2 := 0
		while z <= zb:
			for x_e in x_edges:
				var cyl := MeshInstance3D.new()
				cyl.name = parent.name + "_PileZ_%d_%d" % [int(z), idx2]
				idx2 += 1
				var mesh := CylinderMesh.new()
				mesh.top_radius = 0.28
				mesh.bottom_radius = 0.32
				mesh.height = HARBOR_DECK_Y - HARBOR_SEABED_Y + 0.4
				cyl.mesh = mesh
				cyl.material_override = pile_mat
				cyl.position = Vector3(x_e, (HARBOR_DECK_Y + HARBOR_SEABED_Y) * 0.5, z)
				parent.add_child(cyl)
			z += step


func _harbor_add_axis_pier(parent: Node, pier_name: String, x0: float, z0: float, x1: float, z1: float, deck_mat: Material, side_mat: Material) -> void:
	var cx: float = (x0 + x1) * 0.5
	var cz: float = (z0 + z1) * 0.5
	var along_x: bool = absf(x1 - x0) >= absf(z1 - z0)
	var length: float = maxf(absf(x1 - x0), absf(z1 - z0))
	var yaw: float = 0.0 if along_x else PI * 0.5
	var deck_y: float = HARBOR_DECK_Y
	var thick: float = HARBOR_PIER_THICK
	var size := Vector3(length, thick, HARBOR_PIER_W)
	_harbor_add_box(parent, pier_name, Vector3(cx, deck_y - thick * 0.5, cz), size, yaw, deck_mat, "track_surface")
	# Slightly inset skirt so the deck lip stays visible
	var skirt := Vector3(length - 0.4, thick + 0.15, HARBOR_PIER_W - 0.6)
	_harbor_add_box(parent, pier_name + "_Hull", Vector3(cx, deck_y - thick * 0.5 - 0.08, cz), skirt, yaw, side_mat, "")
	var half_w: float = HARBOR_PIER_W * 0.5
	if along_x:
		_harbor_add_piles(parent, x0, x1, cz - half_w, cz + half_w, true)
	else:
		_harbor_add_piles(parent, cx - half_w, cx + half_w, z0, z1, false)


func _harbor_add_corner_junction(parent: Node, junc_name: String, center: Vector2, width: float, deck_mat: Material, side_mat: Material) -> void:
	var cx: float = center.x
	var cz: float = center.y
	var deck_y: float = HARBOR_DECK_Y
	var thick: float = HARBOR_PIER_THICK
	var size := Vector3(width, thick, width)
	# Solid deck block filling the entire corner intersection
	_harbor_add_box(parent, junc_name, Vector3(cx, deck_y - thick * 0.5, cz), size, 0.0, deck_mat, "track_surface")
	# Hull skirt
	var skirt := Vector3(width - 0.4, thick + 0.15, width - 0.4)
	_harbor_add_box(parent, junc_name + "_Hull", Vector3(cx, deck_y - thick * 0.5 - 0.08, cz), skirt, 0.0, side_mat, "")
	
	# 4 Corner support piles
	var h_w: float = width * 0.5 - 1.8
	var pile_mat := StandardMaterial3D.new()
	pile_mat.albedo_color = Color(0.22, 0.18, 0.14)
	pile_mat.roughness = 0.95
	var corner_offsets := [
		Vector2(-h_w, -h_w), Vector2(h_w, -h_w),
		Vector2(-h_w, h_w), Vector2(h_w, h_w)
	]
	for idx in range(corner_offsets.size()):
		var off = corner_offsets[idx]
		var cyl := MeshInstance3D.new()
		cyl.name = junc_name + "_Pile_%d" % idx
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.32
		mesh.bottom_radius = 0.36
		mesh.height = HARBOR_DECK_Y - HARBOR_SEABED_Y + 0.4
		cyl.mesh = mesh
		cyl.material_override = pile_mat
		cyl.position = Vector3(cx + off.x, (HARBOR_DECK_Y + HARBOR_SEABED_Y) * 0.5, cz + off.y)
		parent.add_child(cyl)


func _harbor_add_dock_platform(parent: Node, plat_name: String, x_min: float, x_max: float, z_min: float, z_max: float, deck_mat: Material, side_mat: Material) -> void:
	var cx: float = (x_min + x_max) * 0.5
	var cz: float = (z_min + z_max) * 0.5
	var len_x: float = absf(x_max - x_min)
	var len_z: float = absf(z_max - z_min)
	var deck_y: float = HARBOR_DECK_Y
	var thick: float = HARBOR_PIER_THICK
	
	# Solid platform deck under buildings and containers
	_harbor_add_box(parent, plat_name, Vector3(cx, deck_y - thick * 0.5, cz), Vector3(len_x, thick, len_z), 0.0, deck_mat, "track_surface")
	# Platform skirt
	_harbor_add_box(parent, plat_name + "_Hull", Vector3(cx, deck_y - thick * 0.5 - 0.08, cz), Vector3(len_x - 0.4, thick + 0.15, len_z - 0.4), 0.0, side_mat, "")
	
	# Piles in regular grid along perimeter
	var pile_mat := StandardMaterial3D.new()
	pile_mat.albedo_color = Color(0.22, 0.18, 0.14)
	pile_mat.roughness = 0.95
	var step := 12.0
	var p_idx := 0
	for z_edge in [z_min + 1.5, z_max - 1.5]:
		var x: float = x_min + 2.0
		while x <= x_max - 2.0:
			var cyl := MeshInstance3D.new()
			cyl.name = plat_name + "_PileX_%d_%d" % [int(x), p_idx]
			p_idx += 1
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.28
			mesh.bottom_radius = 0.32
			mesh.height = HARBOR_DECK_Y - HARBOR_SEABED_Y + 0.4
			cyl.mesh = mesh
			cyl.material_override = pile_mat
			cyl.position = Vector3(x, (HARBOR_DECK_Y + HARBOR_SEABED_Y) * 0.5, z_edge)
			parent.add_child(cyl)
			x += step
	for x_edge in [x_min + 1.5, x_max - 1.5]:
		var z: float = z_min + 2.0
		while z <= z_max - 2.0:
			var cyl := MeshInstance3D.new()
			cyl.name = plat_name + "_PileZ_%d_%d" % [int(z), p_idx]
			p_idx += 1
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.28
			mesh.bottom_radius = 0.32
			mesh.height = HARBOR_DECK_Y - HARBOR_SEABED_Y + 0.4
			cyl.mesh = mesh
			cyl.material_override = pile_mat
			cyl.position = Vector3(x_edge, (HARBOR_DECK_Y + HARBOR_SEABED_Y) * 0.5, z)
			parent.add_child(cyl)
			z += step


func _harbor_add_container(parent: Node, c_name: String, center: Vector3, size: Vector3, yaw: float, color: Color) -> void:
	var mat := _harbor_container_mat(color)
	var body := _harbor_add_box(parent, c_name, center, size, yaw, mat, "props")
	
	# Dark steel corner posts for authentic shipping container silhouette
	var frame_mat := _harbor_steel_mat()
	var post_w := 0.24
	var h_x := size.x * 0.5 - post_w * 0.5
	var h_z := size.z * 0.5 - post_w * 0.5
	var corners := [
		Vector3(-h_x, 0, -h_z), Vector3(h_x, 0, -h_z),
		Vector3(-h_x, 0, h_z), Vector3(h_x, 0, h_z)
	]
	for c_pos in corners:
		var post := MeshInstance3D.new()
		var p_mesh := BoxMesh.new()
		p_mesh.size = Vector3(post_w, size.y + 0.04, post_w)
		post.mesh = p_mesh
		post.material_override = frame_mat
		post.position = c_pos
		body.add_child(post)


func _harbor_add_elevated_viaduct(parent: Node, deck_mat: Material, side_mat: Material, steel_mat: Material) -> void:
	var root := Node3D.new()
	root.name = "HarborViaduct"
	parent.add_child(root)
	
	var base_y: float = HARBOR_DECK_Y
	var peak_y: float = 10.55
	var w: float = HARBOR_PIER_W
	var thick: float = 1.2
	
	# 1. Incline Ramp: z from -25.0 to 10.0 (35m length, 7m rise)
	_harbor_add_sloped_box(root, "Viaduct_InclineRamp",
		Vector3(185.0, base_y - 0.4, -25.0),
		Vector3(185.0, peak_y - 0.4, 10.0),
		w, thick, deck_mat, "track_surface")
	# Incline Side Skirts / Guardrails
	_harbor_add_sloped_box(root, "Viaduct_Incline_RailL",
		Vector3(177.3, base_y + 0.4, -25.0),
		Vector3(177.3, peak_y + 0.4, 10.0),
		0.4, 1.4, steel_mat, "")
	_harbor_add_sloped_box(root, "Viaduct_Incline_RailR",
		Vector3(192.7, base_y + 0.4, -25.0),
		Vector3(192.7, peak_y + 0.4, 10.0),
		0.4, 1.4, steel_mat, "")

	# 2. Level High Skyway Span: z from 10.0 to 65.0 (55m length)
	_harbor_add_box(root, "Viaduct_HighDeck",
		Vector3(185.0, peak_y - thick * 0.5, 37.5),
		Vector3(w, thick, 55.0), 0.0, deck_mat, "track_surface")
	_harbor_add_box(root, "Viaduct_HighHull",
		Vector3(185.0, peak_y - thick * 0.5 - 0.1, 37.5),
		Vector3(w - 0.4, thick + 0.2, 54.6), 0.0, side_mat, "")

	# High Skyway Guardrails
	_harbor_add_box(root, "Viaduct_HighRail_L",
		Vector3(177.3, peak_y + 0.7, 37.5),
		Vector3(0.4, 1.4, 55.0), 0.0, steel_mat, "")
	_harbor_add_box(root, "Viaduct_HighRail_R",
		Vector3(192.7, peak_y + 0.7, 37.5),
		Vector3(0.4, 1.4, 55.0), 0.0, steel_mat, "")

	# Overhead Steel Arch Truss Frames on Skyway
	for z_truss in [18.0, 32.0, 46.0, 58.0]:
		_harbor_add_box(root, "Viaduct_Truss_L_%d" % int(z_truss),
			Vector3(177.3, peak_y + 3.0, z_truss), Vector3(0.6, 6.0, 0.6), 0.0, steel_mat, "")
		_harbor_add_box(root, "Viaduct_Truss_R_%d" % int(z_truss),
			Vector3(192.7, peak_y + 3.0, z_truss), Vector3(0.6, 6.0, 0.6), 0.0, steel_mat, "")
		_harbor_add_box(root, "Viaduct_Truss_Top_%d" % int(z_truss),
			Vector3(185.0, peak_y + 6.0, z_truss), Vector3(16.0, 0.6, 0.6), 0.0, steel_mat, "")

	# 3. Descent Ramp: z from 65.0 to 95.0 (30m length, 7m drop)
	_harbor_add_sloped_box(root, "Viaduct_DescentRamp",
		Vector3(185.0, peak_y - 0.4, 65.0),
		Vector3(185.0, base_y - 0.4, 95.0),
		w, thick, deck_mat, "track_surface")
	_harbor_add_sloped_box(root, "Viaduct_Descent_RailL",
		Vector3(177.3, peak_y + 0.4, 65.0),
		Vector3(177.3, base_y + 0.4, 95.0),
		0.4, 1.4, steel_mat, "")
	_harbor_add_sloped_box(root, "Viaduct_Descent_RailR",
		Vector3(192.7, peak_y + 0.4, 65.0),
		Vector3(192.7, base_y + 0.4, 95.0),
		0.4, 1.4, steel_mat, "")

	# Massive Concrete/Steel Viaduct Support Pylons down to seabed
	for z_pylon in [-8.0, 10.0, 24.0, 38.0, 52.0, 65.0, 78.0]:
		var cur_deck_y = peak_y
		if z_pylon < 10.0:
			var t = (z_pylon - (-25.0)) / 35.0
			cur_deck_y = lerpf(base_y, peak_y, clampf(t, 0.0, 1.0))
		elif z_pylon > 65.0:
			var t = (z_pylon - 65.0) / 30.0
			cur_deck_y = lerpf(peak_y, base_y, clampf(t, 0.0, 1.0))
			
		var pylon_height = cur_deck_y - HARBOR_SEABED_Y
		var pylon_mid_y = (cur_deck_y + HARBOR_SEABED_Y) * 0.5
		
		# Left leg
		_harbor_add_box(root, "Viaduct_Pylon_L_%d" % int(z_pylon),
			Vector3(178.5, pylon_mid_y, z_pylon), Vector3(1.6, pylon_height, 1.6), 0.0, side_mat, "")
		# Right leg
		_harbor_add_box(root, "Viaduct_Pylon_R_%d" % int(z_pylon),
			Vector3(191.5, pylon_mid_y, z_pylon), Vector3(1.6, pylon_height, 1.6), 0.0, side_mat, "")
		# Cross beam
		_harbor_add_box(root, "Viaduct_Pylon_Cross_%d" % int(z_pylon),
			Vector3(185.0, cur_deck_y - 1.2, z_pylon), Vector3(15.0, 1.4, 1.8), 0.0, side_mat, "")


func _add_harbor_piers() -> void:
	var root := Node3D.new()
	root.name = "HarborPiers"
	add_child(root)

	var deck_mat := _harbor_deck_mat()
	var side_mat := _harbor_side_mat()
	var wood_mat := _harbor_wood_mat()
	var steel_mat := _harbor_steel_mat()
	var warehouse_mat := _harbor_warehouse_mat()

	# Container colors
	var col_blue := Color(0.12, 0.28, 0.58)
	var col_red := Color(0.68, 0.16, 0.14)
	var col_orange := Color(0.82, 0.42, 0.10)
	var col_green := Color(0.18, 0.48, 0.28)
	var col_yellow := Color(0.78, 0.65, 0.18)

	# ── 1. Corner Junctions (Gapless 16x16 dock blocks at all turns) ──
	_harbor_add_corner_junction(root, "Junction_NE", Vector2(185.0, -95.0), HARBOR_PIER_W, deck_mat, side_mat)
	_harbor_add_corner_junction(root, "Junction_SE", Vector2(185.0, 125.0), HARBOR_PIER_W, deck_mat, side_mat)
	_harbor_add_corner_junction(root, "Junction_BasinSouth", Vector2(80.0, 125.0), HARBOR_PIER_W, deck_mat, side_mat)
	_harbor_add_corner_junction(root, "Junction_BasinNorth", Vector2(80.0, 35.0), HARBOR_PIER_W, deck_mat, side_mat)
	_harbor_add_corner_junction(root, "Junction_WestBasinNorth", Vector2(-40.0, 35.0), HARBOR_PIER_W, deck_mat, side_mat)
	_harbor_add_corner_junction(root, "Junction_WestBasinSouth", Vector2(-40.0, 125.0), HARBOR_PIER_W, deck_mat, side_mat)
	_harbor_add_corner_junction(root, "Junction_SW", Vector2(-175.0, 125.0), HARBOR_PIER_W, deck_mat, side_mat)
	_harbor_add_corner_junction(root, "Junction_NW", Vector2(-175.0, -95.0), HARBOR_PIER_W, deck_mat, side_mat)

	# ── 2. Straight Track Piers (Gapless abutments to junctions) ──
	# North start pier (eastbound)
	_harbor_add_axis_pier(root, "HarborPier_Start", -167.0, -95.0, 56.0, -95.0, deck_mat, side_mat)
	# NE pier after jump
	_harbor_add_axis_pier(root, "HarborPier_NE", 110.0, -95.0, 177.0, -95.0, deck_mat, side_mat)
	# East pier top approach to viaduct
	_harbor_add_axis_pier(root, "HarborPier_EastApproachN", 185.0, -87.0, 185.0, -25.0, deck_mat, side_mat)
	# East pier bottom approach from viaduct to SE corner
	_harbor_add_axis_pier(root, "HarborPier_EastApproachS", 185.0, 95.0, 185.0, 117.0, deck_mat, side_mat)
	# South pier East straight
	_harbor_add_axis_pier(root, "HarborPier_SouthE", 177.0, 125.0, 88.0, 125.0, deck_mat, side_mat)
	
	# Central Basin Finger Pier (Northbound into basin)
	_harbor_add_axis_pier(root, "HarborPier_CentralFingerN", 80.0, 117.0, 80.0, 43.0, deck_mat, side_mat)
	# Cross-Basin Channel Pier (Westbound)
	_harbor_add_axis_pier(root, "HarborPier_CrossChannelE", 72.0, 35.0, 32.0, 35.0, deck_mat, side_mat)
	_harbor_add_axis_pier(root, "HarborPier_CrossChannelW", 8.0, 35.0, -32.0, 35.0, deck_mat, side_mat)
	# West Central Finger Pier (Southbound to rejoin south pier)
	_harbor_add_axis_pier(root, "HarborPier_WestCentralFingerS", -40.0, 43.0, -40.0, 117.0, deck_mat, side_mat)

	# South Pier West straight before jump
	_harbor_add_axis_pier(root, "HarborPier_SouthPreJump", -48.0, 125.0, -70.0, 125.0, deck_mat, side_mat)
	# South Pier West End after jump to SW corner
	_harbor_add_axis_pier(root, "HarborPier_SouthPostJump", -124.0, 125.0, -167.0, 125.0, deck_mat, side_mat)

	# West Pier South straight
	_harbor_add_axis_pier(root, "HarborPier_WestS", -175.0, 117.0, -175.0, 16.0, deck_mat, side_mat)
	# West Pier North straight
	_harbor_add_axis_pier(root, "HarborPier_WestN", -175.0, -8.0, -175.0, -87.0, deck_mat, side_mat)

	# ── 3. Elevated Viaduct on East Pier ──
	_harbor_add_elevated_viaduct(root, deck_mat, side_mat, steel_mat)

	# ── 4. Jump Ramps across Water Gaps ──
	var dy_up := 2.35
	var ramp_half := 0.32
	# Eastbound Jump (North Pier)
	_harbor_add_sloped_box(root, "HarborRamp_TakeoffE",
		Vector3(56.0, HARBOR_DECK_Y - ramp_half, -95.0),
		Vector3(70.0, HARBOR_DECK_Y + dy_up - ramp_half, -95.0),
		HARBOR_PIER_W - 0.4, 0.65, wood_mat, "ramps")
	_harbor_add_sloped_box(root, "HarborRamp_LandingE",
		Vector3(94.0, HARBOR_DECK_Y + 0.85 - ramp_half, -95.0),
		Vector3(110.0, HARBOR_DECK_Y - ramp_half, -95.0),
		HARBOR_PIER_W - 0.4, 0.65, wood_mat, "ramps")
	# Westbound Jump (South Pier)
	_harbor_add_sloped_box(root, "HarborRamp_TakeoffW",
		Vector3(-70.0, HARBOR_DECK_Y - ramp_half, 125.0),
		Vector3(-84.0, HARBOR_DECK_Y + dy_up - ramp_half, 125.0),
		HARBOR_PIER_W - 0.4, 0.65, wood_mat, "ramps")
	_harbor_add_sloped_box(root, "HarborRamp_LandingW",
		Vector3(-108.0, HARBOR_DECK_Y + 0.85 - ramp_half, 125.0),
		Vector3(-124.0, HARBOR_DECK_Y - ramp_half, 125.0),
		HARBOR_PIER_W - 0.4, 0.65, wood_mat, "ramps")

	# ── 5. Steel Channel Bridges ──
	# Inner Basin Cross-Channel Bridge
	_harbor_add_box(root, "HarborBridge_InnerBasin",
		Vector3(20.0, HARBOR_DECK_Y - 0.35, 35.0),
		Vector3(24.0, 0.70, 14.0), 0.0, steel_mat, "track_surface")
	_harbor_add_box(root, "HarborBridge_Inner_RailN",
		Vector3(20.0, HARBOR_DECK_Y + 0.55, 28.2),
		Vector3(24.0, 1.1, 0.28), 0.0, steel_mat, "")
	_harbor_add_box(root, "HarborBridge_Inner_RailS",
		Vector3(20.0, HARBOR_DECK_Y + 0.55, 41.8),
		Vector3(24.0, 1.1, 0.28), 0.0, steel_mat, "")
	for x_p in [10.0, 30.0]:
		_harbor_add_box(root, "HarborBridge_Inner_Pillar_%d" % int(x_p),
			Vector3(x_p, (HARBOR_DECK_Y + HARBOR_SEABED_Y) * 0.5, 35.0),
			Vector3(1.4, HARBOR_DECK_Y - HARBOR_SEABED_Y, 1.4), 0.0, steel_mat, "")

	# West Pier Channel Bridge
	_harbor_add_box(root, "HarborBridge_West",
		Vector3(-175.0, HARBOR_DECK_Y - 0.35, 4.0),
		Vector3(14.0, 0.70, 24.0), 0.0, steel_mat, "track_surface")
	_harbor_add_box(root, "HarborBridge_West_RailL",
		Vector3(-181.8, HARBOR_DECK_Y + 0.55, 4.0),
		Vector3(0.28, 1.1, 24.0), 0.0, steel_mat, "")
	_harbor_add_box(root, "HarborBridge_West_RailR",
		Vector3(-168.2, HARBOR_DECK_Y + 0.55, 4.0),
		Vector3(0.28, 1.1, 24.0), 0.0, steel_mat, "")
	for z_p2 in [-5.0, 13.0]:
		_harbor_add_box(root, "HarborBridge_West_Pillar_%d" % int(z_p2),
			Vector3(-175.0, (HARBOR_DECK_Y + HARBOR_SEABED_Y) * 0.5, z_p2),
			Vector3(1.4, HARBOR_DECK_Y - HARBOR_SEABED_Y, 1.4), 0.0, steel_mat, "")

	# ── 6. Grounded Dock Platforms (Solid foundations under all warehouses and containers) ──
	# A. North Wharf Platform
	_harbor_add_dock_platform(root, "Platform_NorthWharf", -160.0, 50.0, -132.0, -95.0, deck_mat, side_mat)
	# North Warehouses resting squarely on platform
	var wh_x_list := [-135.0, -85.0, -30.0, 25.0]
	for idx in range(wh_x_list.size()):
		_harbor_add_box(root, "HarborWarehouse_N_%d" % idx,
			Vector3(wh_x_list[idx], HARBOR_DECK_Y + 4.2, -114.0),
			Vector3(22.0, 8.4, 16.0), 0.0, warehouse_mat, "")

	# North Wharf Container Stacks
	_harbor_add_container(root, "CargoN_0", Vector3(-108.0, HARBOR_DECK_Y + 1.3, -107.0), Vector3(12.0, 2.6, 2.4), 0.0, col_blue)
	_harbor_add_container(root, "CargoN_1", Vector3(-108.0, HARBOR_DECK_Y + 3.9, -107.0), Vector3(12.0, 2.6, 2.4), 0.0, col_red)
	_harbor_add_container(root, "CargoN_2", Vector3(-58.0, HARBOR_DECK_Y + 1.3, -107.0), Vector3(12.0, 2.6, 2.4), 0.0, col_orange)
	_harbor_add_container(root, "CargoN_3", Vector3(-58.0, HARBOR_DECK_Y + 3.9, -107.0), Vector3(12.0, 2.6, 2.4), 0.0, col_green)
	_harbor_add_container(root, "CargoN_4", Vector3(-58.0, HARBOR_DECK_Y + 6.5, -107.0), Vector3(12.0, 2.6, 2.4), 0.0, col_blue)
	_harbor_add_container(root, "CargoN_5", Vector3(-3.0, HARBOR_DECK_Y + 1.3, -107.0), Vector3(12.0, 2.6, 2.4), 0.0, col_yellow)
	_harbor_add_container(root, "CargoN_6", Vector3(-3.0, HARBOR_DECK_Y + 3.9, -107.0), Vector3(12.0, 2.6, 2.4), 0.0, col_red)

	# B. East Basin Cargo Terminal Platform
	_harbor_add_dock_platform(root, "Platform_EastBasin", 96.0, 145.0, 25.0, 90.0, deck_mat, side_mat)
	_harbor_add_box(root, "HarborWarehouse_East_0",
		Vector3(124.0, HARBOR_DECK_Y + 3.8, 45.0), Vector3(18.0, 7.6, 14.0), 0.0, warehouse_mat, "")
	_harbor_add_box(root, "HarborWarehouse_East_1",
		Vector3(124.0, HARBOR_DECK_Y + 3.8, 70.0), Vector3(18.0, 7.6, 14.0), 0.0, warehouse_mat, "")
	_harbor_add_container(root, "CargoE_0", Vector3(104.0, HARBOR_DECK_Y + 1.3, 40.0), Vector3(2.4, 2.6, 12.0), 0.0, col_blue)
	_harbor_add_container(root, "CargoE_1", Vector3(104.0, HARBOR_DECK_Y + 3.9, 40.0), Vector3(2.4, 2.6, 12.0), 0.0, col_green)
	_harbor_add_container(root, "CargoE_2", Vector3(104.0, HARBOR_DECK_Y + 1.3, 75.0), Vector3(2.4, 2.6, 12.0), 0.0, col_orange)
	_harbor_add_container(root, "CargoE_3", Vector3(104.0, HARBOR_DECK_Y + 3.9, 75.0), Vector3(2.4, 2.6, 12.0), 0.0, col_red)

	# C. West Basin Logistics Apron Platform
	_harbor_add_dock_platform(root, "Platform_WestBasin", -95.0, -48.0, 20.0, 75.0, deck_mat, side_mat)
	_harbor_add_container(root, "CargoW_0", Vector3(-68.0, HARBOR_DECK_Y + 1.3, 35.0), Vector3(12.0, 2.6, 2.4), 0.0, col_red)
	_harbor_add_container(root, "CargoW_1", Vector3(-68.0, HARBOR_DECK_Y + 3.9, 35.0), Vector3(12.0, 2.6, 2.4), 0.0, col_yellow)
	_harbor_add_container(root, "CargoW_2", Vector3(-68.0, HARBOR_DECK_Y + 1.3, 60.0), Vector3(12.0, 2.6, 2.4), 0.0, col_blue)
	_harbor_add_container(root, "CargoW_3", Vector3(-68.0, HARBOR_DECK_Y + 3.9, 60.0), Vector3(12.0, 2.6, 2.4), 0.0, col_green)

	# D. Finger Pier Docks
	_harbor_add_dock_platform(root, "Platform_FingerA", -45.0, 35.0, -48.0, -22.0, deck_mat, side_mat)
	_harbor_add_box(root, "HarborWarehouse_FingerA",
		Vector3(-20.0, HARBOR_DECK_Y + 3.6, -35.0),
		Vector3(16.0, 7.2, 10.0), 0.0, warehouse_mat, "")

	_harbor_add_dock_platform(root, "Platform_FingerB", 35.0, 115.0, 42.0, 68.0, deck_mat, side_mat)
	_harbor_add_box(root, "HarborWarehouse_FingerB",
		Vector3(75.0, HARBOR_DECK_Y + 3.6, 55.0),
		Vector3(16.0, 7.2, 10.0), 0.0, warehouse_mat, "")

	# ── 7. Perimeter Breakwater Walls ──
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.34, 0.35, 0.36)
	wall_mat.roughness = 0.97
	_harbor_add_box(root, "HarborBreakwater_N",
		Vector3(0.0, 2.1, -210.0), Vector3(460.0, 4.2, 6.0), 0.0, wall_mat, "")
	_harbor_add_box(root, "HarborBreakwater_S",
		Vector3(0.0, 2.1, 220.0), Vector3(460.0, 4.2, 6.0), 0.0, wall_mat, "")
	_harbor_add_box(root, "HarborBreakwater_E",
		Vector3(280.0, 2.1, 5.0), Vector3(6.0, 4.2, 430.0), 0.0, wall_mat, "")
	_harbor_add_box(root, "HarborBreakwater_W",
		Vector3(-270.0, 2.1, 5.0), Vector3(6.0, 4.2, 430.0), 0.0, wall_mat, "")
