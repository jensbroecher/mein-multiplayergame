extends Node3D

## Shared 3/4 broadcast angle — not top-down. Used by post-race spectate too.
const VIEW_OFFSET := Vector3(-42.0, 28.0, 48.0)
const VIEW_FOV := 52.0
const CYCLE_TIME := 10.0

const ZOOM_MIN: float = 0.45
const ZOOM_MAX: float = 2.2
const ZOOM_STEP: float = 0.12

var race_ui = null
var focus_cart: Node3D = null
var zoom_factor: float = 1.0

var _cam: Camera3D
var _index: int = 0
var _timer: float = CYCLE_TIME
var _look: Vector3 = Vector3.ZERO
var _watch_label: Label
var _hint_label: Label


func _ready() -> void:
	_cam = Camera3D.new()
	_cam.name = "Camera3D"
	_cam.current = true
	_cam.fov = VIEW_FOV
	add_child(_cam)

	var listener := AudioListener3D.new()
	listener.current = true
	_cam.add_child(listener)

	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)

	_watch_label = Label.new()
	_watch_label.position = Vector2(28, 18)
	_watch_label.add_theme_font_size_override("font_size", 26)
	_watch_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_watch_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_watch_label.add_theme_constant_override("shadow_offset_y", 2)
	_watch_label.text = "SPECTATING"
	layer.add_child(_watch_label)

	_hint_label = Label.new()
	_hint_label.position = Vector2(28, 50)
	_hint_label.add_theme_font_size_override("font_size", 15)
	_hint_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.9, 0.85))
	_hint_label.text = "[ / ] or 1–6 to switch racer | +/- or Mouse Wheel to zoom"
	layer.add_child(_hint_label)

	call_deferred("_pick_initial")


func _pick_initial() -> void:
	var list := _watchable_carts()
	if list.is_empty():
		return
	_index = 0
	focus_cart = list[0]
	global_position = focus_cart.global_position + VIEW_OFFSET
	_look = focus_cart.global_position + Vector3(0, 0.8, 0)
	look_at(_look, Vector3.UP)
	_refresh_label()


func _watchable_carts() -> Array:
	var active: Array = []
	var all_carts: Array = []
	if not is_inside_tree():
		return active
	for c in get_tree().get_nodes_in_group("player_carts"):
		if not is_instance_valid(c) or not (c is Node3D):
			continue
		all_carts.append(c)
		if not c.get("is_finished_race"):
			active.append(c)
	if active.is_empty():
		return all_carts
	return active


func cycle(dir: int) -> void:
	var list := _watchable_carts()
	if list.is_empty():
		return
	if focus_cart != null and is_instance_valid(focus_cart):
		var cur := list.find(focus_cart)
		if cur >= 0:
			_index = cur
	_index = posmod(_index + dir, list.size())
	focus_cart = list[_index]
	_timer = CYCLE_TIME
	_refresh_label()


func select_slot(slot: int) -> void:
	var all_carts: Array = []
	for c in get_tree().get_nodes_in_group("player_carts"):
		if is_instance_valid(c) and c is Node3D:
			all_carts.append(c)
	if slot < 0 or slot >= all_carts.size():
		return
	focus_cart = all_carts[slot]
	_index = slot
	_timer = CYCLE_TIME
	_refresh_label()


func _refresh_label() -> void:
	if _watch_label == null or focus_cart == null or not is_instance_valid(focus_cart):
		return
	var racer_name := str(focus_cart.get("player_name"))
	if racer_name.is_empty():
		racer_name = focus_cart.name
	_watch_label.text = "SPECTATING  %s" % racer_name
	if race_ui and race_ui.has_method("show_message"):
		race_ui.show_message(racer_name, 1.4)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_factor = clampf(zoom_factor - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_factor = clampf(zoom_factor + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_left"):
		cycle(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		cycle(1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
				zoom_factor = clampf(zoom_factor - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
				get_viewport().set_input_as_handled()
				return
			KEY_MINUS, KEY_UNDERSCORE, KEY_KP_SUBTRACT:
				zoom_factor = clampf(zoom_factor + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
				get_viewport().set_input_as_handled()
				return
			KEY_BRACKETLEFT, KEY_COMMA, KEY_Q:
				cycle(-1)
				get_viewport().set_input_as_handled()
			KEY_BRACKETRIGHT, KEY_PERIOD, KEY_E:
				cycle(1)
				get_viewport().set_input_as_handled()
			KEY_1, KEY_KP_1:
				select_slot(0)
				get_viewport().set_input_as_handled()
			KEY_2, KEY_KP_2:
				select_slot(1)
				get_viewport().set_input_as_handled()
			KEY_3, KEY_KP_3:
				select_slot(2)
				get_viewport().set_input_as_handled()
			KEY_4, KEY_KP_4:
				select_slot(3)
				get_viewport().set_input_as_handled()
			KEY_5, KEY_KP_5:
				select_slot(4)
				get_viewport().set_input_as_handled()
			KEY_6, KEY_KP_6:
				select_slot(5)
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_timer -= delta
	if focus_cart == null or not is_instance_valid(focus_cart) or _timer <= 0.0:
		cycle(1)

	if focus_cart == null or not is_instance_valid(focus_cart):
		return

	var focus_pos: Vector3 = focus_cart.global_position
	var desired: Vector3 = focus_pos + VIEW_OFFSET * zoom_factor
	desired = _raise_above_terrain(desired)
	global_position = global_position.lerp(desired, 2.4 * delta)
	global_position = _raise_above_terrain(global_position)

	var look_fwd := Vector3.FORWARD
	var visuals: Node = focus_cart.get_node_or_null("Visuals")
	if visuals is Node3D:
		look_fwd = -(visuals as Node3D).global_transform.basis.z
		look_fwd.y = 0.0
		if look_fwd.length_squared() > 0.001:
			look_fwd = look_fwd.normalized()
		else:
			look_fwd = Vector3.FORWARD

	var target_look: Vector3 = focus_pos + look_fwd * 10.0 + Vector3(0, 0.8, 0)
	if _look == Vector3.ZERO:
		_look = target_look
	else:
		_look = _look.lerp(target_look, 3.5 * delta)
	if global_position.distance_squared_to(_look) > 0.05:
		look_at(_look, Vector3.UP)

	if race_ui and focus_cart is RigidBody3D:
		var spd: float = (focus_cart as RigidBody3D).linear_velocity.length() * 1.8
		if race_ui.has_method("update_speed"):
			race_ui.update_speed(spd)


func _raise_above_terrain(pos: Vector3) -> Vector3:
	if not is_inside_tree():
		return pos
	var space := get_world_3d().direct_space_state
	if space == null:
		return pos
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 40, 0), pos + Vector3(0, -25, 0))
	var result := space.intersect_ray(query)
	if result and result.has("position"):
		var min_y: float = float(result.position.y) + 2.0
		if pos.y < min_y:
			pos.y = min_y
	return pos
