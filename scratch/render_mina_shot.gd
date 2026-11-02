extends Node
## Renders Mina del Viento's menu tile (images/menu/tile_mina_del_viento.jpg, 1376x768 like the other tiles): a chase
## view down the plateau's straight at TILE_S, the radio telescopes and the balloons, the haboob's wall of dust ahead.
## Windowed:
##   Godot --path . --resolution 1600x1000 res://scratch/render_mina_shot.tscn
## Also saves the uncropped frame as scratch/mina_del_viento_shot.png.

const TILE_S := 575.0
const BACK := 18.0
const UP := 8.0
const AHEAD := 60.0
const CART_MODEL := "res://generated/cars/Viper.tscn"
const CarPaint = preload("res://CarPaint.gd")


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1600, 1000)
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X
	var lvl: Node3D = (load("res://levels/MinaLevel.tscn") as PackedScene).instantiate()
	add_child(lvl)
	MusicManager.set_shadow_quality(3, false)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	for i in 20:
		await get_tree().physics_frame
	var path: Path3D = lvl.get_node("TrackPath")
	var p0: Vector3 = path.to_global(path.curve.sample_baked(TILE_S))
	var pb: Vector3 = path.to_global(path.curve.sample_baked(TILE_S - BACK))
	var pa: Vector3 = path.to_global(path.curve.sample_baked(TILE_S + AHEAD))
	var fwd: Vector3 = pa - pb
	fwd.y = 0.0
	fwd = fwd.normalized()
	var car: Node3D = load(CART_MODEL).instantiate()
	CarPaint.apply(car, CarPaint.factory("Viper"))
	add_child(car)
	var hit := lvl.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p0 + Vector3.UP * 20.0, p0 + Vector3.DOWN * 40.0))
	car.global_transform = Transform3D(Basis.looking_at(-fwd, Vector3.UP).scaled(Vector3.ONE * 2.0), Vector3(p0.x, hit.position.y if hit else p0.y, p0.z))
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 4000.0
	add_child(cam)
	cam.make_current()
	cam.global_position = pb + Vector3.UP * UP
	cam.look_at(pa + Vector3.UP, Vector3.UP)
	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png("res://scratch/mina_del_viento_shot.png")
	# 16:9-ish like the other tiles: drop a strip off the top and more off the bottom (the near road).
	var h: int = int(round(float(img.get_width()) * 768.0 / 1376.0))
	var top: int = int((img.get_height() - h) * 0.3)
	var tile := img.get_region(Rect2i(0, top, img.get_width(), h))
	tile.resize(1376, 768, Image.INTERPOLATE_LANCZOS)
	tile.save_jpg("res://images/menu/tile_mina_del_viento.jpg", 0.9)
	print("SAVED images/menu/tile_mina_del_viento.jpg")
	get_tree().quit()
