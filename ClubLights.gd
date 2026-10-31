extends Node3D
## Club Kilele's light show (Mtaa Nights): moving heads sweeping their beams over the dancefloor and the
## sky, lasers fanning from the DJ booth, coloured washes, the LED wall and the dancefloor, all on one
## beat (BPM). The generator (regenerate_mtaa_nights.gd) builds the rig under this node and lists it in
## the exports; nothing is built here.
##
## Everything runs on the wall clock (`Time.get_unix_time_from_system()`), like WildebeestHerd.gd, so LAN
## peers see the same show without syncing it. Moves are slow sweeps and the beat is a swell, never a
## strobe (camera-motion and flicker comfort). The dancefloor lights up under the carts: their positions
## go to its material every frame.

const BPM := 124.0
## The show's colours (pink, blue, violet, amber, cyan).
const PALETTE := [Color(1.0, 0.12, 0.55), Color(0.12, 0.45, 1.0), Color(0.62, 0.18, 1.0), Color(1.0, 0.55, 0.08), Color(0.10, 0.85, 0.95)]

## Pivots of the moving heads: each turns about its own y (pan) and x (tilt); the beam hangs along -y.
@export var heads: Array[Node3D] = []
## The beam meshes, one per head (club_beam.gdshader, instance uniform `tint`).
@export var beams: Array[GeometryInstance3D] = []
## Laser pivots at the DJ booth: each fans about its y.
@export var lasers: Array[Node3D] = []
@export var laser_meshes: Array[GeometryInstance3D] = []
## Coloured washes over the floor (OmniLights).
@export var washes: Array[Light3D] = []
## The dancefloor's and the LED wall's materials (`clock`; the floor's `cart_pos`).
@export var floor_material: ShaderMaterial
@export var screen_material: ShaderMaterial

var _rest: Array = []
var _epoch := 0.0


func _ready() -> void:
	for h in heads:
		_rest.append(h.rotation if h else Vector3.ZERO)
	# A day's worth of seconds keeps the float precise enough for the shaders.
	_epoch = floorf(Time.get_unix_time_from_system() / 86400.0) * 86400.0


func _process(_delta: float) -> void:
	var t: float = Time.get_unix_time_from_system() - _epoch
	var beat_t: float = t * BPM / 60.0
	var bar: float = floorf(beat_t / 4.0)
	var swell: float = 0.6 + 0.4 * exp(-fposmod(beat_t, 1.0) * 3.5)
	var shader_clock: float = fposmod(t, 3600.0)
	if floor_material:
		floor_material.set_shader_parameter("clock", shader_clock)
		var pos := PackedVector3Array()
		for cart in get_tree().get_nodes_in_group("player_carts"):
			if is_instance_valid(cart) and cart is Node3D:
				pos.append((cart as Node3D).global_position)
				if pos.size() >= 8:
					break
		floor_material.set_shader_parameter("cart_count", pos.size())
		if not pos.is_empty():
			pos.resize(8)
			floor_material.set_shader_parameter("cart_pos", pos)
	if screen_material:
		screen_material.set_shader_parameter("clock", shader_clock)
	# Heads: a figure-of-eight sweep each, half of them mirrored, the whole rig changing colour every
	# four bars (alternate heads a step apart in the palette).
	for i in range(heads.size()):
		var h := heads[i]
		if h == null:
			continue
		var side: float = -1.0 if i % 2 else 1.0
		var ph: float = float(i) * 0.7
		var pan: float = side * (0.55 * sin(t * 0.42 + ph))
		var tilt: float = 0.45 * sin(t * 0.84 + ph * 1.3) + 0.15
		var r: Vector3 = _rest[i]
		h.rotation = Vector3(r.x + tilt, r.y + pan, r.z)
		if i < beams.size() and beams[i]:
			var c: Color = PALETTE[int(bar + float(i % 2) * 2.0) % PALETTE.size()]
			beams[i].set_instance_shader_parameter(&"tint", Vector3(c.r, c.g, c.b))
			beams[i].set_instance_shader_parameter(&"strength", swell)
	# Lasers fan to and fro, together, on the off-beat bars only.
	var laser_on: float = 1.0 if int(bar) % 8 >= 4 else 0.0
	for i in range(lasers.size()):
		var l := lasers[i]
		if l == null:
			continue
		var spread: float = (float(i) - float(lasers.size() - 1) * 0.5) * 0.16
		l.rotation.y = spread * (1.0 + 0.6 * sin(t * 0.9)) + 0.25 * sin(t * 0.35)
		l.rotation.x = 0.18 + 0.1 * sin(t * 0.6 + float(i))
		if i < laser_meshes.size() and laser_meshes[i]:
			laser_meshes[i].set_instance_shader_parameter(&"strength", laser_on * swell)
	for i in range(washes.size()):
		var w := washes[i]
		if w == null:
			continue
		var wc: Color = PALETTE[int(bar + float(i)) % PALETTE.size()]
		w.light_color = wc
		w.light_energy = 2.2 * swell
