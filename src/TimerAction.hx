import actor.TweenType;
import math.Vec3;

typedef TweenFn = Float->Float;

typedef Timer = {
	var time:     Float;
	var length:   Float;
	var subject:  Vec3;
	var original: Vec3;
	var target:   Vec3;
	var type:     TweenType;
	var cb:       Void->Void;
}

class TimerAction {
	static var timers: Array<Timer> = [];

	public static function add(length: Float, subject: Vec3, target: Vec3, type: TweenType, ?cb: Void->Void) {
		var timer: Timer = {
			time:     0,
			length:   length,
			subject:  subject,
			original: subject.copy(),
			target:   target,
			type:     type,
			cb:       cb
		};

		timers.push(timer);
	}

	public static function update(dt: Float) {
		var i = timers.length;
		while (i-- > 0) {
			var timer = timers[i];
			timer.time += dt;

			if (timer.time >= timer.length) {
				timer.time = timer.length;
			}

			// tween based on % between 0 and length
			var progress    = timer.time / timer.length;
			var tween       = tween_for(timer.type);
			var new_subject = Vec3.lerp(timer.original, timer.target, tween(progress));

			timer.subject.x = new_subject.x;
			timer.subject.y = new_subject.y;
			timer.subject.z = new_subject.z;

			if (timer.time == timer.length) {
				if (timer.cb != null) {
					timer.cb();
				}
				timers.remove(timer);
			}
		}
	}

	public static inline function clear() {
		timers = [];
	}

	static function tween_for(type: TweenType): TweenFn {
		inline function out(f: TweenFn) {
			return function(s: Float): Float { return 1 - f(1-s); };
		}

		inline function chain(f1: TweenFn, f2: TweenFn) {
			return function(s: Float): Float { return (s < .5 ? f1(2*s) : 1 + f2(2*s-1)) * .5; }
		}

		function quad(t: Float) {
			return t*t;
		}

		function cubic(t: Float) {
			return t*t*t;
		}

		return switch(type) {
			case Constant:    return function(t) { return 0; }
			case Linear:      return function(t) { return t; }
			case InQuad:      return quad;
			case InCubic:     return cubic;
			case OutQuad:     return out(quad);
			case OutCubic:    return out(cubic);
			case SmoothQuad:  return chain(quad,  out(quad));
			case SmoothCubic: return chain(cubic, out(cubic));
		}
	}
}
