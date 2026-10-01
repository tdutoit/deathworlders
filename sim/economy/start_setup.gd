class_name StartSetup
extends RefCounted
## Gives every empire's capital its opening economy from a StartDef (Sub-spec B19), in empire ID order.

const DEFAULT_START := &"core:start/default"


static func apply(state: MatchState, db: DefDatabase) -> void:
	var start: StartDef = db.get_def(DEFAULT_START)
	if start == null:
		return
	for eid: int in state.empires:
		var e: Empire = state.empires.get_or(eid)
		var planet := state.galaxy.planet(e.capital_planet)
		var c := Colony.new()
		c.id = planet.id
		c.owner = e.id
		c.pops = {e.species: start.pops}
		for b in start.buildings:
			c.buildings.append(String(b))
			_ensure_deposit(planet, db.get_def(b) as BuildingDef, start.buildings.count(b))
		c.primary_focus = String(start.primary_focus)
		c.secondary_focus = String(start.secondary_focus)
		for job: StringName in start.job_caps:
			c.job_caps[String(job)] = int(start.job_caps[job])
		for res: StringName in IdMap.sort_keys(start.stockpile.keys()):
			c.stockpile.add(String(res), int(start.stockpile[res]) * Stockpile.MILLI)
		for res: StringName in IdMap.sort_keys(start.treasury.keys()):
			e.treasury[String(res)] = e.treasury.get(String(res), 0) + int(start.treasury[res]) * Stockpile.MILLI
		c.stage = String(start.stage)
		c.founded_tick = state.tick
		Economy.assign_jobs(c, db)
		state.colonies.put(c.id, c)


## A start building that needs a deposit gets one rich enough to hold all its copies.
static func _ensure_deposit(planet: Planet, b: BuildingDef, copies: int) -> void:
	if b == null or b.requires_deposit == &"":
		return
	var res := String(b.requires_deposit)
	planet.deposits[res] = maxi(int(planet.deposits.get(res, 0)), copies)
