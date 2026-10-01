class_name MatchSettings
extends RefCounted
## Match setup choices, saved with the match (main spec 17). Def references are string IDs.

var galaxy_size := "core:match_preset/size_small"
var pace := "core:match_preset/pace_standard"
var seed_text := ""  # what the player typed; match_seed is derived from it (or random)
var crisis := "normal"  # off / early / normal / late; stored, unused in M1
var players: Array[Dictionary] = []  # {slot: int, species: String, controller: "human" | "ai"}


func add_player(slot: int, species: String, controller: String) -> void:
	players.append({"slot": slot, "species": species, "controller": controller})


func to_dict() -> Dictionary:
	var ps := []
	for p in players:
		ps.append(p.duplicate())
	return {"galaxy_size": galaxy_size, "pace": pace, "seed_text": seed_text, "crisis": crisis, "players": ps}


static func from_dict(d: Dictionary) -> MatchSettings:
	var s := MatchSettings.new()
	s.galaxy_size = String(d["galaxy_size"])
	s.pace = String(d["pace"])
	s.seed_text = String(d["seed_text"])
	s.crisis = String(d["crisis"])
	for p: Dictionary in d["players"]:
		s.add_player(int(p["slot"]), String(p["species"]), String(p["controller"]))
	return s
