class_name Sector
extends RefCounted
## A sector (Sub-spec D3): systems grouped around a hub (the capital, a Logistics Station T2+ or a
## Logistics-focus planet), run by a directive. M2 has no leaders: a built-in default governor runs it.

var id: int
var owner: int
var hub: int  # holder ID (colony or station)
var directive := "core:directive/balanced"
var core := false  # the capital's Core Sector (D3): always reaches core_sector_range
var systems: Array[int] = []  # member systems, recomputed monthly
var export_quotas := {}  # resource ID -> permille of surplus sent up the trunk (D5; default from rules)


func to_dict() -> Dictionary:
	return {"id": id, "owner": owner, "hub": hub, "directive": directive, "core": core, "systems": systems.duplicate(),
		"export_quotas": export_quotas.duplicate()}


static func from_dict(d: Dictionary) -> Sector:
	var s := Sector.new()
	s.id = int(d["id"])
	s.owner = int(d["owner"])
	s.hub = int(d["hub"])
	s.directive = String(d["directive"])
	s.core = d.get("core", false) == true
	s.systems = StateIO.ints(d["systems"])
	s.export_quotas = StateIO.int_map(d.get("export_quotas", {}))
	return s
