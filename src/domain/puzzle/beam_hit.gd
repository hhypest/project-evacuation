class_name BeamHit
extends RefCounted
## One traced game beam that ended on a receiver. The adapter measures geometry; the network decides acceptance.

var emitter_id: StringName = &""
var receiver_id: StringName = &""
## Cosine between the reversed beam direction and the receiver's front normal: 1 is head-on, <= 0 is from behind.
var incidence_cos: float = 0.0


static func make(emitter: StringName, receiver: StringName, cosine: float) -> BeamHit:
	var hit: BeamHit = BeamHit.new()
	hit.emitter_id = emitter
	hit.receiver_id = receiver
	hit.incidence_cos = cosine
	return hit
