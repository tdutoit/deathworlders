class_name FogRulesDef
extends Def
## Fog of war numbers (Sub-spec D12; M5 WP5). Core ships one: core:fog_rules/default. Detection (owner decision
## 2026-10-04): a contact in a covered system is seen when sensor strength + signature - stealth >= threshold.

const ID := &"core:fog_rules/default"
const SIZES: Array[String] = ["S", "M", "L", "XL"]

@export var threshold: int  # detection threshold (60)
@export var owned_strength: int  # sensor strength over own systems (owned planet or outpost, D12)
@export var unit_strength: int  # any own unit's system
@export var scout_strength: int
@export var scout_range: int  # D12: scouts see +1 lane
@export var signature_by_size: Dictionary = {}  # hull size -> signature (D12: S 20, M 40, L 70, XL 100)
@export var freighter_signature: int  # D12: 30
@export var pirate_stealth: int  # D12: pirates have innate stealth
@export var species_stealth: Dictionary = {}  # species ID -> innate stealth (D12: Ohlan)
@export var ghost_days: int  # D12: ghosts fade over 90 days
@export var ghost_cap: int  # most ghosts kept per empire (oldest dropped)
# Intel levels (main spec 7.5; M5 WP6, owner rates 2026-10-04). Points per level; caps are in points.
@export var intel_level_points: int  # 1000: level = points / this
@export var intel_sensor_gain: int  # per day while its units are seen or its systems covered
@export var intel_sensor_cap: int  # sensors alone reach level 2
@export var intel_strong_sensor: int  # covering strength from which sensors reach intel_strong_cap (LP T2)
@export var intel_strong_cap: int  # level 3
@export var intel_decay: int  # per day without a sensor source
@export var intel_battle_gain: int
@export var intel_battle_cap: int
@export var intel_capture_gain: int
@export var intel_capture_cap: int
@export var intel_estimate_width: Array[int] = []  # permille half-width of estimates at levels 1..4


func category() -> String:
	return "fog_rules"


func schema() -> Dictionary:
	return {
		"threshold": {"type": "int", "min": 0},
		"owned_strength": {"type": "int", "min": 0},
		"unit_strength": {"type": "int", "min": 0},
		"scout_strength": {"type": "int", "min": 0},
		"scout_range": {"type": "int", "min": 0},
		"signature_by_size": {"type": "int_map", "keys": SIZES, "min": 0},
		"freighter_signature": {"type": "int", "min": 0},
		"pirate_stealth": {"type": "int", "min": 0},
		"species_stealth": {"type": "int_map", "key_ref": "species", "min": 0},
		"ghost_days": {"type": "int", "min": 0},
		"ghost_cap": {"type": "int", "min": 0},
		"intel_level_points": {"type": "int", "min": 1},
		"intel_sensor_gain": {"type": "int", "min": 0},
		"intel_sensor_cap": {"type": "int", "min": 0},
		"intel_strong_sensor": {"type": "int", "min": 0},
		"intel_strong_cap": {"type": "int", "min": 0},
		"intel_decay": {"type": "int", "min": 0},
		"intel_battle_gain": {"type": "int", "min": 0},
		"intel_battle_cap": {"type": "int", "min": 0},
		"intel_capture_gain": {"type": "int", "min": 0},
		"intel_capture_cap": {"type": "int", "min": 0},
		"intel_estimate_width": {"type": "int_list", "size": 4, "min": 0, "max": 1000},
	}
