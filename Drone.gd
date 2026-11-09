extends Node3D
## A camera drone, built in code at game scale (about 1.3m across the props, to suit the race-size carts),
## nose toward -z: a white body with a band and stripe in `livery`, four carbon arms with dihedral, motors
## with bells in the livery colour, two-blade props that spin (each a node of its own, with a faint disc
## for the blur), landing skids, a two-axis gimbal with its camera under the nose, a GPS puck, two
## antennas, navigation lights (white forward, red aft) and a rear strobe.
##
## Made for the Inspect tile (MenuTileStage.gd), meant for the races too (a broadcast drone over the
## course). Every motion is `animate(t)`, a function of the clock: with `auto_animate` it runs itself on
## the game's time, otherwise the owner calls it.

const MenuPropKit = preload("res://MenuPropKit.gd")
const PropKit = preload("res://PropKit.gd")

const ARM_TIP := Vector2(0.5, 0.44)     # a motor's x and z from the middle
const MOTOR_Y := 0.115
const PROP_R := 0.27
const PROP_SPIN := 31.0                 # rad/s on screen (a real prop's would strobe)

@export var livery := Color(0.15, 0.75, 0.92)
@export var auto_animate := true

var _props: Array[Node3D] = []
var _gimbal: Node3D
var _strobe: Node3D
var _clock := 0.0


func _ready() -> void:
	_build()
	animate(0.0)


func _process(delta: float) -> void:
	if auto_animate:
		_clock += delta
		animate(_clock)


func animate(t: float) -> void:
	for i in _props.size():
		_props[i].rotation.y = t * PROP_SPIN * (1.0 if i % 3 == 0 else -1.0)
	if _gimbal:
		_gimbal.rotation = Vector3(0.18 + 0.06 * sin(t * 0.5), 0.15 * sin(t * 0.33), 0.0)
	if _strobe:
		var f := fmod(t, 1.3)
		_strobe.visible = f < 0.07 or (f > 0.16 and f < 0.23)


func _build() -> void:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material: return MenuPropKit.material(k)
	var kit := {}
	var white := Color(0.93, 0.94, 0.95)
	var carbon := Color(0.07, 0.072, 0.08)
	var dark := Color(0.12, 0.125, 0.14)

	# The body: a side profile (z, y) extruded across x, rounded by its bevel; nose forward (-z).
	var side_frame := Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3.ZERO)
	pk.set_frame(side_frame)
	var body := PackedVector2Array([Vector2(-0.3, 0.05), Vector2(-0.18, 0.02), Vector2(0.2, 0.02), Vector2(0.32, 0.06),
		Vector2(0.3, 0.13), Vector2(0.16, 0.175), Vector2(-0.1, 0.18), Vector2(-0.26, 0.14), Vector2(-0.33, 0.09)])
	pk.extrude(kit, "gloss", body, -0.15, 0.15, 0.045, white)
	# The livery's band round the waist and a stripe down the top.
	var band := PackedVector2Array([Vector2(-0.335, 0.075), Vector2(0.315, 0.075), Vector2(0.318, 0.1), Vector2(-0.335, 0.1)])
	pk.extrude(kit, "gloss", band, -0.153, 0.153, 0.0, livery)
	pk.reset_frame()
	pk.box(kit, "gloss", Transform3D(Basis(), Vector3(0, 0.181, -0.02)), Vector3(0.07, 0.004, 0.36), livery)
	# A dark sensor window at the nose and vents along the sides.
	pk.box(kit, "glass", Transform3D(Basis.from_euler(Vector3(0.5, 0, 0)), Vector3(0, 0.11, -0.325)), Vector3(0.16, 0.05, 0.01), Color(0.03, 0.035, 0.05))
	for s in [-1.0, 1.0]:
		for k in 4:
			pk.box(kit, "matte", Transform3D(Basis(), Vector3(s * 0.151, 0.135, -0.06 + 0.05 * float(k))), Vector3(0.004, 0.012, 0.03), dark)
	# The GPS puck and the antennas.
	pk.lathe(kit, "matte", Vector3(0, 0.18, 0.1), [Vector2(0.05, 0.0), Vector2(0.05, 0.015), Vector2(0.04, 0.025), Vector2(0.0, 0.028)], 20, dark)
	for s in [-1.0, 1.0]:
		pk.tube(kit, "rubber", Vector3(s * 0.08, 0.12, 0.3), Vector3(s * 0.12, 0.27, 0.37), 0.01, 0.007, 8, carbon)

	# The arms, motors and lights.
	var leds := {}
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var root := Vector3(sx * 0.13, 0.085, sz * 0.17)
			var tip := Vector3(sx * ARM_TIP.x, MOTOR_Y - 0.03, sz * ARM_TIP.y)
			pk.beam(kit, "matte", root, tip, 0.065, 0.034, carbon)
			pk.beam(kit, "gloss", root.lerp(tip, 0.55) + Vector3(0, 0.018, 0), tip + Vector3(0, 0.018, 0), 0.02, 0.003, livery)
			var m := Vector3(tip.x, MOTOR_Y - 0.05, tip.z)
			pk.lathe(kit, "matte", m, [Vector2(0.05, 0.0), Vector2(0.052, 0.035), Vector2(0.046, 0.04)], 20, dark)
			pk.lathe(kit, "metal", m, [Vector2(0.046, 0.04), Vector2(0.048, 0.075), Vector2(0.03, 0.085), Vector2(0.012, 0.09), Vector2(0.0, 0.092)], 20, livery.darkened(0.1))
			# A navigation light under the arm's end.
			var led_col := Color(1.0, 0.97, 0.9) if sz < 0.0 else Color(1.0, 0.1, 0.06)
			_led(pk, leds, Vector3(tip.x, MOTOR_Y - 0.06, tip.z), led_col)
	# The skids: two legs each side down to a rail with rubber feet.
	for s in [-1.0, 1.0]:
		for z in [-0.14, 0.14]:
			pk.tube(kit, "matte", Vector3(s * 0.11, 0.03, z), Vector3(s * 0.2, -0.2, z * 1.2), 0.014, 0.012, 8, dark)
		pk.tube(kit, "matte", Vector3(s * 0.2, -0.205, -0.24), Vector3(s * 0.2, -0.205, 0.24), 0.016, 0.016, 10, dark)
		for z in [-0.24, 0.24]:
			pk.lathe(kit, "rubber", Vector3(s * 0.2, -0.205, z), [Vector2(0.018, -0.008), Vector2(0.018, 0.008)], 10, carbon, false,
				Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)))
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = pk.commit(kit)
	add_child(shell)
	var led_mesh := MeshInstance3D.new()
	led_mesh.name = "NavLights"
	led_mesh.mesh = pk.commit(leds)
	led_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(led_mesh)

	# The strobe on the tail.
	var skit := {}
	_led(pk, skit, Vector3(0, 0.16, 0.33), Color(1.0, 0.95, 0.95), 0.022)
	_strobe = MeshInstance3D.new()
	_strobe.name = "Strobe"
	(_strobe as MeshInstance3D).mesh = pk.commit(skit)
	add_child(_strobe)

	# The props: each a node at its motor's top (two blades, dark with livery tips), and a faint disc.
	var disc_mat := StandardMaterial3D.new()
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.albedo_color = Color(0.75, 0.78, 0.82, 0.05)
	disc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	disc_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var disc := CylinderMesh.new()
	disc.top_radius = PROP_R
	disc.bottom_radius = PROP_R
	disc.height = 0.002
	disc.radial_segments = 32
	disc.rings = 1
	var blade_mesh := _prop_mesh()
	var i := 0
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			var hub := Vector3(sx * ARM_TIP.x, MOTOR_Y + 0.05, sz * ARM_TIP.y)
			var prop := MeshInstance3D.new()
			prop.name = "Prop%d" % i
			prop.mesh = blade_mesh
			prop.position = hub
			add_child(prop)
			_props.append(prop)
			var d := MeshInstance3D.new()
			d.mesh = disc
			d.material_override = disc_mat
			d.position = hub + Vector3(0, 0.004, 0)
			d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(d)
			i += 1

	# The gimbal: a yoke hanging under the nose, the camera in it with its lens forward.
	_gimbal = Node3D.new()
	_gimbal.name = "Gimbal"
	_gimbal.position = Vector3(0, 0.0, -0.2)
	add_child(_gimbal)
	var gpk := PropKit.new()
	gpk.material_for = func(k: String) -> Material: return MenuPropKit.material(k)
	var gkit := {}
	gpk.lathe(gkit, "matte", Vector3(0, -0.03, 0), [Vector2(0.035, 0.0), Vector2(0.035, 0.03)], 16, dark)
	gpk.beam(gkit, "matte", Vector3(-0.075, -0.035, 0), Vector3(0.075, -0.035, 0), 0.025, 0.012, dark)
	for s in [-1.0, 1.0]:
		gpk.beam(gkit, "matte", Vector3(s * 0.075, -0.035, 0), Vector3(s * 0.075, -0.11, 0), 0.025, 0.012, dark)
	gpk.box(gkit, "gloss", Transform3D(Basis(), Vector3(0, -0.11, 0.0)), Vector3(0.12, 0.085, 0.11), Color(0.18, 0.185, 0.2))
	var fwd := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))   # the lathe's up along -z
	gpk.lathe(gkit, "metal", Vector3(0, -0.11, -0.055), [Vector2(0.04, 0.0), Vector2(0.04, 0.025), Vector2(0.034, 0.03)], 22, Color(0.2, 0.21, 0.23), false, fwd)
	gpk.lathe(gkit, "glass", Vector3(0, -0.11, -0.085), [Vector2(0.032, 0.0), Vector2(0.022, 0.006), Vector2(0.0, 0.008)], 22, Color(0.05, 0.08, 0.14), false, fwd)
	gpk.lathe(gkit, "gloss", Vector3(0, -0.11, -0.082), [Vector2(0.041, 0.0), Vector2(0.041, 0.004)], 22, livery, false, fwd)
	var cam := MeshInstance3D.new()
	cam.mesh = gpk.commit(gkit)
	_gimbal.add_child(cam)


## A small glowing lens (a flattened dome) into the "led" kit.
func _led(pk: PropKit, kit: Dictionary, c: Vector3, col: Color, r := 0.016) -> void:
	pk.lathe(kit, "led", c, [Vector2(r, 0.0), Vector2(r * 0.8, -r * 0.6), Vector2(0.0, -r * 0.8)], 12, col)
	pk.lathe(kit, "led", c, [Vector2(0.0, r * 0.3), Vector2(r, 0.0)], 12, col)


## Two blades, each tapering and twisted, dark with a livery-coloured tip, round a hub; spinning about y.
func _prop_mesh() -> ArrayMesh:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material: return MenuPropKit.material(k)
	var kit := {}
	var dark := Color(0.08, 0.085, 0.095)
	pk.lathe(kit, "metal", Vector3.ZERO, [Vector2(0.022, -0.012), Vector2(0.022, 0.006), Vector2(0.012, 0.016), Vector2(0.0, 0.018)], 14, Color(0.65, 0.67, 0.7))
	for b in 2:
		var dir := 1.0 if b == 0 else -1.0
		var steps := 8
		for k in steps:
			var u0 := float(k) / steps
			var u1 := float(k + 1) / steps
			var r0 := lerpf(0.02, PROP_R, u0)
			var r1 := lerpf(0.02, PROP_R, u1)
			var w0 := lerpf(0.045, 0.022, u0) * (0.6 + 0.4 * sin(PI * minf(u0 * 1.6, 1.0)))
			var w1 := lerpf(0.045, 0.022, u1) * (0.6 + 0.4 * sin(PI * minf(u1 * 1.6, 1.0)))
			var tw0 := lerpf(0.4, 0.12, u0)
			var tw1 := lerpf(0.4, 0.12, u1)
			var col := dark if u0 < 0.82 else livery
			var a0 := Vector3(dir * r0, sin(tw0) * w0 * 0.5, -dir * cos(tw0) * w0 * 0.5)
			var b0 := Vector3(dir * r0, -sin(tw0) * w0 * 0.5, dir * cos(tw0) * w0 * 0.5)
			var a1 := Vector3(dir * r1, sin(tw1) * w1 * 0.5, -dir * cos(tw1) * w1 * 0.5)
			var b1 := Vector3(dir * r1, -sin(tw1) * w1 * 0.5, dir * cos(tw1) * w1 * 0.5)
			pk.panel(kit, "gloss", [a0, a1, b1, b0], Vector3.UP, col, col)
	return pk.commit(kit)
