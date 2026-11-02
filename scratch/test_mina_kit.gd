extends SceneTree

const MinaKit = preload("res://MinaKit.gd")

func _init() -> void:
	print("--- TESTING MINA KIT ---")

	var t0 = Time.get_ticks_msec()
	var dish_mesh = MinaKit.radio_dish()
	print("Radio Dish Mesh created in %d ms, surfaces: %d, aabb: %s" % [Time.get_ticks_msec() - t0, dish_mesh.get_surface_count(), dish_mesh.get_aabb()])

	t0 = Time.get_ticks_msec()
	var balloon_mesh = MinaKit.hot_air_balloon(0)
	print("Hot Air Balloon Mesh created in %d ms, surfaces: %d, aabb: %s" % [Time.get_ticks_msec() - t0, balloon_mesh.get_surface_count(), balloon_mesh.get_aabb()])

	t0 = Time.get_ticks_msec()
	var truck_mesh = MinaKit.haul_truck()
	print("Haul Truck Mesh created in %d ms, surfaces: %d, aabb: %s" % [Time.get_ticks_msec() - t0, truck_mesh.get_surface_count(), truck_mesh.get_aabb()])

	t0 = Time.get_ticks_msec()
	var conveyor_mesh = MinaKit.conveyor_bridge()
	print("Conveyor Bridge Mesh created in %d ms, surfaces: %d, aabb: %s" % [Time.get_ticks_msec() - t0, conveyor_mesh.get_surface_count(), conveyor_mesh.get_aabb()])

	t0 = Time.get_ticks_msec()
	var tower_mesh = MinaKit.floodlight_tower()
	print("Floodlight Tower Mesh created in %d ms, surfaces: %d, aabb: %s" % [Time.get_ticks_msec() - t0, tower_mesh.get_surface_count(), tower_mesh.get_aabb()])

	t0 = Time.get_ticks_msec()
	var tumbleweed = MinaKit.tumbleweed_mesh()
	print("Tumbleweed Mesh created in %d ms, surfaces: %d, aabb: %s" % [Time.get_ticks_msec() - t0, tumbleweed.get_surface_count(), tumbleweed.get_aabb()])

	print("--- ALL MINA KIT PROPS GENERATED SUCCESSFULLY! ---")
	quit()

