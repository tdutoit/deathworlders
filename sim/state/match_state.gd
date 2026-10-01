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
var colonies := IdMap.new()  # planet id -> Colony (M2)
var stations := IdMap.new()  # id -> Station (M2)
var routes := IdMap.new()  # id -> Route (M2)
var demands := IdMap.new()  # id -> Demand (M2, B8)
var sectors := IdMap.new()  # id -> Sector (M2, D3)
var reserves := {}  # "holder:resource" -> whole units auto-logistics leaves alone (B8; default 20% of cap)
var next_id := 1
var paused := true  # matches start paused
var speed := 1  # 1, 2, 4 or 8 (CmdSetSpeed)
var command_log: Array[Dictionary] = []  # executed commands {tick, type_id, player, payload}

## Runtime only (never saved or hashed): the frozen content the economy reads. Set by whoever creates or
## loads the state (GalaxyGenerator.new_match, SaveGame.read, Sim.replay_from).
var defs: DefDatabase


## A fresh state with every RNG stream seeded from match_seed.
static func create(match_settings: MatchSettings, seed_value: int) -> MatchState:
	var s := MatchState.new()
	s.settings = match_settings
	s.match_seed = seed_value & Bits32.M32
	for stream in RNG_STREAMS:
		s.rng_streams.put(stream, DetRng.from_seed(s.match_seed, stream))
	return s


func colony(planet_id: int) -> Colony:
	return colonies.get_or(planet_id)


func station(id: int) -> Station:
	return stations.get_or(id)


func empire(id: int) -> Empire:
	return empires.get_or(id)


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
		"colonies": StateIO.map_to_array(colonies),
		"stations": StateIO.map_to_array(stations),
		"routes": StateIO.map_to_array(routes),
		"demands": StateIO.map_to_array(demands),
		"sectors": StateIO.map_to_array(sectors),
		"reserves": reserves.duplicate(),
		"next_id": next_id,
		"paused": paused,
		"speed": speed,
		"command_log": command_log.duplicate(true),
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
	s.colonies = StateIO.array_to_map(d.get("colonies", []), Colony.from_dict)
	s.stations = StateIO.array_to_map(d.get("stations", []), Station.from_dict)
	s.routes = StateIO.array_to_map(d.get("routes", []), Route.from_dict)
	s.demands = StateIO.array_to_map(d.get("demands", []), Demand.from_dict)
	s.sectors = StateIO.array_to_map(d.get("sectors", []), Sector.from_dict)
	s.reserves = StateIO.int_map(d.get("reserves", {}))
	s.next_id = int(d["next_id"])
	s.paused = d["paused"] == true
	s.speed = int(d["speed"])
	for entry: Dictionary in d["command_log"]:
		s.command_log.append(entry.duplicate(true))
	return s


## Per-subsystem hashes, so a desync report can say where states diverged. "meta" covers the
## tick, seed, settings, ID counter, pause and speed; "total" combines everything. The command log
## is input history, not state, so it is left out.
func checksum() -> Dictionary:
	var d := to_dict()
	var parts := {
		"meta": DetHash.hash_value([d["tick"], d["match_seed"], d["settings"], d["next_id"], d["paused"], d["speed"]]),
		"galaxy": DetHash.hash_value(d["galaxy"]),
		"empires": DetHash.hash_value(d["empires"]),
		"units": DetHash.hash_value(d["units"]),
		"economy": DetHash.hash_value([d["colonies"], d["stations"], d["sectors"]]),
		"logistics": DetHash.hash_value([d["routes"], d["demands"], d["reserves"]]),
		"rng": DetHash.hash_value(d["rng_streams"]),
	}
	parts["total"] = DetHash.hash_value(parts)
	return parts
