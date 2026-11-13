class_name BallastCube
extends CarryRigidBody
## The two authored ballast props. Collision and art are derived from the same specification.

enum Kind { LIGHT, HEAVY }

const LIGHT_EDGE: float = 0.50
const HEAVY_EDGE: float = 0.75
const LIGHT_MASS: float = 5.0
const HEAVY_MASS: float = 10.0

@export var kind: Kind = Kind.LIGHT


static func make(label: String, id: StringName, at: Vector3, variant: Kind) -> BallastCube:
	var body: BallastCube = new()
	body.name = label
	body.stable_id = id
	body.position = at
	body.kind = variant
	return body


func _ready() -> void:
	var heavy: bool = kind == Kind.HEAVY
	var edge: float = HEAVY_EDGE if heavy else LIGHT_EDGE
	mass = HEAVY_MASS if heavy else LIGHT_MASS
	collision_layer = 2
	collision_mask = 7
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * edge
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	add_child(collision)
	add_child(PropVisuals.ballast_cube(edge, heavy))
