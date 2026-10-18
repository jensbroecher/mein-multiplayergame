@tool
extends Area3D
## A race gate. The finish line (`is_finish_line`, or a node named FinishLine) is the start/finish
## gantry: a navy arch with silver trim and a slim LED screen hung under the beam. The screen runs a
## ticker (the Grand Prix, the stage, the lap and the standings, fed by Level), shows the start
## lights during the countdown (Level.start_race() calls show_start_lights()) and waves a chequered
## flag once the leader is on the last lap. Every other gate is a checkpoint: a light aluminium
## truss arch with a CHECKPOINT banner hung from it.
##
## The gate builds its meshes, collision and text as internal children when it enters the tree, so
## a level file only stores where a gate stands and regenerating a level never saves them. Gates
## share their meshes and materials. In a running race the gate stands itself on the road (levels put
## its origin anywhere from 3m under the road to just above it) and a checkpoint comes down to fit
## under anything over the road; see _settle_on_ground().

## The checkpoint banner's edge bands and ballast blocks.
@export var gate_color: Color = Color(1.0, 0.42, 0.0):
	set(value):
		gate_color = value
		if is_node_ready():
			_build()

@export var is_finish_line: bool = false:
	set(value):
		is_finish_line = value
		if is_node_ready():
			_build()

# Gantry, in gate space: X across the road, cars come from +Z (the grid's side) and leave toward -Z.
const POST_X := 6.85 # post centre line, where the old gate's posts stood
const POST_W := 1.3
const GANTRY_D := 1.6
const SOFFIT_Y := 7.2 # underside of the beam
const TOP_Y := 8.9
const INNER_R := 1.2 # corner radii inside and outside the arch
const OUTER_R := 2.6
const CHAMFER := 0.06
const TRIM_H := 0.03 # how far the silver trim stands proud of the paint
const FOOT_Y := -1.5 # the posts run this far down, into the ground
const ARC_STEPS := 10
# The screen is a slim panel hung under the middle of the beam, low enough for the front row to see
# it: their chase camera (5.2m back, 2.2m up, 75 degree FOV) sees nothing higher than about 7.7m at
# the gantry.
const POD_HALF_W := 2.75
const POD_Y0 := 5.2
const POD_Z0 := -0.12
const POD_Z1 := 0.14
const SCREEN_SIZE := Vector2(5.26, 1.76)
const LED_PITCH := 0.05
const CHEQUER := 0.42 # squares in the band across the beam
const CHEQUER_COLS := 22
const GREEN_HOLD := 4.0 # seconds the lamps stay green before the screen goes back to the ticker
const GLOW_ENERGY := 1.6 # the light the lit lamps throw onto the grid
# The ticker: one line of text drawn into a strip (a SubViewport, redrawn only when the text
# changes) that start_lights.gdshader scrolls across the middle of the screen, TICKER_SS texels to
# an LED.
const TICKER_SS := 2
const TICKER_ROWS := 18 # LED rows the text band covers
# The strip's width; the text uses as much of it as it needs. Six racers with 14-letter names and a
# long title come to about 3600. Phones' GPUs may not take wider.
const TICKER_TEX_W := 4096
const TICKER_NAME_MAX := 14
const TICKER_FONT_SIZE := 32 # in strip texels: capitals about 11 LEDs tall
const TICKER_SPEED := 28.0 # LEDs a second
const TICKER_SPACE := 20.0 # strip texels round a separator and between racers
const TICKER_GOLD := Color(1.0, 0.74, 0.2)
const TICKER_WHITE := Color(0.94, 0.95, 1.0)
const TICKER_CYAN := Color(0.3, 0.86, 1.0)
const TICKER_GREEN := Color(0.45, 1.0, 0.5)
const TICKER_RED := Color(1.0, 0.24, 0.18)

# Checkpoint truss.
const TRUSS_X := 6.85
const TRUSS_W := 0.4 # chord centre to chord centre
# Carts cresting a rise fly through checkpoints at up to about 5.7m (Pinecrest's checkpoint 5), so the
# banner's bottom edge is 6.2m up, as high as the old gate's beam. Under a sign gantry or a bridge
# the truss comes down to fit, but never below TRUSS_MIN_TOP.
const TRUSS_TOP := 8.0
const TRUSS_MIN_TOP := 4.6
const HEADROOM_GAP := 0.45 # space left under whatever is over the road
const HEADROOM_FROM := 3.0 # see _headroom()
const TRUSS_FOOT := -1.0
const CHORD_R := 0.025
const LACE_R := 0.012
const LACE_PITCH := 0.5
const BLOCK := 0.46 # corner blocks where the towers meet the cross truss
const BANNER_W := 10.6
const BANNER_H := 1.3
const BANNER_BAND := 0.12
const BANNER_GAP := 0.06
const TEXT_W := 7.4
const TEXT_CAP := 0.62

# Both.
const FOOT_WALL := 2.5 # how high the feet's colliders reach (see _add_foot)
const ROAD_SEARCH := 4.0 # how far over the origin _settle_on_ground() looks for the road

const NAVY := Color(0.055, 0.08, 0.13)
const INK := Color(0.06, 0.09, 0.17)
const START_LIGHTS := preload("res://start_lights.gdshader")

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}
static var _font: Font
static var _plain_font: Font

var _build_root: Node3D
var _feet: Array[Node3D] = []
var _truss_top := TRUSS_TOP
var _screen_mat: ShaderMaterial
var _glow: OmniLight3D
var _lights_tween: Tween
var _flag_tween: Tween
var _flag_on := false

# The ticker's text: the title (set_ticker_title) and the standings (update_standings). The strip
# shows `_ticker_shown`; new text waits in `_ticker_next` until the strip wraps round to its start,
# where old and new both begin with the same title, so the swap doesn't show.
var _ticker_vp: SubViewport
var _ticker_canvas: Control
var _ticker_title: Array = [] # [[text, colour], ...]
var _ticker_laps := 0
var _ticker_rows_sig := ""
var _ticker_shown: Array = [] # laid-out tokens: {text, colour, x} or {sep, x}
var _ticker_next: Array = []
var _ticker_len := 0.0 # strip length in LEDs
var _ticker_scroll := 0.0


func _ready() -> void:
	if name.contains("FinishLine"):
		is_finish_line = true
	if _build_root == null:
		_build()
	set_process(is_finish_line and not Engine.is_editor_hint())
	if not Engine.is_editor_hint():
		_settle_on_ground()


func _process(delta: float) -> void:
	if _screen_mat == null or _ticker_len <= 0.0:
		return
	_ticker_scroll += TICKER_SPEED * delta
	if _ticker_scroll >= _ticker_len:
		_ticker_scroll = fmod(_ticker_scroll, _ticker_len)
		if not _ticker_next.is_empty():
			_show_ticker(_ticker_next)
	# Whole LEDs, as a real board steps; a fraction blurs the text across two columns.
	_screen_mat.set_shader_parameter("ticker_scroll", floorf(_ticker_scroll))


## The ticker's title, from Level: the Grand Prix, the stage, which race of the GP it is ("" outside
## one) and the race's laps.
func set_ticker_title(cup: String, stage: String, race: String, laps: int) -> void:
	_ticker_title.clear()
	_ticker_title.append([cup if cup != "" else "RC Vibe GP", TICKER_GOLD])
	if stage != "":
		_ticker_title.append([stage, TICKER_WHITE])
	if race != "":
		_ticker_title.append([race, TICKER_CYAN])
	_ticker_laps = laps
	_ticker_rows_sig = ""
	_queue_ticker(_ticker_tokens([_ticker_group("%d Laps" % laps, TICKER_CYAN)]))


## The standings, from Level (its _push_standings rows: pos, name, finished, lap), as often as every
## frame. The ticker takes the new order in when it next comes round to its start; the screen waves
## the chequered flag once the leader is on the last lap.
func update_standings(rows: Array) -> void:
	if rows.is_empty() or _ticker_title.is_empty():
		return
	var lap := int(rows[0].get("lap", 1))
	_set_flag(lap >= _ticker_laps or bool(rows[0].get("finished", false)))
	var sig := str(lap)
	for r in rows:
		sig += "|%s:%s:%s" % [r.get("pos", 0), r.get("name", ""), r.get("finished", false)]
	if sig == _ticker_rows_sig:
		return
	_ticker_rows_sig = sig
	var order: Array = []
	for r in rows:
		var racer_name := str(r.get("name", "Racer"))
		if racer_name.length() > TICKER_NAME_MAX:
			racer_name = racer_name.substr(0, TICKER_NAME_MAX - 1) + "."
		var racer: Array = [[str(r.get("pos", 0)), TICKER_GOLD],
				[racer_name, TICKER_GREEN if r.get("finished", false) else TICKER_WHITE]]
		order.append(racer)
	_queue_ticker(_ticker_tokens([_ticker_group("Lap %d/%d" % [mini(lap, _ticker_laps), _ticker_laps], TICKER_CYAN), order]))


## A ticker group holding one piece of text.
static func _ticker_group(text: String, colour: Color) -> Array:
	return [[[text, colour]]]


## The title, then each group in `groups`, laid out along the strip. A group is a list of runs spaced
## apart (a racer's place and name is a run), a run a list of [text, colour] pieces, and separators
## split the groups. One closes the line too, so it runs on into the title as it loops.
func _ticker_tokens(groups: Array) -> Array:
	var font := _ticker_font()
	var tokens: Array = []
	var x := 0.0
	var all: Array = []
	for piece in _ticker_title:
		all.append(_ticker_group(piece[0], piece[1]))
	all.append_array(groups)
	for group in all:
		for run_i in group.size():
			if run_i > 0:
				x += TICKER_SPACE
			for piece_i in group[run_i].size():
				var piece: Array = group[run_i][piece_i]
				if piece_i > 0:
					x += TICKER_SPACE * 0.4
				var text: String = str(piece[0]).to_upper()
				tokens.append({"text": text, "colour": piece[1], "x": x})
				x += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TICKER_FONT_SIZE).x
		x += TICKER_SPACE
		tokens.append({"sep": true, "x": x})
		x += TICKER_SPACE
	tokens.append({"end": true, "x": minf(x, TICKER_TEX_W)})
	return tokens


func _queue_ticker(tokens: Array) -> void:
	if _ticker_len <= 0.0:
		_show_ticker(tokens)
	else:
		_ticker_next = tokens


func _show_ticker(tokens: Array) -> void:
	_ticker_shown = tokens
	_ticker_next = []
	_ticker_len = float(tokens[-1]["x"]) / TICKER_SS
	if _ticker_vp:
		_ticker_canvas.queue_redraw()
		_ticker_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _screen_mat:
		_screen_mat.set_shader_parameter("ticker_len", _ticker_len)


func _draw_ticker() -> void:
	var h := float(TICKER_ROWS * TICKER_SS)
	_ticker_canvas.draw_rect(Rect2(0.0, 0.0, TICKER_TEX_W, h), Color.BLACK)
	var font := _ticker_font()
	# Capitals centred in the band: a heavy sans' capitals stand about 0.72 of the font size.
	var baseline := (h + TICKER_FONT_SIZE * 0.72) * 0.5
	for t in _ticker_shown:
		if t.has("text"):
			_ticker_canvas.draw_string(font, Vector2(t["x"], baseline), t["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, TICKER_FONT_SIZE, t["colour"])
		elif t.has("sep"):
			# A diamond, centred on the capitals.
			var c := Vector2(float(t["x"]), h * 0.5)
			var r := TICKER_SS * 2.6
			_ticker_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), TICKER_RED)


## Fades the chequered flag in over the ticker (the last lap) or out again.
func _set_flag(on: bool) -> void:
	if on == _flag_on or _screen_mat == null:
		return
	_flag_on = on
	if _flag_tween:
		_flag_tween.kill()
	_flag_tween = create_tween()
	_flag_tween.tween_property(_screen_mat, "shader_parameter/flag_mix", 1.0 if on else 0.0, 0.6)


## Start lights, called by Level.start_race() as the countdown runs: 0 puts the lamps on the screen,
## all dark; 1..3 lights that many red; 4 turns them all green. GREEN_HOLD seconds after green the
## screen goes back to the ticker.
func show_start_lights(step: int) -> void:
	if _screen_mat == null:
		return
	if _lights_tween:
		_lights_tween.kill()
	var green := step >= 4
	var red := Vector3.ZERO if green else Vector3(float(step >= 1), float(step >= 2), float(step >= 3))
	_glow.light_color = Color(0.25, 1.0, 0.35) if green else Color(1.0, 0.1, 0.05)
	_glow.visible = step > 0
	_lights_tween = create_tween().set_parallel()
	_lights_tween.tween_property(_screen_mat, "shader_parameter/board", 1.0, 0.3)
	_lights_tween.tween_property(_screen_mat, "shader_parameter/lamps_red", red, 0.05)
	_lights_tween.tween_property(_screen_mat, "shader_parameter/lamps_green", 1.0 if green else 0.0, 0.05)
	_lights_tween.tween_property(_glow, "light_energy", GLOW_ENERGY * (1.0 if green else clampf(step / 3.0, 0.0, 1.0)), 0.05)
	if green:
		_lights_tween.chain().tween_interval(GREEN_HOLD)
		_lights_tween.chain().tween_property(_screen_mat, "shader_parameter/board", 0.0, 0.6)
		_lights_tween.tween_property(_glow, "light_energy", 0.0, 0.6)
		_lights_tween.chain().tween_callback(_lights_off)


func _lights_off() -> void:
	_screen_mat.set_shader_parameter("lamps_green", 0.0)
	_glow.visible = false


func _build() -> void:
	if _build_root:
		_build_root.free()
	_feet.clear()
	_screen_mat = null
	_glow = null
	_ticker_vp = null
	_ticker_canvas = null
	_build_root = Node3D.new()
	_build_root.name = "GateBuild"
	add_child(_build_root, false, Node.INTERNAL_MODE_BACK)
	if is_finish_line:
		_build_gantry()
	else:
		_build_checkpoint()


func _build_gantry() -> void:
	_add_mesh(_build_root, _gantry_mesh())
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	screen.mesh = quad
	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = START_LIGHTS
	_screen_mat.set_shader_parameter("led_count", (SCREEN_SIZE / LED_PITCH).round())
	_screen_mat.set_shader_parameter("board", 0.0)
	_screen_mat.set_shader_parameter("lamps_red", Vector3.ZERO)
	_screen_mat.set_shader_parameter("lamps_green", 0.0)
	_screen_mat.set_shader_parameter("flag_mix", 1.0 if _flag_on else 0.0)
	screen.material_override = _screen_mat
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.position = Vector3(0.0, (POD_Y0 + SOFFIT_Y) * 0.5, POD_Z1 + 0.004)
	_build_root.add_child(screen)

	# The ticker's strip, rendered only when its text changes.
	_ticker_vp = SubViewport.new()
	_ticker_vp.size = Vector2i(TICKER_TEX_W, TICKER_ROWS * TICKER_SS)
	_ticker_vp.disable_3d = true
	_ticker_vp.transparent_bg = false
	_ticker_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_ticker_canvas = Control.new()
	_ticker_canvas.size = Vector2(_ticker_vp.size)
	_ticker_canvas.draw.connect(_draw_ticker)
	_ticker_vp.add_child(_ticker_canvas)
	_build_root.add_child(_ticker_vp)
	_screen_mat.set_shader_parameter("ticker_tex", _ticker_vp.get_texture())
	_screen_mat.set_shader_parameter("ticker_ss", float(TICKER_SS))
	_screen_mat.set_shader_parameter("ticker_rows", float(TICKER_ROWS))
	_screen_mat.set_shader_parameter("ticker_len", _ticker_len)

	# The lit lamps throw their colour over the grid. Unshadowed, and only on during the countdown.
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0.0, POD_Y0 - 0.4, POD_Z1 + 1.2)
	_glow.omni_range = 18.0
	_glow.light_energy = 0.0
	_glow.light_specular = 0.3
	_glow.shadow_enabled = false
	_glow.set_meta(&"no_shadow", true)
	_glow.visible = false
	_build_root.add_child(_glow)

	var body := _add_body(_build_root, "GateFrame")
	for side in [-1.0, 1.0]:
		_add_box_shape(body, Vector3(side * POST_X, (TOP_Y + FOOT_Y) * 0.5, 0.0), Vector3(POST_W, TOP_Y - FOOT_Y, GANTRY_D))
		_add_foot(Vector3(side * POST_X, 0.0, 0.0), Vector3(1.7, 1.1, 2.0), Vector3(0.0, -0.25, 0.0), _mat("plinth"))
	_add_box_shape(body, Vector3(0.0, (SOFFIT_Y + TOP_Y) * 0.5, 0.0), Vector3(2.0 * POST_X, TOP_Y - SOFFIT_Y, GANTRY_D))
	_add_box_shape(body, Vector3(0.0, (POD_Y0 + SOFFIT_Y) * 0.5, (POD_Z0 + POD_Z1) * 0.5), Vector3(2.0 * POD_HALF_W, SOFFIT_Y - POD_Y0, POD_Z1 - POD_Z0))


func _build_checkpoint() -> void:
	_add_mesh(_build_root, _truss_mesh(_truss_top))
	var banner := _add_mesh(_build_root, _banner_mesh(gate_color))
	banner.position.y = _banner_mid_y()
	for side in [1.0, -1.0]:
		banner.add_child(_banner_text(side))

	var beam_y := _truss_top - BLOCK * 0.5
	var body := _add_body(_build_root, "GateFrame")
	for side in [-1.0, 1.0]:
		_add_box_shape(body, Vector3(side * TRUSS_X, (_truss_top + TRUSS_FOOT) * 0.5, 0.0), Vector3(BLOCK, _truss_top - TRUSS_FOOT, BLOCK))
		_add_foot(Vector3(side * TRUSS_X, 0.0, 0.0), Vector3(1.0, 0.7, 1.0), Vector3.ZERO, _accent_mat(gate_color))
	_add_box_shape(body, Vector3(0.0, beam_y, 0.0), Vector3(2.0 * TRUSS_X + BLOCK, BLOCK, BLOCK))


## CHECKPOINT on one face of the banner (side +1 faces the cars coming in), sized to fit the field
## between the chequered ends whatever font the system falls back to.
func _banner_text(side: float) -> Label3D:
	var label := Label3D.new()
	label.text = "CHECKPOINT"
	label.font = _banner_font()
	label.font_size = 96
	label.modulate = INK
	label.outline_size = 0
	label.shaded = true
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var size: Vector2 = label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size)
	label.pixel_size = minf(TEXT_W / maxf(size.x, 1.0), TEXT_CAP / (label.font_size * 0.72))
	label.transform = Transform3D(Basis(Vector3.UP, 0.0 if side > 0.0 else PI), Vector3(0.0, 0.0, side * 0.016))
	return label


func _add_mesh(parent: Node3D, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	return mi


func _add_body(parent: Node3D, body_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	parent.add_child(body)
	return body


func _add_box_shape(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var cs := CollisionShape3D.new()
	cs.shape = box
	cs.position = center
	body.add_child(cs)


## A foot: the block under a post, moved onto the ground in a race. Its collider is a wall FOOT_WALL
## high: a cart clipping the top edge of a low block is flung into the air (PlayerCart only smooths
## edges up to STEP_SMOOTH_MAX_HEIGHT), where a wall just turns it aside.
func _add_foot(at: Vector3, size: Vector3, center: Vector3, mat: Material) -> void:
	var foot := Node3D.new()
	foot.position = at
	_build_root.add_child(foot)
	_add_mesh(foot, _box_mesh(size, center, mat))
	var bottom := center.y - size.y * 0.5
	_add_box_shape(_add_body(foot, "GateFoot"), Vector3(center.x, (bottom + FOOT_WALL) * 0.5, center.z), Vector3(size.x, FOOT_WALL - bottom, size.z))
	_feet.append(foot)


## In a race: stands the gate on the road under its middle, brings a checkpoint down to fit under
## anything over the road (Glacier Highway's sign gantries), and puts the feet on the ground. Waits
## for the level's runtime collision, so the rays see every prop.
func _settle_on_ground() -> void:
	await get_tree().physics_frame
	var level := get_parent()
	while level and not level.is_in_group("level"):
		level = level.get_parent()
	if level == null or _build_root == null:
		return
	if level.has_method("wait_for_collisions"):
		await level.wait_for_collisions()
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var road := _cast(space, Vector3(0.0, ROAD_SEARCH, 0.0), Vector3(0.0, -2.0, 0.0))
	var road_y: float = road.get("y", 0.0)
	if not is_finish_line:
		var top := minf(_headroom(space, road_y) - HEADROOM_GAP, TRUSS_TOP)
		if top < _truss_top - 0.05:
			_truss_top = maxf(floorf(top * 10.0) / 10.0, TRUSS_MIN_TOP)
			_build()
	_build_root.position.y = road_y
	for foot in _feet:
		var x := foot.position.x
		var hit := _cast(space, Vector3(x, road_y + 2.0, 0.0), Vector3(x, road_y - 2.5, 0.0))
		if not hit.is_empty():
			foot.position.y = hit["y"] - road_y


## Free height over the road at the gate: the lowest underside above the middle or the towers, or
## INF. The rays start HEADROOM_FROM up: anything lower would stop the carts, so it is a prop's
## collision hull reaching over the road (Canyon Chasm's rocks, Northlight's snow banks round the
## towers), not something to duck under.
func _headroom(space: PhysicsDirectSpaceState3D, road_y: float) -> float:
	var room := INF
	for x in [-TRUSS_X, 0.0, TRUSS_X]:
		var hit := _cast(space, Vector3(x, road_y + HEADROOM_FROM, 0.0), Vector3(x, road_y + TRUSS_TOP + 1.0, 0.0))
		if not hit.is_empty():
			room = minf(room, hit["y"] - road_y)
	return room


## Ray between two points in gate space that ignores the gate itself: {y, normal} of the hit in gate
## space, or empty. Back faces don't count: a ray down only finds ground facing up, a ray up only
## undersides.
func _cast(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	# Levels put gates on round coordinates, and a ray straight down a terrain grid line can slip
	# between its triangles (Desert Wadi's finish line), so aim a little off the line.
	var nudge := Vector3(0.031, 0.0, 0.017)
	var q := PhysicsRayQueryParameters3D.create(to_global(from + nudge), to_global(to + nudge))
	q.hit_back_faces = false
	var exclude: Array[RID] = []
	for b in _build_root.find_children("*", "StaticBody3D", true, false):
		exclude.append((b as StaticBody3D).get_rid())
	q.exclude = exclude
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {}
	return {"y": to_local(hit["position"]).y, "normal": (global_basis.inverse() * Vector3(hit["normal"])).normalized()}


## The banner hangs BANNER_GAP under the cross truss's bottom chords.
func _banner_mid_y() -> float:
	return _truss_top - BLOCK * 0.5 - TRUSS_W * 0.5 - CHORD_R - BANNER_GAP - BANNER_H * 0.5


# ----------------------------------------------------------------------------------------------
#  Shared meshes and materials
# ----------------------------------------------------------------------------------------------

static func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"paint":
			m.albedo_color = NAVY
			m.metallic = 0.55
			m.roughness = 0.33
		"trim":
			m.albedo_color = Color(0.78, 0.8, 0.84)
			m.metallic = 0.9
			m.roughness = 0.22
		"led":
			m.albedo_color = Color(0.9, 0.95, 1.0)
			m.emission_enabled = true
			m.emission = Color(0.75, 0.88, 1.0)
			m.emission_energy_multiplier = 1.4
		"plinth":
			m.albedo_color = Color(0.11, 0.115, 0.12)
			m.roughness = 0.75
		"alu":
			m.albedo_color = Color(0.8, 0.82, 0.85)
			m.metallic = 0.85
			m.roughness = 0.3
		"painted":
			# Vertex colours carry the picture: chequers, banner field and bands.
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			m.roughness = 0.6
	_mats[key] = m
	return m


static func _accent_mat(c: Color) -> Material:
	var key := "accent_" + c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.55
		_mats[key] = m
	return _mats[key]


## The ticker's font: plain coverage, not MSDF, since the strip is sampled once per LED.
static func _ticker_font() -> Font:
	if _plain_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Arial Black", "Impact", "Helvetica Neue", "Arial", "sans-serif"])
		f.font_weight = 900
		_plain_font = f
	return _plain_font


static func _banner_font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Arial Black", "Impact", "Helvetica Neue", "Arial", "sans-serif"])
		f.font_weight = 900
		f.multichannel_signed_distance_field = true
		_font = f
	return _font


static func _box_mesh(size: Vector3, center: Vector3, mat: Material) -> Mesh:
	var key := "box_%s_%s_%d" % [size, center, mat.get_instance_id()]
	if not _meshes.has(key):
		var st := _begin()
		_box(st, center - size * 0.5, center + size * 0.5)
		var mesh := ArrayMesh.new()
		_commit(st, mesh, mat)
		_meshes[key] = mesh
	return _meshes[key]


## The arch, the screen pod and the chequered bands. The arch is swept between upside-down U
## contours (see _u_points): paint, a raised silver trim band near each edge, and bevelled edges.
static func _gantry_mesh() -> Mesh:
	if _meshes.has("gantry"):
		return _meshes["gantry"]
	var paint := _begin()
	var trim := _begin()
	var led := _begin()
	var chequer := _begin()
	var radial := _u_radial()
	var zf := GANTRY_D * 0.5
	for face in [1.0, -1.0]:
		var z: float = zf * face
		var n := Vector3(0.0, 0.0, face)
		_face_strip(paint, _inner(CHAMFER), _inner(0.14), z, n)
		_band(trim, _inner(0.14), _inner(0.24), z, face, radial)
		_face_strip(paint, _inner(0.24), _outer(0.3), z, n)
		_band(trim, _outer(0.3), _outer(0.16), z, face, radial)
		_face_strip(paint, _outer(0.16), _outer(CHAMFER), z, n)
		_bevel(paint, _outer(CHAMFER), z, _outer(0.0), z - face * CHAMFER, radial, 1.0, face)
		_bevel(paint, _inner(CHAMFER), z, _inner(0.0), z - face * CHAMFER, radial, -1.0, face)
		# Chequered band across the beam, between the trim lines.
		var zc: float = z + face * 0.02
		var x0 := -CHEQUER * CHEQUER_COLS * 0.5
		var y0 := (SOFFIT_Y + 0.24 + TOP_Y - 0.3) * 0.5 - CHEQUER
		for r in 2:
			for c in CHEQUER_COLS:
				chequer.set_color(Color(0.93, 0.93, 0.92) if (r + c) % 2 == 0 else Color(0.03, 0.03, 0.035))
				var a := Vector3(x0 + c * CHEQUER, y0 + r * CHEQUER, zc)
				_quad(chequer, a, a + Vector3(CHEQUER, 0, 0), a + Vector3(CHEQUER, CHEQUER, 0), a + Vector3(0, CHEQUER, 0), n, n, n, n)
	_wall(paint, _outer(0.0), zf - CHAMFER, -zf + CHAMFER, radial, 1.0)
	_wall(paint, _inner(0.0), zf - CHAMFER, -zf + CHAMFER, radial, -1.0)
	# A light strip round the inside of the arch.
	_wall(led, _inner(-0.005), -0.05, 0.05, radial, -1.0)
	# The screen pod: a box under the middle of the beam, with a silver frame round the screen.
	_box(paint, Vector3(-POD_HALF_W, POD_Y0, POD_Z0), Vector3(POD_HALF_W, SOFFIT_Y, POD_Z1))
	var sx := SCREEN_SIZE.x * 0.5
	var sy0 := (POD_Y0 + SOFFIT_Y - SCREEN_SIZE.y) * 0.5
	var sy1 := sy0 + SCREEN_SIZE.y
	var fw := 0.05
	_box(trim, Vector3(-sx - fw, sy0 - fw, POD_Z1), Vector3(sx + fw, sy0, POD_Z1 + 0.025))
	_box(trim, Vector3(-sx - fw, sy1, POD_Z1), Vector3(sx + fw, sy1 + fw, POD_Z1 + 0.025))
	_box(trim, Vector3(-sx - fw, sy0, POD_Z1), Vector3(-sx, sy1, POD_Z1 + 0.025))
	_box(trim, Vector3(sx, sy0, POD_Z1), Vector3(sx + fw, sy1, POD_Z1 + 0.025))
	var mesh := ArrayMesh.new()
	_commit(paint, mesh, _mat("paint"))
	_commit(trim, mesh, _mat("trim"))
	_commit(led, mesh, _mat("led"))
	_commit(chequer, mesh, _mat("painted"))
	_meshes["gantry"] = mesh
	return mesh


## Both towers, the corner blocks and the cross truss, `top` high: square box truss with zig-zag
## lacing.
static func _truss_mesh(top: float) -> Mesh:
	var key := "truss_%.1f" % top
	if _meshes.has(key):
		return _meshes[key]
	var st := _begin()
	var beam_y := top - BLOCK * 0.5
	for side in [-1.0, 1.0]:
		var x: float = side * TRUSS_X
		_truss_run(st, Vector3(x, TRUSS_FOOT, 0.0), Vector3(x, beam_y - BLOCK * 0.5, 0.0), Vector3.RIGHT)
		_box(st, Vector3(x, beam_y, 0.0) - Vector3.ONE * BLOCK * 0.5, Vector3(x, beam_y, 0.0) + Vector3.ONE * BLOCK * 0.5)
	_truss_run(st, Vector3(-TRUSS_X + BLOCK * 0.5, beam_y, 0.0), Vector3(TRUSS_X - BLOCK * 0.5, beam_y, 0.0), Vector3.UP)
	var mesh := ArrayMesh.new()
	_commit(st, mesh, _mat("alu"))
	_meshes[key] = mesh
	return mesh


## The banner, centred on its own origin: a white field between bands of the gate colour,
## chequered ends, both faces, and the straps it hangs from.
static func _banner_mesh(accent: Color) -> Mesh:
	var key := "banner_" + accent.to_html()
	if _meshes.has(key):
		return _meshes[key]
	var st := _begin()
	var hw := BANNER_W * 0.5
	var hh := BANNER_H * 0.5
	var field := BANNER_H - 2.0 * BANNER_BAND
	var sq := field / 4.0
	var white := Color(0.95, 0.95, 0.93)
	for face in [1.0, -1.0]:
		var z: float = face * 0.01
		var n := Vector3(0.0, 0.0, face)
		st.set_color(accent)
		_rect(st, Vector2(-hw, hh - BANNER_BAND), Vector2(hw, hh), z, n)
		_rect(st, Vector2(-hw, -hh), Vector2(hw, -hh + BANNER_BAND), z, n)
		st.set_color(white)
		_rect(st, Vector2(-hw + 4.0 * sq, -hh + BANNER_BAND), Vector2(hw - 4.0 * sq, hh - BANNER_BAND), z, n)
		for end in [-1.0, 1.0]:
			for r in 4:
				for c in 4:
					st.set_color(white if (r + c) % 2 == 0 else Color(0.03, 0.03, 0.035))
					var x0: float = (hw - 4.0 * sq + c * sq) * end
					var y0: float = -hh + BANNER_BAND + r * sq
					_rect(st, Vector2(minf(x0, x0 + sq * end), y0), Vector2(maxf(x0, x0 + sq * end), y0 + sq), z, n)
	# Hems round the edges, so the banner has some thickness side on.
	st.set_color(accent)
	for e in [[Vector3(-hw, hh, 0.0), Vector3(hw, hh, 0.0), Vector3.UP], [Vector3(-hw, -hh, 0.0), Vector3(hw, -hh, 0.0), Vector3.DOWN],
			[Vector3(-hw, -hh, 0.0), Vector3(-hw, hh, 0.0), Vector3.LEFT], [Vector3(hw, -hh, 0.0), Vector3(hw, hh, 0.0), Vector3.RIGHT]]:
		var d := Vector3(0.0, 0.0, 0.01)
		_quad(st, e[0] - d, e[1] - d, e[1] + d, e[0] + d, e[2], e[2], e[2], e[2])
	# Straps up into the cross truss's bottom chords.
	st.set_color(Color(0.04, 0.04, 0.045))
	for i in 5:
		var x := lerpf(-hw + 0.15, hw - 0.15, i / 4.0)
		_box(st, Vector3(x - 0.02, hh, -0.012), Vector3(x + 0.02, hh + BANNER_GAP + CHORD_R, 0.012))
	var mesh := ArrayMesh.new()
	_commit(st, mesh, _mat("painted"))
	_meshes[key] = mesh
	return mesh


# ----------------------------------------------------------------------------------------------
#  Geometry helpers
# ----------------------------------------------------------------------------------------------

static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _commit(st: SurfaceTool, mesh: ArrayMesh, mat: Material) -> void:
	st.index()
	st.set_material(mat)
	st.commit(mesh)


## A quad with a normal per corner. Godot's front faces wind clockwise ((c - a) x (b - a) points at
## the viewer), so the winding follows the normals whichever way round the corners come.
static func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		n0: Vector3, n1: Vector3, n2: Vector3, n3: Vector3) -> void:
	if (p2 - p0).cross(p1 - p0).dot(n0 + n1 + n2 + n3) < 0.0:
		var p := p1
		p1 = p3
		p3 = p
		var n := n1
		n1 = n3
		n3 = n
	for v in [[p0, n0], [p1, n1], [p2, n2], [p0, n0], [p2, n2], [p3, n3]]:
		st.set_normal(v[1])
		st.add_vertex(v[0])


static func _rect(st: SurfaceTool, lo: Vector2, hi: Vector2, z: float, n: Vector3) -> void:
	_quad(st, Vector3(lo.x, lo.y, z), Vector3(hi.x, lo.y, z), Vector3(hi.x, hi.y, z), Vector3(lo.x, hi.y, z), n, n, n, n)


static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3) -> void:
	var c := [
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
	]
	for f in [[0, 1, 2, 3, Vector3.FORWARD], [4, 5, 6, 7, Vector3.BACK], [0, 1, 5, 4, Vector3.DOWN],
			[3, 2, 6, 7, Vector3.UP], [0, 3, 7, 4, Vector3.LEFT], [1, 2, 6, 5, Vector3.RIGHT]]:
		var n: Vector3 = f[4]
		_quad(st, c[f[0]], c[f[1]], c[f[2]], c[f[3]], n, n, n, n)


## A tube from a to b with smooth sides and open ends (they sit in joints).
static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, r: float, sides: int) -> void:
	var axis := (b - a).normalized()
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var n0 := u * cos(a0) + v * sin(a0)
		var n1 := u * cos(a1) + v * sin(a1)
		_quad(st, a + n0 * r, b + n0 * r, b + n1 * r, a + n1 * r, n0, n0, n1, n1)


## Square box truss from a to b: four chords TRUSS_W apart, `across` giving one side's direction,
## and zig-zag lacing on each face.
static func _truss_run(st: SurfaceTool, a: Vector3, b: Vector3, across: Vector3) -> void:
	var axis := (b - a).normalized()
	var h := TRUSS_W * 0.5
	var u := across * h
	var v := axis.cross(across).normalized() * h
	var corners := [u + v, u - v, -u - v, -u + v]
	for c in corners:
		_tube(st, a + c, b + c, CHORD_R, 8)
	var length := a.distance_to(b)
	var panels := maxi(1, roundi(length / LACE_PITCH))
	for k in 4:
		var c0: Vector3 = corners[k]
		var c1: Vector3 = corners[(k + 1) % 4]
		for j in panels:
			var p := a + axis * (length * j / panels)
			var q := a + axis * (length * (j + 1) / panels)
			if j % 2 == 0:
				_tube(st, p + c0, q + c1, LACE_R, 5)
			else:
				_tube(st, p + c1, q + c0, LACE_R, 5)


## Upside-down U from the left foot round to the right foot: sides at +-half_w, a flat top at top_y
## and quarter-circle corners of radius r. Every U has the same points in the same places, so any
## two stitch into a strip; _u_radial() gives the outward direction at each point.
static func _u_points(half_w: float, top_y: float, r: float) -> PackedVector2Array:
	var radial := _u_radial()
	var pts := PackedVector2Array([Vector2(-half_w, FOOT_Y)])
	for i in range(1, ARC_STEPS + 2):
		pts.append(Vector2(-half_w + r, top_y - r) + radial[i] * r)
	for i in range(ARC_STEPS + 2, 2 * ARC_STEPS + 3):
		pts.append(Vector2(half_w - r, top_y - r) + radial[i] * r)
	pts.append(Vector2(half_w, FOOT_Y))
	return pts


static func _u_radial() -> PackedVector2Array:
	var n := PackedVector2Array([Vector2(-1.0, 0.0)])
	for i in ARC_STEPS + 1:
		var ang := PI - 0.5 * PI * i / ARC_STEPS
		n.append(Vector2(cos(ang), sin(ang)))
	for i in ARC_STEPS + 1:
		var ang := 0.5 * PI - 0.5 * PI * i / ARC_STEPS
		n.append(Vector2(cos(ang), sin(ang)))
	n.append(Vector2(1.0, 0.0))
	return n


## The arch outline moved d into the steel from its outside, or from its inside (the opening).
static func _outer(d: float) -> PackedVector2Array:
	return _u_points(POST_X + POST_W * 0.5 - d, TOP_Y - d, OUTER_R - d)


static func _inner(d: float) -> PackedVector2Array:
	return _u_points(POST_X - POST_W * 0.5 + d, SOFFIT_Y + d, INNER_R + d)


static func _v(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, p.y, z)


## Flat strip at depth z between two U contours.
static func _face_strip(st: SurfaceTool, a: PackedVector2Array, b: PackedVector2Array, z: float, n: Vector3) -> void:
	for i in a.size() - 1:
		_quad(st, _v(a[i], z), _v(b[i], z), _v(b[i + 1], z), _v(a[i + 1], z), n, n, n, n)


## Wall along a U contour from depth z0 to z1, facing out of the arch (out = 1) or into the opening
## (out = -1).
static func _wall(st: SurfaceTool, c: PackedVector2Array, z0: float, z1: float, radial: PackedVector2Array, out: float) -> void:
	for i in c.size() - 1:
		var n0 := Vector3(radial[i].x, radial[i].y, 0.0) * out
		var n1 := Vector3(radial[i + 1].x, radial[i + 1].y, 0.0) * out
		_quad(st, _v(c[i], z0), _v(c[i], z1), _v(c[i + 1], z1), _v(c[i + 1], z0), n0, n0, n1, n1)


## 45-degree bevel from contour a on a face (depth za) to contour b on a wall (depth zb).
static func _bevel(st: SurfaceTool, a: PackedVector2Array, za: float, b: PackedVector2Array, zb: float,
		radial: PackedVector2Array, out: float, face: float) -> void:
	for i in a.size() - 1:
		var n0 := Vector3(radial[i].x * out, radial[i].y * out, face).normalized()
		var n1 := Vector3(radial[i + 1].x * out, radial[i + 1].y * out, face).normalized()
		_quad(st, _v(a[i], za), _v(b[i], zb), _v(b[i + 1], zb), _v(a[i + 1], za), n0, n0, n1, n1)


## Trim band standing TRIM_H proud of a face between contours a (the edge nearer the opening) and b.
static func _band(st: SurfaceTool, a: PackedVector2Array, b: PackedVector2Array, z: float, face: float, radial: PackedVector2Array) -> void:
	var zt := z + face * TRIM_H
	_face_strip(st, a, b, zt, Vector3(0.0, 0.0, face))
	_wall(st, a, z, zt, radial, -1.0)
	_wall(st, b, z, zt, radial, 1.0)
