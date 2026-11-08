class_name PuzzleObservation
extends RefCounted
## One consistent set of world facts for a puzzle tick. Adapters fill it; the network never reads nodes.

var tick_id: int = -1
## Floor button ID -> supported load in kilograms.
var loads: Dictionary[StringName, float] = {}
## Wall buttons pressed since the previous tick. Duplicates count once.
var presses: Array[StringName] = []
## Receiver ID -> whether a valid game beam hits it this tick.
var beam_hits: Dictionary[StringName, bool] = {}
