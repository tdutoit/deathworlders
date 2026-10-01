extends GutTest
# M1 WP5: calendar, tick pipeline and client clock pacing.

const GameClockScript := preload("res://autoload/game_clock.gd")


func test_calendar_dates() -> void:
	assert_eq(Calendar.format(0), "2200-01-01 00:00")
	assert_eq(Calendar.format(23), "2200-01-01 23:00")
	assert_eq(Calendar.format(24), "2200-01-02 00:00")
	assert_eq(Calendar.format(Calendar.HOURS_PER_MONTH), "2200-02-01 00:00")
	assert_eq(Calendar.format(Calendar.HOURS_PER_YEAR - 1), "2200-12-30 23:00")
	assert_eq(Calendar.format(Calendar.HOURS_PER_YEAR), "2201-01-01 00:00")


func test_twelve_months_is_8640_hour_ticks() -> void:
	var state := MatchState.create(MatchSettings.new(), 1)
	var months := 0
	var days := 0
	var none: Array[Command] = []
	while months < 12:
		var flags := Sim.step(state, none)
		if flags & Sim.DAY:
			days += 1
		if flags & Sim.MONTH:
			months += 1
	assert_eq(state.tick, 8640)
	assert_eq(days, 360)
	assert_eq(Calendar.format(state.tick), "2201-01-01 00:00")


func test_matches_start_paused_at_1x() -> void:
	var state := MatchState.create(MatchSettings.new(), 1)
	assert_true(state.paused)
	assert_eq(state.speed, 1)


func test_pause_and_speed_go_through_commands() -> void:
	var state := MatchState.create(MatchSettings.new(), 1)
	var cmds: Array[Command] = [
		CommandRegistry.create(CmdPause.TYPE, 1, {"paused": 0}),
		CommandRegistry.create(CmdSetSpeed.TYPE, 1, {"speed": 8}),
		CommandRegistry.create(CmdSetSpeed.TYPE, 1, {"speed": 3}),
	]
	var rejected := Sim.execute(state, cmds)
	assert_false(state.paused)
	assert_eq(state.speed, 8)
	assert_eq(rejected.size(), 1, "speed 3 is not allowed")
	assert_string_contains(rejected[0].error, "speed must be")
	assert_eq(state.command_log.size(), 2, "rejected commands are not logged as executed")


func test_speed_steps() -> void:
	assert_eq(CmdSetSpeed.step_from(1, 1), 2)
	assert_eq(CmdSetSpeed.step_from(8, 1), 8)
	assert_eq(CmdSetSpeed.step_from(1, -1), 1)
	assert_eq(CmdSetSpeed.step_from(4, -1), 2)


func test_clock_pacing_at_8x() -> void:
	var clock: Node = GameClockScript.new()
	var total := 0
	var worst := 0
	for frame in 60:
		var n: int = clock.consume(1.0 / 60.0, 8)
		total += n
		worst = maxi(worst, n)
	clock.free()
	# 8x = 8 days per second = 192 hour ticks; float accumulation may leave the last one pending.
	assert_between(total, 191, 192)
	assert_lte(worst, 4, "about 3.2 ticks per frame at 60 fps")


func test_clock_caps_a_hitch() -> void:
	var clock: Node = GameClockScript.new()
	assert_eq(clock.consume(5.0, 8), GameClockScript.MAX_TICKS_PER_FRAME, "5 s hitch at 8x is capped")
	assert_lt(clock.consume(1.0 / 60.0, 8), 5, "backlog was dropped, not carried")
	clock.free()


func test_clock_runs_nothing_while_paused() -> void:
	var state := MatchState.create(MatchSettings.new(), 1)
	GameState.state = state
	CommandQueue.reset()
	var clock: Node = GameClockScript.new()
	assert_eq(clock.run_frame(1.0), 0)
	assert_eq(state.tick, 0)
	CommandQueue.submit_new(CmdPause.TYPE, {"paused": 0})
	clock.run_frame(0.5)  # the unpause applies at this boundary, then 12 hours run at 1x
	assert_false(state.paused)
	assert_eq(state.tick, 12)
	clock.free()
	GameState.state = null
	CommandQueue.reset()
