class_name Fleets
extends RefCounted
## Fleet membership, the naval hierarchy and fleet movement (main spec 7.1, 7.6; owner decisions
## 2026-10-01): ships auto-group into squadrons of one class (capital classes first), squadrons into task
## forces, within combat_rules limits. A fleet's ships share one route and move at the fleet's speed: the
## slowest ship's hull speed in lane units per day, halved while any ship is out of fuel.

const CLASS_ORDER: Array[String] = ["battleship", "battlecruiser", "carrier", "cruiser", "destroyer", "assault",
	"frigate", "corvette"]


static func rules(state: MatchState) -> CombatRulesDef:
	return state.defs.get_def(CombatRulesDef.ID)


## Rebuilds the hierarchy from the fleet's ships: by class (CLASS_ORDER, then class name), then ship ID.
static func regroup(state: MatchState, f: Fleet) -> void:
	var r := rules(state)
	var ids := f.ships()
	ids.sort_custom(func(a: int, b: int) -> bool:
		var ka := _class_key(state, a)
		var kb := _class_key(state, b)
		return ka < kb or (ka == kb and a < b))
	var squads := []
	var last := ""
	for sid in ids:
		var key := _class_key(state, sid)
		if squads.is_empty() or key != last or (squads[-1] as Array).size() >= r.squadron_max:
			squads.append([] as Array[int])
		(squads[-1] as Array).append(sid)
		last = key
	f.task_forces = []
	for sq: Array in squads:
		if f.task_forces.is_empty() or (f.task_forces[-1] as Array).size() >= r.task_force_squadrons:
			f.task_forces.append([])
		(f.task_forces[-1] as Array).append(sq)


static func _class_key(state: MatchState, ship_id: int) -> String:
	var u: Unit = state.units.get_or(ship_id)
	var h := state.defs.get_def(StringName(u.hull_id)) as HullDef if u != null else null
	var cls := String(h.hull_class) if h != null else ""
	var rank := CLASS_ORDER.find(cls)
	return "%02d:%s" % [rank if rank >= 0 else CLASS_ORDER.size(), cls]


## Task forces these ships would need, auto-grouped (for the fleet size limit).
static func task_forces_needed(state: MatchState, ship_ids: Array) -> int:
	var probe := Fleet.new()
	probe.task_forces = [[ship_ids.duplicate()]]
	regroup(state, probe)
	return probe.task_forces.size()


static func fits(state: MatchState, ship_ids: Array) -> bool:
	return task_forces_needed(state, ship_ids) <= rules(state).fleet_task_forces


static func create(state: MatchState, owner: int, ship_ids: Array, name := "", reserve := false) -> Fleet:
	var f := Fleet.new()
	f.id = state.alloc_id()
	f.owner = owner
	f.name = name
	f.reserve = reserve
	state.fleets.put(f.id, f)
	add_ships(state, f, ship_ids)
	return f


## Moves ships into a fleet (leaving their old fleets) and regroups it.
static func add_ships(state: MatchState, f: Fleet, ship_ids: Array) -> void:
	var all := f.ships()
	for sid: int in ship_ids:
		var u: Unit = state.units.get_or(sid)
		if u.fleet != StateIO.NONE and u.fleet != f.id:
			remove_ship(state, u)
		u.fleet = f.id
		if not sid in all:
			all.append(sid)
	f.task_forces = [[all]]
	regroup(state, f)


## Takes a ship out of its fleet, keeping the rest of the hierarchy (empty squadrons and task forces go);
## an emptied fleet is removed.
static func remove_ship(state: MatchState, u: Unit) -> void:
	var f: Fleet = state.fleets.get_or(u.fleet)
	u.fleet = StateIO.NONE
	if f == null:
		return
	var tfs := []
	for tf: Array in f.task_forces:
		var squads := []
		for sq: Array in tf:
			var kept := sq.filter(func(x: int) -> bool: return x != u.id)
			if not kept.is_empty():
				squads.append(kept)
		if not squads.is_empty():
			tfs.append(squads)
	f.task_forces = tfs
	if tfs.is_empty():
		state.fleets.erase(f.id)


## The fleet's lead ship (its position and route stand for the fleet), or null.
static func lead(state: MatchState, f: Fleet) -> Unit:
	var ids := f.ships()
	return state.units.get_or(ids[0]) if not ids.is_empty() else null


static func is_moving(state: MatchState, f: Fleet) -> bool:
	var u := lead(state, f)
	return u != null and u.is_moving()


## Lane speed in milli-lane-units per hour: slowest hull speed (lane units/day), halved if any ship is out of
## fuel. Cached per tick.
static func move_speed(state: MatchState, fleet_id: int) -> int:
	var scratch := state.scratch()
	var key := "fleet_speed:%d" % fleet_id
	if not scratch.has(key):
		var f: Fleet = state.fleets.get_or(fleet_id)
		var slowest := -1
		var out_of_fuel := false
		if f != null:
			for sid in f.ships():
				var u: Unit = state.units.get_or(sid)
				var h := state.defs.get_def(StringName(u.hull_id)) as HullDef
				var sp := h.speed if h != null else 0
				slowest = sp if slowest < 0 else mini(slowest, sp)
				out_of_fuel = out_of_fuel or u.out_of_fuel
		var per_hour := FixedMath.floor_div(maxi(slowest, 0) * Movement.MILLI, Calendar.HOURS_PER_DAY)
		scratch[key] = FixedMath.floor_div(per_hour, 2) if out_of_fuel else per_hour
	return scratch[key]


## Gives every ship of the fleet the same route (they share a position, so they stay together).
static func set_route(state: MatchState, f: Fleet, route: Array[int]) -> void:
	for sid in f.ships():
		var u: Unit = state.units.get_or(sid)
		u.path = route.duplicate()
		if u.path.is_empty():
			u.progress = 0
	f.reserve = false  # a fleet that leaves stops collecting new ships


## A just-launched warship: full combat state from its design, then the system's reserve fleet (or a new one).
static func commission(state: MatchState, u: Unit) -> void:
	var st := ShipStats.of(state.defs, u.hull_id, u.components)
	u.hp = st.hull
	u.armor = st.armor
	u.shield = st.shield
	u.ammo = st.ammo
	u.crew = st.crew
	u.marines = st.marines
	for fid: int in state.fleets.ordered():
		var f: Fleet = state.fleets.get_or(fid)
		var l := lead(state, f)
		if f.owner == u.owner and f.reserve and l != null and l.system_id == u.system_id and not l.is_moving() \
				and fits(state, f.ships() + [u.id]):
			add_ships(state, f, [u.id])
			return
	create(state, u.owner, [u.id], "", true)
