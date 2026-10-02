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
# Treaties (E3-E5, E8; M4 WP4)
@export var shared_threat: int  # E5: +20 if a common enemy
@export var fear_max: int  # E5: largest fear bonus
@export var fear_ratio_step: int  # E5: permille of power ratio above 1:1 per fear point (2:1 = +25)
@export var refusal_months: int  # E5: recent-refusal window
@export var refusal_penalty: int  # E5
@export var trust_per_treaty: int  # E3: per active treaty a month
@export var trust_treaty_max: int  # E3: per pair a month
@export var break_others_opinion: int  # E2: everyone else's view of a treaty breaker
@export var break_others_trust: int  # E3
@export var break_reputation: int  # E14 half of Respect -100
@export var call_days: int  # days to answer a call to arms
@export var call_answered_trust: int  # E3
@export var call_ignored_trust: int  # E3
@export var proposal_days: int  # a player's proposal waits this long
@export var protectorate_power: int  # E8: protected power under 40% of a hostile neighbour's
@export var protectorate_hostile_opinion: int  # E8 adapted: hostile = at war or opinion at most this
@export var protectorate_lanes: int  # E8
@export var protectorate_tribute: int  # permille of the protected's credit net (owner 2026-10-02)
@export var protectorate_days: int  # E8: guardian response time
@export var protectorate_success_trust: int  # E8
@export var protectorate_success_reputation: int  # E14 half of Respect +50
@export var protectorate_fail_reputation: int  # E14 half of Respect -150
# E14 Reputation (every empire; Legend for humans comes with WP9)
@export var reputation_min: int
@export var reputation_max: int

const _INTS: Array[String] = ["contact_lanes", "opinion_min", "opinion_max", "opinion_border", "opinion_common_enemy",
	"war_opinion_cap", "trust_start", "trust_start_wary", "wary_affinity", "trust_max", "reputation_min", "reputation_max",
	"shared_threat", "fear_max", "fear_ratio_step", "refusal_months", "refusal_penalty", "trust_per_treaty",
	"trust_treaty_max", "break_others_opinion", "break_others_trust", "break_reputation", "call_days",
	"call_answered_trust", "call_ignored_trust", "proposal_days", "protectorate_power",
	"protectorate_hostile_opinion", "protectorate_lanes", "protectorate_tribute", "protectorate_days",
	"protectorate_success_trust", "protectorate_success_reputation", "protectorate_fail_reputation"]


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
