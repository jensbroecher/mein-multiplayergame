extends RefCounted
## Lamps that give off light on the night and dusk stages (Marina Nights, Mtaa Nights, Ramlat Hamra, Mina del Viento).
## CampKit's and MatatuKit's "lamp" is a StandardMaterial3D with emission MULTIPLY and no emission texture: the texture's
## default is black, so it emits nothing and a lamp reads as paint. `material()` is lamp_glow.gdshader (the vertex colour
## times `energy`, unshaded); `is_dead(m)` tells the broken kind; `fix_mesh` swaps it out of a mesh's surfaces.
## The day stages keep theirs (lamps lit at noon would look wrong). res://scratch/fix_lamp_glow.gd patches saved levels.

static func material(energy := 2.4) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://lamp_glow.gdshader")
	m.set_shader_parameter("energy", energy)
	return m


static func is_dead(m: Material) -> bool:
	var sm := m as StandardMaterial3D
	return sm != null and sm.emission_enabled and sm.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY and sm.emission_texture == null


## Replaces every dead lamp material on `mesh`'s surfaces with `glow`. Returns how many it replaced.
static func fix_mesh(mesh: Mesh, glow: Material) -> int:
	var n := 0
	if mesh == null:
		return 0
	for i in range(mesh.get_surface_count()):
		if is_dead(mesh.surface_get_material(i)):
			mesh.surface_set_material(i, glow)
			n += 1
	return n
