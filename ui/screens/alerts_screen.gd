class_name AlertsScreen
extends ScreenPanel
## Alerts panel (F12, D6): urgent first. Each alert can show its place on the map and, where D6 has one,
## offers a one-click fix whose Command is previewed in a line under it before it is issued.

signal construction_requested(planet_id: int)  # an alert's "Queue": the Construction screen (M4 WP15)

const GLYPHS := ["●", "◐", "○"]  # urgent / soon / info: shape as well as colour (F1, F18)


func _init() -> void:
	title_key = "ALERTS_TITLE"


func _fill(state: MatchState, eid: int) -> void:
	var alerts := Alerts.collect(state, eid)
	if alerts.is_empty():
		heading("ALERTS_NONE")
		return
	for i in alerts.size():
		var a: Dictionary = alerts[i]
		var r := row()
		var glyph := line(GLYPHS[a["severity"]], "Mono", r)
		if a["severity"] == Alerts.URGENT:
			glyph.add_theme_color_override("font_color", UiTokens.color("signal"))
		var text := line(UiKit.tr_fmt(a["key"], a["params"]), "", r)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if a["kind"] != "":
			var kind: String = a["kind"]
			var id: int = a["id"]
			button(TranslationServer.translate("ALERTS_SHOW"), "Show_%d" % i, func() -> void:
				focus_requested.emit(kind, id), r)
		if a.has("build"):
			var pid: int = a["build"]
			button(TranslationServer.translate("ALERTS_QUEUE"), "Queue_%d" % i, func() -> void:
				construction_requested.emit(pid), r)
		var fix: Dictionary = a["fix"]
		if not fix.is_empty():
			button(TranslationServer.translate("ALERTS_FIX"), "Fix_%d" % i, func() -> void:
				CommandQueue.submit_new(fix["type"], fix["payload"]), r)
			line("   " + UiKit.tr_fmt(fix["key"], fix["params"]), "Caption")
