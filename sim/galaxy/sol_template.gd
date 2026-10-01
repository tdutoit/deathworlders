class_name SolTemplate
extends RefCounted
## The handcrafted human start (main spec 4.1b, Sub-spec B19): 8 planets, the asteroid belt, Luna and
## Titan. Deposits are richness 1-3, hand-tuned so the human opening is the same every match.
## In code for M1; becomes a system-template Def when mods need custom starts.

const SYSTEM_NAME := "Sol"
const STAR := "core:star_type/yellow"
const CAPITAL := "Earth"

## name, type (core planet_type name), size, orbit radius, deposits, parent (moons only)
const BODIES: Array[Dictionary] = [
	{"name": "Mercury", "type": "barren", "size": "small", "radius": 25, "deposits": {"ore": 3, "rare_earths": 1}},
	{"name": "Venus", "type": "toxic", "size": "medium", "radius": 40, "deposits": {"rare_earths": 2}},
	{"name": "Earth", "type": "terran", "size": "large", "radius": 55, "deposits": {"food": 3, "ore": 1}},
	{"name": "Luna", "type": "barren", "size": "tiny", "radius": 6, "deposits": {"ore": 1}, "parent": "Earth"},
	{"name": "Mars", "type": "desert", "size": "medium", "radius": 75, "deposits": {"ore": 2, "rare_earths": 1}},
	{"name": "Asteroid Belt", "type": "asteroid_belt", "size": "medium", "radius": 100, "deposits": {"ore": 3, "rare_earths": 2}},
	{"name": "Jupiter", "type": "gas_giant", "size": "huge", "radius": 140, "deposits": {"fuel": 3}},
	{"name": "Saturn", "type": "gas_giant", "size": "large", "radius": 180, "deposits": {"fuel": 2}},
	{"name": "Titan", "type": "arctic", "size": "small", "radius": 8, "deposits": {"ore": 1}, "parent": "Saturn"},
	{"name": "Uranus", "type": "gas_giant", "size": "medium", "radius": 220, "deposits": {"fuel": 1}},
	{"name": "Neptune", "type": "gas_giant", "size": "medium", "radius": 250, "deposits": {"fuel": 1}},
]
