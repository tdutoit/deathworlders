class_name SynergyDef
extends Def
## A focus pair bonus (main spec 4.2, Sub-spec B4): applies when the two foci are Primary + Secondary
## in either order. bonus_permille boosts both foci's jobs; modifiers carry the named effect.

@export var focus_a: StringName
@export var focus_b: StringName
@export var bonus_permille: int = 100


func category() -> String:
	return "synergy"


func schema() -> Dictionary:
	return {
		"focus_a": {"type": "id", "ref": "focus", "required": true},
		"focus_b": {"type": "id", "ref": "focus", "required": true},
		"bonus_permille": {"type": "int", "min": 0},
	}


func matches(primary: StringName, secondary: StringName) -> bool:
	return (primary == focus_a and secondary == focus_b) or (primary == focus_b and secondary == focus_a)


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	if focus_a == focus_b:
		errors.append("focus_a and focus_b must differ")
	return errors
