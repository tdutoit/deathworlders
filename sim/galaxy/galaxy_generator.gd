class_name GalaxyGenerator
extends RefCounted
## Builds a match's galaxy, empires and capitals from its settings (M1 WP7).
## Integer maths only; every random choice comes from the galaxy RNG stream.
## Distances are lane units (B7: in-cluster lanes ~20-40).

const SYSTEM_SPACING := 22  # minimum distance between systems in one cluster
const SYSTEMS_MIN := 5
const SYSTEMS_MAX := 15
const MAX_LANE_DEGREE := 5
const CLUSTER_RADIUS_MAX := 75  # largest cluster radius from _cluster_radius(SYSTEMS_MAX)
const CLUSTER_GAP := 30  # minimum gap between neighbouring clusters' discs
const CLUSTER_NEIGHBOURS := 3  # corridor candidates per cluster beyond the spanning tree
const EXTRA_CORRIDORS_PERMILLE := 250  # extra corridors (loops) as a share of the tree's edges
const ZONE_INNER_MAX := 60  # orbit radius limits of the inner and habitable zones
const ZONE_HABITABLE_MAX := 120
const HOME_ORBIT := 90  # standard homeworlds take the planet orbiting closest to this
const HOME_SIZE := "large"
const ATTEMPTS_PER_SPACING := 20  # rerolls before the capital spacing rule is relaxed by one jump

var _s: MatchState
var _db: DefDatabase
var _rng: DetRng
var _names: NameGenerator


## A new match: state seeded from seed_value, galaxy generated, capitals placed. If capitals can't
## be spaced, the galaxy is regenerated with the galaxy stream seeded from seed + attempt.
## Returns null and fills errors if the settings are unusable.
static func new_match(settings: MatchSettings, seed_value: int, db: DefDatabase, errors: Array[String]) -> MatchState:
	errors.append_array(check_settings(settings, db))
	if not errors.is_empty():
		return null
	var preset: MatchPresetDef = db.get_def(StringName(settings.galaxy_size))
	var spacing := preset.capital_min_jumps
	var attempt := 0
	while true:
		var state := MatchState.create(settings, seed_value)
		if attempt > 0:
			state.rng_streams.put(DetRng.GALAXY, DetRng.from_seed((seed_value + attempt) & Bits32.M32, DetRng.GALAXY))
		var gen := GalaxyGenerator.new()
		if gen._run(state, db, spacing):
			state.defs = db
			StartSetup.apply(state, db)
			Councils.found(state)  # M4: the Galactic Council (E9)
			StrategicAI.roll_personalities(state)  # M4: E11 weights per empire
			StrategicAI.apply_difficulty(state)  # M4: E13
			return state
		attempt += 1
		if attempt % ATTEMPTS_PER_SPACING == 0:
			spacing -= 1
	return null  # unreachable: spacing 0 always succeeds


static func check_settings(settings: MatchSettings, db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	var preset := db.get_def(StringName(settings.galaxy_size)) as MatchPresetDef
	if preset == null or preset.kind != &"galaxy_size":
		errors.append("unknown galaxy size '%s'" % settings.galaxy_size)
	var pace := db.get_def(StringName(settings.pace)) as MatchPresetDef
	if pace == null or pace.kind != &"pace":
		errors.append("unknown pace '%s'" % settings.pace)
	var slots := {}
	for p in settings.players:
		if not db.get_def(StringName(p["species"])) is SpeciesDef:
			errors.append("player slot %d: unknown species '%s'" % [p["slot"], p["species"]])
		if slots.has(p["slot"]):
			errors.append("player slot %d used twice" % p["slot"])
		if p["controller"] == "ai" and not db.get_def(StringName(String(p.get("difficulty", MatchSettings.OFFICER)))) is DifficultyDef:
			errors.append("player slot %d: unknown difficulty '%s'" % [p["slot"], p.get("difficulty", "")])
		slots[p["slot"]] = true
	if preset != null and settings.players.size() > preset.target_systems:
		errors.append("more players than systems")
	return errors


func _run(state: MatchState, db: DefDatabase, capital_spacing: int) -> bool:
	_s = state
	_db = db
	_rng = state.rng(DetRng.GALAXY)
	_names = NameGenerator.new(db, _rng)
	_names.reserve(SolTemplate.SYSTEM_NAME)
	var preset: MatchPresetDef = db.get_def(StringName(state.settings.galaxy_size))
	var sizes := _cluster_sizes(preset)
	var centres := _place_clusters(sizes.size())
	for i in sizes.size():
		_build_cluster(centres[i], sizes[i])
	_build_corridors()
	for id: int in _s.galaxy.systems.keys():
		_make_planets(_s.galaxy.system(id))
	return _place_capitals(capital_spacing)


# --- clusters and systems ---

## System count per cluster: 5-15 each, adjusted so the total hits the preset target.
func _cluster_sizes(preset: MatchPresetDef) -> Array[int]:
	var n := preset.cluster_count
	var target := clampi(preset.target_systems, n * SYSTEMS_MIN, n * SYSTEMS_MAX)
	var sizes: Array[int] = []
	var total := 0
	for i in n:
		sizes.append(_rng.range(SYSTEMS_MIN, SYSTEMS_MAX + 1))
		total += sizes[i]
	while total != target:
		var i := _rng.range(0, n)
		if total > target and sizes[i] > SYSTEMS_MIN:
			sizes[i] -= 1
			total -= 1
		elif total < target and sizes[i] < SYSTEMS_MAX:
			sizes[i] += 1
			total += 1
	return sizes


static func _cluster_radius(systems: int) -> int:
	return 11 * FixedMath.isqrt(2 * systems) + 20


## Cluster centres by dart throwing in a disc; the disc grows 10% if it gets too crowded.
func _place_clusters(count: int) -> Array[Vector2i]:
	var spacing := 2 * CLUSTER_RADIUS_MAX + CLUSTER_GAP
	var radius := FixedMath.floor_div(120 * FixedMath.isqrt(count * 100), 10)  # ~120 * sqrt(count)
	while true:
		var points := _poisson_disc(Vector2i.ZERO, radius, spacing, count, 500 * count)
		if points.size() == count:
			return points
		radius += FixedMath.floor_div(radius, 10)
	return []


func _build_cluster(centre: Vector2i, size: int) -> void:
	var c := Cluster.new()
	c.id = _s.alloc_id()
	c.name = _names.cluster_name()
	c.x = centre.x
	c.y = centre.y
	_s.galaxy.clusters.put(c.id, c)
	var radius := _cluster_radius(size)
	var points: Array[Vector2i] = []
	while true:
		points = _poisson_disc(centre, radius, SYSTEM_SPACING, size, 300 * size)
		if points.size() == size:
			break
		radius += 10
	var star_types := _db.defs("star_type")
	var star_weights: Array[int] = []
	for def in star_types:
		star_weights.append((def as StarTypeDef).weight)
	for p in points:
		var sys := StarSystem.new()
		sys.id = _s.alloc_id()
		sys.name = _names.star_name()
		sys.cluster_id = c.id
		sys.x = p.x
		sys.y = p.y
		sys.star_type = String(star_types[_pick_weighted(star_weights)].id)
		_s.galaxy.systems.put(sys.id, sys)
		c.system_ids.append(sys.id)
	_build_cluster_lanes(c)


## Up to `count` points at least `spacing` apart inside the disc (centre, radius).
func _poisson_disc(centre: Vector2i, radius: int, spacing: int, count: int, attempts: int) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var r2 := radius * radius
	var s2 := spacing * spacing
	for i in attempts:
		if points.size() == count:
			break
		var x := _rng.range(-radius, radius + 1)
		var y := _rng.range(-radius, radius + 1)
		if x * x + y * y > r2:
			continue
		var p := centre + Vector2i(x, y)
		var ok := true
		for q in points:
			if FixedMath.dist2(p.x, p.y, q.x, q.y) < s2:
				ok = false
				break
		if ok:
			points.append(p)
	return points


# --- lanes ---

## Minimum spanning tree plus the relative-neighbourhood graph; then nodes above the degree cap drop
## their longest non-tree lanes. The tree keeps every cluster connected even with tied distances.
func _build_cluster_lanes(c: Cluster) -> void:
	var ids := c.system_ids
	var edges := []  # [dist2, a, b], a < b
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			edges.append([_sys_dist2(ids[i], ids[j]), ids[i], ids[j]])
	edges.sort_custom(_edge_less)
	var tree := _spanning_tree(edges)
	var chosen := {}  # "a:b" -> edge
	for e in tree:
		chosen[_edge_key(e)] = e
	for e: Array in edges:
		if chosen.has(_edge_key(e)):
			continue
		var blocked := false
		for r in ids:
			if r != e[1] and r != e[2] and maxi(_sys_dist2(e[1], r), _sys_dist2(e[2], r)) < e[0]:
				blocked = true
				break
		if not blocked:
			chosen[_edge_key(e)] = e
	var in_tree := {}
	for e in tree:
		in_tree[_edge_key(e)] = true
	var lanes: Array = chosen.values()
	lanes.sort_custom(_edge_less)
	var degree := {}
	for e: Array in lanes:
		degree[e[1]] = degree.get(e[1], 0) + 1
		degree[e[2]] = degree.get(e[2], 0) + 1
	for i in range(lanes.size() - 1, -1, -1):  # longest first
		var e: Array = lanes[i]
		if in_tree.has(_edge_key(e)):
			continue
		if degree[e[1]] > MAX_LANE_DEGREE or degree[e[2]] > MAX_LANE_DEGREE:
			degree[e[1]] -= 1
			degree[e[2]] -= 1
			lanes.remove_at(i)
	for e: Array in lanes:
		_add_lane(e[1], e[2], e[0])


## Kruskal over edges sorted by (dist2, a, b).
func _spanning_tree(sorted_edges: Array) -> Array:
	var parent := {}
	var tree := []
	for e: Array in sorted_edges:
		var ra := _find(parent, e[1])
		var rb := _find(parent, e[2])
		if ra != rb:
			parent[ra] = rb
			tree.append(e)
	return tree


static func _find(parent: Dictionary, x: int) -> int:
	while parent.has(x):
		x = parent[x]
	return x


func _add_lane(a: int, b: int, dist2: int) -> Hyperlane:
	var lane := Hyperlane.new()
	lane.id = _s.alloc_id()
	lane.a = mini(a, b)
	lane.b = maxi(a, b)
	lane.length = _ceil_sqrt(dist2)
	_s.galaxy.lanes.put(lane.id, lane)
	_s.galaxy.system(a).lane_ids.append(lane.id)
	_s.galaxy.system(b).lane_ids.append(lane.id)
	return lane


## Clusters joined by a spanning tree plus ~25% extra edges for loops; each corridor is a lane between
## the closest pair of systems of the two clusters.
func _build_corridors() -> void:
	var cids: Array = _s.galaxy.clusters.keys()
	var edges := []
	for i in cids.size():
		for j in range(i + 1, cids.size()):
			var a := _s.galaxy.cluster(cids[i])
			var b := _s.galaxy.cluster(cids[j])
			edges.append([FixedMath.dist2(a.x, a.y, b.x, b.y), cids[i], cids[j]])
	edges.sort_custom(_edge_less)
	var tree := _spanning_tree(edges)
	var picked := {}
	for e in tree:
		picked[_edge_key(e)] = e
	# Extra loops come from each cluster's nearest neighbours, shortest first.
	var near := {}
	for cid: int in cids:
		var mine := edges.filter(func(e: Array) -> bool: return e[1] == cid or e[2] == cid)
		for k in mini(CLUSTER_NEIGHBOURS, mine.size()):
			near[_edge_key(mine[k])] = mine[k]
	var extras: Array = near.values().filter(func(e: Array) -> bool: return not picked.has(_edge_key(e)))
	extras.sort_custom(_edge_less)
	var want := FixedMath.div_round(tree.size() * EXTRA_CORRIDORS_PERMILLE, 1000)
	for k in mini(want, extras.size()):
		picked[_edge_key(extras[k])] = extras[k]
	var corridors: Array = picked.values()
	corridors.sort_custom(_edge_less)
	for e: Array in corridors:
		var best := []
		for a: int in _s.galaxy.cluster(e[1]).system_ids:
			for b: int in _s.galaxy.cluster(e[2]).system_ids:
				var cand := [_sys_dist2(a, b), mini(a, b), maxi(a, b)]
				if best.is_empty() or _edge_less(cand, best):
					best = cand
		var lane := _add_lane(best[1], best[2], best[0])
		_s.galaxy.corridors.append(lane.id)
	_s.galaxy.corridors.sort()


# --- planets ---

func _make_planets(sys: StarSystem) -> void:
	var star: StarTypeDef = _db.get_def(StringName(sys.star_type))
	var count := _rng.range(star.planet_min, star.planet_max + 1)
	var types := _db.defs("planet_type")
	var radius := 0
	for i in count:
		radius += 25 + _rng.range(0, 10)
		var zone := "inner" if radius < ZONE_INNER_MAX else ("habitable" if radius <= ZONE_HABITABLE_MAX else "outer")
		var weights: Array[int] = []
		for def in types:
			weights.append(int((def as PlanetTypeDef).zone_weights.get(StringName(zone), 0)))
		var ptype: PlanetTypeDef = types[_pick_weighted(weights)]
		var size_weights: Array[int] = []
		for size in PlanetTypeDef.SIZES:
			size_weights.append(int(ptype.size_weights.get(StringName(size), 0)))
		var size: String = PlanetTypeDef.SIZES[_pick_weighted(size_weights)]
		var deposits := {}
		for res_id: Variant in IdMap.sort_keys(ptype.deposit_chances.keys()):
			if _rng.range(0, 1000) < ptype.deposit_chances[res_id]:
				deposits[String(res_id)] = _rng.range(1, 4)
		_add_planet(sys, NameGenerator.planet_name(sys.name, i), String(ptype.id), size, i, radius, deposits)


func _add_planet(sys: StarSystem, name: String, ptype: String, size: String, orbit_index: int,
		radius: int, deposits: Dictionary, parent_id: int = StateIO.NONE) -> Planet:
	var p := Planet.new()
	p.id = _s.alloc_id()
	p.system_id = sys.id
	p.parent_id = parent_id
	p.name = name
	p.planet_type = ptype
	p.size = size
	p.orbit_index = orbit_index
	p.orbit_radius = radius
	p.deposits = deposits
	p.orbital_slots = (_db.get_def(PlanetSizeDef.id_for(size)) as PlanetSizeDef).orbital_slots
	_s.galaxy.planets.put(p.id, p)
	sys.planet_ids.append(p.id)
	return p


# --- capitals ---

## Picks one capital system per player, spread so every pair is >= spacing lane jumps apart; returns
## false if that isn't possible on this galaxy. Then builds Sol / standard homeworlds and empires.
func _place_capitals(spacing: int) -> bool:
	var players := _s.settings.players.duplicate()
	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["slot"] < b["slot"])
	if players.is_empty():
		return true
	var ids: Array = _s.galaxy.systems.keys()
	var chosen: Array[int] = [ids[_rng.range(0, ids.size())]]
	var hops: Array[Dictionary] = [_hops_from(chosen[0])]
	while chosen.size() < players.size():
		var best := -1
		var best_min := -1
		for id: int in ids:
			if id in chosen:
				continue
			var m := 1 << 30
			for h in hops:
				m = mini(m, h.get(id, 1 << 30))
			if m > best_min:
				best_min = m
				best = id
		if best_min < spacing:
			return false
		chosen.append(best)
		hops.append(_hops_from(best))
	var sol_used := false
	for i in players.size():
		var p: Dictionary = players[i]
		var species: SpeciesDef = _db.get_def(StringName(p["species"]))
		var e := Empire.new()
		e.id = _s.alloc_id()
		e.species = String(species.id)
		e.player_slot = int(p["slot"])
		e.color = species.color
		_s.empires.put(e.id, e)
		var sys := _s.galaxy.system(chosen[i])
		if species.home_template == &"sol" and not sol_used:
			sol_used = true
			e.capital_planet = _build_sol(sys)
		else:
			e.capital_planet = _build_standard_home(sys, species)
		sys.owner = e.id
		_s.galaxy.planet(e.capital_planet).owner = e.id
	return true


## Lane jumps from one system to every reachable system (BFS in ID order).
func _hops_from(start: int) -> Dictionary:
	var dist := {start: 0}
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for lane_id in _s.galaxy.system(at).lane_ids:
			var next := _s.galaxy.lane(lane_id).other_end(at)
			if not dist.has(next):
				dist[next] = dist[at] + 1
				queue.append(next)
	return dist


## Replaces the system's planets with Sol; returns Earth's ID.
func _build_sol(sys: StarSystem) -> int:
	for pid in sys.planet_ids:
		_s.galaxy.planets.erase(pid)
	sys.planet_ids.clear()
	sys.name = SolTemplate.SYSTEM_NAME
	sys.star_type = SolTemplate.STAR
	var by_name := {}
	var orbit := 0
	var capital := StateIO.NONE
	for body: Dictionary in SolTemplate.BODIES:
		var deposits := {}
		for r: String in body["deposits"]:
			deposits["core:resource/" + r] = body["deposits"][r]
		var parent: int = by_name[body["parent"]] if body.has("parent") else StateIO.NONE
		var index := 0 if body.has("parent") else orbit
		var p := _add_planet(sys, body["name"], "core:planet_type/" + body["type"], body["size"], index,
				body["radius"], deposits, parent)
		by_name[body["name"]] = p.id
		if not body.has("parent"):
			orbit += 1
		if body["name"] == SolTemplate.CAPITAL:
			capital = p.id
	return capital


## Turns the planet orbiting closest to HOME_ORBIT into a large homeworld of the species' type.
func _build_standard_home(sys: StarSystem, species: SpeciesDef) -> int:
	var best: Planet = null
	for pid in sys.planet_ids:
		var p := _s.galaxy.planet(pid)
		if best == null or absi(p.orbit_radius - HOME_ORBIT) < absi(best.orbit_radius - HOME_ORBIT):
			best = p
	best.planet_type = String(species.home_planet_type)
	best.size = HOME_SIZE
	best.orbital_slots = (_db.get_def(PlanetSizeDef.id_for(HOME_SIZE)) as PlanetSizeDef).orbital_slots
	return best.id


# --- helpers ---

func _pick_weighted(weights: Array[int]) -> int:
	var total := 0
	for w in weights:
		total += w
	var roll := _rng.range(0, total)
	for i in weights.size():
		roll -= weights[i]
		if roll < 0:
			return i
	return weights.size() - 1


func _sys_dist2(a: int, b: int) -> int:
	var sa := _s.galaxy.system(a)
	var sb := _s.galaxy.system(b)
	return FixedMath.dist2(sa.x, sa.y, sb.x, sb.y)


static func _ceil_sqrt(n: int) -> int:
	var r := FixedMath.isqrt(n)
	return r if r * r == n else r + 1


static func _edge_key(e: Array) -> String:
	return "%d:%d" % [e[1], e[2]]


static func _edge_less(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] < b[0]
	if a[1] != b[1]:
		return a[1] < b[1]
	return a[2] < b[2]
