extends Node
## Morning fog that lifts as the race goes on (Shuangjiang, regenerate_shuangjiang.gd): on the level's WorldEnvironment
## (depth fog), the fog's far end and density ease from their values at load to `end_far` and `end_density` over
## `lift_time` seconds once the race is under way (Level's `race_state` past the lobby; from load where there is none), and its
## colour from the haze toward `end_color`; the mist lying on the river (the level's children named "Mist...", drawn by
## river_mist.gdshader) thins to `end_mist` of its density. Every peer runs it from its own clock: fog needs no syncing.
## `res://scratch/fog_lift_check.tscn -- [level=] [lift=4]` (headless) prints it lifting.

@export var lift_time := 210.0
@export var end_far := 2600.0
@export var end_begin := 160.0
@export var end_density := 0.75
@export var end_sky := 0.25
@export var end_color := Color(0.78, 0.78, 0.8)
@export var end_mist := 0.35

var _env: Environment
var _from := {}
var _t := 0.0
var _mists: Array = []


func _ready() -> void:
	var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		set_process(false)
		return
	# A copy, so the saved resource keeps its morning values for the next race.
	_env = we.environment.duplicate()
	we.environment = _env
	_from = {"far": _env.fog_depth_end, "begin": _env.fog_depth_begin, "density": _env.fog_density, "sky": _env.fog_sky_affect,
		"color": _env.fog_light_color}
	for c in get_parent().get_children():
		if c is MeshInstance3D and String(c.name).begins_with("Mist") and c.material_override is ShaderMaterial:
			var m := (c.material_override as ShaderMaterial).duplicate() as ShaderMaterial
			c.material_override = m
			_mists.append([m, float(m.get_shader_parameter("density"))])


func _process(delta: float) -> void:
	var lvl: Node = get_parent()
	var rs: Variant = lvl.get("race_state") if lvl != null else null
	if rs is int and rs == 0:
		return
	_t += delta
	var f: float = smoothstep(0.0, 1.0, clampf(_t / lift_time, 0.0, 1.0))
	_env.fog_depth_end = lerpf(_from["far"], end_far, f)
	_env.fog_depth_begin = lerpf(_from["begin"], end_begin, f)
	_env.fog_density = lerpf(_from["density"], end_density, f)
	_env.fog_sky_affect = lerpf(_from["sky"], end_sky, f)
	_env.fog_light_color = (_from["color"] as Color).lerp(end_color, f * 0.6)
	for mm in _mists:
		(mm[0] as ShaderMaterial).set_shader_parameter("density", float(mm[1]) * lerpf(1.0, end_mist, f))
	if f >= 1.0:
		set_process(false)
