@tool
extends Node3D
## The game's people in one line, for checking them by eye: open scratch/human_lineup.tscn in the editor and look
## round, or run it (F6) to fly along it. Everything is built here as internal children (nothing is saved in the scene).
##
## The spectators are the game's own: generated/crowd_person.res drawn by stadium_person.gdshader, so they do their
## real animations (bursts of cheering, clapping and waving, hops, weight shifts, sips, glances). Each one's outfit is
## spelled out (crowd_common.gdshaderinc's explicit seeds: `lineup_code` packs it), so the line covers every pose with
## its prop, every hairstyle, every kind of shirt, trousers, shorts, dresses and shoes, sunglasses and beards, the
## skin groups, children, yukata and the flags, and then the far-away cards (stadium_crowd.gdshader) of the 16 poses.
## A number and a description float over each. A car drives up and down the line (the spectators near it turn to
## watch it, as they watch player one's car in a race), and the Lakeside's cyclists ride a loop behind it when the
## scene runs (Cyclists.gd isn't a tool script).
##
## Running: WASD (or the arrows) and Q/E fly, the right mouse button looks round, Shift is fast, the wheel sets the
## speed, 1-9 jump to a section, C stops or starts the car, L hides the labels, Esc quits.

const PERSON_MESH := "res://generated/crowd_person.res"
## The game's spectators are 1.86 times life; most stages draw them at their props' 1.6 (CrowdPlacer's `scale`).
const FIGURE_SCALE := 1.6 / 1.86
## Figure units (before FIGURE_SCALE) between neighbours, and between sections.
const SPACING := 3.0
const SECTION_GAP := 4.0
const SEAT_H := 0.84
const CARD_FORWARD := 0.6
const CARDS := [
	[1.1, 2.75, 0.9, 0.0, 0.475],
	[2.1, 3.15, 0.9, 0.0, 0.675],
	[1.1, 3.5, 1.65, 0.0, 1.75],
	[2.1, 3.9, 1.65, 0.0, 1.95],
	[3.0, 4.9, 1.65, -0.5, 2.45],
]

const POSE_NAMES := ["sitting, idle", "sitting, clapping", "sitting, filming (phone)", "sitting, talking",
	"sitting, arms crossed", "sitting, cheering", "sitting, drinking (bottle)", "idle", "clapping", "cheering (some hop)",
	"filming (phone)", "arms crossed", "waving a flag", "hands on hips", "waving", "drinking (bottle)"]
const HAIR_NAMES := ["bald", "short hair", "afro", "long hair", "cap", "headscarf"]
const PATTERN_NAMES := ["plain", "plain", "plain", "hoops", "stripes", "chest band", "badge", "plain"]
const SHIRT_NAMES := ["orange", "green", "yellow", "white", "red", "blue", "black", "grey", "pink", "light blue", "purple", "teal"]
const TROUSER_NAMES := ["navy", "black", "khaki", "grey", "denim", "stone", "olive", "brown"]
const YUKATA_NAMES := ["indigo", "white", "pink", "midnight", "red", "lilac", "teal", "cream"]
const FLAG_NAMES := ["orange and green", "red and white", "blue and yellow"]

@export var car_drives := true
@export var car_name := "Mudrunner"
@export var car_speed := 13.0

var _labels: Array[Label3D] = []
var _sections: Array = []          # [name, x of its first figure (world)]
var _car: Node3D
var _car_wheels: Array = []
var _car_radius := 0.4
var _car_loop: Array = []          # the car's way: [start, end, kind] pieces, built in _build_car
var _car_len := 0.0
var _line_end := 0.0
var _cam: Camera3D
var _speed := 12.0
var _look := false
var _yaw := 0.0
var _pitch := -0.18


func _ready() -> void:
	for c in get_children(true):
		if c.get_meta(&"lineup", false):
			c.queue_free()
	_build()


func _add(node: Node, parent: Node = self) -> Node:
	node.set_meta(&"lineup", true)
	parent.add_child(node, false, Node.INTERNAL_MODE_FRONT)
	return node


# ---------------------------------------------------------------------------------------------
#  Who stands in the line
# ---------------------------------------------------------------------------------------------

## An outfit, the defaults overridden by `o`: shirt (0-11), female, dress, sleeves (long), long (trousers), pattern
## (0-7), white_shoes, flag (0-2), beard, sun (sunglasses), hair (0-5), kid, colb (trousers, and a yukata's colour:
## 0-7), skin (the skin draw, 0-1), yukata.
func _o(o: Dictionary) -> Dictionary:
	var d := {"shirt": 0, "female": false, "dress": false, "sleeves": false, "long": true, "pattern": 0, "white_shoes": true,
		"flag": 0, "beard": false, "sun": false, "hair": 1, "kid": false, "colb": 0, "skin": 0.5, "yukata": false}
	d.merge(o, true)
	return d


## The outfit's code: crowd_common.gdshaderinc's explicit seed is 2 + this.
static func lineup_code(o: Dictionary) -> int:
	var c := int(o["shirt"]) & 15
	c |= (1 if o["female"] else 0) << 4
	c |= (1 if o["dress"] else 0) << 5
	c |= (1 if o["sleeves"] else 0) << 6
	c |= (1 if o["long"] else 0) << 7
	c |= (int(o["pattern"]) & 7) << 8
	c |= (1 if o["white_shoes"] else 0) << 11
	c |= (int(o["flag"]) & 3) << 12
	c |= (1 if o["beard"] else 0) << 14
	c |= (1 if o["sun"] else 0) << 15
	c |= (int(o["hair"]) & 7) << 16
	c |= (1 if o["kid"] else 0) << 19
	c |= (int(o["colb"]) & 7) << 20
	return c


func _sections_list() -> Array:
	var poses := [
		[0, _o({"female": true, "hair": 3, "shirt": 8, "colb": 4, "skin": 0.90})],
		[1, _o({"hair": 1, "shirt": 5, "pattern": 3, "colb": 2, "skin": 0.30})],
		[2, _o({"female": true, "hair": 4, "shirt": 3, "colb": 1, "skin": 0.945})],
		[3, _o({"hair": 0, "beard": true, "shirt": 7, "sleeves": true, "colb": 0, "skin": 0.55})],
		[4, _o({"female": true, "hair": 2, "shirt": 2, "colb": 6, "skin": 0.20})],
		[5, _o({"hair": 4, "shirt": 0, "pattern": 5, "colb": 1, "skin": 0.83})],
		[6, _o({"female": true, "hair": 5, "shirt": 11, "sleeves": true, "colb": 3, "skin": 0.98})],
		[7, _o({"hair": 1, "shirt": 4, "colb": 4, "skin": 0.65})],
		[8, _o({"female": true, "hair": 3, "dress": true, "shirt": 10, "skin": 0.88})],
		[9, _o({"hair": 2, "sun": true, "shirt": 1, "pattern": 4, "colb": 0, "skin": 0.40})],
		[10, _o({"female": true, "hair": 1, "shirt": 9, "colb": 5, "skin": 0.95})],
		[11, _o({"hair": 1, "shirt": 6, "sleeves": true, "colb": 3, "skin": 0.97})],
		[12, _o({"hair": 4, "shirt": 2, "flag": 0, "colb": 1, "skin": 0.50})],
		[13, _o({"female": true, "hair": 3, "shirt": 4, "long": false, "colb": 2, "skin": 0.84})],
		[14, _o({"hair": 1, "shirt": 3, "pattern": 6, "colb": 0, "skin": 0.91})],
		[15, _o({"female": true, "hair": 2, "dress": true, "shirt": 0, "skin": 0.25})],
	]
	var hair := [
		[7, _o({"hair": 0, "beard": true, "shirt": 5, "skin": 0.45})],
		[8, _o({"hair": 1, "shirt": 1, "colb": 2, "skin": 0.60})],
		[14, _o({"female": true, "hair": 2, "shirt": 8, "colb": 4, "skin": 0.15})],
		[13, _o({"female": true, "hair": 3, "shirt": 11, "colb": 0, "skin": 0.89})],
		[9, _o({"female": true, "hair": 4, "shirt": 10, "colb": 1, "skin": 0.70})],
		[11, _o({"female": true, "hair": 5, "shirt": 9, "sleeves": true, "colb": 6, "skin": 0.97})],
	]
	var clothes := [
		[7, _o({"shirt": 5, "pattern": 0, "colb": 2, "skin": 0.35})],
		[9, _o({"shirt": 4, "pattern": 3, "colb": 0, "skin": 0.62})],
		[8, _o({"shirt": 3, "pattern": 4, "colb": 1, "skin": 0.90})],
		[14, _o({"shirt": 2, "pattern": 5, "colb": 6, "skin": 0.18})],
		[13, _o({"shirt": 6, "pattern": 6, "colb": 5, "skin": 0.84})],
		[11, _o({"shirt": 1, "sleeves": true, "colb": 7, "skin": 0.50})],
		[7, _o({"shirt": 0, "long": false, "colb": 4, "skin": 0.28})],
		[8, _o({"female": true, "hair": 3, "dress": true, "shirt": 9, "skin": 0.92})],
		[15, _o({"shirt": 7, "white_shoes": false, "colb": 3, "skin": 0.75})],
		[10, _o({"hair": 1, "sun": true, "shirt": 8, "colb": 0, "skin": 0.945})],
		[13, _o({"hair": 1, "beard": true, "shirt": 11, "colb": 2, "skin": 0.98})],
	]
	var skins := []
	var draws := [0.10, 0.45, 0.78, 0.83, 0.90, 0.945, 0.985]
	var skin_poses := [7, 13, 8, 14, 9, 11, 7]
	for i in range(draws.size()):
		skins.append([skin_poses[i], _o({"female": i % 2 == 1, "hair": 3 if i % 2 == 1 else 1, "shirt": (i * 5) % 12, "colb": i, "skin": draws[i]})])
	var kids := [
		[9, _o({"kid": true, "hair": 1, "shirt": 4, "pattern": 3, "colb": 0, "skin": 0.40})],
		[14, _o({"kid": true, "female": true, "hair": 3, "dress": true, "shirt": 8, "skin": 0.90})],
		[7, _o({"kid": true, "hair": 4, "shirt": 2, "long": false, "colb": 1, "skin": 0.20})],
		[0, _o({"kid": true, "female": true, "hair": 2, "shirt": 9, "colb": 4, "skin": 0.60})],
	]
	var yukata := [
		[7, _o({"female": true, "hair": 3, "yukata": true, "colb": 0, "shirt": 0, "skin": 0.945})],
		[14, _o({"female": true, "hair": 1, "yukata": true, "colb": 2, "shirt": 3, "skin": 0.95})],
		[11, _o({"hair": 1, "yukata": true, "colb": 3, "shirt": 1, "skin": 0.94})],
		[10, _o({"female": true, "hair": 3, "yukata": true, "colb": 5, "shirt": 4, "skin": 0.88})],
		[1, _o({"female": true, "hair": 3, "yukata": true, "colb": 7, "shirt": 2, "skin": 0.945})],
		[9, _o({"kid": true, "female": true, "hair": 1, "yukata": true, "colb": 4, "shirt": 5, "skin": 0.95})],
	]
	var flags := [
		[12, _o({"hair": 1, "shirt": 3, "flag": 1, "colb": 1, "skin": 0.30})],
		[12, _o({"female": true, "hair": 3, "shirt": 5, "flag": 2, "colb": 0, "skin": 0.90})],
	]
	return [
		["1  Every pose, with its prop", poses, false],
		["2  Hair", hair, false],
		["3  Shirts, trousers, shorts, dresses, shoes", clothes, false],
		["4  Skin", skins, false],
		["5  Children", kids, false],
		["6  Yukata (Yoshino Rapids' fair)", yukata, false],
		["7  Flags", flags, false],
		["8  Far away: the flat cards of the 16 poses", poses, true],
	]


func _describe(n: int, pose: int, o: Dictionary, card: bool) -> String:
	var who: String = ("girl" if o["female"] else "boy") if o["kid"] else ("woman" if o["female"] else "man")
	var bits: Array = [HAIR_NAMES[int(o["hair"])]]
	if o["beard"] and not o["female"]:
		bits.append("beard")
	if o["sun"]:
		bits.append("sunglasses")
	var clothes: String
	if o["yukata"]:
		clothes = "%s yukata, obi" % YUKATA_NAMES[int(o["colb"])]
	else:
		var shirt: String = "%s %s" % [SHIRT_NAMES[int(o["shirt"])], "shirt" if PATTERN_NAMES[int(o["pattern"])] == "plain" else PATTERN_NAMES[int(o["pattern"])] + " shirt"]
		if o["sleeves"]:
			shirt += ", long sleeves"
		var legs: String
		if o["dress"] and o["female"]:
			legs = "%s dress" % SHIRT_NAMES[(int(o["shirt"]) + 5) % 12]
		else:
			legs = "%s %s" % [TROUSER_NAMES[int(o["colb"])], "trousers" if o["long"] else "shorts"]
		clothes = "%s, %s, %s shoes" % [shirt, legs, "white" if o["white_shoes"] else "black"]
	var extra := ""
	if pose == 12:
		extra = "\nflag: " + FLAG_NAMES[int(o["flag"])]
	return "#%d  %s%s\n%s, %s\n%s%s" % [n, POSE_NAMES[pose], "  (far card)" if card else "", who, ", ".join(bits), clothes, extra]


# ---------------------------------------------------------------------------------------------
#  Building
# ---------------------------------------------------------------------------------------------

func _build() -> void:
	_build_world()
	var people := Node3D.new()
	people.name = "People"
	people.scale = Vector3.ONE * FIGURE_SCALE
	_add(people)
	var xfs: Array = []
	var cds: Array = []
	var card_items: Array = []        # per card class: [transforms, customs]
	for k in range(CARDS.size()):
		card_items.append([[], []])
	var stools: Array = []
	var codes := PackedInt32Array()
	var x := 0.0
	var n := 0
	_sections.clear()
	_labels.clear()
	for sec in _sections_list():
		_sections.append([sec[0], x * FIGURE_SCALE])
		var banner := Label3D.new()
		banner.text = sec[0]
		banner.font_size = 96
		banner.outline_size = 18
		banner.pixel_size = 0.012
		banner.modulate = Color(1.0, 0.86, 0.35)
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		banner.position = Vector3(x - 1.2, 9.4, 0.0)
		_add(banner, people)
		_labels.append(banner)
		var i := 0
		for entry in sec[1]:
			var pose: int = entry[0]
			var o: Dictionary = entry[1]
			var card: bool = sec[2]
			var seated := pose < 7
			n += 1
			var phase := fposmod(float(n) * 0.6180339 + 0.13, 1.0)
			# The outfit's code goes to the materials (crowd_lineup), its number in the list through the instance.
			codes.append(lineup_code(o))
			var cd := Color(2.0 + float(codes.size() - 1), float(o["skin"]) + (2.0 if o["yukata"] else 0.0), (float(pose) + 0.5) / 16.0, phase)
			var pos := Vector3(x, SEAT_H if seated else 0.0, 0.0)
			if card:
				var cls := 1 if pose == 5 else (3 if (pose == 9 or pose == 14) else (4 if pose == 12 else (2 if pose >= 7 else 0)))
				card_items[cls][0].append(Transform3D(Basis(), pos + Vector3(0, 0, CARD_FORWARD if seated else 0.0)))
				card_items[cls][1].append(cd)
			else:
				xfs.append(Transform3D(Basis(), pos))
				cds.append(cd)
			if seated:
				stools.append(Vector3(x, SEAT_H * 0.5, 0.0))
			var lb := Label3D.new()
			lb.text = _describe(n, pose, o, card)
			# Facing the front, wrapped to the gap between neighbours (as billboards they piled up seen along the line).
			lb.font_size = 40
			lb.outline_size = 10
			lb.pixel_size = 0.0075
			lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lb.width = SPACING * 0.92 / 0.0075
			lb.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			lb.position = Vector3(x, 5.6, 0.0)
			_add(lb, people)
			_labels.append(lb)
			# A number on the ground in front, readable from above.
			var num := Label3D.new()
			num.text = str(n)
			num.font_size = 72
			num.outline_size = 14
			num.pixel_size = 0.01
			num.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
			num.position = Vector3(x, 0.02, 1.6)
			_add(num, people)
			x += SPACING
			i += 1
		x += SECTION_GAP
	_line_end = (x - SECTION_GAP) * FIGURE_SCALE
	# The 3D figures.
	var person: Mesh = load(PERSON_MESH)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://stadium_person.gdshader")
	mat.set_shader_parameter("lod_mode", 1)
	mat.set_shader_parameter("lod_fade_begin", 900.0)
	mat.set_shader_parameter("lod_fade_end", 1000.0)
	mat.set_shader_parameter("lod_jitter", 0.0)
	codes.resize(96)
	mat.set_shader_parameter("crowd_lineup", codes)
	var mmi := _multimesh("Spectators", person, xfs, cds, people)
	mmi.material_override = mat
	# The cards, always cards, whatever the distance.
	for cls in range(CARDS.size()):
		if card_items[cls][0].is_empty():
			continue
		var sh: Array = CARDS[cls]
		var quad := QuadMesh.new()
		quad.size = Vector2(float(sh[0]), float(sh[1]))
		quad.center_offset = Vector3(float(sh[3]), float(sh[4]), 0.0)
		var cm := ShaderMaterial.new()
		cm.shader = load("res://stadium_crowd.gdshader")
		cm.set_shader_parameter("lod_mode", 2)
		cm.set_shader_parameter("lod_fade_begin", -100.0)
		cm.set_shader_parameter("lod_fade_end", -50.0)
		cm.set_shader_parameter("lod_jitter", 0.0)
		cm.set_shader_parameter("card_w", float(sh[0]))
		cm.set_shader_parameter("card_h", float(sh[1]))
		cm.set_shader_parameter("card_below", float(sh[2]))
		cm.set_shader_parameter("card_x", float(sh[3]))
		cm.set_shader_parameter("crowd_lineup", codes)
		quad.material = cm
		_multimesh("Cards_%d" % cls, quad, card_items[cls][0], card_items[cls][1], people)
	# Stools for the seated.
	var stool := BoxMesh.new()
	stool.size = Vector3(1.0, SEAT_H, 1.0)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.45, 0.30, 0.18)
	stool.material = smat
	var sxf: Array = []
	for p in stools:
		sxf.append(Transform3D(Basis(), p))
	_multimesh("Stools", stool, sxf, [], people)
	_build_car()
	if not Engine.is_editor_hint():
		_build_cyclists()
		_build_camera()
		_build_help()


func _multimesh(node_name: String, mesh: Mesh, xfs: Array, cds: Array, parent: Node) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = not cds.is_empty()
	# White instance colours: the Compatibility renderer loses the mesh's vertex colours on a MultiMesh with custom
	# data and no colours (every figure drew as a rest-pose doll).
	mm.use_colors = not cds.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in range(xfs.size()):
		mm.set_instance_transform(i, xfs[i])
		if not cds.is_empty():
			mm.set_instance_custom_data(i, cds[i])
			mm.set_instance_color(i, Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	_add(mmi, parent)
	return mmi


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.52, 0.82)
	sm.sky_horizon_color = Color(0.72, 0.80, 0.88)
	sm.ground_horizon_color = Color(0.72, 0.80, 0.88)
	sm.ground_bottom_color = Color(0.62, 0.68, 0.72)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_add(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	_add(sun)
	# The ground: a metre grid, so sizes read.
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400.0, 2400.0)
	ground.mesh = pm
	ground.position = Vector3(150.0, 0.0, 0.0)
	var gs := Shader.new()
	gs.code = """shader_type spatial;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 f = abs(fract(wp.xz) - 0.5);
	vec2 w = fwidth(wp.xz);
	float line = 1.0 - smoothstep(0.0, 1.5, min((0.5 - f.x) / w.x, (0.5 - f.y) / w.y));
	vec2 f5 = abs(fract(wp.xz / 5.0) - 0.5);
	float line5 = 1.0 - smoothstep(0.0, 1.5, min((0.5 - f5.x) / (w.x / 5.0), (0.5 - f5.y) / (w.y / 5.0)));
	ALBEDO = mix(mix(vec3(0.50, 0.53, 0.50), vec3(0.40, 0.43, 0.41), line * 0.7), vec3(0.32, 0.35, 0.33), line5 * 0.8);
	ROUGHNESS = 0.95;
}
"""
	var gm := ShaderMaterial.new()
	gm.shader = gs
	ground.material_override = gm
	_add(ground)


## The car that drives up and down in front of the line (out along z 9m, back along 15m), so the spectators near it
## turn to watch it.
func _build_car() -> void:
	var path := "res://generated/cars/%s.tscn" % car_name
	if not ResourceLoader.exists(path):
		return
	var src: Node3D = (load(path) as PackedScene).instantiate()
	_car = Node3D.new()
	_car.name = "Car"
	_car.set_script(load("res://DisplayCar.gd"))
	_car.set("paint", preload("res://CarPaint.gd").factory(car_name))
	var model := src.get_node("Model") as Node3D
	var m2 := Node3D.new()
	m2.name = "Model"
	m2.transform = model.transform
	_car_wheels.clear()
	for c in model.get_children():
		if c is MeshInstance3D:
			var mi := MeshInstance3D.new()
			mi.name = c.name
			mi.mesh = (c as MeshInstance3D).mesh
			mi.transform = (c as MeshInstance3D).transform
			mi.set_meta(&"car_shader", true)
			m2.add_child(mi)
			if String(c.name).begins_with("Wheel"):
				_car_wheels.append([mi, mi.transform])
				_car_radius = (c as MeshInstance3D).mesh.get_aabb().size.y * 0.5
	src.free()
	_car.add_child(m2)
	_add(_car)
	var x0 := -14.0
	var x1 := _line_end + 14.0
	_car_loop = [[Vector3(x0, 0, 9.0), Vector3(x1, 0, 9.0)], [Vector3(x1, 0, 12.0), 3.0, -1.0], [Vector3(x1, 0, 15.0), Vector3(x0, 0, 15.0)],
		[Vector3(x0, 0, 12.0), 3.0, 1.0]]
	_car_len = 2.0 * (x1 - x0) + 2.0 * PI * 3.0
	_place_car(0.0)


## Where the car is `s` metres round its loop, and which way it heads.
func _car_at(s: float) -> Array:
	var straight: float = (_car_loop[0][1] as Vector3).x - (_car_loop[0][0] as Vector3).x
	var arc := PI * 3.0
	s = fposmod(s, _car_len)
	if s < straight:
		return [(_car_loop[0][0] as Vector3) + Vector3(s, 0, 0), Vector3(1, 0, 0)]
	s -= straight
	if s < arc:
		var a := s / 3.0
		var c: Vector3 = _car_loop[1][0]
		return [c + Vector3(sin(a), 0, -cos(a)) * 3.0, Vector3(cos(a), 0, sin(a))]
	s -= arc
	if s < straight:
		return [(_car_loop[2][0] as Vector3) - Vector3(s, 0, 0), Vector3(-1, 0, 0)]
	s -= straight
	var a2 := s / 3.0
	var c2: Vector3 = _car_loop[3][0]
	return [c2 + Vector3(-sin(a2), 0, cos(a2)) * 3.0, Vector3(-cos(a2), 0, -sin(a2))]


func _place_car(s: float) -> void:
	if _car == null:
		return
	var at: Array = _car_at(s)
	var fwd: Vector3 = at[1]
	# The car scenes' Model undoes PlayerCart's x2 and half turn (as the Lakeside's show cars).
	_car.transform = Transform3D(Basis.looking_at(fwd, Vector3.UP).rotated(Vector3.UP, PI).scaled(Vector3.ONE * 2.0), at[0])
	var roll := -s / maxf(_car_radius, 0.05)
	for w in _car_wheels:
		var mi: MeshInstance3D = w[0]
		var rest: Transform3D = w[1]
		mi.transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, roll), rest.origin)
	var p: Vector3 = at[0]
	RenderingServer.global_shader_parameter_set("xray_car_a", Vector4(p.x, p.y + 0.6, p.z, 1.0))


func _build_cyclists() -> void:
	var meshes: Array[Mesh] = []
	var thighs: Array[Mesh] = []
	var shins: Array[Mesh] = []
	for i in range(6):
		var b := "res://generated/lakeside_cyclist_%d.res" % i
		if not ResourceLoader.exists(b):
			return
		meshes.append(load(b))
		thighs.append(load("res://generated/lakeside_cyclist_thigh_%d.res" % i))
		shins.append(load("res://generated/lakeside_cyclist_shin_%d.res" % i))
	var route := PackedVector3Array()
	var cx := _line_end * 0.5
	var rx := _line_end * 0.5 + 16.0
	var rz := 9.0
	var steps := int(TAU * rx / 1.0)
	for k in range(steps):
		var a := TAU * float(k) / float(steps)
		route.append(Vector3(cx + cos(a) * rx, 0.035, -18.0 + sin(a) * rz))
	var cyc := Node3D.new()
	cyc.name = "Cyclists"
	cyc.set_script(load("res://Cyclists.gd"))
	var routes: Array[PackedVector3Array] = [route]
	var riders: Array[Vector4] = []
	for i in range(6):
		riders.append(Vector4(0, float(i) * 23.0 + (40.0 if i >= 3 else 0.0), 6.0 * (1.0 if i < 4 else -1.0), 0.6))
	cyc.set("routes", routes)
	cyc.set("riders", riders)
	cyc.set("body_meshes", meshes)
	cyc.set("thigh_meshes", thighs)
	cyc.set("shin_meshes", shins)
	cyc.set("wheel_mesh", load("res://generated/lakeside_bike_wheel.res"))
	cyc.set("crank_mesh", load("res://generated/lakeside_bike_crank.res"))
	_add(cyc)


func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.far = 900.0
	_add(_cam)
	_cam.make_current()
	_jump_to(0)


func _jump_to(i: int) -> void:
	if _cam == null or i >= _sections.size():
		return
	var x: float = _sections[i][1]
	_yaw = deg_to_rad(-22.0)
	_pitch = deg_to_rad(-10.0)
	_cam.global_position = Vector3(x + 2.0, 4.2, 11.0)
	_cam.rotation = Vector3(_pitch, _yaw, 0.0)


func _build_help() -> void:
	var layer := CanvasLayer.new()
	_add(layer)
	var lb := Label.new()
	lb.text = "WASD/arrows + Q/E: fly   right mouse: look   Shift: fast   wheel: speed   1-%d: sections   C: car   L: labels   Esc: quit" % _sections.size()
	lb.position = Vector2(14, 10)
	lb.add_theme_font_size_override("font_size", 18)
	lb.add_theme_color_override("font_outline_color", Color.BLACK)
	lb.add_theme_constant_override("outline_size", 6)
	layer.add_child(lb)


# ---------------------------------------------------------------------------------------------
#  Running
# ---------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _car and car_drives:
		_place_car(Time.get_ticks_msec() * 0.001 * car_speed)
	if _cam == null:
		return
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if Input.is_key_pressed(KEY_E):
		move.y += 1.0
	if Input.is_key_pressed(KEY_Q):
		move.y -= 1.0
	var sp := _speed * (4.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	_cam.global_position += _cam.global_transform.basis * move * sp * delta
	_cam.global_position.y = maxf(_cam.global_position.y, 0.4)


func _unhandled_input(event: InputEvent) -> void:
	if _cam == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_look = mb.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _look else Input.MOUSE_MODE_VISIBLE
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_speed = minf(_speed * 1.25, 120.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_speed = maxf(_speed / 1.25, 1.0)
	elif event is InputEventMouseMotion and _look:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.004
		_pitch = clampf(_pitch - mm.relative.y * 0.004, -1.5, 1.5)
		_cam.rotation = Vector3(_pitch, _yaw, 0.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_9:
			_jump_to(int(k - KEY_1))
		elif k == KEY_C:
			car_drives = not car_drives
			if not car_drives:
				RenderingServer.global_shader_parameter_set("xray_car_a", Vector4.ZERO)
		elif k == KEY_L:
			for lb in _labels:
				lb.visible = not lb.visible
		elif k == KEY_ESCAPE:
			get_tree().quit()
