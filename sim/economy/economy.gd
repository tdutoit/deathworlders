class_name Economy
extends RefCounted
## Planet economy (M2 WP2): jobs, production, food, growth, stability, taxes and upkeep.
## Sub-spec B0: amounts are milli-units and rates are monthly; a monthly total T is spread over the 30 days
## as floor(T*(d+1)/30) - floor(T*d/30), so a month adds up to exactly T. Colonies run in ID order.
## All rule numbers come from EconomyRulesDef / PlanetSizeDef / the job and building Defs.

const MILLI := 1000
const DAYS := Calendar.DAYS_PER_MONTH


static func rules(db: DefDatabase) -> EconomyRulesDef:
	return db.get_def(EconomyRulesDef.ID)


## Day tick: production and food for every colony. `day` is the day of the month just completed (0..29).
static func day_tick(state: MatchState, day: int) -> void:
	var db := state.defs
	var order := job_order(db)
	for pid: int in state.colonies:
		var c: Colony = state.colonies.get_or(pid)
		_produce(state, c, db, day, order)
		if c.retool_days > 0:
			c.retool_days -= 1


## Month tick: growth or starvation, jobs, stability, strikes, taxes and upkeep; then empire deficits.
static func month_tick(state: MatchState) -> void:
	var db := state.defs
	var r := rules(db)
	var upkeep_due := {}  # empire id -> milli-credits
	var reach := {}  # empire id -> {system: lanes to the nearest hub} (D9)
	for pid: int in state.colonies:
		var c: Colony = state.colonies.get_or(pid)
		var effects := Sectors.reach_effects(r, reach_of(state, reach, c.owner, state.galaxy.planet(c.id).system_id))
		_month_colony(state, c, db, r, effects[1])
		var e := state.empire(c.owner)
		var taxes := c.total_pops() * r.tax_per_pop_milli
		_credit(e, "core:resource/credits", taxes)
		c.add_flow(c.produced, "core:resource/credits", taxes)
		for i in c.buildings.size():
			var b: BuildingDef = db.get_def(StringName(c.buildings[i]))
			for res: StringName in IdMap.sort_keys(b.upkeep.keys()):
				if _is_global(db, String(res)):
					upkeep_due[c.owner] = upkeep_due.get(c.owner, 0) + FixedMath.mul_permille(b.upkeep[res] * MILLI, 1000 + effects[0])
				else:
					c.stockpile.take(String(res), b.upkeep[res] * MILLI)
		_roll_flows(c)
	for extra: Dictionary in [StationOps.upkeep(state, reach), Shipyards.upkeep(state)]:
		for eid: int in extra:
			upkeep_due[eid] = upkeep_due.get(eid, 0) + extra[eid]
	for eid: int in state.empires:
		var e: Empire = state.empires.get_or(eid)
		var due: int = upkeep_due.get(eid, 0)
		var have: int = e.treasury.get("core:resource/credits", 0)
		if due > have:
			e.treasury["core:resource/credits"] = 0
			e.deficit_months += 1
		else:
			e.treasury["core:resource/credits"] = have - due
			e.deficit_months = 0


## Lanes from a system to the empire's nearest sector hub, computed once per empire per call (D9).
static func reach_of(state: MatchState, cache: Dictionary, eid: int, system_id: int) -> int:
	if not cache.has(eid):
		cache[eid] = Sectors.reach_map(state, eid)
	return int(cache[eid].get(system_id, Sectors.FAR))


# --- production ---

## Jobs in the order they produce each day: raw producers first (JobDef.priority, then ID), so a Worker
## can use Ore mined the same day.
static func job_order(db: DefDatabase) -> Array:
	var jobs := db.defs("job")
	jobs.sort_custom(func(a: JobDef, b: JobDef) -> bool:
		return a.priority < b.priority if a.priority != b.priority else String(a.id) < String(b.id))
	return jobs.map(func(j: JobDef) -> String: return String(j.id))


static func _produce(state: MatchState, c: Colony, db: DefDatabase, day: int, order: Array) -> void:
	var mods := PlanetMods.of(c, db)
	var e := state.empire(c.owner)
	for job_id: String in order:
		var n: int = c.jobs.get(job_id, 0)
		if n <= 0:
			continue
		var job: JobDef = db.get_def(StringName(job_id))
		var short_name := job_id.get_slice("/", 1)
		# Inputs come from the local stockpile; a shortage scales the whole job down (B3).
		var needs := {}
		var ratio := MILLI
		for res: StringName in IdMap.sort_keys(job.inputs.keys()):
			var per_pop := maxi(0, int(job.inputs[res]) + mods.add("job.input.%s.%s" % [short_name, String(res).get_slice("/", 1)]))
			var need := share(per_pop * n * MILLI, day)
			needs[String(res)] = need
			if need > 0:
				ratio = mini(ratio, FixedMath.floor_div(c.stockpile.milli(String(res)) * MILLI, need))
		for res: String in needs:
			var used := c.stockpile.take(res, FixedMath.floor_div(needs[res] * ratio, MILLI))
			c.add_flow(c.consumed, res, used)
		var out_permille := output_permille(c, job_id, db, mods)
		for res: StringName in IdMap.sort_keys(job.outputs.keys()):
			var total := FixedMath.mul_permille(int(job.outputs[res]) * n * MILLI, out_permille)
			_deliver(state, c, e, db, mods, String(res), FixedMath.floor_div(share(total, day) * ratio, MILLI))
	for i in c.buildings.size():
		if i == c.offline_building:
			continue
		var b: BuildingDef = db.get_def(StringName(c.buildings[i]))
		for res: StringName in IdMap.sort_keys(b.outputs.keys()):
			_deliver(state, c, e, db, mods, String(res), share(int(b.outputs[res]) * MILLI, day))
	# Pops eat daily; running out at any point this month marks the colony as starving (B17).
	var food := "core:resource/food"
	var hunger := share(c.total_pops() * rules(db).food_per_pop * MILLI, day)
	var eaten := c.stockpile.take(food, hunger)
	c.add_flow(c.consumed, food, eaten)
	if eaten < hunger:
		c.starving = true


## floor(T*(d+1)/30) - floor(T*d/30): day d's part of a monthly total T.
static func share(total: int, day: int) -> int:
	return FixedMath.floor_div(total * (day + 1), DAYS) - FixedMath.floor_div(total * day, DAYS)


static func _deliver(state: MatchState, c: Colony, e: Empire, db: DefDatabase, mods: PlanetMods, res: String, amount: int) -> void:
	if amount <= 0:
		return
	c.add_flow(c.produced, res, amount)
	if _is_global(db, res):
		_credit(e, res, amount)
	else:
		c.stockpile.add(res, amount, cap_milli(c, db, mods, res))


static func _credit(e: Empire, res: String, amount: int) -> void:
	e.treasury[res] = e.treasury.get(res, 0) + amount


static func _is_global(db: DefDatabase, res: String) -> bool:
	var def := db.get_def(StringName(res)) as ResourceDef
	return def != null and not def.physical


## Output multiplier of a job on this colony, in permille (focus, synergy, modifiers, stability, retooling).
static func output_permille(c: Colony, job_id: String, db: DefDatabase, mods: PlanetMods) -> int:
	var r := rules(db)
	var p := 1000
	var boosted := false
	if c.primary_focus != "":
		var f: FocusDef = db.get_def(StringName(c.primary_focus))
		if StringName(job_id) in f.boosted_jobs:
			p += f.bonus_permille
			boosted = true
	if c.secondary_focus != "":
		var f: FocusDef = db.get_def(StringName(c.secondary_focus))
		if StringName(job_id) in f.boosted_jobs:
			p += FixedMath.mul_permille(f.bonus_permille, r.secondary_focus_permille)
			boosted = true
	var syn := PlanetMods.synergy(c, db)
	if syn != null and boosted:
		p += syn.bonus_permille
	p += mods.permille("job.output." + job_id.get_slice("/", 1))
	if c.stability < r.low_stability_threshold:
		p += r.low_stability_output_permille
	if c.retool_days > 0 and boosted:
		p += r.retool_output_permille
	return maxi(0, p)


## Stockpile cap for a physical resource in milli-units; 0 = uncapped (B5).
static func cap_milli(c: Colony, db: DefDatabase, mods: PlanetMods, res: String) -> int:
	var def := db.get_def(StringName(res)) as ResourceDef
	if def == null or def.stockpile_default_cap <= 0:
		return 0
	return mods.resolve("planet.stockpile_cap", def.stockpile_default_cap) * MILLI


# --- planet capacity ---

static func size_def(planet: Planet, db: DefDatabase) -> PlanetSizeDef:
	return db.get_def(PlanetSizeDef.id_for(planet.size))


## Building slots (B2 + modifiers such as the capital's +2).
static func slots(c: Colony, planet: Planet, db: DefDatabase) -> int:
	return PlanetMods.of(c, db).resolve("planet.building_slots", size_def(planet, db).building_slots)


static func used_slots(c: Colony, db: DefDatabase) -> int:
	var n := 0
	for b in c.buildings:
		if (db.get_def(StringName(b)) as BuildingDef).uses_slot:
			n += 1
	return n


## Effective housing = (size housing + modifiers) * the owner species' habitability / 1000 (B2).
static func housing(state: MatchState, c: Colony, planet: Planet, db: DefDatabase) -> int:
	var species: SpeciesDef = db.get_def(StringName(state.empire(c.owner).species))
	var hab: int = species.habitability.get(StringName(planet.planet_type), 0)
	var base := PlanetMods.of(c, db).resolve("planet.housing", size_def(planet, db).housing)
	return FixedMath.mul_permille(base, hab)


# --- jobs (D4: always auto-assigned; per-planet priority list and caps) ---

static func assign_jobs(c: Colony, db: DefDatabase) -> void:
	var open := {}  # job -> job slots from buildings
	for i in c.buildings.size():
		if i == c.offline_building:
			continue
		var b: BuildingDef = db.get_def(StringName(c.buildings[i]))
		for job: StringName in b.jobs:
			open[String(job)] = open.get(String(job), 0) + int(b.jobs[job])
	var order: Array[String] = []
	if c.starving:
		for job: String in job_order(db):
			if (db.get_def(StringName(job)) as JobDef).outputs.has(&"core:resource/food"):
				order.append(job)
	order.append_array(c.job_priority)
	for focus in [c.primary_focus, c.secondary_focus]:
		if focus != "":
			for job: StringName in (db.get_def(StringName(focus)) as FocusDef).boosted_jobs:
				order.append(String(job))
	order.append_array(job_order(db))
	var free := c.total_pops()
	var filled := {}
	for job in order:
		if free <= 0:
			break
		if filled.has(job) or not open.has(job):
			continue
		var take := mini(open[job], free)
		if c.job_caps.has(job):
			take = mini(take, int(c.job_caps[job]))
		if take > 0:
			filled[job] = take
			free -= take
	c.jobs = filled


# --- month ---

static func _month_colony(state: MatchState, c: Colony, db: DefDatabase, r: EconomyRulesDef, reach_stability: int = 0) -> void:
	var planet := state.galaxy.planet(c.id)
	var food := "core:resource/food"
	var surplus: bool = not c.starving and c.produced.get(food, 0) > c.consumed.get(food, 0)
	var mods := PlanetMods.of(c, db)
	if c.starving:
		c.starving_months += 1
		if c.starving_months % r.starvation_pop_loss_months == 0 and c.total_pops() > 1:
			_remove_pop(c)
	else:
		c.starving_months = 0
		if surplus:
			var free := maxi(0, housing(state, c, planet, db) - c.total_pops())
			var points := r.growth_base + r.growth_per_free_housing * free
			c.growth += FixedMath.mul_permille(points, 1000 + mods.permille("planet.growth"))
			if c.growth >= r.growth_points_per_pop:
				if c.total_pops() < housing(state, c, planet, db):
					var species := state.empire(c.owner).species
					c.pops[species] = c.pops.get(species, 0) + 1
					c.growth -= r.growth_points_per_pop
				else:
					c.growth = r.growth_points_per_pop
	assign_jobs(c, db)
	var stab := r.stability_base
	stab += r.stability_starvation if c.starving else (r.stability_food_surplus if surplus else 0)
	stab += mini(r.stability_garrison_max, r.stability_garrison_each * mods.add("planet.garrison"))
	if c.retool_days > 0:
		stab += r.stability_retooling
	stab += r.stability_unemployed_each * c.unemployed()
	stab += r.stability_deficit_each_month * state.empire(c.owner).deficit_months
	stab += reach_stability
	for job: String in IdMap.sort_keys(c.jobs.keys()):
		stab += (db.get_def(StringName(job)) as JobDef).stability * int(c.jobs[job])
	c.stability = clampi(stab, 0, 100)
	# Strikes (B18): below the threshold a random building goes offline for the next month.
	var was_offline := c.offline_building
	c.offline_building = -1
	if c.stability < r.strike_threshold and not c.buildings.is_empty():
		c.offline_building = state.rng(DetRng.EVENTS).range(0, c.buildings.size())
	if c.offline_building != was_offline:
		assign_jobs(c, db)
	c.starving = false


## Starvation pop loss: one pop from the largest species group (ties: lowest ID).
static func _remove_pop(c: Colony) -> void:
	var pick := ""
	for s: String in IdMap.sort_keys(c.pops.keys()):
		if pick == "" or c.pops[s] > c.pops[pick]:
			pick = s
	c.pops[pick] -= 1
	if c.pops[pick] <= 0:
		c.pops.erase(pick)


static func _roll_flows(c: Colony) -> void:
	c.last_produced = c.produced
	c.last_consumed = c.consumed
	c.produced = {}
	c.consumed = {}
