class_name SessionStatus
extends RefCounted

var phase: SessionLifecycle.Phase = SessionLifecycle.Phase.READY
var generation: int = 0
var focused: bool = false
var can_start: bool = false
var can_resume: bool = false
var can_restart: bool = false
var accepts_gameplay: bool = false
