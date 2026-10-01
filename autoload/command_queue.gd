extends Node
## Entry point for player and AI Commands (Sub-spec C7). Local loopback lockstep for M1: commands are
## stamped exec_tick = tick + delay and GameClock hands them to the sim on that tick.

var schedule := CommandSchedule.new()
var local_player := 0  # empire ID of this client's player; set when a match starts


func submit(cmd: Command) -> void:
	var state: MatchState = GameState.state
	assert(state != null, "CommandQueue.submit: no match running")
	schedule.submit(cmd, state.tick)


## Builds a command for the local player and submits it.
func submit_new(type_id: StringName, payload: Dictionary) -> Command:
	var cmd := CommandRegistry.create(type_id, local_player, payload)
	submit(cmd)
	return cmd


func reset() -> void:
	schedule = CommandSchedule.new()
