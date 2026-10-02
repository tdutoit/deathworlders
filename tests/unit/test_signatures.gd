extends GutTest
# M4 WP9: the five signature mechanics.

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


## Slot 0 = `species` (player), slot 1 = Krothi AI, slot 2 = Thessari AI; all in contact.
func _match(species: String, control := "human") -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/" + species, control)
	settings.add_player(1, "core:species/krothi", "ai")
	settings.add_player(2, "core:species/thessari", "ai")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, 3, _db, errors)
	var ids := _ids(s)
	for a in ids:
		for b in ids:
			if a != b:
				Relations._meet(s, a, b)
	return s


func _ids(s: MatchState) -> Array:
	var out := [0, 0, 0]
	for e: Empire in s.empires.values():
		out[e.player_slot] = e.id
	return out


func _do(s: MatchState, eid: int, type: StringName, payload: Dictionary) -> Command:
	var c := CommandRegistry.create(type, eid, payload)
	if c.validate(s):
		c.apply(s)
	return c


# --- Legend ---

func test_legend_events_and_effects() -> void:
	var s := _match("human")
	var ids := _ids(s)
	var h := s.empire(ids[0])
	assert_eq(LegendMechanic.respect(h), 100)
	var t := Treaties.sign(s, ids[0], ids[1], "core:treaty/nonaggression")
	Treaties.break_treaty(s, t, ids[0])
	assert_eq(LegendMechanic.respect(h), 0, "breaking a treaty: Respect -100")
	assert_eq(LegendMechanic.fear(h), 130, "Fear +30")
	Wars.declare(s, ids[0], ids[1], "")
	assert_eq(LegendMechanic.fear(h), 180, "war without casus belli: Fear +50")
	h.mechanic["fear"] = 800
	h.mechanic["respect"] = 800
	assert_eq(SignatureMechanics.opinion_from(s, ids[0], ids[2]), 20 - 20 + 10, "Respect/40 - Fear/40 + 10 at Respect 600")
	assert_eq(SignatureMechanics.peace_discount(s, ids[0]), 20, "Fear 600: peace 20 cheaper")
	assert_true("containment" in Wars.casus_belli(s, ids[2], ids[0]), "Fear 800: containment")
	Councils.month_tick(s)
	assert_true(ids[0] in s.council.members, "Respect 800: recognised")


func test_legend_kept_treaty() -> void:
	var s := _match("human")
	var ids := _ids(s)
	var t := Treaties.sign(s, ids[0], ids[2], "core:treaty/trade")
	s.tick = t.start_tick + 10 * Calendar.HOURS_PER_YEAR
	SignatureMechanics.month_tick(s)
	SignatureMechanics.month_tick(s)
	assert_eq(LegendMechanic.respect(s.empire(ids[0])), 120, "kept 10 years: +20, once")


# --- Precedence ---

func test_precedence_votes_veto_and_stagnation() -> void:
	var s := _match("vesskar", "ai")
	var ids := _ids(s)
	var v := s.empire(ids[0])
	assert_true(Councils.is_member(s, ids[0]))
	assert_gte(Councils.votes(s, ids[0]), 3, "1 + Precedence 2")
	s.council.members.append(ids[1])
	s.empire(ids[1]).treasury["core:resource/influence"] = 100 * 1000
	Councils.propose(s, ids[1], "core:resolution/sanctions", ids[0], -1)
	s.council.proposals[0]["votes"][str(ids[0])] = -1
	assert_true(SignatureMechanics.council_veto(s, s.council.proposals[0]), "sanctions on themselves: vetoed")
	assert_false(SignatureMechanics.council_veto(s, s.council.proposals[0]), "one veto a session")
	v.mechanic["last_adapt"] = s.tick - 8 * Calendar.HOURS_PER_YEAR
	SignatureMechanics.month_tick(s)
	assert_eq(SignatureMechanics.output_permille(s, ids[0]), -60, "8 years: 3 points beyond 5, -2% each")
	Treaties.sign(s, ids[0], ids[2], "core:treaty/nonaggression")
	assert_eq(SignatureMechanics.output_permille(s, ids[0]), 0, "adapting resets it")


# --- Brood Surge ---

func test_brood_surge() -> void:
	var s := _match("krothi")
	var ids := _ids(s)
	var c := s.colony(s.empire(ids[0]).capital_planet)
	c.stockpile.add("core:resource/components", 100 * 1000)
	var pops := c.total_pops()
	assert_gte(pops, 6, "a capital has 6+ pops")
	var ships := s.units.values().filter(func(u: Unit) -> bool: return u.owner == ids[0] and u.kind == "warship").size()
	_do(s, ids[0], CmdBroodSurge.TYPE, {"colony": c.id})
	assert_eq(c.total_pops(), pops - 2, "two pops")
	assert_ne(_do(s, ids[0], CmdBroodSurge.TYPE, {"colony": c.id}).error, "", "once per 6 months")
	for d in 15:
		s.tick += Calendar.HOURS_PER_DAY
		SignatureMechanics.day_tick(s)
	var after := s.units.values().filter(func(u: Unit) -> bool: return u.owner == ids[0] and u.kind == "warship").size()
	assert_eq(after, ships + 1, "a corvette after 15 days")
	assert_ne(_do(s, ids[2], CmdBroodSurge.TYPE, {"colony": s.empire(ids[2]).capital_planet}).error, "", "Thessari can't surge")


# --- Contracts ---

func test_contracts() -> void:
	var s := _match("ohlan")
	var ids := _ids(s)
	var e := s.empire(ids[0])
	e.treasury["core:resource/credits"] = 1000 * 1000
	_do(s, ids[0], CmdHireMercenaries.TYPE, {})
	assert_eq(int(e.treasury["core:resource/credits"]), 700 * 1000, "300 credits")
	assert_eq(int(SignatureMechanics.of(s, e).meter(s, e)["CONTRACTS_MERCENARIES"]), 3)
	Treaties.sign(s, ids[0], ids[2], "core:treaty/trade")
	SignatureMechanics.month_tick(s)
	assert_eq(int(e.treasury["core:resource/credits"]), (700 + 3 - 30) * 1000, "+3 per trade agreement, -30 fee")
	SignatureMechanics.treaty_event(s, ids[0], {"type": "goods_delivered", "resource": "core:resource/alloys", "amount": 100 * 1000})
	assert_eq(int(e.treasury["core:resource/credits"]), (673 + 15) * 1000, "5% of 300 credits of alloys")
	s.tick += 13 * Calendar.HOURS_PER_MONTH
	SignatureMechanics.month_tick(s)
	assert_eq(int(SignatureMechanics.of(s, e).meter(s, e)["CONTRACTS_MERCENARIES"]), 0, "gone after a year")


# --- Sanctuary ---

func test_sanctuary() -> void:
	var s := _match("thessari")
	var ids := _ids(s)
	var c := s.colony(s.empire(ids[0]).capital_planet)
	SignatureMechanics.month_tick(s)
	var defences := func() -> int: return s.stations.values().filter(func(st: Station) -> bool: return st.def_id == SanctuaryMechanic.STATION and st.owner == ids[0]).size()
	var want := maxi(1, c.total_pops() / 10) if c.total_pops() >= 5 else 0
	assert_eq(defences.call(), want, "one per 10 pops, at least one at 5")
	var st: Station = s.stations.values().filter(func(x: Station) -> bool: return x.def_id == SanctuaryMechanic.STATION)[0]
	assert_gt(st.hp, 0, "armed")
	assert_true(Battles.is_armed_station(s, st))
	assert_eq(SignatureMechanics.opinion_from(s, ids[0], ids[1]), 10)
	assert_eq(SignatureMechanics.acceptance_bonus(s, ids[0], ids[1], "core:treaty/defence_pact"), 10)
	assert_eq(SignatureMechanics.acceptance_bonus(s, ids[0], ids[1], "core:treaty/trade"), 0)
	assert_ne(BuildRules.check_station(s, ids[0], c.id, SanctuaryMechanic.STATION), "", "not buildable")
