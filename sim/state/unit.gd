class_name Unit
extends RefCounted
## A mobile unit: scouts, freighters and colony ships in M2. While moving, path holds the systems still to visit and
## progress counts milli-lane-units travelled on the current lane (system_id -> path[0]).

var id: int
var owner: int
var kind: String  # "scout", "freighter", "colony" (the hull's role)
var hull_id: String  # hull Def ID ("" for M1 debug scouts)
var home: int = StateIO.NONE  # freighters: the hub (station or colony ID) whose berth it uses
var system_id: int
var path: Array[int] = []
var progress: int  # milli-lane-units (1 lane unit = 1000)
var speed: int  # milli-lane-units per hour tick
# Freight (M2 WP5): where it is inside its system, what it's doing and what it carries.
var body: int = StateIO.NONE  # planet ID it is at (when not on a lane)
var route: int = StateIO.NONE  # assigned Route ID
var phase := ""  # "", "to_source", "loading", "to_dest", "unloading", "home"
var wait_hours := 0  # loading/unloading or in-system travel still to go
var impulse_to: int = StateIO.NONE  # body it is flying to inside the system
var cargo := {}  # resource ID -> milli-units aboard
var job := {}  # one-shot auto-logistics trip {source, dest, resource, amount (milli)}; empty when none
var target_planet: int = StateIO.NONE  # colony ships: the planet to settle
var out_of_fuel := false  # last fuel draw failed: half speed until resupplied (M2 rule)
var raid_checked: int = StateIO.NONE  # freighters: last system a raider passage roll was made in (B9)
var target_owner: int = StateIO.NONE  # raiders: the empire they hunt
var months_left := 0  # raiders: months before leaving (0 = stays, e.g. a base's guard)
var design := 0  # warships: the design it was built from (may since be edited or deleted)
var components: Array[String] = []  # warships: its components, in hull slot order ("" = empty)
var fleet: int = StateIO.NONE  # warships: the fleet it belongs to
var hp := 0  # warships: current hull points (A1 hull)
var armor := 0  # current armour (ablates, A9)
var shield := 0  # current shield
var ammo := 0
var crew := 0
var marines := 0
var xp := 0  # veterancy (A12, A13)
var moved := false  # moved on a lane this month (B12 fuel: moving vs idle); reset by the monthly fuel draw
var unsupplied_days := 0  # warships: consecutive days outside supply range (A13 attrition)


func is_moving() -> bool:
	return not path.is_empty()


func cargo_milli() -> int:
	var n := 0
	for res: String in cargo:
		n += cargo[res]
	return n


func to_dict() -> Dictionary:
	return {
		"id": id, "owner": owner, "kind": kind, "system_id": system_id, "path": path.duplicate(),
		"progress": progress, "speed": speed, "hull_id": hull_id, "home": home,
		"body": body, "route": route, "phase": phase, "wait_hours": wait_hours, "impulse_to": impulse_to,
		"cargo": cargo.duplicate(), "job": job.duplicate(), "target_planet": target_planet, "out_of_fuel": out_of_fuel, "raid_checked": raid_checked,
		"target_owner": target_owner, "months_left": months_left, "design": design, "components": components.duplicate(),
		"fleet": fleet, "hp": hp, "armor": armor, "shield": shield, "ammo": ammo, "crew": crew, "marines": marines,
		"xp": xp, "moved": moved, "unsupplied_days": unsupplied_days,
	}


static func from_dict(d: Dictionary) -> Unit:
	var u := Unit.new()
	u.id = int(d["id"])
	u.owner = int(d["owner"])
	u.kind = String(d["kind"])
	u.system_id = int(d["system_id"])
	u.path = StateIO.ints(d["path"])
	u.progress = int(d["progress"])
	u.speed = int(d["speed"])
	u.hull_id = String(d.get("hull_id", ""))
	u.home = int(d.get("home", StateIO.NONE))
	u.body = int(d.get("body", StateIO.NONE))
	u.route = int(d.get("route", StateIO.NONE))
	u.phase = String(d.get("phase", ""))
	u.wait_hours = int(d.get("wait_hours", 0))
	u.impulse_to = int(d.get("impulse_to", StateIO.NONE))
	u.cargo = StateIO.int_map(d.get("cargo", {}))
	u.target_planet = int(d.get("target_planet", StateIO.NONE))
	u.out_of_fuel = d.get("out_of_fuel", false) == true
	u.raid_checked = int(d.get("raid_checked", StateIO.NONE))
	u.target_owner = int(d.get("target_owner", StateIO.NONE))
	u.months_left = int(d.get("months_left", 0))
	u.design = int(d.get("design", 0))
	u.components.assign(d.get("components", []))
	u.fleet = int(d.get("fleet", StateIO.NONE))
	u.hp = int(d.get("hp", 0))
	u.armor = int(d.get("armor", 0))
	u.shield = int(d.get("shield", 0))
	u.ammo = int(d.get("ammo", 0))
	u.crew = int(d.get("crew", 0))
	u.marines = int(d.get("marines", 0))
	u.xp = int(d.get("xp", 0))
	u.moved = d.get("moved", false) == true
	u.unsupplied_days = int(d.get("unsupplied_days", 0))
	u.job = {}
	var j: Dictionary = d.get("job", {})
	if not j.is_empty():
		u.job = {"source": int(j["source"]), "dest": int(j["dest"]), "resource": String(j["resource"]), "amount": int(j["amount"])}
	return u
