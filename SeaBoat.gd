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

var _hull: Node3D
var _body: AnimatableBody3D
var _home: Transform3D
var _perimeter := 0.0
var _seed := 0.0


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


func _physics_process(_delta: float) -> void:
	if _hull != null:
		_place(_now())


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
	_hull.transform = xf
	if _body != null:
		_body.transform = xf
