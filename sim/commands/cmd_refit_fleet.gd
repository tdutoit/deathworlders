class_name CmdRefitFleet
extends Command
## core:cmd/refit_fleet {"fleet": ID, "design": own design ID} (C7 `refit_fleet`, main spec 7.4; M5 WP7).
## Every eligible ship of the fleet starts a refit to the design (Refits). The fleet must sit, out of battle,
## in a system with an own shipyard or depot (a shipyard of the hull's size for a Mk upgrade), the design's
## techs must be researched, and the system's own stockpiles must hold the whole cost.

const TYPE := &"core:cmd/refit_fleet"

var _ships: Array[int] = []
var _plans: Array[Dictionary] = []
var _holders: Array[int] = []


func validate(state: MatchState) -> bool:
	var f := FleetRules.owned(state, player_id, p_int("fleet"))
	if f == null:
		return reject("fleet %d is not yours" % p_int("fleet"))
	var d := Designs.owned(state, player_id, p_int("design"))
	if d == null:
		return reject("design %d is not yours" % p_int("design"))
	var tech := Shipyards.design_tech(state, player_id, d)
	if tech != "":
		return reject(tech)
	var lead := Fleets.lead(state, f)
	if lead == null or Fleets.is_moving(state, f) or Battles.in_battle(state, lead.id):
		return reject("the fleet must be stopped and out of battle")
	var fac := Refits.facilities(state, player_id, lead.system_id)
	if not fac[1]:
		return reject("no shipyard or supply depot of yours here")
	var hull := state.defs.get_def(StringName(d.hull)) as HullDef
	_ships.clear()
	_plans.clear()
	var need := {}
	for sid in f.ships():
		var u: Unit = state.units.get_or(sid)
		if not Refits.eligible(state, u, d):
			continue
		if u.hull_id != d.hull and int(fac[0]) < HullDef.YARD_SIZES.find(String(hull.shipyard_size)):
			return reject("a Mk upgrade to %s needs a size %s shipyard here" % [d.hull, hull.shipyard_size])
		var p := Refits.plan(state, u, d)
		_ships.append(u.id)
		_plans.append(p)
		for res: String in p["cost"]:
			need[res] = int(need.get(res, 0)) + int(p["cost"][res])
	if _ships.is_empty():
		return reject("no ship in the fleet can take this design")
	_holders = Refits.holders(state, player_id, lead.system_id)
	for res: String in IdMap.sort_keys(need.keys()):
		if Refits.stock(state, _holders, res) < int(need[res]):
			return reject("not enough %s here (%d needed)" % [res, int(need[res]) / Stockpile.MILLI])
	return true


func apply(state: MatchState) -> void:
	var d := Designs.owned(state, player_id, p_int("design"))
	for i in _ships.size():
		Refits.start(state, state.units.get_or(_ships[i]), d, _plans[i], _holders)
