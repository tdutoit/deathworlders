class_name AiRulesDef
extends Def
## Strategic AI constants (Sub-spec E11-E13; M4 WP10, owner placeholders) as data. Core ships one:
## core:ai_rules/default. Utilities are plain integers compared against each other.

const ID := &"core:ai_rules/default"

@export var personality_spread: int  # E11: species weights +-this on the ai stream
@export var actions_per_month: int  # E12/E13: top N actions (Officer 2; difficulty overrides, WP12)
@export var peace_years: int  # E16: no AI declares war before this year of the match
@export var war_lanes: int  # E12: targets within this many lanes of own territory
@export var war_ratio_base: int  # permille power over the target needed at Caution 0
@export var war_ratio_per_caution: int  # + this permille per Caution point
@export var war_no_cb_aggression: int  # only this aggressive an AI wars without a casus belli
@export var war_cb_bonus: int
@export var war_opportunity_bonus: int  # the target is already at war elsewhere
@export var claim_aggression: int  # AIs at least this aggressive claim neighbours' systems
@export var claim_influence_cushion: int  # influence kept back
@export var claim_opinion: int  # claim only empires it likes no more than this
@export var peace_exhaustion: int  # E7: at 75 the AI strongly seeks peace
@export var peace_losing_score: int  # offers white peace at or below this war score
@export var peace_winning_score: int  # demands terms at or above this war score
@export var peace_utility: int
@export var treaty_divisor: int  # personality weight / this = a treaty's base utility
@export var treaty_threat_bonus: int  # defensive treaties when a stronger hostile neighbour exists
@export var council_ambition: int  # members at least this ambitious propose resolutions
@export var sanction_opinion: int  # propose sanctions on empires it likes no more than this
@export var protectorate_utility: int
# War operations (M4 WP11)
@export var reserve_per_caution: int  # home reserve = fleet value x Caution x this / 1000
@export var repair_hull: int  # permille of hull below which a fleet goes home to repair


const _INTS: Array[String] = ["personality_spread", "actions_per_month", "peace_years", "war_lanes",
	"war_ratio_base", "war_ratio_per_caution", "war_no_cb_aggression", "war_cb_bonus", "war_opportunity_bonus",
	"claim_aggression", "claim_influence_cushion", "claim_opinion", "peace_exhaustion", "peace_losing_score",
	"peace_winning_score", "peace_utility", "treaty_divisor", "treaty_threat_bonus", "council_ambition",
	"sanction_opinion", "protectorate_utility", "reserve_per_caution", "repair_hull"]


func category() -> String:
	return "ai_rules"


func schema() -> Dictionary:
	var s := {}
	for field in _INTS:
		s[field] = {"type": "int"}
	return s
