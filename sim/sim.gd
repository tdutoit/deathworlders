class_name Sim
extends RefCounted
## The deterministic simulation entry points (M1 WP5/WP6). Pure: no Nodes, files or clocks.
##
## One hour tick = execute(state, due commands) then advance(state). While paused the client still
## calls execute() each frame so pause/speed commands take effect.

const DAY := 1  # advance() flags
const MONTH := 2


## Validates and applies commands in order. Applied ones go to state.command_log; rejected ones
## are returned (with cmd.error set) so the caller can log them.
static func execute(state: MatchState, commands: Array[Command]) -> Array[Command]:
	var rejected: Array[Command] = []
	for cmd in commands:
		if cmd.validate(state):
			cmd.apply(state)
			state.command_log.append({
				"tick": state.tick, "type_id": String(cmd.type_id), "player": cmd.player_id,
				"payload": cmd.payload.duplicate(true),
			})
		else:
			rejected.append(cmd)
	return rejected


## One hour: movement, then the clock moves on. Returns DAY / MONTH flags for boundaries reached.
static func advance(state: MatchState) -> int:
	Movement.tick(state)
	state.tick += 1
	var flags := 0
	if Calendar.is_day_start(state.tick):
		flags |= DAY
		_day_tick(state)
	if Calendar.is_month_start(state.tick):
		flags |= MONTH
		_month_tick(state)
	return flags


static func step(state: MatchState, commands: Array[Command]) -> int:
	execute(state, commands)
	return advance(state)


## Production, food and construction progress (M2).
static func _day_tick(state: MatchState) -> void:
	if state.defs == null:
		return
	@warning_ignore("integer_division")
	var day := (state.tick / Calendar.HOURS_PER_DAY - 1) % Calendar.DAYS_PER_MONTH  # day just completed
	Economy.day_tick(state, day)


## Settlement: growth, stability, taxes and upkeep (M2).
static func _month_tick(state: MatchState) -> void:
	if state.defs == null:
		return
	Economy.month_tick(state)


## Rebuilds a match from its seed and settings plus a command log (main spec 18.4 debug replay).
static func replay(seed_value: int, settings: MatchSettings, db: DefDatabase, command_log: Array,
		until_tick: int) -> MatchState:
	var errors: Array[String] = []
	var start := GalaxyGenerator.new_match(settings, seed_value, db, errors)
	assert(start != null, "Sim.replay: " + ", ".join(errors))
	return replay_from(start.to_dict(), command_log, until_tick, db)


## Rebuilds a match from a starting snapshot plus a command log, running until_tick hour ticks.
## Log entries are applied at their tick, in log order, exactly as the live run applied them.
static func replay_from(initial: Dictionary, command_log: Array, until_tick: int, db: DefDatabase = null) -> MatchState:
	var state := MatchState.from_dict(initial)
	state.defs = db
	state.command_log.clear()
	var i := 0
	while true:
		var due: Array[Command] = []
		while i < command_log.size() and int(command_log[i]["tick"]) <= state.tick:
			due.append(CommandRegistry.from_dict(command_log[i]))
			i += 1
		execute(state, due)
		if state.tick >= until_tick:
			break
		advance(state)
	return state
