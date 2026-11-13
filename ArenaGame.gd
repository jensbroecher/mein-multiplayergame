extends Node3D
## The arena games (NetworkManager.arena, the menus' ARENA pages, the lobby's arena modes): a child named "ArenaGame"
## of an arena level (regenerate_arena_hexbowl.gd, regenerate_arena_ctf.gd), which Level.gd finds and lets run the
## match instead of the laps. Every player for themselves, or two teams (red and blue).
##
## Football (`kind` "football", the Hex Bowl): six goals (children of "Goals", each a frame whose -z faces the pitch:
## x across the mouth, its metas "half_width" and "height"), one per side of the hexagon. All against all, each player
## owns one: a ball in someone else's goal scores for whoever touched it last, and its owner loses a point. In teams the
## goals alternate red and blue: a ball in the other side's goal scores for your side. The ball (KickBall.gd's ARENA
## style, "Balls/Ball_0") comes back to the middle after each goal; from MULTIBALL_FIRST a second ("Ball_1") joins
## every MULTIBALL_EVERY seconds until it goes in. A goal doesn't just take the ball away: it flies on into the net
## for GOAL_LINGER, charging up in the scorer's colour while the goal's frame lights up and confetti comes out of its
## mouth, then bursts (ArenaFx.gd); it comes back down a column of light. A ball nobody can get at (at rest up on
## something for STRANDED_TIME, or not moved STUCK_MOVE in STUCK_TIME) is taken back to the middle.
##
## Capture the flag (`kind` "ctf"): one flag at "FlagSpawn". Drive into it to take it; ram its carrier to steal it (a
## carrier that blows up or is respawned drops it, and a dropped flag goes home after FLAG_RETURN). Bring it to a
## base ("Bases/Base_i", its meta "letter") that isn't yours and the base turns your colour (CLAIM_BONUS points), the
## flag back to the middle after FLAG_RESPAWN. Every base held scores a point every BASE_TICK seconds; `win_score`
## ends it early. Everyone sees the flag: a beam of light over it, its carrier on the minimap, and an arrow over each
## local player's car pointing at it (at the nearest base to claim while they carry it).
##
## The host runs the rules and the bots (each bot's PlayerCart.arena_target) and sends the state about 12 times a
## second (`_state_rpc`: the clock, the scores, the balls, the flag, the bases); the events (goals, claims, steals) go
## reliably (`_event_rpc`), and the sides once at the start (`_config_rpc`). The balls are the host's: a client's are
## frozen and follow its state. The rest is drawn on every peer: the flag, the beams and bases, each car's team pip
## and name tag colour, the HUD (a scoreboard over each race HUD), the arrows, the minimap's markers (Minimap.gd).
##
## Bots in capture the flag drive by a graph laid by the level's generator (metas "nav_points", a PackedVector3Array,
## and "nav_links", [a, b, one_way] triples in a PackedInt32Array: one way for jumps and launch fans), straight at
## their goal once it is near and on their level.

const TEAM_COLORS := [Color(0.96, 0.22, 0.2), Color(0.2, 0.5, 1.0)]
const TEAM_NAMES := ["RED", "BLUE"]
const SLOT_COLORS := [Color(0.96, 0.22, 0.2), Color(0.2, 0.5, 1.0), Color(1.0, 0.82, 0.1), Color(0.25, 0.86, 0.36),
	Color(0.76, 0.38, 1.0), Color(1.0, 0.52, 0.12)]
const SLOT_NAMES := ["RED", "BLUE", "YELLOW", "GREEN", "PURPLE", "ORANGE"]
const NEUTRAL := Color(0.74, 0.76, 0.8)

@export_enum("football", "ctf") var kind := "football"
@export var match_seconds := 300.0
## A side that reaches it wins at once (0: none).
@export var win_score := 0

const GOAL_PAUSE := 2.6
const GOAL_LINGER := 0.55
const GOAL_FLASH := 1.6
const APPEAR_TIME := 0.5
## A ball at rest (under STRANDED_SPEED) with its middle more than STRANDED_UP over where it lies on the pitch is up
## on something no car drives on; after STRANDED_TIME it goes back to the middle. So does one that hasn't moved
## STUCK_MOVE in STUCK_TIME (wedged: with six cars after it a free ball never lies that long).
const STRANDED_UP := 1.5
const STRANDED_SPEED := 1.6
const STRANDED_TIME := 2.0
const STUCK_MOVE := 2.0
const STUCK_TIME := 12.0
const MULTIBALL_FIRST := 80.0
const MULTIBALL_EVERY := 75.0
const TOUCH_REACH := 3.3
const PICKUP_REACH := 3.8
const STEAL_REACH := 3.1
const STEAL_GRACE := 2.0
const BASE_RADIUS := 9.0
const CLAIM_BONUS := 10
const BASE_TICK := 2.0
const FLAG_RETURN := 20.0
const FLAG_RESPAWN := 3.0
const SYNC_EVERY := 0.08
const SOUND_GOAL := "res://sounds/Fans_cheering.wav"
const SOUND_CLAIM := "res://sounds/checkpoint_passed.wav"
const SOUND_PICKUP := "res://sounds/items/shield_up.wav"
const SOUND_DROP := "res://sounds/items/shield_break.wav"

enum Flag { HOME, CARRIED, DROPPED, RESPAWNING }

var teams := false
var _level: Node
var _side := {}
var _spawn_of := {}
var _sides := 2
var _score := PackedInt32Array()
var _stat := {}
var _time_left := 0.0
var _running := false
var _ended := false
var _sync_t := 0.0
var _cfg_received := false

var _goals: Array = []
var _goal_owner := PackedInt32Array()
var _balls: Array = []
var _ball_active: Array = []
var _ball_pause: Array = []
var _last_touch: Array = []
var _ball_net: Array = []
var _ball_spawn := Vector3.ZERO
var _ball_linger: Array = []
var _ball_side: Array = []
var _ball_stranded: Array = []
var _ball_anchor: Array = []
## Each ball's passing look on this peer: [what ("", "charge", "appear"), its age, its colour].
var _ball_anim: Array = []
var _goal_flash := PackedFloat32Array()
var _goal_labels: Array = []
var _fx: Node3D
var _multiball_t := 0.0

var _bases: Array = []
var _base_owner := PackedInt32Array()
var _flag_state: int = Flag.HOME
var _carrier := 0
var _flag_pos := Vector3.ZERO
var _flag_home := Vector3.ZERO
var _flag_timer := 0.0
var _tick := 0.0
var _no_pick := {}
var _steal_grace := 0.0

var _astar: AStar3D
var _nav_pts := PackedVector3Array()
var _bot_nav := {}
var _bot_role := {}

var _flag_node: Node3D
var _flag_cloth: MeshInstance3D
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _base_vis: Array = []
var _goal_vis: Array = []
var _arrows := {}
var _pips := {}
var _huds: Array = []
var _resp_t := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_level = get_parent()
	var a: Dictionary = NetworkManager.arena
	teams = bool(a.get("teams", false)) if str(a.get("kind", "")) == kind else bool(get_meta(&"default_teams", false))
	_sides = 2 if teams else NetworkManager.MAX_PLAYERS
	_score.resize(_sides)
	var goals_node := get_node_or_null("Goals")
	if goals_node:
		for g in goals_node.get_children():
			if g is Node3D:
				_goals.append(g)
	_goal_owner.resize(_goals.size())
	for i in _goals.size():
		_goal_owner[i] = i % 2 if teams else i
	var balls_node := get_node_or_null("Balls")
	if balls_node:
		for b in balls_node.get_children():
			if b is RigidBody3D:
				_balls.append(b)
				_ball_active.append(false)
				_ball_pause.append(0.0)
				_last_touch.append(0)
				_ball_net.append([b.global_position, Vector3.ZERO])
				_ball_linger.append(0.0)
				_ball_side.append(-1)
				_ball_stranded.append(0.0)
				_ball_anchor.append([b.global_position, 0.0])
				_ball_anim.append(["", 0.0, Color(1, 1, 1)])
	var bs := get_node_or_null("BallSpawn")
	_ball_spawn = bs.global_position if bs else global_position
	var bases_node := get_node_or_null("Bases")
	if bases_node:
		for b in bases_node.get_children():
			if b is Node3D:
				_bases.append(b)
	_base_owner.resize(_bases.size())
	_base_owner.fill(-1)
	var fs := get_node_or_null("FlagSpawn")
	_flag_home = fs.global_position if fs else global_position
	_flag_pos = _flag_home
	var client := multiplayer.multiplayer_peer != null and not multiplayer.is_server()
	for i in _balls.size():
		var b: RigidBody3D = _balls[i]
		if client:
			b.set("remote_driven", true)
		_set_ball_active(i, i == 0, false)
	if kind == "ctf":
		_build_flag()
		_build_bases()
		_build_nav()
	_build_goal_vis()
	_goal_flash.resize(_goals.size())
	if kind == "football":
		_fx = Node3D.new()
		_fx.name = "ArenaFx"
		_fx.set_script(load("res://ArenaFx.gd"))
		add_child(_fx)
	call_deferred("_setup_hud")
	if client:
		_request_config.rpc_id(1)


# ======================================================================================
#  Sides, colours, names
# ======================================================================================

func side_of(id: int) -> int:
	return int(_side.get(id, -1))


func side_color(side: int) -> Color:
	if side < 0:
		return NEUTRAL
	return TEAM_COLORS[side % 2] if teams else SLOT_COLORS[side % SLOT_COLORS.size()]


func side_name(side: int) -> String:
	if side < 0:
		return ""
	return TEAM_NAMES[side % 2] if teams else SLOT_NAMES[side % SLOT_NAMES.size()]


func cart_color(cart: Node) -> Color:
	return side_color(side_of(str(cart.name).to_int()))


func _cart(id: int) -> Node:
	var pc: Node = _level.get_node_or_null("Players") if _level else null
	return pc.get_node_or_null(str(id)) if pc else null


func _carts() -> Array:
	return get_tree().get_nodes_in_group("player_carts")


func _name_of(id: int) -> String:
	if NetworkManager.players.has(id):
		return str(NetworkManager.players[id].get("name", "Racer"))
	var c := _cart(id)
	return str(c.get("player_name")) if c else "Racer"


## A side's display name: the team's, or in all-vs-all the player's own.
func _side_label(side: int) -> String:
	if teams:
		return side_name(side)
	for id in _side:
		if int(_side[id]) == side:
			return _name_of(id)
	return side_name(side)


func item_spots() -> Array:
	var out: Array = []
	var n := get_node_or_null("ItemSpots")
	if n:
		for c in n.get_children():
			if c is Node3D:
				out.append((c as Node3D).global_position + Vector3(0, 1.5, 0))
	return out


# ======================================================================================
#  Start, config
# ======================================================================================

## Level.start_race, on every peer at the green light.
func on_race_started() -> void:
	_running = true
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		var i := 0
		for id in _level.player_stats.keys():
			_spawn_of[id] = i
			_side[id] = i % 2 if teams else i % NetworkManager.MAX_PLAYERS
			_stat[id] = 0
			i += 1
		_time_left = match_seconds
		_multiball_t = MULTIBALL_FIRST
		if kind == "football":
			_kickoff(0)
		_send_config()
	_apply_sides()


func _send_config() -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_config_rpc.rpc(teams, _side, _spawn_of)


@rpc("any_peer", "call_remote", "reliable")
func _request_config() -> void:
	if multiplayer.is_server() and not _side.is_empty():
		_config_rpc.rpc_id(multiplayer.get_remote_sender_id(), teams, _side, _spawn_of)


@rpc("authority", "call_remote", "reliable")
func _config_rpc(t: bool, sides: Dictionary, spawns: Dictionary) -> void:
	teams = t
	_sides = 2 if teams else NetworkManager.MAX_PLAYERS
	_score.resize(_sides)
	_side = sides
	_spawn_of = spawns
	for i in _goals.size():
		_goal_owner[i] = i % 2 if teams else i
	_cfg_received = true
	_apply_sides()


## Each cart's team (for the bots' items), name tag colour and pip; the goals' colours.
func _apply_sides() -> void:
	for cart in _carts():
		var id := str(cart.name).to_int()
		var s := side_of(id)
		cart.set("arena_team", s if teams else -1)
		var tag = cart.get_node_or_null("Visuals/NameTag")
		if tag is Label3D:
			(tag as Label3D).modulate = side_color(s).lightened(0.25)
	_paint_goals()


# ======================================================================================
#  The host's rules
# ======================================================================================

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _level == null:
		return
	var host := multiplayer.multiplayer_peer == null or multiplayer.is_server()
	if not host:
		_follow_net_balls(delta)
		return
	if not _running or _ended:
		return
	_time_left = maxf(0.0, _time_left - delta)
	if kind == "football":
		_football_rules(delta)
	else:
		_ctf_rules(delta)
	_drive_bots(delta)
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = SYNC_EVERY
		_broadcast()
	var top := 0
	for v in _score:
		top = maxi(top, v)
	if _time_left <= 0.0 or (win_score > 0 and top >= win_score):
		_finish_match()


func _broadcast() -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	var balls: Array = []
	for i in _balls.size():
		var b: RigidBody3D = _balls[i]
		balls.append([_ball_active[i], b.global_position, b.linear_velocity])
	_state_rpc.rpc(_time_left, _score, balls, [_flag_state, _carrier, _flag_pos], _base_owner)


@rpc("authority", "call_remote", "unreliable_ordered")
func _state_rpc(t_left: float, scores: PackedInt32Array, balls: Array, flag: Array, bases: PackedInt32Array) -> void:
	_running = true
	_time_left = t_left
	_score = scores
	for i in mini(balls.size(), _balls.size()):
		var on: bool = balls[i][0]
		if on != bool(_ball_active[i]):
			_set_ball_active(i, on, false)
		_ball_net[i] = [balls[i][1], balls[i][2], Time.get_ticks_msec()]
	_flag_state = int(flag[0])
	_carrier = int(flag[1])
	_flag_pos = flag[2]
	if bases.size() == _base_owner.size():
		_base_owner = bases


func _follow_net_balls(_delta: float) -> void:
	for i in _balls.size():
		if not bool(_ball_active[i]) or (_ball_net[i] as Array).size() < 3:
			continue
		var b: RigidBody3D = _balls[i]
		var age: float = minf((Time.get_ticks_msec() - int(_ball_net[i][2])) * 0.001, 0.25)
		var want: Vector3 = (_ball_net[i][0] as Vector3) + (_ball_net[i][1] as Vector3) * age
		if b.global_position.distance_to(want) > 6.0:
			b.global_position = want
		else:
			b.global_position = b.global_position.lerp(want, 0.35)


# ---- Football --------------------------------------------------------------------------------------------------------

func _set_ball_active(i: int, on: bool, at_spawn := true) -> void:
	_ball_active[i] = on
	var b: RigidBody3D = _balls[i]
	b.visible = on
	b.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if not on and b.has_method("set_fx"):
		_ball_anim[i] = ["", 0.0, Color(1, 1, 1)]
		b.set_fx(1.0, 0.0)
	if on and at_spawn and (multiplayer.multiplayer_peer == null or multiplayer.is_server()):
		var off := Vector3(randf_range(-3.0, 3.0), 7.0 + 2.0 * i, randf_range(-3.0, 3.0))
		if b.has_method("reset_home"):
			b.reset_home(Transform3D(Basis(), _ball_spawn + off))
		else:
			b.global_position = _ball_spawn + off
		b.linear_velocity = Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))


func _kickoff(i: int) -> void:
	_ball_pause[i] = 0.0
	_ball_linger[i] = 0.0
	_ball_stranded[i] = 0.0
	_last_touch[i] = 0
	_set_ball_active(i, true)
	var at: Vector3 = (_balls[i] as Node3D).global_position
	_ball_anchor[i] = [at, 0.0]
	_ball_fx_all("spawn", i, at, -1, -1)


## A ball nobody can get at goes back to the middle: a puff where it lay, a new kick-off.
func _return_ball(i: int) -> void:
	_ball_fx_all("reset", i, (_balls[i] as Node3D).global_position, -1, -1)
	_event_rpc_all("ballreset", "", -1)
	_kickoff(i)


## Whether ball `i` lies where no car gets at it (see STRANDED_UP and STUCK_MOVE).
func _ball_out_of_reach(i: int, delta: float) -> bool:
	var b: RigidBody3D = _balls[i]
	var p := b.global_position
	var up := p.y - (_ball_spawn.y - 0.5) - 0.95
	if up > STRANDED_UP and b.linear_velocity.length() < STRANDED_SPEED:
		_ball_stranded[i] = float(_ball_stranded[i]) + delta
	else:
		_ball_stranded[i] = 0.0
	var anchor: Array = _ball_anchor[i]
	if p.distance_to(anchor[0]) > STUCK_MOVE:
		_ball_anchor[i] = [p, 0.0]
	else:
		anchor[1] = float(anchor[1]) + delta
	return float(_ball_stranded[i]) > STRANDED_TIME or float((_ball_anchor[i] as Array)[1]) > STUCK_TIME


func _football_rules(delta: float) -> void:
	if _balls.size() > 1:
		_multiball_t -= delta
		if _multiball_t <= 0.0:
			_multiball_t = MULTIBALL_EVERY
			if not bool(_ball_active[1]) and _ball_pause[1] <= 0.0 and _time_left > 20.0:
				_kickoff(1)
				_event_rpc_all("multiball", "", -1)
	for i in _balls.size():
		if _ball_pause[i] > 0.0:
			_ball_pause[i] -= delta
			if _ball_pause[i] <= 0.0 and i == 0:
				_kickoff(0)
			continue
		if not bool(_ball_active[i]):
			continue
		var b: RigidBody3D = _balls[i]
		var p := b.global_position
		# In the net after a goal: it bursts when the moment is over, and comes back after the pause.
		if float(_ball_linger[i]) > 0.0:
			_ball_linger[i] = float(_ball_linger[i]) - delta
			if float(_ball_linger[i]) <= 0.0:
				_ball_fx_all("burst", i, p, int(_ball_side[i]), -1)
				_set_ball_active(i, false, false)
				if i == 0:
					_ball_pause[0] = GOAL_PAUSE
			continue
		var best := TOUCH_REACH
		for cart in _carts():
			var d: float = cart.global_position.distance_to(p)
			if d < best:
				best = d
				_last_touch[i] = str(cart.name).to_int()
		if p.y < _ball_spawn.y - 25.0 or p.distance_to(_ball_spawn) > 400.0:
			_kickoff(i)
			continue
		if _ball_out_of_reach(i, delta):
			_return_ball(i)
			continue
		for g in _goals.size():
			var goal: Node3D = _goals[g]
			var lp := goal.to_local(p)
			if lp.z > 0.7 and lp.z < 9.0 and absf(lp.x) < float(goal.get_meta(&"half_width", 6.0)) and lp.y < float(goal.get_meta(&"height", 5.0)) + 0.5:
				_goal_scored(i, g)
				break


func _goal_scored(ball: int, goal: int) -> void:
	var owner := int(_goal_owner[goal])
	var scorer := int(_last_touch[ball])
	var s_side := side_of(scorer)
	var own := s_side == owner or scorer == 0
	var fx_side := -1
	if teams:
		var beneficiary := 1 - owner
		fx_side = beneficiary
		_score[beneficiary] += 1
		if not own:
			_stat[scorer] = int(_stat.get(scorer, 0)) + 1
		_event_rpc_all("owngoal" if own else "goal", _name_of(scorer) if scorer != 0 else "", beneficiary)
	else:
		_score[owner] = maxi(0, _score[owner] - 1)
		if not own and s_side >= 0:
			_score[s_side] += 1
			_stat[scorer] = int(_stat.get(scorer, 0)) + 1
		_event_rpc_all("owngoal" if own else "goal", _name_of(scorer) if scorer != 0 else "", owner if own else s_side)
		fx_side = owner if own else s_side
	# The ball flies on into the net and bursts there (_football_rules), in the colour of the side that gained.
	_ball_side[ball] = fx_side
	_ball_linger[ball] = GOAL_LINGER
	_ball_fx_all("score", ball, (_balls[ball] as Node3D).global_position, fx_side, goal)


func _ball_fx_all(what: String, ball: int, at: Vector3, side: int, goal: int) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_ball_fx_rpc(what, ball, at, side, goal)
	else:
		_ball_fx_rpc.rpc(what, ball, at, side, goal)


## A ball's moment on every peer: "score" (it is in goal `goal`: it charges up, the goal lights), "burst" (it goes,
## at `at`), "spawn" (it comes in at `at`), "reset" (a stranded one is taken from `at`).
@rpc("authority", "call_local", "reliable")
func _ball_fx_rpc(what: String, ball: int, at: Vector3, side: int, goal: int) -> void:
	if _fx == null or ball < 0 or ball >= _balls.size():
		return
	var col := side_color(side) if side >= 0 else Color(0.62, 1.0, 0.3)
	match what:
		"score":
			_ball_anim[ball] = ["charge", 0.0, col]
			if goal >= 0 and goal < _goals.size():
				_goal_flash[goal] = GOAL_FLASH
				var g: Node3D = _goals[goal]
				_fx.goal(g, float(g.get_meta(&"half_width", 6.0)), float(g.get_meta(&"height", 5.0)), col)
		"burst":
			_ball_anim[ball] = ["", 0.0, col]
			_fx.burst(at, col)
		"spawn":
			_ball_anim[ball] = ["appear", 0.0, col]
			(_balls[ball] as Node).call("set_fx", 0.02, 4.0, col)
			_fx.spawn(at, _ball_spawn.y - 0.5, col)
		"reset":
			_fx.poof(at)


## The balls' passing looks (KickBall.set_fx) and the goals' frames lighting up after a goal, on every peer.
func _update_ball_fx(delta: float) -> void:
	for i in _balls.size():
		var a: Array = _ball_anim[i]
		if str(a[0]) == "":
			continue
		a[1] = float(a[1]) + delta
		var b: Node = _balls[i]
		if str(a[0]) == "charge":
			var k := clampf(float(a[1]) / GOAL_LINGER, 0.0, 1.0)
			b.call("set_fx", 1.0 + 0.2 * k * k, 0.4 + 3.2 * k * k, a[2])
		else:
			var k := clampf(float(a[1]) / APPEAR_TIME, 0.0, 1.0)
			# Out of nothing, a little past its size and back (a back ease).
			var size := 1.0 + 2.70158 * pow(k - 1.0, 3.0) + 1.70158 * pow(k - 1.0, 2.0)
			b.call("set_fx", size, 4.0 * pow(1.0 - k, 2.0), a[2])
			if k >= 1.0:
				a[0] = ""
				b.call("set_fx", 1.0, 0.0, a[2])
	for g in mini(_goal_flash.size(), _goal_vis.size()):
		if _goal_flash[g] <= 0.0:
			continue
		_goal_flash[g] = maxf(0.0, _goal_flash[g] - delta)
		var k := _goal_flash[g] / GOAL_FLASH
		var energy := 0.55 + 6.0 * k * k * (0.78 + 0.22 * cos(_goal_flash[g] * 9.0))
		for m in _goal_vis[g]:
			(m as StandardMaterial3D).emission_energy_multiplier = energy


# ---- Capture the flag --------------------------------------------------------------------------------------------

func _ctf_rules(delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	_steal_grace = maxf(0.0, _steal_grace - delta)
	match _flag_state:
		Flag.HOME, Flag.DROPPED:
			if _flag_state == Flag.DROPPED:
				_flag_timer -= delta
				if _flag_timer <= 0.0:
					_flag_state = Flag.HOME
					_flag_pos = _flag_home
					_event_rpc_all("return", "", -1)
					return
			for cart in _carts():
				var id := str(cart.name).to_int()
				if float(_no_pick.get(id, 0.0)) > now or not _can_hold(cart):
					continue
				if cart.global_position.distance_to(_flag_pos + Vector3(0, 0.8, 0)) < PICKUP_REACH:
					_flag_state = Flag.CARRIED
					_carrier = id
					_steal_grace = STEAL_GRACE * 0.5
					_event_rpc_all("pickup", _name_of(id), side_of(id))
					break
		Flag.CARRIED:
			var c := _cart(_carrier)
			if c == null or not _can_hold(c):
				_drop_flag(c)
				return
			_flag_pos = c.global_position
			var cs := side_of(_carrier)
			# Rammed: the flag goes to whoever hit the carrier.
			if _steal_grace <= 0.0:
				for o in _carts():
					var oid := str(o.name).to_int()
					if oid == _carrier or not _can_hold(o) or (teams and side_of(oid) == cs):
						continue
					if o.global_position.distance_to(c.global_position) < STEAL_REACH:
						_no_pick[_carrier] = now + 1.5
						_carrier = oid
						_steal_grace = STEAL_GRACE
						_event_rpc_all("steal", _name_of(oid), side_of(oid))
						return
			for bi in _bases.size():
				var base: Node3D = _bases[bi]
				var d: Vector3 = base.global_position - c.global_position
				if Vector2(d.x, d.z).length() < BASE_RADIUS and absf(d.y) < 6.0 and int(_base_owner[bi]) != cs:
					_base_owner[bi] = cs
					_score[cs] += CLAIM_BONUS
					_stat[_carrier] = int(_stat.get(_carrier, 0)) + 1
					_event_rpc_all("claim", _name_of(_carrier) + "|" + str(base.get_meta(&"letter", "?")), cs)
					_flag_state = Flag.RESPAWNING
					_flag_timer = FLAG_RESPAWN
					_carrier = 0
					_flag_pos = _flag_home
					return
		Flag.RESPAWNING:
			_flag_timer -= delta
			if _flag_timer <= 0.0:
				_flag_state = Flag.HOME
				_flag_pos = _flag_home
	_tick -= delta
	if _tick <= 0.0:
		_tick = BASE_TICK
		for bi in _base_owner.size():
			if int(_base_owner[bi]) >= 0:
				_score[int(_base_owner[bi])] += 1


func _can_hold(cart: Node) -> bool:
	return is_instance_valid(cart) and not cart.get("is_exploding") and not cart.get("is_teleporting") \
			and not cart.get("is_drowned") and bool(cart.get("can_move"))


func _drop_flag(c: Node) -> void:
	var at := _flag_pos
	if c != null and is_instance_valid(c):
		at = c.global_position
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 2, 0), at + Vector3(0, -60, 0), 1))
	_flag_pos = (hit["position"] as Vector3) if not hit.is_empty() else _flag_home
	if _flag_pos.y < _flag_home.y - 40.0:
		_flag_pos = _flag_home
	_no_pick[_carrier] = Time.get_ticks_msec() * 0.001 + 2.0
	_carrier = 0
	_flag_state = Flag.DROPPED
	_flag_timer = FLAG_RETURN
	_event_rpc_all("drop", "", -1)


# ---- Events ------------------------------------------------------------------------------------------------------

func _event_rpc_all(what: String, who: String, side: int) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_event_rpc(what, who, side)
	else:
		_event_rpc.rpc(what, who, side)


@rpc("authority", "call_local", "reliable")
func _event_rpc(what: String, who: String, side: int) -> void:
	var text := ""
	var sound := ""
	var db := -6.0
	match what:
		"goal":
			text = ("%s SCORES!" % side_name(side)) if teams else ("GOAL!  %s" % who)
			if teams and who != "":
				text += "\n" + who
			sound = SOUND_GOAL
			db = -4.0
		"owngoal":
			text = "OWN GOAL!" + (("\n" + side_name(side) + " +1") if teams else ("\n" + who if who != "" else ""))
			sound = SOUND_GOAL
		"multiball":
			text = "MULTIBALL!"
			sound = SOUND_PICKUP
		"ballreset":
			text = "BALL BACK TO THE MIDDLE"
		"pickup":
			text = "%s HAS THE FLAG!" % who
			sound = SOUND_PICKUP
		"steal":
			text = "%s STOLE THE FLAG!" % who
			sound = SOUND_PICKUP
		"drop":
			text = "THE FLAG IS DOWN!"
			sound = SOUND_DROP
		"return":
			text = "THE FLAG IS BACK IN THE MIDDLE"
		"claim":
			var parts := who.split("|")
			text = "%s CLAIMED BASE %s" % [parts[0], parts[1] if parts.size() > 1 else "?"]
			if teams:
				text += "\nFOR " + side_name(side)
			sound = SOUND_CLAIM
			db = -2.0
	if text != "":
		for ui in _level._all_race_uis():
			ui.show_message(text, 2.6)
	if sound != "":
		MusicManager.play_sfx(sound, db)
	# The stands go up for a goal (StageAmbience's roar on a stadium level).
	if what == "goal" and _level.get("_ambience") != null:
		_level.get("_ambience").roar()


# ---- The end -----------------------------------------------------------------------------------------------------

func _finish_match() -> void:
	if _ended:
		return
	_ended = true
	_running = false
	for cart in _carts():
		cart.set("arena_target", Vector3.INF)
	var rows: Array = []
	for id in _side:
		var s := side_of(id)
		var bot := true
		if NetworkManager.players.has(id):
			bot = bool(NetworkManager.players[id].get("is_ai", false))
		rows.append({"arena": true, "name": _name_of(id), "is_bot": bot, "side": s, "team_name": side_name(s),
			"team_color": side_color(s), "stat": int(_stat.get(id, 0)), "score": int(_score[s]) if s >= 0 else 0,
			"stat_name": "GOALS" if kind == "football" else "CLAIMS"})
	rows.sort_custom(func(a, b):
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		return int(a["stat"]) > int(b["stat"]))
	var headline := ""
	if teams:
		var a0 := int(_score[0])
		var a1 := int(_score[1])
		headline = ("DRAW  %d : %d" % [a0, a1]) if a0 == a1 else ("%s WINS  %d : %d" % [TEAM_NAMES[0] if a0 > a1 else TEAM_NAMES[1], maxi(a0, a1), mini(a0, a1)])
	elif not rows.is_empty():
		headline = "%s WINS" % str(rows[0]["name"])
	for i in rows.size():
		rows[i]["pos"] = i + 1
	if not rows.is_empty():
		rows[0]["headline"] = headline
	_broadcast()
	_level.end_arena(rows)


# ======================================================================================
#  Bots
# ======================================================================================

func _drive_bots(delta: float) -> void:
	for cart in _carts():
		if not cart.get("is_ai"):
			continue
		var id := str(cart.name).to_int()
		if kind == "football":
			_football_bot(cart, id)
		else:
			_ctf_bot(cart, id, delta)


func _football_bot(cart: Node3D, id: int) -> void:
	var s := side_of(id)
	var me := cart.global_position
	var bi := -1
	var bd := INF
	for i in _balls.size():
		if bool(_ball_active[i]):
			var d: float = (_balls[i] as Node3D).global_position.distance_to(me)
			if d < bd:
				bd = d
				bi = i
	if bi < 0:
		cart.set("arena_target", _ball_spawn + (me - _ball_spawn).normalized() * 18.0)
		cart.set("arena_arrive", true)
		return
	var ball: Vector3 = (_balls[bi] as Node3D).global_position
	# The goal it guards (its own nearest the ball) and the one it shoots at (the other side's nearest the ball).
	var own_g := -1
	var tgt_g := -1
	var own_d := INF
	var tgt_d := INF
	for g in _goals.size():
		var gp: Vector3 = (_goals[g] as Node3D).global_position
		var d := gp.distance_to(ball)
		if int(_goal_owner[g]) == s:
			if d < own_d:
				own_d = d
				own_g = g
		elif d < tgt_d:
			tgt_d = d
			tgt_g = g
	# Teams: the side's nearest cart to the ball attacks; the rest hold a goal of theirs nearest the ball.
	var attacker := true
	if teams:
		var mine := me.distance_to(ball)
		for o in _carts():
			if o != cart and side_of(str(o.name).to_int()) == s and o.global_position.distance_to(ball) < mine - 2.0:
				attacker = false
				break
	var defend := own_g >= 0 and own_d < 30.0 and (not attacker or (not teams and own_d < 22.0))
	if not attacker and not defend:
		defend = own_g >= 0
	if defend and bd > 9.0:
		var mouth: Vector3 = (_goals[own_g] as Node3D).global_position
		var keep := mouth + (ball - mouth).normalized() * minf(7.0, own_d * 0.5)
		cart.set("arena_target", keep)
		cart.set("arena_arrive", true)
		return
	# Attack: come in behind the ball on the line to the goal, then drive through it.
	var goal_at: Vector3 = (_goals[tgt_g] as Node3D).global_position if tgt_g >= 0 else _ball_spawn
	if defend:
		goal_at = ball + (ball - (_goals[own_g] as Node3D).global_position).normalized() * 20.0
	var dir := goal_at - ball
	dir.y = 0.0
	dir = dir.normalized()
	var behind := ball - dir * 3.4
	var to_me := me - ball
	to_me.y = 0.0
	var ahead := to_me.dot(dir)
	var target: Vector3
	if ahead > -1.0:
		# On the wrong side: round the ball.
		var side_v := Vector3(-dir.z, 0, dir.x)
		if to_me.dot(side_v) < 0.0:
			side_v = -side_v
		target = ball - dir * 3.0 + side_v * 5.0
	elif me.distance_to(behind) < 4.5 or (ahead < -2.0 and absf(to_me.normalized().dot(-dir)) > 0.92):
		target = ball + dir * 6.0
	else:
		target = behind
	cart.set("arena_target", target)
	cart.set("arena_arrive", false)


func _ctf_bot(cart: Node3D, id: int, _delta: float) -> void:
	var s := side_of(id)
	var me := cart.global_position
	var goal := _flag_pos
	if _flag_state == Flag.CARRIED and _carrier == id:
		goal = _best_base(me, s)
	elif _flag_state == Flag.CARRIED:
		var c := _cart(_carrier)
		if c != null:
			if teams and side_of(_carrier) == s:
				# Escort: run alongside the carrier, a little ahead.
				var v: Vector3 = c.linear_velocity
				goal = c.global_position + v * 0.6 + Vector3(v.z, 0, -v.x).normalized() * 6.0 * (1.0 if id % 2 == 0 else -1.0)
			else:
				goal = c.global_position + (c.linear_velocity as Vector3) * 0.35
	elif _flag_state == Flag.RESPAWNING:
		goal = _flag_home
	cart.set("arena_target", _nav_step(id, me, goal))
	cart.set("arena_arrive", false)


func _best_base(from: Vector3, s: int) -> Vector3:
	var best := _flag_home
	var bd := INF
	for bi in _bases.size():
		if int(_base_owner[bi]) == s:
			continue
		var p: Vector3 = (_bases[bi] as Node3D).global_position
		# Taking a base from a rival is worth a little extra (it stops their points).
		var d := from.distance_to(p) * (0.8 if int(_base_owner[bi]) >= 0 else 1.0)
		if d < bd:
			bd = d
			best = p
	return best


func _build_nav() -> void:
	_nav_pts = get_meta(&"nav_points", PackedVector3Array())
	var links: PackedInt32Array = get_meta(&"nav_links", PackedInt32Array())
	if _nav_pts.is_empty():
		return
	_astar = AStar3D.new()
	for i in _nav_pts.size():
		_astar.add_point(i, _nav_pts[i])
	var k := 0
	while k + 2 < links.size():
		_astar.connect_points(links[k], links[k + 1], links[k + 2] == 0)
		k += 3


func _nearest_nav(p: Vector3) -> int:
	var best := -1
	var bd := INF
	for i in _nav_pts.size():
		var q: Vector3 = _nav_pts[i]
		# Height counts three times over: the node on your level, not the one on the cliff above.
		var d := Vector2(q.x - p.x, q.z - p.z).length() + absf(q.y - p.y) * 3.0
		if d < bd:
			bd = d
			best = i
	return best


## Where a bot drives next on its way to `goal`: straight there when it's near and on the same level, else the next
## point of its path on the graph (planned again every second or when the goal moves on).
func _nav_step(id: int, me: Vector3, goal: Vector3) -> Vector3:
	if _astar == null:
		return goal
	var flat := Vector2(goal.x - me.x, goal.z - me.z).length()
	if flat < 32.0 and absf(goal.y - me.y) < 3.5:
		return goal
	var st: Dictionary = _bot_nav.get(id, {})
	var now := Time.get_ticks_msec() * 0.001
	if st.is_empty() or now > float(st["t"]) or (st["goal"] as Vector3).distance_to(goal) > 20.0:
		var a := _nearest_nav(me)
		var b := _nearest_nav(goal)
		var path := _astar.get_point_path(a, b) if a >= 0 and b >= 0 else PackedVector3Array()
		st = {"t": now + 1.0, "goal": goal, "path": path, "i": 0}
		_bot_nav[id] = st
	var path: PackedVector3Array = st["path"]
	var i: int = st["i"]
	while i < path.size() and Vector2(path[i].x - me.x, path[i].z - me.z).length() < 9.0:
		i += 1
	# Skip ahead to a later point on its level that is near enough to drive straight at.
	if i < path.size() - 1 and Vector2(path[i + 1].x - me.x, path[i + 1].z - me.z).length() < 26.0 and absf(path[i + 1].y - me.y) < 2.5:
		i += 1
	st["i"] = i
	if i >= path.size():
		return goal
	return path[i]


# ======================================================================================
#  What every peer draws
# ======================================================================================

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _level == null:
		return
	_resp_t -= delta
	if _resp_t <= 0.0:
		_resp_t = 0.5
		_update_respawns()
		_apply_sides()
	if kind == "ctf":
		_update_flag_vis(delta)
		_update_base_vis()
	else:
		_update_ball_fx(delta)
	_update_pips()
	_update_arrows()
	_update_huds()


## Where each cart comes back after a fall or a blast: in football its own spot by its goal; in capture the flag the
## graph's point nearest where it is, facing the middle.
func _update_respawns() -> void:
	var sps: Array = _level.spawn_points
	for cart in _carts():
		var id := str(cart.name).to_int()
		if cart.get("is_teleporting"):
			continue
		var xf: Transform3D
		if kind == "ctf" and not _nav_pts.is_empty():
			var n := _nearest_nav(cart.global_position)
			var p: Vector3 = _nav_pts[n] + Vector3(0, 1.0, 0)
			var look := Vector3(_flag_home.x, p.y, _flag_home.z)
			if look.distance_to(p) < 1.0:
				look = p + Vector3(0, 0, -1)
			xf = Transform3D(Basis.looking_at(look - p, Vector3.UP), p)
		elif _spawn_of.has(id) and not sps.is_empty():
			xf = (sps[int(_spawn_of[id]) % sps.size()] as Node3D).global_transform
			xf.origin += Vector3(0, 1.0, 0)
		else:
			continue
		cart.set("last_checkpoint_transform", xf)


# ---- The flag ----------------------------------------------------------------------------------------------------

func _build_flag() -> void:
	_flag_node = Node3D.new()
	_flag_node.name = "Flag"
	add_child(_flag_node)
	_flag_node.top_level = true
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.07
	pm.bottom_radius = 0.09
	pm.height = 4.2
	pole.mesh = pm
	pole.position = Vector3(0, 2.1, 0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.85, 0.86, 0.9)
	pmat.metallic = 0.8
	pmat.roughness = 0.3
	pole.material_override = pmat
	_flag_node.add_child(pole)
	var knob := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.18
	km.height = 0.36
	knob.mesh = km
	knob.position = Vector3(0, 4.3, 0)
	knob.material_override = pmat
	_flag_node.add_child(knob)
	_flag_cloth = MeshInstance3D.new()
	var cm := PlaneMesh.new()
	cm.size = Vector2(2.4, 1.5)
	cm.subdivide_width = 16
	cm.subdivide_depth = 8
	cm.orientation = PlaneMesh.FACE_Z
	_flag_cloth.mesh = cm
	_flag_cloth.position = Vector3(1.25, 3.4, 0)
	var sh := Shader.new()
	sh.code = FLAG_SHADER
	var fm := ShaderMaterial.new()
	fm.shader = sh
	_flag_cloth.material_override = fm
	_flag_node.add_child(_flag_cloth)
	_beam = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 1.6
	bm.bottom_radius = 0.9
	bm.height = 140.0
	bm.radial_segments = 16
	bm.cap_top = false
	bm.cap_bottom = false
	_beam.mesh = bm
	_beam.position = Vector3(0, 70.0, 0)
	_beam_mat = _beam_material(Color(1, 1, 1, 0.35))
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flag_node.add_child(_beam)


const FLAG_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 color : source_color = vec3(1.0);
void vertex() {
	float t = (VERTEX.x + 1.2) / 2.4;
	VERTEX.z += sin(TIME * 7.0 - VERTEX.x * 3.0) * 0.22 * t;
	VERTEX.y += sin(TIME * 5.0 - VERTEX.x * 2.0) * 0.05 * t;
}
void fragment() {
	float check = step(0.5, fract(UV.x * 4.0)) == step(0.5, fract(UV.y * 2.5)) ? 1.0 : 0.82;
	ALBEDO = color * check;
	EMISSION = color * 0.35;
	ROUGHNESS = 0.7;
}
"""


func _beam_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = c
	m.disable_receive_shadows = true
	return m


func _update_flag_vis(delta: float) -> void:
	if _flag_node == null:
		return
	var col := NEUTRAL
	var at := _flag_pos
	_flag_node.visible = _flag_state != Flag.RESPAWNING
	if _flag_state == Flag.CARRIED:
		var c := _cart(_carrier)
		if c != null:
			at = c.global_position + Vector3(0, 0.6, 0)
			col = side_color(side_of(_carrier))
	elif _flag_state == Flag.DROPPED:
		col = Color(1.0, 0.9, 0.5)
	_flag_node.global_position = _flag_node.global_position.lerp(at, minf(1.0, delta * 20.0)) if _flag_node.global_position.distance_to(at) < 8.0 else at
	(_flag_cloth.material_override as ShaderMaterial).set_shader_parameter("color", col if _flag_state == Flag.CARRIED else Color(1, 1, 1))
	var pulse := 0.28 + 0.1 * sin(Time.get_ticks_msec() * 0.006)
	_beam_mat.albedo_color = Color(col.r, col.g, col.b, pulse)


# ---- Bases ---------------------------------------------------------------------------------------------------------

func _build_bases() -> void:
	for b in _bases:
		var base: Node3D = b
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = BASE_RADIUS - 0.7
		tm.outer_radius = BASE_RADIUS
		tm.rings = 48
		tm.ring_segments = 8
		ring.mesh = tm
		ring.position = Vector3(0, 0.12, 0)
		ring.scale = Vector3(1, 0.25, 1)
		var rmat := StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.albedo_color = NEUTRAL
		ring.material_override = rmat
		base.add_child(ring)
		var beam := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = BASE_RADIUS * 0.9
		bm.bottom_radius = BASE_RADIUS
		bm.height = 46.0
		bm.radial_segments = 32
		bm.cap_top = false
		bm.cap_bottom = false
		beam.mesh = bm
		beam.position = Vector3(0, 23.0, 0)
		var bmat := _beam_material(Color(NEUTRAL.r, NEUTRAL.g, NEUTRAL.b, 0.07))
		beam.material_override = bmat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		base.add_child(beam)
		var lab := Label3D.new()
		lab.text = str(base.get_meta(&"letter", "?"))
		lab.font_size = 256
		lab.pixel_size = 0.018
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.outline_size = 24
		lab.outline_modulate = Color(0, 0, 0, 0.8)
		lab.position = Vector3(0, 11.0, 0)
		lab.no_depth_test = false
		base.add_child(lab)
		_base_vis.append([rmat, bmat, lab])


func _update_base_vis() -> void:
	for bi in _base_vis.size():
		var o := int(_base_owner[bi])
		var c := side_color(o)
		var v: Array = _base_vis[bi]
		(v[0] as StandardMaterial3D).albedo_color = c
		(v[1] as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, 0.14 if o >= 0 else 0.06)
		(v[2] as Label3D).modulate = c.lightened(0.2)


# ---- Goals ---------------------------------------------------------------------------------------------------------

## Each goal's coloured parts (meshes in its "Paint" group, made by the generator) take its owner's colour.
func _build_goal_vis() -> void:
	for g in _goals:
		var mats: Array = []
		for n in (g as Node).find_children("*", "GeometryInstance3D", true, false):
			if (n as Node).is_in_group(&"arena_paint"):
				var m := StandardMaterial3D.new()
				m.albedo_color = Color(1, 1, 1)
				m.emission_enabled = true
				m.emission_energy_multiplier = 0.55
				(n as GeometryInstance3D).material_override = m
				mats.append(m)
		_goal_vis.append(mats)
		# Whose goal it is, over its bar on the pitch side of the glass.
		var lab := Label3D.new()
		lab.font_size = 96
		lab.pixel_size = 0.0155
		lab.outline_size = 18
		lab.outline_modulate = Color(0, 0, 0, 0.9)
		lab.double_sided = false
		lab.position = Vector3(0, float((g as Node).get_meta(&"height", 5.0)) + 1.55, -0.5)
		lab.rotation.y = PI
		(g as Node).add_child(lab)
		_goal_labels.append(lab)
	_paint_goals()


func _paint_goals() -> void:
	for gi in _goal_vis.size():
		var c := side_color(int(_goal_owner[gi]) if not _side.is_empty() or teams else -1)
		if not teams and not _side.values().has(int(_goal_owner[gi])):
			c = NEUTRAL
		for m in _goal_vis[gi]:
			(m as StandardMaterial3D).albedo_color = c
			(m as StandardMaterial3D).emission = c
		if gi < _goal_labels.size():
			var lab: Label3D = _goal_labels[gi]
			lab.text = _side_label(int(_goal_owner[gi])).to_upper() if c != NEUTRAL else ""
			lab.modulate = c.lightened(0.3)


# ---- Pips over the cars, arrows over the local players' ----------------------------------------------------------

func _update_pips() -> void:
	for cart in _carts():
		var id := str(cart.name).to_int()
		var pip: MeshInstance3D = _pips.get(id)
		if pip == null or not is_instance_valid(pip):
			pip = MeshInstance3D.new()
			var pm := SphereMesh.new()
			pm.radius = 0.32
			pm.height = 0.64
			pm.radial_segments = 4
			pm.rings = 2
			pip.mesh = pm
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pip.material_override = m
			pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(pip)
			pip.top_level = true
			_pips[id] = pip
		var s := side_of(id)
		pip.visible = s >= 0 and _running
		(pip.material_override as StandardMaterial3D).albedo_color = side_color(s)
		pip.global_position = cart.global_position + Vector3(0, 2.3 + 0.12 * sin(Time.get_ticks_msec() * 0.004 + id), 0)
		pip.rotation.y = Time.get_ticks_msec() * 0.002
	for id in _pips.keys():
		if _cart(id) == null:
			(_pips[id] as Node).queue_free()
			_pips.erase(id)


func _arrow_target(cart: Node3D) -> Array:
	var id := str(cart.name).to_int()
	if kind != "ctf" or _flag_state == Flag.RESPAWNING:
		return []
	if _flag_state == Flag.CARRIED:
		if _carrier == id:
			return [_best_base(cart.global_position, side_of(id)), Color(1, 1, 1)]
		var c := _cart(_carrier)
		if c != null:
			return [c.global_position, side_color(side_of(_carrier))]
	return [_flag_pos, Color(1.0, 0.95, 0.6)]


func _update_arrows() -> void:
	for cart in _carts():
		if cart.get("is_local_player") != true:
			continue
		var id := str(cart.name).to_int()
		var arrow: MeshInstance3D = _arrows.get(id)
		if arrow == null or not is_instance_valid(arrow):
			arrow = MeshInstance3D.new()
			arrow.mesh = _arrow_mesh()
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.no_depth_test = true
			m.render_priority = 10
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			arrow.material_override = m
			arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(arrow)
			arrow.top_level = true
			_arrows[id] = arrow
		var t := _arrow_target(cart)
		var at: Vector3 = cart.global_position + Vector3(0, 3.4, 0)
		if t.is_empty() or not _running or (t[0] as Vector3).distance_to(cart.global_position) < 6.0:
			arrow.visible = false
			continue
		arrow.visible = true
		var to: Vector3 = (t[0] as Vector3) - at
		var flat := Vector3(to.x, 0, to.z)
		var pitch := clampf(atan2(to.y, maxf(flat.length(), 0.1)), -0.6, 0.6)
		arrow.global_transform = Transform3D(Basis.looking_at(flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD, Vector3.UP).rotated(Basis.looking_at(flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD, Vector3.UP).x, pitch), at)
		var c: Color = t[1]
		(arrow.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, 0.92)


## A chunky arrow pointing along -z, 2.4m long, a little thickness so it reads from the side too.
static func _arrow_mesh() -> ArrayMesh:
	var outline := PackedVector2Array([Vector2(0, -1.3), Vector2(0.95, -0.15), Vector2(0.38, -0.15), Vector2(0.38, 1.1),
		Vector2(-0.38, 1.1), Vector2(-0.38, -0.15), Vector2(-0.95, -0.15)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var th := 0.14
	var tris := Geometry2D.triangulate_polygon(outline)
	for top in [true, false]:
		var y := th if top else -th
		for k in range(0, tris.size(), 3):
			var idx: Array = [tris[k], tris[k + 1], tris[k + 2]] if top else [tris[k], tris[k + 2], tris[k + 1]]
			for j in idx:
				st.add_vertex(Vector3(outline[j].x, y, outline[j].y))
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var v := [Vector3(a.x, th, a.y), Vector3(b.x, th, b.y), Vector3(b.x, -th, b.y), Vector3(a.x, -th, a.y)]
		for j in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(v[j])
	return st.commit()


# ---- HUD -----------------------------------------------------------------------------------------------------------

func _setup_hud() -> void:
	if _level == null or not _level.has_method("_all_race_uis"):
		return
	for ui in _level._all_race_uis():
		var hud: Control = ui.get_node_or_null("HUDPanel")
		if hud == null:
			continue
		for n in ["PositionContainer", "LabelLap"]:
			var c = hud.get_node_or_null(n)
			if c:
				c.visible = false
		var sp = ui.get("standings_panel")
		if sp:
			sp.visible = false
		# The race messages (GO!, a goal, a claim) under the scoreboard.
		if ui.has_method("_shift_message"):
			ui._shift_message(96.0)
		var root := Control.new()
		root.name = "ArenaHUD"
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		hud.add_child(root)
		var top := PanelContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.set_anchors_preset(Control.PRESET_CENTER_TOP)
		top.position = Vector2(-150, 12)
		top.custom_minimum_size = Vector2(300, 0)
		top.grow_horizontal = Control.GROW_DIRECTION_BOTH
		top.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.05, 0.07, 0.7)))
		root.add_child(top)
		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 2)
		top.add_child(vb)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		vb.add_child(row)
		var l_score := _hud_label("0", 34, TEAM_COLORS[0])
		var clock := _hud_label("5:00", 30, Color(1, 1, 1))
		var r_score := _hud_label("0", 34, TEAM_COLORS[1])
		row.add_child(l_score)
		row.add_child(clock)
		row.add_child(r_score)
		var sub := _hud_label("", 15, Color(0.85, 0.88, 0.92))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(sub)
		var bases_row := HBoxContainer.new()
		bases_row.alignment = BoxContainer.ALIGNMENT_CENTER
		bases_row.add_theme_constant_override("separation", 6)
		vb.add_child(bases_row)
		var base_labels: Array = []
		for b in _bases:
			var bl := _hud_label(str((b as Node).get_meta(&"letter", "?")), 20, NEUTRAL)
			bl.custom_minimum_size = Vector2(28, 0)
			bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bases_row.add_child(bl)
			base_labels.append(bl)
		var board := PanelContainer.new()
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.position = Vector2(16, 126)
		board.custom_minimum_size = Vector2(210, 0)
		board.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.05, 0.07, 0.58)))
		root.add_child(board)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 1)
		board.add_child(list)
		_huds.append({"root": root, "l": l_score, "r": r_score, "clock": clock, "sub": sub, "bases": base_labels, "list": list,
			"board": board, "sig": ""})


func _panel_style(bg: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = Color(1, 1, 1, 0.18)
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	return st


func _hud_label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.modulate = col
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _update_huds() -> void:
	var secs := int(ceil(_time_left)) if _running or _ended else int(match_seconds)
	var clock_text := "%d:%02d" % [secs / 60, secs % 60]
	var status := ""
	if kind == "ctf":
		match _flag_state:
			Flag.HOME:
				status = "The flag is in the middle"
			Flag.CARRIED:
				status = "%s has the flag" % _name_of(_carrier)
			Flag.DROPPED:
				status = "The flag is down (%ds)" % int(ceil(_flag_timer))
			Flag.RESPAWNING:
				status = "New flag in the middle..."
	elif _balls.size() > 1 and bool(_ball_active[1]):
		status = "MULTIBALL"
	for h in _huds:
		(h["clock"] as Label).text = clock_text
		(h["clock"] as Label).modulate = Color(1, 0.4, 0.35) if _running and _time_left < 30.0 else Color(1, 1, 1)
		(h["sub"] as Label).text = status
		(h["l"] as Label).visible = teams
		(h["r"] as Label).visible = teams
		if teams:
			(h["l"] as Label).text = str(_score[0]) if _score.size() > 0 else "0"
			(h["r"] as Label).text = str(_score[1]) if _score.size() > 1 else "0"
		var bl: Array = h["bases"]
		for i in mini(bl.size(), _base_owner.size()):
			(bl[i] as Label).modulate = side_color(int(_base_owner[i]))
		_fill_board(h)


## The score list: in all-vs-all every player (their colour, their score), in teams each player's goals or claims.
func _fill_board(h: Dictionary) -> void:
	var rows: Array = []
	for id in _side:
		var s := side_of(id)
		rows.append([_name_of(id), int(_score[s]) if not teams and s >= 0 and s < _score.size() else int(_stat.get(id, 0)), side_color(s)])
	rows.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	var sig := str(rows)
	if sig == str(h["sig"]):
		return
	h["sig"] = sig
	var list: VBoxContainer = h["list"]
	for c in list.get_children():
		c.queue_free()
	var head := _hud_label("SCORE" if not teams else ("GOALS" if kind == "football" else "CLAIMS"), 13, Color(0.7, 0.75, 0.8))
	list.add_child(head)
	for r in rows:
		var hb := HBoxContainer.new()
		var dot := _hud_label("■", 15, r[2])
		var nm := _hud_label(str(r[0]), 15, Color(1, 1, 1))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		var sc := _hud_label(str(r[1]), 15, Color(1, 1, 1))
		hb.add_child(dot)
		hb.add_child(nm)
		hb.add_child(sc)
		list.add_child(hb)
	(h["board"] as Control).visible = not rows.is_empty()


# ---- Minimap -------------------------------------------------------------------------------------------------------

func minimap_outline() -> Array:
	return get_meta(&"outline", [])


func minimap_draw(ctrl: Control, t: float, top: bool) -> void:
	if not top:
		for gi in _goals.size():
			var g: Node3D = _goals[gi]
			var hw: float = g.get_meta(&"half_width", 6.0)
			var a: Vector2 = ctrl.to_map(g.global_transform * Vector3(-hw, 0, 0))
			var b: Vector2 = ctrl.to_map(g.global_transform * Vector3(hw, 0, 0))
			ctrl.draw_line(a, b, side_color(int(_goal_owner[gi])), 4.0, true)
		var font := ctrl.get_theme_default_font()
		for bi in _bases.size():
			var p: Vector2 = ctrl.to_map((_bases[bi] as Node3D).global_position)
			var c := side_color(int(_base_owner[bi]))
			ctrl.draw_circle(p, 7.5, Color(c.r, c.g, c.b, 0.85))
			ctrl.draw_arc(p, 7.5, 0.0, TAU, 20, Color(0, 0, 0, 0.8), 1.2, true)
			if font:
				ctrl.draw_string(font, p + Vector2(-4.0, 4.5), str((_bases[bi] as Node).get_meta(&"letter", "?")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.05, 0.05, 0.08))
		return
	for i in _balls.size():
		if bool(_ball_active[i]):
			var p: Vector2 = ctrl.to_map((_balls[i] as Node3D).global_position)
			ctrl.draw_circle(p, 4.5, Color(1, 1, 1))
			ctrl.draw_arc(p, 4.5, 0.0, TAU, 16, Color(0.4, 1.0, 0.2), 1.5, true)
	if kind == "ctf" and _flag_state != Flag.RESPAWNING:
		var at := _flag_pos
		var col := Color(1.0, 0.95, 0.6)
		if _flag_state == Flag.CARRIED and _cart(_carrier) != null:
			at = _cart(_carrier).global_position
			col = side_color(side_of(_carrier))
		var p: Vector2 = ctrl.to_map(at)
		var pulse := 9.0 + 3.0 * sin(t * 6.0)
		ctrl.draw_arc(p, pulse, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.9), 2.5, true)
		ctrl.draw_line(p + Vector2(0, 6), p + Vector2(0, -9), Color(1, 1, 1), 1.6, true)
		ctrl.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(8, -6), p + Vector2(0, -3)]), col)
