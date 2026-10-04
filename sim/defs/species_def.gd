class_name SpeciesDef
extends Def
## A playable species (main spec 10.2, Sub-spec C SpeciesDef row): habitability, home template and colour
## (M1), plus traits, AI personality weights (E11), base affinity toward each species (E2) and the signature
## mechanic hook (M4).

const PERSONALITY: Array[String] = ["aggression", "expansion", "honour", "xenophilia", "greed", "caution", "ambition"]

@export var color: String  # "#rrggbb" empire colour default, cosmetic
@export var habitability: Dictionary = {}  # planet_type id -> permille; missing = 0
@export var home_template: StringName  # "sol" = handcrafted Sol (main spec 4.1b); "standard" otherwise
@export var home_planet_type: StringName  # planet_type id of the homeworld
@export var traits: Array[StringName] = []  # trait Def IDs
@export var ai_personality: Dictionary = {}  # E11 weight -> 0..100
@export var personality_key: String  # loc key of the personality name ("Stubborn Wildcards")
@export var affinity: Dictionary = {}  # species ID -> base opinion toward that species (E2), -100..100
@export var signature_mechanic: StringName  # "legend", "precedence", "brood_surge", "contracts", "sanctuary"
@export var starting_techs: Array[StringName] = []  # techs researched at match start (M5)


func category() -> String:
	return "species"


func schema() -> Dictionary:
	return {
		"starting_techs": {"type": "id_list", "ref": "tech"},
		"color": {"type": "color", "required": true},
		"habitability": {"type": "int_map", "key_ref": "planet_type", "min": 0, "max": 2000},
		"home_template": {"type": "enum", "values": ["sol", "standard"], "required": true},
		"home_planet_type": {"type": "id", "ref": "planet_type", "required": true},
		"traits": {"type": "id_list", "ref": "trait"},
		"ai_personality": {"type": "int_map", "keys": PERSONALITY, "min": 0, "max": 100},
		"personality_key": {"type": "string"},
		"affinity": {"type": "int_map", "key_ref": "species", "min": -100, "max": 100},
		"signature_mechanic": {"type": "name"},
	}


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	if signature_mechanic != &"" and not SignatureMechanics.has(signature_mechanic):
		errors.append("unknown signature_mechanic '%s' (registered: %s)" % [signature_mechanic, SignatureMechanics.names()])
	return errors
