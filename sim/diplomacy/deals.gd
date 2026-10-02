class_name Deals
extends RefCounted
## Deals (Sub-spec E6, B15; M4 WP5, owner decisions 2026-10-02): credits, influence, resources and claimed
## systems, once or every month. Valued per E6 from the valuing empire's side; resources travel by the
## giver's freighters (a trade agreement lets them cross the border), credits and influence move at once,
## systems change hands with their colonies (pops keep their species) and stations.

const KINDS: Array[String] = ["credits", "influence", "resource", "system"]
const CREDITS := "core:resource/credits"
const INFLUENCE := "core:resource/influence"


static func rules(state: MatchState) -> DiplomacyRulesDef:
	return Relations.rules(state)


## "" if these items can be dealt between `a` and `b` (shape, ownership, stock for one-off items, the trade
## agreement for goods unless `with_trade` is being signed with them), else the reason.
static func check(state: MatchState, a: int, b: int, items: Array, with_trade := false) -> String:
	if items.is_empty():
		return "an empty deal"
	for it: Variant in items:
		if not it is Dictionary:
			return "items must be objects"
		var giver := int(it.get("giver", -1))
		var kind := String(it.get("kind", ""))
		var amount := int(it.get("amount", 0))
		var months := int(it.get("months", 0))
		if giver != a and giver != b:
			return "every item is given by one of the two empires"
		if not kind in KINDS or amount <= 0 or months < 0:
			return "unknown item or amount"
		match kind:
			"credits", "influence":
				var res := CREDITS if kind == "credits" else INFLUENCE
				if months == 0 and int(state.empire(giver).treasury.get(res, 0)) < amount * Stockpile.MILLI:
					return "not enough %s" % kind
			"resource":
				var res := String(it.get("ref", ""))
				if not state.defs.get_def(StringName(res)) is ResourceDef:
					return "unknown resource %s" % res
				if not with_trade and not Treaties.has_effect(state, a, b, "trade"):
					return "goods need a trade agreement"
				if months == 0 and total_stock(state, giver, res) < amount * Stockpile.MILLI:
					return "not enough %s" % res
			"system":
				var sid := int(it.get("ref", -1))
				var sys := state.galaxy.system(sid)
				if sys == null or sys.owner != giver:
					return "%s doesn't own that system" % giver
				if sid == state.galaxy.planet(state.empire(giver).capital_planet).system_id:
					return "the capital system can't be ceded"
				if months != 0 or amount != 1:
					return "a system is ceded once"
	return ""


static func total_stock(state: MatchState, eid: int, res: String) -> int:
	var total := 0
	for h in AutoLogistics._own_holders(state, eid):
		var sp := Holders.stockpile(state, h)
		if sp != null:
			total += sp.milli(res)
	return total


## E6 scarcity for the valuing empire (permille): its target stock (months of last month's use) over what it
## has, clamped.
static func scarcity(state: MatchState, eid: int, res: String) -> int:
	var r := rules(state)
	var used := 0
	for pid: int in state.colonies.ordered():
		var c: Colony = state.colonies.get_or(pid)
		if c.owner == eid:
			used += int(c.last_consumed.get(res, 0))
	var target := used * r.deal_target_months
	return clampi(FixedMath.floor_div(target * 1000, maxi(1, total_stock(state, eid, res))), r.scarcity_min, r.scarcity_max)


## E6 value of an item to `valuer` in credits: base value x amount x scarcity, greed on what it gives up,
## recurring items at recurring_permille of their total, systems by their colonies' output.
static func value(state: MatchState, valuer: int, it: Dictionary) -> int:
	var r := rules(state)
	var amount := int(it["amount"])
	var v := 0
	match String(it["kind"]):
		"credits":
			v = amount
		"influence":
			v = amount * r.influence_value
		"resource":
			var rd := state.defs.get_def(StringName(String(it["ref"]))) as ResourceDef
			v = FixedMath.mul_permille(FixedMath.floor_div(amount * rd.base_value, 1000), scarcity(state, valuer, String(it["ref"])))
		"system":
			v = maxi(r.system_min_value, system_output(state, int(it["ref"])) * r.system_value_months)
	var months := int(it.get("months", 0))
	if months > 0:
		v = FixedMath.mul_permille(v * months, r.recurring_permille)
	if int(it["giver"]) == valuer:
		v = FixedMath.mul_permille(v, r.greed_base + Treaties.personality(state, valuer, "greed") * r.greed_per_point)
	return v


## Monthly output of the system's colonies, in credits at base value.
static func system_output(state: MatchState, sid: int) -> int:
	var total := 0
	for pid in state.galaxy.system(sid).planet_ids:
		var c := state.colony(pid)
		if c == null:
			continue
		for res: String in IdMap.sort_keys(c.last_produced.keys()):
			var rd := state.defs.get_def(StringName(res)) as ResourceDef
			if rd != null:
				total += FixedMath.floor_div(int(c.last_produced[res]) * rd.base_value, 1000 * 1000)
	return total


## E5's deal term for `valuer`: (what it gains - what it gives) in credits, scaled and capped.
static func balance_points(state: MatchState, valuer: int, items: Array) -> int:
	var r := rules(state)
	var bal := 0
	for it: Dictionary in items:
		bal += -value(state, valuer, it) if int(it["giver"]) == valuer else value(state, valuer, it)
	return clampi(FixedMath.floor_div(bal, maxi(1, r.deal_value_per_point)), -r.deal_balance_max, r.deal_balance_max)


static func is_gift(items: Array, giver: int) -> bool:
	return items.all(func(it: Dictionary) -> bool: return int(it["giver"]) == giver)


## Carries out an accepted deal: the first payments now; recurring items continue monthly.
static func execute(state: MatchState, a: int, b: int, items: Array) -> void:
	var d := Deal.new()
	d.id = state.alloc_id()
	d.a = a
	d.b = b
	d.tick = state.tick
	for it: Dictionary in items:
		var x := it.duplicate()
		x["left"] = maxi(1, int(it.get("months", 0)))
		d.items.append(x)
	state.deals.put(d.id, d)
	if is_gift(items, a):
		var r := rules(state)
		var worth := 0
		for it: Dictionary in items:
			worth += value(state, b, it)
		Relations.add_event(state, b, a, "gift", FixedMath.floor_div(worth, maxi(1, r.gift_value_per_opinion)))
	_pay(state, d)


## One round of payments; the deal is done when nothing is left to pay or deliver.
static func _pay(state: MatchState, d: Deal) -> void:
	for it: Dictionary in d.items:
		if int(it["left"]) <= 0:
			continue
		it["left"] = int(it["left"]) - 1
		var giver := int(it["giver"])
		var receiver := d.b if giver == d.a else d.a
		var amount := int(it["amount"])
		match String(it["kind"]):
			"credits", "influence":
				var res := CREDITS if it["kind"] == "credits" else INFLUENCE
				var ge := state.empire(giver)
				var have := int(ge.treasury.get(res, 0))
				if have < amount * Stockpile.MILLI:
					fail(state, d, giver)
					return
				ge.treasury[res] = have - amount * Stockpile.MILLI
				var re := state.empire(receiver)
				re.treasury[res] = int(re.treasury.get(res, 0)) + amount * Stockpile.MILLI
			"resource":
				var dl := Delivery.new()
				dl.id = state.alloc_id()
				dl.deal = d.id
				dl.giver = giver
				dl.receiver = receiver
				dl.resource = String(it["ref"])
				dl.remaining = amount * Stockpile.MILLI
				state.deliveries.put(dl.id, dl)
			"system":
				transfer_system(state, int(it["ref"]), giver, receiver)
	_close_if_done(state, d)


static func _close_if_done(state: MatchState, d: Deal) -> void:
	if d.items.any(func(it: Dictionary) -> bool: return int(it["left"]) > 0):
		return
	for did: int in state.deliveries.ordered():
		if (state.deliveries.get_or(did) as Delivery).deal == d.id:
			return
	state.deals.erase(d.id)


## The deal fails (unpaid or a convoy lost): the other side's opinion of the empire that failed it (E6).
static func fail(state: MatchState, d: Deal, at_fault: int) -> void:
	var other := d.b if at_fault == d.a else d.a
	Relations.add_event(state, other, at_fault, "deal_failed", int(rules(state).event_cap.get(&"deal_failed", -10)))
	for did: int in state.deliveries.ordered():
		var dl: Delivery = state.deliveries.get_or(did)
		if dl.deal == d.id:
			var u: Unit = state.units.get_or(dl.unit)
			if u != null and int(u.job.get("delivery", -1)) == dl.id:
				u.job.erase("delivery")
			state.deliveries.erase(did)
	state.deals.erase(d.id)


## A system changes hands (ceded in a deal or a peace, E6/E7): its owner, the giver's colonies (pops keep their
## species) and stations there; the giver's routes and demands that touch them go.
static func transfer_system(state: MatchState, sid: int, from: int, to: int) -> void:
	var sys := state.galaxy.system(sid)
	sys.owner = to
	var moved := {}
	for pid in sys.planet_ids:
		var c := state.colony(pid)
		if c != null and c.owner == from:
			c.owner = to
			c.queue.clear()
			c.mods_cache = []
			moved[pid] = true
	for stid: int in state.stations.ordered():
		var st: Station = state.stations.get_or(stid)
		if st.owner == from and st.system_id == sid:
			st.owner = to
			st.ship_queue.clear()
			moved[stid] = true
	for rid: int in state.routes.ordered():
		var rt: Route = state.routes.get_or(rid)
		if moved.has(rt.source) or moved.has(rt.dest):
			state.routes.erase(rid)
	for did: int in state.demands.ordered():
		if moved.has((state.demands.get_or(did) as Demand).holder):
			state.demands.erase(did)
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		if u.owner == from and moved.has(u.home):
			u.home = StateIO.NONE


static func month_tick(state: MatchState) -> void:
	for did: int in state.deals.ordered():
		var d: Deal = state.deals.get_or(did)
		if d != null and d.tick < state.tick:
			_pay(state, d)


## Daily: idle giver freighters pick up deliveries (source: the giver's holder with most of it; destination:
## the receiver's capital), and deliveries whose freighter dropped the job wait for another.
static func day_tick(state: MatchState) -> void:
	for did: int in state.deliveries.ordered():
		var dl: Delivery = state.deliveries.get_or(did)
		var u: Unit = state.units.get_or(dl.unit) if dl.unit != StateIO.NONE else null
		if u != null and int(u.job.get("delivery", -1)) == dl.id:
			continue
		dl.unit = StateIO.NONE
		var source := StateIO.NONE
		var best := 0
		for h in AutoLogistics._own_holders(state, dl.giver):
			var sp := Holders.stockpile(state, h)
			if sp != null and sp.milli(dl.resource) > best:
				best = sp.milli(dl.resource)
				source = h
		var dest := state.empire(dl.receiver).capital_planet
		if source == StateIO.NONE or state.colony(dest) == null:
			continue
		for uid: int in state.units.ordered():
			var f: Unit = state.units.get_or(uid)
			if f.owner == dl.giver and f.kind == "freighter" and f.job.is_empty() and f.route == StateIO.NONE \
					and not f.is_moving() and f.phase in ["", "home"]:
				f.job = {"source": source, "dest": dest, "resource": dl.resource,
					"amount": mini(dl.remaining, Freight.capacity_milli(state, f)), "delivery": dl.id}
				dl.unit = f.id
				break


## Freight hook: a deal freighter unloaded `amount` at its destination.
static func delivered(state: MatchState, delivery_id: int, amount: int) -> void:
	var dl: Delivery = state.deliveries.get_or(delivery_id)
	if dl == null:
		return
	dl.remaining -= amount
	dl.unit = StateIO.NONE
	if dl.remaining <= 0:
		state.deliveries.erase(dl.id)
		var d: Deal = state.deals.get_or(dl.deal)
		if d != null:
			_close_if_done(state, d)


## Pirates/raid hook: a deal freighter was lost with its cargo: the deal fails, the giver at fault (E6).
static func lost(state: MatchState, delivery_id: int) -> void:
	var dl: Delivery = state.deliveries.get_or(delivery_id)
	var d: Deal = state.deals.get_or(dl.deal) if dl != null else null
	if d != null:
		fail(state, d, dl.giver)
