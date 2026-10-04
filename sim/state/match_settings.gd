class_name MatchSettings
extends RefCounted
## Match setup choices, saved with the match (main spec 17). Def references are string IDs.

var galaxy_size := "core:match_preset/size_small"
var pace := "core:match_preset/pace_standard"
var seed_text := ""  # what the player typed; match_seed is derived from it (or random)
var crisis := "normal"  # off / early / normal / late; stored, unused in M1
var fog := "standard"  # D12 fog of war: off / standard / hardcore (M5)
var players: Array[Dictionary] = []  # {slot, species, controller: "human" | "ai", difficulty (AI), council_seat (bool)}


const OFFICER := "core:difficulty/officer"


## difficulty: an AI slot's E13 level (M4); council_seat: a founding Galactic Council seat (E9, M4).
func add_player(slot: int, species: String, controller: String, difficulty := OFFICER, council_seat := false) -> void:
	players.append({"slot": slot, "species": species, "controller": controller, "difficulty": difficulty,
		"council_seat": council_seat})


func to_dict() -> Dictionary:
	var ps := []
	for p in players:
		ps.append(p.duplicate())
	return {"galaxy_size": galaxy_size, "pace": pace, "seed_text": seed_text, "crisis": crisis, "fog": fog, "players": ps}


static func from_dict(d: Dictionary) -> MatchSettings:
	var s := MatchSettings.new()
	s.galaxy_size = String(d["galaxy_size"])
	s.pace = String(d["pace"])
	s.seed_text = String(d["seed_text"])
	s.crisis = String(d["crisis"])
	s.fog = String(d.get("fog", "standard"))
	for p: Dictionary in d["players"]:
		s.add_player(int(p["slot"]), String(p["species"]), String(p["controller"]), String(p.get("difficulty", OFFICER)),
			p.get("council_seat", false) == true)
	return s
