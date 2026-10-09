# NorthlightWater.gd
#
# The water of Northlight Caverns, for PlayerCart: the pool in the crevasse under the ice arch, and
# the lead of open water under the Thin Ice. The level names this node "RiverWater", which is how
# PlayerCart finds a water body that has more than one level: it reads water_bounds once and calls
# surface_at() under the car every physics frame (see RiverWater.gd for the original).
extends Node3D

## Everything that can be water, so PlayerCart can skip the lookup elsewhere.
@export var water_bounds: Rect2 = Rect2()

## The crevasse pool: a rectangle along the slot.
@export var crevasse_center := Vector2.ZERO
@export var crevasse_dir := Vector2(1.0, 0.0)
@export var crevasse_half_len := 0.0
@export var crevasse_half_w := 0.0
@export var crevasse_y := 0.0

## The lead: everything within lead_half_w of its centreline.
@export var lead_line := PackedVector2Array()
@export var lead_half_w := 0.0
@export var lead_y := 0.0

var _lead_box := Rect2()


func _ready() -> void:
	if lead_line.size() > 0:
		_lead_box = Rect2(lead_line[0], Vector2.ZERO)
		for q in lead_line:
			_lead_box = _lead_box.expand(q)
		_lead_box = _lead_box.grow(lead_half_w)


## Water surface height at (x, z), or NAN where there is no water.
func surface_at(x: float, z: float) -> float:
	var q := Vector2(x, z)
	if not water_bounds.has_point(q):
		return NAN
	var d: Vector2 = q - crevasse_center
	var along: float = d.dot(crevasse_dir)
	var across: float = d.dot(Vector2(-crevasse_dir.y, crevasse_dir.x))
	if absf(along) <= crevasse_half_len and absf(across) <= crevasse_half_w:
		return crevasse_y
	if _lead_box.has_point(q):
		for i in range(lead_line.size() - 1):
			var a: Vector2 = lead_line[i]
			var ab: Vector2 = lead_line[i + 1] - a
			var t: float = clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
			if q.distance_to(a + ab * t) <= lead_half_w:
				return lead_y
	return NAN
