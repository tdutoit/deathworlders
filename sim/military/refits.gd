class_name Refits
extends RefCounted
## Refits (main spec 7.4 "refit before battle"; M5 WP7; owner rules 2026-10-04). A fleet at an own shipyard
## or supply depot refits every ship of the design's hull class (same species, Mk up to the design's) to one of
## the empire's designs. Time: base_days + days_per_slot per changed slot (pace, then empire.refit_time); a Mk
## upgrade adds half the new hull's build days and needs a shipyard of the hull's size. Cost, paid up front from
## the empire's stockpiles in that system: the added parts in full plus half the hull cost difference; removed
## parts refund half. A refitting ship holds position; in battle it fights with its old parts and the refit
## pauses. Numbers in combat_rules (refit_*).

const STATIONS: Array[StringName] = [&"shipyard", &"depot"]


## The empire's operational refit stations in a system: [best shipyard size index (-1 none), any depot or yard?].
static func facilities(state: MatchState, eid: int, system_id: int) -> Array:
	var yard := -1
	var any := false
	for sid: int in state.stations.ordered():
		var s: Station = state.stations.get_or(sid)
		if s.owner != eid or s.system_id != system_id or not s.operational:
			continue
		var def := state.defs.get_def(StringName(s.def_id)) as StationDef
		if def.function in STATIONS:
			any = true
		if def.function == &"shipyard":
			yard = maxi(yard, HullDef.YARD_SIZES.find(String(def.shipyard_size)))
	return [yard, any]


## Whether a ship can take this design: same species and class, Mk not above the design's, not already
## refitting, and something changes.
static func eligible(state: MatchState, u: Unit, d: ShipDesign) -> bool:
	if not u.refit.is_empty() or u.kind != "warship":
		return false
	var old := state.defs.get_def(StringName(u.hull_id)) as HullDef
	var new := state.defs.get_def(StringName(d.hull)) as HullDef
	if old == null or new == null or old.hull_class != new.hull_class or old.species != new.species or old.mark > new.mark:
		return false
	return u.hull_id != d.hull or u.components != d.components


## {"cost": resource -> milli (pace), "refund": resource -> milli, "days": int} for one ship.
static func plan(state: MatchState, u: Unit, d: ShipDesign) -> Dictionary:
	var r := state.defs.get_def(CombatRulesDef.ID) as CombatRulesDef
	var pace := BuildRules.pace(state)
	var have := {}  # component -> count on the ship now
	for c in u.components:
		if c != "":
			have[c] = int(have.get(c, 0)) + 1
	var cost := {}
	var refund := {}
	var added := {}
	for c in d.components:
		if c == "":
			continue
		if int(have.get(c, 0)) > 0:
			have[c] = int(have[c]) - 1
		else:
			added[c] = int(added.get(c, 0)) + 1
	for c: String in IdMap.sort_keys(added.keys()):
		_add_cost(state, cost, c, int(added[c]) * 1000)
	for c: String in IdMap.sort_keys(have.keys()):
		if int(have[c]) > 0:
			_add_cost(state, refund, c, int(have[c]) * r.refit_refund_permille)
	var changed := 0
	for i in maxi(u.components.size(), d.components.size()):
		var a := u.components[i] if i < u.components.size() else ""
		var b := d.components[i] if i < d.components.size() else ""
		if a != b:
			changed += 1
	var days := r.refit_base_days + r.refit_days_per_slot * changed
	if u.hull_id != d.hull:
		var old := state.defs.get_def(StringName(u.hull_id)) as HullDef
		var new := state.defs.get_def(StringName(d.hull)) as HullDef
		for res: StringName in IdMap.sort_keys(new.cost.keys()):
			var diff := int(new.cost[res]) - int(old.cost.get(res, 0))
			if diff > 0:
				cost[String(res)] = int(cost.get(String(res), 0)) + FixedMath.mul_permille(diff * Stockpile.MILLI, r.refit_hull_permille)
		days += FixedMath.mul_permille(new.build_days, r.refit_hull_permille)
	days = Pace.scale(days, pace)
	days = maxi(1, FixedMath.mul_permille(days, 1000 + SpeciesTraits.empire_permille(state, u.owner, "empire.refit_time")))
	for res: String in cost:
		cost[res] = Pace.scale(int(cost[res]), pace)
	return {"cost": cost, "refund": refund, "days": days}


static func _add_cost(state: MatchState, into: Dictionary, component: String, permille: int) -> void:
	var c := state.defs.get_def(StringName(component)) as ComponentDef
	if c == null:
		return
	for res: StringName in c.cost:
		into[String(res)] = int(into.get(String(res), 0)) + FixedMath.mul_permille(int(c.cost[res]) * Stockpile.MILLI, permille)


## Stockpile holders of the empire in a system (stations first, then colonies; ID order).
static func holders(state: MatchState, eid: int, system_id: int) -> Array[int]:
	var out: Array[int] = []
	for sid: int in state.stations.ordered():
		var s: Station = state.stations.get_or(sid)
		if s.owner == eid and s.system_id == system_id and s.operational:
			out.append(s.id)
	for pid in state.galaxy.system(system_id).planet_ids:
		var c := state.colony(pid)
		if c != null and c.owner == eid:
			out.append(pid)
	return out


static func stock(state: MatchState, ids: Array[int], res: String) -> int:
	var total := 0
	for h in ids:
		total += Holders.stockpile(state, h).milli(res)
	return total


## Starts a refit on one ship (rules already checked): pays, refunds, sets the countdown.
static func start(state: MatchState, u: Unit, d: ShipDesign, p: Dictionary, ids: Array[int]) -> void:
	for res: String in IdMap.sort_keys(p["cost"].keys()):
		var left := int(p["cost"][res])
		for h in ids:
			if left <= 0:
				break
			left -= Holders.stockpile(state, h).take(res, left)
	for res: String in IdMap.sort_keys(p["refund"].keys()):
		var left := int(p["refund"][res])
		for h in ids:
			if left <= 0:
				break
			left -= Holders.stockpile(state, h).add(res, left, Holders.cap_milli(state, h, res))
	u.refit = {"design": d.id, "hull": d.hull, "components": d.components.duplicate(), "days": int(p["days"])}


## Daily countdown; a ship in battle pauses. Finished ships take the new hull and parts, fully repaired.
static func day_tick(state: MatchState) -> void:
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.refit.is_empty() or Battles.in_battle(state, u.id):
			continue
		u.refit["days"] = int(u.refit["days"]) - 1
		if int(u.refit["days"]) > 0:
			continue
		u.hull_id = String(u.refit["hull"])
		u.components.assign(u.refit["components"])
		u.design = int(u.refit["design"])
		u.refit = {}
		Fleets.arm(state, u)
		if u.fleet != StateIO.NONE:
			Fleets.regroup(state, state.fleets.get_or(u.fleet))
