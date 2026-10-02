extends GutTest
# M4 WP5: deals (Sub-spec E6, B15).

var _db: DefDatabase
const ORE := "core:resource/ore"


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


## Player (human) and an AI (human species, so affinity +10). In contact.
func _match() -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	settings.add_player(1, "core:species/human", "ai")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, 3, _db, errors)
	var ids := _ids(s)
	Relations._meet(s, ids[0], ids[1])
	Relations._meet(s, ids[1], ids[0])
	return s


func _ids(s: MatchState) -> Array:
	var out := [0, 0]
	for e: Empire in s.empires.values():
		out[e.player_slot] = e.id
	return out


func _do(s: MatchState, eid: int, type: StringName, payload: Dictionary) -> Command:
	var c := CommandRegistry.create(type, eid, payload)
	if c.validate(s):
		c.apply(s)
	return c


func _credits(s: MatchState, eid: int) -> int:
	return int(s.empire(eid).treasury.get("core:resource/credits", 0))


func test_valuation() -> void:
	var s := _match()
	var ids := _ids(s)
	var once := {"giver": ids[0], "kind": "credits", "ref": "", "amount": 100, "months": 0}
	assert_eq(Deals.value(s, ids[1], once), 100, "credits at face value to the receiver")
	var monthly := once.duplicate()
	monthly["months"] = 10
	assert_eq(Deals.value(s, ids[1], monthly), 600, "recurring at 60% of the total (E6)")
	var given := once.duplicate()
	given["giver"] = ids[1]
	var greed := Treaties.personality(s, ids[1], "greed")
	assert_eq(Deals.value(s, ids[1], given), 100 * (500 + greed * 10) / 1000, "greed weighs what it gives up (E6)")
	assert_between(Deals.scarcity(s, ids[1], ORE), 500, 2000)


func test_checks() -> void:
	var s := _match()
	var ids := _ids(s)
	var goods := [{"giver": ids[0], "kind": "resource", "ref": ORE, "amount": 10, "months": 0}]
	assert_ne(Deals.check(s, ids[0], ids[1], goods), "", "goods need a trade agreement")
	Treaties.sign(s, ids[0], ids[1], "core:treaty/trade")
	assert_eq(Deals.check(s, ids[0], ids[1], goods), "")
	var home := s.galaxy.planet(s.empire(ids[0]).capital_planet).system_id
	assert_ne(Deals.check(s, ids[0], ids[1], [{"giver": ids[0], "kind": "system", "ref": str(home), "amount": 1, "months": 0}]), "",
		"the capital system can't be ceded")


func test_gift_and_credits() -> void:
	var s := _match()
	var ids := _ids(s)
	var before := [_credits(s, ids[0]), _credits(s, ids[1])]
	_do(s, ids[0], CmdProposeDeal.TYPE, {"to": ids[1], "items": [{"giver": ids[0], "kind": "credits", "ref": "", "amount": 100, "months": 0}]})
	assert_eq(_credits(s, ids[0]), before[0] - 100 * 1000)
	assert_eq(_credits(s, ids[1]), before[1] + 100 * 1000)
	assert_eq(int(Relations.of(s, ids[1], ids[0]).events["gift"][0]), 4, "+1 opinion per 25 credit-value (E2)")


func test_bad_deal_refused_good_deal_taken() -> void:
	var s := _match()
	var ids := _ids(s)
	s.empire(ids[1]).treasury["core:resource/credits"] = 5000 * 1000
	var greedy := [{"giver": ids[1], "kind": "credits", "ref": "", "amount": 3000, "months": 0},
		{"giver": ids[0], "kind": "credits", "ref": "", "amount": 10, "months": 0}]
	var before := _credits(s, ids[1])
	_do(s, ids[0], CmdProposeDeal.TYPE, {"to": ids[1], "items": greedy})
	assert_eq(_credits(s, ids[1]), before, "a lopsided deal is refused")
	var fair := [{"giver": ids[1], "kind": "credits", "ref": "", "amount": 50, "months": 0},
		{"giver": ids[0], "kind": "influence", "ref": "", "amount": 20, "months": 0}]
	s.empire(ids[0]).treasury["core:resource/influence"] = 100 * 1000
	_do(s, ids[0], CmdProposeDeal.TYPE, {"to": ids[1], "items": fair})
	assert_eq(_credits(s, ids[1]), before - 50 * 1000, "20 influence (worth 100) for 50 credits: taken")


func test_recurring_payments() -> void:
	var s := _match()
	var ids := _ids(s)
	var before := _credits(s, ids[1])
	Deals.execute(s, ids[0], ids[1], [{"giver": ids[0], "kind": "credits", "ref": "", "amount": 10, "months": 3}])
	for m in 4:
		s.tick += Calendar.HOURS_PER_MONTH
		Deals.month_tick(s)
	assert_eq(_credits(s, ids[1]), before + 30 * 1000, "three monthly payments")
	assert_eq(s.deals.size(), 0, "then done")


func test_goods_delivered_by_convoy() -> void:
	var s := _match()
	var ids := _ids(s)
	Treaties.sign(s, ids[0], ids[1], "core:treaty/trade")
	Deals.execute(s, ids[0], ids[1], [{"giver": ids[0], "kind": "resource", "ref": ORE, "amount": 20, "months": 0}])
	assert_eq(s.deliveries.size(), 1)
	var none: Array[Command] = []
	for h in Calendar.HOURS_PER_DAY * 365:  # 19 lanes between the capitals on this map
		Sim.step(s, none)
		if s.deliveries.is_empty():
			break
	assert_eq(s.deliveries.size(), 0, "delivered: unloaded at their capital (Freight hook)")
	assert_eq(s.deals.size(), 0)


func test_lost_convoy_fails_the_deal() -> void:
	var s := _match()
	var ids := _ids(s)
	Treaties.sign(s, ids[0], ids[1], "core:treaty/trade")
	Deals.execute(s, ids[0], ids[1], [{"giver": ids[0], "kind": "resource", "ref": ORE, "amount": 20, "months": 0}])
	Deals.day_tick(s)
	var dl: Delivery = s.deliveries.values()[0]
	assert_ne(dl.unit, StateIO.NONE, "a freighter took it")
	Pirates._lose(s, s.units.get_or(dl.unit))
	assert_eq(s.deals.size(), 0, "the deal failed")
	assert_eq(int(Relations.of(s, ids[1], ids[0]).events["deal_failed"][0]), -20)


func test_system_transfer() -> void:
	var s := _match()
	var ids := _ids(s)
	var home := s.galaxy.planet(s.empire(ids[0]).capital_planet).system_id
	var lid: int = s.galaxy.system(home).lane_ids[0]
	var sid := s.galaxy.lane(lid).other_end(home)
	s.galaxy.system(sid).owner = ids[0]
	var pid: int = s.galaxy.system(sid).planet_ids[0]
	var c := Colony.new()
	c.id = pid
	c.owner = ids[0]
	c.pops["core:species/human"] = 2
	s.colonies.put(pid, c)
	Deals.execute(s, ids[0], ids[1], [{"giver": ids[0], "kind": "system", "ref": str(sid), "amount": 1, "months": 0}])
	assert_eq(s.galaxy.system(sid).owner, ids[1])
	assert_eq(c.owner, ids[1], "the colony goes with it")
	assert_eq(int(c.pops["core:species/human"]), 2, "pops keep their species")
