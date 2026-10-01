extends GutTest
# M1 WP6: commands, local lockstep schedule, movement and replay.

## Line of 4 systems plus a shortcut: 1-2 (10), 2-3 (10), 3-4 (10), 1-3 (25). Empire 5 owns nothing.
static func build_line() -> MatchState:
	var s := MatchState.create(MatchSettings.new(), 99)
	for i in 4:
		var sys := StarSystem.new()
		sys.id = s.alloc_id()  # 1..4
		sys.name = "S%d" % sys.id
		sys.star_type = "core:star_type/yellow"
		s.galaxy.systems.put(sys.id, sys)
	for pair: Array in [[1, 2, 10], [2, 3, 10], [3, 4, 10], [1, 3, 25]]:
		var l := Hyperlane.new()
		l.id = s.alloc_id()  # 5..8
		l.a = pair[0]
		l.b = pair[1]
		l.length = pair[2]
		s.galaxy.lanes.put(l.id, l)
		s.galaxy.system(l.a).lane_ids.append(l.id)
		s.galaxy.system(l.b).lane_ids.append(l.id)
	var e := Empire.new()
	e.id = s.alloc_id()  # 9
	e.species = "core:species/human"
	s.empires.put(e.id, e)
	return s


func _cmd(type_id: StringName, player: int, payload: Dictionary) -> Command:
	return CommandRegistry.create(type_id, player, payload)


func _run(s: MatchState, schedule: CommandSchedule, ticks: int) -> void:
	for i in ticks:
		Sim.step(s, schedule.take_due(s.tick))


func test_pathfinder_prefers_shorter_total_length() -> void:
	var g := build_line().galaxy
	assert_eq(Pathfinder.route(g, 1, 3), [2, 3] as Array[int], "20 via 2 beats 25 direct")
	assert_eq(Pathfinder.route(g, 1, 4), [2, 3, 4] as Array[int])
	assert_eq(Pathfinder.route(g, 4, 1), [3, 2, 1] as Array[int])
	assert_eq(Pathfinder.route(g, 2, 2), [] as Array[int])
	assert_eq(Pathfinder.route(g, 1, 77), [] as Array[int])


func test_schedule_delay_and_order() -> void:
	var sched := CommandSchedule.new()
	var a := _cmd(CmdDebugSpawnScout.TYPE, 9, {"system": 1})
	var b := _cmd(CmdDebugSpawnScout.TYPE, 3, {"system": 2})
	var p := _cmd(CmdPause.TYPE, 9, {"paused": 0})
	sched.submit(a, 10)
	sched.submit(b, 10)
	sched.submit(p, 10)
	assert_eq(a.exec_tick, 12, "normal commands wait DELAY ticks")
	assert_eq(p.exec_tick, 10, "pause/speed run at the current boundary")
	assert_eq(sched.take_due(10), [p] as Array[Command])
	assert_eq(sched.take_due(11), [] as Array[Command])
	assert_eq(sched.take_due(12), [b, a] as Array[Command], "same tick: lower player_id first")
	assert_eq(sched.size(), 0)


func test_spawn_and_move_scout() -> void:
	var s := build_line()
	var sched := CommandSchedule.new()
	sched.submit(_cmd(CmdDebugSpawnScout.TYPE, 9, {"system": 1}), s.tick)
	_run(s, sched, 3)
	assert_eq(s.units.size(), 1)
	var scout: Unit = s.units.values()[0]
	assert_eq(scout.id, 10)
	assert_eq(scout.system_id, 1)
	sched.submit(_cmd(CmdMoveUnit.TYPE, 9, {"unit": scout.id, "to": 4}), s.tick)
	_run(s, sched, 2)  # command is not applied yet
	assert_false(scout.is_moving())
	_run(s, sched, 1)  # applied, then the first hour of movement
	assert_eq(scout.path, [2, 3, 4] as Array[int])
	assert_eq(scout.progress, 4)
	_run(s, sched, 2)  # 12 >= 10: arrives at 2, 2 units into the next lane
	assert_eq(scout.system_id, 2)
	assert_eq(scout.progress, 2)
	_run(s, sched, 10)
	assert_eq(scout.system_id, 4)
	assert_false(scout.is_moving())
	assert_eq(scout.progress, 0)


func test_move_mid_lane_finishes_current_lane() -> void:
	var s := build_line()
	Sim.execute(s, [_cmd(CmdDebugSpawnScout.TYPE, 9, {"system": 1})] as Array[Command])
	var scout: Unit = s.units.values()[0]
	Sim.execute(s, [_cmd(CmdMoveUnit.TYPE, 9, {"unit": scout.id, "to": 4})] as Array[Command])
	Sim.advance(s)
	Sim.execute(s, [_cmd(CmdMoveUnit.TYPE, 9, {"unit": scout.id, "to": 1})] as Array[Command])
	assert_eq(scout.path, [2, 1] as Array[int], "reaches 2 first, then turns back")


func test_invalid_commands_are_rejected_not_applied() -> void:
	var s := build_line()
	Sim.execute(s, [_cmd(CmdDebugSpawnScout.TYPE, 9, {"system": 1})] as Array[Command])
	var scout_id: int = s.units.keys()[0]
	var bad: Array[Command] = [
		_cmd(CmdDebugSpawnScout.TYPE, 9, {"system": 99}),
		_cmd(CmdDebugSpawnScout.TYPE, 42, {"system": 1}),
		_cmd(CmdMoveUnit.TYPE, 42, {"unit": scout_id, "to": 4}),
		_cmd(CmdMoveUnit.TYPE, 9, {"unit": 999, "to": 4}),
		_cmd(CmdMoveUnit.TYPE, 9, {"unit": scout_id, "to": 99}),
	]
	var before := s.checksum()
	var rejected := Sim.execute(s, bad)
	assert_eq(rejected.size(), 5)
	for cmd in rejected:
		assert_ne(cmd.error, "", String(cmd.type_id))
	assert_eq(s.checksum(), before, "state untouched")
	assert_eq(s.command_log.size(), 1, "only the first spawn was logged")


func test_command_log_records_execution() -> void:
	var s := build_line()
	s.tick = 5
	Sim.execute(s, [_cmd(CmdDebugSpawnScout.TYPE, 9, {"system": 3})] as Array[Command])
	assert_eq(s.command_log, [{"tick": 5, "type_id": "core:cmd/debug_spawn_scout", "player": 9, "payload": {"system": 3}}] as Array[Dictionary])


func test_replay_matches_live_run() -> void:
	var s := build_line()
	var initial := s.to_dict()
	var sched := CommandSchedule.new()
	# A scripted session: unpause, spawn two scouts, move them, change speed, pause late.
	var script := {
		0: [[CmdPause.TYPE, {"paused": 0}], [CmdDebugSpawnScout.TYPE, {"system": 1}]],
		1: [[CmdDebugSpawnScout.TYPE, {"system": 4}]],
		5: [[CmdMoveUnit.TYPE, {"unit": 10, "to": 4}], [CmdMoveUnit.TYPE, {"unit": 11, "to": 1}]],
		9: [[CmdSetSpeed.TYPE, {"speed": 4}], [CmdMoveUnit.TYPE, {"unit": 10, "to": 1}]],
		30: [[CmdPause.TYPE, {"paused": 1}]],
	}
	for t in 40:
		for entry: Array in script.get(t, []):
			sched.submit(_cmd(entry[0], 9, entry[1]), s.tick)
		Sim.step(s, sched.take_due(s.tick))
	var replayed := Sim.replay_from(initial, s.command_log, s.tick)
	assert_eq(replayed.checksum(), s.checksum())
	assert_eq(replayed.command_log, s.command_log)
	# Same again after the log has been through JSON (as in a save file or network message).
	var json_log: Array = JSON.parse_string(JSON.stringify(s.command_log))
	assert_eq(Sim.replay_from(initial, json_log, s.tick).checksum(), s.checksum())


func test_command_round_trip() -> void:
	var cmd := _cmd(CmdMoveUnit.TYPE, 9, {"unit": 10, "to": 4})
	cmd.exec_tick = 77
	cmd.seq = 3
	var copy := CommandRegistry.from_dict(JSON.parse_string(JSON.stringify(cmd.to_dict())))
	assert_true(copy is CmdMoveUnit)
	assert_eq(copy.to_dict(), cmd.to_dict())
