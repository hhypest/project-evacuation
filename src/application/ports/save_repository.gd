class_name SaveRepository
extends RefCounted
## Progress storage boundary. Application only sees validated checkpoint snapshots and typed results.


func read_checkpoint() -> SaveResult:
	return SaveResult.new(SaveResult.Code.MISSING)


func write_checkpoint(_snapshot: SaveSnapshot) -> SaveResult.Code:
	return SaveResult.Code.IO_ERROR
