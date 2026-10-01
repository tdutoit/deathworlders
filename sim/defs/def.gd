class_name Def
extends Resource
## Base of every content definition (Sub-spec C2). Defs are immutable once the database is frozen.
##
## Each subclass declares its category and a field schema. The schema drives JSON conversion,
## patch ops, reference checks and content hashing, so a new Def type only needs fields + schema.
## Field types: int, bool, string, name (free StringName), enum, color ("#rrggbb"), id (reference),
## id_list, name_list, int_map (Dictionary of StringName -> int), modifiers.
## Options: required, min, max, ref (category for id/id_list), key_ref (category for int_map keys),
## keys (allowed int_map keys), values (allowed enum values).

@export var id: StringName  # "core:hull/human_cruiser_mk1"
@export var name_key: String  # localisation key
@export var desc_key: String
@export var icon: String  # res:// or mod-relative path
@export var tags: Array[StringName] = []
@export var modifiers: Array[ModifierDef] = []  # passive effects (C4)

# Set by the loader, not authored.
var source_mod: StringName
var source_file: String
var affects_sim := true  # false only if every mod that touched this Def is cosmetic


func category() -> String:
	return ""


## Subclass fields (excluding the base fields below).
func schema() -> Dictionary:
	return {}


func full_schema() -> Dictionary:
	var s := {
		"name_key": {"type": "string", "required": true},
		"desc_key": {"type": "string"},
		"icon": {"type": "string"},
		"tags": {"type": "name_list"},
		"modifiers": {"type": "modifiers"},
	}
	s.merge(schema())
	return s


## Subclass-specific checks beyond the schema; return readable error strings.
func validate(_db: DefDatabase) -> Array[String]:
	return []


## Canonical form for hashing and debugging: ints, strings, arrays and dictionaries only.
func to_dict() -> Dictionary:
	var out := {"id": id}
	var s := full_schema()
	for field: String in s:
		var value: Variant = get(field)
		if s[field]["type"] == "modifiers":
			var mods := []
			for m: ModifierDef in value:
				mods.append(m.to_dict())
			value = mods
		out[field] = value
	return out
