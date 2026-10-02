extends GutTest
# M4 WP12: difficulty (E13) and match setup (F15): Council seats, settings round trip.

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func test_difficulty_and_council_seats() -> void:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human", MatchSettings.OFFICER, true)
	settings.add_player(1, "core:species/krothi", "ai", "core:difficulty/admiral")
	settings.add_player(2, "core:species/vesskar", "ai", "core:difficulty/cadet")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, 3, _db, errors)
	assert_eq(errors, [] as Array[String])
	var by_slot := {}
	for e: Empire in s.empires.values():
		by_slot[e.player_slot] = e
	assert_eq((by_slot[1] as Empire).ai_output, 300, "Admiral: +30% output")
	assert_eq((by_slot[1] as Empire).ai_actions, 3)
	assert_eq((by_slot[2] as Empire).ai_output, -200, "Cadet: -20%")
	assert_eq((by_slot[2] as Empire).ai_actions, 1)
	assert_eq((by_slot[0] as Empire).ai_output, 0, "players get no bonus")
	assert_true((by_slot[0] as Empire).id in s.council.members, "a founding seat from match setup")
	assert_true((by_slot[2] as Empire).id in s.council.members, "the Vess'kar too")
	var back := MatchSettings.from_dict(settings.to_dict())
	assert_eq(back.players[1]["difficulty"], "core:difficulty/admiral")
	assert_eq(back.players[0]["council_seat"], true)


func test_unknown_difficulty_rejected() -> void:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	settings.add_player(1, "core:species/krothi", "ai", "core:difficulty/godlike")
	assert_eq(GalaxyGenerator.check_settings(settings, _db).size(), 1)
