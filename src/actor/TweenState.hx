package actor;

import math.Vec3;

@:publicFields
class TweenState {
	var tween_type: TweenType;
	var tween_duration: Float;

	var tween_time: Float = 0;
	var cmd_queue: Array<String> = [];

	var position: Vec3;

	function set_from(base: TweenState) {
		position = base.position.copy();
	}

	function new(type: TweenType, duration: Float) {
		tween_type = type;
		tween_duration = duration;
		position = new Vec3(0, 0, 0);
	}
}
