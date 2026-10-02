class_name DiplomacyRulesDef
extends Def
## Diplomacy constants (Sub-spec E1-E3, E14 Reputation; M4) as data. Core ships one:
## core:diplomacy_rules/default. Opinion is -100..100, trust 0..100.

const ID := &"core:diplomacy_rules/default"
## Event modifiers (E2): one accumulating modifier per type and directed pair, decaying 1 point toward 0
## every `event_decay_months[type]` months (0 = never).
const EVENTS: Array[String] = ["gift", "fought_together", "rescued", "denied", "espionage", "treaty_broken",
	"treaty_broken_other", "humiliated", "war_memory", "deal_failed", "warmonger", "defiance"]

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
# Deals (E6; M4 WP5)
@export var influence_value: int  # credits per influence point in deals (placeholder; influence has no B1 base value)
@export var deal_target_months: int  # E6 scarcity: target stock = this many months of last month's use
@export var scarcity_min: int  # E6
@export var scarcity_max: int  # E6
@export var recurring_permille: int  # E6: recurring deals at 60%
@export var system_value_months: int  # E6: a system is worth 60 months of its output
@export var system_min_value: int  # an outpost system with no colony output (placeholder)
@export var greed_base: int  # E6 personality_greed = (base + greed x per_point) permille on what the valuer gives up
@export var greed_per_point: int  # E6
@export var deal_value_per_point: int  # E5 deal_balance: credits of value per point (placeholder)
@export var deal_balance_max: int  # E5 deal_balance cap either way (placeholder)
@export var gift_value_per_opinion: int  # E2: +1 opinion per 25 credit-value
# War (E7; M4 WP6)
@export var claim_influence: int  # E7: influence per claimed system
@export var opinion_claims: int  # E2: overlapping claims, while true
@export var no_cb_reputation: int  # E7/E14: war without a casus belli (half of Respect -200)
@export var no_cb_opinion: int  # E7: everyone's opinion of the aggressor ('warmonger' event)
@export var containment_ratio: int  # E7: the target's power at least this permille of yours
@export var score_battle_cost: int  # E7: battle value of enemy ships destroyed per point
@export var score_convoy_value: int  # E7: cargo value destroyed per point
@export var blockade_max: int  # E7: blockade points a month
@export var exhaustion_loss_step: int  # E7: +1 per this permille of the pre-war fleet lost (5%)
@export var exhaustion_peace_recovery: int  # points a month at peace (placeholder; E7 gives none)
@export var exhaustion_stability_50: int  # E7
@export var exhaustion_stability_75: int  # E7
@export var forced_peace_months: int  # E7: at 100 for this long, a status quo peace
@export var cede_cost_min: int  # E7
@export var cede_cost_max: int  # E7
@export var cede_value_per_point: int  # E7 'by value': system value per point above the minimum (placeholder)
@export var reparations_cost: int  # E7: war score per 1000 credit-value
@export var reparations_months: int  # E7: paid monthly over 5 years (owner)
@export var humiliation_cost: int  # E7
@export var humiliation_influence: int  # influence the humiliated loses (placeholder)
@export var disarmament_cost: int  # E7
@export var disarmament_years: int  # E7; cap = half the fleet value at peace (owner)
@export var peace_days: int  # a player's peace offer waits this long
# War footing (D7; M4 WP7)
@export var footing_transition_days: int  # D7
@export var demob_months: int  # D7
@export var demob_stability: int  # D7
# Galactic Council (E9; M4 WP8)
@export var council_session_months: int  # E9: a session every 2 years
@export var council_proposal_influence: int  # E9
@export var votes_influence_step: int  # E9: 1 vote per 5 influence income a month
@export var defiance_opinion: int  # E9
@export var defiance_trust: int  # E9
# E14 Reputation (every empire; Legend for humans comes with WP9)
@export var reputation_min: int
@export var reputation_max: int

const _INTS: Array[String] = ["influence_value", "deal_target_months", "scarcity_min", "scarcity_max",
	"recurring_permille", "system_value_months", "system_min_value", "greed_base", "greed_per_point",
	"deal_value_per_point", "deal_balance_max", "gift_value_per_opinion", "contact_lanes", "opinion_min",
	"opinion_max", "opinion_border", "opinion_common_enemy", "war_opinion_cap", "trust_start", "trust_start_wary",
	"wary_affinity", "trust_max", "reputation_min", "reputation_max", "shared_threat", "fear_max",
	"fear_ratio_step", "refusal_months", "refusal_penalty", "trust_per_treaty", "trust_treaty_max",
	"break_others_opinion", "break_others_trust", "break_reputation", "call_days", "call_answered_trust",
	"call_ignored_trust", "proposal_days", "protectorate_power", "protectorate_hostile_opinion",
	"protectorate_lanes", "protectorate_tribute", "protectorate_days", "protectorate_success_trust",
	"protectorate_success_reputation", "protectorate_fail_reputation", "claim_influence", "opinion_claims",
	"no_cb_reputation", "no_cb_opinion", "containment_ratio", "score_battle_cost", "score_convoy_value",
	"blockade_max", "exhaustion_loss_step", "exhaustion_peace_recovery", "exhaustion_stability_50",
	"exhaustion_stability_75", "forced_peace_months", "cede_cost_min", "cede_cost_max", "cede_value_per_point",
	"reparations_cost", "reparations_months", "humiliation_cost", "humiliation_influence", "disarmament_cost",
	"disarmament_years", "peace_days", "footing_transition_days", "demob_months", "demob_stability",
	"council_session_months", "council_proposal_influence", "votes_influence_step", "defiance_opinion",
	"defiance_trust"]


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
