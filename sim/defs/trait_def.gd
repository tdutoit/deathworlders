class_name TraitDef
extends Def
## A species trait (main spec 10.2-10.3, A13, M4 WP1): a named bundle of modifiers. Scope decides who reads
## them: SHIP keys apply to the owner's ships and armed stations (ShipStats; an optional condition
## {"hull_class": [...]} limits them to those classes), EMPIRE keys to the owning empire (SpeciesTraits),
## PLANET keys to colonies whose pops are mostly of that species (PlanetMods).


func category() -> String:
	return "trait"


func schema() -> Dictionary:
	return {}


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	for m in modifiers:
		for k: Variant in m.condition:
			if k != "hull_class" or not m.condition[k] is Array:
				errors.append("trait modifier conditions support only {\"hull_class\": [classes]}")
	return errors
