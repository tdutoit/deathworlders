extends GutTest
# M3 WP4: fleet supply and attrition (Sub-spec B12, A13; owner decisions 2026-10-01).

const FUEL := "core:resource/fuel"
const MUNITIONS := "core:resource/munitions"
const ALLOYS := "core:resource/alloys"

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _match() -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(settings, 3, _db, errors)


func _human(s: MatchState) -> Empire:
	return s.empires.values()[0]


func _home(s: MatchState) -> int:
	return s.galaxy.planet(_human(s).capital_planet).system_id


func _ship(s: MatchState, cls: String, system: int) -> Unit:
	var d: DesignDef = _db.get_def(StringName("core:design/human_%s_standard" % cls))
	var u := Shipyards.spawn(s, _human(s).id, String(d.hull), system)
	u.components.assign(Array(d.components).map(func(c: StringName) -> String: return String(c)))
	Fleets.commission(s, u)
	return u


func _earth(s: MatchState) -> Colony:
	return s.colony(_human(s).capital_planet)


## A system n lanes from home.
func _at(s: MatchState, hops: int) -> int:
	var dist := AutoLogistics._hops_from(s, _home(s), {})
	for sid: int in IdMap.sort_keys(dist.keys()):
		if dist[sid] == hops:
			return sid
	return -1


func _dock(s: MatchState) -> Station:
	for st: Station in s.stations.values():
		if st.owner == _human(s).id and st.system_id == _home(s) and (_db.get_def(StringName(st.def_id)) as StationDef).function == &"shipyard":
			return st
	return null


func test_fuel_by_size_moving_and_idle() -> void:
	var s := _match()
	var u := _ship(s, "cruiser", _home(s))  # size M: 2 moving, 0.5 idle (B12)
	var total := func() -> int:
		var n := 0
		for h in AutoLogistics._own_holders(s, _human(s).id):
			n += Holders.stockpile(s, h).milli(FUEL)
		return n
	var before: int = total.call()
	Supply.month_tick(s)
	var freighter_fuel := 0
	for f: Unit in s.units.values():
		if f.kind == "freighter":
			freighter_fuel += int((_db.get_def(StringName(f.hull_id)) as HullDef).upkeep.get(&"core:resource/fuel", 0)) * 1000
	assert_eq(before - total.call() - freighter_fuel, 500, "idle cruiser: 0.5 fuel")
	u.moved = true
	before = total.call()
	Supply.month_tick(s)
	assert_eq(before - total.call() - freighter_fuel, 2000, "moving cruiser: 2 fuel")
	assert_false(u.moved, "reset each month")


func test_ammo_refills_from_munitions() -> void:
	var s := _match()
	var u := _ship(s, "destroyer", _home(s))  # missile pod: 20 ammo
	u.ammo = 0
	var before := _earth(s).stockpile.milli(MUNITIONS) + _dock(s).stockpile.milli(MUNITIONS)
	FleetSupply.day_tick(s)
	assert_eq(u.ammo, 20)
	var used := before - (_earth(s).stockpile.milli(MUNITIONS) + _dock(s).stockpile.milli(MUNITIONS))
	assert_eq(used, 10 * 1000, "1 munition per 2 ammo (B12)")


func test_out_of_supply_attrition_after_30_days() -> void:
	var s := _match()
	var far := _at(s, 4)
	var u := _ship(s, "cruiser", far)
	for d in 30:
		FleetSupply.day_tick(s)
	assert_eq(u.hp, 1500, "30 days of grace")
	assert_eq(u.unsupplied_days, 30)
	FleetSupply.day_tick(s)
	assert_eq(u.hp, 1500 - 15, "then 1% of hull a day")


func test_attrition_can_destroy_a_ship() -> void:
	var s := _match()
	var u := _ship(s, "corvette", _at(s, 4))
	u.unsupplied_days = 100
	u.hp = 1
	FleetSupply.day_tick(s)
	assert_null(s.units.get_or(u.id), "lost")
	assert_eq(s.fleets.values().filter(func(f: Fleet) -> bool: return u.id in f.ships()).size(), 0)


func test_docked_repair_costs_alloys() -> void:
	var s := _match()
	var u := _ship(s, "cruiser", _home(s))
	u.hp = 1000
	u.armor = 70
	_dock(s).stockpile.add(ALLOYS, 100 * 1000)
	var before := _dock(s).stockpile.milli(ALLOYS)
	FleetSupply.day_tick(s)
	assert_eq(u.hp, 1000 + 75, "5% of 1500 a day at a shipyard")
	assert_eq(before - _dock(s).stockpile.milli(ALLOYS), 4 * 1000, "75 hull at 20 per alloy, rounded up")
	assert_gt(u.armor, 70, "armour comes back with the hull")
	u.hp = 1490
	FleetSupply.day_tick(s)
	assert_eq(u.hp, 1500)
	assert_eq(u.armor, 140, "full hull, full armour")


func test_field_repair_in_supply_range() -> void:
	var s := _match()
	var u := _ship(s, "cruiser", _at(s, 1))  # the capital colony supplies 1 lane out
	u.hp = 1000
	FleetSupply.day_tick(s)
	assert_eq(u.hp, 1015, "1% a day in the field")
	assert_eq(u.unsupplied_days, 0)


func test_shields_refill_and_no_repair_while_moving() -> void:
	var s := _match()
	var u := _ship(s, "cruiser", _home(s))
	u.shield = 0
	u.hp = 1000
	u.path = [_at(s, 1)] as Array[int]
	FleetSupply.day_tick(s)
	assert_eq(u.shield, 450, "shields refill outside battle")
	assert_eq(u.hp, 1000, "no repair while moving")
