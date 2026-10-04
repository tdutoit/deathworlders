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
var designs := IdMap.new()  # id -> ShipDesign (M3)
var fleets := IdMap.new()  # id -> Fleet (M3)
var battles := IdMap.new()  # id -> Battle in progress (M3)
var reports := IdMap.new()  # id -> BattleReport of finished battles (M3)
var treaties := IdMap.new()  # id -> Treaty (M4)
var proposals := IdMap.new()  # id -> Proposal waiting for a player
var calls := IdMap.new()  # id -> CallToArms
var deals := IdMap.new()  # id -> Deal being carried out (M4 WP5)
var deliveries := IdMap.new()  # id -> Delivery (deal goods by convoy)
var war_info := IdMap.new()  # id -> War record per warring pair (M4 WP6; `wars` stays the hostility set)
var peace_offers := IdMap.new()  # id -> PeaceOffer waiting for a player
var claims := {}  # "empire:system" -> tick claimed (E7)
var council: Council = null  # the Galactic Council (E9; M4 WP8)
var relations := {}  # "from:to" -> Relation, from first contact (M4); iterate with IdMap.sort_keys
var wars := {}  # "a:b" (lower empire ID first) -> true while those empires are at war (M3 toggle)
var pirate_bases := {}  # system ID -> months until it sends out the next raider (D9)
var agents := IdMap.new()  # id -> Agent (M5 espionage)
var knowledge := IdMap.new()  # empire id -> Knowledge (M5 fog of war, D12)
var reserves := {}  # "holder:resource" -> whole units auto-logistics leaves alone (B8; default 20% of cap)
var next_id := 1
var paused := true  # matches start paused
var speed := 1  # 1, 2, 4 or 8 (CmdSetSpeed)
var command_log: Array[Dictionary] = []  # executed commands {tick, type_id, player, payload}

## Runtime only (never saved or hashed): the frozen content the economy reads. Set by whoever creates or
## loads the state (GalaxyGenerator.new_match, SaveGame.read, Sim.replay_from).
var defs: DefDatabase
var _scratch := {}
var _scratch_tick := -1
## Runtime only: system -> {system: lanes} (AutoLogistics._hops_from). Lanes never change after generation,
## so it lives as long as this state object; never saved or hashed.
var hop_cache := {}
## Runtime only: empire id -> [raided set, {system: region}] (Freight._safe_regions). Recomputed only when
## that empire's raided set changes; never saved or hashed.
var region_cache := {}


## Forget the cache. Sim.execute and Sim.advance call this first, so data cached by views or tools between
## ticks (possibly before this tick's movement) never reaches the sim; peers without a UI must agree.
func clear_scratch() -> void:
	_scratch = {}
	_scratch_tick = -1


## Runtime only: a cache that is emptied whenever the tick changes. For derived data (reach maps) that
## several subsystems need in the same tick. Never saved or hashed.
func scratch() -> Dictionary:
	if _scratch_tick != tick:
		_scratch = {}
		_scratch_tick = tick
	return _scratch


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
		"designs": StateIO.map_to_array(designs),
		"fleets": StateIO.map_to_array(fleets),
		"battles": StateIO.map_to_array(battles),
		"reports": StateIO.map_to_array(reports),
		"wars": wars.duplicate(),
		"relations": _relations_array(),
		"treaties": StateIO.map_to_array(treaties),
		"proposals": StateIO.map_to_array(proposals),
		"calls": StateIO.map_to_array(calls),
		"deals": StateIO.map_to_array(deals),
		"deliveries": StateIO.map_to_array(deliveries),
		"war_info": StateIO.map_to_array(war_info),
		"peace_offers": StateIO.map_to_array(peace_offers),
		"claims": claims.duplicate(),
		"council": council.to_dict() if council != null else {},
		"pirate_bases": pirate_bases.duplicate(),
		"reserves": reserves.duplicate(),
		"knowledge": StateIO.map_to_array(knowledge),
		"agents": StateIO.map_to_array(agents),
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
	s.designs = StateIO.array_to_map(d.get("designs", []), ShipDesign.from_dict)
	s.fleets = StateIO.array_to_map(d.get("fleets", []), Fleet.from_dict)
	s.battles = StateIO.array_to_map(d.get("battles", []), Battle.from_dict)
	s.reports = StateIO.array_to_map(d.get("reports", []), BattleReport.from_dict)
	for k: Variant in d.get("wars", {}):
		s.wars[String(k)] = true
	s.treaties = StateIO.array_to_map(d.get("treaties", []), Treaty.from_dict)
	s.proposals = StateIO.array_to_map(d.get("proposals", []), Proposal.from_dict)
	s.calls = StateIO.array_to_map(d.get("calls", []), CallToArms.from_dict)
	s.deals = StateIO.array_to_map(d.get("deals", []), Deal.from_dict)
	s.deliveries = StateIO.array_to_map(d.get("deliveries", []), Delivery.from_dict)
	s.war_info = StateIO.array_to_map(d.get("war_info", []), War.from_dict)
	s.peace_offers = StateIO.array_to_map(d.get("peace_offers", []), PeaceOffer.from_dict)
	s.claims = StateIO.int_map(d.get("claims", {}))
	s.council = Council.from_dict(d["council"]) if not (d.get("council", {}) as Dictionary).is_empty() else null
	for rd: Dictionary in d.get("relations", []):
		var rel := Relation.from_dict(rd)
		s.relations["%d:%d" % [rel.from, rel.to]] = rel
	for k: Variant in d.get("pirate_bases", {}):
		s.pirate_bases[int(k)] = int(d["pirate_bases"][k])
	s.reserves = StateIO.int_map(d.get("reserves", {}))
	s.knowledge = StateIO.array_to_map(d.get("knowledge", []), Knowledge.from_dict)
	s.agents = StateIO.array_to_map(d.get("agents", []), Agent.from_dict)
	s.next_id = int(d["next_id"])
	s.paused = d["paused"] == true
	s.speed = int(d["speed"])
	for entry: Dictionary in d["command_log"]:
		s.command_log.append(entry.duplicate(true))
	return s


func _relations_array() -> Array:
	var out := []
	for k: String in IdMap.sort_keys(relations.keys()):
		out.append((relations[k] as Relation).to_dict())
	return out


## Per-subsystem hashes, so a desync report can say where states diverged. "meta" covers the
## tick, seed, settings, ID counter, pause and speed; "total" combines everything. The command log
## is input history, not state, so it is left out.
func checksum() -> Dictionary:
	var d := to_dict()
	var parts := {
		"meta": DetHash.hash_value([d["tick"], d["match_seed"], d["settings"], d["next_id"], d["paused"], d["speed"]]),
		"galaxy": DetHash.hash_value(d["galaxy"]),
		"empires": DetHash.hash_value(d["empires"]),  # includes research (M5): techs, queue, progress
		"units": DetHash.hash_value([d["units"], d["pirate_bases"]]),
		"economy": DetHash.hash_value([d["colonies"], d["stations"], d["sectors"]]),
		"logistics": DetHash.hash_value([d["routes"], d["demands"], d["reserves"]]),
		"military": DetHash.hash_value([d["designs"], d["fleets"]]),
		"combat": DetHash.hash_value([d["battles"], d["reports"], d["wars"]]),
		"diplomacy": DetHash.hash_value([d["relations"], d["treaties"], d["proposals"], d["calls"], d["deals"], d["deliveries"], d["war_info"], d["peace_offers"], d["claims"], d["council"]]),
		"rng": DetHash.hash_value(d["rng_streams"]),
		"knowledge": DetHash.hash_value([d["knowledge"], d["agents"]]),  # M5 fog of war, intel, espionage
	}
	parts["total"] = DetHash.hash_value(parts)
	return parts
