class_name Delivery
extends RefCounted
## Goods a deal sends by convoy (E6, B15; M4 WP5): the giver's freighters carry `remaining` milli-units of
## `resource` to the receiver's capital. A freighter lost on the way fails the deal.

var id: int
var deal: int
var giver: int
var receiver: int
var resource: String
var remaining := 0  # milli-units still to deliver
var unit: int = StateIO.NONE  # freighter carrying it now


func to_dict() -> Dictionary:
	return {"id": id, "deal": deal, "giver": giver, "receiver": receiver, "resource": resource,
		"remaining": remaining, "unit": unit}


static func from_dict(d: Dictionary) -> Delivery:
	var x := Delivery.new()
	x.id = int(d["id"])
	x.deal = int(d["deal"])
	x.giver = int(d["giver"])
	x.receiver = int(d["receiver"])
	x.resource = String(d["resource"])
	x.remaining = int(d["remaining"])
	x.unit = int(d.get("unit", StateIO.NONE))
	return x
