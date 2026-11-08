class_name DeviceDefinition
extends RefCounted
## Engine-independent description of one puzzle device and the IDs that drive its inputs.

enum Kind { SOURCE, FLOOR_BUTTON, WALL_BUTTON, RECEIVER, AND, OR, NOT, DELAY, LATCH, DOOR, EMITTER, GRAVITY_FIELD, PORTAL_PAIR }
enum WallMode { TIMED, TOGGLE }

var id: StringName = &""
var kind: Kind = Kind.SOURCE
## Ordered input IDs. LATCH uses [set, reset].
var inputs: Array[StringName] = []
## Floor button: supported load in kilograms that presses the plate.
var press_threshold: float = 4.0
## Floor button: load below which a pressed plate releases (hysteresis).
var release_threshold: float = 3.0
## Sensor debounce: consecutive ticks a new state must hold before it is accepted.
var settle_ticks: int = 3
var wall_mode: WallMode = WallMode.TIMED
## Wall button in TIMED mode: how long one press keeps the output on.
var hold_seconds: float = 3.0
## DELAY: transport delay between input and output.
var delay_seconds: float = 0.5
## SOURCE output; LATCH memory after build or reset.
var initial: bool = false
## EMITTER/RECEIVER: optical channel. A receiver accepts only beams of its own channel.
var channel: int = 0
## RECEIVER: widest accepted angle between the beam and the receiver's front normal, degrees.
var acceptance_degrees: float = 30.0


static func make(device_id: StringName, device_kind: Kind, device_inputs: Array[StringName] = []) -> DeviceDefinition:
	var definition: DeviceDefinition = DeviceDefinition.new()
	definition.id = device_id
	definition.kind = device_kind
	definition.inputs = device_inputs.duplicate()
	return definition


func is_sensor() -> bool:
	return kind in [Kind.SOURCE, Kind.FLOOR_BUTTON, Kind.WALL_BUTTON, Kind.RECEIVER]


## Memory elements publish their stored value during a tick and may legally close a loop.
func is_memory() -> bool:
	return kind in [Kind.DELAY, Kind.LATCH]


func duplicate_definition() -> DeviceDefinition:
	var copy: DeviceDefinition = DeviceDefinition.make(id, kind, inputs)
	copy.press_threshold = press_threshold
	copy.release_threshold = release_threshold
	copy.settle_ticks = settle_ticks
	copy.wall_mode = wall_mode
	copy.hold_seconds = hold_seconds
	copy.delay_seconds = delay_seconds
	copy.initial = initial
	copy.channel = channel
	copy.acceptance_degrees = acceptance_degrees
	return copy
