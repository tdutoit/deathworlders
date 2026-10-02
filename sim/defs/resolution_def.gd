class_name ResolutionDef
extends Def
## A Galactic Council resolution (Sub-spec E9; M4 WP8, owner decisions 2026-10-02). In force from the session
## it passes until a later session passes its repeal. `effect` names the rule; `value` is its number.

const EFFECTS: Array[String] = ["trade_standards", "sanctions", "pirate_suppression", "recognition"]

@export var effect: StringName
@export var needs_target: bool  # aimed at one empire (Sanctions on X, Recognition of X)
@export var value: int  # trade_standards: Clerk credits permille (members +, others -); sanctions: opinion;
                        # pirate_suppression: security in member space
@export var permanent: bool  # done once it passes (Recognition), never "in force"


func category() -> String:
	return "resolution"


func schema() -> Dictionary:
	return {
		"effect": {"type": "enum", "values": EFFECTS, "required": true},
		"needs_target": {"type": "bool"},
		"value": {"type": "int"},
		"permanent": {"type": "bool"},
	}
