package actor;

import math.Utils;
import math.Vec3;
import math.Mat4;

typedef TweenFn = Float->Float;
typedef CommandFn = Void->Void;

class Actor {
	var tween_stack: Array<TweenState> = [];
	var current: TweenState;
	public var actual = new TweenState(Constant, 0);
	var commands = new Map<String, CommandFn>();

	var children: Array<Actor> = [];
	var matrix: Mat4 = new Mat4();

	function push(type: TweenType, t: Float) {
		var state = new TweenState(type, t);
		var len = tween_stack.length;
		if (len > 0) {
			state.set_from(tween_stack[len-1]);
		}
		tween_stack.push(state);
		current = state;
	}

	public function new() {
		this.push(Constant, 0);
	}

	public inline function register(k: String, v: CommandFn) {
		this.commands[k] = v;
	}

	public inline function trigger(k: String) {
		if (this.commands.exists(k)) {
			this.commands[k]();
		}
		for (child in this.children) {
			child.trigger(k);
		}
	}

	public function queuecommand(cmd: String) {
		if (this.current.cmd_queue.indexOf(cmd) < 0) {
			this.current.cmd_queue.push(cmd);
		}
	}

	public function sleep(t: Float) {
		this.push(Constant, t);
	}

	public function linear(t: Float) {
		this.push(Linear, t);
	}

	public function accelerate(t: Float) {
		this.push(InQuad, t);
	}

	public function decelerate(t: Float) {
		this.push(OutQuad, t);
	}

	public function smooth(t: Float) {
		this.push(SmoothQuad, t);
	}

	function tween_for(type: TweenType): TweenFn {
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
			case Constant: return function(t) { return 0; }
			case Linear: return function(t) { return t; }
			case InQuad: return quad;
			case InCubic: return cubic;
			case OutQuad: return out(quad);
			case OutCubic: return out(cubic);
			case SmoothQuad: return chain(quad, out(quad));
			case SmoothCubic: return chain(cubic, out(cubic));
		}
	}

	function mix(a: TweenState, b: TweenState, t: Float) {
		var tween = tween_for(b.tween_type);
		actual.position = Vec3.lerp(a.position, b.position, tween(t));
	}

	public function update(dt: Float, ?parent: Actor): Void {
		var a = tween_stack[0];
		var b = tween_stack[1];

		if (b == null) {
			actual = a;
			return;
		}

		b.tween_time += dt;
		var progress = b.tween_time / b.tween_duration;

		// we need at least one thing left on the stack at all times.
		if (progress >= 1 && tween_stack.length > 1) {
			tween_stack.splice(0, 1);

			if (b.cmd_queue.length > 0) {
				for (cmd in b.cmd_queue) {
					if (this.commands.exists(cmd)) {
						this.commands[cmd]();
					}
				}
				b.cmd_queue = [];
			}

			// if a tween was overshot, don't lose the time.
			tween_stack[0].tween_time += b.tween_time - b.tween_duration;
		}

		mix(a, b, Utils.clamp(progress, 0, 1));

		this.matrix = Mat4.from_srt(
			this.actual.position,
			new Vec3(0, 0, 0),
			new Vec3(1, 1, 1)
		);
		if (parent != null) {
			this.matrix = parent.matrix * this.matrix;
		}

		for (child in this.children) {
			child.update(dt, this);
		}
	}

	public var position(get, set): Vec3;
	inline function get_position() {
		return current.position;
	}
	inline function set_position(v: Vec3) {
		current.position = v;
		return v;
	}
}
