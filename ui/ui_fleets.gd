class_name UiFleets
extends RefCounted
## Fleet display helpers shared by the Fleets screen and the context panel (F5). Read-only.


## "1st Fleet" style default names follow the owner's fleet order; reserve fleets name their system.
static func name_of(state: MatchState, f: Fleet) -> String:
	if f.name != "":
		return f.name
	var l := Fleets.lead(state, f)
	if f.reserve and l != null:
		return UiKit.tr_fmt("FLEET_RESERVE_NAME", {"system": state.galaxy.system(l.system_id).name})
	var n := 0
	for fid: int in state.fleets.ordered():
		var other: Fleet = state.fleets.get_or(fid)
		if other.owner == f.owner:
			n += 1
		if other.id == f.id:
			break
	return UiKit.tr_fmt("FLEET_DEFAULT_NAME", {"n": n})


## Battle value (A1 cost) of the fleet's ships.
static func strength(state: MatchState, f: Fleet) -> int:
	return MilitaryAutopilot.strength(state, f)


## [hull now, hull max, ammo now, ammo max] summed over the fleet's ships.
static func condition(state: MatchState, f: Fleet) -> Array[int]:
	var out: Array[int] = [0, 0, 0, 0]
	for sid in f.ships():
		var u: Unit = state.units.get_or(sid)
		var st := ShipStats.cached(state.defs, u.hull_id, u.components, SpeciesTraits.source_of(state, u.owner))
		out[0] += u.hp
		out[1] += st.hull
		out[2] += u.ammo
		out[3] += st.ammo
	return out


## "3 Cruiser, 2 Destroyer" for a task force.
static func composition(state: MatchState, tf: Array) -> String:
	var counts := {}
	var order: Array[String] = []
	for sq: Array in tf:
		for sid: int in sq:
			var u: Unit = state.units.get_or(sid)
			var h := state.defs.get_def(StringName(u.hull_id)) as HullDef
			var cls := String(h.hull_class) if h != null else "?"
			if not counts.has(cls):
				order.append(cls)
			counts[cls] = int(counts.get(cls, 0)) + 1
	var parts: Array[String] = []
	for cls in order:
		parts.append("%d %s" % [counts[cls], TranslationServer.translate("CLASS_" + cls.to_upper())])
	return ", ".join(parts)


static func supplied(state: MatchState, f: Fleet) -> bool:
	for sid in f.ships():
		if (state.units.get_or(sid) as Unit).unsupplied_days > 0:
			return false
	return true


## Where the fleet is and what it is doing, one line.
static func status(state: MatchState, f: Fleet) -> String:
	var l := Fleets.lead(state, f)
	if l == null:
		return ""
	var at := state.galaxy.system(l.system_id).name
	if Battles.in_battle(state, l.id):
		return UiKit.tr_fmt("FLEET_STATUS_BATTLE", {"system": at})
	if f.mission == "patrol":
		return UiKit.tr_fmt("FLEET_STATUS_PATROL", {"system": at, "n": f.patrol.size()})
	if f.mission == "escort":
		return UiKit.tr_fmt("FLEET_STATUS_ESCORT", {"system": at, "hub": UiNames.holder(state, f.escort_hub)})
	if l.is_moving():
		return UiKit.tr_fmt("FLEET_STATUS_MOVING", {"system": at, "dest": state.galaxy.system(l.path[-1]).name})
	return UiKit.tr_fmt("FLEET_STATUS_IDLE", {"system": at})
