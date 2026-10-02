class_name SignatureRulesDef
extends Def
## Signature mechanic numbers (main spec 10.1, 10.4, Sub-spec E9, E14; owner placeholders 2026-10-02 for Brood
## Surge, Contracts, Sanctuary and Precedence stagnation). Core ships one: core:signature_rules/default.

const ID := &"core:signature_rules/default"

# Legend (humans, E14): Respect and Fear 0..legend_max
@export var legend_start: int
@export var legend_max: int
@export var outnumbered_ratio: int  # permille: enemy start cost at least this times yours
@export var outnumbered_respect: int
@export var outnumbered_fear: int
@export var protect_respect: int
@export var protect_fail_respect: int
@export var kept_treaty_years: int
@export var kept_treaty_respect: int
@export var break_respect: int
@export var break_fear: int
@export var capital_fleet_share: int  # permille of an empire's navy destroyed in one battle = its capital fleet
@export var capital_fleet_respect: int
@export var capital_fleet_fear: int
@export var no_cb_respect: int
@export var no_cb_fear: int
@export var opinion_divisor: int  # E2: + Respect / 40 - Fear / 40
@export var respect_first_pick: int
@export var respect_all_opinion: int
@export var respect_all_bonus: int
@export var respect_recognition: int
@export var fear_deterrence: int
@export var fear_deterrence_caution: int
@export var fear_peace: int
@export var fear_peace_discount: int
@export var fear_coalition: int
# Precedence (Vess'kar, E9)
@export var precedence_votes: int
@export var stagnation_free: int  # years without adapting before output suffers
@export var stagnation_step: int  # output permille per point beyond the free years (negative)
@export var stagnation_max: int  # floor of the output penalty (negative)
@export var veto_stance: int  # AI vetoes a passed resolution it scores at or below this
# Brood Surge (Krothi)
@export var surge_min_pops: int
@export var surge_pops: int
@export var surge_days: int
@export var surge_component_permille: int
@export var surge_cooldown_months: int
# Contracts (Ohlan)
@export var merc_hire: int  # credits
@export var merc_monthly: int  # credits
@export var merc_ships: int
@export var merc_months: int
@export var convoy_profit: int  # permille of delivered goods' value
@export var contract_per_trade: int  # credits a month per trade agreement
# Sanctuary (Thessari)
@export var sanctuary_min_pops: int
@export var sanctuary_pops_per_platform: int
@export var sanctuary_opinion: int
@export var sanctuary_acceptance: int

const _INTS: Array[String] = ["legend_start", "legend_max", "outnumbered_ratio", "outnumbered_respect",
	"outnumbered_fear", "protect_respect", "protect_fail_respect", "kept_treaty_years", "kept_treaty_respect",
	"break_respect", "break_fear", "capital_fleet_share", "capital_fleet_respect", "capital_fleet_fear",
	"no_cb_respect", "no_cb_fear", "opinion_divisor", "respect_first_pick", "respect_all_opinion",
	"respect_all_bonus", "respect_recognition", "fear_deterrence", "fear_deterrence_caution", "fear_peace",
	"fear_peace_discount", "fear_coalition", "precedence_votes", "stagnation_free", "stagnation_step",
	"stagnation_max", "veto_stance", "surge_min_pops", "surge_pops", "surge_days", "surge_component_permille",
	"surge_cooldown_months", "merc_hire", "merc_monthly", "merc_ships", "merc_months", "convoy_profit",
	"contract_per_trade", "sanctuary_min_pops", "sanctuary_pops_per_platform", "sanctuary_opinion",
	"sanctuary_acceptance"]


func category() -> String:
	return "signature_rules"


func schema() -> Dictionary:
	var s := {}
	for field in _INTS:
		s[field] = {"type": "int"}
	return s
