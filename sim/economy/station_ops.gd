class_name StationOps
extends RefCounted
## Station economy (main spec 5, Sub-spec B5/B11/B13): mining output into the station's own stockpile and
## monthly upkeep. A Mining focus on an own colony in the system boosts its stations (B11: +250 permille at
## Primary, half at Secondary).

const MINING_FOCUS := "core:focus/mining"
const MINING_BONUS_PERMILLE := 250  # B11


static func cap_milli(state: MatchState, s: Station, res: String) -> int:
	var def: StationDef = state.defs.get_def(StringName(s.def_id))
	if not s.operational:
		return 0  # construction sites accept whatever is delivered
	var rdef := state.defs.get_def(StringName(res)) as ResourceDef
	if rdef != null and not rdef.physical:
		return 0
	return def.stockpile_cap * Stockpile.MILLI


static func day_tick(state: MatchState, day: int) -> void:
	for sid: int in state.stations:
		var s: Station = state.stations.get_or(sid)
		if not s.operational:
			continue
		var def: StationDef = state.defs.get_def(StringName(s.def_id))
		if def.outputs.is_empty():
			continue
		var permille := 1000 + mining_bonus(state, s)
		for res: StringName in IdMap.sort_keys(def.outputs.keys()):
			var total := FixedMath.mul_permille(int(def.outputs[res]) * Stockpile.MILLI, permille)
			s.stockpile.add(String(res), Economy.share(total, day), cap_milli(state, s, String(res)))


static func mining_bonus(state: MatchState, s: Station) -> int:
	var r := Economy.rules(state.defs)
	var best := 0
	for pid in state.galaxy.system(s.system_id).planet_ids:
		var c := state.colony(pid)
		if c == null or c.owner != s.owner:
			continue
		if c.primary_focus == MINING_FOCUS:
			best = maxi(best, MINING_BONUS_PERMILLE)
		elif c.secondary_focus == MINING_FOCUS:
			best = maxi(best, FixedMath.mul_permille(MINING_BONUS_PERMILLE, r.secondary_focus_permille))
	return best


## Monthly credits upkeep of every operational station, per owner (milli-credits).
static func upkeep(state: MatchState) -> Dictionary:
	var due := {}
	for sid: int in state.stations:
		var s: Station = state.stations.get_or(sid)
		if not s.operational:
			continue
		var def: StationDef = state.defs.get_def(StringName(s.def_id))
		for res: StringName in def.upkeep:
			if res == &"core:resource/credits":
				due[s.owner] = due.get(s.owner, 0) + int(def.upkeep[res]) * Stockpile.MILLI
	return due
