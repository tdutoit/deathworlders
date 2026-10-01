class_name ModifierDef
extends Resource
## A passive effect on a declared modifier key (Sub-spec C4).
## Resolution: final = (base + sum(ADD)) * (1000 + sum(PERMILLE)) / 1000.

enum Mode { ADD, PERMILLE }
enum Scope { OWNER, EMPIRE, PLANET, SYSTEM, FLEET, SHIP, UNIT }

@export var key: StringName  # "ship.accuracy.missile"; must be declared by a ModifierKeyDef
@export var mode: Mode = Mode.ADD
@export var value: int  # 100 = +10% in PERMILLE mode
@export var scope: Scope = Scope.OWNER
@export var condition: Dictionary = {}  # optional, event DSL (C8)


func to_dict() -> Dictionary:
	return {"key": key, "mode": mode, "value": value, "scope": scope, "condition": condition}


## Lowercase JSON names for the enums, e.g. "permille", "planet".
static func mode_names() -> PackedStringArray:
	return _lower(Mode.keys())


static func scope_names() -> PackedStringArray:
	return _lower(Scope.keys())


static func _lower(names: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for n: String in names:
		out.append(n.to_lower())
	return out
