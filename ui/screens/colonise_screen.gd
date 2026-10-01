class_name ColoniseScreen
extends ScreenPanel
## Colonise screen (F8): what settling a planet means before the order is given: habitability, housing,
## the colony ship that goes, reach to the nearest hub (D9), claim cost, early upkeep and a payback estimate.

var planet_id := 0


func _init() -> void:
	title_key = "COLONISE_TITLE"


func open_for(pid: int) -> void:
	planet_id = pid
	open()


func _fill(state: MatchState, eid: int) -> void:
	var p := state.galaxy.planet(planet_id)
	if p == null:
		return
	var db := state.defs
	var species: SpeciesDef = db.get_def(StringName(state.empire(eid).species))
	var hab := int(species.habitability.get(StringName(p.planet_type), 0))
	var size: PlanetSizeDef = db.get_def(PlanetSizeDef.id_for(p.size))
	var r := Economy.rules(db)
	line(UiKit.tr_fmt("COLONISE_PLANET", {"name": p.name, "type": UiNames.def_name(p.planet_type),
		"size": TranslationServer.translate("SIZE_" + p.size.to_upper())}), "Subtitle")
	line(UiKit.tr_fmt("COLONISE_HABITABILITY", {"species": UiNames.def_name(species.id), "pct": hab / 10,
		"housing": FixedMath.mul_permille(size.housing, hab)}))
	var ship_id := ContextPanel.idle_colony_ship(state, planet_id)
	var ship: Unit = state.units.get_or(ship_id)
	if ship != null:
		line(UiKit.tr_fmt("COLONISE_SHIP", {"at": state.galaxy.system(ship.system_id).name}))
	else:
		heading("COLONISE_NO_SHIP")
	var reach := int(Sectors.reach_map(state, eid).get(p.system_id, Sectors.FAR))
	var effects := Sectors.reach_effects(r, reach)
	var reach_text: String = UiKit.tr_fmt("COLONISE_REACH", {"n": reach}) if reach < Sectors.FAR else TranslationServer.translate("COLONISE_REACH_FAR")
	if effects[1] != 0:
		reach_text += "  " + UiKit.tr_fmt("COLONISE_REACH_PENALTY", {"stab": effects[1], "upkeep": effects[0] / 10})
	line(reach_text)
	if state.galaxy.system(p.system_id).owner == StateIO.NONE:
		line(UiKit.tr_fmt("COLONISE_CLAIM", {"n": UiKit.units(Colonisation.claim_cost_milli(state, eid)),
			"have": UiKit.units(int(state.empire(eid).treasury.get(Colonisation.INFLUENCE, 0)))}))
	line(UiKit.tr_fmt("COLONISE_UPKEEP", {"n": r.new_colony_upkeep_credits}))
	var months := Colonisation.payback_months(state, eid, planet_id)
	if months < 0:
		heading("COLONISE_PAYBACK_NEVER")
	else:
		line(UiKit.tr_fmt("COLONISE_PAYBACK", {"years": maxi(1, (months + 6) / 12),
			"date": Calendar.format(state.tick + months * Calendar.HOURS_PER_MONTH).get_slice("-", 0)}))
	var reason := Colonisation.check_colonise(state, eid, ship_id, planet_id)
	var go := button(TranslationServer.translate("COLONISE_GO"), "Go", func() -> void:
		CommandQueue.submit_new(CmdColonise.TYPE, {"unit": ship_id, "planet": planet_id})
		close())
	go.disabled = reason != ""
	if reason != "":
		heading("COLONISE_BLOCKED")  # the sim's reason strings are English log text, not loc keys
