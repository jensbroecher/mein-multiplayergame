extends RigidBody3D

@onready var area = $Area3D
@onready var visuals = $Visuals
@export var owner_id: int

var pulse_time = 0.0

func _ready():
	add_to_group("bombs")
	area.body_entered.connect(_on_body_entered)
	
	# Self destruct after 60s
	get_tree().create_timer(60.0).timeout.connect(func(): if is_instance_valid(self): queue_free())
	
	# Lock physics after 2 seconds (allows it to land and settle)
	get_tree().create_timer(2.0).timeout.connect(func(): freeze = true)

func _process(delta):
	# Pulse visual scale
	pulse_time += delta * 5.0
	var s = 1.0 + sin(pulse_time) * 0.1
	visuals.scale = Vector3(s, s, s)

func _on_body_entered(body):
	if not multiplayer.is_server(): return
	
	if body.is_in_group("player_carts"):
		# Safety: Don't trigger on yourself if you just dropped it 
		# But if you drive into it later, maybe it should?
		# Mario Kart allows hitting your own bomb. But usually not immediately.
		if body.name.to_int() != owner_id:
			if body.has_method("on_hit"):
				body.on_hit()
				_explode()

func _explode():
	# Notify clients to play sound/particles (omitted for brevity but recommended)
	queue_free()
