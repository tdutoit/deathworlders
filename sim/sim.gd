class_name Sim
extends RefCounted
## The deterministic simulation entry points (M1 WP5/WP6). Pure: no Nodes, files or clocks.
##
## One hour tick = execute(state, due commands) then advance(state). While paused the client still
## calls execute() each frame so pause/speed commands take effect.

const DAY := 1  # advance() flags
const MONTH := 2
const EMPIRE_HOURS := 8  # M4 WP14: each empire's AI turn (and daily logistics) gets its own hour, by ID order
const AI_PHASE := 5  # month hour of the first empire's AI turn (AI_PHASE + k for the k-th empire, mod EMPIRE_HOURS)
const MONTH_PHASES := AI_PHASE + EMPIRE_HOURS  # hours after the month boundary that carry monthly work (_month_phase)


## Validates and applies commands in order. Applied ones go to state.command_log; rejected ones
## are returned (with cmd.error set) so the caller can log them.
static func execute(state: MatchState, commands: Array[Command]) -> Array[Command]:
	state.clear_scratch()
	var rejected: Array[Command] = []
	for cmd in commands:
		if cmd.validate(state):
			cmd.apply(state)
			SignatureMechanics.command_applied(state, cmd)
			state.command_log.append({
				"tick": state.tick, "type_id": String(cmd.type_id), "player": cmd.player_id,
				"payload": cmd.payload.duplicate(true),
			})
		else:
			rejected.append(cmd)
	return rejected


## One hour: movement, then the clock moves on. Returns DAY / MONTH flags for boundaries reached.
static func advance(state: MatchState) -> int:
	state.clear_scratch()
	Movement.tick(state)
	if state.defs != null:
		Freight.tick(state)
		Colonisation.tick(state)
		Pirates.tick(state)
		Battles.tick(state)
		Fleets.mission_tick(state)
	state.tick += 1
	var flags := 0
	if Calendar.is_day_start(state.tick):
		flags |= DAY
		_day_tick(state)
	if Calendar.is_month_start(state.tick):
		flags |= MONTH
		_month_tick(state)
	elif state.tick > Calendar.HOURS_PER_MONTH and state.tick % Calendar.HOURS_PER_MONTH <= MONTH_PHASES:
		_month_phase(state, state.tick % Calendar.HOURS_PER_MONTH)
	if state.defs != null and state.tick > 0:
		_logistics_hour(state, state.tick % Calendar.HOURS_PER_DAY)
	return flags


## Auto-logistics (B8) once a day per empire, the k-th empire (ID order) k hours after the day start, so no
## hour carries every empire's assignment (M4 WP14 perf; the first runs right after the day tick).
static func _logistics_hour(state: MatchState, hour: int) -> void:
	var k := 0
	for eid: int in state.empires.ordered():
		if k % EMPIRE_HOURS == hour:
			AutoLogistics.empire_day(state, eid)
		k += 1


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
	StationOps.day_tick(state, day)
	Builder.day_tick(state)
	Shipyards.day_tick(state)
	Deals.day_tick(state)  # M4: deal goods claim idle freighters before auto-logistics (_logistics_hour)
	FleetSupply.day_tick(state)
	SignatureMechanics.day_tick(state)  # M4: Brood Surge and other daily mechanics


## Settlement at the month boundary: growth, stability, taxes and upkeep, then sector membership (M2).
static func _month_tick(state: MatchState) -> void:
	if state.defs == null:
		return
	Economy.month_tick(state)
	Sectors.update_membership(state)


## The rest of the monthly work runs in the hours after the boundary, so no single hour carries it all (M2
## perf pass): 1 fuel supply, 2 pirates, 3 governors, 4 diplomacy (M4), then each AI empire's turn in its own
## hour (economic and military autopilot, then the strategic AI; M4 WP14), then the signature mechanics.
static func _month_phase(state: MatchState, hour: int) -> void:
	if state.defs == null:
		return
	match hour:
		1:
			Supply.month_tick(state)
		2:
			Pirates.month_tick(state)
		3:
			Governor.month_tick(state)
		4:
			Relations.month_tick(state)  # M4: contacts, opinion standing and decay
			Treaties.month_tick(state)  # trust from treaties, notice, tribute, obligations, calls
			Deals.month_tick(state)  # recurring deal payments
			Wars.month_tick(state)  # blockades, exhaustion, forced peace
			WarFooting.month_tick(state)  # Total War exhaustion
			Councils.month_tick(state)  # Galactic Council sessions
		MONTH_PHASES:
			SignatureMechanics.month_tick(state)
		_:
			if hour >= AI_PHASE:
				var k := 0
				for eid: int in state.empires.ordered():
					if AI_PHASE + k % EMPIRE_HOURS == hour:
						Autopilot.empire_month(state, eid)
						StrategicAI.empire_month(state, eid)  # E12: AI diplomacy and war decisions
					k += 1


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
