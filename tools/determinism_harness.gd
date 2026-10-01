class_name DeterminismHarness
extends RefCounted
## Determinism harness core (M1 WP11). One case = galaxy size + seed, run four ways:
##   fresh, fresh again, save/load at the midpoint, and replay from seed + the fresh run's log.
## Per-subsystem checksums are recorded every month and diffed against the first run.

const RUNS: Array[String] = ["fresh", "repeat", "save_load", "replay"]
const SCOUTS_PER_EMPIRE := 3
const WEEK := Calendar.HOURS_PER_DAY * 7
const PLAYERS: Array[String] = ["human", "vesskar", "krothi", "thessari"]

var db: DefDatabase
var manifests: Dictionary
var save_dir := "user://determinism"


func _init(content_db: DefDatabase, loaded_manifests: Dictionary) -> void:
	db = content_db
	manifests = loaded_manifests


static func settings_for(size: String) -> MatchSettings:
	var s := MatchSettings.new()
	s.galaxy_size = "core:match_preset/size_" + size
	for i in PLAYERS.size():
		s.add_player(i, "core:species/" + PLAYERS[i], "human" if i == 0 else "ai")
	return s


## Runs one case. Returns {ok: bool, message: String, checksums: Array (per month, run "fresh")}.
func run_case(size: String, seed_value: int, months: int) -> Dictionary:
	var settings := settings_for(size)
	var results := {}
	var fresh_log: Array = []
	for run in RUNS:
		var r := _run(run, settings, seed_value, months, fresh_log)
		results[run] = r["checksums"]
		if run == "fresh":
			fresh_log = r["log"]
	var base: Array = results["fresh"]
	for run in RUNS:
		var other: Array = results[run]
		for m in base.size():
			if m >= other.size():
				return {"ok": false, "message": "%s: stopped after month %d" % [run, other.size()], "checksums": base}
			for part: String in base[m]:
				if base[m][part] != other[m][part]:
					return {"ok": false, "checksums": base,
						"message": "%s seed %d: run '%s' diverges at month %d in '%s'" % [size, seed_value, run, m + 1, part]}
	return {"ok": true, "message": "%s seed %d: %d months x %d runs identical" % [size, seed_value, base.size(), RUNS.size()], "checksums": base}


func _run(run: String, settings: MatchSettings, seed_value: int, months: int, fresh_log: Array) -> Dictionary:
	var errors: Array[String] = []
	var state := GalaxyGenerator.new_match(settings, seed_value, db, errors)
	assert(state != null, ", ".join(errors))
	var checksums := []
	var end_tick := months * Calendar.HOURS_PER_MONTH
	if run == "replay":
		var i := 0
		while true:
			var due: Array[Command] = []
			while i < fresh_log.size() and int(fresh_log[i]["tick"]) <= state.tick:
				due.append(CommandRegistry.from_dict(fresh_log[i]))
				i += 1
			Sim.execute(state, due)
			if state.tick >= end_tick:
				break
			if Sim.advance(state) & Sim.MONTH:
				checksums.append(state.checksum())
		return {"checksums": checksums, "log": []}
	var sched := CommandSchedule.new()
	var driver := DetRng.from_seed(seed_value, "harness")
	var half := months / 2 * Calendar.HOURS_PER_MONTH
	while state.tick < end_tick:
		_drive(state, sched, driver)
		if Sim.step(state, sched.take_due(state.tick)) & Sim.MONTH:
			checksums.append(state.checksum())
		if run == "save_load" and state.tick == half:
			var path := save_dir.path_join("harness.sav")
			var err := SaveGame.write(path, state, sched, db, manifests)
			assert(err == "", err)
			var loaded := SaveGame.read(path, db, manifests)
			assert(loaded.errors.is_empty(), ", ".join(loaded.errors))
			state = loaded.state
			sched = CommandSchedule.new()
			sched.restore(loaded.pending)
	return {"checksums": checksums, "log": state.command_log.duplicate(true)}


## The scripted player input: unpause at the start, speed changes monthly, a pause blip every
## 5 months, and weekly per empire either a new scout (up to 3) or a scout sent somewhere new.
func _drive(state: MatchState, sched: CommandSchedule, driver: DetRng) -> void:
	var t := state.tick
	if t == 0:
		_submit(state, sched, CmdPause.TYPE, state.empires.keys()[0], {"paused": 0})
	if t % Calendar.HOURS_PER_MONTH == 1:
		var speed: int = CmdSetSpeed.SPEEDS[driver.range(0, CmdSetSpeed.SPEEDS.size())]
		_submit(state, sched, CmdSetSpeed.TYPE, state.empires.keys()[0], {"speed": speed})
	if t % (5 * Calendar.HOURS_PER_MONTH) == 2:
		_submit(state, sched, CmdPause.TYPE, state.empires.keys()[0], {"paused": 1})
		_submit(state, sched, CmdPause.TYPE, state.empires.keys()[0], {"paused": 0})
	if t % WEEK != 3:
		return
	var systems: Array = state.galaxy.systems.keys()
	for eid: int in state.empires:
		var mine := []
		for uid: int in state.units:
			if (state.units.get_or(uid) as Unit).owner == eid:
				mine.append(uid)
		if mine.size() < SCOUTS_PER_EMPIRE:
			var capital := state.galaxy.planet((state.empires.get_or(eid) as Empire).capital_planet).system_id
			_submit(state, sched, CmdDebugSpawnScout.TYPE, eid, {"system": capital})
		else:
			var unit: int = mine[driver.range(0, mine.size())]
			_submit(state, sched, CmdMoveUnit.TYPE, eid, {"unit": unit, "to": systems[driver.range(0, systems.size())]})


static func _submit(state: MatchState, sched: CommandSchedule, type_id: StringName, player: int, payload: Dictionary) -> void:
	sched.submit(CommandRegistry.create(type_id, player, payload), state.tick)


## "month part hash" lines for comparing machines.
static func checksum_lines(checksums: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	for m in checksums.size():
		for part: String in IdMap.sort_keys(checksums[m].keys()):
			lines.append("%d %s %08x" % [m + 1, part, checksums[m][part]])
	return lines
