class_name DiplomacyRulesDef
extends Def
## Diplomacy constants (Sub-spec E1-E3, E14 Reputation; M4) as data. Core ships one:
## core:diplomacy_rules/default. Opinion is -100..100, trust 0..100.

const ID := &"core:diplomacy_rules/default"
## Event modifiers (E2): one accumulating modifier per type and directed pair, decaying 1 point toward 0
## every `event_decay_months[type]` months (0 = never).
const EVENTS: Array[String] = ["gift", "fought_together", "rescued", "denied", "espionage", "treaty_broken",
	"treaty_broken_other", "humiliated", "war_memory"]

# Contact (owner decision 2026-10-02): territory within contact_lanes, or a ship in the other's space.
@export var contact_lanes: int
# E1/E2 opinion
@export var opinion_min: int
@export var opinion_max: int
@export var opinion_border: int  # shared border, while true
@export var opinion_common_enemy: int  # at war with the same empire, while true
@export var war_opinion_cap: int  # opinion can't be higher while at war
@export var event_cap: Dictionary = {}  # event type -> largest total (its sign is the event's direction)
@export var event_decay_months: Dictionary = {}  # event type -> months per point of decay (0 = none)
# E3 trust
@export var trust_start: int
@export var trust_start_wary: int  # when the base affinity is at or below wary_affinity
@export var wary_affinity: int
@export var trust_max: int
# E14 Reputation (every empire; Legend for humans comes with WP9)
@export var reputation_min: int
@export var reputation_max: int

const _INTS: Array[String] = ["contact_lanes", "opinion_min", "opinion_max", "opinion_border", "opinion_common_enemy",
	"war_opinion_cap", "trust_start", "trust_start_wary", "wary_affinity", "trust_max", "reputation_min", "reputation_max"]


func category() -> String:
	return "diplomacy_rules"


func schema() -> Dictionary:
	var s := {}
	for field in _INTS:
		s[field] = {"type": "int"}
	s["event_cap"] = {"type": "int_map", "keys": EVENTS}
	s["event_decay_months"] = {"type": "int_map", "keys": EVENTS, "min": 0}
	return s


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	if opinion_min >= opinion_max or trust_max <= 0 or reputation_min >= reputation_max:
		errors.append("opinion_min < opinion_max, trust_max > 0 and reputation_min < reputation_max")
	return errors
