class_name JobDef
extends Def
## A pop job (Sub-spec B3): monthly output and input per employed pop, before modifiers.
## Non-resource effects per employed pop (berths, stockpile cap, garrison) are modifiers.

@export var outputs: Dictionary = {}  # resource ID -> units per pop per month
@export var inputs: Dictionary = {}  # resource ID -> units per pop per month, from the local stockpile
@export var stability: int  # stability per employed pop (C3)
@export var priority: int = 50  # auto-assignment order among non-focus jobs (lower first)


func category() -> String:
	return "job"


func schema() -> Dictionary:
	return {
		"outputs": {"type": "int_map", "key_ref": "resource", "min": 0},
		"inputs": {"type": "int_map", "key_ref": "resource", "min": 0},
		"stability": {"type": "int"},
		"priority": {"type": "int", "min": 0},
	}
