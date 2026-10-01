class_name ShipStats
extends RefCounted
## A design's effective combat stats and cost (Sub-spec A1, C5): hull values plus its modules' SHIP-scope
## modifiers, summed per key and applied once (A0): final = (base + sum ADD) * (1000 + sum PERMILLE) / 1000.
## Pure function of content: hull ID + component IDs.

const ARMOR := &"ship.armor"
const SHIELD := &"ship.shield"
const PD := &"ship.pd"
const CREW := &"ship.crew"
const MARINES := &"ship.marines"
const ECM := &"ship.ecm"
const EVASION := &"ship.evasion"

var hull_id := ""
var size: StringName = &"S"
var hull_class: StringName
var hull := 0  # hull_max
var armor := 0
var shield := 0  # shield_max
var shield_regen := 0  # permille of shield_max per round
var evasion := 0
var speed := 0
var pd := 0
var crew := 0
var marines := 0
var ecm := 0  # ECM suites
var ammo := 0  # ammo_max
var weapons: Array[ComponentDef] = []  # weapon and hangar components, slot order


## Stats for a hull and its components ("" = empty slot). Unknown IDs are skipped (validation reports them).
static func of(db: DefDatabase, hull_id: String, components: Array) -> ShipStats:
	var st := ShipStats.new()
	var h := db.get_def(StringName(hull_id)) as HullDef
	if h == null:
		return st
	var rules := db.get_def(CombatRulesDef.ID) as CombatRulesDef
	var add := {}
	var per := {}
	for cid: Variant in components:
		var c := db.get_def(StringName(cid)) as ComponentDef if String(cid) != "" else null
		if c == null:
			continue
		if c.is_weapon():
			st.weapons.append(c)
		for m: ModifierDef in c.modifiers:
			if m.mode == ModifierDef.Mode.ADD:
				add[m.key] = int(add.get(m.key, 0)) + m.value
			else:
				per[m.key] = int(per.get(m.key, 0)) + m.value
	var resolve := func(key: StringName, base: int) -> int:
		return FixedMath.mul_permille(base + int(add.get(key, 0)), 1000 + int(per.get(key, 0)))
	st.hull_id = hull_id
	st.size = h.size
	st.hull_class = h.hull_class
	st.hull = h.hull
	st.armor = resolve.call(ARMOR, h.armor)
	st.shield = resolve.call(SHIELD, h.shield)
	st.shield_regen = h.shield_regen if h.shield_regen > 0 else (rules.shield_regen if rules else 0)
	st.evasion = resolve.call(EVASION, h.evasion)
	st.speed = h.speed
	st.pd = resolve.call(PD, h.pd)
	var base_crew := h.crew if h.crew > 0 else (int(rules.crew_by_size.get(h.size, 0)) if rules else 0)
	st.crew = resolve.call(CREW, base_crew)
	st.marines = resolve.call(MARINES, 0)
	st.ecm = resolve.call(ECM, 0)
	for w in st.weapons:
		var fam := db.get_def(w.family) as WeaponFamilyDef
		if w.ammo_per_shot > 0 or (fam != null and fam.uses_ammo):
			st.ammo += rules.ammo_per_weapon if rules else 0
	return st


## Resource cost (whole units, before pace): hull plus every component.
static func cost(db: DefDatabase, hull_id: String, components: Array) -> Dictionary:
	var out := {}
	var h := db.get_def(StringName(hull_id)) as HullDef
	if h != null:
		for res: StringName in h.cost:
			out[String(res)] = int(out.get(String(res), 0)) + int(h.cost[res])
	for cid: Variant in components:
		var c := db.get_def(StringName(cid)) as ComponentDef if String(cid) != "" else null
		if c == null:
			continue
		for res: StringName in c.cost:
			out[String(res)] = int(out.get(String(res), 0)) + int(c.cost[res])
	return out
