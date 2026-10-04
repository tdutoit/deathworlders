class_name TreatyDef
extends Def
## A treaty type (Sub-spec E4; M4 WP4). The proposer pays `influence` on signing. The receiver accepts when
## its view of the proposer meets `min_opinion` and `min_trust` and the E5 acceptance score is >= 0 (with
## `threshold` as the treaty's term). While active, each side's view of the other gets `opinion` (only the
## protected's view of its guardian for protectorates). Ending before `min_years` is breaking it.

const EFFECTS: Array[String] = ["no_war", "trade", "access", "call_to_arms", "alliance", "protectorate"]
const KINDS: Array[String] = ["", "defensive", "trade"]  # which E11 personality term applies (E11 note)

@export var influence: int
@export var min_opinion: int
@export var min_trust: int
@export var threshold: int  # E5 treaty_threshold
@export var opinion: int  # standing opinion while active (E2)
@export var min_years: int
@export var notice_months: int  # ending it cleanly takes this notice (non-aggression: 12)
@export var break_opinion: int  # the victim's opinion of the breaker (event, decays)
@export var break_trust_zero: bool  # the victim's trust in the breaker drops to 0 (E3 says every break does)
@export var kind: StringName
@export var effects: Array[StringName] = []
@export var requires_tech: Array[StringName] = []  # techs the proposer needs (M5 research pact, intel sharing)


func category() -> String:
	return "treaty"


func schema() -> Dictionary:
	return {
		"requires_tech": {"type": "id_list", "ref": "tech"},
		"influence": {"type": "int", "min": 0},
		"min_opinion": {"type": "int", "min": -100, "max": 100},
		"min_trust": {"type": "int", "min": 0, "max": 100},
		"threshold": {"type": "int"},
		"opinion": {"type": "int"},
		"min_years": {"type": "int", "min": 0},
		"notice_months": {"type": "int", "min": 0},
		"break_opinion": {"type": "int", "max": 0},
		"break_trust_zero": {"type": "bool"},
		"kind": {"type": "enum", "values": KINDS},
		"effects": {"type": "name_list"},
	}


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	for e in effects:
		if not String(e) in EFFECTS:
			errors.append("unknown effect '%s' (known: %s)" % [e, EFFECTS])
	return errors


func has(effect: String) -> bool:
	return StringName(effect) in effects
