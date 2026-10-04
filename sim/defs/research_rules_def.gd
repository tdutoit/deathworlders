class_name ResearchRulesDef
extends Def
## Research numbers (Sub-spec B14; M5). Core ships one: core:research_rules/default. Tech costs live on each
## TechDef; the pace multiplier applies to them.

const ID := &"core:research_rules/default"

@export var tier_prereqs: int  # B14: a tier needs 3 techs of the tier below in the same branch
@export var slots: int  # B14: parallel research slots (+1 from techs via empire.research_slots)
@export var reverse_fragments: int  # B14: fragments of one faction per reverse-engineering unlock
@export var reverse_cost_permille: int  # B14: a reverse-engineered tech costs 50% of its RP
@export var reverse_unlocks: int  # B14: unlocks per species (owner: 3)
@export var admire_xenophilia: int  # xenophilia from which a copied species is flattered
@export var admire_opinion: int  # flattered: opinion event
@export var stolen_opinion: int  # furious: opinion event (negative)


func category() -> String:
	return "research_rules"


func schema() -> Dictionary:
	return {
		"stolen_opinion": {"type": "int"},
		"admire_opinion": {"type": "int"},
		"admire_xenophilia": {"type": "int"},
		"reverse_unlocks": {"type": "int"},
		"tier_prereqs": {"type": "int", "min": 0},
		"slots": {"type": "int", "min": 1},
		"reverse_fragments": {"type": "int", "min": 1},
		"reverse_cost_permille": {"type": "int", "min": 0},
	}
