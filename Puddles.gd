extends RefCounted
## The rain puddles the ground and road shaders draw, worked out again on the CPU so a cart can feel them (PlayerCart:
## a little drag, a small spray and a splash). Each stage's puddles are the same formula as its shader's, from the same
## value noise (`hash12`/`vnoise`, Dave Hoskins' hash on the integer lattice, so the GPU's float32 and GDScript's doubles
## agree to a few millionths), per the body the cart stands on:
##   Quer durch Kronburg (stadt_road.gdshader, stadt_ground.gdshader): the building site's haul road (BaustrasseTrack,
##     kind 11: puddles in its ruts and hollows), the scrapyard's slabs (SchrottplatzTrack, kind 13: puddles where mud
##     lies over them), the site's and the yard's mud off the road (BaustellenMatsch).
##   Zeche Kronprinz (zeche_ground.gdshader): the track (KohlenTrack: puddles in the ruts and hollows, not at its edges).
## Msitu Falls' jungle road draws its puddles from a noise texture and is not covered. `lat` is metres right of the lap's
## line (signed; Zeche's shader takes the distance), `s` metres along it: the shaders' UV.x and UV.y. Returns 0 (dry) to 1
## (deep in the puddle); the shaders show water from about 0.4.

## Where a puddle starts to count (the drawn water's edge).
const WET := 0.45


## A stage's key from its level scene's file, or "" for stages without puddles here.
static func stage_of(level: Node) -> String:
	if level == null:
		return ""
	var f: String = level.scene_file_path.get_file()
	if f.begins_with("Stadtrallye"):
		return "stadtrallye"
	if f.begins_with("Zeche"):
		return "zeche"
	return ""


## Whether the body `body` (a collider's name) can hold puddles on `stage`: only then is the lap's lateral needed.
static func has_puddles(stage: String, body: String) -> bool:
	match stage:
		"stadtrallye":
			return body == "BaustrasseTrack" or body == "SchrottplatzTrack" or body == "BaustellenMatsch"
		"zeche":
			return body == "KohlenTrack"
	return false


static func at(stage: String, body: String, p: Vector3, lat: float, s: float) -> float:
	var xz := Vector2(p.x, p.z)
	match stage:
		"stadtrallye":
			if body == "BaustrasseTrack":
				var ruts := 0.0
				for ri in [-1.0, 1.0]:
					var rc: float = ri * (2.1 + (vnoise(Vector2(s / 13.0, ri)) - 0.5) * 1.2)
					ruts += _stripe(lat - rc, 0.75) + _stripe(lat - rc * 2.35, 0.7) * 0.6
				return smoothstep(0.64, 0.69, vnoise(xz / 5.5 + Vector2(11.0, 11.0)) * 0.7 + clampf(ruts, 0.0, 1.0) * 0.32)
			if body == "SchrottplatzTrack":
				var mw: float = smoothstep(0.45, 0.62, vnoise(xz / 8.0 + Vector2(5.0, 5.0)) + smoothstep(7.5 * 0.6, 7.5, absf(lat)) * 0.3)
				return smoothstep(0.7, 0.74, vnoise(xz / 6.0 + Vector2(23.0, 23.0))) * mw
			if body == "BaustellenMatsch":
				return smoothstep(0.66, 0.70, vnoise(xz / 7.0 + Vector2(31.0, 31.0)) * 0.8 + 0.12)
		"zeche":
			if body == "KohlenTrack":
				var a: float = absf(lat)
				var wob: float = (vnoise(xz * 0.05) - 0.5) * 1.2
				var rut := 0.0
				for c in [1.4 + wob, 4.6 + wob]:
					rut = maxf(rut, 1.0 - smoothstep(0.25, 0.7, absf(a - c)))
				var edge: float = smoothstep(8.0 - 1.6, 8.0 - 0.2, a + (vnoise(xz * 0.4) - 0.5) * 1.2)
				return smoothstep(0.72, 0.8, vnoise(xz / 7.0 + Vector2(3.0, 3.0))) * (0.3 + 0.7 * rut) * (1.0 - edge)
	return 0.0


## A line `w` wide at signed distance `d` (the shaders' `stripe` at a vanishing pixel size).
static func _stripe(d: float, w: float) -> float:
	return 1.0 if absf(d) < w * 0.5 else 0.0


static func _fract(v: float) -> float:
	return v - floorf(v)


static func hash12(p: Vector2) -> float:
	var p3 := Vector3(_fract(p.x * 0.1031), _fract(p.y * 0.1031), _fract(p.x * 0.1031))
	var d: float = p3.dot(Vector3(p3.y, p3.z, p3.x) + Vector3(33.33, 33.33, 33.33))
	p3 += Vector3(d, d, d)
	return _fract((p3.x + p3.y) * p3.z)


static func vnoise(p: Vector2) -> float:
	var i := Vector2(floorf(p.x), floorf(p.y))
	var f := p - i
	var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	return lerpf(lerpf(hash12(i), hash12(i + Vector2(1, 0)), u.x), lerpf(hash12(i + Vector2(0, 1)), hash12(i + Vector2(1, 1)), u.x), u.y)
