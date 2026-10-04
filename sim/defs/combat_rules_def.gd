class_name CombatRulesDef
extends Def
## Space combat constants (Sub-spec A0–A13; the A9 family matrix lives in weapon_family Defs) as data, so the combat harness can tune them and mods can
## patch them. Core ships one: core:combat_rules/default. Permille unless named otherwise.

const ID := &"core:combat_rules/default"
const SIZES: Array[String] = ["S", "M", "L", "XL"]
const VETERANCY: Array[String] = ["green", "regular", "veteran", "elite"]

# A0, A7
@export var hit_min: int
@export var hit_max: int
@export var variance_min: int  # damage roll range [min, max) permille
@export var variance_max: int
# A1, A9
@export var shield_regen: int  # default per round when a hull sets none
@export var armor_k: int
@export var ablation_divisor: int
@export var crippled_hull: int  # below this share of hull_max a ship is crippled
@export var crippled_accuracy: int
# A4, A5, A6, A8
@export var round_cap: int
@export var range_step_rounds: int
@export var escort_classes: Array[StringName] = []  # hull classes that screen (A6) and are not capital ships (A10)
@export var screen_escort_share: int  # screening while escorts are at least this share of enemy hulls
@export var screen_weight: int  # capital ships' target weight while screened
@export var target_top: int  # pick among the top N candidates
@export var pd_intercept: int
@export var ecm_missile_penalty: int  # per ECM suite (A7)
@export var sensor_net_accuracy: int  # system owner (A13)
# A10
@export var morale_start: int
@export var morale_out_of_supply: int
@export var morale_recent_defeat: int
@export var morale_loss_mult: int
@export var morale_capital_lost: int
@export var outnumbered_ratio: int  # by cost, permille (2000 = 2:1)
@export var morale_outnumbered: int
@export var retreat_morale: int
@export var retreat_roll_mult: int
@export var disengage_rounds: int
@export var disengage_incoming_accuracy: int
@export var pursuit_rounds: int
# A11
@export var boarding_min: int
@export var boarding_max: int
@export var boarding_fail_loss: int
@export var capture_salvage_mult: int
# A12
@export var decisive_enemy_loss: int
@export var decisive_own_loss: int
@export var victory_min_loss: int
@export var pyrrhic_own_loss: int
@export var draw_band: int
@export var salvage: int  # tech fragments = destroyed enemy cost x this / 1000
@export var xp_per_round: int
@export var xp_per_kill: int
# A13 veterancy, B12 / A13 supply
@export var veterancy_xp: Dictionary = {}  # tier -> XP needed
@export var veterancy_accuracy: Dictionary = {}  # tier -> permille
@export var veterancy_morale_resist: Dictionary = {}  # tier -> permille
@export var out_of_supply_accuracy: int
@export var attrition_after_days: int
@export var attrition_per_day: int  # permille of hull_max
@export var ai_civilian_stall_days: int  # at peace, no new warship while a civilian build has stalled this long (M4 WP14)
@export var report_keep: int  # battle reports kept per match, newest (M4 WP14, owner 2026-10-03)
# Last Stand (A10; species with empire.last_stand): outnumbered by outnumbered_ratio and morale below the trigger
@export var last_stand_trigger_morale: int
@export var last_stand_damage: int  # permille damage bonus while it lasts
@export var last_stand_morale_floor: int
@export var last_stand_rounds: int
# Crew and ammunition placeholders (owner, 2026-10-01; A2 has none)
@export var crew_by_size: Dictionary = {}  # hull size -> crew
@export var ammo_per_weapon: int  # ammo_max per ammo-using weapon
# Fleet supply (B12) and repair (owner placeholders 2026-10-01)
@export var fuel_moving_milli: Dictionary = {}  # hull size -> fuel per month while it moved that month
@export var fuel_idle_milli: Dictionary = {}  # hull size -> fuel per month otherwise
@export var ammo_per_munition: int  # B12: 1 munition refills 2 ammo
@export var repair_docked: int  # permille of hull_max per day at an own shipyard or supply depot
@export var repair_field: int  # permille of hull_max per day elsewhere in supply range
@export var repair_hull_per_alloy: int  # hull points one alloy repairs
# Convoy protection (main spec 6.6; owner decisions 2026-10-01)
@export var escort_raid: int  # permille of the raid chance against an escorted hub's freighters
@export var patrol_security: int  # D9 security a patrol adds to each own system on its list
@export var patrol_wait_hours: int  # hours a patrol stays in each system
# Defensive autopilot for AI slots (M3 WP10 placeholders)
@export var ai_build_classes: Array[StringName] = []  # hull classes built in turn (unbuildable ones skipped)
@export var ai_military_share: int  # warship credit upkeep allowed, permille of the credit net before it
@export var ai_min_fleet_value: int  # battle value (A1 cost) of warships kept whatever the budget (while the economy may expand)
@export var ai_attack_ratio: int  # engage a threat with at least this battle value, permille of its own
@export var ai_loss_months: int  # convoy losses this recent count
@export var ai_loss_trigger: int  # recent losses that start a patrol and an escort
# Naval hierarchy (main spec 7.1): ships auto-group into squadrons of one class, squadrons into task forces
@export var squadron_max: int
@export var task_force_squadrons: int
@export var fleet_task_forces: int
# Who pirates fly (B9 raiders, D9 bases)
@export var pirate_raider_design: StringName
@export var pirate_base_design: StringName
@export var refit_base_days: int  # M5 WP7 refits (owner 2026-10-04): 3 days
@export var refit_days_per_slot: int  # + 2 per changed slot
@export var refit_refund_permille: int  # removed parts refund 50%
@export var refit_hull_permille: int  # Mk upgrade: 50% of the hull cost difference and of the new hull's build days

const _INTS: Array[String] = ["hit_min", "hit_max", "variance_min", "variance_max", "shield_regen", "armor_k",
	"ablation_divisor", "crippled_hull", "crippled_accuracy", "round_cap", "range_step_rounds", "screen_escort_share",
	"screen_weight", "target_top", "pd_intercept", "ecm_missile_penalty", "sensor_net_accuracy", "morale_start",
	"morale_out_of_supply", "morale_recent_defeat", "morale_loss_mult", "morale_capital_lost", "outnumbered_ratio",
	"morale_outnumbered", "retreat_morale", "retreat_roll_mult", "disengage_rounds", "disengage_incoming_accuracy",
	"pursuit_rounds", "boarding_min", "boarding_max", "boarding_fail_loss", "capture_salvage_mult",
	"decisive_enemy_loss", "decisive_own_loss", "victory_min_loss", "pyrrhic_own_loss", "draw_band", "salvage",
	"xp_per_round", "xp_per_kill", "out_of_supply_accuracy", "attrition_after_days", "attrition_per_day",
	"ammo_per_weapon", "squadron_max", "task_force_squadrons", "fleet_task_forces", "ammo_per_munition",
	"repair_docked", "repair_field", "repair_hull_per_alloy", "escort_raid", "patrol_security", "patrol_wait_hours",
	"ai_military_share", "ai_min_fleet_value", "ai_attack_ratio", "ai_loss_months", "ai_loss_trigger",
	"last_stand_trigger_morale", "last_stand_damage", "last_stand_morale_floor", "last_stand_rounds",
	"report_keep", "ai_civilian_stall_days"]


func category() -> String:
	return "combat_rules"


func schema() -> Dictionary:
	var s := {}
	for field in _INTS:
		s[field] = {"type": "int"}
	s["escort_classes"] = {"type": "name_list"}
	s["ai_build_classes"] = {"type": "name_list"}
	s["veterancy_xp"] = {"type": "int_map", "keys": VETERANCY, "min": 0}
	s["veterancy_accuracy"] = {"type": "int_map", "keys": VETERANCY}
	s["veterancy_morale_resist"] = {"type": "int_map", "keys": VETERANCY}
	s["crew_by_size"] = {"type": "int_map", "keys": SIZES, "min": 0}
	for f in ["refit_base_days", "refit_days_per_slot", "refit_refund_permille", "refit_hull_permille"]:
		s[f] = {"type": "int", "min": 0}
	s["fuel_moving_milli"] = {"type": "int_map", "keys": SIZES, "min": 0}
	s["fuel_idle_milli"] = {"type": "int_map", "keys": SIZES, "min": 0}
	s["pirate_raider_design"] = {"type": "id", "ref": "design"}
	s["pirate_base_design"] = {"type": "id", "ref": "design"}
	return s


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	if hit_min > hit_max or variance_min >= variance_max or armor_k <= 0 or ablation_divisor <= 0:
		errors.append("hit_min <= hit_max, variance_min < variance_max, armor_k > 0 and ablation_divisor > 0")
	return errors
