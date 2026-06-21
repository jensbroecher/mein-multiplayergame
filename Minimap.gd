extends Control

var track_points: Array[Vector2] = []
var alternative_tracks: Array[Array] = [] # Array of Array of Vector2
var track_center: Vector2 = Vector2.ZERO
var track_scale: float = 1.0
var level: Node3D = null

var finish_line_pos: Vector2 = Vector2.ZERO
var has_finish_line: bool = false

var time_elapsed: float = 0.0

func _ready() -> void:
	# Try to initialize on startup
	call_deferred("_initialize_track")

func _initialize_track() -> void:
	level = get_tree().get_first_node_in_group("level")
	if not level:
		return
		
	var track_path = level.track_path
	if not track_path:
		track_path = level.get_node_or_null("TrackPath")
		
	if not track_path or not track_path.curve:
		return
		
	var curve = track_path.curve
	var baked = curve.get_baked_points()
	if baked.is_empty():
		return
		
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	
	track_points.clear()
	for pt in baked:
		var global_pt = track_path.to_global(pt)
		var p2d = Vector2(global_pt.x, global_pt.z)
		track_points.append(p2d)
		
		min_pos.x = min(min_pos.x, p2d.x)
		min_pos.y = min(min_pos.y, p2d.y)
		max_pos.x = max(max_pos.x, p2d.x)
		max_pos.y = max(max_pos.y, p2d.y)
		
	# Finish Line
	var fl = level.get_node_or_null("FinishLine")
	if fl:
		var fl_global = fl.global_position
		finish_line_pos = Vector2(fl_global.x, fl_global.z)
		has_finish_line = true
	else:
		has_finish_line = false
		
	# Alternative Paths
	alternative_tracks.clear()
	if "alternative_paths" in level and level.alternative_paths:
		for alt_path in level.alternative_paths:
			if alt_path and alt_path.curve:
				var alt_baked = alt_path.curve.get_baked_points()
				var alt_points: Array[Vector2] = []
				for pt in alt_baked:
					var global_pt = alt_path.to_global(pt)
					alt_points.append(Vector2(global_pt.x, global_pt.z))
				alternative_tracks.append(alt_points)
				
	_update_scale(min_pos, max_pos)

func _update_scale(min_pos: Vector2, max_pos: Vector2) -> void:
	if min_pos.x == INF:
		return
	var track_size = max_pos - min_pos
	track_center = min_pos + track_size * 0.5
	
	var padding = 12.0
	var usable_size = size - Vector2(padding * 2, padding * 2)
	usable_size.x = max(usable_size.x, 10.0)
	usable_size.y = max(usable_size.y, 10.0)
	
	var sz_x = max(track_size.x, 1.0)
	var sz_y = max(track_size.y, 1.0)
	track_scale = min(usable_size.x / sz_x, usable_size.y / sz_y)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# Recalculate scale on resize
		if level:
			var track_path = level.track_path
			if not track_path:
				track_path = level.get_node_or_null("TrackPath")
			if track_path and track_path.curve:
				var min_pos := Vector2(INF, INF)
				var max_pos := Vector2(-INF, -INF)
				for p2d in track_points:
					min_pos.x = min(min_pos.x, p2d.x)
					min_pos.y = min(min_pos.y, p2d.y)
					max_pos.x = max(max_pos.x, p2d.x)
					max_pos.y = max(max_pos.y, p2d.y)
				_update_scale(min_pos, max_pos)

func _process(delta: float) -> void:
	time_elapsed += delta
	if track_points.is_empty():
		_initialize_track()
	queue_redraw()

func _draw() -> void:
	if track_points.is_empty():
		return
		
	# Draw Alternative Tracks (dimmer, secondary)
	for alt_points in alternative_tracks:
		if alt_points.size() > 1:
			var local_alt_points = PackedVector2Array()
			for pt in alt_points:
				var local_pt = (pt - track_center) * track_scale + size * 0.5
				local_alt_points.append(local_pt)
			draw_polyline(local_alt_points, Color(0.0, 0.6, 0.8, 0.25), 1.5, true)
			
	# Convert main track points to local minimap coordinates
	var local_points = PackedVector2Array()
	for pt in track_points:
		var local_pt = (pt - track_center) * track_scale + size * 0.5
		local_points.append(local_pt)
		
	# Connect loop
	if local_points.size() > 1 and local_points[0].distance_to(local_points[-1]) > 1.0:
		local_points.append(local_points[0])
		
	# Draw track shadows/borders for glow effect
	draw_polyline(local_points, Color(1, 1, 1, 0.08), 5.0, true)
	draw_polyline(local_points, Color(0.0, 0.8, 1.0, 0.7), 2.0, true)
	
	# Draw Finish Line
	if has_finish_line:
		var fl_local = (finish_line_pos - track_center) * track_scale + size * 0.5
		draw_circle(fl_local, 4.5, Color(1.0, 0.85, 0.0))
		draw_circle(fl_local, 2.5, Color(0.1, 0.1, 0.12))
		draw_circle(fl_local, 1.0, Color(1.0, 1.0, 1.0))
		
	# Draw Player Carts
	var carts = get_tree().get_nodes_in_group("player_carts")
	for cart in carts:
		if not is_instance_valid(cart):
			continue
			
		var cart_pos_3d = cart.global_position
		var cart_pos_2d = Vector2(cart_pos_3d.x, cart_pos_3d.z)
		var p = (cart_pos_2d - track_center) * track_scale + size * 0.5
		
		var is_local = cart.get("is_local_player") == true
		
		# Draw pulsing animation for local player
		if is_local:
			var pulse_r = 7.0 + sin(time_elapsed * 7.0) * 3.0
			var pulse_alpha = 0.3 - sin(time_elapsed * 7.0) * 0.1
			draw_circle(p, pulse_r, Color(0.2, 1.0, 0.2, pulse_alpha))
			
		# Draw cart direction indicator (triangle)
		var fwd_3d = -cart.global_transform.basis.z
		var dir = Vector2(fwd_3d.x, fwd_3d.z).normalized()
		var right = Vector2(-dir.y, dir.x)
		
		var size_factor = 1.2 if is_local else 1.0
		var len = 7.0 * size_factor
		var width = 5.0 * size_factor
		
		var front = p + dir * len
		var back_left = p - dir * (len * 0.6) - right * width
		var back_right = p - dir * (len * 0.6) + right * width
		
		var cart_color = _get_cart_color(cart)
		var tri_points = PackedVector2Array([front, back_right, back_left])
		
		draw_polygon(tri_points, [cart_color])
		# Dark contour outline for visibility
		draw_polyline(PackedVector2Array([front, back_right, back_left, front]), Color(0.06, 0.06, 0.08, 0.9), 1.0, true)

func _get_cart_color(cart: Node) -> Color:
	if cart.get("is_local_player") == true:
		return Color(0.2, 1.0, 0.2) # Neon green
		
	var car_idx = cart.get("car_index")
	if car_idx == null:
		return Color(0.9, 0.9, 0.9)
		
	match car_idx:
		0: return Color(1.0, 0.2, 0.2) # Viper (Red)
		1: return Color(0.75, 0.2, 1.0) # Shadow (Purple/Violet)
		2: return Color(1.0, 0.6, 0.0) # Strikeforce (Orange)
		3: return Color(0.0, 0.8, 1.0) # Apex (Cyan/Blue)
		_: return Color(0.9, 0.9, 0.9)
