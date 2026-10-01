class_name Galaxy
extends RefCounted
## The map: clusters, systems, lanes and planets, each an IdMap keyed by entity ID.
## corridors lists the IDs of lanes that join two clusters (sorted).

var clusters := IdMap.new()
var systems := IdMap.new()
var lanes := IdMap.new()
var planets := IdMap.new()
var corridors: Array[int] = []


func cluster(id: int) -> Cluster:
	return clusters.get_or(id)


func system(id: int) -> StarSystem:
	return systems.get_or(id)


func lane(id: int) -> Hyperlane:
	return lanes.get_or(id)


func planet(id: int) -> Planet:
	return planets.get_or(id)


## The lane joining two systems, or null.
func lane_between(a: int, b: int) -> Hyperlane:
	var s := system(a)
	if s == null:
		return null
	for lane_id in s.lane_ids:
		var l := lane(lane_id)
		if l.other_end(a) == b:
			return l
	return null


func to_dict() -> Dictionary:
	return {
		"clusters": StateIO.map_to_array(clusters),
		"systems": StateIO.map_to_array(systems),
		"lanes": StateIO.map_to_array(lanes),
		"planets": StateIO.map_to_array(planets),
		"corridors": corridors.duplicate(),
	}


static func from_dict(d: Dictionary) -> Galaxy:
	var g := Galaxy.new()
	g.clusters = StateIO.array_to_map(d["clusters"], Cluster.from_dict)
	g.systems = StateIO.array_to_map(d["systems"], StarSystem.from_dict)
	g.lanes = StateIO.array_to_map(d["lanes"], Hyperlane.from_dict)
	g.planets = StateIO.array_to_map(d["planets"], Planet.from_dict)
	g.corridors = StateIO.ints(d["corridors"])
	return g
