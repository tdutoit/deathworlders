class_name SectorLogistics
extends RefCounted
## Two-tier logistics (Sub-spec D5). The default governor's demands are derived from the state every day
## (never stored), and only draw on sources inside the sector ("local" tier):
##   - each non-Manual colony keeps input_buffer_months of its jobs' inputs and food_buffer_months of food
##     (Critical when under a month of food);
##   - each sector hub gathers the sector's mining output up to hub_collect_permille of its cap (Low).
## The trunk tier: a non-core sector's hub exports its quota (default 50%) of surplus to the Core hub.

const FOOD := "core:resource/food"


static func demands(state: MatchState, eid: int) -> Array:
	var out := []
	var r := Economy.rules(state.defs)
	var core := core_sector(state, eid)
	var cols: Array[Colony] = []  # the empire's colonies and operational stations, gathered once
	for pid: int in state.colonies.ordered():
		var c: Colony = state.colonies.get_or(pid)
		if c.owner == eid:
			cols.append(c)
	var stations: Array[Station] = []
	for sid: int in state.stations.ordered():
		var st: Station = state.stations.get_or(sid)
		if st.owner == eid and st.operational:
			stations.append(st)
	for sid: int in state.sectors.ordered():
		var sec: Sector = state.sectors.get_or(sid)
		if sec.owner != eid:
			continue
		var in_sector := {}
		for sys_id in sec.systems:
			in_sector[sys_id] = true
		_colony_needs(state, sec, r, out, cols, in_sector)
		_hub_collection(state, sec, r, out, stations, in_sector)
		if core != null and sec.id != core.id:
			_exports(state, sec, core, r, out)
	return out


static func core_sector(state: MatchState, eid: int) -> Sector:
	for sid: int in state.sectors.ordered():
		var sec: Sector = state.sectors.get_or(sid)
		if sec.owner == eid and sec.core:
			return sec
	return null


static func _colony_needs(state: MatchState, sec: Sector, r: EconomyRulesDef, out: Array, cols: Array[Colony],
		in_sector: Dictionary) -> void:
	for c in cols:
		var pid := c.id
		if c.autonomy == "manual" or not in_sector.has(state.galaxy.planet(pid).system_id):
			continue
		var need := {}  # resource -> milli per month
		for job: String in IdMap.sort_keys(c.jobs.keys()):
			var jd: JobDef = state.defs.get_def(StringName(job))
			for res: StringName in jd.inputs:
				need[String(res)] = need.get(String(res), 0) + int(jd.inputs[res]) * int(c.jobs[job]) * Stockpile.MILLI
		for res: String in IdMap.sort_keys(need.keys()):
			out.append({"holder": pid, "resource": res, "target": need[res] * r.input_buffer_months, "priority": 2, "sector": sec.id})
		var eat := c.total_pops() * r.food_per_pop * Stockpile.MILLI
		if eat > 0:
			var urgent := c.stockpile.milli(FOOD) < eat
			out.append({"holder": pid, "resource": FOOD, "target": eat * r.food_buffer_months, "priority": 3 if urgent else 2, "sector": sec.id})


static func _hub_collection(state: MatchState, sec: Sector, r: EconomyRulesDef, out: Array, stations: Array[Station],
		in_sector: Dictionary) -> void:
	var made := {}  # resource -> station IDs producing it in the sector
	for s in stations:
		if not in_sector.has(s.system_id) or s.id == sec.hub:
			continue
		for res: StringName in (state.defs.get_def(StringName(s.def_id)) as StationDef).outputs:
			if not made.has(String(res)):
				made[String(res)] = []
			made[String(res)].append(s.id)
	for res: String in IdMap.sort_keys(made.keys()):
		var cap := Holders.cap_milli(state, sec.hub, res)
		if cap > 0:  # only from the stations that mine it, so colonies keep their own stock
			out.append({"holder": sec.hub, "resource": res, "target": FixedMath.mul_permille(cap, r.hub_collect_permille),
				"priority": 1, "sector": sec.id, "sources": made[res]})


## Trunk exports (D5): quota x the hub's surplus above its reserve goes to the Core hub.
static func _exports(state: MatchState, sec: Sector, core: Sector, r: EconomyRulesDef, out: Array) -> void:
	var stock := Holders.stockpile(state, sec.hub)
	var core_stock := Holders.stockpile(state, core.hub)
	for res: String in IdMap.sort_keys(stock.amounts.keys()):
		var rdef := state.defs.get_def(StringName(res)) as ResourceDef
		if rdef == null or not rdef.physical:
			continue
		var quota: int = sec.export_quotas.get(res, r.export_quota_default_permille)
		var surplus := stock.milli(res) - AutoLogistics.reserve_milli(state, sec.hub, res)
		var amount := FixedMath.mul_permille(surplus, quota)
		if amount > 0:
			out.append({"holder": core.hub, "resource": res, "target": core_stock.milli(res) + amount, "priority": 1, "sources": [sec.hub]})


## Open import requests (D5): needs of a non-core sector that nothing inside the sector can supply.
## [{sector, holder, resource, deficit (milli)}]
static func import_requests(state: MatchState, eid: int) -> Array:
	var out := []
	var core := core_sector(state, eid)
	var promised := {}
	for d: Dictionary in demands(state, eid):
		if not d.has("sector") or (core != null and d["sector"] == core.id):
			continue
		var deficit: int = d["target"] - Holders.stockpile(state, d["holder"]).milli(d["resource"])
		if deficit <= 0:
			continue
		var sec: Sector = state.sectors.get_or(d["sector"])
		var local := false
		for h in AutoLogistics._own_holders(state, eid):
			if h != d["holder"] and Holders.system(state, h) in sec.systems and AutoLogistics._surplus(state, h, d["resource"], promised) > 0:
				local = true
				break
		if not local:
			out.append({"sector": sec.id, "holder": d["holder"], "resource": d["resource"], "deficit": deficit})
	return out
