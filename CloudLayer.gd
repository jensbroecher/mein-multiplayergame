extends Node
## The Yamabushi Trail's cloud (regenerate_yamabushi.gd): the mountain stands in a layer of cloud between `band_low`
## and `band_high` metres. Under it the forest is dim and misty, in it the fog closes to a few dozen metres, above it
## the air is clear in the dawn's light and the cloud lies below as a sea (the CloudSea mesh). Every viewer's fog and
## sun follow their own camera's height, eased; nothing is synced and nothing runs in the generator.

@export var band_low := 95.0
@export var band_high := 150.0
@export var below_end := 900.0
@export var inside_end := 85.0
@export var above_end := 5200.0
@export var below_color := Color(0.50, 0.55, 0.62)
@export var inside_color := Color(0.80, 0.82, 0.86)
@export var above_color := Color(0.96, 0.84, 0.70)
@export var below_sun := 0.3

var _env: Environment
var _sun: DirectionalLight3D
var _sun_energy := 1.0
var _h := -1.0


func _ready() -> void:
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		set_process(false)
		return
	for child in get_tree().root.get_children():
		if "regenerate" in str(child.name).to_lower():
			set_process(false)
			return
	var we: WorldEnvironment = get_parent().get_node_or_null("WorldEnvironment")
	if we:
		_env = we.environment
	_sun = get_parent().get_node_or_null("SunLight")
	if _sun:
		_sun_energy = _sun.light_energy


func _process(delta: float) -> void:
	var vp := get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	if cam == null or _env == null:
		return
	var y: float = cam.global_position.y
	_h = y if _h < 0.0 or absf(y - _h) > 40.0 else lerpf(_h, y, clampf(delta * 2.5, 0.0, 1.0))
	# 0 below the cloud, 1 above it; `inside` peaks in the band.
	var up: float = smoothstep(band_low + 10.0, band_high + 12.0, _h)
	var inside: float = smoothstep(band_low - 35.0, band_low + 5.0, _h) * (1.0 - smoothstep(band_high - 12.0, band_high + 14.0, _h))
	var end: float = lerpf(below_end, above_end, up)
	end = lerpf(end, inside_end, inside)
	_env.fog_depth_end = end
	_env.fog_depth_begin = lerpf(lerpf(30.0, 260.0, up), 4.0, inside)
	_env.fog_light_color = below_color.lerp(above_color, up).lerp(inside_color, inside)
	_env.fog_sky_affect = lerpf(lerpf(0.92, 0.05, up), 1.0, inside)
	_env.fog_aerial_perspective = lerpf(0.0, 0.45, up) * (1.0 - inside)
	if _sun:
		_sun.light_energy = _sun_energy * lerpf(below_sun, 1.0, up) * (1.0 - 0.6 * inside)
