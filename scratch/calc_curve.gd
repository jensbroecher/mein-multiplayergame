# scratch/calc_curve.gd
extends SceneTree

func _init():
	var curve := Curve3D.new()
	curve.bake_interval = 0.25

	var curve_pts = [
		[Vector3(0, 0, 45), Vector3(0, 0, -45), Vector3(-85.0, 2.8, 280.0)],    # 0 Finish Line
		[Vector3(0, 0, 40), Vector3(0, 0, -40), Vector3(-85.0, 2.8, 160.0)],    # 1 South straight
		[Vector3(0, 0, 35), Vector3(2, 0, -35), Vector3(-82.0, 2.8, 30.0)],     # 2 Pre-Divergence 1 (Express On-Ramp)
		[Vector3(-12, 0, 35), Vector3(12, 0, -35), Vector3(-55.0, 2.8, -50.0)], # 3 Lower glacier curve
		[Vector3(-10, 0, 25), Vector3(5, 0, -25), Vector3(-18.0, 2.8, -115.0)], # 4 Post-Divergence 1 Rejoin
		[Vector3(0, 0, 20), Vector3(0, 0, -20), Vector3(0.0, 2.8, -150.0)],    # 5 Tunnel Approach Straight (Aligning to X = 0)
		[Vector3(0, 0, 15), Vector3(0, 0, -15), Vector3(0.0, 2.8, -180.0)],    # 6 Tunnel Entrance Portal & Crossover Apex (Z = -180, Y = 2.8)
		[Vector3(0, 0, 15), Vector3(0, 0, -15), Vector3(0.0, 2.8, -210.0)],    # 7 Tunnel Underpass Midpoint (Z = -210, Y = 2.8)
		[Vector3(0, 0, 15), Vector3(0, 0, -15), Vector3(0.0, 2.8, -240.0)],    # 8 Tunnel Exit Portal (Z = -240, Y = 2.8)
		[Vector3(0, 0, 15), Vector3(0, 0, -25), Vector3(0.0, 2.8, -270.0)],    # 9 North Basin Runout Straight
		[Vector3(-10, -0.2, 20), Vector3(12, 0.4, -25), Vector3(30.0, 3.8, -320.0)], # 10 Pre-Divergence 2 (Gorge Cut Off-Ramp)
		[Vector3(-18, -0.4, 20), Vector3(22, 0.6, -20), Vector3(80.0, 5.8, -370.0)], # 11 North Rim broad curve
		[Vector3(-22, -0.6, 12), Vector3(20, 0.8, -12), Vector3(140.0, 8.5, -370.0)],# 12 Post-Divergence 2 Rejoin
		[Vector3(-20, -0.8, -16), Vector3(18, 0.8, 16), Vector3(195.0, 12.0, -320.0)],# 13 East flank climb
		[Vector3(-6, -0.8, -25), Vector3(6, 0.8, 25), Vector3(210.0, 15.0, -240.0)],  # 14 Eastern summit traverse
		[Vector3(0, 0, -25), Vector3(0, 0, 25), Vector3(180.0, 16.5, -180.0)],        # 15 Summit vista bend
		[Vector3(25, 0, 0), Vector3(-25, 0, 0), Vector3(135.0, 16.5, -180.0)],        # 16 East Overpass Approach Straight
		[Vector3(20, 0, 0), Vector3(-20, 0, 0), Vector3(70.0, 16.5, -180.0)],   # 17 High East viaduct span
		[Vector3(20, 0, 0), Vector3(-20, 0, 0), Vector3(0.0, 16.5, -180.0)],    # 18 OVERPASS CROSSING APEX (Z = -180, Y = 16.5m directly above Pt 6!)
		[Vector3(20, 0, 0), Vector3(-20, 0, 0), Vector3(-70.0, 16.5, -180.0)],  # 19 High West viaduct span / Pre-Divergence 3
		[Vector3(25, 0, 15), Vector3(-25, 0, -15), Vector3(-130.0, 16.5, -160.0)],# 20 West Overpass Abutment
		[Vector3(12, 0.8, -24), Vector3(-12, -0.8, 24), Vector3(-155.0, 13.0, -100.0)],# 21 Mountain viaduct descent
		[Vector3(6, 0.8, -26), Vector3(-6, -0.8, 26), Vector3(-160.0, 9.0, -20.0)],   # 22 Outer shelf sweep
		[Vector3(-4, 0.8, -25), Vector3(4, -0.6, 25), Vector3(-145.0, 5.5, 60.0)],   # 23 Post-Divergence 3 Rejoin
		[Vector3(-8, 0.6, -22), Vector3(8, -0.2, 24), Vector3(-120.0, 3.8, 140.0)],  # 24 Valley landing
		[Vector3(-6, 0.2, -25), Vector3(6, 0.0, 25), Vector3(-110.0, 2.8, 220.0)],  # 25 South sweeper
		[Vector3(-16, 0, -10), Vector3(16, 0, 10), Vector3(-95.0, 2.8, 330.0)],    # 26 Turnaround loop
		[Vector3(-15, 0, 12), Vector3(15, 0, -12), Vector3(-70.0, 2.8, 350.0)],    # 27 Loop apex
		[Vector3(-4, 0, 25), Vector3(4, 0, -25), Vector3(-65.0, 2.8, 320.0)],     # 28 Aligning into home straight
		[Vector3(0, 0, 45), Vector3(0, 0, -45), Vector3(-85.0, 2.8, 280.0)],      # 29 Closed back to start
	]

	for pt in curve_pts:
		curve.add_point(pt[2], pt[0], pt[1])

	var total_len := curve.get_baked_length()
	print("Calculated baked length: %.1f meters" % total_len)

	var junctions = [
		["Alt1 Split (Right)", Vector3(-78.0, 2.8, 25.0)],
		["Alt1 Merge (Left)", Vector3(-4.0, 2.8, -148.0)],
		["Alt2 Split (Right)", Vector3(6.0, 2.8, -276.0)],
		["Alt2 Merge (Right)", Vector3(140.0, 8.5, -370.0)],
		["Alt3 Split (Left)", Vector3(-75.0, 16.5, -180.0)],
		["Alt3 Merge (Left)", Vector3(-145.0, 5.5, 60.0)],
	]

	for j in junctions:
		var off = curve.get_closest_offset(j[1])
		var pt = curve.sample_baked(off)
		print("%s -> offset: %.1f m (dist to target: %.2f m)" % [j[0], off, pt.distance_to(j[1])])

	quit(0)
