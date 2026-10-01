class_name Demand
extends RefCounted
## A demand target (Sub-spec B8): keep `resource` at `target` units or more at a holder. Auto-logistics
## fills the deficit from surplus elsewhere.

var id: int
var owner: int
var holder: int
var resource: String
var target: int  # whole units
var priority := 2  # 1 Low, 2 Normal, 3 Critical


func to_dict() -> Dictionary:
	return {"id": id, "owner": owner, "holder": holder, "resource": resource, "target": target, "priority": priority}


static func from_dict(d: Dictionary) -> Demand:
	var m := Demand.new()
	m.id = int(d["id"])
	m.owner = int(d["owner"])
	m.holder = int(d["holder"])
	m.resource = String(d["resource"])
	m.target = int(d["target"])
	m.priority = int(d["priority"])
	return m
