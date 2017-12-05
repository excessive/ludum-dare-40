package components;

import math.Capsule;
import math.Mat4;
import math.Vec3;

@:publicFields
class Rail {
	var friction: Float;
	var length:   Float;
	var capsule:  Capsule;
	var mtx:      Null<Mat4>;
	var prev:     Null<Rail>;
	var next:     Null<Rail>;

	function new(start: Vec3, end: Vec3, ?mtx: Mat4) {
		this.friction = 0.25;
		this.length   = Vec3.distance(start, end);
		this.capsule  = new Capsule(start, end, 0.25);
		this.mtx      = mtx;
	}

	public function copy(): Rail {
		var r  = new Rail(this.capsule.a.copy(), this.capsule.b.copy(), this.mtx);
		r.prev = this.prev;
		r.next = this.next;

		return r;
	}
}
