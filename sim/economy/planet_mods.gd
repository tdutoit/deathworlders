class_name PlanetMods
extends RefCounted
## Modifier sums for one colony (Sub-spec C4): from its buildings (not the one on strike), employed jobs
## (per pop), Primary focus, Secondary focus (at the rules' share) and the matching synergy.
## Built once per colony per tick: get(key) -> [add, permille].

var _sums := {}  # key -> [add, permille]


static func of(c: Colony, db: DefDatabase) -> PlanetMods:
	var m := PlanetMods.new()
	var rules: EconomyRulesDef = db.get_def(EconomyRulesDef.ID)
	for i in c.buildings.size():
		if i != c.offline_building:
			m._add_all((db.get_def(StringName(c.buildings[i])) as Def).modifiers, 1, 1000)
	for job: String in IdMap.sort_keys(c.jobs.keys()):
		m._add_all((db.get_def(StringName(job)) as Def).modifiers, c.jobs[job], 1000)
	if c.primary_focus != "":
		m._add_all((db.get_def(StringName(c.primary_focus)) as Def).modifiers, 1, 1000)
	if c.secondary_focus != "":
		m._add_all((db.get_def(StringName(c.secondary_focus)) as Def).modifiers, 1, rules.secondary_focus_permille)
	var syn := synergy(c, db)
	if syn != null:
		m._add_all(syn.modifiers, 1, 1000)
	return m


## The synergy matching the colony's focus pair, or null.
static func synergy(c: Colony, db: DefDatabase) -> SynergyDef:
	if c.primary_focus == "" or c.secondary_focus == "":
		return null
	for def in db.defs("synergy"):
		var s: SynergyDef = def
		if s.matches(StringName(c.primary_focus), StringName(c.secondary_focus)):
			return s
	return null


func _add_all(mods: Array[ModifierDef], times: int, share_permille: int) -> void:
	for mod in mods:
		if not _sums.has(mod.key):
			_sums[mod.key] = [0, 0]
		var v := FixedMath.mul_permille(mod.value * times, share_permille)
		if mod.mode == ModifierDef.Mode.ADD:
			_sums[mod.key][0] += v
		else:
			_sums[mod.key][1] += v


func add(key: String) -> int:
	return _sums.get(StringName(key), [0, 0])[0]


func permille(key: String) -> int:
	return _sums.get(StringName(key), [0, 0])[1]


## (base + add) * (1000 + permille) / 1000, floored (C4 resolution).
func resolve(key: String, base: int) -> int:
	return FixedMath.mul_permille(base + add(key), 1000 + permille(key))
