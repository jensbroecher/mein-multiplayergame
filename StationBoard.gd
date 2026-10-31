extends Node3D
## A departure board at a monorail station (Bloombay's South Beach): a dark LED panel in a white frame
## with amber text, the station's name and the time of day across the top, the next trains under it
## (where each goes and when it comes: in minutes, DUE, or BOARDING while it waits at the platform) and
## a line along the bottom. It reads the timetable from the train (Monorail.gd's upcoming(), the same wall
## clock the train runs on), so every peer's board agrees without syncing. Panel and text are built here
## as internal children: a level stores only the transform and the settings. +z is the board's face;
## `two_sided` puts the same text on its back too, for a board hung across a platform.

@export var train: NodePath
## The stops (indices into the train's `stops`) this platform serves.
@export var at := PackedInt32Array()
@export var station_name := "SOUTH BEACH"
@export var size := Vector2(3.6, 1.6)
@export var two_sided := false

const AMBER := Color(1.0, 0.62, 0.14)
const PANEL := Color(0.04, 0.045, 0.05)
const FRAME := Color(0.93, 0.95, 0.96)
const ROWS := 2
const REFRESH := 0.25

var _faces: Array = []   # per face: {"title", "clock", "dest": [], "when": [], "status"}
var _train: Node
var _wait := 0.0


func _ready() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _panel_mesh()
	add_child(mi, false, Node.INTERNAL_MODE_BACK)
	_faces.append(_face(Transform3D.IDENTITY))
	if two_sided:
		_faces.append(_face(Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)))
	_refresh()


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = REFRESH
	_refresh()


func _refresh() -> void:
	if _train == null or not is_instance_valid(_train):
		_train = get_node_or_null(train)
	var calls: Array = _train.upcoming(at, ROWS) if _train and _train.has_method("upcoming") else []
	var names: PackedStringArray = _train.get("stop_names") if _train else PackedStringArray()
	var t := Time.get_time_dict_from_system()
	var clock := "%02d%s%02d" % [t.hour, ":" if int(Time.get_ticks_msec() / 500) % 2 == 0 else " ", t.minute]
	var status := "STAND BEHIND THE YELLOW LINE"
	if not calls.is_empty():
		var first: Dictionary = calls[0]
		var dest := _name(names, int(first["to"]))
		if float(first["arrive"]) <= 0.0:
			status = "NOW BOARDING - DEPARTS IN %ds" % ceili(float(first["leave"]))
		elif float(first["arrive"]) < 45.0:
			status = "TRAIN APPROACHING - %s" % dest
	for f in _faces:
		(f["clock"] as Label3D).text = clock
		(f["status"] as Label3D).text = status
		for r in ROWS:
			var dest_l: Label3D = f["dest"][r]
			var when_l: Label3D = f["when"][r]
			if r < calls.size():
				var c: Dictionary = calls[r]
				dest_l.text = _name(names, int(c["to"]))
				when_l.text = _when(float(c["arrive"]))
			else:
				dest_l.text = ""
				when_l.text = ""


func _name(names: PackedStringArray, i: int) -> String:
	return names[i] if i < names.size() else "STOP %d" % i


func _when(arrive: float) -> String:
	if arrive <= 0.0:
		return "BOARDING"
	if arrive < 45.0:
		return "DUE"
	return "%d MIN" % ceili(arrive / 60.0)


## The text of one face (the +z one, turned by `xf`): title and clock, ROWS rows, a status line.
func _face(xf: Transform3D) -> Dictionary:
	var hw := size.x * 0.5 - 0.16
	var top := size.y * 0.5 - 0.2
	var row_h := (size.y - 0.4) / (ROWS + 2)
	var f := {"dest": [], "when": []}
	f["title"] = _label(xf, Vector3(-hw, top, 0), station_name, HORIZONTAL_ALIGNMENT_LEFT, 0.0042)
	f["clock"] = _label(xf, Vector3(hw, top, 0), "", HORIZONTAL_ALIGNMENT_RIGHT, 0.0042)
	for r in ROWS:
		var y := top - row_h * (r + 1.1)
		f["dest"].append(_label(xf, Vector3(-hw, y, 0), "", HORIZONTAL_ALIGNMENT_LEFT, 0.0032))
		f["when"].append(_label(xf, Vector3(hw, y, 0), "", HORIZONTAL_ALIGNMENT_RIGHT, 0.0032))
	f["status"] = _label(xf, Vector3(-hw, top - row_h * (ROWS + 1.15), 0), "", HORIZONTAL_ALIGNMENT_LEFT, 0.0024)
	return f


func _label(xf: Transform3D, at_pos: Vector3, text: String, align: HorizontalAlignment, pixel: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = pixel
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.uppercase = true
	l.shaded = false
	l.double_sided = false
	l.outline_size = 0
	# Over 1, so the glow picks the letters up like lit LEDs.
	l.modulate = Color(AMBER.r * 1.6, AMBER.g * 1.6, AMBER.b * 1.6)
	l.position = xf * (at_pos + Vector3(0, 0, 0.035))
	l.basis = xf.basis
	add_child(l, false, Node.INTERNAL_MODE_BACK)
	return l


## The panel: a dark face (both sides) in a white frame, a hood over the top.
func _panel_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	_box(st, Vector3(0, 0, 0), Vector3(size.x - 0.1, size.y - 0.1, 0.05), PANEL)
	_box(st, Vector3(0, hy - 0.03, 0), Vector3(size.x, 0.06, 0.1), FRAME)
	_box(st, Vector3(0, -hy + 0.03, 0), Vector3(size.x, 0.06, 0.1), FRAME)
	_box(st, Vector3(-hx + 0.03, 0, 0), Vector3(0.06, size.y, 0.1), FRAME)
	_box(st, Vector3(hx - 0.03, 0, 0), Vector3(0.06, size.y, 0.1), FRAME)
	_box(st, Vector3(0, hy + 0.04, 0), Vector3(size.x + 0.12, 0.05, 0.3), FRAME.darkened(0.08))
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.4
	mesh.surface_set_material(0, mat)
	return mesh


static func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	var faces := [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1] * (h * f[1].abs())
		var v: Vector3 = f[2] * (h * f[2].abs())
		var o: Vector3 = c + n * (h * n.abs())
		var q := [o - u - v, o + u - v, o + u + v, o - u + v]
		# Front faces wind clockwise seen from outside: (c - a) x (b - a) along the normal.
		var tri := [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]
		for t in tri:
			var a: Vector3 = t[0]
			var b: Vector3 = t[1]
			var cc: Vector3 = t[2]
			if (cc - a).cross(b - a).dot(n) < 0.0:
				var tmp := b
				b = cc
				cc = tmp
			for p in [a, b, cc]:
				st.set_color(col)
				st.add_vertex(p)
