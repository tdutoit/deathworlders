class_name TechDef
extends Def
## A research tech (main spec 8, Sub-spec B14, C `tech` row; M5 WP1). Researching it applies its modifiers to
## the owning empire (each key's scope decides who reads it, as for traits) and unlocks every hull, component,
## building, station and treaty whose `requires_tech` lists it. The unlock list is derived from those fields
## (TechTree.unlocks) rather than stored twice. Tier rule (B14): a tech of tier N > 1 needs
## `research_rules.tier_prereqs` researched techs of tier N-1 in its branch, plus its own `prereqs`.

const BRANCHES: Array[String] = ["physics", "engineering", "logistics", "society", "military", "xeno"]
const CONDITIONS: Array[String] = ["hull_class", "hull", "planet_size", "resource", "tech"]

@export var branch: StringName
@export var tier: int = 1
@export var cost: int  # research points before pace
@export var prereqs: Array[StringName] = []  # tech IDs needed besides the tier rule
@export var exclusive_with: Array[StringName] = []  # researching this locks these for the match
@export var species_only: Array[StringName] = []  # species IDs that may research it; empty = everyone


func category() -> String:
	return "tech"


func schema() -> Dictionary:
	return {
		"branch": {"type": "enum", "values": BRANCHES, "required": true},
		"tier": {"type": "int", "min": 1, "max": 5},
		"cost": {"type": "int", "min": 1},
		"prereqs": {"type": "id_list", "ref": "tech"},
		"exclusive_with": {"type": "id_list", "ref": "tech"},
		"species_only": {"type": "id_list", "ref": "species"},
	}


func validate(db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	for m in modifiers:
		for k: Variant in m.condition:
			if not String(k) in CONDITIONS or not m.condition[k] is Array:
				errors.append("tech modifier conditions support only %s (each a list)" % [CONDITIONS])
	for p in prereqs:
		var t := db.get_def(p) as TechDef
		if t != null and t.tier >= tier:
			errors.append("prereq '%s' is tier %d, not below this tech's tier %d (no cycles)" % [p, t.tier, tier])
	for x in exclusive_with:
		var t := db.get_def(x) as TechDef
		if t == null:
			continue
		if x == id:
			errors.append("a tech can't be exclusive with itself")
		elif not id in t.exclusive_with:
			errors.append("exclusive_with '%s' doesn't list this tech back" % x)
		elif t.tier != tier or t.branch != branch:
			errors.append("exclusive partner '%s' must share the branch and tier" % x)
	if tier > 1:
		var rules := db.get_def(ResearchRulesDef.ID) as ResearchRulesDef
		var need := rules.tier_prereqs if rules != null else 0
		if TechTree.reachable_in_tier(db, branch, tier - 1, species_only) < need:
			errors.append("the tier rule needs %d researchable tier-%d %s techs below it" % [need, tier - 1, branch])
	return errors
