class_name Route
extends RefCounted
## A manual freight route (Sub-spec B8): source holder -> destination holder, one resource, an amount per
## trip and a priority. Holders are colonies (planet ID) or stations (station ID). Freighters assigned to it
## carry Unit.route = this ID.

var id: int
var owner: int
var source: int
var dest: int
var resource: String
var amount: int  # whole units per trip
var priority := 2  # 1 Low, 2 Normal, 3 Critical


func to_dict() -> Dictionary:
	return {"id": id, "owner": owner, "source": source, "dest": dest, "resource": resource, "amount": amount, "priority": priority}


static func from_dict(d: Dictionary) -> Route:
	var r := Route.new()
	r.id = int(d["id"])
	r.owner = int(d["owner"])
	r.source = int(d["source"])
	r.dest = int(d["dest"])
	r.resource = String(d["resource"])
	r.amount = int(d["amount"])
	r.priority = int(d["priority"])
	return r
