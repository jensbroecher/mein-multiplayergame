extends Node
## The race commentator. Level feeds it the standings rows it already gets on every peer
## (`update`), and it speaks calls with the racers' names through the OS text-to-speech
## (`DisplayServer.tts_speak`): who has taken the lead, who leads onto the final lap, and who
## wins and takes second and third. It works only from the standings, so it needs no networking
## of its own: each peer says what it sees. The prerecorded `voice/lola` clips stay the
## announcer for the player's own gates; this is the one that knows names.

## Emitted with every call, whether or not it was spoken (tests listen to it).
signal said(text: String)

## A new leader must hold the front this long before it's called (a quick swap back is no news).
const LEAD_HOLD := 1.2
## Lead calls are at least this far apart, so a close fight doesn't turn into chatter.
const LEAD_COOLDOWN := 7.0
## The grid shuffles in the first seconds, so the lead is tracked silently until then.
const START_GRACE := 5.0
## When the opening call is made after GO (after the "go" clip is done).
const OPENING_DELAY := 2.6
## Finish calls wait for the announcer's finish and place clips to be done.
const FINISH_DELAY := 3.0
const FINAL_LAP_DELAY := 2.0
## A little quicker than a normal read, for an excited call.
const SPEECH_RATE := 1.12
const MAX_NAME_LENGTH := 20

const LEAD_LINES: PackedStringArray = [
	"%s has taken the lead!",
	"%s moves into the lead!",
	"%s is now in front!",
	"And it's %s out in front!",
]
const PASS_LINES: PackedStringArray = [
	"%s passes %s for the lead!",
	"%s goes by %s and takes the lead!",
]
const WIN_LINES: PackedStringArray = [
	"%s wins the race!",
	"%s takes the win!",
	"It's %s who takes the chequered flag!",
]
const PLACE_LINES: PackedStringArray = [
	"",
	"%s takes second place.",
	"%s completes the podium in third.",
]
const EXPLOSION_LINES: PackedStringArray = [
	"%s takes out %s!",
	"%s blows up %s!",
	"%s blasts %s off the track!",
	"%s sends %s spinning!",
	"Direct hit by %s on %s!",
]
const MISSILE_LINES: PackedStringArray = [
	"%s hits %s with a missile!",
	"%s blasts %s with a rocket!",
	"%s fires a missile right into %s!",
	"Direct missile hit by %s on %s!",
	"%s snipes %s with a missile!",
]
const GUIDED_MISSILE_LINES: PackedStringArray = [
	"%s locks on and hits %s with a guided missile!",
	"%s's guided missile hunts down %s!",
	"%s takes out %s with a homing missile!",
	"No escape! %s hits %s with a guided missile!",
]
const BOMB_LINES: PackedStringArray = [
	"%s blows up %s with a bomb!",
	"%s detonates %s with a bomb!",
	"%s drops a bomb right on %s!",
	"%s wipes out %s with an explosive bomb!",
]
const LIGHTNING_LINES: PackedStringArray = [
	"%s zaps %s with lightning!",
	"%s shocks %s with a lightning bolt!",
	"%s strikes %s with lightning!",
	"%s fries %s with an electric arc!",
]
const LIGHTNING_MULTI_LINES: PackedStringArray = [
	"%s zaps the whole pack with lightning!",
	"%s strikes multiple racers with lightning!",
	"%s unleashes lightning across the track!",
]
const SELF_EXPLOSION_LINES: PackedStringArray = [
	"%s blew themselves up!",
	"Oh no, %s caught their own blast!",
	"%s just took themselves out!",
]
const SELF_BOMB_LINES: PackedStringArray = [
	"%s got caught in their own bomb!",
	"%s blew themselves up with a bomb!",
	"Ouch! %s detonated their own bomb!",
]
const SELF_MISSILE_LINES: PackedStringArray = [
	"%s caught their own missile blast!",
	"%s took themselves out with a rocket!",
]
const EXPLOSION_COOLDOWN := 2.5

var _active := false
var _clock := 0.0
var _since_go := 0.0
var _opened := false
var _leader_id := -1
var _leader_name := ""
var _candidate_id := -1
var _candidate_since := 0.0
var _last_lead_call := -1000.0
var _final_lap_called := false
var _finish_called: Dictionary = {}
## Calls waiting out their delay: {"at": clock time, "text": String}.
var _pending: Array = []
var _last_speak_time := -1000.0
var _last_explosion_call := -1000.0

static var _cached_voice_id: String = ""
static var _voice_search_done: bool = false
static var _has_tts_cached: bool = false
static var _has_tts_checked: bool = false


func _ready() -> void:
	add_to_group(&"race_commentator")


## The race went green: the grid is settled, so start watching the lead.
func begin() -> void:
	_active = true
	_since_go = 0.0


func _process(delta: float) -> void:
	_clock += delta
	if _active:
		_since_go += delta
	while not _pending.is_empty() and float(_pending[0]["at"]) <= _clock:
		_say(str(_pending.pop_front()["text"]))


func _exit_tree() -> void:
	if _has_tts():
		DisplayServer.tts_stop()


## Level's standings rows ({id, pos, name, finished, lap}, best first), every frame.
func update(rows: Array, max_laps: int) -> void:
	if not _active or rows.is_empty():
		return
	var top: Dictionary = rows[0]
	var any_finished := false
	for row in rows:
		if row["finished"]:
			any_finished = true
	_call_finishers(rows)
	if any_finished:
		return
	if _leader_id == -1 or _since_go < START_GRACE:
		# Silent: the lead is whoever is in front while the field gets going.
		_leader_id = int(top["id"])
		_leader_name = _clean_name(str(top["name"]))
		_candidate_id = -1
		if not _opened and _since_go >= OPENING_DELAY:
			_opened = true
			_queue("And they're off! %s leads the field away." % _leader_name, 0.0)
		return
	_track_lead(top)
	if not _final_lap_called and max_laps > 1 and int(top["lap"]) >= max_laps:
		_final_lap_called = true
		# The final-lap clip is the announcer's; this follows it.
		_last_lead_call = _clock
		_queue("%s leads onto the final lap!" % _clean_name(str(top["name"])), FINAL_LAP_DELAY)


func _track_lead(top: Dictionary) -> void:
	var id := int(top["id"])
	if id == _leader_id:
		_candidate_id = -1
		return
	if id != _candidate_id:
		_candidate_id = id
		_candidate_since = _clock
		return
	if _clock - _candidate_since < LEAD_HOLD or _clock - _last_lead_call < LEAD_COOLDOWN:
		return
	if _is_speaking():
		return
	var previous := _leader_name
	_leader_id = id
	_leader_name = _clean_name(str(top["name"]))
	_candidate_id = -1
	_last_lead_call = _clock
	if previous != "" and previous != _leader_name and randi() % 3 == 0:
		_queue(PASS_LINES[randi() % PASS_LINES.size()] % [_leader_name, previous], 0.0)
	else:
		_queue(LEAD_LINES[randi() % LEAD_LINES.size()] % _leader_name, 0.0)


## The first three across the line get a call by name.
func _call_finishers(rows: Array) -> void:
	for row in rows:
		if not row["finished"]:
			continue
		var id := int(row["id"])
		if _finish_called.has(id):
			continue
		_finish_called[id] = true
		var place := int(row["pos"])
		if place < 1 or place > 3:
			continue
		var racer := _clean_name(str(row["name"]))
		if place == 1:
			_queue(WIN_LINES[randi() % WIN_LINES.size()] % racer, FINISH_DELAY)
		else:
			_queue(PLACE_LINES[place - 1] % racer, FINISH_DELAY)


## Called when a cart explodes or gets hit. Announces the combat event with item details.
func call_explosion(attacker_name: String, victim_name: String, weapon: String = "") -> void:
	if not _active:
		return
	if _clock - _last_explosion_call < EXPLOSION_COOLDOWN:
		return
	if _is_speaking():
		return
	var a := _clean_name(attacker_name)
	var v := _clean_name(victim_name)
	var w := weapon.to_upper().strip_edges()
	var text := ""
	var is_self := (a == "" or a == "Someone" or a == v)

	if is_self:
		if w == "BOMB":
			text = SELF_BOMB_LINES[randi() % SELF_BOMB_LINES.size()] % v
		elif w in ["MISSILE", "GUIDED_MISSILE"]:
			text = SELF_MISSILE_LINES[randi() % SELF_MISSILE_LINES.size()] % v
		else:
			text = SELF_EXPLOSION_LINES[randi() % SELF_EXPLOSION_LINES.size()] % v
	else:
		if w == "GUIDED_MISSILE":
			text = GUIDED_MISSILE_LINES[randi() % GUIDED_MISSILE_LINES.size()] % [a, v]
		elif w == "MISSILE":
			text = MISSILE_LINES[randi() % MISSILE_LINES.size()] % [a, v]
		elif w == "BOMB":
			text = BOMB_LINES[randi() % BOMB_LINES.size()] % [a, v]
		elif w == "LIGHTNING":
			text = LIGHTNING_LINES[randi() % LIGHTNING_LINES.size()] % [a, v]
		else:
			text = EXPLOSION_LINES[randi() % EXPLOSION_LINES.size()] % [a, v]

	_last_explosion_call = _clock
	_queue(text, 0.2)


func call_lightning(attacker_name: String, victim_name: String) -> void:
	call_explosion(attacker_name, victim_name, "LIGHTNING")


func call_lightning_multi(attacker_name: String, victim_names: Array) -> void:
	if not _active:
		return
	if _clock - _last_explosion_call < EXPLOSION_COOLDOWN:
		return
	if _is_speaking():
		return
	var a := _clean_name(attacker_name)
	var text := ""
	if victim_names.size() > 1:
		text = LIGHTNING_MULTI_LINES[randi() % LIGHTNING_MULTI_LINES.size()] % a
	elif victim_names.size() == 1:
		text = LIGHTNING_LINES[randi() % LIGHTNING_LINES.size()] % [a, _clean_name(str(victim_names[0]))]
	else:
		return
	_last_explosion_call = _clock
	_queue(text, 0.2)


## A name fit to be spoken: letters, digits and spaces ("Player_1" reads as "Player 1"), no
## emoji or symbols the voice would spell out, and not too long.
func _clean_name(raw: String) -> String:
	var out := ""
	for ch in raw.replace("_", " ").replace("-", " "):
		var code := ch.unicode_at(0)
		var is_letter := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) \
				or (code >= 97 and code <= 122) or (code >= 0xC0 and code <= 0x24F)
		if is_letter or ch == " " or ch == "'" or ch == ".":
			out += ch
	out = out.strip_edges().left(MAX_NAME_LENGTH).strip_edges()
	return out if out != "" else "Racer"


func _queue(text: String, delay: float) -> void:
	if delay <= 0.0:
		_say(text)
	else:
		_pending.append({"at": _clock + delay, "text": text})


## Pre-warms the OS text-to-speech engine and caches the best voice ID on a background
## thread so that speaking during a race causes zero main-thread lag or frame drops.
static func warm_up() -> void:
	if _voice_search_done:
		return
	if not _has_tts():
		_voice_search_done = true
		return
	WorkerThreadPool.add_task(func():
		var voice := _find_best_voice()
		_cached_voice_id = voice
		_voice_search_done = true
		if voice != "":
			DisplayServer.tts_speak(" ", voice, 0, 1.0, 1.0, 0, false)
			DisplayServer.tts_stop()
	)


func _say(text: String) -> void:
	said.emit(text)
	if not MusicManager.commentary_enabled or not _has_tts():
		return
	var voice := _pick_voice()
	if voice == "":
		return
	var volume := int(clampf(MusicManager.commentary_volume, 0.0, 1.0) * 100.0)
	_last_speak_time = _clock
	WorkerThreadPool.add_task(_speak_thread.bind(text, voice, volume))


static func _speak_thread(text: String, voice: String, volume: int) -> void:
	DisplayServer.tts_speak(text, voice, volume, 1.0, SPEECH_RATE, 0, false)


static func _has_tts() -> bool:
	if not _has_tts_checked:
		_has_tts_cached = DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)
		_has_tts_checked = true
	return _has_tts_cached


func _is_speaking() -> bool:
	if not _has_tts():
		return false
	if _clock - _last_speak_time < 0.4:
		return true
	return DisplayServer.tts_is_speaking()


## Returns the cached English voice for the calls, or searches for it if not already cached.
static func _pick_voice() -> String:
	if _voice_search_done:
		return _cached_voice_id
	_cached_voice_id = _find_best_voice()
	_voice_search_done = true
	return _cached_voice_id


## An English voice for the calls, the best-sounding one the OS has. The calls are English, so a
## voice for another language would mispronounce them; one is still used if there's no English.
static func _find_best_voice() -> String:
	if not _has_tts():
		return ""
	var best_score := -1000
	var chosen_id := ""
	for id in DisplayServer.tts_get_voices_for_language("en"):
		var lower: String = id.to_lower()
		var score := 0
		if lower.contains("premium") or lower.contains("enhanced"):
			score += 3
		if lower.contains("en-us") or lower.contains("en_us") or lower.contains("en-gb"):
			score += 1
		# macOS's novelty and Eloquence voices (Bells, Zarvox, Grandma...) are no commentators.
		if lower.contains("eloquence") or lower.contains("speech.synthesis"):
			score -= 5
		if score > best_score:
			best_score = score
			chosen_id = id
	if chosen_id == "":
		var voices := DisplayServer.tts_get_voices()
		if not voices.is_empty():
			chosen_id = str(voices[0]["id"])
	return chosen_id
