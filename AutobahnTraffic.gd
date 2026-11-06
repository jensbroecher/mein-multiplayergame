extends Node3D
## Traffic on a straight road along this node's -z (Kronburger Hütte's Autobahn viaduct): `meshes` (vehicles, nose toward
## -z) driven along `lanes` (x offsets; positive lanes run toward -z, negative ones back toward +z) over `length` metres,
## on the wall clock so every peer sees the same traffic, each vehicle at its own speed and spacing. A vehicle shrinks to
## nothing over `fade` metres at either end. One MultiMesh per vehicle kind; nothing on a headless server. Not solid.

@export var meshes: Array[Mesh] = []
@export var lanes := PackedFloat32Array([5.0, -5.0])
@export var length := 1000.0
@export var per_lane := 7
@export var speeds := Vector2(26.0, 42.0)
@export var fade := 40.0
## Optional: the road's height (over this node's y) every `height_step` metres along its length (Rheinufer's A 47 rises
## over the Rhine; Kronburger Hütte's viaduct is level and leaves it empty). Vehicles follow it and pitch with it.
@export var heights := PackedFloat32Array()
@export var height_step := 10.0

var _mmis: Array[MultiMeshInstance3D] = []
## Per vehicle: [kind, index in its kind, lane x, direction (+1 toward -z), speed, phase].
var _cars: Array = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or meshes.is_empty():
		set_process(false)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4747
	var counts: Array[int] = []
	counts.resize(meshes.size())
	counts.fill(0)
	for li in range(lanes.size()):
		var lane_speed: float = rng.randf_range(speeds.x, speeds.y) * (1.12 if absf(lanes[li]) < 8.0 else 0.92)
		for k in range(per_lane):
			var kind: int = rng.randi_range(0, meshes.size() - 1)
			var phase: float = (float(k) + rng.randf_range(-0.3, 0.3)) / float(per_lane) * length
			_cars.append([kind, counts[kind], lanes[li], 1.0 if lanes[li] > 0.0 else -1.0, lane_speed * rng.randf_range(0.97, 1.03), phase])
			counts[kind] += 1
	for i in range(meshes.size()):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[i]
		mm.instance_count = counts[i]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var top := 12.0
		for h in heights:
			top = maxf(top, h + 12.0)
		mmi.custom_aabb = AABB(Vector3(-20, -2, -length - 20), Vector3(40, top, length + 40))
		add_child(mmi, false, Node.INTERNAL_MODE_BACK)
		_mmis.append(mmi)


func _process(_delta: float) -> void:
	var t: float = fposmod(Time.get_unix_time_from_system(), 86400.0)
	for c in _cars:
		var speed: float = c[4]
		var s: float = fposmod(t * speed + float(c[5]), length)
		var dir: float = c[3]
		var z: float = -s if dir > 0.0 else -(length - s)
		var sc: float = clampf(minf(s, length - s) / fade, 0.0, 1.0)
		var basis := Basis() if dir > 0.0 else Basis(Vector3.UP, PI)
		var y := 0.0
		if heights.size() > 1:
			var d: float = -z
			y = _height(d)
			var slope: float = (_height(d + 2.0) - _height(d - 2.0)) / 4.0
			basis = basis * Basis(Vector3.RIGHT, atan(slope) * dir)
		_mmis[c[0]].multimesh.set_instance_transform(c[1], Transform3D(basis.scaled(Vector3.ONE * maxf(sc, 0.001)), Vector3(c[2], y, z)))


func _height(d: float) -> float:
	var f: float = clampf(d / height_step, 0.0, float(heights.size() - 1))
	var i: int = mini(int(f), heights.size() - 2)
	return lerpf(heights[i], heights[i + 1], f - float(i))
