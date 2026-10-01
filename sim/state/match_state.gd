class_name MatchState
extends RefCounted
## The whole match state (M1 WP4). The spec calls it GameState; that name belongs to the autoload,
## which holds the current MatchState. Changed only by Commands and tick functions.
## Entity IDs come from alloc_id(): monotonic, so they are deterministic as long as creation order is.

const RNG_STREAMS: Array[String] = [DetRng.GALAXY, DetRng.COMBAT, DetRng.EVENTS, DetRng.AI, DetRng.MISC]

var tick := 0  # hour ticks since the match start
var settings := MatchSettings.new()
var match_seed := 0
var rng_streams := IdMap.new()  # stream name -> DetRng
var galaxy := Galaxy.new()
var empires := IdMap.new()  # id -> Empire
var units := IdMap.new()  # id -> Unit
var next_id := 1


## A fresh state with every RNG stream seeded from match_seed.
static func create(match_settings: MatchSettings, seed_value: int) -> MatchState:
	var s := MatchState.new()
	s.settings = match_settings
	s.match_seed = seed_value & Bits32.M32
	for stream in RNG_STREAMS:
		s.rng_streams.put(stream, DetRng.from_seed(s.match_seed, stream))
	return s


func alloc_id() -> int:
	var id := next_id
	next_id += 1
	return id


func rng(stream: String) -> DetRng:
	if not rng_streams.has(stream):
		rng_streams.put(stream, DetRng.from_seed(match_seed, stream))
	return rng_streams.get_or(stream)


func to_dict() -> Dictionary:
	var rngs := {}
	for name: String in rng_streams:
		rngs[name] = (rng_streams.get_or(name) as DetRng).get_state()
	return {
		"tick": tick,
		"settings": settings.to_dict(),
		"match_seed": match_seed,
		"rng_streams": rngs,
		"galaxy": galaxy.to_dict(),
		"empires": StateIO.map_to_array(empires),
		"units": StateIO.map_to_array(units),
		"next_id": next_id,
	}


static func from_dict(d: Dictionary) -> MatchState:
	var s := MatchState.new()
	s.tick = int(d["tick"])
	s.settings = MatchSettings.from_dict(d["settings"])
	s.match_seed = int(d["match_seed"])
	var rngs: Dictionary = d["rng_streams"]
	for name: String in IdMap.sort_keys(rngs.keys()):
		var r := DetRng.new()
		r.set_state(StateIO.ints(rngs[name]))
		s.rng_streams.put(name, r)
	s.galaxy = Galaxy.from_dict(d["galaxy"])
	s.empires = StateIO.array_to_map(d["empires"], Empire.from_dict)
	s.units = StateIO.array_to_map(d["units"], Unit.from_dict)
	s.next_id = int(d["next_id"])
	return s


## Per-subsystem hashes, so a desync report can say where states diverged. "meta" covers the
## tick, seed, settings and ID counter; "total" combines everything.
func checksum() -> Dictionary:
	var d := to_dict()
	var parts := {
		"meta": DetHash.hash_value([d["tick"], d["match_seed"], d["settings"], d["next_id"]]),
		"galaxy": DetHash.hash_value(d["galaxy"]),
		"empires": DetHash.hash_value(d["empires"]),
		"units": DetHash.hash_value(d["units"]),
		"rng": DetHash.hash_value(d["rng_streams"]),
	}
	parts["total"] = DetHash.hash_value(parts)
	return parts
