extends Node3D

# Prototype for Freight Line's flatcar shortcut: can a PlayerCart ride, and drive along, a moving
# AnimatableBody3D deck? A 140m deck moves along -Z at `deck_speed`; the cart is dropped on its tail.
# Phase 1 the cart idles (does it ride along or slide off the back?), phase 2 it drives at full
# throttle (does it accelerate relative to the deck as on a road?). Prints speeds relative to the deck.
#   Godot --headless --path . res://scratch/train_ride_test.tscn [-- deck_speed=15 sync=1]

const CART_SCENE := preload("res://PlayerCart.tscn")

var deck_speed := 15.0
var sync_physics := true
var deck: AnimatableBody3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("deck_speed="):
			deck_speed = float(a.substr(11))
		elif a == "sync=0":
			sync_physics = false
	Engine.physics_ticks_per_second = 60
	MusicManager.window_mode = 0
	AudioServer.set_bus_mute(0, true)
	await get_tree().process_frame

	var ground := StaticBody3D.new()
	var gcs := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(60, 1, 2000)
	gcs.shape = gshape
	ground.add_child(gcs)
	ground.position = Vector3(0, -3.5, -500)   # far below the deck, only a safety net
	add_child(ground)

	deck = AnimatableBody3D.new()
	deck.name = "FlatcarDeck"
	deck.sync_to_physics = sync_physics
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 0.4, 140.0)
	cs.shape = box
	deck.add_child(cs)
	deck.position = Vector3(0, -0.2, 0)     # top at y = 0
	add_child(deck)

	var cart: RigidBody3D = CART_SCENE.instantiate()
	cart.name = "1"
	cart.position = Vector3(0, 0.9, 60)    # on the deck's tail (deck spans z -70..70)
	add_child(cart)
	for i in 3:
		await get_tree().physics_frame
	cart.set("is_landing", false)
	cart.set("can_move", true)
	cart.freeze = false
	var t := 0.0
	var dt := 1.0 / 60.0
	var phase := 0
	for i in 60 * 10:
		deck.position.z -= deck_speed * dt
		await get_tree().physics_frame
		t += dt
		if phase == 0 and t > 4.0:
			phase = 1
			Input.action_press("p1_throttle")
		if i % 30 == 0:
			var rel_z: float = cart.global_position.z - deck.global_position.z
			var rel_v: Vector3 = cart.linear_velocity - Vector3(0, 0, -deck_speed)
			print("t=%.1f phase=%d on_deck_y=%.2f rel_z=%.1f rel_vel=(%.2f, %.2f, %.2f) cart_speed=%.1f ground=%s" % [
				t, phase, cart.global_position.y, rel_z, rel_v.x, rel_v.y, rel_v.z, cart.linear_velocity.length(), str(cart.get("is_on_ground"))])
		if cart.global_position.y < -1.0:
			print("FELL OFF at t=%.1f" % t)
			break
	Input.action_release("p1_throttle")
	get_tree().quit()
