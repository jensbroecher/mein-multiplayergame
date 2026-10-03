# Jumbotron.gd
# Drives the trackside video board: aims a broadcast camera at the pack and keeps its render
# target refreshing just often enough to look live.
#
# Structure and throttling follow the proven VideoScreen implementation from the jetski game
# (GDMP-demo/project/mii_avatar/games/jetski) rather than being invented here - binding only
# albedo_texture on an unshaded material, and driving render_target_update_mode every frame are
# both load-bearing details.
extends Node3D

@onready var viewport: SubViewport = $BroadcastViewport
@onready var camera: Camera3D = $BroadcastViewport/BroadcastCamera
@onready var screen_mesh: MeshInstance3D = $Screen

## Camera offset from the pack, so the board shows a three-quarter chase rather than a nose-on.
@export var camera_offset := Vector3(14.0, 5.5, 10.0)
@export var lerp_speed := 3.0
## Refresh the render target every Nth frame. 3 gives roughly 12Hz at 36fps, which reads as live
## and costs about a twentieth of one extra full-screen pass at 320x180.
@export var update_interval: int = 3
## Beyond this distance from the board, stop rendering the broadcast entirely.
@export var max_render_distance: float = 600.0
## Aim here until racers exist.
@export var fallback_target := Vector3(-85.0, 3.0, 200.0)

var _frame := 0
var _target := Vector3.ZERO

func _ready() -> void:
	if viewport == null or camera == null or screen_mesh == null:
		push_warning("Jumbotron: missing BroadcastViewport / BroadcastCamera / Screen")
		set_process(false)
		return

	# Fresh material built here rather than mutated in place from a serialised one. Albedo only:
	# an unshaded albedo is the whole image, and adding an emission texture on top of it is what
	# left the board black in an earlier revision.
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = viewport.get_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_mesh.material_override = mat

	_target = fallback_target

func _process(delta: float) -> void:
	if camera == null:
		return

	# Aim at the middle of the pack, falling back to the start straight before anyone spawns.
	var aim := fallback_target
	var carts := get_tree().get_nodes_in_group("player_carts")
	var sum := Vector3.ZERO
	var count := 0
	for c in carts:
		if is_instance_valid(c) and c is Node3D:
			sum += (c as Node3D).global_position
			count += 1
	if count > 0:
		aim = sum / float(count)

	camera.global_position = camera.global_position.lerp(aim + camera_offset, delta * lerp_speed)
	camera.look_at(aim, Vector3.UP)

	# Throttle: off on most frames, on when it is due. UPDATE_WHEN_VISIBLE lets the engine skip
	# the render when the viewport cannot be seen at all.
	_frame += 1
	if _frame % maxi(update_interval, 1) != 0:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if global_position.distance_to(aim) > max_render_distance:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
