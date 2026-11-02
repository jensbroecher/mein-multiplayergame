extends Node3D
## Mina del Viento's balloon fiesta (regenerate_mina.gd). The balloons aloft (children with a "centre" meta) drift on
## slow loops of their own over the plateau, bobbing and turning; every balloon with a "burner" meta fires its burner
## now and then (the `burn` instance uniform of mina_balloon.gdshader and mina_flame.gdshader). All of it runs on the
## wall clock, like WildebeestHerd, so LAN peers see the same sky without anything being synced.

## Seconds between one balloon's burns, and how long a burn lasts.
const BURN_EVERY := Vector2(7.0, 18.0)
const BURN_FOR := Vector2(1.8, 3.6)

var _sky: Array = []
var _burners: Array = []


func _ready() -> void:
	for c in get_children():
		if c.has_meta(&"centre"):
			_sky.append(c)
		if c.get_meta(&"burner", false):
			var gi: GeometryInstance3D = c as GeometryInstance3D
			if gi == null:
				gi = c.get_node_or_null("Mesh") as GeometryInstance3D
			if gi:
				_burners.append(gi)
	set_process(not Engine.is_editor_hint())


func _hash01(i: int, salt: int) -> float:
	return float(hash(Vector2i(i, salt)) % 10007) / 10007.0


func _process(_delta: float) -> void:
	var t: float = fmod(Time.get_unix_time_from_system(), 86400.0)
	for b in _sky:
		var n: Node3D = b
		var c: Vector3 = n.get_meta(&"centre")
		var r: Vector2 = n.get_meta(&"radius")
		var per: float = n.get_meta(&"period")
		var ph: float = n.get_meta(&"phase")
		var a: float = TAU * fposmod(t / per + ph, 1.0)
		n.position = c + Vector3(cos(a) * r.x, sin(t * 0.17 + ph * 9.0) * 5.0, sin(a) * r.y)
		n.rotation.y = ph * TAU + t * 0.012
	for i in range(_burners.size()):
		var every: float = lerpf(BURN_EVERY.x, BURN_EVERY.y, _hash01(i, 3))
		var dur: float = lerpf(BURN_FOR.x, BURN_FOR.y, _hash01(i, 7))
		var u: float = fposmod(t + _hash01(i, 11) * every, every)
		var burn: float = smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(dur - 0.4, dur, u))
		(_burners[i] as GeometryInstance3D).set_instance_shader_parameter(&"burn", burn)
