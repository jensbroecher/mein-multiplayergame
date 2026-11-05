extends RefCounted
## The race start's camera move (PlayerCart's intro): from a wide, high view of the grid it sweeps round and comes
## down onto the race camera, ending exactly where that camera is, so the hand-over doesn't show.
##
## The path is in polar coordinates about the player's car: the angle sweeps `sweep` toward the race camera's own
## angle (from `side`), the distance and height ease from the start's to the race camera's, all on one smootherstep,
## so it starts and stops at rest. The view turns from the car to the race camera's aim over the second half, and the
## last quarter blends onto the race camera's live pose.
##
## Which start: `choose` tries CANDIDATES (both sides, three sweeps, two heights, and a crane straight down from high
## behind) and walks each path, scoring how much of it sees the car: the line of sight blocked (a building, a hill, a
## roof), the camera inside something or under the ground, and trees along the line. Trees' crowns have no collider,
## only their trunks (DressingColliders' cylinders, a level's own trunk bodies), so a trunk standing within CROWN_R of
## the ground under the line, where the line is low enough to be in a crown, counts as a crown in the way. Mtaa Nights'
## houses and Lakeside's spruces beside the grid sent the old orbit (always the same 180 degrees in world axes, ending
## at a fixed world offset the race camera then snapped from) through walls and branches.

## [sweep (degrees), start distance (m), start height (m)], tried on both sides, in order of preference; then the crane.
## The last ones come in from straight behind the grid, far back and low: down a street between houses (Mtaa
## Nights), where every sweep meets a wall and only the crane, looking straight down into the street, was clear.
const CANDIDATES := [
	[150.0, 50.0, 26.0], [150.0, 36.0, 38.0],
	[100.0, 50.0, 26.0], [100.0, 36.0, 38.0],
	[60.0, 46.0, 30.0], [60.0, 32.0, 44.0],
	[25.0, 70.0, 20.0], [0.0, 80.0, 16.0], [0.0, 55.0, 24.0],
]
const CRANE_HEIGHT := 58.0
## Points scored along each path (over its first 85%: the rest is the race camera's own view).
const SAMPLES := 12
const SCORED_SHARE := 0.85
## Trees: a trunk within CROWN_R of the ground under a point of the line of sight, where that point is CROWN_FROM to
## CROWN_TOP over the ground, is a crown in the way. The last NEAR_CAR metres to the car aren't tested (the grid).
const CROWN_R := 3.5
const CROWN_FROM := 3.0
const CROWN_TOP := 20.0
const NEAR_CAR := 8.0
const LINE_STEP := 3.0
## The camera keeps this far over the ground, and this far from anything solid.
const GROUND_CLEAR := 2.5
const SOLID_CLEAR := 1.2
## Trunks, by their body's name (or its parent's): DressingColliders' plant cells (tree trunks are their tall
## cylinders; shrubs' boxes stop under CROWN_FROM) and the levels' own trunk bodies.
const TRUNK_WORDS := ["dressingsolid_plant", "tree", "trunk", "palm", "forest", "jungle", "woodland", "spruce", "pine"]


static func candidates() -> Array:
	var out: Array = []
	for c in CANDIDATES:
		for side in ([1.0, -1.0] if float(c[0]) > 0.0 else [1.0]):
			out.append({"sweep": deg_to_rad(float(c[0])), "dist": float(c[1]), "h": float(c[2]), "side": side,
				"name": ("%s %d deg from %dm, %dm up" % ["left" if side > 0.0 else "right", int(c[0]), int(c[1]), int(c[2])]) if float(c[0]) > 0.0 \
					else "straight in from %dm back, %dm up" % [int(c[1]), int(c[2])]})
	out.append({"sweep": 0.0, "dist": -1.0, "h": CRANE_HEIGHT, "side": 1.0, "name": "crane from %dm up" % int(CRANE_HEIGHT)})
	return out


## The camera's position and the point it looks at, `t` (0..1) along the move, for the race camera at `race_pos`
## looking at `race_look`.
static func pose(plan: Dictionary, centre: Vector3, race_pos: Vector3, race_look: Vector3, t: float) -> Array:
	t = clampf(t, 0.0, 1.0)
	# The path's end is fixed when it is planned (`end_pos`, `end_look`: the race camera's rest pose); only the last
	# quarter blends onto the live race camera, so the sweep never swings with it.
	var end_pos: Vector3 = plan.get("end_pos", race_pos)
	var end_look: Vector3 = plan.get("end_look", race_look)
	var rel: Vector3 = end_pos - centre
	var ang_end: float = atan2(rel.z, rel.x)
	var dist_end: float = Vector2(rel.x, rel.z).length()
	var dist0: float = float(plan.get("dist", 40.0))
	if dist0 <= 0.0:
		dist0 = dist_end * 1.15 + 6.0
	dist0 = maxf(dist0, dist_end)
	var h0: float = maxf(float(plan.get("h", 30.0)), rel.y)
	var e: float = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	var ang: float = ang_end + float(plan.get("side", 1.0)) * float(plan.get("sweep", 0.0)) * (1.0 - e)
	var dist: float = lerpf(dist0, dist_end, e)
	var p: Vector3 = centre + Vector3(cos(ang) * dist, lerpf(h0, rel.y, e), sin(ang) * dist)
	var look: Vector3 = (centre + Vector3.UP * 0.8).lerp(end_look, smoothstep(0.45, 1.0, t))
	var w: float = smoothstep(0.75, 1.0, t)
	return [p.lerp(race_pos, w), look.lerp(race_look, w)]


## The candidate whose path sees the car best (ties go to the earlier, wider sweep), with its `cost` (0: clear all the
## way) and `name`.
static func choose(space: PhysicsDirectSpaceState3D, centre: Vector3, race_pos: Vector3, race_look: Vector3,
		excludes: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_cost := INF
	var cands: Array = candidates()
	for i in cands.size():
		var c: Dictionary = cands[i]
		var cost := 0.0
		for k in SAMPLES:
			var t: float = float(k) / float(SAMPLES - 1) * SCORED_SHARE
			var pr: Array = pose(c, centre, race_pos, race_look, t)
			cost += blocked(space, pr[0], centre + Vector3.UP * 1.0, excludes)
			if cost >= best_cost:
				break
		cost += float(i) * 0.001
		if cost < best_cost:
			best_cost = cost
			best = c
	best = best.duplicate()
	best["cost"] = best_cost
	best["end_pos"] = race_pos
	best["end_look"] = race_look
	return best


## How badly the view from `p` to `target` is blocked: 0 clear, 0.6 a tree's crown in the way, 1 the line blocked,
## 1.5 the camera inside or against something, 2 under (or nearly at) the ground.
static func blocked(space: PhysicsDirectSpaceState3D, p: Vector3, target: Vector3, excludes: Array) -> float:
	var down := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 80.0, p + Vector3.DOWN * 120.0)
	down.exclude = excludes
	var hit: Dictionary = space.intersect_ray(down)
	if not hit.is_empty() and float(hit["position"].y) > p.y - GROUND_CLEAR:
		return 2.0
	var sphere := SphereShape3D.new()
	sphere.radius = SOLID_CLEAR
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis(), p)
	q.exclude = excludes
	if not space.intersect_shape(q, 1).is_empty():
		return 1.5
	var los := PhysicsRayQueryParameters3D.create(p, target)
	los.exclude = excludes
	var lh: Dictionary = space.intersect_ray(los)
	if not lh.is_empty() and (lh["position"] as Vector3).distance_to(target) > 1.5:
		return 1.0
	var line: float = p.distance_to(target)
	var d := 0.0
	while d < line - NEAR_CAR:
		var at: Vector3 = p.lerp(target, d / line)
		d += LINE_STEP
		if _crown_in_way(space, at, excludes):
			return 0.6
	return 0.0


## Whether a tree's trunk stands within CROWN_R of the ground under `at`, with
## `at` low enough over that ground to be in its crown.
static func _crown_in_way(space: PhysicsDirectSpaceState3D, at: Vector3, excludes: Array) -> bool:
	var down := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * (CROWN_TOP + 2.0))
	down.exclude = excludes
	var hit: Dictionary = space.intersect_ray(down)
	if hit.is_empty():
		return false
	var gy: float = float(hit["position"].y)
	var above: float = at.y - gy
	if above < CROWN_FROM + 1.0 or above > CROWN_TOP:
		return false
	var cyl := CylinderShape3D.new()
	cyl.radius = CROWN_R
	cyl.height = above - CROWN_FROM
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cyl
	q.transform = Transform3D(Basis(), Vector3(at.x, gy + CROWN_FROM + cyl.height * 0.5, at.z))
	var ex: Array = excludes.duplicate()
	ex.append(hit["rid"])
	q.exclude = ex
	for r in space.intersect_shape(q, 8):
		var col: Object = r.get("collider")
		if col is Node and _trunk(col as Node):
			return true
	return false


static func _trunk(n: Node) -> bool:
	var s := String(n.name).to_lower()
	if n.get_parent():
		s += " " + String(n.get_parent().name).to_lower()
	for w in TRUNK_WORDS:
		if s.contains(w):
			return true
	return false
