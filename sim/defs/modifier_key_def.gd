class_name ModifierKeyDef
extends Def
## Declares a modifiable stat (Sub-spec C4). The key is the ID's name part:
## "core:modifier_key/planet.housing" declares "planet.housing". Keys are global across mods.

@export var default_value: int
@export var min_value: int = -1000000000
@export var max_value: int = 1000000000
@export var scope: ModifierDef.Scope = ModifierDef.Scope.OWNER


func category() -> String:
	return "modifier_key"


func schema() -> Dictionary:
	return {
		"default_value": {"type": "int"},
		"min_value": {"type": "int"},
		"max_value": {"type": "int"},
		"scope": {"type": "scope"},
	}


func key() -> StringName:
	return StringName(String(id).get_slice("/", 1))


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	if min_value > max_value:
		errors.append("min_value is greater than max_value")
	elif default_value < min_value or default_value > max_value:
		errors.append("default_value is outside min_value..max_value")
	return errors
