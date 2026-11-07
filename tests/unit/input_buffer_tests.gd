class_name InputBufferTests
extends TestSuite


func suite_name() -> StringName:
	return &"unit"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var buffer: GameplayInputBuffer = GameplayInputBuffer.new()
	buffer.configure(true, 1)
	buffer.record_action(&"move_forward", true)
	buffer.record_action(&"move_right", true)
	buffer.record_action(&"jump", true)
	buffer.record_action(&"interact", true)
	buffer.record_look(Vector2(12, -3))
	var first: GameplayInputFrame = buffer.take_frame()
	var second: GameplayInputFrame = buffer.take_frame()
	results.append(TestOutcome.new("diagonal input is normalized, edges and look consumed once",
		is_equal_approx(first.move_axis.length(), 1.0) and first.jump_requested and first.interact_requested
		and first.look_delta == Vector2(12, -3) and second.move_axis == first.move_axis
		and not second.jump_requested and not second.interact_requested and second.look_delta == Vector2.ZERO))
	buffer.record_action(&"jump", true, true)
	results.append(TestOutcome.new("keyboard echo never repeats a jump edge", not buffer.take_frame().jump_requested))
	buffer.record_look(Vector2(500, 500))
	buffer.configure(false, 1)
	buffer.configure(true, 1)
	buffer.record_action(&"move_forward", true, true)
	var resumed: GameplayInputFrame = buffer.take_frame()
	results.append(TestOutcome.new("pause clears held input and look, held keys await release",
		resumed.move_axis == Vector2.ZERO and resumed.look_delta == Vector2.ZERO))
	buffer.record_action(&"move_forward", false)
	buffer.record_action(&"move_forward", true)
	results.append(TestOutcome.new("release and fresh press rearm an action",
		buffer.take_frame().move_axis == Vector2(0, -1)))
	buffer.configure(true, 2)
	var restarted: GameplayInputFrame = buffer.take_frame()
	results.append(TestOutcome.new("new generation discards old input",
		restarted.generation == 2 and restarted.move_axis == Vector2.ZERO))
	buffer.configure(false, 2)
	buffer.record_action(&"jump", true)
	buffer.release_unheld_actions([])
	buffer.configure(true, 2)
	buffer.record_action(&"jump", true)
	results.append(TestOutcome.new("release outside the window is reconciled before the next press",
		buffer.take_frame().jump_requested))
	buffer.configure(false, 2)
	buffer.record_action(&"interact", true)
	buffer.record_look(Vector2(10, 10))
	buffer.configure(true, 2)
	var menu_input: GameplayInputFrame = buffer.take_frame()
	results.append(TestOutcome.new("menu actions and mouse motion never spill into gameplay",
		not menu_input.interact_requested and menu_input.look_delta == Vector2.ZERO))
	return results
