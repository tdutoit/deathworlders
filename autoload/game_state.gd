extends Node
## Holds the current match (main spec 16.2). Views read `state`; only Commands and tick functions
## change it. The state itself is a plain MatchState (sim/state); this node only owns the reference.

var state: MatchState
