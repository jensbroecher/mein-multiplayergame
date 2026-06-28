extends Area3D

@export var gate_color: Color = Color.YELLOW:
	set(value):
		gate_color = value
		if is_inside_tree():
			_update_visuals()

@export var is_finish_line: bool = false:
	set(value):
		is_finish_line = value
		if is_inside_tree():
			_update_visuals()

@onready var top_bar = find_child("TopBar", true, false)

func _ready():
	if name.contains("FinishLine"):
		is_finish_line = true
	_update_visuals()

func _update_visuals():
	if top_bar:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = gate_color
		# Make it glow a bit if it's the finish line (green)
		if gate_color.g > 0.8 and gate_color.r < 0.2:
			mat.emission_enabled = true
			mat.emission = gate_color
			mat.emission_energy_multiplier = 0.5
		top_bar.material_override = mat
	
	var decal = get_node_or_null("StartFinishDecal")
	if decal:
		decal.visible = is_finish_line
