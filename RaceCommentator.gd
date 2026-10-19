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
var _voice_id := ""
var _voice_searched := false


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


func _say(text: String) -> void:
	said.emit(text)
	if not MusicManager.commentary_enabled or not _has_tts():
		return
	var voice := _pick_voice()
	if voice == "":
		return
	var volume := int(clampf(MusicManager.commentary_volume, 0.0, 1.0) * 100.0)
	DisplayServer.tts_speak(text, voice, volume, 1.0, SPEECH_RATE, 0, false)


func _has_tts() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)


func _is_speaking() -> bool:
	return _has_tts() and DisplayServer.tts_is_speaking()


## An English voice for the calls, the best-sounding one the OS has. The calls are English, so a
## voice for another language would mispronounce them; one is still used if there's no English.
func _pick_voice() -> String:
	if _voice_searched:
		return _voice_id
	_voice_searched = true
	var best_score := -1000
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
			_voice_id = id
	if _voice_id == "":
		var voices := DisplayServer.tts_get_voices()
		if not voices.is_empty():
			_voice_id = str(voices[0]["id"])
	return _voice_id
