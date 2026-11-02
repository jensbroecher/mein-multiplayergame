extends SceneTree

const PropKit = preload("res://PropKit.gd")
const FreightKit = preload("res://FreightKit.gd")

func _init() -> void:
	var pk = FreightKit.new_kit()
	var kit = {}
	FreightKit.pole(pk, kit)
	var mesh = pk.commit(kit)
	
	var dc_script = load("res://DressingColliders.gd")
	var dc = Node.new()
	dc.set_script(dc_script)
	
	var info = dc._mesh_shape(mesh)
	print("DressingColliders _mesh_shape for pole: ", info)
	quit()

