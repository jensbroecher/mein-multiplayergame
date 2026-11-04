extends Node3D
## A boat on the sea (Bloombay Dunes' cruise ship, sailboats and the yacht at anchor). It sails round a
## loop in this node's frame: two straights along z, `length` long and 2 * `turn_radius` apart, joined by
## half circles, counter-clockwise seen from above, at `speed`. Where it is comes from the wall clock (like
## Monorail.gd), so every LAN peer sees it in the same place without syncing; `phase` (metres along the
## loop) spreads boats apart. With `length` and `turn_radius` 0 it lies at anchor on the node's spot,
## swinging slowly about it (`swing_deg`).
##
## It rises and falls on the swell and rolls and pitches a little; a sailboat (`heel_deg`) leans away from
## `wind`. The model (its bow along +z, its waterline `draft` metres over its own y 0 at `model_scale`) and
## an AnimatableBody3D box round its hull (up to `body_top` over the water) are internal children, built
## on load: the level stores only this node's settings.

@export var model: PackedScene
@export var model_scale := 1.0
@export var draft := 0.0
@export var length := 0.0
@export var turn_radius := 0.0
@export var speed := 5.0
@export var phase := 0.0
@export var heel_deg := 0.0
## The way the wind blows (toward), in world space.
@export var wind := Vector3(1, 0, 0)
@export var swing_deg := 0.0
@export var bob_height := 0.15
@export var bob_period := 6.5
@export var roll_deg := 1.2
@export var pitch_deg := 0.6
@export var body_top := 3.0
## Sound (optional; Harbor Pier's boats): an engine loop on the hull, at `engine_db` and heard as loud as that at
## `engine_unit` metres, pitched by `engine_pitch`; now and then a blast on the horn (one of `horns`, at random) every
## `horn_gap` seconds (min, max), from the hull's height `horn_y`.
@export var engine_sound: AudioStream
@export var engine_db := 0.0
@export var engine_unit := 15.0
@export var engine_pitch := 1.0
@export var horns: Array[AudioStream] = []
@export var horn_db: PackedFloat32Array = PackedFloat32Array()
@export var horn_unit := 60.0
@export var horn_pitch := 1.0
@export var horn_gap := Vector2(40.0, 90.0)
@export var horn_y := 6.0
## A wake (optional; Harbor Pier's boats under way): a ribbon of foam along the way the boat came, `wake_width` across
## at the stern, spreading `wake_spread` metres a second each side, gone after `wake_seconds`; and a bow wave.
@export var wake_width := 0.0
@export var wake_spread := 0.7
@export var wake_seconds := 22.0

var _hull: Node3D
var _body: AnimatableBody3D
var _home: Transform3D
var _perimeter := 0.0
var _seed := 0.0
var _horn: AudioStreamPlayer3D
var _hull_box := AABB()
var _pos := Vector3.ZERO
var _yaw := 0.0
var _trail: Array = []
var _trail_mesh: ImmediateMesh
var _trail_at := -1.0
var _t0 := 0.0
static var _wake_mat: ShaderMaterial
var _horn_wait := 0.0


func _ready() -> void:
	if model == null:
		return
	_home = transform
	_perimeter = 2.0 * length + TAU * turn_radius
	_seed = fposmod(position.x * 0.137 + position.z * 0.071, 100.0)
	_hull = Node3D.new()
	_hull.name = "Hull"
	add_child(_hull, false, Node.INTERNAL_MODE_BACK)
	var m := model.instantiate() as Node3D
	m.scale = Vector3.ONE * model_scale
	m.position.y = -draft
	_hull.add_child(m)
	# The hull's box, from the model's own bounds (in the hull's frame).
	var box := AABB()
	var first := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = _hull.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	_hull_box = box
	if not first:
		var top := minf(box.end.y, body_top)
		var shape := BoxShape3D.new()
		shape.size = Vector3(box.size.x, maxf(top - box.position.y, 0.5), box.size.z)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(box.get_center().x, (box.position.y + top) * 0.5, box.get_center().z)
		_body = AnimatableBody3D.new()
		_body.name = "HullBody"
		_body.add_child(cs)
		add_child(_body, false, Node.INTERNAL_MODE_BACK)
	_place(_now())
	_add_sounds()
	_add_wake()


func _physics_process(delta: float) -> void:
	if _hull != null:
		_place(_now())
		if _trail_mesh != null:
			_update_wake()
	if _horn != null and not horns.is_empty():
		_horn_wait -= delta
		if _horn_wait <= 0.0:
			var i := randi() % horns.size()
			_horn.stream = horns[i]
			_horn.volume_db = horn_db[i] if i < horn_db.size() else 0.0
			_horn.pitch_scale = horn_pitch * randf_range(0.97, 1.03)
			_horn.play()
			_horn_wait = randf_range(horn_gap.x, horn_gap.y)


## The engine's loop and the horn, riding on the hull (headless servers make no sound).
func _add_sounds() -> void:
	if DisplayServer.get_name() == "headless" or _hull == null:
		return
	if engine_sound != null:
		var e := AudioStreamPlayer3D.new()
		e.name = "Engine"
		e.stream = engine_sound
		e.bus = &"SFX"
		e.volume_db = engine_db
		e.unit_size = engine_unit
		e.max_distance = engine_unit * 20.0
		e.pitch_scale = engine_pitch
		e.position = Vector3(0, 1.0, 0)
		e.autoplay = true
		_hull.add_child(e)
		# Every boat's engine starts at its own point in the loop.
		e.play(randf() * maxf(engine_sound.get_length() - 0.1, 0.0))
	if not horns.is_empty():
		_horn = AudioStreamPlayer3D.new()
		_horn.name = "Horn"
		_horn.bus = &"SFX"
		_horn.unit_size = horn_unit
		_horn.max_distance = horn_unit * 30.0
		_horn.position = Vector3(0, horn_y, 0)
		_hull.add_child(_horn)
		_horn_wait = randf_range(horn_gap.x * 0.3, horn_gap.y)


func _now() -> float:
	return Time.get_unix_time_from_system()


## Where the loop is at `s` metres along it: [position, heading], in the node's frame.
func _on_loop(s: float) -> Array:
	var r := turn_radius
	if s < length:
		return [Vector3(r, 0.0, length * 0.5 - s), Vector3(0, 0, -1)]
	s -= length
	var arc := PI * r
	if s < arc:
		var a := s / maxf(r, 0.001)
		return [Vector3(cos(a) * r, 0.0, -length * 0.5 - sin(a) * r), Vector3(-sin(a), 0.0, -cos(a))]
	s -= arc
	if s < length:
		return [Vector3(-r, 0.0, -length * 0.5 + s), Vector3(0, 0, 1)]
	s -= length
	var b := s / maxf(r, 0.001)
	return [Vector3(-cos(b) * r, 0.0, length * 0.5 + sin(b) * r), Vector3(sin(b), 0.0, cos(b))]


func _place(t: float) -> void:
	var pos := Vector3.ZERO
	var yaw := 0.0
	if _perimeter > 0.01:
		# The clock's seconds are doubles: fmod them by the lap time before they reach a float.
		var lap := _perimeter / maxf(speed, 0.01)
		var pf: Array = _on_loop(fposmod(fposmod(t, lap) * speed + phase, _perimeter))
		pos = pf[0]
		var h: Vector3 = pf[1]
		yaw = atan2(h.x, h.z)
	else:
		yaw = deg_to_rad(swing_deg) * sin(TAU * fposmod(t, 97.0) / 97.0 + _seed)
	var w := TAU / maxf(bob_period, 0.1)
	var tt := fposmod(t, 3600.0) + _seed
	var heave := bob_height * (sin(tt * w) * 0.7 + sin(tt * w * 1.71 + 1.3) * 0.3)
	var roll := deg_to_rad(roll_deg) * sin(tt * w * 0.83 + 0.5)
	var pitch := deg_to_rad(pitch_deg) * sin(tt * w * 1.13 + 2.1)
	var b := Basis(Vector3.UP, yaw)
	if heel_deg != 0.0:
		# The mast leans away from the wind: rolling about +z by a positive angle tips the top toward -x.
		var side := (_home.basis * b * Vector3.RIGHT).normalized().dot(wind.normalized())
		roll -= deg_to_rad(heel_deg) * clampf(side * 2.0, -1.0, 1.0)
	b = b * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	var xf := Transform3D(b, pos + Vector3(0.0, heave, 0.0))
	_pos = pos
	_yaw = yaw
	_hull.transform = xf
	if _body != null:
		_body.transform = xf



## The wake's mesh (rebuilt from the trail as the boat moves) and the bow wave on the hull. Only for a boat under way.
func _add_wake() -> void:
	if wake_width <= 0.0 or _perimeter <= 0.01 or DisplayServer.get_name() == "headless" or _hull == null:
		return
	if _wake_mat == null:
		_wake_mat = ShaderMaterial.new()
		_wake_mat.shader = load("res://boat_wake.gdshader")
		# Drawn after the water, whose plane is transparent too.
		_wake_mat.render_priority = 2
	_t0 = _now()
	# The wake it has already laid: where it was over the last wake_seconds (its course is the clock's).
	var back := 0.0
	while back <= wake_seconds:
		var py: Array = _pos_yaw(_t0 - back)
		var f := Vector3(sin(py[1]), 0, cos(py[1]))
		_trail.append([(py[0] as Vector3) + f * _hull_box.position.z, Vector3(f.z, 0, -f.x), -back])
		back += 0.25
	_trail_at = 0.0
	_trail_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.name = "Wake"
	mi.mesh = _trail_mesh
	mi.material_override = _wake_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi, false, Node.INTERNAL_MODE_BACK)
	# The bow wave: a V of foam from the stem back along both sides, on the hull (it heaves with it).
	var half_l: float = _hull_box.size.z * 0.5
	var stem_z: float = _hull_box.end.z
	var beam: float = _hull_box.size.x * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 6
	for i in range(rows):
		var a0: float = float(i) / float(rows)
		var a1: float = float(i + 1) / float(rows)
		var z0: float = stem_z - a0 * half_l * 0.9
		var z1: float = stem_z - a1 * half_l * 0.9
		var w0: float = beam * (0.15 + 1.1 * sqrt(a0))
		var w1: float = beam * (0.15 + 1.1 * sqrt(a1))
		var q := [Vector3(-w0, 0.14, z0), Vector3(w0, 0.14, z0), Vector3(w1, 0.14, z1), Vector3(-w1, 0.14, z1)]
		var uv := [Vector2(0, a0), Vector2(1, a0), Vector2(1, a1), Vector2(0, a1)]
		for tri in [[0, 1, 2], [0, 2, 3]]:
			for k in tri:
				st.set_color(Color(1, 1, 1, 0.8))
				st.set_uv(uv[k])
				st.set_normal(Vector3.UP)
				st.add_vertex(q[k])
	var bow := MeshInstance3D.new()
	bow.name = "BowWave"
	bow.mesh = st.commit()
	bow.material_override = _wake_mat
	bow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hull.add_child(bow)


## Samples the stern every quarter second (in the node's frame, at the water) and lays the ribbon over them.
func _update_wake() -> void:
	var now: float = _now() - _t0
	var fwd := Vector3(sin(_yaw), 0, cos(_yaw))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var stern: Vector3 = _pos + fwd * _hull_box.position.z
	if now - _trail_at >= 0.25:
		_trail_at = now
		_trail.push_front([stern, right, now])
		while _trail.size() > 2 and now - float(_trail[_trail.size() - 1][2]) > wake_seconds:
			_trail.pop_back()
	_trail_mesh.clear_surfaces()
	var pts: Array = [[stern, right, now]] + _trail
	if pts.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p in pts:
		var age: float = clampf((now - float(p[2])) / wake_seconds, 0.0, 1.0)
		var w: float = wake_width * 0.5 + wake_spread * age * wake_seconds
		var c: Vector3 = p[0]
		var r: Vector3 = p[1]
		_trail_mesh.surface_set_color(Color(1, 1, 1, 1))
		_trail_mesh.surface_set_normal(Vector3.UP)
		_trail_mesh.surface_set_uv(Vector2(0, age))
		_trail_mesh.surface_add_vertex(Vector3(c.x, 0.12, c.z) - r * w)
		_trail_mesh.surface_set_color(Color(1, 1, 1, 1))
		_trail_mesh.surface_set_normal(Vector3.UP)
		_trail_mesh.surface_set_uv(Vector2(1, age))
		_trail_mesh.surface_add_vertex(Vector3(c.x, 0.12, c.z) + r * w)
	_trail_mesh.surface_end()



## Where the loop has the boat at wall time `t`, and its heading (as `_place` lays it, without the swell).
func _pos_yaw(t: float) -> Array:
	var lap := _perimeter / maxf(speed, 0.01)
	var pf: Array = _on_loop(fposmod(fposmod(t, lap) * speed + phase, _perimeter))
	var h: Vector3 = pf[1]
	return [pf[0], atan2(h.x, h.z)]
