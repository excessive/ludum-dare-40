import lua.Coroutine.yield;
import lua.Lua.pcall;

typedef Routine = {
	var resume: (Float->Void)->Void;
	var delay:  Float;
}

class TimerScript {
	static var routines: Array<Routine> = [];

	public static function add(f: (Float->Void)->Void) {
		var routine: Routine = {
			resume: untyped __lua__("coroutine.wrap(function(_, ...) {0}(...) end)", f),
			delay:  0
		};
		routines.push(routine);

		routine.resume(function(delay: Float) {
			routine.delay = delay - Math.abs(routine.delay);
			yield();
		});
	}

	public static function update(dt: Float) {
		var i = routines.length;
		while (i-- > 0) {
			var routine = routines[i];
			routine.delay -= dt;

			if (routine.delay <= 0) {
				if (!(pcall(routine.resume).status)) {
					routines.remove(routine);
				}
			}
		}
	}

	public static inline function clear() {
		routines = [];
	}
}
