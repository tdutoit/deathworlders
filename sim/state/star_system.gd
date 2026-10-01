class_name StarSystem
extends RefCounted
## One star system (main spec 3.3).

var id: int
var name: String
var cluster_id: int
var x: int
var y: int
var star_type: String  # star_type Def ID
var planet_ids: Array[int] = []
var lane_ids: Array[int] = []
var owner: int = StateIO.NONE  # empire ID


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "cluster_id": cluster_id, "x": x, "y": y, "star_type": star_type,
		"planet_ids": planet_ids.duplicate(), "lane_ids": lane_ids.duplicate(), "owner": owner,
	}


static func from_dict(d: Dictionary) -> StarSystem:
	var s := StarSystem.new()
	s.id = int(d["id"])
	s.name = String(d["name"])
	s.cluster_id = int(d["cluster_id"])
	s.x = int(d["x"])
	s.y = int(d["y"])
	s.star_type = String(d["star_type"])
	s.planet_ids = StateIO.ints(d["planet_ids"])
	s.lane_ids = StateIO.ints(d["lane_ids"])
	s.owner = int(d["owner"])
	return s
