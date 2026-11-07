# CarAntenna.gd
#
# The RC antenna's styles (CarPaint.ANTENNAS): PlayerCart.tscn's Visuals/Antenna holds the mount ball, the rod and the
# round tip; dress() shows it for a paint job's style and adds the flag the first time. PlayerCart dresses its own, the
# car select screen and scratch/car_preview.gd a copy of it. Free of the game's autoloads, so tools can use it.
extends RefCounted

## Dresses an antenna (PlayerCart.tscn's Visuals/Antenna, or a copy of it: the car select screen's) for a paint job's
## antenna style (CarPaint.ANTENNAS): hidden at 0, the round glowing tip at 1, a pennant trailing back from the rod's
## top at 2, either in the accent colour. The flag is made the first time (a child "Flag", sharing one mesh).
static func dress(ant: Node3D, style: int, accent: Color) -> void:
	if ant == null:
		return
	ant.visible = style > 0
	var flag := ant.get_node_or_null("Flag") as MeshInstance3D
	if flag == null:
		flag = MeshInstance3D.new()
		flag.name = "Flag"
		flag.mesh = flag_mesh()
		ant.add_child(flag)
	var tip := ant.get_node_or_null("Tip") as MeshInstance3D
	if tip:
		tip.visible = style == 1
		var src := tip.mesh.surface_get_material(0) as StandardMaterial3D
		if src:
			var mat := src.duplicate() as StandardMaterial3D
			mat.albedo_color = accent
			mat.emission = accent
			tip.material_override = mat
	flag.visible = style == 2
	var fmat := (flag.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	fmat.albedo_color = accent
	fmat.emission = accent
	flag.material_override = fmat


## The antenna's pennant: from the rod's top (y ROD_TOP) down FLAG_H at the hoist, tapering to a point
## FLAG_L back (+z, behind the car), with a gentle wave across it; drawn from both sides, glowing a little in its
## colour like the tip. One mesh for every cart.
const ROD_TOP := 0.8
const FLAG_L := 0.16
const FLAG_H := 0.075
static var _flag: ArrayMesh


static func flag_mesh() -> ArrayMesh:
	if _flag != null:
		return _flag
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	var top: Array = []
	var bot: Array = []
	for i in n + 1:
		var t: float = float(i) / n
		var x: float = 0.014 * sin(t * PI * 1.6) * t
		var yc: float = ROD_TOP - FLAG_H * 0.5 - 0.004 * t
		var h: float = FLAG_H * 0.5 * (1.0 - t)
		top.append(Vector3(x, yc + h + 0.0005, t * FLAG_L + 0.004))
		bot.append(Vector3(x, yc - h - 0.0005, t * FLAG_L + 0.004))
	for i in n:
		st.add_vertex(top[i])
		st.add_vertex(bot[i])
		st.add_vertex(top[i + 1])
		st.add_vertex(top[i + 1])
		st.add_vertex(bot[i])
		st.add_vertex(bot[i + 1])
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.2, 0)
	mat.roughness = 0.55
	mat.emission_enabled = true
	mat.emission = Color(1, 0.2, 0)
	mat.emission_energy_multiplier = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_flag = st.commit()
	return _flag
