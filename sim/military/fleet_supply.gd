class_name FleetSupply
extends RefCounted
## Daily warship supply (Sub-spec B12, A13; owner decisions 2026-10-01), ships in ID order:
##   - a ship is in supply when an own holder's supply range covers its system (Supply.sources_at);
##   - in supply: ammo refills from the nearest covering stockpiles, 1 munition per ammo_per_munition ammo;
##   - out of supply: after attrition_after_days, attrition_per_day of hull_max a day (a ship at 0 is lost);
##   - repair while not moving: repair_docked a day in a system with an own operational shipyard or supply
##     depot (paid from that station), else repair_field in supply range (paid from the covering stockpiles),
##     1 alloy per repair_hull_per_alloy hull points; armour comes back in proportion;
##   - shields refill fully outside battle.
## Fuel stays monthly (Supply.month_tick).

const MUNITIONS := "core:resource/munitions"
const ALLOYS := "core:resource/alloys"


static func day_tick(state: MatchState) -> void:
	var r := state.defs.get_def(CombatRulesDef.ID) as CombatRulesDef
	if r == null:
		return
	var points := {}  # owner -> Supply.own_supply_points (built in one pass for every owner, on first need)
	var sources_at := {}  # "owner:system" -> Supply.sources_at
	var usable := {}  # owner -> its supply points plus those of empires granting it military access (once a day)
	var docks := {}  # owner -> {system: [stockpile of each own operational shipyard / depot there]}
	var built := false
	for uid: int in state.units.keys():
		var u: Unit = state.units.get_or(uid)
		if u == null or u.kind != "warship" or u.owner < 0 or Battles.in_battle(state, u.id):
			continue  # no resupply or repair in battle
		if not built:
			points = Supply.all_supply_points(state)
			docks = _all_docks(state)
			built = true
		var key := "%d:%d" % [u.owner, u.system_id]
		if not sources_at.has(key):
			if not usable.has(u.owner):
				var pts: Array = (points.get(u.owner, []) as Array).duplicate()
				for other: int in state.empires.ordered():
					if other != u.owner and Treaties.has_effect(state, u.owner, other, "access"):
						pts.append_array(points.get(other, []))  # military access: their stockpiles supply us (E4)
				usable[u.owner] = pts
			sources_at[key] = Supply.sources_at(state, usable[u.owner], u.system_id)
		var st := ShipStats.cached(state.defs, u.hull_id, u.components, SpeciesTraits.source_of(state, u.owner))
		var sources: Array = sources_at[key]
		var in_supply := not sources.is_empty() and not u.is_moving()
		if not sources.is_empty():
			u.unsupplied_days = 0
			_refill_ammo(u, st, sources, r)
		else:
			u.unsupplied_days += 1
			if u.unsupplied_days > r.attrition_after_days:
				u.hp -= maxi(1, FixedMath.mul_permille(st.hull, r.attrition_per_day))
				if u.hp <= 0:
					_lose(state, u)
					continue
		u.shield = st.shield
		if not u.is_moving():
			var dock: Array = docks.get(u.owner, {}).get(u.system_id, [])
			if not dock.is_empty():
				_repair(u, st, r.repair_docked, dock, r)
			elif in_supply:
				_repair(u, st, r.repair_field, sources.map(func(e: Array) -> Stockpile: return e[2]), r)


static func _refill_ammo(u: Unit, st: ShipStats, sources: Array, r: CombatRulesDef) -> void:
	var missing := st.ammo - u.ammo
	for entry: Array in sources:
		if missing <= 0:
			break
		var sp: Stockpile = entry[2]
		var munitions_needed := FixedMath.floor_div(missing + r.ammo_per_munition - 1, r.ammo_per_munition)  # rounded up
		var whole := mini(munitions_needed, FixedMath.floor_div(sp.milli(MUNITIONS), Stockpile.MILLI))
		sp.take(MUNITIONS, whole * Stockpile.MILLI)
		var ammo := mini(missing, whole * r.ammo_per_munition)
		u.ammo += ammo
		missing -= ammo


## Repairs up to rate permille of hull_max, limited by the alloys the stockpiles can pay.
static func _repair(u: Unit, st: ShipStats, rate: int, stockpiles: Array, r: CombatRulesDef) -> void:
	var damage := st.hull - u.hp
	if damage <= 0 and u.armor >= st.armor:
		return
	var heal := mini(damage, maxi(1, FixedMath.mul_permille(st.hull, rate)))
	var alloys_needed := FixedMath.floor_div(heal + r.repair_hull_per_alloy - 1, r.repair_hull_per_alloy)
	var paid := 0
	for sp: Stockpile in stockpiles:
		if paid >= alloys_needed:
			break
		var whole := mini(alloys_needed - paid, FixedMath.floor_div(sp.milli(ALLOYS), Stockpile.MILLI))
		sp.take(ALLOYS, whole * Stockpile.MILLI)
		paid += whole
	heal = mini(heal, paid * r.repair_hull_per_alloy)
	if heal <= 0 and damage > 0:
		return
	u.hp += heal
	# Armour comes back in step with hull (a fully repaired hull means full armour).
	u.armor = st.armor if u.hp >= st.hull else mini(st.armor, u.armor + FixedMath.floor_div((st.armor - u.armor) * heal, maxi(1, damage)))


## {owner: {system: [stockpile]}} of every owner's operational shipyards and supply depots (docked repair),
## stations in ID order.
static func _all_docks(state: MatchState) -> Dictionary:
	var out := {}
	for sid: int in state.stations.ordered():
		var s: Station = state.stations.get_or(sid)
		if not s.operational:
			continue
		var fn := (state.defs.get_def(StringName(s.def_id)) as StationDef).function
		if fn == &"shipyard" or fn == &"depot":
			if not out.has(s.owner):
				out[s.owner] = {}
			if not out[s.owner].has(s.system_id):
				out[s.owner][s.system_id] = []
			out[s.owner][s.system_id].append(s.stockpile)
	return out


## A ship lost to attrition: out of its fleet and the match.
static func _lose(state: MatchState, u: Unit) -> void:
	Fleets.remove_ship(state, u)
	state.units.erase(u.id)
