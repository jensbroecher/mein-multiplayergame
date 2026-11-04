extends RefCounted
## The player's time trial records (user://time_trial_records.cfg), shown on the garage's record boards
## (Garage.gd, the Hall of Fame) and against which the HUD's lap timer shows its splits (RaceUI.gd). Level.gd
## records them for the human in a time trial: a lap when it is clean (no gate missed), a run when it finished
## with every lap clean.
##
## Per stage (the section is the level's file name without extension, as in Level.LAP_RECORDS_PATH):
## run_ms, run_laps, run_laps_ms (each lap of the best run), run_car, run_date; lap_ms, lap_splits (the time at
## each gate of the best lap, from its start; the last is the lap), lap_car, lap_date; runs (finished runs).

const FILE := "user://time_trial_records.cfg"


static func key_of(scene_path: String) -> String:
	return scene_path.get_file().get_basename()


## A stage's records: {run_ms, run_laps, run_laps_ms, run_car, run_date, lap_ms, lap_splits, lap_car, lap_date,
## runs}; run_ms and lap_ms are 0 when none is set.
static func stage(key: String) -> Dictionary:
	var config := ConfigFile.new()
	config.load(FILE)
	return _read(config, key)


static func _read(config: ConfigFile, key: String) -> Dictionary:
	return {
		"run_ms": int(config.get_value(key, "run_ms", 0)),
		"run_laps": int(config.get_value(key, "run_laps", 0)),
		"run_laps_ms": Array(config.get_value(key, "run_laps_ms", [])),
		"run_car": str(config.get_value(key, "run_car", "")),
		"run_date": str(config.get_value(key, "run_date", "")),
		"lap_ms": int(config.get_value(key, "lap_ms", 0)),
		"lap_splits": Array(config.get_value(key, "lap_splits", [])),
		"lap_car": str(config.get_value(key, "lap_car", "")),
		"lap_date": str(config.get_value(key, "lap_date", "")),
		"runs": int(config.get_value(key, "runs", 0)),
	}


## A clean lap: saved if it beats the stage's best. Returns the best before it (0 for none).
static func submit_lap(key: String, lap_ms: int, splits: Array, car: String) -> int:
	var config := ConfigFile.new()
	config.load(FILE)
	var best := int(config.get_value(key, "lap_ms", 0))
	if lap_ms <= 0 or (best > 0 and lap_ms >= best):
		return best
	config.set_value(key, "lap_ms", lap_ms)
	config.set_value(key, "lap_splits", splits.duplicate())
	config.set_value(key, "lap_car", car)
	config.set_value(key, "lap_date", Time.get_date_string_from_system())
	config.save(FILE)
	return best


## A finished run (counted whether or not it was clean); saved as the best run if it was clean and beats the
## best (one of another number of laps, should the race's laps ever change, is simply replaced). Returns the
## best before it (0 for none or not comparable).
static func submit_run(key: String, lap_times: Array, total_ms: int, car: String, clean: bool) -> int:
	var config := ConfigFile.new()
	config.load(FILE)
	config.set_value(key, "runs", int(config.get_value(key, "runs", 0)) + 1)
	var best := int(config.get_value(key, "run_ms", 0))
	var best_laps := int(config.get_value(key, "run_laps", 0))
	var comparable: bool = best > 0 and best_laps == lap_times.size()
	if clean and total_ms > 0 and (not comparable or total_ms < best):
		config.set_value(key, "run_ms", total_ms)
		config.set_value(key, "run_laps", lap_times.size())
		config.set_value(key, "run_laps_ms", lap_times.duplicate())
		config.set_value(key, "run_car", car)
		config.set_value(key, "run_date", Time.get_date_string_from_system())
	config.save(FILE)
	return best if comparable else 0


## 83456 -> "1:23.456".
static func format_ms(ms: int) -> String:
	if ms <= 0:
		return "--:--.---"
	return "%d:%06.3f" % [int(ms / 60000.0), fmod(ms / 1000.0, 60.0)]


## A difference: -1234 -> "-1.234", 1234 -> "+1.234" (minutes only past one).
static func format_delta(ms: int) -> String:
	var sign_ch := "-" if ms < 0 else "+"
	var a: int = absi(ms)
	if a >= 60000:
		return "%s%d:%06.3f" % [sign_ch, int(a / 60000.0), fmod(a / 1000.0, 60.0)]
	return "%s%.3f" % [sign_ch, a / 1000.0]
