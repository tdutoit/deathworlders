extends GutTest
# M4 WP2: signature mechanic framework (registry, hooks, per-empire state).

var _db: DefDatabase


class CountingMechanic extends SignatureMechanic:
	func init_state(_state: MatchState, e: Empire) -> void:
		e.mechanic = {"months": 0, "battles": 0, "commands": 0, "label": "test"}

	func month_tick(_state: MatchState, e: Empire) -> void:
		e.mechanic["months"] += 1

	func battle_resolved(_state: MatchState, e: Empire, _report: BattleReport) -> void:
		e.mechanic["battles"] += 1

	func command_applied(_state: MatchState, e: Empire, _cmd: Command) -> void:
		e.mechanic["commands"] += 1


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func after_each() -> void:
	SignatureMechanics.register(&"legend", LegendMechanic)


func _match() -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(settings, 3, _db, errors)


func test_core_registers_five_mechanics() -> void:
	assert_eq(SignatureMechanics.names(), [&"brood_surge", &"contracts", &"legend", &"precedence", &"sanctuary"])
	var s := _match()
	assert_true(SignatureMechanics.of(s, s.empires.values()[0]) is LegendMechanic, "humans: Legend")


func test_unknown_mechanic_fails_validation() -> void:
	var sp := SpeciesDef.new()
	sp.signature_mechanic = &"no_such_thing"
	assert_eq(sp.validate(_db).size(), 1)
	sp.signature_mechanic = &"contracts"
	assert_eq(sp.validate(_db).size(), 0)


func test_hooks_and_state() -> void:
	SignatureMechanics.register(&"legend", CountingMechanic)
	var s := _match()
	var e: Empire = s.empires.values()[0]
	assert_eq(e.mechanic.get("months"), 0, "state set up at match start")
	var none: Array[Command] = []
	for h in Calendar.HOURS_PER_MONTH + Sim.MONTH_PHASES + 1:
		Sim.step(s, none)
	assert_eq(e.mechanic["months"], 1, "monthly hook")
	var cmd := CommandRegistry.create(CmdPause.TYPE, e.id, {"paused": 1})
	Sim.execute(s, [cmd] as Array[Command])
	assert_eq(e.mechanic["commands"], 1, "command hook")
	var home := s.galaxy.planet(e.capital_planet).system_id
	var d: DesignDef = _db.get_def(&"core:design/human_cruiser_standard")
	var u := Shipyards.spawn(s, e.id, String(d.hull), home)
	u.components.assign(Array(d.components).map(func(c: StringName) -> String: return String(c)))
	Fleets.arm(s, u)
	Fleets.create(s, e.id, [u.id])
	Pirates.spawn_raider(s, home, e.id)
	for h in 120:
		s.clear_scratch()
		Battles.tick(s)
	assert_eq(e.mechanic["battles"], 1, "battle hook")
	var back := MatchState.from_dict(s.to_dict())
	assert_eq((back.empires.values()[0] as Empire).mechanic, e.mechanic, "saved")
	assert_eq(back.checksum(), s.checksum())
