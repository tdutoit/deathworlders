extends Node
## Client-side clock (M1 WP5): turns frame time into whole hour ticks at the match speed and runs
## them through Sim. Floats are fine here: only whole ticks reach the sim.

signal hour_passed(tick: int)
signal day_passed(tick: int)
signal month_passed(tick: int)

const HOURS_PER_SECOND_AT_1X := 24.0  # 1x = one in-game day per real second (tunable)
const MAX_TICKS_PER_FRAME := 16  # at 8x a 60 fps frame needs ~3; more means a hitch: drop the backlog

var _accum := 0.0


func _process(delta: float) -> void:
	run_frame(delta)


## Executes due commands (even while paused), then the hour ticks this frame earned.
func run_frame(delta: float) -> int:
	var state: MatchState = GameState.state
	if state == null:
		return 0
	_execute_due(state)
	if state.paused:
		_accum = 0.0
		return 0
	var ticks := consume(delta, state.speed)
	for i in ticks:
		_execute_due(state)
		if state.paused:
			return i
		var flags := Sim.advance(state)
		hour_passed.emit(state.tick)
		if flags & Sim.DAY:
			day_passed.emit(state.tick)
		if flags & Sim.MONTH:
			month_passed.emit(state.tick)
	return ticks


## Whole ticks to run for this frame's delta at the given speed, capped per frame.
func consume(delta: float, speed: int) -> int:
	_accum += delta * HOURS_PER_SECOND_AT_1X * speed
	var ticks := int(_accum)
	if ticks > MAX_TICKS_PER_FRAME:
		_accum = 0.0
		return MAX_TICKS_PER_FRAME
	_accum -= ticks
	return ticks


func _execute_due(state: MatchState) -> void:
	for cmd in Sim.execute(state, CommandQueue.schedule.take_due(state.tick)):
		printerr("Command rejected at tick %d: %s (%s)" % [state.tick, cmd.type_id, cmd.error])


func _unhandled_input(event: InputEvent) -> void:
	var state: MatchState = GameState.state
	if state == null:
		return
	if event.is_action_pressed("pause"):
		CommandQueue.submit_new(CmdPause.TYPE, {"paused": 0 if state.paused else 1})
	elif event.is_action_pressed("speed_up"):
		CommandQueue.submit_new(CmdSetSpeed.TYPE, {"speed": CmdSetSpeed.step_from(state.speed, 1)})
	elif event.is_action_pressed("speed_down"):
		CommandQueue.submit_new(CmdSetSpeed.TYPE, {"speed": CmdSetSpeed.step_from(state.speed, -1)})
	else:
		return
	get_viewport().set_input_as_handled()
