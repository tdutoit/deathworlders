class_name EconomyRulesDef
extends Def
## Economy rule constants (Sub-spec B3, B4, B13, B17, B18) as data, so mods can patch them.
## Core ships one: core:economy_rules/default. Rates are per month; *_milli values are milli-units.

const ID := &"core:economy_rules/default"

@export var food_per_pop: int  # B1
@export var tax_per_pop_milli: int  # B3: 0.5 credits
@export var secondary_focus_permille: int  # B4: Secondary gets half
@export var retool_days: int  # B4 (Standard pace)
@export var retool_output_permille: int  # B4
@export var growth_base: int  # B17
@export var growth_per_free_housing: int  # B17
@export var growth_points_per_pop: int  # B17
@export var starvation_pop_loss_months: int  # B17
@export var stability_base: int  # B18
@export var stability_food_surplus: int
@export var stability_starvation: int
@export var stability_garrison_each: int
@export var stability_garrison_max: int
@export var stability_retooling: int
@export var stability_unemployed_each: int
@export var stability_deficit_each_month: int
@export var low_stability_threshold: int
@export var low_stability_output_permille: int
@export var strike_threshold: int
@export var revolt_threshold: int
@export var reserve_default_permille: int  # B8: stockpiles keep 20% of cap from auto-logistics
@export var colony_hub_range: int  # lanes a Logistics-focus planet's freighters serve (B8 gives station tiers only)
# Sectors and stages (D2, D3, D9)
@export var sector_cap: int  # D3: 1 Core + techs; 2 at the start
@export var core_sector_range: int  # lanes the capital's Core Sector reaches
@export var export_quota_default_permille: int  # D5: 50%
@export var developed_pops: int  # D2
@export var developed_years: int
@export var core_pops: int
@export var core_stability: int
@export var core_hub_lanes: int
@export var reach_1: int  # D9 reach bands: from reach_1 lanes, from reach_2, from reach_3
@export var reach_2: int
@export var reach_3: int
@export var reach_upkeep_1: int  # permille
@export var reach_upkeep_2: int
@export var reach_upkeep_3: int
@export var reach_stability_1: int
@export var reach_stability_2: int
@export var reach_stability_3: int
# Sector logistics (D5): what the default governor keeps stocked
@export var input_buffer_months: int  # job inputs kept at each colony
@export var food_buffer_months: int  # food kept at each colony
@export var hub_collect_permille: int  # share of the hub's cap it gathers of the sector's mining output
# Colonisation and claims (B16, B17, D9)
@export var claim_influence_base: int  # D9: 25
@export var claim_influence_per_system_permille: int  # D9: +60 permille per owned system
@export var new_colony_upkeep_credits: int  # D9: 5 a month until its Farm completes
@export var new_colony_growth_permille: int  # B17: +100% growth
@export var new_colony_growth_years: int  # B17: for 5 years
@export var planet_supply_range: int  # B12: an owned planet supplies units 1 lane away


func category() -> String:
	return "economy_rules"


func schema() -> Dictionary:
	var s := {}
	for field in ["food_per_pop", "tax_per_pop_milli", "secondary_focus_permille", "retool_days", "retool_output_permille",
			"growth_base", "growth_per_free_housing", "growth_points_per_pop", "starvation_pop_loss_months",
			"stability_base", "stability_food_surplus", "stability_starvation", "stability_garrison_each",
			"stability_garrison_max", "stability_retooling", "stability_unemployed_each", "stability_deficit_each_month",
			"low_stability_threshold", "low_stability_output_permille", "strike_threshold", "revolt_threshold",
			"reserve_default_permille", "colony_hub_range", "sector_cap", "core_sector_range",
			"export_quota_default_permille", "developed_pops", "developed_years", "core_pops", "core_stability",
			"core_hub_lanes", "reach_1", "reach_2", "reach_3", "reach_upkeep_1", "reach_upkeep_2", "reach_upkeep_3",
			"reach_stability_1", "reach_stability_2", "reach_stability_3", "input_buffer_months",
			"food_buffer_months", "hub_collect_permille", "claim_influence_base", "claim_influence_per_system_permille",
			"new_colony_upkeep_credits", "new_colony_growth_permille", "new_colony_growth_years", "planet_supply_range"]:
		s[field] = {"type": "int"}
	return s
