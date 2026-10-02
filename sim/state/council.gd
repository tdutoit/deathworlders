class_name Council
extends RefCounted
## The Galactic Council (Sub-spec E9; M4 WP8). Members vote at sessions every council_session_months.
## proposals: [{id, proposer, def, target (-1), repeal (active resolution id or -1), votes: {"eid": 1|-1}}]
## active: [{id, def, target, proposer, tick, for: [member IDs that voted for it]}]
## last_session: [{def, target, repeal, proposer, yes, no, passed, vetoed}] for the UI.

var members: Array[int] = []
var next_session := 0
var proposals: Array = []
var active: Array = []
var last_session: Array = []
var sessions := 0


func to_dict() -> Dictionary:
	return {"members": members.duplicate(), "next_session": next_session, "proposals": proposals.duplicate(true),
		"active": active.duplicate(true), "last_session": last_session.duplicate(true), "sessions": sessions}


static func from_dict(d: Dictionary) -> Council:
	var c := Council.new()
	c.members = StateIO.ints(d.get("members", []))
	c.next_session = int(d.get("next_session", 0))
	c.proposals = StateIO.ints_deep(d.get("proposals", []))
	c.active = StateIO.ints_deep(d.get("active", []))
	c.last_session = StateIO.ints_deep(d.get("last_session", []))
	c.sessions = int(d.get("sessions", 0))
	return c
