class_name CmdSetSpeed
extends Command
## core:cmd/set_speed {"speed": 1 | 2 | 4 | 8} (main spec 2: pause plus 1x, 2x, 4x, 8x)

const TYPE := &"core:cmd/set_speed"
const SPEEDS: Array[int] = [1, 2, 4, 8]


func validate(_state: MatchState) -> bool:
	if not p_int("speed") in SPEEDS:
		return reject("speed must be one of %s" % [SPEEDS])
	return true


func apply(state: MatchState) -> void:
	state.speed = p_int("speed")


func is_immediate() -> bool:
	return true


## Next speed step up or down from current (clamped).
static func step_from(current: int, direction: int) -> int:
	var i := clampi(SPEEDS.find(current) + direction, 0, SPEEDS.size() - 1)
	return SPEEDS[i]
