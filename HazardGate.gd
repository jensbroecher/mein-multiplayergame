extends Node3D
## Where the route meets a moving hazard (Quer durch Kronburg: the Ring's traffic, the wrecking ball, the scrapyard's
## magnet, the excavator's bucket): this node stands on the route's line at the hazard, its -z along the route. It joins
## the "rail_crossings" group, so PlayerCart's `_ai_rail_crossing_override` makes a bot stop `ai_stop_short` metres short
## of it while the hazard will be over the road when the bot gets there, and drive on once it won't (as at Estación
## Seca's level crossings). It also keeps bots from firing a boost into it (`_ai_rail_crossing_ahead`).
##
## The hazard (`hazard`, a node path) gives `period` (seconds), `cycle_time()` (seconds into its cycle, from the wall
## clock) and `cover_intervals(gate)`: when in its cycle it covers the road here, as [start, end] pairs (it works them
## out once, for this gate's place and heading, and keeps them).

@export var hazard: NodePath
@export var ai_stop_short := 12.0
## Half the road's width here, and how far along the route either side of this node the hazard counts as on the road.
@export var road_half := 7.5
@export var reach := 6.0
## Seconds before and after the bot's arrival the road must be clear (it is not a point: the bot takes a while to cross).
@export var lead := 0.8
@export var trail := 1.6
## The slack either side of that window (seconds); negative: what the bot asks for (PlayerCart passes 1.6). A fast hazard
## with short gaps (the wrecking ball) needs less, or the gate never opens.
@export var own_margin := -1.0

var _hz: Node


func _ready() -> void:
	add_to_group("rail_crossings")
	_hz = get_node_or_null(hazard)


## Whether the hazard will be on the road here at any time from `eta` seconds from now (widened by `margin`).
func is_closed_for(eta: float, margin := 1.0) -> bool:
	if _hz == null or not is_instance_valid(_hz):
		return false
	var period: float = float(_hz.get("period"))
	if period <= 0.0:
		return false
	if own_margin >= 0.0:
		margin = own_margin
	var tt: float = _hz.cycle_time()
	var a: float = tt + eta - lead - margin
	var b: float = tt + eta + trail + margin
	for iv in _hz.cover_intervals(self):
		for k in [-1.0, 0.0, 1.0, 2.0]:
			var s0: float = float(iv[0]) + k * period
			var s1: float = float(iv[1]) + k * period
			if s1 >= a and s0 <= b:
				return true
	return false


## Whether a point (world) lies on the road here: within `road_half` (+ `pad`) across the route and `reach` along it.
func on_road(p: Vector3, pad := 0.0) -> bool:
	var q: Vector3 = global_transform.affine_inverse() * p
	return absf(q.x) < road_half + pad and absf(q.z) < reach + pad
