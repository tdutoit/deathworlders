class_name ContractsMechanic
extends SignatureMechanic
## Contracts (Ohlan; main spec 10.1; M4 WP9, owner placeholders): hire a mercenary fleet (merc_hire credits,
## then merc_monthly a month: merc_ships Ohlan standard destroyers for merc_months, then they leave, or earlier
## when the fee can't be paid); convoy profit (convoy_profit permille of the value of goods Ohlan freighters
## deliver in deals) and contract income (contract_per_trade credits a month per trade agreement).
## State: {"mercs": [{"ships": [unit IDs], "until": tick}]}.

const DESIGN := "core:design/ohlan_destroyer_standard"
const CREDITS := "core:resource/credits"


func init_state(_state: MatchState, e: Empire) -> void:
	e.mechanic = {"mercs": []}


static func check_hire(state: MatchState, eid: int) -> String:
	var e := state.empire(eid)
	if not SignatureMechanics.of(state, e) is ContractsMechanic:
		return "only the Ohlan Consortium hires mercenaries"
	if int(e.treasury.get(CREDITS, 0)) < SignatureMechanics.rules(state).merc_hire * Stockpile.MILLI:
		return "needs %d credits" % SignatureMechanics.rules(state).merc_hire
	return ""


static func hire(state: MatchState, eid: int) -> void:
	var e := state.empire(eid)
	var r := SignatureMechanics.rules(state)
	e.treasury[CREDITS] = int(e.treasury.get(CREDITS, 0)) - r.merc_hire * Stockpile.MILLI
	var d := state.defs.get_def(StringName(DESIGN)) as DesignDef
	var home := state.galaxy.planet(e.capital_planet).system_id
	var ids := []
	for i in r.merc_ships:
		var u := Shipyards.spawn(state, eid, String(d.hull), home)
		u.components.assign(Array(d.components).map(func(x: StringName) -> String: return String(x)))
		Fleets.arm(state, u)
		ids.append(u.id)
	Fleets.create(state, eid, ids, "")
	var mercs: Array = e.mechanic.get("mercs", [])
	mercs.append({"ships": ids, "until": state.tick + r.merc_months * Calendar.HOURS_PER_MONTH})
	e.mechanic["mercs"] = mercs


func month_tick(state: MatchState, e: Empire) -> void:
	var r := SignatureMechanics.rules(state)
	var trades := 0
	for tid: int in state.treaties.ordered():
		var t: Treaty = state.treaties.get_or(tid)
		if (t.a == e.id or t.b == e.id) and Treaties.def_of(state, t.def_id).has("trade"):
			trades += 1
	e.treasury[CREDITS] = int(e.treasury.get(CREDITS, 0)) + trades * r.contract_per_trade * Stockpile.MILLI
	var keep := []
	for m: Dictionary in e.mechanic.get("mercs", []):
		var have := int(e.treasury.get(CREDITS, 0))
		if state.tick < int(m["until"]) and have >= r.merc_monthly * Stockpile.MILLI:
			e.treasury[CREDITS] = have - r.merc_monthly * Stockpile.MILLI
			keep.append(m)
			continue
		for sid: int in m["ships"]:
			var u: Unit = state.units.get_or(sid)
			if u != null and u.owner == e.id and not Battles.in_battle(state, u.id):
				Fleets.remove_ship(state, u)
				state.units.erase(u.id)
	e.mechanic["mercs"] = keep


func treaty_event(state: MatchState, e: Empire, event: Dictionary) -> void:
	if String(event.get("type", "")) != "goods_delivered":
		return
	var rd := state.defs.get_def(StringName(String(event["resource"]))) as ResourceDef
	if rd == null:
		return
	var value := FixedMath.floor_div(int(event["amount"]) * rd.base_value, 1000)  # milli-credits
	e.treasury[CREDITS] = int(e.treasury.get(CREDITS, 0)) + FixedMath.mul_permille(value, SignatureMechanics.rules(state).convoy_profit)


func meter(state: MatchState, e: Empire) -> Dictionary:
	var n := 0
	for m: Dictionary in e.mechanic.get("mercs", []):
		for sid: int in m["ships"]:
			if state.units.has(sid):
				n += 1
	return {"CONTRACTS_MERCENARIES": n}
