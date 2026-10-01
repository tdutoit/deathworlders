class_name WeaponFamilyDef
extends Def
## A weapon family (Sub-spec C3, A9): how it meets shields and armour, and whether point defence and ECM
## act on it (A7, A8). Core: kinetic, energy, missile, fighter.

@export var shield_mult: int = 1000  # permille of damage dealt to shields (A9)
@export var armor_eff: int = 1000  # permille of the target's armour that counts (A9)
@export var interceptable: bool  # point defence can intercept it (A8)
@export var uses_ammo: bool
@export var ecm_affected: bool  # ECM suites lower its accuracy (A7)


func category() -> String:
	return "weapon_family"


func schema() -> Dictionary:
	return {
		"shield_mult": {"type": "int", "min": 1},
		"armor_eff": {"type": "int", "min": 0},
		"interceptable": {"type": "bool"},
		"uses_ammo": {"type": "bool"},
		"ecm_affected": {"type": "bool"},
	}
