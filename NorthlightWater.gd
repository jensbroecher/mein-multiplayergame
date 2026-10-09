# NorthlightWater.gd
#
# The water of Northlight Caverns, for PlayerCart: the pool in the crevasse under the ice arch, and
# the holes in the Thin Ice. The level names this node "RiverWater", which is how
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

## The holes in the Thin Ice: (x, z, radius, rim phase) each, and the water level in each. With the
## holes' level answered under the whole sheet, a cart driving on the ice where the lake dips sat in
## it and threw spray.
@export var holes := PackedVector4Array()
@export var hole_y := PackedFloat32Array()

## A cart counts as in a hole from this far out past its rim, where its wheels are over the edge.
const HOLE_MARGIN := 0.3

## The lead under the sheet, everywhere within lead_half_w of its centreline. A cart that went
## through a hole can roll on under the ice along the lead's bed; there it must still count as under
## water, or it sits stuck under the sheet. So the lead outside the holes answers under_ice_y: far
## enough down that a cart on top of the ice never touches it, and far above a cart on the bed.
@export var lead_line := PackedVector2Array()
@export var lead_half_w := 0.0
@export var under_ice_y := 0.0

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
	for i in range(holes.size()):
		var h: Vector4 = holes[i]
		var rel := Vector2(x - h.x, z - h.y)
		if rel.length() <= _rim(h, atan2(rel.y, rel.x)) + HOLE_MARGIN:
			return hole_y[i]
	if _lead_box.has_point(q):
		for i in range(lead_line.size() - 1):
			var a: Vector2 = lead_line[i]
			var ab: Vector2 = lead_line[i + 1] - a
			var t: float = clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
			if q.distance_to(a + ab * t) <= lead_half_w:
				return under_ice_y
	return NAN


## A hole's rim at angle `ang`: the same ragged circle as the generator's _hole_rim().
static func _rim(h: Vector4, ang: float) -> float:
	return h.z * (1.0 + 0.09 * sin(3.0 * ang + h.w) + 0.05 * sin(7.0 * ang + 2.3 * h.w))
