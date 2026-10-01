class_name Cluster
extends RefCounted
## A region of 5-15 star systems (main spec 3.1).

var id: int
var name: String
var x: int
var y: int
var system_ids: Array[int] = []


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "x": x, "y": y, "system_ids": system_ids.duplicate()}


static func from_dict(d: Dictionary) -> Cluster:
	var c := Cluster.new()
	c.id = int(d["id"])
	c.name = String(d["name"])
	c.x = int(d["x"])
	c.y = int(d["y"])
	c.system_ids = StateIO.ints(d["system_ids"])
	return c
