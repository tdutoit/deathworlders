class_name SignatureMechanics
extends RefCounted
## Registry and dispatch for signature mechanics (M4 WP2). A species names its mechanic in
## `SpeciesDef.signature_mechanic`; the name maps to a SignatureMechanic script. Core registers the five
## species mechanics (filled in by WP9); mods and tests can register more with `register` before a match.

static var _scripts := {
	&"legend": LegendMechanic,
	&"precedence": PrecedenceMechanic,
	&"brood_surge": BroodSurgeMechanic,
	&"contracts": ContractsMechanic,
	&"sanctuary": SanctuaryMechanic,
}
static var _instances := {}  # name -> SignatureMechanic (stateless)


static func register(mechanic: StringName, script: GDScript) -> void:
	_scripts[mechanic] = script
	_instances.erase(mechanic)


static func names() -> Array:
	return IdMap.sort_keys(_scripts.keys())


static func has(mechanic: StringName) -> bool:
	return _scripts.has(mechanic)


## The empire's mechanic, or null (no species, or none set).
static func of(state: MatchState, e: Empire) -> SignatureMechanic:
	var sd := state.defs.get_def(StringName(e.species)) as SpeciesDef if state.defs != null and e != null else null
	if sd == null or not _scripts.has(sd.signature_mechanic):
		return null
	if not _instances.has(sd.signature_mechanic):
		_instances[sd.signature_mechanic] = (_scripts[sd.signature_mechanic] as GDScript).new()
	return _instances[sd.signature_mechanic]


static func init_all(state: MatchState) -> void:
	for eid: int in state.empires.ordered():
		var e: Empire = state.empires.get_or(eid)
		var m := of(state, e)
		if m != null and e.mechanic.is_empty():
			m.init_state(state, e)


static func rules(state: MatchState) -> SignatureRulesDef:
	return state.defs.get_def(SignatureRulesDef.ID) as SignatureRulesDef


static func day_tick(state: MatchState) -> void:
	for eid: int in state.empires.ordered():
		var e: Empire = state.empires.get_or(eid)
		var m := of(state, e)
		if m != null:
			m.day_tick(state, e)


static func opinion_from(state: MatchState, target: int, viewer: int) -> int:
	var e := state.empire(target)
	var m := of(state, e)
	return m.opinion_from(state, e, viewer) if m != null else 0


static func acceptance_bonus(state: MatchState, target: int, proposer: int, def_id: String) -> int:
	var e := state.empire(target)
	var m := of(state, e)
	return m.acceptance_bonus(state, e, proposer, def_id) if m != null else 0


static func peace_discount(state: MatchState, eid: int) -> int:
	var e := state.empire(eid)
	var m := of(state, e)
	return m.peace_discount(state, e) if m != null else 0


static func output_permille(state: MatchState, eid: int) -> int:
	var e := state.empire(eid)
	var m := of(state, e)
	return m.output_permille(state, e) if m != null else 0


static func containment_target(state: MatchState, eid: int) -> bool:
	var e := state.empire(eid)
	var m := of(state, e)
	return m != null and m.containment_target(state, e)


static func auto_recognition(state: MatchState, eid: int) -> bool:
	var e := state.empire(eid)
	var m := of(state, e)
	return m != null and m.auto_recognition(state, e)


static func month_tick(state: MatchState) -> void:
	for eid: int in state.empires.ordered():
		var e: Empire = state.empires.get_or(eid)
		var m := of(state, e)
		if m != null:
			if e.mechanic.is_empty():
				m.init_state(state, e)
			m.month_tick(state, e)


static func battle_resolved(state: MatchState, report: BattleReport) -> void:
	for owner: int in report.all_owners():
		var e := state.empire(owner) if owner >= 0 else null
		var m := of(state, e)
		if m != null:
			m.battle_resolved(state, e, report)


static func command_applied(state: MatchState, cmd: Command) -> void:
	var e := state.empire(cmd.player_id) if cmd.player_id >= 0 else null
	var m := of(state, e)
	if m != null:
		m.command_applied(state, e, cmd)


static func council_votes(state: MatchState, eid: int) -> int:
	var e := state.empire(eid)
	var m := of(state, e)
	return m.council_votes(state, e) if m != null else 0


## True if any member's mechanic vetoes this passed proposal (members in ID order).
static func council_veto(state: MatchState, proposal: Dictionary) -> bool:
	for eid: int in state.council.members:
		var e := state.empire(eid)
		var m := of(state, e)
		if m != null and m.council_veto(state, e, proposal):
			return true
	return false


static func treaty_event(state: MatchState, eid: int, event: Dictionary) -> void:
	var e := state.empire(eid)
	var m := of(state, e)
	if m != null:
		m.treaty_event(state, e, event)
