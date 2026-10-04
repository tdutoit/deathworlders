class_name Intel
extends RefCounted
## Intel levels 0-4 per directed empire pair (main spec 7.5; M5 WP6; owner rates 2026-10-04), kept in each
## empire's Knowledge as points (fog_rules.intel_level_points per level, 4 levels). Sources and caps:
## sensors (its units seen or its systems covered, daily; higher cap where a strong listening post covers
## them), battles against it, captured ships; agents (WP9) and intel sharing (WP10) add theirs. Without a
## sensor source a day, points decay, but never below level 1 once the empires have fought. Xenolinguistics
## (empire.contact_intel) lifts every contact to that level. Deception Networks (empire.deception) shows an
## empire that many levels lower to others; difficulty adds levels (Admiral) or grants full vision (Deathworld).

const MAX_LEVEL := 4


static func points(state: MatchState, eid: int, other: int) -> int:
	var k: Knowledge = state.knowledge.get_or(eid)
	return int(k.intel.get(other, 0)) if k != null else 0


## Intel level of `eid` on `other` (pirates and own: full; fog Off or full vision: full).
static func level(state: MatchState, eid: int, other: int) -> int:
	var e := state.empire(eid)
	if e == null or other == eid or not Fog.enabled(state) or e.full_vision:
		return MAX_LEVEL
	var r := Fog.rules(state)
	var lv := points(state, eid, other) / maxi(1, r.intel_level_points) + e.intel_bonus
	if other >= 0:
		lv -= SpeciesTraits.empire_add(state, other, "empire.deception")
	return clampi(lv, 0, MAX_LEVEL)


## Adds points from a source up to its cap (in points); gains scale with empire.intel_gain (Signal Analysis).
static func gain(state: MatchState, eid: int, other: int, amount: int, cap: int) -> void:
	if other < 0 or other == eid or state.empire(eid) == null or not Fog.enabled(state):
		return
	var k := Fog.knowledge(state, eid)
	var now := int(k.intel.get(other, 0))
	if now >= cap:
		return
	var boosted := FixedMath.mul_permille(amount, 1000 + SpeciesTraits.empire_permille(state, eid, "empire.intel_gain"))
	k.intel[other] = mini(cap, now + boosted)


## Daily, from Fog.empire_day once visibility is known: sensor gains or decay, and the floors.
static func empire_day(state: MatchState, eid: int, r: FogRulesDef) -> void:
	var k := Fog.knowledge(state, eid)
	var best := {}  # other empire -> best sensor strength over something of theirs seen today
	for uid: int in k.visible:
		var u: Unit = state.units.get_or(uid)
		if u != null and u.owner >= 0:
			best[u.owner] = maxi(int(best.get(u.owner, 0)), int(k.covered.get(u.system_id, 0)))
	for sid: int in k.covered:
		var o := state.galaxy.system(sid).owner
		if o >= 0 and o != eid:
			best[o] = maxi(int(best.get(o, 0)), int(k.covered[sid]))
	var contact_lv := SpeciesTraits.empire_add(state, eid, "empire.contact_intel")
	for other: int in state.empires.ordered():
		if other == eid:
			continue
		if best.has(other):
			var cap := r.intel_sensor_cap if int(best[other]) < r.intel_strong_sensor else r.intel_strong_cap
			gain(state, eid, other, r.intel_sensor_gain, cap)
		elif k.intel.has(other):
			k.intel[other] = maxi(0, int(k.intel[other]) - r.intel_decay)
		var floor_pts := 0
		if k.fought.has(other):
			floor_pts = r.intel_level_points
		if contact_lv > 0 and Relations.has_contact(state, eid, other):
			floor_pts = maxi(floor_pts, contact_lv * r.intel_level_points)
		if floor_pts > int(k.intel.get(other, 0)):
			k.intel[other] = floor_pts
		if k.intel.has(other) and int(k.intel[other]) == 0:
			k.intel.erase(other)


## After a battle: every empire on each side learns about every empire on the other.
static func battle_fought(state: MatchState, b: Battle) -> void:
	if not Fog.enabled(state):
		return
	var r := Fog.rules(state)
	for side in 2:
		for eid: int in b.sides[side]:
			if state.empire(eid) == null:
				continue
			for other: int in b.sides[1 - side]:
				if other >= 0:
					Fog.knowledge(state, eid).fought[other] = true
					gain(state, eid, other, r.intel_battle_gain, r.intel_battle_cap)


static func ship_captured(state: MatchState, captor: int, from_owner: int) -> void:
	if not Fog.enabled(state):
		return
	var r := Fog.rules(state)
	gain(state, captor, from_owner, r.intel_capture_gain, r.intel_capture_cap)


## A3 step 3: the side that gets a free opening round (0 or 1), or -1. Side X ambushes when its lead has
## intel >= 3 on the other lead and the other lead has intel <= 1 on it.
static func ambush_side(state: MatchState, owners: Array[int]) -> int:
	if owners.size() < 2 or owners[0] < 0 or owners[1] < 0 or not Fog.enabled(state):
		return -1
	for side in 2:
		if level(state, owners[side], owners[1 - side]) >= 3 and level(state, owners[1 - side], owners[side]) <= 1:
			return side
	return -1


## [low, high] estimate of a true value at the observer's intel level (owner decision: error bars with a
## fixed seeded offset; level 4 exact, level 0 unknown = [-1, -1]). `salt` keeps estimates of different
## things independent. The bar always contains the true value.
static func estimate(state: MatchState, eid: int, other: int, value: int, salt: String) -> Array[int]:
	var lv := level(state, eid, other)
	if lv <= 0:
		return [-1, -1]
	var r := Fog.rules(state)
	var width := int(r.intel_estimate_width[lv - 1]) if lv - 1 < r.intel_estimate_width.size() else 0
	if width <= 0:
		return [value, value]
	var h := DetHash.hash_value([state.match_seed, eid, other, salt]) & 0x7fffffff
	var offset := h % (width + 1) - width / 2  # within +-width/2, so the true value stays inside
	var centre := FixedMath.mul_permille(value, 1000 + offset)
	return [maxi(0, FixedMath.mul_permille(centre, 1000 - width)), FixedMath.mul_permille(centre, 1000 + width)]
