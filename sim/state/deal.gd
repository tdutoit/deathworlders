class_name Deal
extends RefCounted
## An accepted deal being carried out (Sub-spec E6; M4 WP5). `a` proposed it, `b` accepted. Items:
## {"giver", "kind" ("credits" | "influence" | "resource" | "system"), "ref" (resource ID or system ID as a
## string), "amount" (whole units; 1 for a system), "months" (0 = once, N = every month for N months),
## "left" (payments still due)}.

var id: int
var a: int
var b: int
var tick := 0
var items: Array = []


func to_dict() -> Dictionary:
	return {"id": id, "a": a, "b": b, "tick": tick, "items": items.duplicate(true)}


static func from_dict(d: Dictionary) -> Deal:
	var x := Deal.new()
	x.id = int(d["id"])
	x.a = int(d["a"])
	x.b = int(d["b"])
	x.tick = int(d.get("tick", 0))
	x.items = StateIO.ints_deep(d.get("items", []))
	return x
