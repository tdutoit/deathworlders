class_name SanctuaryMechanic
extends SignatureMechanic
## Sanctuary (Thessari; main spec 10.1; M4 WP9, owner placeholders): every Thessari colony with
## sanctuary_min_pops pops keeps planetary defences (core:station/planetary_defence, armed like a defensive
## platform, free, not buildable): one per sanctuary_pops_per_platform pops, at least one; they fight in battles
## in its system. Every other empire's opinion of the Thessari +sanctuary_opinion; defence pacts, alliances and
## protectorates proposed to them +sanctuary_acceptance (E5).

const STATION := "core:station/planetary_defence"


## Monthly: planetary defences follow each colony's pops (added or removed to match).
func month_tick(state: MatchState, e: Empire) -> void:
	var r := SignatureMechanics.rules(state)
	var have := {}  # planet ID -> [station IDs]
	for sid: int in state.stations.ordered():
		var st: Station = state.stations.get_or(sid)
		if st.def_id == STATION:
			if st.owner != e.id or state.colony(st.planet_id) == null or state.colony(st.planet_id).owner != e.id:
				if st.owner == e.id:
					state.stations.erase(sid)  # its colony is gone
				continue
			have[st.planet_id] = (have.get(st.planet_id, []) as Array) + [sid]
	for pid: int in state.colonies.ordered():
		var c: Colony = state.colonies.get_or(pid)
		if c.owner != e.id:
			continue
		var want := 0
		if c.total_pops() >= r.sanctuary_min_pops:
			want = maxi(1, FixedMath.floor_div(c.total_pops(), r.sanctuary_pops_per_platform))
		var current: Array = have.get(pid, [])
		while current.size() > want:
			var gone: int = current.pop_back()
			if not Battles.in_battle(state, gone):
				state.stations.erase(gone)
		for i in want - current.size():
			var st := Station.new()
			st.id = state.alloc_id()
			st.def_id = STATION
			st.owner = e.id
			st.planet_id = pid
			st.system_id = state.galaxy.planet(pid).system_id
			st.operational = true
			state.stations.put(st.id, st)
			Battles.arm_station(state, st)


func opinion_from(state: MatchState, e: Empire, viewer: int) -> int:
	return SignatureMechanics.rules(state).sanctuary_opinion if viewer != e.id else 0


func acceptance_bonus(state: MatchState, _e: Empire, _proposer: int, def_id: String) -> int:
	var d := Treaties.def_of(state, def_id) if def_id != "" else null
	if d != null and (d.has("call_to_arms") or d.has("protectorate")):
		return SignatureMechanics.rules(state).sanctuary_acceptance
	return 0


func meter(state: MatchState, e: Empire) -> Dictionary:
	var n := 0
	for sid: int in state.stations.ordered():
		var st: Station = state.stations.get_or(sid)
		if st.def_id == STATION and st.owner == e.id:
			n += 1
	return {"SANCTUARY_DEFENCES": n}
