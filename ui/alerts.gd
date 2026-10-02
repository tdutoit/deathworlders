class_name Alerts
extends RefCounted
## Management by exception (Sub-spec D6, F12): the M2 alerts, derived from GameState on demand (read-only).
## Each alert: {"severity": URGENT/SOON/INFO, "key": loc key, "params": {...}, "kind"/"id": what to focus,
## "fix": {"type", "payload", "key", "params"} or {} when there is no one-click Command}.
## M2 has no per-alert history, so time-based triggers use what the state records (stalled_days, losses).

const URGENT := 0
const SOON := 1
const INFO := 2

const FOOD := "core:resource/food"
const STARVE_DAYS := 90  # D6: food hits 0 within 90 days
const STALL_DAYS := 14
const OVERFLOW_PERMILLE := 900
const UNEMPLOYED_MIN := 2
const LOW_STABILITY := 30
const LOSS_DAYS := 30
const FREIGHTER_HULL := "core:hull/freighter_light"


static func collect(state: MatchState, eid: int) -> Array:
	var out := []
	if state == null or state.empire(eid) == null:
		return out
	var e := state.empire(eid)
	if e.deficit_months > 0:
		out.append(_alert(URGENT, "ALERT_DEFICIT", {"n": e.deficit_months}, "", 0))
	for pid: int in state.colonies:
		var c: Colony = state.colonies.get_or(pid)
		if c.owner == eid:
			_colony_alerts(state, c, out)
	for sid: int in state.stations:
		var s: Station = state.stations.get_or(sid)
		if s.owner == eid:
			_station_alerts(state, s, out)
	_freighter_alerts(state, eid, out)
	for l: Dictionary in e.losses:
		if state.tick - int(l["tick"]) <= LOSS_DAYS * Calendar.HOURS_PER_DAY:
			out.append(_alert(SOON, "ALERT_CONVOY_LOST_FLEET" if l.get("by", "") == "fleet" else "ALERT_CONVOY_LOST",
				{"system": state.galaxy.system(int(l["system"])).name},
				"system", int(l["system"])))
	# M3: battles under way and recent battle reports.
	for bid: int in state.battles.ordered():
		var b: Battle = state.battles.get_or(bid)
		if b.side_of_owner(eid) >= 0:
			out.append(_alert(URGENT, "ALERT_BATTLE", {"system": state.galaxy.system(b.system_id).name}, "system", b.system_id))
	for rid: int in state.reports.ordered():
		var rep: BattleReport = state.reports.get_or(rid)
		var side: int = rep.side_of(eid)
		if side >= 0 and state.tick - int(rep.data["end_tick"]) <= LOSS_DAYS * Calendar.HOURS_PER_DAY:
			out.append(_alert(INFO, "ALERT_BATTLE_REPORT", {"system": state.galaxy.system(int(rep.data["system"])).name,
				"result": TranslationServer.translate("RESULT_" + String(rep.data["results"][side]).to_upper())},
				"system", int(rep.data["system"])))
	var raiders := Pirates.raiders_hunting(state, eid)
	if raiders > 0:
		out.append(_alert(SOON, "ALERT_PIRATES", {"n": raiders}, "", 0))
	for uid: int in state.units:
		var u: Unit = state.units.get_or(uid)
		if u.owner == eid and u.out_of_fuel:
			out.append(_alert(SOON, "ALERT_SUPPLY", {"name": state.galaxy.system(u.system_id).name}, "unit", u.id))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["severity"] != b["severity"]:
			return a["severity"] < b["severity"]
		return a["id"] < b["id"])
	return out


static func count(state: MatchState, eid: int) -> int:
	return collect(state, eid).size()


static func _colony_alerts(state: MatchState, c: Colony, out: Array) -> void:
	var name := state.galaxy.planet(c.id).name
	var stock := c.stockpile.milli(FOOD)
	var net := int(c.last_produced.get(FOOD, 0)) - int(c.last_consumed.get(FOOD, 0))
	if c.starving or (net < 0 and stock * Calendar.DAYS_PER_MONTH < -net * STARVE_DAYS):
		var days := 0 if c.starving else FixedMath.floor_div(stock * Calendar.DAYS_PER_MONTH, -net)
		var need := maxi(1, FixedMath.floor_div(-net * 3, Stockpile.MILLI))  # three months of the shortfall
		out.append(_alert(URGENT, "ALERT_STARVATION", {"name": name, "n": days}, "planet", c.id,
			_fix(CmdSetDemandTarget.TYPE, {"holder": c.id, "resource": FOOD, "target": need, "priority": 3},
				"FIX_ROUTE_FOOD", {"n": need, "name": name})))
	if not c.queue.is_empty() and c.queue[0].stalled_days >= STALL_DAYS:
		_stalled(state, c.id, name, c.queue[0], out)
	if c.unemployed() >= UNEMPLOYED_MIN:
		var next := Governor.next_building(state, c)
		var fix := {} if next == "" else _fix(CmdQueueBuilding.TYPE, {"planet": c.id, "building": next},
			"FIX_QUEUE_BUILDING", {"name": _def_name(state, next)})
		out.append(_alert(SOON, "ALERT_UNEMPLOYMENT", {"name": name, "n": c.unemployed()}, "planet", c.id, fix))
	if c.stability < LOW_STABILITY:
		out.append(_alert(SOON, "ALERT_STABILITY", {"name": name, "n": c.stability}, "planet", c.id))
	_overflow(state, c.id, name, c.stockpile, out)


static func _station_alerts(state: MatchState, s: Station, out: Array) -> void:
	var def: StationDef = state.defs.get_def(StringName(s.def_id))
	var name := TranslationServer.translate(def.name_key) + " · " + state.galaxy.planet(s.planet_id).name
	if s.build != null and s.build.stalled_days >= STALL_DAYS:
		_stalled(state, s.id, name, s.build, out)
	if s.operational and def.function == &"shipyard" and s.ship_queue.is_empty():
		var fix := {}
		if Shipyards.check_ship(state, s.owner, s.id, FREIGHTER_HULL) == "":
			fix = _fix(CmdQueueShip.TYPE, {"station": s.id, "hull": FREIGHTER_HULL}, "FIX_QUEUE_SHIP",
				{"name": _def_name(state, FREIGHTER_HULL)})
		out.append(_alert(INFO, "ALERT_SHIPYARD_IDLE", {"name": name}, "planet", s.planet_id, fix))
	if s.operational:
		_overflow(state, s.id, name, s.stockpile, out)


static func _stalled(state: MatchState, holder: int, name: String, b: Construction, out: Array) -> void:
	var today := b.today_need()
	var site := Holders.stockpile(state, holder)
	for res: String in IdMap.sort_keys(today.keys()):
		if site.milli(res) < int(today[res]):
			var paid := b.paid()
			var rest := maxi(1, FixedMath.floor_div(int(b.cost[res]) - int(paid.get(res, 0)) + Stockpile.MILLI - 1, Stockpile.MILLI))
			out.append(_alert(SOON, "ALERT_STALLED", {"name": name, "res": _def_name(state, res), "n": b.stalled_days},
				"planet", Holders.body(state, holder),
				_fix(CmdSetDemandTarget.TYPE, {"holder": holder, "resource": res, "target": rest, "priority": 3},
					"FIX_IMPORT", {"n": rest, "res": _def_name(state, res), "name": name})))
			return


static func _overflow(state: MatchState, holder: int, name: String, stock: Stockpile, out: Array) -> void:
	for res: String in IdMap.sort_keys(stock.amounts.keys()):
		var cap := Holders.cap_milli(state, holder, res)
		if cap > 0 and stock.milli(res) * 1000 >= cap * OVERFLOW_PERMILLE:
			out.append(_alert(INFO, "ALERT_OVERFLOW", {"name": name, "res": _def_name(state, res)}, "planet",
				Holders.body(state, holder)))


## Freighter shortage: every berthed freighter busy and none idle (no 30-day history in M2).
static func _freighter_alerts(state: MatchState, eid: int, out: Array) -> void:
	var total := 0
	var busy := 0
	for uid: int in state.units:
		var u: Unit = state.units.get_or(uid)
		if u.owner == eid and u.kind == "freighter":
			total += 1
			if not Freight.plan(state, u).is_empty():
				busy += 1
	if total > 0 and busy * 1000 > total * 950:
		var fix := {}
		for sid: int in state.stations:
			var s: Station = state.stations.get_or(sid)
			if s.owner == eid and Shipyards.check_ship(state, eid, s.id, FREIGHTER_HULL) == "":
				fix = _fix(CmdQueueShip.TYPE, {"station": s.id, "hull": FREIGHTER_HULL}, "FIX_QUEUE_SHIP",
					{"name": _def_name(state, FREIGHTER_HULL)})
				break
		out.append(_alert(SOON, "ALERT_FREIGHTERS", {"busy": busy, "n": total}, "", 0, fix))


static func _alert(severity: int, key: String, params: Dictionary, kind: String, id: int, fix := {}) -> Dictionary:
	return {"severity": severity, "key": key, "params": params, "kind": kind, "id": id, "fix": fix}


static func _fix(type: StringName, payload: Dictionary, key: String, params: Dictionary) -> Dictionary:
	return {"type": type, "payload": payload, "key": key, "params": params}


static func _def_name(state: MatchState, id: String) -> String:
	var def := state.defs.get_def(StringName(id))
	return TranslationServer.translate(def.name_key) if def else id
