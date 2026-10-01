class_name Colony
extends RefCounted
## The economy of one owned planet (main spec 13, Sub-spec B2–B5, B17–B18, D2, D4). Keyed by planet ID.

var id: int  # = planet ID
var owner: int
var pops := {}  # species ID -> count
var jobs := {}  # job ID -> employed pops (derived by Economy.assign_jobs)
var buildings: Array[String] = []  # building IDs
var offline_building := -1  # index into buildings shut by a strike this month (B18), or -1
var primary_focus := ""
var secondary_focus := ""
var retool_days := 0  # days left of retooling after a focus change (B4)
var stability := 50
var growth := 0  # growth points toward the next pop (B17)
var stage := "colony"  # outpost / colony / developed / core (D2)
var founded_tick := 0
var starving := false  # food ran out at some point this month
var starving_months := 0
var job_priority: Array[String] = []  # player-set order (D4)
var job_caps := {}  # job ID -> max employed (D4 priorities + caps)
var stockpile := Stockpile.new()
var produced := {}  # resource ID -> milli-units this month (globals included)
var consumed := {}
var last_produced := {}  # last full month, for the UI and growth
var last_consumed := {}


func total_pops() -> int:
	var n := 0
	for s: String in pops:
		n += pops[s]
	return n


func employed() -> int:
	var n := 0
	for j: String in jobs:
		n += jobs[j]
	return n


func unemployed() -> int:
	return total_pops() - employed()


func add_flow(flows: Dictionary, res: String, amount: int) -> void:
	if amount != 0:
		flows[res] = flows.get(res, 0) + amount


func to_dict() -> Dictionary:
	return {
		"id": id, "owner": owner, "pops": pops.duplicate(), "jobs": jobs.duplicate(),
		"buildings": buildings.duplicate(), "offline_building": offline_building,
		"primary_focus": primary_focus, "secondary_focus": secondary_focus, "retool_days": retool_days,
		"stability": stability, "growth": growth, "stage": stage, "founded_tick": founded_tick,
		"starving": starving, "starving_months": starving_months, "job_priority": job_priority.duplicate(),
		"job_caps": job_caps.duplicate(), "stockpile": stockpile.to_dict(),
		"produced": produced.duplicate(), "consumed": consumed.duplicate(),
		"last_produced": last_produced.duplicate(), "last_consumed": last_consumed.duplicate(),
	}


static func from_dict(d: Dictionary) -> Colony:
	var c := Colony.new()
	c.id = int(d["id"])
	c.owner = int(d["owner"])
	c.pops = StateIO.int_map(d["pops"])
	c.jobs = StateIO.int_map(d["jobs"])
	for b: Variant in d["buildings"]:
		c.buildings.append(String(b))
	c.offline_building = int(d["offline_building"])
	c.primary_focus = String(d["primary_focus"])
	c.secondary_focus = String(d["secondary_focus"])
	c.retool_days = int(d["retool_days"])
	c.stability = int(d["stability"])
	c.growth = int(d["growth"])
	c.stage = String(d["stage"])
	c.founded_tick = int(d["founded_tick"])
	c.starving = d["starving"] == true
	c.starving_months = int(d["starving_months"])
	for j: Variant in d["job_priority"]:
		c.job_priority.append(String(j))
	c.job_caps = StateIO.int_map(d["job_caps"])
	c.stockpile = Stockpile.from_dict(d["stockpile"])
	c.produced = StateIO.int_map(d["produced"])
	c.consumed = StateIO.int_map(d["consumed"])
	c.last_produced = StateIO.int_map(d["last_produced"])
	c.last_consumed = StateIO.int_map(d["last_consumed"])
	return c
