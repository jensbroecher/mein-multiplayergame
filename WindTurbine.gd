@tool
extends Node3D

## Controller for modern animated wind turbine.
## Rotates the 3-blade rotor assembly and pulses the red aviation obstruction beacon.
## The rotor turns clockwise seen from upwind (its front, +Z), as real turbines do and as the blades'
## airfoils are built for (WindTurbineBuilder.gd): rotation about +Z is negative.

@export var spin_speed: float = 40.0 ## Degrees per second
@export var initial_angle: float = 0.0 ## Initial rotor angle in degrees
@export var beacon_flash_period: float = 1.35 ## Beacon flash cycle in seconds

var _rotor: Node3D = null
var _beacon: MeshInstance3D = null
var _beacon_mat: StandardMaterial3D = null
var _angle: float = 0.0


func _ready() -> void:
	_angle = initial_angle
	_rotor = get_node_or_null("RotorPivot")
	if _rotor:
		_rotor.rotation_degrees.z = -_angle

	_beacon = get_node_or_null("Beacon") as MeshInstance3D
	if _beacon and _beacon.material_override is StandardMaterial3D:
		_beacon_mat = (_beacon.material_override as StandardMaterial3D).duplicate()
		_beacon.material_override = _beacon_mat


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _rotor == null:
		_rotor = get_node_or_null("RotorPivot")
	if _rotor:
		_angle += spin_speed * delta
		if _angle >= 360.0:
			_angle -= 360.0
		elif _angle < 0.0:
			_angle += 360.0
		_rotor.rotation_degrees.z = -_angle

	# FAA/ICAO double-pulse aviation obstruction warning beacon
	if _beacon_mat:
		var t: float = fmod(float(Time.get_ticks_msec()) / 1000.0, beacon_flash_period)
		var flash := 0.2 # Dim baseline glow
		# Pulse 1: 0.00s to 0.14s; Pulse 2: 0.28s to 0.42s
		if (t >= 0.0 and t < 0.14) or (t >= 0.28 and t < 0.42):
			flash = 4.0
		_beacon_mat.emission_energy_multiplier = flash
