extends Node
## Loads a level with a FogLift (Shuangjiang), starts the race's clock by hand and prints the fog and the river mist as
## they lift: `res://scratch/fog_lift_check.tscn -- [level=res://levels/ShuangjiangLevel.tscn] [lift=4]` (headless).

var _lvl: Node
var _fog: Node
var _t := 0.0
var _next := 0.0


func _ready() -> void:
	var path := "res://levels/ShuangjiangLevel.tscn"
	var lift := 4.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			path = a.substr(6)
		elif a.begins_with("lift="):
			lift = float(a.substr(5))
	_lvl = (load(path) as PackedScene).instantiate()
	_fog = _lvl.get_node_or_null("FogLift")
	if _fog == null:
		print("FAIL: no FogLift")
		get_tree().quit(1)
		return
	_fog.lift_time = lift
	add_child(_lvl)


func _process(delta: float) -> void:
	if _lvl == null:
		return
	_t += delta
	if _t > 0.5 and _lvl.get("race_state") == 0:
		print("race starts")
		_lvl.set("race_state", 1)
	if _t >= _next:
		_next += 1.0
		var env: Environment = (_lvl.get_node("WorldEnvironment") as WorldEnvironment).environment
		var mist: ShaderMaterial = (_lvl.get_node("MistRiver0") as MeshInstance3D).material_override
		print("t=%.1f fog %.0f-%.0fm density %.2f sky %.2f mist %.2f" % [_t, env.fog_depth_begin, env.fog_depth_end, env.fog_density,
			env.fog_sky_affect, float(mist.get_shader_parameter("density"))])
	if _t > float(_fog.lift_time) + 2.0:
		get_tree().quit()
