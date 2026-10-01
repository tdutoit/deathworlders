class_name ShipDesign
extends RefCounted
## An empire's ship design (main spec 7.4, C5): a hull and one component per hull slot ("" = empty), by
## string ID. Lives in the match state; saving, editing and deleting are Commands, so designs stay
## deterministic in multiplayer. Ships keep a copy of their components, so editing a design never changes
## ships already built or queued.

var id: int
var owner: int
var name: String
var hull: String  # hull Def ID
var components: Array[String] = []  # component Def IDs in hull slot order; "" = empty slot
var source := ""  # design Def it was copied from ("" for player-made)


func to_dict() -> Dictionary:
	return {"id": id, "owner": owner, "name": name, "hull": hull, "components": components.duplicate(), "source": source}


static func from_dict(d: Dictionary) -> ShipDesign:
	var s := ShipDesign.new()
	s.id = int(d["id"])
	s.owner = int(d["owner"])
	s.name = String(d["name"])
	s.hull = String(d["hull"])
	s.components.assign(d["components"])
	s.source = String(d.get("source", ""))
	return s
