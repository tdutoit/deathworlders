class_name WarFooting
extends RefCounted
## War footing (Sub-spec D7; M4 WP7): one empire-wide lever. A change takes transition_days at half effect;
## leaving a Total War footing for Peace costs demob_stability for demob_months. Numbers: war_footing Defs and
## diplomacy_rules.

const PEACE := "core:war_footing/peace"


static func def_of(state: MatchState, e: Empire) -> WarFootingDef:
	return state.defs.get_def(StringName(e.footing)) as WarFootingDef


## Share of the footing's effect in force (permille): half during the transition (D7).
static func strength(state: MatchState, e: Empire) -> int:
	return 500 if state.tick < e.footing_until else 1000


## Job output bonus for a resource (permille), from the empire's footing.
static func output_permille(state: MatchState, e: Empire, res: String) -> int:
	var d := def_of(state, e) if e != null else null
	if d == null:
		return 0
	return FixedMath.mul_permille(int(d.output.get(StringName(res), 0)), strength(state, e))


## Empire-wide stability from the footing and a demobilisation dip.
static func stability(state: MatchState, e: Empire) -> int:
	var d := def_of(state, e) if e != null else null
	if d == null:
		return 0
	var s := FixedMath.mul_permille(d.stability, strength(state, e))
	if state.tick < e.demob_until:
		s += Relations.rules(state).demob_stability
	return s


## Exhaustion gain factor (permille) of the empire's footing; Stubborn humans use their own at Total War.
static func exhaustion_factor(state: MatchState, eid: int) -> int:
	var e := state.empire(eid)
	var d := def_of(state, e) if e != null else null
	if d == null:
		return 1000
	if d.total_war:
		var own := SpeciesTraits.empire_add(state, eid, "empire.total_war_exhaustion")
		if own > 0:
			return own
	return d.exhaustion_permille


## Changes the footing (transition clock restarts; Total War to Peace starts the demobilisation dip).
static func change(state: MatchState, e: Empire, footing: String) -> void:
	var r := Relations.rules(state)
	var old := def_of(state, e)
	var new := state.defs.get_def(StringName(footing)) as WarFootingDef
	if old != null and old.total_war and new.order == 0:
		e.demob_until = state.tick + r.demob_months * Calendar.HOURS_PER_MONTH
	e.footing = footing
	e.footing_until = state.tick + r.footing_transition_days * Calendar.HOURS_PER_DAY


## Monthly exhaustion from the footing (E7: +1 a month at Total War, while at war).
static func month_tick(state: MatchState) -> void:
	for eid: int in state.empires.ordered():
		var e: Empire = state.empires.get_or(eid)
		var d := def_of(state, e)
		if d == null or d.monthly_exhaustion <= 0:
			continue
		var at_war := false
		for wid: int in state.war_info.ordered():
			var w: War = state.war_info.get_or(wid)
			at_war = at_war or w.attacker == eid or w.defender == eid
		if at_war:
			var monthly := d.monthly_exhaustion
			var own := SpeciesTraits.empire_add(state, eid, "empire.total_war_exhaustion")
			if d.total_war and own > 0:
				monthly = FixedMath.mul_permille(monthly, own)
			e.war_exhaustion = clampi(e.war_exhaustion + monthly, 0, 100000)
