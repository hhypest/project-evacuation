extends SceneTree
## --suite all|unit|contract|integration|regression [--self-test-failure]

var _suite: StringName = &"all"
var _self_test_failure: bool = false
var _finished: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var started: int = Time.get_ticks_msec()
	if not _parse_arguments(OS.get_cmdline_user_args()):
		quit(2)
		return
	var suites: Array[TestSuite] = [
		SessionTests.new(), SessionControllerTests.new(), InputBufferTests.new(),
		RuntimeTests.new(), PhysicsTests.new(), ScopeLoadTests.new(), ScopeTests.new(),
	]
	var count: int = 0
	var failed: int = 0
	create_timer(30.0, true, false, true).timeout.connect(_on_timeout)
	print("TEST_RUN Godot=%s suite=%s" % [Engine.get_version_info()["string"], _suite])
	for suite: TestSuite in suites:
		if _suite != &"all" and suite.suite_name() != _suite:
			continue
		var results: Array[TestOutcome] = await suite.run(self)
		if results.is_empty():
			results.append(TestOutcome.new("selected suite must not be empty", false))
		for result: TestOutcome in results:
			count += 1
			if not result.passed:
				failed += 1
			print("%s [%s] %s %s" % [
				"PASS" if result.passed else "FAIL", suite.suite_name(), result.name, result.detail
			])
	if _self_test_failure:
		count += 1
		failed += 1
		print("FAIL [runner] intentional failure to verify exit-code handling")
	if count == 0:
		failed += 1
	print("TEST_RESULT total=%d failed=%d elapsed_ms=%d" % [count, failed, Time.get_ticks_msec() - started])
	_finished = true
	quit(0 if failed == 0 else 1)


func _parse_arguments(arguments: PackedStringArray) -> bool:
	var index: int = 0
	while index < arguments.size():
		match arguments[index]:
			"--suite":
				index += 1
				if index >= arguments.size():
					printerr("--suite requires a name")
					return false
				_suite = StringName(arguments[index])
			"--self-test-failure":
				_self_test_failure = true
			_:
				printerr("Unknown test argument: " + arguments[index])
				return false
		index += 1
	if _suite not in [&"all", &"unit", &"contract", &"integration", &"regression"]:
		printerr("Unknown suite: " + str(_suite))
		return false
	return true


func _on_timeout() -> void:
	if not _finished:
		printerr("TEST_TIMEOUT: suite did not complete within 30 seconds")
		quit(3)
