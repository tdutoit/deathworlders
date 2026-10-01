extends Node
## Global signals for views and UI (main spec 16.2). Signals are added by the work packages that
## emit them.

## A match was created or loaded; GameState.state is ready.
signal match_started
## The match was closed (back to the menu).
signal match_ended
## kind: "", "cluster", "system", "planet" or "unit"; id: entity ID (0 when kind is "").
signal selection_changed(kind: String, id: int)
## level: "galaxy", "cluster" or "solar"; focus_id: cluster or system ID in focus (0 for galaxy).
signal view_changed(level: String, focus_id: int)
