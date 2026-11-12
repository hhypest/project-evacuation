class_name CameraPreferences
extends RefCounted
## Local presentation preferences. The checkpoint format and player physics are independent.

const FOV_MIN: float = 55.0
const FOV_MAX: float = 90.0
const SENSITIVITY_MIN: float = 25.0
const SENSITIVITY_MAX: float = 200.0
const ALIGN_MIN: float = 90.0
const ALIGN_MAX: float = 360.0
const BASE_RADIANS_PER_PIXEL: float = 0.0025

var fov: float = 65.0
var sensitivity: float = 100.0
var gravity_rate: float = 360.0
var show_hint: bool = true
