class_name EspionageRulesDef
extends Def
## Espionage numbers (main spec 12; M5 WP9, owner placeholders 2026-10-04). Core ships one:
## core:espionage_rules/default.

const ID := &"core:espionage_rules/default"

@export var max_agents: int  # agents per empire (3)
@export var recruit_influence: int  # influence per agent (40)
@export var upkeep_credits: int  # credits per agent per month (2)
@export var insert_days: int  # days to get in place (30)
@export var success_permille: int  # monthly success (350)
@export var caught_permille: int  # monthly chance of being caught (80)
@export var caught_opinion: int  # the target's espionage opinion event (-30, E3)
@export var caught_reputation: int  # Reputation (-10)
@export var core_lanes: int  # core systems: capital system + this many lanes (1)
@export var core_strength: int  # sensor strength over them (40)
@export var intel_points: int  # gather_intel success (500)
@export var intel_cap: int  # up to level 3 (3000)
@export var fragments: int  # steal_fragments success (15)
@export var unrest_stability: int  # incite_unrest success (10)
@export var ai_influence_reserve: int  # the AI recruits with at least this much influence (80)


func category() -> String:
	return "espionage_rules"


func schema() -> Dictionary:
	return {
		"max_agents": {"type": "int"},
		"recruit_influence": {"type": "int"},
		"upkeep_credits": {"type": "int"},
		"insert_days": {"type": "int"},
		"success_permille": {"type": "int"},
		"caught_permille": {"type": "int"},
		"caught_opinion": {"type": "int"},
		"caught_reputation": {"type": "int"},
		"core_lanes": {"type": "int"},
		"core_strength": {"type": "int"},
		"intel_points": {"type": "int"},
		"intel_cap": {"type": "int"},
		"fragments": {"type": "int"},
		"unrest_stability": {"type": "int"},
		"ai_influence_reserve": {"type": "int"},
	}
