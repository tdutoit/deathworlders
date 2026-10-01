class_name Freight
extends RefCounted
## Freighters carrying goods (main spec 6.3, Sub-spec B6–B8). Runs every hour after Movement, freighters in
## ID order. A route loop: fly to the source, load for a day, fly to the destination, unload for a day.
## Lane legs use Movement (path); a freighter arriving by lane is placed at its target body. In-system legs
## take Holders.impulse_days. Nothing is destroyed: what doesn't fit stays aboard, an empty source means a
## day's wait and a retry.

const DAY := Calendar.HOURS_PER_DAY


static func tick(state: MatchState) -> void:
	for uid: int in state.units:
		var u: Unit = state.units.get_or(uid)
		if u.kind != "freighter":
			continue
		if u.wait_hours > 0:
			u.wait_hours -= 1
			if u.wait_hours > 0:
				continue
			_wait_done(state, u)
		elif not u.is_moving():
			_decide(state, u)


## What the freighter is working for: its manual route, or its one-shot auto job, or {} when free.
## {source, dest, resource, amount (milli), auto (bool)}
static func plan(state: MatchState, u: Unit) -> Dictionary:
	if u.route != StateIO.NONE:
		var r: Route = state.routes.get_or(u.route)
		if r != null:
			return {"source": r.source, "dest": r.dest, "resource": r.resource, "amount": r.amount * Stockpile.MILLI, "auto": false}
	if not u.job.is_empty():
		return {"source": u.job["source"], "dest": u.job["dest"], "resource": u.job["resource"], "amount": u.job["amount"], "auto": true}
	return {}


static func _decide(state: MatchState, u: Unit) -> void:
	var p := plan(state, u)
	if p.is_empty() and u.phase == "" and (u.home == StateIO.NONE or u.body == Holders.body(state, u.home)):
		return  # idle at home
	if p.is_empty() and u.phase in ["to_source", "to_dest"]:
		u.phase = "home"  # its route was deleted or unassigned on the way
	if u.phase == "" or (u.phase == "home" and not p.is_empty()):
		u.phase = "to_source" if not p.is_empty() else ("home" if u.home != StateIO.NONE else "")
	match u.phase:
		"to_source":
			if _travel(state, u, p["source"]):
				u.phase = "loading"
				u.wait_hours = DAY
		"to_dest":
			if _travel(state, u, p["dest"]):
				u.phase = "unloading"
				u.wait_hours = DAY
		"home":
			if u.home == StateIO.NONE or _travel(state, u, u.home):
				u.phase = ""


## Moves the freighter toward a holder. Returns true once it is at the holder's body.
static func _travel(state: MatchState, u: Unit, holder: int) -> bool:
	var target_system := Holders.system(state, holder)
	var target_body := Holders.body(state, holder)
	if target_system == StateIO.NONE:
		return false
	if u.system_id != target_system:
		var path := Pathfinder.route(state.galaxy, u.system_id, target_system)
		if path.is_empty():
			return false
		u.path = path
		u.progress = 0
		u.body = StateIO.NONE
		return false
	if u.body == StateIO.NONE or state.galaxy.planet(u.body).system_id != target_system:
		u.body = target_body  # arrived by lane: straight to the body
	if u.body == target_body:
		return true
	u.impulse_to = target_body
	u.wait_hours = Holders.impulse_days(state, u.body, target_body) * DAY
	return false


static func _wait_done(state: MatchState, u: Unit) -> void:
	if u.impulse_to != StateIO.NONE:
		u.body = u.impulse_to
		u.impulse_to = StateIO.NONE
		_decide(state, u)
		return
	var p := plan(state, u)
	match u.phase:
		"loading":
			if p.is_empty():
				u.phase = "home"
			elif _load(state, u, p) > 0 or u.cargo_milli() > 0:
				u.phase = "to_dest"
			elif p["auto"]:
				u.job = {}  # the surplus is gone: give the job back, tomorrow's assignment finds another
				u.phase = "home"
			else:
				u.wait_hours = DAY  # manual route: nothing to load yet, try again tomorrow
				return
		"unloading":
			_unload(state, u, p["dest"] if not p.is_empty() else u.home)
			if not p.is_empty() and p["auto"]:
				u.job = {}
				u.phase = "home"
			else:
				u.phase = "to_source" if not p.is_empty() else "home"
	_decide(state, u)


static func capacity_milli(state: MatchState, u: Unit) -> int:
	var hull := state.defs.get_def(StringName(u.hull_id)) as HullDef
	return hull.cargo_capacity * Stockpile.MILLI if hull else 0


static func _load(state: MatchState, u: Unit, p: Dictionary) -> int:
	var src := Holders.stockpile(state, p["source"])
	if src == null:
		return 0
	var want := mini(int(p["amount"]), capacity_milli(state, u) - u.cargo_milli())
	if p["auto"]:  # auto-logistics never dips into the source's reserve (B8)
		want = mini(want, src.milli(p["resource"]) - AutoLogistics.reserve_milli(state, p["source"], p["resource"]))
	var got := src.take(p["resource"], maxi(0, want))
	if got > 0:
		u.cargo[p["resource"]] = u.cargo.get(p["resource"], 0) + got
	return got


static func _unload(state: MatchState, u: Unit, holder: int) -> void:
	var dst := Holders.stockpile(state, holder)
	if dst == null:
		return
	for res: String in IdMap.sort_keys(u.cargo.keys()):
		var space := Holders.space_milli(state, holder, res)
		var put: int = u.cargo[res] if space < 0 else mini(u.cargo[res], space)
		if put > 0:
			dst.add(res, put)
			u.cargo[res] -= put
			if u.cargo[res] <= 0:
				u.cargo.erase(res)


# --- planning helpers (shared with the UI, Sub-spec B7) ---

## One-way trip in days between two holders for a freighter hull: impulse days in-system, lane days between
## systems (lane units / lane speed per day, rounded up).
static func one_way_days(state: MatchState, from_holder: int, to_holder: int, hull: HullDef) -> int:
	var a := Holders.system(state, from_holder)
	var b := Holders.system(state, to_holder)
	if a == b:
		return Holders.impulse_days(state, Holders.body(state, from_holder), Holders.body(state, to_holder))
	var units := 0
	var at := a
	for next in Pathfinder.route(state.galaxy, a, b):
		units += state.galaxy.lane_between(at, next).length
		at = next
	var speed := maxi(1, hull.lane_speed)
	return FixedMath.floor_div(units + speed - 1, speed)  # rounded up


## B7: throughput per month = capacity * 30 / (2 * one_way + 2), for one freighter of this hull.
static func throughput(state: MatchState, r: Route, hull: HullDef) -> int:
	var round_trip := 2 * one_way_days(state, r.source, r.dest, hull) + 2
	return FixedMath.floor_div(hull.cargo_capacity * Calendar.DAYS_PER_MONTH, round_trip)
