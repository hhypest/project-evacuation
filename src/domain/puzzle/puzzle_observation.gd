class_name PuzzleObservation
extends RefCounted
## One consistent set of world facts for a puzzle tick. Adapters fill it; the network never reads nodes.

var tick_id: int = -1
## Floor button ID -> supported load in kilograms.
var loads: Dictionary[StringName, float] = {}
## Wall buttons pressed since the previous tick. Duplicates count once.
var presses: Array[StringName] = []
## Beams that ended on a receiver this tick. Acceptance (power, channel, angle) is decided by the network.
var beams: Array[BeamHit] = []
