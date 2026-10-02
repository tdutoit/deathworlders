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


static func treaty_event(state: MatchState, eid: int, event: Dictionary) -> void:
	var e := state.empire(eid)
	var m := of(state, e)
	if m != null:
		m.treaty_event(state, e, event)
